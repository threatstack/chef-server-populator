if(node[:chef_server_populator][:default_org].nil?)
  node.default[:chef_server_populator][:default_org] = node[:chef_server_populator][:server_org]
end

include_recipe 'chef-server-populator::configurator'

# if backup pull files include restore

if(node[:chef_server_populator][:backup][:remote][:connection])
  chef_gem 'aws-sdk-s3' do
    compile_time true
    version '1.75.0'
  end

  require 'aws-sdk-s3'
  s3 = Aws::S3::Resource.new(region: 'us-east-1')
  %w[latest.tgz latest.dump].each do |f|
    target = File.join(node[:chef_server_populator][:backup][:remote][:file_prefix], f)
    latest = s3.bucket(node[:chef_server_populator][:backup][:remote][:directory]).object(target)
    latest.get(response_target: "/tmp/#{f}")
  end

  node.normal[:chef_server_populator][:restore][:file] = '/tmp/latest.dump'
  node.normal[:chef_server_populator][:restore][:data] = '/tmp/latest.tgz'
end

if(::File.exist?(node[:chef_server_populator][:restore][:file]) && ::File.exist?(node[:chef_server_populator][:restore][:data]))

  include_recipe 'chef-server-populator::restore'

else

    include_recipe 'chef-server-populator::org'
    orgs = node[:chef_server_populator][:solo_org]

    orgs.each do |k, org|
      knife_cmd = "#{node[:chef_server_populator][:knife_exec]}"
      knife_opts = "-s https://127.0.0.1/organizations/#{org['org_name']} -c /etc/opscode/pivotal.rb"

      node[:chef_server_populator][:clients].each do |client, pub_key|
        execute "#{k} - create client: #{client}" do
          command "#{knife_cmd} client create #{client} --admin -d #{knife_opts} > /dev/null 2>&1"
          not_if "#{knife_cmd} client list #{knife_opts}| tr -d ' ' | grep '^#{client}$'"
          retries 5
        end
        if(pub_key && node[:chef_server_populator][:base_path])
          pub_key_path = File.join(node[:chef_server_populator][:base_path], pub_key)
          execute "#{k} - remove default public key for #{client}" do
            command "chef-server-ctl delete-client-key #{org['org_name']} #{client} default"
            only_if "chef-server-ctl list-client-keys #{org['org_name']} #{client} | grep 'name: default$'"
          end
          execute "#{k} - set public key for: #{client}" do
          if (node['chef-server'][:version].to_f >= 12.1 || node['chef-server'][:version].to_f == 0.0)
            command "chef-server-ctl add-client-key #{org['org_name']} #{client} --public-key-path #{pub_key_path} --key-name populator"
          else
            command "chef-server-ctl add-client-key #{org['org_name']} #{client} #{pub_key_path} --key-name populator"
          end
            not_if "chef-server-ctl list-client-keys #{org['org_name']} #{client} | grep 'name: populator$'"
          end
        end
      end

      %w(apt-chef chef-server-populator).each do |cb|
        execute "#{k} - install #{cb} cookbook" do
          command "#{knife_cmd} cookbook upload #{cb} #{knife_opts} -o #{Chef::Config[:cookbook_path].join(':')} --include-dependencies"
          only_if do
            node[:chef_server_populator][:cookbook_auto_install]
          end
          retries 5
        end
      end
    end
end
