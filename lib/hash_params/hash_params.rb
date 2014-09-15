

class HashParams < Delegator

  attr_accessor :errors, :contents

  def initialize(opts={}, injection_target = nil)
    @contents      = {}
    @incoming_hash = opts
    @errors        =[]
    if injection_target
      warn '[DEPRECATION] `injection_target` is deprecated. It will be removed from the next version of this gem'
    end
    @target = injection_target
    super(@incoming_hash)
    if block_given?
      warn '[DEPRECATION] Passing blocks into the constructor is deprecated. Please use validate or strictly validate in the future'
      strictly_validate(&Proc.new)
    end
  end

  def valid
    @errors.size == 0
  end

  alias_method :valid?, :valid

  def strictly_validate(&code)
    #reset the internal hash it will be filled with only the valid values
    @contents={}
    validate(&code)
    self
  end

  def validate(&code)
    instance_eval(&code)
    self
  end

  def __getobj__
    @contents || {}
  end

  def __setobj__(obj)
    @contents = obj
  end

  def deep_merge(other_hash)
    dup.deep_merge!(other_hash)
  end

  # Same as +deep_merge+, but modifies +self+.
  def deep_merge!(other_hash)
    other_hash.each_pair do |k, v|
      tv      = self[k]
      self[k] = tv.is_a?(Hash) && v.is_a?(Hash) ? tv.deep_merge(v) : v
    end
    self
  end

  private

  def param(key, h = {})

    #What happens if value is  FalseClass ?  Need something a little better
    val = @incoming_hash[key] || @incoming_hash[key.to_sym] || @incoming_hash[key.to_s]

    ok, error = validate!(val, h)
    if ok
      #The value is valid add it
      var_name = h[:as] ? h[:as] : key
      inject_into_target(@target, var_name, val)
    else
      @errors << "#{key} failed to validate: #{error}"
    end

    #after all that see if a block is given and process that
    if block_given? && val.is_a?(Hash)
      #Proc.new references the implict block
      ::Pry.send(:binding).pry
      val     = HashParams.new(val).strictly_validate(&Proc.new)
      @errors += val.errors
    end

    self[var_name]=val

    self

  rescue => e
    @errors << e.to_s
  end

  alias_method :key, :param

  def inject_into_target(target, var_name, val)
    warn '[DEPRECATION] inject_into_target will be removed in the next version'
    if target
      #for read write methods
      target.singleton_class.class_eval do
        attr_accessor var_name;
      end
      target.send("#{var_name}=", val)
    end
  end

  def validate!(param, options ={})
    #returns [bool, error]

    if param.nil? && options[:default]
      param = options[:default].respond_to?(:call) ? options[:default].call(self) : options[:default]
    end

    #don't bother with the rest if required parameter is missing
    if options[:required] && param.nil?
      return [false, 'Required Parameter missing and has no default specified']
    end
    #do all coercion and transformation first there could be an array of coersions they will be run in order

    Array(options[:coerce]).each do |c|
      param = coerce(param, c, options)
    end

    return [false, 'Failed Coersion'] if param.nil?

    is_valid = true
    error    =''

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
        #@errors << error
        is_valid = false
      end
    end

    #return true or false depending on if it validated
    [is_valid, error]
  end


  def coerce(val, type, h)

    # exceptions bubble up
    #order is important
    return val if type.nil? || val.nil?

    #two special types of transforms
    #There is no Boolean type so we handle them special
    if type.to_s == 'boolean'
      return val if (val == true || val == false)
      return false if  /(false|f|no|n|0)$/i === val.to_s.downcase
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
    return Hash[val.gsub(/[{}]/, '').gsub('}', '').split(h[:delimiter] || ',').map { |c| c.split(h[:separator] ||':').map { |i| i.strip } }] if type == Hash

    nil
  end


  def present?(object)
    !blank?(object)
  end

  def blank?(object)
    object.nil? || (object.respond_to?(:empty) && object.empty)
  end

end
