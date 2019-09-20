# typed: true

def main
  a = T.let([], T.untyped)
  a.map do |foo, bar|
    # TODO: ^ hover: T.untyped
    # TODO:      ^ hover: T.untyped
  end
  b = T.let([], T::Array[T.untyped])
  b.map do |foo|
          # ^ hover: sig {params(args: T.untyped).returns(T.untyped)}
  end
  c = T.let([], T::Array[String])
  c.map do |foo|
          # ^ hover: sig {params(args: T.untyped).returns(String)}
  end
end
