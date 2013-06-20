default[:beaver][:pip_package] = 'beaver==22'
default[:beaver][:server_ipaddress] = nil
default[:beaver][:inputs] = []
default[:beaver][:outputs] = []
default[:beaver][:format] = "json"
default[:beaver][:user] = 'beaver'
default[:beaver][:group] = 'beaver'
default[:beaver][:init_type] = node[:platform] == 'ubuntu' ? 'upstart' : 'runit'
default[:beaver][:supports_setuid] = true
