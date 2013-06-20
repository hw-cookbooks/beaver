include_recipe 'python'
include_recipe 'logrotate'
include_recipe 'git'

python_pip node[:beaver][:pip_package] do
  action :install
end
