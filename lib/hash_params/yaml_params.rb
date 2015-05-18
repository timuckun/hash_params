module YamlParams

  ENVIRONMENT = ENV['YAML_PARAMS_ENV'] ||  (defined?(HashParams)  &&  HashParams::ENVIRONMENT) ||  'development'

  def self.autoconfig(opts={})

    script_name = File.basename($0)
    script_dir  = File.dirname($0)
    home_dir    = File.expand_path('~')
    host_name   = Socket.gethostname

    files     = opts.delete(:files)
    files     = Array(files && files.is_a?(String) && files.split(','))
    roots     = opts.delete(:roots)
    roots     = Array(roots && roots.is_a?(String) && roots.split(','))
    app_name  = opts.delete(:app_name) || script_name
    env       = opts.delete(:env) || opts.delete(:environment) || ENVIRONMENT

    #Sequence is important when constructing this list as later files will override the earlier ones
    all_files = %W(
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
    all_files += all_files.map { |f| "#{app_name}_#{f}" }
    all_files += files

    all_roots = [
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
      all_roots << Rails.root.join('config')
    end
    all_roots += roots
    h         = {}

    all_roots.each do |root|
      all_files.each do |fname|
        file = File.join(root, fname)
        h    = deep_merge(h, hash_from_yaml_file(file)) if File.exists?(file)
      end
    end

    if block_given?
      HashParams::HashValidator.new.validate_hash(h, opts, &Proc.new)
    else
      HashParams::HashValidator.new.validate_hash(h, opts)
    end
  end

  def self.hash_from_yaml_file(filename, env=ENVIRONMENT)
    r = File.exists?(filename) ? YAML::load(ERB.new(File.read(filename)).result) : {}
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