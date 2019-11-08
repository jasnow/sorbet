# typed: strict

class T::Enum
  extend T::Props::CustomType

  ## Enum class methods ##
  sig {returns(T::Array[T.experimental_attached_class])}
  def self.values; end

  # Convert from serialized value to enum instance.
  #
  # Note: It would have been nice to make this method final before people started overriding it.
  # Note: Failed CriticalMethodsNoRuntimeTypingTest
  sig {overridable.params(serialized_val: T.untyped).returns(T.nilable(T.experimental_attached_class)).checked(:never)}
  def self.try_deserialize(serialized_val); end

  # Convert from serialized value to enum instance.
  #
  # Note: It would have been nice to make this method final before people started overriding it.
  # Note: Failed CriticalMethodsNoRuntimeTypingTest
  #
  # @return [self]
  # @raise [KeyError] if serialized value does not match any instance.
  sig {overridable.params(serialized_val: T.untyped).returns(T.experimental_attached_class).checked(:never)}
  def self.from_serialized(serialized_val); end

  # Note: It would have been nice to make this method final before people started overriding it.
  # @return [Boolean] Does the given serialized value correspond with any of this enum's values.
  sig {overridable.params(serialized_val: T.untyped).returns(T::Boolean)}
  def self.has_serialized?(serialized_val); end


  ## T::Props::CustomType

  sig {params(value: T.untyped).returns(T::Boolean).checked(:never)}
  def self.instance?(value); end

  sig {params(instance: T.nilable(T::Enum)).returns(T.untyped).checked(:never)}
  def self.serialize(instance); end

  sig {params(mongo_value: T.untyped).returns(T.experimental_attached_class).checked(:never)}
  def self.deserialize(mongo_value); end


  ## Enum instance methods ##


  sig {returns(T.self_type)}
  def dup; end

  sig {returns(T.self_type).checked(:tests)}
  def clone; end

  sig {returns(T.untyped).checked(:never)}
  def serialize; end

  sig {params(args: T.untyped).returns(T.untyped)}
  def to_json(*args); end

  sig {returns(String)}
  def to_s; end

  sig {returns(String)}
  def inspect; end

  sig {params(other: BasicObject).returns(T.nilable(Integer))}
  def <=>(other); end


  sig {params(other: BasicObject).returns(T::Boolean).checked(:never)}
  def ==(other); end

  sig {params(other: BasicObject).returns(T::Boolean).checked(:never)}
  def ===(other); end


  ## Private implementation ##


  sig {params(serialized_val: T.untyped).void}
  private def initialize(serialized_val=nil); end

  sig {params(const_name: Symbol).void}
  def _bind_name(const_name); end

  # Entrypoint for allowing people to register new enum values.
  # All enum values must be defined within this block.
  sig {params(blk: T.proc.void).void}
  def self.enums(&blk); end
end
