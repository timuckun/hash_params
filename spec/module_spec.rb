require 'pry'
module M1
  def im
    puts 'm1 im'
  end
end

module M2
  def self.cm
    puts 'm2 cm'
  end
end


module T1
  include M1
end
module T2
  extend M1
end
module T3
  include M2
end
module T4
  extend M2
end

binding.pry
puts 'done'