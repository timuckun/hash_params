class YamlParams

  ENVIRONMENT = ENV['HASH_PARAMS_ENV'] || (defined?(Rails) && Rails.env) || ENV['RAILS_ENV'] || ENV['RACK_ENV'] || 'development'

  def initialize(file_name = nil)
    if file_name
      YamlParams.from_yaml_file file_name
    else
      YamlParams.autoconfigure
    end
  end

  def self.from_yaml_file(filename, env=ENVIRONMENT)
    r = File.exists?(filename) ? YAML::load(ERB.new(File.read(filename)).result) : {}
    r[env] || r
  end

  def self.autoconfigure(app_name='', env=ENVIRONMENT, roots=nil, file_separator='_', file_extension='yml')
    h={}
    home_dir = File.expand_path('~')
    hostname = Socket.gethostname

    base_file_names = %W(
        settings.#{file_extension}
        default.#{file_extension}
    #{env}.#{file_extension}
    #{hostname}.#{file_extension}
    #{hostname}#{file_separator}#{env}.#{file_extension}
        local.#{file_extension}
        local#{file_separator}#{env}.#{file_extension}
    #{app_name}#{file_separator}settings.#{file_extension}
    #{app_name}#{file_separator}default.#{file_extension}
    #{app_name}#{file_separator}#{env}.#{file_extension}
    #{app_name}#{file_separator}#{hostname}.#{file_extension}
    #{app_name}#{file_separator}#{hostname}#{file_separator}#{env}.#{file_extension}
    #{app_name}#{file_separator}local.#{file_extension}
    #{app_name}#{file_separator}local#{file_separator}#{env}.#{file_extension}

    )

    all_roots       = Array(roots) if roots
    all_roots       ||= [
        File.join('/etc', app_name.to_s),
        File.join('/usr', 'local', 'etc', app_name.to_s),
        File.join(home_dir, 'etc', app_name.to_s),
        File.join(home_dir, '.yaml_params', app_name.to_s),
        File.join(Dir.pwd, 'config'),
        File.join(Dir.pwd, 'settings')
    ]
    if defined?(Rails)
      all_roots << Rails.root.join('config')
    end

    all_roots.each do |root|
      base_file_names.each do |fname|
        deep_merge!(load_from_file(File.join(root, fname)))
      end
    end
    h
  end



end

