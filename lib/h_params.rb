require 'yaml'
require 'erb'
require 'socket'
#require 'delegate'
require 'pry'


class HParams

  ENVIRONMENT = ENV['HASH_PARAMS_ENV'] || (defined?(Rails) && Rails.env) || ENV['RAILS_ENV'] || ENV['RACK_ENV'] || 'development'
  VERSION     = '2.0.0'

  class ValidationError < StandardError
  end
  class CoercionError < StandardError
  end

  def self.validate_hash(incoming_hash, opts={})

  end

  def self.validate_hash_old(incoming_hash, validations={}, opts={})
    #default is to raise errors
    raise_errors = opts[:raise_errors].nil? ? true : opts[:raise_errors]

    #default is strict but if they don't specify strict and the validations are empty then it's false
    strict       = if opts[:strict]
                     opts[:strict]
                   elsif validations.empty?
                     false
                   else
                     true
                   end

    clean_hash  = {}
    errors_hash = {}


    validations.each do |hash_key, validation|
      begin
        value        = incoming_hash[hash_key]
        new_hash_key = opts[:symbolize_key] ? hash_key.to_s.to_sym : hash_key
        value        = if value.is_a?(Hash)
                         validate_hash(value, validation, opts)
                       else
                         validate(value, validation)
                       end

        clean_hash[new_hash_key] = value
      rescue => e
        errors_hash[new_hash_key]= e.to_s
      end
    end
    valid       = errors_hash.empty?
    return_hash = if strict
                    clean_hash
                  else
                    incoming_hash.merge(clean_hash)
                  end
    raise "Validation errors: #{errors_hash.inspect}" if raise_errors && !valid
    inject_into_target return_hash, :valid?, valid
    inject_into_target return_hash, :errors, errors_hash
    if opts[:make_methods]
      return_hash.each do |k, v|
        inject_into_target(return_hash, k, v)
      end
    end
    return_hash
  end


  def self.strictly_validate_hash(incoming_hash, validations={}, opts={})
    opts[:strict] = true
    validate_hash(incoming_hash, validations, opts)
  end

  def self.validate(param, validations={}, options={})
    #NOTE  if validations is nil then it gets coerced into an empty hash
    #      The consequence of this is that the value gets passed back unchanged

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

  def self.coerce(val, type, opts={})

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

  class << self
    alias_method :autoconfigure, :validate_default_yaml_files
    alias_method :param, :validate
  end

  private

  def self.present?(object)
    !blank?(object)
  end

  def self.blank?(object)
    object.nil? || (object.respond_to?(:empty) && object.empty)
  end

  def self.hash_from_yaml_file(filename, env=ENVIRONMENT)
    r = File.exists?(filename) ? YAML::load(ERB.new(File.read(filename)).result) : {}
    r[env] || r
  end


  def self.hash_from_default_yaml_files(app_name=nil, env=nil, roots=nil, file_separator=nil, file_extension=nil)
    #if a nil is passed in we still use the defaults
    app_name       ||= ''
    env            ||= ENVIRONMENT
    roots          ||= nil
    file_separator ||= '_'
    file_extension ||= 'yml'

    h        = {}
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
        settings.local.#{file_extension}
        settings.local#{file_separator}#{env}.#{file_extension}
        config.local.#{file_extension}
        config.local#{file_separator}#{env}.#{file_extension}
    #{app_name}#{file_separator}settings.#{file_extension}
    #{app_name}#{file_separator}config.#{file_extension}
    #{app_name}#{file_separator}default.#{file_extension}
    #{app_name}#{file_separator}#{env}.#{file_extension}
    #{app_name}#{file_separator}#{hostname}.#{file_extension}
    #{app_name}#{file_separator}#{hostname}#{file_separator}#{env}.#{file_extension}
    #{app_name}#{file_separator}local.#{file_extension}
    #{app_name}#{file_separator}local#{file_separator}#{env}.#{file_extension}
    #{app_name}#{file_separator}settings.local.#{file_extension}
    #{app_name}#{file_separator}settings.local#{file_separator}#{env}.#{file_extension}
    #{app_name}#{file_separator}config.local.#{file_extension}
    #{app_name}#{file_separator}config.local#{file_separator}#{env}.#{file_extension}

    )

    all_roots       = Array(roots) if roots
    all_roots       ||= [
        Dir.pwd,
        File.join('/etc', app_name.to_s),
        File.join('/usr', 'local', 'etc', app_name.to_s),
        File.join(home_dir, 'etc', app_name.to_s),
        File.join(home_dir, '.hash_params', app_name.to_s),
        File.join(Dir.pwd, 'config'),
        File.join(Dir.pwd, 'settings')
    ]
    if defined?(Rails)
      all_roots << Rails.root.join('config')
    end

    all_roots.each do |root|
      base_file_names.each do |fname|
        file = File.join(root, fname)
        h    = deep_merge(h, hash_from_yaml_file(file)) if File.exists?(file)
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


  def self.inject_into_target(target, var_name, val)
    #only do read
    target.singleton_class.module_eval do
      define_method var_name.to_s.to_sym do
        val
      end
    end

    # if target
    #   #for read write methods
    #   target.singleton_class.class_eval do
    #     attr_accessor var_name;
    #   end
    #   target.send("#{var_name}=", val)
    # end
  end
end







