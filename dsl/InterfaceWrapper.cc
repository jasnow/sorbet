#include "dsl/InterfaceWrapper.h"
#include "ast/Helpers.h"
#include "ast/ast.h"
#include "core/Context.h"
#include "core/Names.h"
#include "core/core.h"
#include "core/errors/dsl.h"
#include "dsl/dsl.h"
#include "dsl/util.h"

using namespace std;

namespace sorbet::dsl {
unique_ptr<ast::Expression> InterfaceWrapper::replaceDSL(core::MutableContext ctx, unique_ptr<ast::Send> send) {
    if (ctx.state.runningUnderAutogen) {
        return send;
    }

    if (send->fun != core::Names::wrapInstance()) {
        return send;
    }

    if (!ast::isa_tree<ast::UnresolvedConstantLit>(send->recv.get())) {
        if (auto e = ctx.state.beginError(send->recv->loc, core::errors::DSL::BadWrapInstance)) {
            e.setHeader("Unsupported wrap_instance() on a non-constant-literal");
        }
        return send;
    }

    if (send->args.size() != 1) {
        if (auto e = ctx.state.beginError(send->loc, core::errors::DSL::BadWrapInstance)) {
            e.setHeader("Wrong number of arguments to `{}`. Expected: `{}`, got: `{}`", "wrap_instance", 0,
                        send->args.size());
        }
        return send;
    }

    return ast::MK::Let(send->loc, move(send->args.front()), move(send->recv));
}
} // namespace sorbet::dsl
