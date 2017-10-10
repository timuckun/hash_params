module HashParams
  module Validator

    class ValidationError < StandardError
    end

    class CoercionError < StandardError
    end

    def with_binding(&code)
      BindingValidator.new.with_binding(&code)
    end

    def validate(param, type=nil, validations={})

      coercions = Array(validations[:coerce]) << type

      if param.nil? && validations[:default]
        param = validations[:default].respond_to?(:call) ? validations[:default].call() : validations[:default]
      end

      #if there is a :validate lambda run that too
      if validations[:validate] && validations[:validate].respond_to?(:call)
        param = validations.delete(:validate).call(param)
      end

      #don't bother with the rest if required parameter is missing
      if validations[:required] && param.nil?
        raise ValidationError.new('Required Parameter missing and has no default specified')
      end

      if block_given? && !param.is_a?(Hash)
        param = yield(param, validations)
      end

      #  do all coercion and transformation first there could be an array of coersions they will be run in order
      coercions.each do |c|
        param = coerce(param, c, validations)
      end

      if param.is_a?(Hash)
        param = if block_given?
                  HashParams::HashValidator.new.validate_hash(param, validations, &Proc.new)
                else
                  HashParams::HashValidator.new.validate_hash(param, validations)
                end
      end

      #don't bother with the rest if required parameter is missing
      if validations[:required] && param.nil?
        raise ValidationError.new('Required Parameter missing and has no default specified')
      end

      error = nil
      validations.each do |key, value|
        error = case key
                  when :blank
                    'Parameter cannot be blank' if !value && (param.nil? || (param.respond_to?(:empty) && param.empty)) #)!value && blank?(value)
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
      error = validations[:errmsg] || error
      raise ValidationError.new(error) if error
      param
    end

    private

    def coerce(val, type=nil, opts={})

      # exceptions bubble up
      #order is important

      #if type is nil just return the object
      return val if type.nil?

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
      return val.to_s.to_sym if type == Symbol
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
  end
end