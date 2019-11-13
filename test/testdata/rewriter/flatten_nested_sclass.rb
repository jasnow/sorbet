# typed: true

class A
  def self.foo;
    class << self
      def bar; end
    end
  end
end

A.foo
A.bar

class B
  def foo;
    class << self
      def bar; end
    end
  end
end

B.new.foo
B.new.bar


class C
  def self.foo;
    class << self
      class << self
        def bar; end
      end
    end
  end
end
