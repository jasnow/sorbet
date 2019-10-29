#include "gtest/gtest.h"
// has to go first as it violates are requirements
#include "ast/ast.h"
#include "ast/desugar/Desugar.h"
#include "common/common.h"
#include "core/Error.h"
#include "core/ErrorQueue.h"
#include "core/Names.h"
#include "core/Unfreeze.h"
#include "dsl/dsl.h"
#include "flattener/flatten.h"
#include "infer/infer.h"
#include "local_vars/local_vars.h"
#include "namer/namer.h"
#include "resolver/resolver.h"
#include "spdlog/spdlog.h"
// has to come before the next one. This comment stops formatter from reordering them
#include "spdlog/sinks/stdout_color_sinks.h"
#include <fstream>
#include <memory>

namespace spd = spdlog;
using namespace std;

namespace sorbet::infer::test {

auto logger = spd::stderr_color_mt("infer_test");
auto errorQueue = make_shared<sorbet::core::ErrorQueue>(*logger, *logger);

class InferFixture : public ::testing::Test {
public:
    void SetUp() override {
        ctxPtr = make_unique<core::GlobalState>(errorQueue);
        ctxPtr->initEmpty();
    }
    core::MutableContext getCtx() {
        return core::MutableContext(*ctxPtr, core::Symbols::root());
    }

private:
    unique_ptr<core::GlobalState> ctxPtr;
};

void processSource(core::GlobalState &cb, string str) {
    sorbet::core::UnfreezeNameTable nt(cb);
    sorbet::core::UnfreezeSymbolTable st(cb);
    sorbet::core::UnfreezeFileTable ft(cb);
    auto ast = parser::Parser::run(cb, "<test>", str);
    sorbet::core::MutableContext ctx(cb, core::Symbols::root());
    auto fileId = ast->loc.file();
    auto tree = ast::ParsedFile{ast::desugar::node2Tree(ctx, move(ast)), fileId};
    tree.tree = dsl::DSL::run(ctx, move(tree.tree));
    tree = local_vars::LocalVars::run(ctx, move(tree));
    vector<ast::ParsedFile> trees;
    trees.emplace_back(move(tree));
    trees = namer::Namer::run(ctx, move(trees));
    auto workers = WorkerPool::create(0, *logger);
    resolver::Resolver::run(ctx, move(trees), *workers);
    for (auto &tree : trees) {
        tree = flatten::runOne(ctx, move(tree));
    }
}

TEST_F(InferFixture, LiteralsSubtyping) { // NOLINT
    auto ctx = getCtx();
    auto intLit = core::make_type<core::LiteralType>(int64_t(1));
    auto intClass = core::make_type<core::ClassType>(core::Symbols::Integer());
    auto floatLit = core::make_type<core::LiteralType>(1.0f);
    auto floatClass = core::make_type<core::ClassType>(core::Symbols::Float());
    auto trueLit = core::make_type<core::LiteralType>(true);
    auto trueClass = core::make_type<core::ClassType>(core::Symbols::TrueClass());
    auto stringLit = core::make_type<core::LiteralType>(core::Symbols::String(), core::Names::assignTemp());
    auto stringClass = core::make_type<core::ClassType>(core::Symbols::String());
    EXPECT_TRUE(core::Types::isSubType(ctx, intLit, intClass));
    EXPECT_TRUE(core::Types::isSubType(ctx, floatLit, floatClass));
    EXPECT_TRUE(core::Types::isSubType(ctx, trueLit, trueClass));
    EXPECT_TRUE(core::Types::isSubType(ctx, stringLit, stringClass));

    EXPECT_TRUE(core::Types::isSubType(ctx, intLit, intLit));
    EXPECT_TRUE(core::Types::isSubType(ctx, floatLit, floatLit));
    EXPECT_TRUE(core::Types::isSubType(ctx, trueLit, trueLit));
    EXPECT_TRUE(core::Types::isSubType(ctx, stringLit, stringLit));

    EXPECT_FALSE(core::Types::isSubType(ctx, intClass, intLit));
    EXPECT_TRUE(core::Types::isSubType(ctx, core::Types::top(), core::Types::untypedUntracked()));
    EXPECT_TRUE(core::Types::isSubType(ctx, core::Types::untypedUntracked(), core::Types::top()));
}

TEST_F(InferFixture, ClassesSubtyping) { // NOLINT
    auto ctx = getCtx();
    processSource(ctx, "class Bar; end; class Foo < Bar; end");
    const auto &rootScope = core::Symbols::root().data(ctx);

    auto barSymbol = rootScope->findMember(ctx, ctx.state.enterNameConstant("Bar"));
    auto fooSymbol = rootScope->findMember(ctx, ctx.state.enterNameConstant("Foo"));
    ASSERT_EQ("<C <U Bar>>", barSymbol.data(ctx)->name.data(ctx)->showRaw(ctx));
    ASSERT_EQ("<C <U Foo>>", fooSymbol.data(ctx)->name.data(ctx)->showRaw(ctx));

    auto barType = core::make_type<core::ClassType>(barSymbol);
    auto fooType = core::make_type<core::ClassType>(fooSymbol);

    ASSERT_TRUE(core::Types::isSubType(ctx, fooType, barType));
    ASSERT_TRUE(core::Types::isSubType(ctx, fooType, fooType));
    ASSERT_TRUE(core::Types::isSubType(ctx, barType, barType));
    ASSERT_FALSE(core::Types::isSubType(ctx, barType, fooType));
}

TEST_F(InferFixture, ClassesLubs) { // NOLINT
    auto ctx = getCtx();
    processSource(ctx, "class Bar; end; class Foo1 < Bar; end; class Foo2 < Bar;  end");
    const auto &rootScope = core::Symbols::root().data(ctx);

    auto barSymbol = rootScope->findMember(ctx, ctx.state.enterNameConstant("Bar"));
    auto foo1Symbol = rootScope->findMember(ctx, ctx.state.enterNameConstant("Foo1"));
    auto foo2Symbol = rootScope->findMember(ctx, ctx.state.enterNameConstant("Foo2"));
    ASSERT_EQ("<C <U Bar>>", barSymbol.data(ctx)->name.data(ctx)->showRaw(ctx));
    ASSERT_EQ("<C <U Foo1>>", foo1Symbol.data(ctx)->name.data(ctx)->showRaw(ctx));
    ASSERT_EQ("<C <U Foo2>>", foo2Symbol.data(ctx)->name.data(ctx)->showRaw(ctx));

    auto barType = core::make_type<core::ClassType>(barSymbol);
    auto foo1Type = core::make_type<core::ClassType>(foo1Symbol);
    auto foo2Type = core::make_type<core::ClassType>(foo2Symbol);

    auto barNfoo1 = core::Types::any(ctx, barType, foo1Type);
    auto foo1Nbar = core::Types::any(ctx, foo1Type, barType);
    auto barNfoo2 = core::Types::any(ctx, barType, foo2Type);
    auto foo2Nbar = core::Types::any(ctx, foo2Type, barType);
    auto foo1Nfoo2 = core::Types::any(ctx, foo1Type, foo2Type);
    auto foo2Nfoo1 = core::Types::any(ctx, foo2Type, foo1Type);

    ASSERT_EQ("ClassType", barNfoo1->typeName());
    ASSERT_TRUE(core::Types::isSubType(ctx, barType, barNfoo1));
    ASSERT_TRUE(core::Types::isSubType(ctx, foo1Type, barNfoo1));
    ASSERT_EQ("ClassType", barNfoo2->typeName());
    ASSERT_TRUE(core::Types::isSubType(ctx, barType, barNfoo2));
    ASSERT_TRUE(core::Types::isSubType(ctx, foo2Type, barNfoo2));
    ASSERT_EQ("ClassType", foo1Nbar->typeName());
    ASSERT_TRUE(core::Types::isSubType(ctx, barType, foo1Nbar));
    ASSERT_TRUE(core::Types::isSubType(ctx, foo1Type, foo1Nbar));
    ASSERT_EQ("ClassType", foo2Nbar->typeName());
    ASSERT_TRUE(core::Types::isSubType(ctx, barType, foo2Nbar));
    ASSERT_TRUE(core::Types::isSubType(ctx, foo2Type, foo2Nbar));

    ASSERT_TRUE(core::Types::equiv(ctx, barNfoo2, foo2Nbar));
    ASSERT_TRUE(core::Types::equiv(ctx, barNfoo1, foo1Nbar));
    ASSERT_TRUE(core::Types::equiv(ctx, foo1Nfoo2, foo2Nfoo1));

    auto intType = core::make_type<core::ClassType>(core::Symbols::Integer());
    auto intNfoo1 = core::Types::any(ctx, foo1Type, intType);
    auto intNbar = core::Types::any(ctx, barType, intType);
    auto intNfoo1Nbar = core::Types::any(ctx, intNfoo1, barType);
    ASSERT_TRUE(core::Types::equiv(ctx, intNfoo1Nbar, intNbar));
    auto intNfoo1Nfoo2 = core::Types::any(ctx, intNfoo1, foo2Type);
    auto intNfoo1Nfoo2Nbar = core::Types::any(ctx, intNfoo1Nfoo2, barType);
    ASSERT_TRUE(core::Types::equiv(ctx, intNfoo1Nfoo2Nbar, intNbar));
}

TEST_F(InferFixture, ClassesGlbs) { // NOLINT
    auto ctx = getCtx();
    processSource(ctx, "class Bar; end; class Foo1 < Bar; end; class Foo2 < Bar;  end");
    const auto &rootScope = core::Symbols::root().data(ctx);

    auto barSymbol = rootScope->findMember(ctx, ctx.state.enterNameConstant("Bar"));
    auto foo1Symbol = rootScope->findMember(ctx, ctx.state.enterNameConstant("Foo1"));
    auto foo2Symbol = rootScope->findMember(ctx, ctx.state.enterNameConstant("Foo2"));
    ASSERT_EQ("<C <U Bar>>", barSymbol.data(ctx)->name.data(ctx)->showRaw(ctx));
    ASSERT_EQ("<C <U Foo1>>", foo1Symbol.data(ctx)->name.data(ctx)->showRaw(ctx));
    ASSERT_EQ("<C <U Foo2>>", foo2Symbol.data(ctx)->name.data(ctx)->showRaw(ctx));

    auto barType = core::make_type<core::ClassType>(barSymbol);
    auto foo1Type = core::make_type<core::ClassType>(foo1Symbol);
    auto foo2Type = core::make_type<core::ClassType>(foo2Symbol);

    auto barOrfoo1 = core::Types::all(ctx, barType, foo1Type);
    auto foo1Orbar = core::Types::all(ctx, foo1Type, barType);
    auto barOrfoo2 = core::Types::all(ctx, barType, foo2Type);
    auto foo2Orbar = core::Types::all(ctx, foo2Type, barType);
    auto foo1Orfoo2 = core::Types::all(ctx, foo1Type, foo2Type);
    auto foo2Orfoo1 = core::Types::all(ctx, foo2Type, foo1Type);

    ASSERT_EQ("ClassType", barOrfoo1->typeName());
    ASSERT_TRUE(core::Types::isSubType(ctx, barOrfoo1, barType));
    ASSERT_TRUE(core::Types::isSubType(ctx, barOrfoo1, foo1Type));
    ASSERT_EQ("ClassType", barOrfoo2->typeName());
    ASSERT_TRUE(core::Types::isSubType(ctx, barOrfoo2, barType));
    ASSERT_TRUE(core::Types::isSubType(ctx, barOrfoo2, foo2Type));
    ASSERT_EQ("ClassType", foo1Orbar->typeName());
    ASSERT_TRUE(core::Types::isSubType(ctx, foo1Orbar, barType));
    ASSERT_TRUE(core::Types::isSubType(ctx, foo1Orbar, foo1Type));
    ASSERT_EQ("ClassType", foo2Orbar->typeName());
    ASSERT_TRUE(core::Types::isSubType(ctx, foo2Orbar, barType));
    ASSERT_TRUE(core::Types::isSubType(ctx, foo2Orbar, foo2Type));

    ASSERT_TRUE(core::Types::equiv(ctx, barOrfoo2, foo2Orbar));
    ASSERT_TRUE(core::Types::equiv(ctx, barOrfoo1, foo1Orbar));
    ASSERT_TRUE(core::Types::equiv(ctx, foo1Orfoo2, foo2Orfoo1));
}

} // namespace sorbet::infer::test
