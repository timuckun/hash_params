require 'yaml'
require 'erb'
require 'socket'
#require 'delegate'
require 'pry'
require 'ostruct'


class HashParams

  ENVIRONMENT = ENV['HASH_PARAMS_ENV'] || (defined?(Rails) && Rails.env) || ENV['RAILS_ENV'] || ENV['RACK_ENV'] || 'development'
  VERSION     = '2.0.0'

  class ValidationError < StandardError
  end
  class CoercionError < StandardError
  end

  def validate_hash(h, options={})
    #Hash Validation has to be stateful

    @incoming = h
    @outgoing = OpenStruct.new
    @options  = options

    @outgoing.validation_errors = OpenStruct.new
    if block_given?
      instance_eval(&Proc.new)
    else
      #no proc was given. This means pass all values
      @outgoing = @incoming
    end

    @outgoing['valid?'] = @outgoing.validation_errors.to_h.empty?
    @outgoing
    #default is to raise errors
    #   raise_errors = opts[:raise_errors].nil? ? true : opts[:raise_errors]
    #
    #   #default is strict but if they don't specify strict and the validations are empty then it's false
    #   strict       = if opts[:strict]
    #                    opts[:strict]
    #                  elsif validations.empty?
    #                    false
    #                  else
    #                    true
    #                  end
    #
    #   clean_hash  = {}
    #   errors_hash = {}
    #

  end

  def param(key, opts={})
    begin
      value   = HashParams.validate(@incoming[key], opts)
      new_key = opts[:as] || key
      set_key_value new_key, value, opts[:as]
        binding.pry
    rescue => e
      @outgoing.validation_errors[key] = [e.to_s, e.backtrace].join("\n")
      raise e if @options[:raise_errors]
    end
  end

  def set_key_value(key, value, as=nil)
    key = as unless as.nil?
    #key = key.to_s.to_sym if opts[:symbolize_keys]
    inject_into_target(opts[:injection_target], key, value) if opts[:injection_target]
    #inject_into_target(target, key, value) if opts[:make_methods]
    @outgoing[key]=value
  end


  def inject_into_target(target, var_name, val)
    #only do read
    target.singleton_class.module_eval do
      define_method var_name.to_s.to_sym do
        val
      end
    end
  end

  ##### CLass methods
  class << self

    def validate(param, validations={})
      #NOTE  if validations is nil then it gets coerced into an empty hash
      #      The consequence of this is that the value gets passed back unchanged

      if param.is_a?(Hash) && block_given?
        #if the param is a hash then the validations are actually options
       # binding.pry
        return HashParams.new.validate_hash(param, validations, &Proc.new)
      end
      if param.nil? && validations[:default]
        param = validations[:default].respond_to?(:call) ? validations[:default].call(self) : validations[:default]
      end

      if block_given?
        return param if yield(param, validations)
        #if the block didn't return a true value raise the error
        raise ValidationError.new("Unable to validate #{param} with given block")
      end

      #don't bother with the rest if required parameter is missing
      if validations[:required] && param.nil?
        raise ValidationError.new('Required Parameter missing and has no default specified')
      end
      #do all coercion and transformation first there could be an array of coersions they will be run in order

      Array(validations[:coerce]).each do |c|
        param = coerce(param, c, validations)
      end
      error = nil
      validations.each do |key, value|

        error = case key
                  when :validate
                    "#{param.to_s} failed validation using proc" if value.respond_to?(:call) && !value.call(param)
                  when :blank
                    'Parameter cannot be blank' if !value && blank?(param)
                  when :format
                    "#{param} must be a string if using the format validation" && next unless param.kind_of?(String)
                    "#{param} must match format #{value}" unless param =~ value
                  when :is
                    "#{param} must be #{value}" unless param === value
                  when :in, :within, :range
                    "#{param} must be within #{value}" unless value.respond_to?(:include) ? value.include?(param) : Array(value).include?(param)
                  when :min
                    "#{param} cannot be less than #{value}" unless value <= param
                  when :max
                    "#{param} cannot be greater than #{value}" unless value >= param
                  when :min_length
                    "#{param} cannot have length less than #{value}" unless value <= param.length
                  when :max_length
                    "#{param} cannot have length greater than #{value}" unless value >= param.length
                  else
                    nil
                end

      end
      raise ValidationError.new(error) if error
      param
    end

    def coerce(val, type, opts={})

      # exceptions bubble up
      #order is important

      #why would anyone want to coerce to nil? If they want il they get nil
      return nil if type.nil?

      #return val if type.nil? || val.nil?

      #two special types of transforms
      #There is no Boolean type so we handle them special
      if type.to_s == 'boolean'
        return val if (val == true || val == false)
        return false if /(false|f|no|n|0)$/i === val.to_s.downcase
        return true if /(true|t|yes|y|1)$/i === val.to_s.downcase

        # if we can't parse we return a nil
        # maybe !!val is a better return?
        raise CoercionError.new("Unable to coerce #{val} to boolean")
      end
      #they have given us a coercion which is a string or symbol which is not "boolean", we are going to cast this into a proc and run it

      return type.to_proc.call(val) if type.is_a?(Symbol) || type.is_a?(String)
      #could be a proc

      return type.call(val) if type.respond_to?(:call)
      #nothing but simple types left
      return val if val.is_a?(type)
      return Integer(val) if type == Integer
      return Float(val) if type == Float
      return String(val) if type == String
      return Date.parse(val) if type == Date
      return Time.parse(val) if type == Time
      return DateTime.parse(val) if type == DateTime
      return Array(val.split(opts[:delimiter] || ',')) if type == Array
      return Hash[val.gsub(/[{}]/, '').gsub('}', '').split(opts[:delimiter] || ',').map { |c| c.split(opts[:separator] ||':').map { |i| i.strip } }] if type == Hash

      raise CoercionError("Unable to  coerce #{val} to #{type}")
    end


    # alias_method :autoconfigure, :validate_default_yaml_files
    # alias_method :param, :validate


    def present?(object)
      !blank?(object)
    end

    def blank?(object)
      object.nil? || (object.respond_to?(:empty) && object.empty)
    end

    # def hash_from_yaml_file(filename, env=ENVIRONMENT)
    #   r = File.exists?(filename) ? YAML::load(ERB.new(File.read(filename)).result) : {}
    #   r[env] || r
    # end


    # def hash_from_default_yaml_files(app_name=nil, env=nil, roots=nil, file_separator=nil, file_extension=nil)
    #   #if a nil is passed in we still use the defaults
    #   app_name       ||= ''
    #   env            ||= ENVIRONMENT
    #   roots          ||= nil
    #   file_separator ||= '_'
    #   file_extension ||= 'yml'
    #
    #   h        = {}
    #   home_dir = File.expand_path('~')
    #   hostname = Socket.gethostname
    #
    #   base_file_names = %W(
    #     settings.#{file_extension}
    #     default.#{file_extension}
    #   #{env}.#{file_extension}
    #   #{hostname}.#{file_extension}
    #   #{hostname}#{file_separator}#{env}.#{file_extension}
    #     local.#{file_extension}
    #     local#{file_separator}#{env}.#{file_extension}
    #     settings.local.#{file_extension}
    #     settings.local#{file_separator}#{env}.#{file_extension}
    #     config.local.#{file_extension}
    #     config.local#{file_separator}#{env}.#{file_extension}
    #   #{app_name}#{file_separator}settings.#{file_extension}
    #   #{app_name}#{file_separator}config.#{file_extension}
    #   #{app_name}#{file_separator}default.#{file_extension}
    #   #{app_name}#{file_separator}#{env}.#{file_extension}
    #   #{app_name}#{file_separator}#{hostname}.#{file_extension}
    #   #{app_name}#{file_separator}#{hostname}#{file_separator}#{env}.#{file_extension}
    #   #{app_name}#{file_separator}local.#{file_extension}
    #   #{app_name}#{file_separator}local#{file_separator}#{env}.#{file_extension}
    #   #{app_name}#{file_separator}settings.local.#{file_extension}
    #   #{app_name}#{file_separator}settings.local#{file_separator}#{env}.#{file_extension}
    #   #{app_name}#{file_separator}config.local.#{file_extension}
    #   #{app_name}#{file_separator}config.local#{file_separator}#{env}.#{file_extension}
    #
    #   )
    #
    #   all_roots       = Array(roots) if roots
    #   all_roots       ||= [
    #       Dir.pwd,
    #       File.join('/etc', app_name.to_s),
    #       File.join('/usr', 'local', 'etc', app_name.to_s),
    #       File.join(home_dir, 'etc', app_name.to_s),
    #       File.join(home_dir, '.hash_params', app_name.to_s),
    #       File.join(Dir.pwd, 'config'),
    #       File.join(Dir.pwd, 'settings')
    #   ]
    #   if defined?(Rails)
    #     all_roots << Rails.root.join('config')
    #   end
    #
    #   all_roots.each do |root|
    #     base_file_names.each do |fname|
    #       file = File.join(root, fname)
    #       h    = deep_merge(h, hash_from_yaml_file(file)) if File.exists?(file)
    #     end
    #   end
    #   h
    # end


    def deep_merge(hash, other_hash)
      if other_hash.is_a?(::Hash) && hash.is_a?(::Hash)
        other_hash.each do |k, v|
          hash[k] = hash.key?(k) ? deep_merge(hash[k], v) : v
        end
        hash
      else
        other_hash
      end
    end


    # if target
    #   #for read write methods
    #   target.singleton_class.class_eval do
    #     attr_accessor var_name;
    #   end
    #   target.send("#{var_name}=", val)
    # end
    #end
  end # class << self

end







