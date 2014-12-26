class HashParamsOriginal < Hash
  VERSION = '0.0.2'
  attr :valid, :errors

  def initialize(opts={}, injection_target =nil, &code)
    @incoming_hash   = opts
    @errors =[]
    # @parent                = code.binding.eval 'self'
    @target =injection_target
    instance_eval(&code)
    @valid = (@errors.size == 0)
  end

  def param(key, h = {})


    #What happens if value is  FalseClass ?  Need something a little better
    val = @incoming_hash[key] || @incoming_hash[key.to_sym] || @incoming_hash[key.to_s]
    if val.nil? && h[:default]
      val = h[:default].respond_to?(:call) ? h[:default].call(self) : h[:default]
    end


    #don't bother with the rest if required parameter is missing
    return @errors << "Parameter #{key} is required and missing" if h[:required] && val.nil?
    #do all coercion and transformation first there could be an array of coersions they will be run in order

    Array(h[:coerce]).each do |c|
      val = coerce(val, c, h)
    end

    #coersion could return a nil which won't validate, it could return a false which will attempt to validate
    if  validate!(val, h)
      #The value is valid add it
      var_name      = h[:as] ? h[:as] : key
      self[var_name]=val
      inject_into_target(@target, var_name, val)
    end
    binding.pry if key == :recursive   || key ==  :wasnt_here_before
    #after all that see if a block is given and process that
    if block_given? && val.is_a?(Hash)
      #Proc.new references the implict block
      val = HashParams.new(val, nil, &Proc.new)
      self[var_name]=val
    end

    binding.pry if key == :recursive   || key ==  :wasnt_here_before
    val
  rescue => e
    @errors << e.to_s
  end

  def inject_into_target(target, var_name, val)
    if target
      #for read write methods
      target.singleton_class.class_eval do
        attr_accessor var_name;
      end
      target.send("#{var_name}=", val)
    end
  end

  def validate!(param, options ={})
    return false if param.nil?
    is_valid = true

    options.each do |key, value|

      error = case key
                when :validate
                  "#{param.to_s} failed validation using proc" if  value.respond_to?(:call) && !value.call(param)
                when :blank
                  'Parameter cannot be blank' if !value && blank?(param)
                when :format
                  'Parameter must be a string if using the format validation' && next unless param.kind_of?(String)
                  "Parameter must match format #{value}" unless param =~ value
                when :is
                  "Parameter must be #{value}" unless param === value
                when :in, :within, :range
                  "Parameter must be within #{value}" unless value.respond_to?(:include) ? value.include?(param) : Array(value).include?(param)
                when :min
                  "Parameter cannot be less than #{value}" unless  value <= param
                when :max
                  "Parameter cannot be greater than #{value}" unless  value >= param
                when :min_length
                  "Parameter cannot have length less than #{value}" unless  value <= param.length
                when :max_length
                  "Parameter cannot have length greater than #{value}" unless  value >= param.length
                else
                  nil
              end
      if error
        @errors << error
        is_valid = false
      end
    end

    #return true or false depending on if it validated
    is_valid
  end


  def coerce(val, type, h)

    # exceptions bubble up
    #order is important
    return val if type.nil? || val.nil?

    #two special types of transforms
    #There is no Boolean type so we handle them special
    if type == :boolean || type =='boolean'
      return val if (val == true || val == false)
      return false if   /(false|f|no|n|0)$/i === val.to_s.downcase
      return true if  /(true|t|yes|y|1)$/i === val.to_s.downcase

      # if we can't parse we return a nil
      # maybe !!val is a better return?
      return nil
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
    return Array(val.split(h[:delimiter] || ',')) if type == Array
    return Hash[val.gsub(/[{}]/,'').gsub('}','').split(h[:delimiter] || ',').map { |c| c.split(h[:separator] ||':').map{|i| i.strip} }] if type == Hash

    nil
  end

  def valid?
    @valid
  end
  def present?(object)
    !blank?(object)
  end

  def blank?(object)
    return true if object.nil?
    return true if object.respond_to?(:empty) && object.empty
    return false
  end
end
