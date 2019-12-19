#include "rewriter/MixinEncryptedProp.h"
#include "ast/Helpers.h"
#include "ast/ast.h"
#include "core/Context.h"
#include "core/core.h"
#include "rewriter/Util.h"

using namespace std;

namespace sorbet::rewriter {

unique_ptr<ast::Expression> mkNilableEncryptedValue(core::MutableContext ctx, core::Loc loc) {
    auto opus = ast::MK::UnresolvedConstant(loc, ast::MK::EmptyTree(), core::Names::Constants::Opus());
    auto db = ast::MK::UnresolvedConstant(loc, move(opus), core::Names::Constants::DB());
    auto model = ast::MK::UnresolvedConstant(loc, move(db), core::Names::Constants::Model());
    auto mixins = ast::MK::UnresolvedConstant(loc, move(model), core::Names::Constants::Mixins());
    auto enc = ast::MK::UnresolvedConstant(loc, move(mixins), core::Names::Constants::Encryptable());
    auto ev = ast::MK::UnresolvedConstant(loc, move(enc), core::Names::Constants::EncryptedValue());
    return ASTUtil::mkNilable(loc, move(ev));
}

unique_ptr<ast::Expression> mkNilableString(core::Loc loc) {
    return ASTUtil::mkNilable(loc, ast::MK::Constant(loc, core::Symbols::String()));
}

vector<unique_ptr<ast::Expression>> MixinEncryptedProp::run(core::MutableContext ctx, ast::Send *send) {
    vector<unique_ptr<ast::Expression>> empty;

    if (ctx.state.runningUnderAutogen) {
        return empty;
    }

    bool isImmutable = false; // Are there no setters?
    core::NameRef name = core::NameRef::noName();
    core::NameRef enc_name = core::NameRef::noName();

    if (send->fun._id != core::Names::encryptedProp()._id) {
        return empty;
    }
    if (send->args.empty()) {
        return empty;
    }

    auto loc = send->loc;
    auto *sym = ast::cast_tree<ast::Literal>(send->args[0].get());
    if (!sym || !sym->isSymbol(ctx)) {
        return empty;
    }
    name = sym->asSymbol(ctx);
    ENFORCE(sym->loc.source(ctx).size() > 1 && sym->loc.source(ctx)[0] == ':');
    auto nameLoc = core::Loc(sym->loc.file(), sym->loc.beginPos() + 1, sym->loc.endPos());
    enc_name = name.prepend(ctx, "encrypted_");

    ast::Hash *rules = nullptr;
    if (!send->args.empty()) {
        rules = ast::cast_tree<ast::Hash>(send->args.back().get());
    }

    if (rules) {
        if (ASTUtil::hasTruthyHashValue(ctx, *rules, core::Names::immutable())) {
            isImmutable = true;
        }
    }

    vector<unique_ptr<ast::Expression>> stats;

    // Compute the getters

    stats.emplace_back(ast::MK::Sig(loc, ast::MK::Hash0(loc), mkNilableString(loc)));
    stats.emplace_back(ASTUtil::mkGet(loc, name, ast::MK::Cast(loc, mkNilableString(loc))));

    stats.emplace_back(ast::MK::Sig(loc, ast::MK::Hash0(loc), mkNilableEncryptedValue(ctx, loc)));
    stats.emplace_back(ASTUtil::mkGet(loc, enc_name, ast::MK::Cast(loc, mkNilableEncryptedValue(ctx, loc))));
    core::NameRef setName = name.addEq(ctx);
    core::NameRef setEncName = enc_name.addEq(ctx);

    // Compute the setter
    if (!isImmutable) {
        stats.emplace_back(
            ast::MK::Sig(loc, ast::MK::Hash1(loc, ast::MK::Symbol(nameLoc, core::Names::arg0()), mkNilableString(loc)),
                         mkNilableString(loc)));
        stats.emplace_back(ASTUtil::mkSet(loc, setName, nameLoc, ast::MK::Cast(loc, mkNilableString(loc))));

        stats.emplace_back(ast::MK::Sig(
            loc, ast::MK::Hash1(loc, ast::MK::Symbol(nameLoc, core::Names::arg0()), mkNilableEncryptedValue(ctx, loc)),
            mkNilableEncryptedValue(ctx, loc)));
        stats.emplace_back(
            ASTUtil::mkSet(loc, setEncName, nameLoc, ast::MK::Cast(loc, mkNilableEncryptedValue(ctx, loc))));
    }

    // Compute the Mutator
    {
        // Compute a setter
        ast::ClassDef::RHS_store rhs;
        rhs.emplace_back(
            ast::MK::Sig(loc, ast::MK::Hash1(nameLoc, ast::MK::Symbol(loc, core::Names::arg0()), mkNilableString(loc)),
                         mkNilableString(loc)));
        rhs.emplace_back(ASTUtil::mkSet(loc, setName, nameLoc, ast::MK::Cast(loc, mkNilableString(loc))));

        rhs.emplace_back(ast::MK::Sig(
            loc, ast::MK::Hash1(loc, ast::MK::Symbol(nameLoc, core::Names::arg0()), mkNilableEncryptedValue(ctx, loc)),
            mkNilableEncryptedValue(ctx, loc)));
        rhs.emplace_back(
            ASTUtil::mkSet(loc, setEncName, nameLoc, ast::MK::Cast(loc, mkNilableEncryptedValue(ctx, loc))));
    }

    return stats;
}

}; // namespace sorbet::rewriter
