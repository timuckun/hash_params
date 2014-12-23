module HashParams
  # def self.deep_merge(hash, other_hash)
  #   h={}
  #   other_hash.each_pair do |k, v|
  #     tv      = hash[k]
  #     h[k] = tv.is_a?(Hash) && v.is_a?(Hash) ? HashParams.deep_merge(v) : v
  #   end
  #   h
  # end
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

  def i_method
    puts 'instance method'
  end
  def self.c_method
    puts 'class method'
  end
end

