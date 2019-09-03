# typed: __STDLIB_INTERNAL

# A [Hash](Hash) is a dictionary-like collection of
# unique keys and their values. Also called associative arrays, they are
# similar to Arrays, but where an
# [Array](https://ruby-doc.org/core-2.6.3/Array.html) uses integers as its
# index, a [Hash](Hash) allows you to use any object
# type.
#
# Hashes enumerate their values in the order that the corresponding keys
# were inserted.
#
# A [Hash](Hash) can be easily created by using its
# implicit form:
#
# ```ruby
# grades = { "Jane Doe" => 10, "Jim Doe" => 6 }
# ```
#
# Hashes allow an alternate syntax for keys that are symbols. Instead of
#
# ```ruby
# options = { :font_size => 10, :font_family => "Arial" }
# ```
#
# You could write it as:
#
# ```ruby
# options = { font_size: 10, font_family: "Arial" }
# ```
#
# Each named key is a symbol you can access in hash:
#
# ```ruby
# options[:font_size]  # => 10
# ```
#
# A [Hash](Hash) can also be created through its
# [::new](Hash#method-c-new) method:
#
# ```ruby
# grades = Hash.new
# grades["Dorothy Doe"] = 9
# ```
#
# Hashes have a *default value* that is returned when accessing keys that
# do not exist in the hash. If no default is set `nil` is used. You can
# set the default value by sending it as an argument to
# [::new](Hash#method-c-new):
#
# ```ruby
# grades = Hash.new(0)
# ```
#
# Or by using the [default=](Hash#method-i-default-3D)
# method:
#
# ```ruby
# grades = {"Timmy Doe" => 8}
# grades.default = 0
# ```
#
# Accessing a value in a [Hash](Hash) requires using
# its key:
#
# ```ruby
# puts grades["Jane Doe"] # => 0
# ```
#
#
# Hashes are an easy way to represent data structures, such as
#
# ```ruby
# books         = {}
# books[:matz]  = "The Ruby Programming Language"
# books[:black] = "The Well-Grounded Rubyist"
# ```
#
# Hashes are also commonly used as a way to have named parameters in
# functions. Note that no brackets are used below. If a hash is the last
# argument on a method call, no braces are needed, thus creating a really
# clean interface:
#
# ```ruby
# Person.create(name: "John Doe", age: 27)
#
# def self.create(params)
#   @name = params[:name]
#   @age  = params[:age]
# end
# ```
#
#
# Two objects refer to the same hash key when their `hash` value is
# identical and the two objects are `eql?` to each other.
#
# A user-defined class may be used as a hash key if the `hash` and `eql?`
# methods are overridden to provide meaningful behavior. By default,
# separate instances refer to separate hash keys.
#
# A typical implementation of `hash` is based on the object’s data while
# `eql?` is usually aliased to the overridden `==` method:
#
# ```ruby
# class Book
#   attr_reader :author, :title
#
#   def initialize(author, title)
#     @author = author
#     @title = title
#   end
#
#   def ==(other)
#     self.class === other and
#       other.author == @author and
#       other.title == @title
#   end
#
#   alias eql? ==
#
#   def hash
#     @author.hash ^ @title.hash # XOR
#   end
# end
#
# book1 = Book.new 'matz', 'Ruby in a Nutshell'
# book2 = Book.new 'matz', 'Ruby in a Nutshell'
#
# reviews = {}
#
# reviews[book1] = 'Great reference!'
# reviews[book2] = 'Nice and compact!'
#
# reviews.length #=> 1
# ```
#
# See also Object\#hash and
# [Object\#eql?](https://ruby-doc.org/core-2.6.3/Object.html#method-i-eql-3F)
class Hash < Object
  include Enumerable

  extend T::Generic
  K = type_member(:out)
  V = type_member(:out)
  Elem = type_member(:out)

  # Creates a new hash populated with the given objects.
  #
  # Similar to the literal `{ key => value , ... }` . In the first form,
  # keys and values occur in pairs, so there must be an even number of
  # arguments.
  #
  # The second and third form take a single argument which is either an
  # array of key-value pairs or an object convertible to a hash.
  #
  # ```ruby
  # Hash["a", 100, "b", 200]             #=> {"a"=>100, "b"=>200}
  # Hash[ [ ["a", 100], ["b", 200] ] ]   #=> {"a"=>100, "b"=>200}
  # Hash["a" => 100, "b" => 200]         #=> {"a"=>100, "b"=>200}
  # ```
  sig do
    type_parameters(:U, :V).params(
      arg0: T::Array[[T.type_parameter(:U), T.type_parameter(:V)]],
    )
    .returns(T::Hash[T.type_parameter(:U), T.type_parameter(:V)])
  end
  def self.[](*arg0); end

  # Element Reference—Retrieves the *value* object corresponding to the
  # *key* object. If not found, returns the default value (see `Hash::new`
  # for details).
  #
  # ```ruby
  # h = { "a" => 100, "b" => 200 }
  # h["a"]   #=> 100
  # h["c"]   #=> nil
  # ```
  sig do
    params(
        arg0: K,
    )
    .returns(T.nilable(V))
  end
  def [](arg0); end

  # Associates the value given by `value` with the key given by `key` .
  #
  # ```ruby
  # h = { "a" => 100, "b" => 200 }
  # h["a"] = 9
  # h["c"] = 4
  # h   #=> {"a"=>9, "b"=>200, "c"=>4}
  # h.store("d", 42) #=> 42
  # h   #=> {"a"=>9, "b"=>200, "c"=>4, "d"=>42}
  # ```
  #
  # `key` should not have its value changed while it is in use as a key (an
  # `unfrozen String` passed as a key will be duplicated and frozen).
  #
  # ```ruby
  # a = "a"
  # b = "b".freeze
  # h = { a => 100, b => 200 }
  # h.key(100).equal? a #=> false
  # h.key(200).equal? b #=> true
  # ```
  sig do
    params(
        arg0: K,
        arg1: V,
    )
    .returns(V)
  end
  def []=(arg0, arg1); end

  # Searches through the hash comparing *obj* with the key using `==` .
  # Returns the key-value pair (two elements array) or `nil` if no match is
  # found. See `Array#assoc` .
  #
  # ```ruby
  # h = {"colors"  => ["red", "blue", "green"],
  #      "letters" => ["a", "b", "c" ]}
  # h.assoc("letters")  #=> ["letters", ["a", "b", "c"]]
  # h.assoc("foo")      #=> nil
  # ```
  sig do
    params(
        arg0: K,
    )
    .returns(T::Array[T.any(K, V)])
  end
  def assoc(arg0); end

  # Removes all key-value pairs from *hsh* .
  #
  # ```ruby
  # h = { "a" => 100, "b" => 200 }   #=> {"a"=>100, "b"=>200}
  # h.clear                          #=> {}
  # ```
  sig {returns(T::Hash[K, V])}
  def clear(); end

  # Makes *hsh* compare its keys by their identity, i.e. it will consider
  # exact same objects as same keys.
  #
  # ```ruby
  # h1 = { "a" => 100, "b" => 200, :c => "c" }
  # h1["a"]        #=> 100
  # h1.compare_by_identity
  # h1.compare_by_identity? #=> true
  # h1["a".dup]    #=> nil  # different objects.
  # h1[:c]         #=> "c"  # same symbols are all same.
  # ```
  sig {returns(T::Hash[K, V])}
  def compare_by_identity(); end

  # Returns `true` if *hsh* will compare its keys by their identity. Also
  # see `Hash#compare_by_identity` .
  sig {returns(T::Boolean)}
  def compare_by_identity?(); end

  # Returns the default value, the value that would be returned by
  # *[hsh](https://ruby-doc.org/core-2.6.3/key)* if *key* did not exist in
  # *hsh* . See also `Hash::new` and `Hash#default=` .
  #
  # ```ruby
  # h = Hash.new                            #=> {}
  # h.default                               #=> nil
  # h.default(2)                            #=> nil
  #
  # h = Hash.new("cat")                     #=> {}
  # h.default                               #=> "cat"
  # h.default(2)                            #=> "cat"
  #
  # h = Hash.new {|h,k| h[k] = k.to_i*10}   #=> {}
  # h.default                               #=> nil
  # h.default(2)                            #=> 20
  # ```
  sig do
    params(
        arg0: K,
    )
    .returns(T.nilable(V))
  end
  sig do
    params(
        arg0: K,
        blk: T.proc.params(arg0: K).returns(V),
    )
    .returns(T.nilable(V))
  end
  def default(arg0=T.unsafe(nil), &blk); end

  sig do
    params(
        arg0: V,
    )
    .returns(V)
  end
  def default=(arg0); end

  # Deletes the key-value pair and returns the value from *hsh* whose key is
  # equal to *key* . If the key is not found, it returns *nil* . If the
  # optional code block is given and the key is not found, pass in the key
  # and return the result of *block* .
  #
  # ```ruby
  # h = { "a" => 100, "b" => 200 }
  # h.delete("a")                              #=> 100
  # h.delete("z")                              #=> nil
  # h.delete("z") { |el| "#{el} not found" }   #=> "z not found"
  # ```
  sig do
    params(
        arg0: K,
    )
    .returns(T.nilable(V))
  end
  sig do
    type_parameters(:U).params(
        arg0: K,
        blk: T.proc.params(arg0: K).returns(T.type_parameter(:U)),
    )
    .returns(T.any(T.type_parameter(:U), V))
  end
  def delete(arg0, &blk); end

  # Deletes every key-value pair from *hsh* for which *block* evaluates to
  # `true` .
  #
  # If no block is given, an enumerator is returned instead.
  #
  # ```ruby
  # h = { "a" => 100, "b" => 200, "c" => 300 }
  # h.delete_if {|key, value| key >= "b" }   #=> {"a"=>100}
  # ```
  sig do
    params(
        blk: T.proc.params(arg0: K, arg1: V).returns(BasicObject),
    )
    .returns(T::Hash[K, V])
  end
  sig {returns(T::Enumerator[[K, V]])}
  def delete_if(&blk); end

  # Calls *block* once for each key in *hsh* , passing the key-value pair as
  # parameters.
  #
  # If no block is given, an enumerator is returned instead.
  #
  # ```ruby
  # h = { "a" => 100, "b" => 200 }
  # h.each {|key, value| puts "#{key} is #{value}" }
  # ```
  #
  # *produces:*
  #
  # ```ruby
  # a is 100
  # b is 200
  # ```
  sig do
    params(
        blk: T.proc.params(arg0: [K, V]).returns(BasicObject),
    )
    .returns(T::Hash[K, V])
  end
  sig {returns(T::Enumerator[[K, V]])}
  def each(&blk); end

  # Calls *block* once for each key in *hsh* , passing the key as a
  # parameter.
  #
  # If no block is given, an enumerator is returned instead.
  #
  # ```ruby
  # h = { "a" => 100, "b" => 200 }
  # h.each_key {|key| puts key }
  # ```
  #
  # *produces:*
  #
  # ```ruby
  # a
  # b
  # ```
  sig do
    params(
        blk: T.proc.params(arg0: K).returns(BasicObject),
    )
    .returns(T::Hash[K, V])
  end
  sig {returns(T::Enumerator[[K, V]])}
  def each_key(&blk); end

  # Calls *block* once for each key in *hsh* , passing the key-value pair as
  # parameters.
  #
  # If no block is given, an enumerator is returned instead.
  #
  # ```ruby
  # h = { "a" => 100, "b" => 200 }
  # h.each {|key, value| puts "#{key} is #{value}" }
  # ```
  #
  # *produces:*
  #
  # ```ruby
  # a is 100
  # b is 200
  # ```
  sig do
    params(
        blk: T.proc.params(arg0: K, arg1: V).returns(BasicObject),
    )
    .returns(T::Hash[K, V])
  end
  sig {returns(T::Enumerator[[K, V]])}
  def each_pair(&blk); end

  # Calls *block* once for each key in *hsh* , passing the value as a
  # parameter.
  #
  # If no block is given, an enumerator is returned instead.
  #
  # ```ruby
  # h = { "a" => 100, "b" => 200 }
  # h.each_value {|value| puts value }
  # ```
  #
  # *produces:*
  #
  # ```ruby
  # 100
  # 200
  # ```
  sig do
    params(
        blk: T.proc.params(arg0: V).returns(BasicObject),
    )
    .returns(T::Hash[K, V])
  end
  sig {returns(T::Enumerator[[K, V]])}
  def each_value(&blk); end

  # Returns `true` if *hsh* contains no key-value pairs.
  #
  # ```ruby
  # {}.empty?   #=> true
  # ```
  sig {returns(T::Boolean)}
  def empty?(); end

  # Returns a value from the hash for the given key. If the key can’t be
  # found, there are several options: With no other arguments, it will raise
  # a `KeyError` exception; if *default* is given, then that will be
  # returned; if the optional code block is specified, then that will be run
  # and its result returned.
  #
  # ```ruby
  # h = { "a" => 100, "b" => 200 }
  # h.fetch("a")                            #=> 100
  # h.fetch("z", "go fish")                 #=> "go fish"
  # h.fetch("z") { |el| "go fish, #{el}"}   #=> "go fish, z"
  # ```
  #
  # The following example shows that an exception is raised if the key is
  # not found and a default value is not supplied.
  #
  # ```ruby
  # h = { "a" => 100, "b" => 200 }
  # h.fetch("z")
  # ```
  #
  # *produces:*
  #
  # ```
  #  prog.rb:2:in `fetch': key not found (KeyError)
  #   from prog.rb:2
  # ```
  sig do
    params(
        arg0: K,
    )
    .returns(V)
  end
  sig do
   type_parameters(:X).params(
      arg0: K,
      arg1: T.type_parameter(:X),
    )
    .returns(T.any(V, T.type_parameter(:X)))
  end
  sig do
   type_parameters(:X).params(
        arg0: K,
        blk: T.proc.params(arg0: K).returns(T.type_parameter(:X)),
    )
    .returns(T.any(V, T.type_parameter(:X)))
  end
  def fetch(arg0, arg1=T.unsafe(nil), &blk); end

  # Returns `true` if the given key is present in *hsh* .
  #
  # ```ruby
  # h = { "a" => 100, "b" => 200 }
  # h.has_key?("a")   #=> true
  # h.has_key?("z")   #=> false
  # ```
  #
  # Note that `include?` and `member?` do not test member equality using
  # `==` as do other Enumerables.
  #
  # See also
  # [Enumerable\#include?](https://ruby-doc.org/core-2.6.3/Enumerable.html#method-i-include-3F)
  sig do
    params(
        arg0: K,
    )
    .returns(T::Boolean)
  end
  def has_key?(arg0); end

  # Returns `true` if the given value is present for some key in *hsh* .
  #
  # ```ruby
  # h = { "a" => 100, "b" => 200 }
  # h.value?(100)   #=> true
  # h.value?(999)   #=> false
  # ```
  sig do
    params(
        arg0: V,
    )
    .returns(T::Boolean)
  end
  def has_value?(arg0); end

  sig {returns(Hash)}
  sig do
    params(
        default: BasicObject,
    )
    .returns(Hash)
  end
  sig do
    params(
        blk: T.proc.params(hash: Hash, key: BasicObject).returns(BasicObject)
    )
    .void
  end
  def initialize(default=T.unsafe(nil), &blk); end

  # Return the contents of this hash as a string.
  #
  # ```ruby
  # h = { "c" => 300, "a" => 100, "d" => 400, "c" => 300  }
  # h.to_s   #=> "{\"c\"=>300, \"a\"=>100, \"d\"=>400}"
  # ```
  #
  #
  #
  # Also aliased as: [to\_s](Hash.downloaded.ruby_doc#method-i-to_s)
  sig {returns(String)}
  def inspect(); end

  # Returns a new hash created by using *hsh* ’s values as keys, and the
  # keys as values. If a key with the same value already exists in the *hsh*
  # , then the last one defined will be used, the earlier value(s) will be
  # discarded.
  #
  # ```ruby
  # h = { "n" => 100, "m" => 100, "y" => 300, "d" => 200, "a" => 0 }
  # h.invert   #=> {0=>"a", 100=>"m", 200=>"d", 300=>"y"}
  # ```
  #
  # If there is no key with the same value,
  # [\#invert](Hash.downloaded.ruby_doc#method-i-invert) is involutive.
  #
  # ```ruby
  # h = { a: 1, b: 3, c: 4 }
  # h.invert.invert == h #=> true
  # ```
  #
  # The condition, no key with the same value, can be tested by comparing
  # the size of inverted hash.
  #
  # ```ruby
  # # no key with the same value
  # h = { a: 1, b: 3, c: 4 }
  # h.size == h.invert.size #=> true
  #
  # # two (or more) keys has the same value
  # h = { a: 1, b: 3, c: 1 }
  # h.size == h.invert.size #=> false
  # ```
  sig {returns(T::Hash[V, K])}
  def invert(); end

  # Deletes every key-value pair from *hsh* for which *block* evaluates to
  # `false` .
  #
  # If no block is given, an enumerator is returned instead.
  #
  # See also [\#select\!](Hash.downloaded.ruby_doc#method-i-select-21).
  sig do
    params(
        blk: T.proc.params(arg0: K, arg1: V).returns(BasicObject),
    )
    .returns(T::Hash[K, V])
  end
  sig {returns(T::Enumerator[[K, V]])}
  def keep_if(&blk); end

  # Returns the key of an occurrence of a given value. If the value is not
  # found, returns `nil` .
  #
  # ```ruby
  # h = { "a" => 100, "b" => 200, "c" => 300, "d" => 300 }
  # h.key(200)   #=> "b"
  # h.key(300)   #=> "c"
  # h.key(999)   #=> nil
  # ```
  sig do
    params(
        arg0: V,
    )
    .returns(T.nilable(K))
  end
  def key(arg0); end

  # Returns `true` if the given key is present in *hsh* .
  #
  # ```ruby
  # h = { "a" => 100, "b" => 200 }
  # h.has_key?("a")   #=> true
  # h.has_key?("z")   #=> false
  # ```
  #
  # Note that `include?` and `member?` do not test member equality using
  # `==` as do other Enumerables.
  #
  # See also
  # [Enumerable\#include?](https://ruby-doc.org/core-2.6.3/Enumerable.html#method-i-include-3F)
  sig do
    params(
        arg0: K,
    )
    .returns(T::Boolean)
  end
  def key?(arg0); end

  # Returns a new array populated with the keys from this hash. See also
  # `Hash#values` .
  #
  # ```ruby
  # h = { "a" => 100, "b" => 200, "c" => 300, "d" => 400 }
  # h.keys   #=> ["a", "b", "c", "d"]
  # ```
  sig {returns(T::Array[K])}
  def keys(); end

  # Returns the number of key-value pairs in the hash.
  #
  # ```ruby
  # h = { "d" => 100, "a" => 200, "v" => 300, "e" => 400 }
  # h.size          #=> 4
  # h.delete("a")   #=> 200
  # h.size          #=> 3
  # h.length        #=> 3
  # ```
  #
  # [\#length](Hash.downloaded.ruby_doc#method-i-length) is an alias for
  # [\#size](Hash.downloaded.ruby_doc#method-i-size).
  sig {returns(Integer)}
  def length(); end

  # Returns `true` if the given key is present in *hsh* .
  #
  # ```ruby
  # h = { "a" => 100, "b" => 200 }
  # h.has_key?("a")   #=> true
  # h.has_key?("z")   #=> false
  # ```
  #
  # Note that `include?` and `member?` do not test member equality using
  # `==` as do other Enumerables.
  #
  # See also
  # [Enumerable\#include?](https://ruby-doc.org/core-2.6.3/Enumerable.html#method-i-include-3F)
  sig do
    params(
        arg0: K,
    )
    .returns(T::Boolean)
  end
  def member?(arg0); end

  # Returns a new hash that combines the contents of the receiver and the
  # contents of the given hashes.
  #
  # If no block is given, entries with duplicate keys are overwritten with
  # the values from each `other_hash` successively, otherwise the value for
  # each duplicate key is determined by calling the block with the key, its
  # value in the receiver and its value in each `other_hash` .
  #
  # When called without any argument, returns a copy of the receiver.
  #
  # ```ruby
  # h1 = { "a" => 100, "b" => 200 }
  # h2 = { "b" => 246, "c" => 300 }
  # h3 = { "b" => 357, "d" => 400 }
  # h1.merge          #=> {"a"=>100, "b"=>200}
  # h1.merge(h2)      #=> {"a"=>100, "b"=>246, "c"=>300}
  # h1.merge(h2, h3)  #=> {"a"=>100, "b"=>357, "c"=>300, "d"=>400}
  # h1.merge(h2) {|key, oldval, newval| newval - oldval}
  #                   #=> {"a"=>100, "b"=>46,  "c"=>300}
  # h1.merge(h2, h3) {|key, oldval, newval| newval - oldval}
  #                   #=> {"a"=>100, "b"=>311, "c"=>300, "d"=>400}
  # h1                #=> {"a"=>100, "b"=>200}
  # ```
  sig do
    type_parameters(:A ,:B).params(
        arg0: T::Hash[T.type_parameter(:A), T.type_parameter(:B)],
    )
    .returns(T::Hash[T.any(T.type_parameter(:A), K), T.any(T.type_parameter(:B), V)])
  end
  sig do
    type_parameters(:A ,:B).params(
        arg0: T::Hash[T.type_parameter(:A), T.type_parameter(:B)],
        blk: T.proc.params(arg0: K, arg1: V, arg2: T.type_parameter(:B)).returns(T.any(V, T.type_parameter(:B))),
    )
    .returns(T::Hash[T.any(T.type_parameter(:A), K), T.any(T.type_parameter(:B), V)])
  end
  def merge(*arg0, &blk); end

  # Searches through the hash comparing *obj* with the value using `==` .
  # Returns the first key-value pair (two-element array) that matches. See
  # also `Array#rassoc` .
  #
  # ```ruby
  # a = {1=> "one", 2 => "two", 3 => "three", "ii" => "two"}
  # a.rassoc("two")    #=> [2, "two"]
  # a.rassoc("four")   #=> nil
  # ```
  sig do
    params(
        arg0: K,
    )
    .returns(T::Array[T.any(K, V)])
  end
  def rassoc(arg0); end

  # Rebuilds the hash based on the current hash values for each key. If
  # values of key objects have changed since they were inserted, this method
  # will reindex *hsh* . If `Hash#rehash` is called while an iterator is
  # traversing the hash, a `RuntimeError` will be raised in the iterator.
  #
  # ```ruby
  # a = [ "a", "b" ]
  # c = [ "c", "d" ]
  # h = { a => 100, c => 300 }
  # h[a]       #=> 100
  # a[0] = "z"
  # h[a]       #=> nil
  # h.rehash   #=> {["z", "b"]=>100, ["c", "d"]=>300}
  # h[a]       #=> 100
  # ```
  sig {returns(T::Hash[K, V])}
  def rehash(); end

  # Returns a new hash consisting of entries for which the block returns
  # false.
  #
  # If no block is given, an enumerator is returned instead.
  #
  # ```ruby
  # h = { "a" => 100, "b" => 200, "c" => 300 }
  # h.reject {|k,v| k < "b"}  #=> {"b" => 200, "c" => 300}
  # h.reject {|k,v| v > 100}  #=> {"a" => 100}
  # ```
  sig {returns(T::Enumerator[[K, V]])}
  sig do
    params(
        blk: T.proc.params(arg0: K, arg1: V).returns(BasicObject),
    )
    .returns(T::Hash[K, V])
  end
  def reject(&blk); end

  # Equivalent to `Hash#delete_if`, but returns `nil` if no changes were
  # made.
  sig do
    params(
        blk: T.proc.params(arg0: K, arg1: V).returns(BasicObject),
    )
    .returns(T::Hash[K, V])
  end
  def reject!(&blk); end

  # Returns a new hash consisting of entries for which the block returns
  # true.
  #
  # If no block is given, an enumerator is returned instead.
  #
  # ```ruby
  # h = { "a" => 100, "b" => 200, "c" => 300 }
  # h.select {|k,v| k > "a"}  #=> {"b" => 200, "c" => 300}
  # h.select {|k,v| v < 200}  #=> {"a" => 100}
  # ```
  #
  # [\#filter](Hash.downloaded.ruby_doc#method-i-filter) is an alias for
  # [\#select](Hash.downloaded.ruby_doc#method-i-select).
  sig do
    params(
        blk: T.proc.params(arg0: K, arg1: V).returns(BasicObject),
    )
    .returns(T::Hash[K, V])
  end
  def select(&blk); end

  # Equivalent to [\#keep\_if](Hash.downloaded.ruby_doc#method-i-keep_if),
  # but returns `nil` if no changes were made.
  #
  # [\#filter\!](Hash.downloaded.ruby_doc#method-i-filter-21) is an alias
  # for [\#select\!](Hash.downloaded.ruby_doc#method-i-select-21).
  sig do
    params(
        blk: T.proc.params(arg0: K, arg1: V).returns(BasicObject),
    )
    .returns(T::Hash[K, V])
  end
  def select!(&blk); end

  # Removes a key-value pair from *hsh* and returns it as the two-item array
  # `[` *key, value* `]`, or the hash’s default value if the hash is empty.
  #
  # ```ruby
  # h = { 1 => "a", 2 => "b", 3 => "c" }
  # h.shift   #=> [1, "a"]
  # h         #=> {2=>"b", 3=>"c"}
  # ```
  sig {returns(T::Array[T.any(K, V)])}
  def shift(); end

  # Returns the number of key-value pairs in the hash.
  #
  # ```ruby
  # h = { "d" => 100, "a" => 200, "v" => 300, "e" => 400 }
  # h.size          #=> 4
  # h.delete("a")   #=> 200
  # h.size          #=> 3
  # h.length        #=> 3
  # ```
  #
  # [\#length](Hash.downloaded.ruby_doc#method-i-length) is an alias for
  # [\#size](Hash.downloaded.ruby_doc#method-i-size).
  sig {returns(Integer)}
  def size(); end

  # Associates the value given by `value` with the key given by `key` .
  #
  # ```ruby
  # h = { "a" => 100, "b" => 200 }
  # h["a"] = 9
  # h["c"] = 4
  # h   #=> {"a"=>9, "b"=>200, "c"=>4}
  # h.store("d", 42) #=> 42
  # h   #=> {"a"=>9, "b"=>200, "c"=>4, "d"=>42}
  # ```
  #
  # `key` should not have its value changed while it is in use as a key (an
  # `unfrozen String` passed as a key will be duplicated and frozen).
  #
  # ```ruby
  # a = "a"
  # b = "b".freeze
  # h = { a => 100, b => 200 }
  # h.key(100).equal? a #=> false
  # h.key(200).equal? b #=> true
  # ```
  sig do
    params(
        arg0: K,
        arg1: V,
    )
    .returns(V)
  end
  def store(arg0, arg1); end

  # Converts *hsh* to a nested array of `[` *key, value* `]` arrays.
  #
  # ```ruby
  # h = { "c" => 300, "a" => 100, "d" => 400, "c" => 300  }
  # h.to_a   #=> [["c", 300], ["a", 100], ["d", 400]]
  # ```
  sig {returns(T::Array[[K, V]])}
  def to_a(); end

  # Returns `self`.
  sig {returns(T::Hash[K, V])}
  def to_hash(); end

  # Alias for: [inspect](Hash.downloaded.ruby_doc#method-i-inspect)
  sig {returns(String)}
  def to_s(); end

  # Returns `true` if the given value is present for some key in *hsh* .
  #
  # ```ruby
  # h = { "a" => 100, "b" => 200 }
  # h.value?(100)   #=> true
  # h.value?(999)   #=> false
  # ```
  sig do
    params(
        arg0: V,
    )
    .returns(T::Boolean)
  end
  def value?(arg0); end

  # Returns a new array populated with the values from *hsh* . See also
  # `Hash#keys` .
  #
  # ```ruby
  # h = { "a" => 100, "b" => 200, "c" => 300 }
  # h.values   #=> [100, 200, 300]
  # ```
  sig {returns(T::Array[V])}
  def values(); end

  sig do
    params(
        arg0: K,
    )
    .returns(T::Array[V])
  end
  def values_at(*arg0); end
end
