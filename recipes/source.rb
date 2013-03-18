#
# Cookbook Name:: redis
# Recipe:: source
#
# Author:: Gerhard Lazu (<gerhard.lazu@papercavalier.com>)
#
# Copyright 2010, Paper Cavalier, LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

include_recipe "build-essential"
include_recipe "iptables::redis"

user "redis" do
  comment "Redis Administrator"
  system true
  shell "/bin/false"
end

node.set[:redis][:pidfile] = "#{node[:redis][:pid_dir]}/redis.pid"

[node[:redis][:pid_dir], node[:redis][:datadir]].each do |dir|
  directory dir do
    owner "redis"
    group "redis"
    mode 0755
    recursive true
  end
end

remote_file "#{Chef::Config[:file_cache_path]}/redis-#{node[:redis][:version]}.tar.gz" do
  source "http://redis.googlecode.com/files/redis-#{node[:redis][:version]}.tar.gz"
  action :create_if_missing
end

bash "Compiling Redis #{node[:redis][:version]} from source" do
  cwd Chef::Config[:file_cache_path]
  code <<-EOH
    tar zxf redis-#{node[:redis][:version]}.tar.gz
    cd redis-#{node[:redis][:version]}
    make
    make PREFIX=#{node[:redis][:dir]} install
  EOH
  not_if "#{node[:redis][:dir]}/bin/redis-server -v 2>&1 | grep 'Redis server version #{::Regexp.escape(node[:redis][:version])} '"
  notifies :restart, "service[redis]"
end

file node[:redis][:logfile] do
  owner "redis"
  group "redis"
  mode 0644
  action :create_if_missing
  backup false
end

template node[:redis][:config] do
  source "redis.conf.erb"
  owner "redis"
  group "redis"
  mode 0644
end

template "/etc/profile.d/redis.sh" do
  source "profile.sh.erb"
  owner "root"
  group "root"
  mode "0644"
end

template "/etc/init.d/redis" do
  if platform?("centos", "redhat", "fedora")
    source "redhat.init.erb"
  else
    source "redis.init.erb"
  end
  mode 0755
end

service "redis" do
  supports :start => true, :stop => true, :restart => true
  action [:enable, :start]
  subscribes :restart, resources(:template => node[:redis][:config])
  subscribes :restart, resources(:template => "/etc/init.d/redis")
end

logrotate_app "redis" do
  path [node[:redis][:logfile]]
  rotate 10
  create "644 redis redis"
end
