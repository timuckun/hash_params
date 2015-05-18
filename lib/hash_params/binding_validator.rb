module HashParams
  class BindingValidator

    def with_binding (&code)
      @binding = code.binding
      instance_eval(&code)
    end


    def var(var_name, type, opts={})
      raise 'Variable name must be a string or symbol' unless (var_name.is_a?(String) || var_name.is_a?(Symbol))
      value    = @binding.local_variable_get var_name
      new_value = if value.is_a?(Hash)
                    if block_given?
                      #if the param is a hash then the validations are actually options
                      HashParams::HashValidator.new.validate_hash(value, opts, &Proc.new)
                    else
                      HashParams::HashValidator.new.validate_hash(value, opts)
                    end
                  else
                    HashParams.validate value, type,  opts
                  end
      @binding.local_variable_set var_name, new_value
    end
  end
end
