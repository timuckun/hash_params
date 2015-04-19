module HashParams


  class HashValidator

    def validate_hash(h, options={})
      #Hash Validation has to be stateful

      @incoming = h
      @outgoing = {}
      @options  = options

      inject_into_target(@outgoing, :validation_errors, [])

      if block_given?
        instance_eval(&Proc.new)
      else
        #no proc was given. This means pass all values
        @outgoing = @incoming
        inject_into_target(@outgoing, :validation_errors, [])
      end
      inject_into_target(@outgoing, :valid?, @outgoing.validation_errors.empty?)
      @outgoing

    end

    def param(key, opts={})
      value     = @incoming[key]
      # if a block is given to the param then it's a recursive call
      # recursive calls can only be done with a hash
      new_value = if block_given? && value.is_a?(Hash)
                    HashParams::HashValidator.new.validate_hash(value, @options, &Proc.new)
                  else
                    HashParams::Validator.validate(value, opts)
                  end
      set_key_value key, new_value, opts[:as]
      new_value
    rescue => e
      @outgoing.validation_errors << "Error processing key '#{key}': #{e}" # [e.to_s, e.backtrace].join("\n")
      raise e if @options[:raise_errors]
      nil
    end

    def set_key_value(key, value, as=nil)
      key = as unless as.nil?
      key = key.to_s.to_sym if @options[:symbolize_keys]
      inject_into_target(@options[:injection_target], key, value) if @options[:injection_target]
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
  end
end
