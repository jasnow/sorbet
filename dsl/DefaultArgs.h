#ifndef SORBET_DSL_DEFAULT_ARGS_H
#define SORBET_DSL_DEFAULT_ARGS_H
#include "ast/ast.h"

namespace sorbet::dsl {

/**
 * This class desugars things of the form
 *
 *   sig {params(arg0: String, arg1: Integer).void}
 *   def foo(arg0, arg1 = my_expr)
 *   end
 *
 * into
 *
 *   # TODO to insert the sig here
 *   # sig {params(arg0: String, arg1: Integer).returns(Integer)}
 *   def foo<defaultArg>1(arg0, arg1)
 *       my_expr
 *   end
 *   sig {params(arg0: String, arg1: Integer).void}
 *   def foo(arg0, arg1 = foo<defaultArg>2(arg0, arg1))
 *   end
 */
class DefaultArgs final {
public:
    static void patchDSL(core::MutableContext ctx, ast::ClassDef *klass);

    DefaultArgs() = delete;
};

} // namespace sorbet::dsl

#endif
