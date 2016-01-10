if(node[:chef_server_populator][:chef_server])
  node.set['chef-server'] = node['chef-server'].merge(node[:chef_server_populator][:chef_server])
end

unless(node[:chef_server_populator][:endpoint])
  node.default[:chef_server_populator][:endpoint] = node[:chef_server_populator][:servername_override]
end

if(node[:chef_server_populator][:endpoint])
  node.set['chef-server'][:api_fqdn] =
    node.set['chef-server'][:configuration][:nginx][:server_name] =
    node.set['chef-server'][:configuration][:bookshelf][:vip] =
    node.set['chef-server'][:configuration][:lb][:api_fqdn] =
    node.set['chef-server'][:configuration][:lb][:web_ui_fqdn] = node[:chef_server_populator][:endpoint]
  node.set['chef-server'][:configuration][:nginx][:url] =
    node.set['chef-server'][:configuration][:bookshelf][:url] = "https://#{node[:chef_server_populator][:endpoint]}"
else
  node.set['chef-server'][:api_fqdn] =
    node.set['chef-server'][:configuration][:nginx][:server_name] =
    node.set['chef-server'][:configuration][:bookshelf][:vip] =
    node.set['chef-server'][:configuration][:lb][:api_fqdn] =
    node.set['chef-server'][:configuration][:lb][:web_ui_fqdn] = node[:fqdn]
  node.set['chef-server'][:configuration][:nginx][:url] =
    node.set['chef-server'][:configuration][:bookshelf][:url] = "https://#{node[:fqdn]}"
end

node.set['chef-server'][:configration][:postgresql][:shared_buffers] = "#{(node.memory.total.to_i / 1024) / 2}MB"

include_recipe 'chef-server'
