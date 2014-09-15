
class YamlParams < HashParams

  def initialize(opts={})

    super({})

    specified_roots = opts.delete(:roots)
    app_name        = opts.delete(:app_name)
    separator       = opts.delete(:separator) || '_'
    extension       = opts.delete(:extension) || 'yml'
    filename        = opts.delete :file_name
    env             = opts.delete(:env) || opts.delete(:environment) || ENV['YAML_PARAMS_ENV'] || rails_env || 'development'

    roots = specified_roots ? Array(specified_roots) : default_roots(app_name)

    if filename
      #if they specified a specific file name only process that
      process_file(filename, env)
    else
      process_default_roots_and_files(roots, app_name, separator, extension, env)
    end

  end


  private

  def process_default_roots_and_files(roots, app_name, separator, extension, env)
    hostname        = Socket.gethostname
    base_file_names = [
        'settings',
        'default',
        "#{env}",
        "#{hostname}",
        "#{hostname}#{separator}#{env}",
        'local',
        "local#{separator}#{env}"
    ]

    roots.each do |root|
      base_file_names.each do |f|
        fname = "#{f}.#{extension}"
        deep_merge!(process_file(File.join(root, fname), env))
        deep_merge!(process_file(File.join(root, "#{app_name}#{separator}#{fname}"), env)) if app_name

      end
    end
  end

  def rails_config_path
    @rails_config_path ||= Rails.root.join('config') if defined?(rails)
  end

  def rails_env
    @rails_env ||= if defined?(Rails)
                     Rails.env
                   else
                     ENV['RAILS_ENV'] || ENV['RACK_ENV']
                   end
  end

  def default_roots(app_name)
    home_dir = File.expand_path('~')
    r        = [
        File.join('/etc', app_name.to_s),
        File.join('/usr', 'local', 'etc', app_name.to_s),
        File.join(home_dir, 'etc', app_name.to_s),
        File.join(home_dir, '.yaml_params', app_name.to_s),
        File.join(Dir.pwd, 'config'),
        File.join(Dir.pwd, 'settings')
    ]
    r << rails_config_path if rails_config_path
    r
  end

  def process_file(filename, env)
    r ={}
    if File.exists?(filename)
      r = YAML::load(ERB.new(File.read(filename)).result)
    end
    r[env] || r
  end

end

