# typed: true
class Module
  include T::Sig
end

# This file tests that when sig suggestion fails to find a method def, it still
# suggests `sig` because it the name of a method in scope.

class Outer
  def above_query; end

  class Inner
    # Even though there are method defs after this, none are in the right
    # scope, so no suggested sig.

    sig # error: no block
    #  ^ apply-completion: [A] item: 0
  end

  def below_query; end
end

def outside_on_root; end

# No method def at all later in the file
sig # error: no block
#  ^ apply-completion: [B] item: 0
