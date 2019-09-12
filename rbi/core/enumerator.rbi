# typed: __STDLIB_INTERNAL

# A class which allows both internal and external iteration.
#
# An [`Enumerator`](https://docs.ruby-lang.org/en/2.6.0/Enumerator.html) can be
# created by the following methods.
# *   Kernel#to\_enum
# *   Kernel#enum\_for
# *   [`Enumerator.new`](https://docs.ruby-lang.org/en/2.6.0/Enumerator.html#method-c-new)
#
#
# Most methods have two forms: a block form where the contents are evaluated for
# each item in the enumeration, and a non-block form which returns a new
# [`Enumerator`](https://docs.ruby-lang.org/en/2.6.0/Enumerator.html) wrapping
# the iteration.
#
# ```ruby
# enumerator = %w(one two three).each
# puts enumerator.class # => Enumerator
#
# enumerator.each_with_object("foo") do |item, obj|
#   puts "#{obj}: #{item}"
# end
#
# # foo: one
# # foo: two
# # foo: three
#
# enum_with_obj = enumerator.each_with_object("foo")
# puts enum_with_obj.class # => Enumerator
#
# enum_with_obj.each do |item, obj|
#   puts "#{obj}: #{item}"
# end
#
# # foo: one
# # foo: two
# # foo: three
# ```
#
# This allows you to chain Enumerators together. For example, you can map a
# list's elements to strings containing the index and the element as a string
# via:
#
# ```ruby
# puts %w[foo bar baz].map.with_index { |w, i| "#{i}:#{w}" }
# # => ["0:foo", "1:bar", "2:baz"]
# ```
#
# An [`Enumerator`](https://docs.ruby-lang.org/en/2.6.0/Enumerator.html) can
# also be used as an external iterator. For example,
# [`Enumerator#next`](https://docs.ruby-lang.org/en/2.6.0/Enumerator.html#method-i-next)
# returns the next value of the iterator or raises
# [`StopIteration`](https://docs.ruby-lang.org/en/2.6.0/StopIteration.html) if
# the [`Enumerator`](https://docs.ruby-lang.org/en/2.6.0/Enumerator.html) is at
# the end.
#
# ```ruby
# e = [1,2,3].each   # returns an enumerator object.
# puts e.next   # => 1
# puts e.next   # => 2
# puts e.next   # => 3
# puts e.next   # raises StopIteration
# ```
#
# You can use this to implement an internal iterator as follows:
#
# ```ruby
# def ext_each(e)
#   while true
#     begin
#       vs = e.next_values
#     rescue StopIteration
#       return $!.result
#     end
#     y = yield(*vs)
#     e.feed y
#   end
# end
#
# o = Object.new
#
# def o.each
#   puts yield
#   puts yield(1)
#   puts yield(1, 2)
#   3
# end
#
# # use o.each as an internal iterator directly.
# puts o.each {|*x| puts x; [:b, *x] }
# # => [], [:b], [1], [:b, 1], [1, 2], [:b, 1, 2], 3
#
# # convert o.each to an external iterator for
# # implementing an internal iterator.
# puts ext_each(o.to_enum) {|*x| puts x; [:b, *x] }
# # => [], [:b], [1], [:b, 1], [1, 2], [:b, 1, 2], 3
# ```
class Enumerator < Object
  include Enumerable

  extend T::Generic
  Elem = type_member(:out)

  # Iterates over the block according to how this
  # [`Enumerator`](https://docs.ruby-lang.org/en/2.6.0/Enumerator.html) was
  # constructed. If no block and no arguments are given, returns self.
  #
  # ### Examples
  #
  # ```ruby
  # "Hello, world!".scan(/\w+/)                     #=> ["Hello", "world"]
  # "Hello, world!".to_enum(:scan, /\w+/).to_a      #=> ["Hello", "world"]
  # "Hello, world!".to_enum(:scan).each(/\w+/).to_a #=> ["Hello", "world"]
  #
  # obj = Object.new
  #
  # def obj.each_arg(a, b=:b, *rest)
  #   yield a
  #   yield b
  #   yield rest
  #   :method_returned
  # end
  #
  # enum = obj.to_enum :each_arg, :a, :x
  #
  # enum.each.to_a                  #=> [:a, :x, []]
  # enum.each.equal?(enum)          #=> true
  # enum.each { |elm| elm }         #=> :method_returned
  #
  # enum.each(:y, :z).to_a          #=> [:a, :x, [:y, :z]]
  # enum.each(:y, :z).equal?(enum)  #=> false
  # enum.each(:y, :z) { |elm| elm } #=> :method_returned
  # ```
  sig do
    params(
        blk: T.proc.params(arg0: Elem).returns(BasicObject),
    )
    .returns(T.untyped)
  end
  sig {returns(T.self_type)}
  def each(&blk); end

  # Sets the value to be returned by the next yield inside `e`.
  #
  # If the value is not set, the yield returns nil.
  #
  # This value is cleared after being yielded.
  #
  # ```ruby
  # # Array#map passes the array's elements to "yield" and collects the
  # # results of "yield" as an array.
  # # Following example shows that "next" returns the passed elements and
  # # values passed to "feed" are collected as an array which can be
  # # obtained by StopIteration#result.
  # e = [1,2,3].map
  # p e.next           #=> 1
  # e.feed "a"
  # p e.next           #=> 2
  # e.feed "b"
  # p e.next           #=> 3
  # e.feed "c"
  # begin
  #   e.next
  # rescue StopIteration
  #   p $!.result      #=> ["a", "b", "c"]
  # end
  #
  # o = Object.new
  # def o.each
  #   x = yield         # (2) blocks
  #   p x               # (5) => "foo"
  #   x = yield         # (6) blocks
  #   p x               # (8) => nil
  #   x = yield         # (9) blocks
  #   p x               # not reached w/o another e.next
  # end
  #
  # e = o.to_enum
  # e.next              # (1)
  # e.feed "foo"        # (3)
  # e.next              # (4)
  # e.next              # (7)
  #                     # (10)
  # ```
  sig do
    params(
        arg0: Elem,
    )
    .returns(NilClass)
  end
  def feed(arg0); end

  sig do
    params(
        arg0: Integer,
        blk: T.proc.params(arg0: Enumerator::Yielder).void,
    )
    .void
  end
  def initialize(arg0=T.unsafe(nil), &blk); end

  # Creates a printable version of *e*.
  sig {returns(String)}
  def inspect(); end

  # Returns the next object in the enumerator, and move the internal position
  # forward. When the position reached at the end,
  # [`StopIteration`](https://docs.ruby-lang.org/en/2.6.0/StopIteration.html) is
  # raised.
  #
  # ### Example
  #
  # ```ruby
  # a = [1,2,3]
  # e = a.to_enum
  # p e.next   #=> 1
  # p e.next   #=> 2
  # p e.next   #=> 3
  # p e.next   #raises StopIteration
  # ```
  #
  # Note that enumeration sequence by `next` does not affect other non-external
  # enumeration methods, unless the underlying iteration methods itself has
  # side-effect, e.g.
  # [`IO#each_line`](https://docs.ruby-lang.org/en/2.6.0/IO.html#method-i-each_line).
  sig {returns(Elem)}
  def next(); end

  # Returns the next object as an array in the enumerator, and move the internal
  # position forward. When the position reached at the end,
  # [`StopIteration`](https://docs.ruby-lang.org/en/2.6.0/StopIteration.html) is
  # raised.
  #
  # This method can be used to distinguish `yield` and `yield nil`.
  #
  # ### Example
  #
  # ```ruby
  # o = Object.new
  # def o.each
  #   yield
  #   yield 1
  #   yield 1, 2
  #   yield nil
  #   yield [1, 2]
  # end
  # e = o.to_enum
  # p e.next_values
  # p e.next_values
  # p e.next_values
  # p e.next_values
  # p e.next_values
  # e = o.to_enum
  # p e.next
  # p e.next
  # p e.next
  # p e.next
  # p e.next
  #
  # ## yield args       next_values      next
  # #  yield            []               nil
  # #  yield 1          [1]              1
  # #  yield 1, 2       [1, 2]           [1, 2]
  # #  yield nil        [nil]            nil
  # #  yield [1, 2]     [[1, 2]]         [1, 2]
  # ```
  #
  # Note that `next_values` does not affect other non-external enumeration
  # methods unless underlying iteration method itself has side-effect, e.g.
  # [`IO#each_line`](https://docs.ruby-lang.org/en/2.6.0/IO.html#method-i-each_line).
  sig {returns(T::Array[Elem])}
  def next_values(); end

  # Returns the next object in the enumerator, but doesn't move the internal
  # position forward. If the position is already at the end,
  # [`StopIteration`](https://docs.ruby-lang.org/en/2.6.0/StopIteration.html) is
  # raised.
  #
  # ### Example
  #
  # ```ruby
  # a = [1,2,3]
  # e = a.to_enum
  # p e.next   #=> 1
  # p e.peek   #=> 2
  # p e.peek   #=> 2
  # p e.peek   #=> 2
  # p e.next   #=> 2
  # p e.next   #=> 3
  # p e.peek   #raises StopIteration
  # ```
  sig {returns(Elem)}
  def peek(); end

  # Returns the next object as an array, similar to
  # [`Enumerator#next_values`](https://docs.ruby-lang.org/en/2.6.0/Enumerator.html#method-i-next_values),
  # but doesn't move the internal position forward. If the position is already
  # at the end,
  # [`StopIteration`](https://docs.ruby-lang.org/en/2.6.0/StopIteration.html) is
  # raised.
  #
  # ### Example
  #
  # ```ruby
  # o = Object.new
  # def o.each
  #   yield
  #   yield 1
  #   yield 1, 2
  # end
  # e = o.to_enum
  # p e.peek_values    #=> []
  # e.next
  # p e.peek_values    #=> [1]
  # p e.peek_values    #=> [1]
  # e.next
  # p e.peek_values    #=> [1, 2]
  # e.next
  # p e.peek_values    # raises StopIteration
  # ```
  sig {returns(T::Array[Elem])}
  def peek_values(); end

  # Rewinds the enumeration sequence to the beginning.
  #
  # If the enclosed object responds to a "rewind" method, it is called.
  sig {returns(T.self_type)}
  def rewind(); end

  # Returns the size of the enumerator, or `nil` if it can't be calculated
  # lazily.
  #
  # ```ruby
  # (1..100).to_a.permutation(4).size # => 94109400
  # loop.size # => Float::INFINITY
  # (1..100).drop_while.size # => nil
  # ```
  sig {returns(T.nilable(T.any(Integer, Float)))}
  def size(); end

  # Iterates the given block for each element with an index, which starts from
  # `offset`. If no block is given, returns a new
  # [`Enumerator`](https://docs.ruby-lang.org/en/2.6.0/Enumerator.html) that
  # includes the index, starting from `offset`
  #
  # `offset`
  # :   the starting index to use
  sig do
    params(
        offset: Integer,
        blk: T.proc.params(arg0: Elem, arg1: Integer).returns(BasicObject),
    )
    .returns(T.untyped)
  end
  sig do
    params(
        offset: Integer,
    )
    .returns(T::Enumerator[[Elem, Integer]])
  end
  def with_index(offset=0, &blk); end

  # Iterates the given block for each element with an arbitrary object, `obj`,
  # and returns `obj`
  #
  # If no block is given, returns a new
  # [`Enumerator`](https://docs.ruby-lang.org/en/2.6.0/Enumerator.html).
  #
  # ### Example
  #
  # ```ruby
  # to_three = Enumerator.new do |y|
  #   3.times do |x|
  #     y << x
  #   end
  # end
  #
  # to_three_with_string = to_three.with_object("foo")
  # to_three_with_string.each do |x,string|
  #   puts "#{string}: #{x}"
  # end
  #
  # # => foo:0
  # # => foo:1
  # # => foo:2
  # ```
  sig do
    type_parameters(:U).params(
        arg0: T.type_parameter(:U),
        blk: T.proc.params(arg0: Elem, arg1: T.type_parameter(:U)).returns(BasicObject),
    )
    .returns(T.untyped)
  end
  sig do
    type_parameters(:U).params(
        arg0: T.type_parameter(:U),
    )
    .returns(T::Enumerator[[Elem, T.type_parameter(:U)]])
  end
  def with_object(arg0, &blk); end
end

# [`Generator`](https://docs.ruby-lang.org/en/2.6.0/Enumerator/Generator.html)
class Enumerator::Generator < Object
  include Enumerable

  extend T::Generic
  Elem = type_member(:out)
end

# [`Lazy`](https://docs.ruby-lang.org/en/2.6.0/Enumerator/Lazy.html)
class Enumerator::Lazy < Enumerator
  extend T::Generic
  Elem = type_member(:out)
end

# [`Yielder`](https://docs.ruby-lang.org/en/2.6.0/Enumerator/Yielder.html)
class Enumerator::Yielder < Object
  sig do
    params(
        arg0: BasicObject,
    )
    .void
  end
  def <<(*arg0); end

  sig do
    params(
        arg0: BasicObject,
    )
    .void
  end
  def yield(*arg0); end
end
