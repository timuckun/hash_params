module YamlParams

  ENVIRONMENT = ENV['YAML_PARAMS_ENV'] || (defined?(HashParams) && HashParams::ENVIRONMENT) || 'development'

  def self.autoconfig(opts={})

    script_name        = File.basename($0)
    script_dir         = File.dirname($0)
    home_dir           = File.expand_path('~')
    host_name          = Socket.gethostname
    special_file_names = opts.delete(:files)
    special_file_names = Array(special_file_names && special_file_names.is_a?(String) && special_file_names.split(','))
    special_roots      = opts.delete(:roots)
    special_roots      = Array(special_roots && special_roots.is_a?(String) && special_roots.split(','))
    app_name           = opts.delete(:app_name) || script_name
    env                = opts.delete(:env) || opts.delete(:environment) || ENVIRONMENT
    generated_hash     = {}
    all_file_names     = []


    #Sequence is important when constructing this list as later files will override the earlier ones
    generic_file_names = %W(
                  settings.yml
                  config.yml
                   default.yml
                  #{env}.yml
                  #{host_name}.yml
                  #{host_name}_#{env}.yml
                  local.yml
                  local_#{env}.yml
                  settings.local.yml
                  settings.local_#{env}.yml
                  config.local.yml
                  config.local_#{env}.yml
    )
    #prepend the app name to the default file names
    app_file_names     = generic_file_names.map { |f| "#{app_name}_#{f}" }

    default_roots = [
        script_dir,
        File.join('/etc', app_name.to_s),
        File.join('/usr', 'local', 'etc', app_name.to_s),
        File.join(home_dir, 'etc', app_name.to_s),
        File.join(home_dir, ".#{app_name}"),
        File.join(home_dir, '.hash_params', app_name.to_s),
        File.join(script_dir, 'config'),
        File.join(script_dir, 'settings')
    ]
    if defined?(Rails)
      default_roots << Rails.root.join('config')
      default_roots << Rails.root.join('config', env)
      default_roots << Rails.root.join('config', 'settings')
      default_roots << Rails.root.join('config', 'settings', env)
    end


    #process the  /etc/app_name* files
    app_file_names.each do |fname|
      all_file_names << File.join('/etc', fname)
    end
    #now process the default roots which will override the above
    (default_roots + special_roots).each do |root|
      (generic_file_names + app_file_names + special_file_names).each do |fname|
        all_file_names << File.join(root, fname)
      end
    end

    all_file_names.each do |file|
      generated_hash = deep_merge(generated_hash, hash_from_yaml_file(file)) if File.exists?(file)
    end

    if block_given?
      HashParams::HashValidator.new.validate_hash(generated_hash, opts, &Proc.new)
    else
      HashParams::HashValidator.new.validate_hash(generated_hash, opts)
    end
  end

  def self.hash_from_yaml_file(filename, env=nil)
    env ||= ENVIRONMENT
    r   = File.exists?(filename) ? YAML::load(ERB.new(File.read(filename)).result) : {}
    r[env] || r
  end

  def self.deep_merge(hash, other_hash)
    if other_hash.is_a?(::Hash) && hash.is_a?(::Hash)
      other_hash.each do |k, v|
        hash[k] = hash.key?(k) ? deep_merge(hash[k], v) : v
      end
      hash
    else
      other_hash
    end
  end

end