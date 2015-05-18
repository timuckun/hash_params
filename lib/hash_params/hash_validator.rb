module HashParams


  class HPHash < Hash
    attr_accessor :validation_errors

    def initialize(args=nil)
      @validation_errors=[]
      super(args)
    end

    def valid?
      @validation_errors.empty?
    end

    def set_key_value(key, value, symbolize_key, make_method)
      key = key.to_s.to_sym if symbolize_key
      if make_method
        singleton_class.module_eval do
          define_method key.to_s.to_sym do
            value
          end
        end
      end
      self[key]=value
    end
  end

  class HashValidator

    def validate_hash(h, options={})
      #Hash Validation has to be stateful

      @incoming = h
      @outgoing = HPHash.new
      @options  = options

      if block_given?
        instance_eval(&Proc.new)
      else
        #no proc was given this means just pass the hash back as is
        @outgoing = @incoming
      end
      @outgoing
    end

    def key(hash_key, type, opts={})
      value     = @incoming[hash_key] || @incoming[hash_key.to_s]
      # if a block is given to the param then it's a recursive call
      # recursive calls can only be done with a hash
      new_value = if value.is_a?(Hash)
                    if block_given?
                      #if the param is a hash then the validations are actually options
                      HashParams::HashValidator.new.validate_hash(value, @options, &Proc.new)
                    else
                      HashParams::HashValidator.new.validate_hash(value, opts)
                    end
                  else
                    HashParams.validate value, type, opts
                  end
      hash_key  = opts[:as] if opts[:as]
      @outgoing.set_key_value(hash_key, new_value, @options[:symbolize_keys], @options[:make_methods])
      new_value
    rescue => e
      @outgoing.validation_errors << "Error processing key '#{hash_key}': #{e}" # [e.to_s, e.backtrace].join("\n")
      raise e if @options[:raise_errors]
      nil
    end
    alias_method :param, :key
  end
end
