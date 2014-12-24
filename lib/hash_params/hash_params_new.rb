class HashParamsNew

  ENVIRONMENT = ENV['HASH_PARAMS_ENV'] || (defined?(Rails) && Rails.env) || ENV['RAILS_ENV'] || ENV['RACK_ENV'] || 'development'

  extend HashParamsValidator
  attr_accessor :errors, :contents, :invalid_data, :valid_data

  def initialize(incoming_hash={}, opts={})

    @opts           =opts
    @symbolize_keys = opts.delete :symbolize_keys
    @make_methods   = opts.delete :make_methods
    @contents       = @incoming_hash = incoming_hash
    set_content :hash_params_errors, {}
    set_content :hash_params_invalid_data, {}

    @target = @opts.delete :injection_target
    if @target
      warn '[DEPRECATION] `injection_target` is deprecated. It will be removed from the next version of this gem'
    end
    # ::Pry.send(:binding).pry
    if block_given?
      warn '[DEPRECATION] Passing blocks into the constructor is deprecated. Please use validate or strictly validate in the future'
      sift(&Proc.new)
    end
  end

  def to_hash
    @contents
  end

  def valid?
    @contents[:hash_params_errors].size == 0
  end

  def sift(&code)
    #reset the internal hash it will be filled with only the valid values
    @contents={}
    set_content :hash_params_errors, {}
    set_content :hash_params_invalid_data, {}

    validate(&code)
    @contents
  end

  def set_content(key, value)
    key = key.to_s.to_sym if @symbolize_keys
    inject_into_target(@contents, key, value) if @make_methods
    inject_into_target(@target, key, value) if @target
    @contents[key]=value
  end

  def validate_params(&code)
    instance_eval(&code)
    self
  end

  #these are convience methods
  def from_yaml_file(filename, env=ENVIRONMENT)
    initialize(HashParamsNew.from_yaml_file(filename, env))
  end

  def autoconfigure
    initialize(HashParamsNew.autoconfigure((app_name='', env=ENVIRONMENT, roots=nil, file_separator='_', file_extension='yml')))
  end

  def self.from_yaml_file(filename, env=ENVIRONMENT)
    r = File.exists?(filename) ? YAML::load(ERB.new(File.read(filename)).result) : {}
    r[env] || r
  end

  def self.autoconfigure(app_name='', env=ENVIRONMENT, roots=nil, file_separator='_', file_extension='yml')
    h        ={}
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
        h = HashParamsNew::deep_merge(h, from_yaml_file(File.join(root, fname)))
      end
    end
    h
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


  # # Same as +deep_merge+, but modifies +self+.
  # def self.deep_merge!(other_hash)
  #   other_hash.each_pair do |k, v|
  #     self[k] = self[k].is_a?(Hash) && v.is_a?(Hash) ? self[k].deep_merge(v) : v
  #   end
  #   self
  # end
  #
  # def deep_merge(other_hash)
  #   dup.deep_merge!(other_hash)
  # end
  #
  private


  # def __getobj__
  #   @contents || {}
  # end
  #
  # def __setobj__(obj)
  #   @contents = obj
  # end


  def param(key, h = {})

    #What happens if value is  FalseClass ?  Need something a little better
    val = @incoming_hash[key] || @incoming_hash[key.to_sym] || @incoming_hash[key.to_s]

    begin
      #validate raises errors we don't want to catch them
      val = HashParamsNew.validate(val, h)
      var_name = h[:as] ? h[:as] : key
      set_content var_name, val
    rescue => e
      @contents[:hash_params_errors].merge!({key: e.to_s})
    end
    ok, error = validate_value(val, h)
    if ok
      #The value is valid add it

    else
      @errors[key] = "#{val} failed to validate: #{error}"
    end

    #after all that see if a block is given and process that
    if block_given? && val.is_a?(Hash)
      #Proc.new references the implict block
      val = HashParamsNew.new(val).sift(&Proc.new)
      @errors.merge!(val.errors)
    end

    set_content var_name, val

    self

  rescue => e
    @errors[:system_error] = e.to_s
  end

  alias_method :key, :param

  def inject_into_target(target, var_name, val)
    #warn '[DEPRECATION] inject_into_target will be removed in the next version'
    if target
      #for read write methods
      target.singleton_class.class_eval do
        attr_accessor var_name;
      end
      target.send("#{var_name}=", val)
    end
  end

  def validate_value(param, options ={})
    #returns [bool, error]
    [true, HashParamsNew.validate(param, options)]
  rescue => e
    [false, e]
  end

end
