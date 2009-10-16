class Fixnum
  # Fixnum is identically  Smalltalk SmallInteger

  MAX = 0xfffffffffffffff

  def self.induced_from(obj)
    i = Type.coerce_to(obj, Integer, :to_int)
    unless i._isFixnum
      raise RangeError, 'Object is out of range for a Fixnum' 
    end
    i
  end

  #  The 3 selectors  + - *   should be emitted as special sends and don't need
  #  methods installed. They will fall back to Bignum (to implementations in
  #  Smalltalk Integer) if the special send fails.

  # The selectors 
  #    + - * >= <= < &  
  #  are special sends and may not be reimplemented in Fixnum.

  primitive_nobridge '_isSpecial', 'isSpecial'

  primitive '<',  '_rubyLt:'
  primitive '<=', '_rubyLteq:'
  primitive '>' , '_rubyGt:'
  primitive '>=', '_rubyGteq:'
  primitive '==', '_rubyEqual:'

  primitive '===', '_rubyEqual:'  #  === same as == for Fixnum

  #  /    # note division does not produce Fractions in Ruby
  #         until math.n is required, then may produce Rationals ...
  primitive_nobridge '/', '_rubyDivide:'
  primitive_nobridge '_divide', '_rubyDivide:'

  primitive_nobridge '_quo_rem', 'quoRem:into:' # Smalltalk coercion on arg, used by BigDecimal

  primitive_nobridge '%', '_rubyModulo:'
  primitive_nobridge 'modulo', '_rubyModulo:'

  primitive_nobridge '_raised_to' , '_rubyRaisedTo:'
  def **(arg)
    if arg._isNumeric
      if (arg <=> 0) < 0
        r = self.to_f
        return r ** arg
      end
    end
    self._raised_to(arg)
  end

  # unaries  +@  -@  eliminated during IR generation by compiler

  #  ~ inherited from Integer
  primitive_nobridge '&', '_rubyBitAnd:'
  primitive_nobridge '|', '_rubyBitOr:'
  primitive_nobridge '^', '_rubyBitXor:'
  primitive_nobridge '<<', '_rubyShiftLeft:'
  # >> inherited from Integer

  def <=>(arg)
    # reimplemented to reduce use of polymorphic send caches
    if arg._isNumeric
      if self > arg
        1 
      elsif self == arg
        0 
      else
        -1 
      end
    else
      nil
    end
  end

  primitive_nobridge '_bit_at', 'bitAt:'

  # abs inherited from Integer

  primitive 'id2name', '_ruby_id2name'

  # quo inherited from Integer
  primitive 'size', '_rubySize'
  primitive 'to_f', 'asFloat'

  # to_s inherited from Integer

  primitive 'to_sym', '_rubyToSym'

  def zero?  
    self.equal?(0)
  end

  def nonzero?
    if self.equal?(0)
      nil
    else
      self
    end
  end

end
Fixnum._freeze_constants
