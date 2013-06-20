def load_current_resource
  %w(init_type user group).each do |key|
    new_resource.send(key, node[:beaver][key]) unless new_resource.send(key)
  end
  
  case new_resource.files
  when String
    new_resource.files [Mash.new(:path => new_resource.files)]
  when Array
    processed = new_resource.files.map do |elm|
      case elm
      when String
        {:path => elm}
      when Hash
        Mash.new(elm)
      else
        elm
      end
    end
    new_resource.files processed
  end
end

action :create do

  run_context.include_recipe 'beaver'

  # Build out our paths
  
  basedir = ::File.join(new_resource.base_dir, new_resource.name)
  conf_file = ::File.join(basedir, 'etc/beaver.conf')
  log_file = ::File.join(new_resource.log_dir, "beaver_#{new_resource.name}.log")
  pid_file = ::File.join(new_resource.pid_dir, "beaver_#{new_resource.name}.pid")

  # Cache our attributes so we can easily pass them through
  
  new_args = Mash.new.tap do |mash|
    %w(user group output files).each do |key|
      mash[key] = new_resource.send(key)
    end
  end

  # Ensure user/group exists

  if(new_resource.manage_user)
    group new_resource.group
    user new_resource.user do
      group new_resource.group
      shell '/bin/false'
      home basedir
      comment "Beaver user - #{new_resource.name}"
    end
  end

  # Ensure all directories exist
  
  [conf_file, pid_file, log_file].each do |leaf|
    directory ::File.dirname(leaf) do
      recursive true
      owner new_resource.user
      group new_resource.group
    end
  end
  
  template conf_file do
    cookbook 'beaver'
    source 'beaver.conf.erb'
    mode 0640
    owner new_resource.user
    group new_resource.group
    variables(
      :conf => new_resource.output.values.first,
      :files => new_resource.files
    )
    notifies :restart, "service[beaver_#{new_resource.name}]"
  end

  cmd = "beaver -t #{new_resource.output.keys.first} -c #{conf_file}"

  case new_resource.init_type
  when 'upstart'
    template "/etc/init/beaver-#{new_resource.name}.conf" do
      mode "0644"
      cookbook 'beaver'
      source "upstart.conf.erb"
      variables(
        :cmd => cmd,
        :name => new_resource.name,
        :group => new_resource.group,
        :user => new_resource.user,
        :basedir => basedir,
        :log => log_file
      )
      notifies :restart, "service[beaver_#{new_resource.name}]"
    end

    custom_provider = Chef::Provider::Service::Upstart
    custom_service_name = "beaver-#{new_resource.name}"
  when 'runit'
    run_context.include_recipe 'runit'
    
    runit_service "beaver-#{new_resource.name}" do
      default_logger true
      run_template_name 'beaver'
      cookbook 'beaver'
      options(
        :cmd => cmd,
        :group => new_resource.group,
        :user => new_resource.user
      )
    end
    custom_service_name = "beaver-#{new_resource.name}"
  else
    template "/etc/init.d/beaver_#{new_resource.name}" do
      cookbook 'beaver'
      mode 0755
      source 'initd.erb'
      variables(
        :name => new_resource.name,
        :cmd => cmd,
        :pid_file => pid_file,
        :user => new_resource.user,
        :log => log_file
      )
      notifies :restart, "service[beaver_#{new_resource.name}]"
    end
  end

  service_resource = service "beaver_#{new_resource.name}" do
    if(custom_service_name)
      service_name custom_service_name
    end
    if(custom_provider)
      provider custom_provider
    end
    supports :restart => false, :reload => false, :status => true
    action [:enable, :start]
  end

  logrotate_app "beaver_#{new_resource.name}" do
    cookbook 'logrotate'
    path log_file
    frequency 'daily'
    postrotate "invoke-rc.d #{service_resource.service_name} force-reload >/dev/null 2>&1 || true"
    options %w(missingok notifempty)
    rotate 30
    create "0440 #{new_args[:user]} #{new_args[:group]}"
  end
end
