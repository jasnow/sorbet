#include "rewriter/DefaultArgs.h"
#include "ast/Helpers.h"
#include "ast/treemap/treemap.h"
#include "common/typecase.h"
#include "core/GlobalState.h"

using namespace std;

namespace sorbet::rewriter {

unique_ptr<ast::Expression> mangleSig(core::Context ctx, unique_ptr<ast::Expression> expr, ast::Expression *param) {
    auto sig = ast::cast_tree<ast::Send>(expr.get());
    ENFORCE(sig);
    ENFORCE(sig->fun == core::Names::sig());

    if (auto kw = ast::cast_tree<ast::KeywordArg>(param)) {
        param = kw->expr.get();
    }

    auto ident = ast::cast_tree<ast::UnresolvedIdent>(param);
    if (!ident) {
        return ast::MK::EmptyTree();
    }
    auto name = ident->name;

    unique_ptr<ast::Expression> retType;

    if (sig->block == nullptr) {
        return ast::MK::EmptyTree();
    }

    auto send = ast::cast_tree<ast::Send>(sig->block->body.get());
    if (!send) {
        return ast::MK::EmptyTree();
    }

    while (send != nullptr) {
        switch (send->fun._id) {
            case core::Names::params()._id: {
                if (send->args.size() != 1) {
                    return ast::MK::EmptyTree();
                }
                auto *hash = ast::cast_tree<ast::Hash>(send->args[0].get());
                if (!hash) {
                    return ast::MK::EmptyTree();
                }
                int i = -1;
                for (auto &key : hash->keys) {
                    i++;
                    auto &value = hash->values[i];
                    auto lit = ast::cast_tree<ast::Literal>(key.get());
                    if (lit && lit->isSymbol(ctx)) {
                        auto symName = lit->asSymbol(ctx);
                        if (name == symName) {
                            retType = value->deepCopy();
                        }
                    }
                }
                break;
            }

            case core::Names::abstract()._id: {
                // Don't make this method at all since abstract methods can't
                // have bodies
                return nullptr;
            }

            case core::Names::override_()._id: {
                // A total hack but we allow .void.void or .void.returns and
                // the one with content wins
                send->fun = core::Names::void_();
            }
        }
        auto recv = ast::cast_tree<ast::Send>(send->recv.get());
        send = recv;
    }

    send = ast::cast_tree<ast::Send>(sig->block->body.get());
    while (send != nullptr) {
        switch (send->fun._id) {
            case core::Names::returns()._id: {
                if (!retType) {
                    return ast::MK::EmptyTree();
                }
                send->args[0] = move(retType);
                break;
            }

            case core::Names::void_()._id: {
                if (!retType) {
                    return ast::MK::EmptyTree();
                }
                send->fun = core::Names::returns();
                send->args.emplace_back(move(retType));
                break;
            }
        }

        auto recv = ast::cast_tree<ast::Send>(send->recv.get());
        send = recv;
    }
    return expr;
}

static std::unique_ptr<ast::Reference> dupRef(ast::Reference *arg) {
    unique_ptr<ast::Reference> newArg;
    typecase(
        arg, [&](ast::UnresolvedIdent *nm) { newArg = ast::MK::Local(arg->loc, nm->name); },
        [&](ast::RestArg *rest) { newArg = ast::MK::RestArg(arg->loc, dupRef(rest->expr.get())); },
        [&](ast::KeywordArg *kw) { newArg = ast::MK::KeywordArg(arg->loc, dupRef(kw->expr.get())); },
        [&](ast::OptionalArg *opt) {
            newArg = ast::MK::OptionalArg(arg->loc, dupRef(opt->expr.get()), ast::MK::EmptyTree());
        },
        [&](ast::BlockArg *blk) { newArg = ast::MK::BlockArg(arg->loc, dupRef(blk->expr.get())); },
        [&](ast::ShadowArg *shadow) { newArg = ast::MK::ShadowArg(arg->loc, dupRef(shadow->expr.get())); });
    return newArg;
}

void DefaultArgs::run(core::MutableContext ctx, ast::ClassDef *klass) {
    vector<unique_ptr<ast::Expression>> newMethods;
    ast::Send *lastSig = nullptr;
    bool isOverload = false;

    for (auto &stat : klass->rhs) {
        typecase(
            stat.get(),
            [&](ast::Send *send) {
                if (send->fun != core::Names::sig()) {
                    return;
                }
                if (lastSig != nullptr) {
                    isOverload = true;
                    return;
                }
                lastSig = send;
            },
            [&](ast::MethodDef *mdef) {
                if (isOverload) {
                    // Overloaded methods have multiple signatures, not all of
                    // which include all the arguments. Programatically copying
                    // them over and figuring out which ones apply to which
                    // defaults and how is super hard. This is one of the
                    // reasons we don't let users write them, and only have them
                    // in the stdlib.
                    return;
                }
                auto i = -1;
                auto uniqueNum = 1;
                for (auto &methodArg : mdef->args) {
                    ++i;
                    auto arg = ast::cast_tree<ast::OptionalArg>(methodArg.get());
                    if (!arg) {
                        continue;
                    }

                    ENFORCE(ast::isa_tree<ast::UnresolvedIdent>(arg->expr.get()) ||
                            ast::isa_tree<ast::KeywordArg>(arg->expr.get()));
                    auto name = ctx.state.freshNameUnique(core::UniqueNameKind::DefaultArg, mdef->name, uniqueNum++);
                    ast::MethodDef::ARGS_store args;
                    for (auto &arg : mdef->args) {
                        auto ref = ast::cast_tree<ast::Reference>(arg.get());
                        args.emplace_back(dupRef(ref));
                    }
                    auto loc = arg->default_->loc;
                    auto rhs = move(arg->default_);
                    arg->default_ = ast::MK::EmptyTree();

                    if (lastSig) {
                        auto sig = mangleSig(ctx, lastSig->deepCopy(), arg->expr.get());
                        if (sig == nullptr) {
                            continue;
                        }
                        newMethods.emplace_back(move(sig));
                    }
                    newMethods.emplace_back(ast::MK::Method(loc, loc, name, std::move(args), std::move(rhs),
                                                            mdef->flags | ast::MethodDef::RewriterSynthesized));
                }
                lastSig = nullptr;
            },

            [&](ast::Expression *expr) {});
    }

    for (auto &stat : newMethods) {
        klass->rhs.emplace_back(move(stat));
    }
}

} // namespace sorbet::rewriter
