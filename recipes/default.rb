#
# Cookbook Name:: rvm-redmine
# Recipe:: default
#
# Copyright 2013, Takayuki SHIMIZUKAWA
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

include_recipe "openssl"
include_recipe "imagemagick" #need for redmine gantt
include_recipe "imagemagick::devel" #need for redmine gantt
include_recipe "rvm::system"
include_recipe "rvm::gem_package"


directory node.rvm_redmine.user_home do
  owner node.rvm_redmine.user
  group node.rvm_redmine.group
  recursive true
end

file "#{node.rvm_redmine.user_home}/.gemrc" do
  # for ignore rdoc and ri
  action :create
  owner node.rvm_redmine.user
  group node.rvm_redmine.group
  content "gem: --no-ri --no-rdoc"
end

#rvm_install "#{node.rvm.ruby_version} -C --with-iconv-dir=$rvm_usr_path --with-openssl-dir=$rvm_usr_path -C --with-zlib-dir=$rvm_usr_path --with-readline-dir=$rvm_usr_path"
rvm_environment node.rvm_redmine.rvm_name

rvm_gem 'rubygems-update' do
  ruby_string node.rvm_redmine.rvm_name
  version '1.3.7'
end
rvm_shell 'update_rubygems' do
  #not_if "test `gem -v` = 1.3.7"
  ruby_string node.rvm_redmine.rvm_name
end
rvm_gem 'rdoc' do
  ruby_string node.rvm_redmine.rvm_name
end
rvm_gem 'rmagick' do
  ruby_string node.rvm_redmine.rvm_name
  version '1.15.17'
end
rvm_gem 'bundler' do
  ruby_string node.rvm_redmine.rvm_name
  version '1.2.1'
end

remote_file node.rvm_redmine.archive do
  action :create_if_missing
  source "http://rubyforge.org/frs/download.php/#{node.rvm_redmine.dl_id}/#{node.rvm_redmine.file}"
  mode "0664"
  owner node.rvm_redmine.user
  group node.rvm_redmine.group
end

execute "extract-rails-archive" do
  user node.rvm_redmine.user
  group node.rvm_redmine.group
  environment ({'HOME' => node.rvm_redmine.user_home})
  command "tar zxf #{node.rvm_redmine.archive} -C #{node.rvm_redmine.user_home}"
  not_if "test -f #{node.rvm_redmine.path}"
end

template "#{node.rvm_redmine.path}/config/database.yml" do
  source "database.yml.erb"
  mode "0644"
  owner node.rvm_redmine.user
  group node.rvm_redmine.group
  variables({
    :mysql_root_password => node['mysql']['server_root_password'],
  })
end

template "#{node.rvm_redmine.path}/Gemfile.local" do
  source "Gemfile.local"
  mode "0644"
  owner node.rvm_redmine.user
  group node.rvm_redmine.group
end

template "#{node.rvm_redmine.path}/config/additional_environment.rb" do
  source "additional_environment.rb"
  mode "0644"
  owner node.rvm_redmine.user
  group node.rvm_redmine.group
end

rvm_shell "bundle install for rails" do
  ruby_string node.rvm_redmine.rvm_name
  cwd   node.rvm_redmine.path
  code "bundle install --without development test pg postgresql sqlite rmagick"
end

rvm_shell "rails-setup" do
  ruby_string node.rvm_redmine.rvm_name
  user  node.rvm_redmine.user
  group node.rvm_redmine.group
  cwd   node.rvm_redmine.path

  #environment({'RAILS_ENV' => 'production', 'REDMINE_LANG' => 'ja'})  #this work only with use_rvm! see https://github.com/fnichol/chef-rvm/blob/master/providers/shell.rb#L78
  code <<-EOH
  gem -v
  export RAILS_ENV=production
  export REDMINE_LANG=ja
  rake --trace db:create
  rake --trace generate_session_store
  rake --trace db:migrate
  rake --trace redmine:load_default_data
  EOH
end

template "#{node.rvm_redmine.path}/redmine.sh" do
  source "redmine.sh.erb"
  owner node.rvm_redmine.user
  group node.rvm_redmine.group
  mode "0755"
end

template "/etc/init.d/redmine" do
  source "init.d.redmine.erb"
  owner "root"
  group "root"
  mode "0755"
  notifies :enable, "service[redmine]"
  notifies :start, "service[redmine]"
end

template "#{node.rvm_redmine.path}/config/unicorn.config.rb" do
  source "unicorn.config.rb.erb"
  owner node.rvm_redmine.user
  group node.rvm_redmine.group
  mode "0644"
  notifies :restart, "service[redmine]"
end

service "redmine" do
  supports :restart => true, :start => true, :stop => true, :reload => true
  action :enable
end