# typed: true
extend T::Sig

sig {returns(Integer)}
def foo
  3
end
foo + :sym # error: `Symbol(:"sym")` doesn't match `Integer` for argument `arg0`