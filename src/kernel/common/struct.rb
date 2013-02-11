# depends on: class.rb enumerable.rb hash.rb

class Struct

#  include Enumerable

  class << self
    alias_method :subclass_new, :new
  end

  ##
  # call-seq:
  #   Struct.new( [aString] [, aSym]+> )    => StructClass
  #   StructClass.new(arg, ...)             => obj
  #   StructClass[arg, ...]                 => obj
  #
  # Creates a new class, named by <em>aString</em>, containing accessor
  # methods for the given symbols. If the name <em>aString</em> is omitted,
  # an anonymous structure class will be created. Otherwise, the name of
  # this struct will appear as a constant in class <tt>Struct</tt>, so it
  # must be unique for all <tt>Struct</tt>s in the system and should start
  # with a capital letter. Assigning a structure class to a constant
  # effectively gives the class the name of the constant.
  #
  # <tt>Struct::new</tt> returns a new <tt>Class</tt> object, which can then
  # be used to create specific instances of the new structure. The number of
  # actual parameters must be less than or equal to the number of attributes
  # defined for this class; unset parameters default to \nil{}. Passing too
  # many parameters will raise an \E{ArgumentError}.
  #
  # The remaining methods listed in this section (class and instance) are
  # defined for this generated class.
  #
  #    # Create a structure with a name in Struct
  #    Struct.new("Customer", :name, :address)    #=> Struct::Customer
  #    Struct::Customer.new("Dave", "123 Main")   #=> #<Struct::Customer
  # name="Dave", address="123 Main">
  #    # Create a structure named by its constant
  #    Customer = Struct.new(:name, :address)     #=> Customer
  #    Customer.new("Dave", "123 Main")           #=> #<Customer
  # name="Dave", address="123 Main">

  def self.new(klass_name, *attrs_arg, &block)

    unless klass_name._equal?(nil) then
      # GEMSTONE
      #
      # We don't want to throw an exception just to distinguish
      # between a string and a symbol...
      # begin
      #   klass_name = Type.coerce_to(klass_name, String, :to_str)
      # rescue TypeError
      #   attrs.unshift klass_name
      #   klass_name = nil
      # end
      if klass_name._isSymbol
        attrs_arg.unshift klass_name
        klass_name = nil
      end
      # END GEMSTONE
    end

    n = 0
    idx = 0
    lim = attrs_arg.__size
    field_names = Array.new(lim)
    attrs = Array.new(lim * 2)
    while n < lim
      begin
        sym = attrs_arg.__at(n).to_sym
        if sym._equal?(nil)
          raise ArgumentError, 'nil attribute name in Struct.new'
        end
        field_names[n] = sym
        attrs[idx] = sym
        attrs[idx + 1] = :"@#{sym}"
        idx += 2
      rescue NoMethodError => e
        raise TypeError, e.message
      end
      n += 1
    end
    unless (n * 2)._equal?(idx)
      raise ArgumentError , 'inconsistent attrs in Struct.new'
    end
    attrs.freeze
    field_names.freeze

    # the field names get fixed instVars with smalltalk style names
    klass = Class.new_fixed_instvars(self, field_names) {
      attr_accessor(*field_names)

      def self.new(*args)
        return subclass_new(*args)
      end

      def self.[](*args)
        return new(*args)
      end

      include Enumerable  # Maglev
    }
    if klass_name
      Struct.const_set(klass_name, klass) 
    end
    klass.const_set(:STRUCT_ATTRS, attrs)
    klass.const_set(:STRUCT_ATTRS_fieldNames, field_names)

    klass.module_eval(&block) if block

    return klass
  end

  def __attrs # :nodoc:
    return self.class.const_get(:STRUCT_ATTRS)
  end

  def __field_names # :nodoc:
    return self.class.const_get(:STRUCT_ATTRS_fieldNames)
  end

  def instance_variables
    # Hide the ivars used to store the struct fields
    # Struct inherits no instVars from it's super classes
    names = super()
    attrs = self.__attrs
    num_members = attrs.__size >> 1
    num_ivs = names.__size
    if num_ivs <= num_members
      []
    else
      names[num_members, num_ivs - num_members]
    end
  end

  def initialize(*args)
    attrs = self.__attrs
    lim = attrs.__size
    n_args = args.__size
    if n_args > (lim >> 1)
      raise ArgumentError , 'too many args'
    end
    n = 0
    idx = 0
    # run to the end of attrs , setting fields to nil
    # if more fields than given in *args
    while n < lim
      self.instance_variable_set( attrs[n + 1], args[idx] )
      n += 2
      idx += 1
    end
  end

  private :initialize

  ##
  # call-seq:
  #   struct == other_struct     => true or false
  #
  # Equality---Returns <tt>true</tt> if <em>other_struct</em> is equal to
  # this one: they must be of the same class as generated by
  # <tt>Struct::new</tt>, and the values of all instance variables must be
  # equal (according to <tt>Object#==</tt>).
  #
  #    Customer = Struct.new(:name, :address, :zip)
  #    joe   = Customer.new("Joe Smith", "123 Maple, Anytown NC", 12345)
  #    joejr = Customer.new("Joe Smith", "123 Maple, Anytown NC", 12345)
  #    jane  = Customer.new("Jane Doe", "456 Elm, Anytown NC", 12345)
  #    joe == joejr   #=> true
  #    joe == jane    #=> false

  def ==(other)
    return true if self._equal?(other)
    return false if (self.class != other.class)
    myvals = self.values
    othervals = other.values

    n = 0
    lim = myvals.size
    return false if (lim != othervals.size)
    while n < lim
      rg = RecursionGuard
      rgstack = rg.stack
      myelem = myvals.__at(n)
      unless rgstack.include?(myelem)
        otherelem = othervals.__at(n)
        unless rgstack.include?(otherelem)
          rg.guard(myelem) do
            rg.guard(otherelem) do
              return false if (myelem != otherelem)
            end
          end
        end
      end
      n += 1
    end
    return true
  end

  ##
  # call-seq:
  #   struct[symbol]    => anObject
  #   struct[fixnum]    => anObject
  #
  # Attribute Reference---Returns the value of the instance variable named
  # by <em>symbol</em>, or indexed (0..length-1) by <em>fixnum</em>. Will
  # raise <tt>NameError</tt> if the named variable does not exist, or
  # <tt>IndexError</tt> if the index is out of range.
  #
  #    Customer = Struct.new(:name, :address, :zip)
  #    joe = Customer.new("Joe Smith", "123 Maple, Anytown NC", 12345)
  #    joe["name"]   #=> "Joe Smith"
  #    joe[:name]    #=> "Joe Smith"
  #    joe[0]        #=> "Joe Smith"

  def __iv_name_for(var)
    # for the specified field name or number,
    # return the instance variable name for use in an instance_variable_get
    attrs = self.__attrs
    if var._isNumeric
      var = var.to_i
      num_fields = attrs.__size >> 1
      if var >= num_fields then
  raise IndexError, "offset #{var} too large for struct(size:#{num_fields})"
      end
      if var < 0
        if var < -num_fields then
    raise IndexError, "offset #{var + num_fields} too small for struct(size:#{num_fields})"
        end
        var = var + num_fields
      end
      idx = (var << 1) + 1
    else
      if var._isString
        var = var.to_sym
      elsif (! var._isSymbol)
        raise TypeError , 'expected a Numeric, String, or Symbol'
      end
      idx = 0                  # one-based
      unless var.__at(0)._equal?( ?@ )
        idx = attrs.__offset1_identical(var)
      end
      if idx._equal?(0)
        raise NameError, "no member '#{var}' in struct"
      end
      # idx - 1 + 1 is the instVar name
    end
    attrs[idx]
  end

  def [](var)
    return instance_variable_get(self.__iv_name_for(var))
  end

  ##
  # call-seq:
  #   struct[symbol] = obj    => obj
  #   struct[fixnum] = obj    => obj
  #
  # Attribute Assignment---Assigns to the instance variable named by
  # <em>symbol</em> or <em>fixnum</em> the value <em>obj</em> and returns
  # it. Will raise a <tt>NameError</tt> if the named variable does not
  # exist, or an <tt>IndexError</tt> if the index is out of range.
  #
  #    Customer = Struct.new(:name, :address, :zip)
  #    joe = Customer.new("Joe Smith", "123 Maple, Anytown NC", 12345)
  #    joe["name"] = "Luke"
  #    joe[:zip]   = "90210"
  #    joe.name   #=> "Luke"
  #    joe.zip    #=> "90210"

  def []=(var, obj)
    return instance_variable_set( self.__iv_name_for(var), obj)
  end

  ##
  # call-seq:
  #   struct.each {|obj| block }  => struct
  #
  # Calls <em>block</em> once for each instance variable, passing the value
  # as a parameter.
  #
  #    Customer = Struct.new(:name, :address, :zip)
  #    joe = Customer.new("Joe Smith", "123 Maple, Anytown NC", 12345)
  #    joe.each {|x| puts(x) }
  #
  # <em>produces:</em>
  #
  #    Joe Smith
  #    123 Maple, Anytown NC
  #    12345

  def each(&block)
    if block_given?
      return self.values.each(&block)
    else
      return self.values.each()
    end
  end

  def each()  # added for 1.8.7
    # Returns an ArrayEnumerator
    return self.values.each()
  end

  ##
  # call-seq:
  #   struct.each_pair {|sym, obj| block }     => struct
  #
  # Calls <em>block</em> once for each instance variable, passing the name
  # (as a symbol) and the value as parameters.
  #
  #    Customer = Struct.new(:name, :address, :zip)
  #    joe = Customer.new("Joe Smith", "123 Maple, Anytown NC", 12345)
  #    joe.each_pair {|name, value| puts("#{name} => #{value}") }
  #
  # <em>produces:</em>
  #
  #    name => Joe Smith
  #    address => 123 Maple, Anytown NC
  #    zip => 12345

  def each_pair(&block)
    attrs = self.__attrs
    n = 0
    lim = attrs.__size
    unless block_given?
      # for 1.8.7, returns an ArrayEnumerator
      pairs = []
      while n < lim
        pairs << [ attrs[n], self.instance_variable_get( attrs[n+1] ) ]
        n += 2
      end
      return pairs.each()
    end
    while n < lim
      block.call( attrs[n], self.instance_variable_get( attrs[n+1] ))
      n += 2
    end
  end

  ##
  # call-seq:
  #   (p1)
  #
  # code-seq:
  #
  #   struct.eql?(other)   => true or false
  #
  # Two structures are equal if they are the same object, or if all their
  # fields are equal (using <tt>eql?</tt>).

  def eql?(other)
    return true if self._equal?(other)
    return false if (self.class != other.class)
    myvals = self.values
    othervals = other.values
    return false if (myvals.size != othervals.size)

    n = 0
    lim = myvals.size
    while n < lim
      rg = RecursionGuard
      rgstack = rg.stack
      myelem = myvals.__at(n)
      unless rgstack.include?(myelem)
        otherelem = othervals.__at(n)
        unless rgstack.include?(otherelem)
          rg.guard(myelem) do
            rg.guard(otherelem) do
              unless myelem.eql?(otherelem)
                return false
              end
            end
          end
        end
      end
      n += 1
    end
    return true
  end

  ##
  # call-seq:
  #   struct.hash   => fixnum
  #
  # Return a hash value based on this struct's contents.

  def hash
    ary = self.to_a
    hval = 4459
    n = 0
    lim = ary.__size
    while n < lim
      elem = ary.__at(n)
      if elem._is_a?(Struct)
        eh = elem.class.name.hash
      else
        eh = elem.hash
      end
      if eh._not_equal?(0)
	unless eh._isFixnum
	  eh = eh & 0xfffffffffffffff # truncate to Fixnum
	end
        hval = (hval >> 1) ^ eh
      end
      n += 1
    end
    hval
  end

  ##
  # call-seq:
  #   struct.length    => fixnum
  #   struct.size      => fixnum
  #
  # Returns the number of instance variables.
  #
  #    Customer = Struct.new(:name, :address, :zip)
  #    joe = Customer.new("Joe Smith", "123 Maple, Anytown NC", 12345)
  #    joe.length   #=> 3

  def length
    return (self.__attrs.__size) >> 1
  end

  alias_method :size, :length

  ##
  # call-seq:
  #   struct.members    => array
  #
  # Returns an array of strings representing the names of the instance
  # variables.
  #
  #    Customer = Struct.new(:name, :address, :zip)
  #    joe = Customer.new("Joe Smith", "123 Maple, Anytown NC", 12345)
  #    joe.members   #=> ["name", "address", "zip"]

  def self.members
    names = self.const_get(:STRUCT_ATTRS_fieldNames)
    n = 0
    lim = names.__size
    res = Array.new(lim)
    while n < lim
      res[n] = names[n].to_s
      n += 1
    end
    res
  end

  def members
    return self.class.members
  end

  ##
  # call-seq:
  #   struct.select(fixnum, ... )   => array
  #   struct.select {|i| block }    => array
  #
  # The first form returns an array containing the elements in
  # <em>struct</em> corresponding to the given indices. The second form
  # invokes the block passing in successive elements from <em>struct</em>,
  # returning an array containing those elements for which the block returns
  # a true value (equivalent to <tt>Enumerable#select</tt>).
  #
  #    Lots = Struct.new(:a, :b, :c, :d, :e, :f)
  #    l = Lots.new(11, 22, 33, 44, 55, 66)
  #    l.select(1, 3, 5)               #=> [22, 44, 66]
  #    l.select(0, 2, 4)               #=> [11, 33, 55]
  #    l.select(-1, -3, -5)            #=> [66, 44, 22]
  #    l.select {|v| (v % 2).zero? }   #=> [22, 44, 66]

  def select(&block)
    to_a.select(&block)
  end

  ##
  # call-seq:
  #   struct.to_a     => array
  #   struct.values   => array
  #
  # Returns the values for this instance as an array.
  #
  #    Customer = Struct.new(:name, :address, :zip)
  #    joe = Customer.new("Joe Smith", "123 Maple, Anytown NC", 12345)
  #    joe.to_a[1]   #=> "123 Maple, Anytown NC"

  def to_a
    attrs = self.__attrs
    lim = attrs.__size
    res = Array.new(lim >> 1)
    n = 0
    idx = 0
    while n < lim
      res[idx] = self.instance_variable_get( attrs[n+1] )
      idx += 1
      n += 2
    end
    res
  end

  ##
  # call-seq:
  #   struct.to_s      => string
  #   struct.inspect   => string
  #
  # Describe the contents of this struct in a string.

  def to_s
    rg = RecursionGuard
    return "[...]" if rg.guarding?(self)

    rg.guard(self) do
      "#<struct #{self.class.name} #{self.__field_names.zip(self.to_a).map{|o| o[1] = o[1].inspect; o.join('=')}.join(', ') }>"
    end
  end

  alias_method :inspect, :to_s

  ##
  # call-seq:
  #   struct.to_a     => array
  #   struct.values   => array
  #
  # Returns the values for this instance as an array.
  #
  #    Customer = Struct.new(:name, :address, :zip)
  #    joe = Customer.new("Joe Smith", "123 Maple, Anytown NC", 12345)
  #    joe.to_a[1]   #=> "123 Maple, Anytown NC"

  alias_method :values, :to_a

  ##
  # call-seq:
  #   struct.values_at(selector,... )  => an_array
  #
  # Returns an array containing the elements in <em>self</em> corresponding
  # to the given selector(s). The selectors may be either integer indices or
  # ranges. See also </code>.select<code>.
  #
  #    a = %w{ a b c d e f }
  #    a.values_at(1, 3, 5)
  #    a.values_at(1, 3, 5, 7)
  #    a.values_at(-1, -3, -5, -7)
  #    a.values_at(1..3, 2...5)

  def values_at(*args)
    to_a.values_at(*args)
  end
end

