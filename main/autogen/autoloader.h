#ifndef AUTOGEN_AUTOLOADER_H
#define AUTOGEN_AUTOLOADER_H
#include "ast/ast.h"
#include "main/autogen/autogen.h"
#include "main/options/options.h"
#include <string_view>

namespace sorbet::autogen {

// Contains same information as `realmain::options::AutoloaderConfig` except with `core::NameRef`s
// instead of strings.
struct AutoloaderConfig {
    static AutoloaderConfig enterConfig(core::GlobalState &gs, const realmain::options::AutoloaderConfig &cfg);

    bool include(const NamedDefinition &) const;
    bool includePath(std::string_view path) const;
    bool includeRequire(core::NameRef req) const;
    // Should definitions in this namespace be collapsed into their
    // parent if they all are from the same file?
    bool sameFileCollapsable(const std::vector<core::NameRef> &module) const;
    std::string_view normalizePath(core::Context ctx, core::FileRef file) const;

    std::string rootDir;
    std::string preamble;
    UnorderedSet<core::NameRef> topLevelNamespaceRefs;
    UnorderedSet<core::NameRef> excludedRequireRefs;
    UnorderedSet<std::vector<core::NameRef>> nonCollapsableModuleNames;
    std::vector<std::string> absoluteIgnorePatterns;
    std::vector<std::string> relativeIgnorePatterns;
    std::vector<std::string> stripPrefixes;

    AutoloaderConfig() = default;
    AutoloaderConfig(const AutoloaderConfig &) = delete;
    AutoloaderConfig(AutoloaderConfig &&) = default;
    AutoloaderConfig &operator=(const AutoloaderConfig &) = delete;
    AutoloaderConfig &operator=(AutoloaderConfig &&) = default;
};

struct NamedDefinition {
    static NamedDefinition fromDef(core::Context, ParsedFile &, DefinitionRef);
    static bool preferredTo(core::Context, const NamedDefinition &lhs, const NamedDefinition &rhs);

    Definition def;
    std::vector<core::NameRef> nameParts;
    std::vector<core::NameRef> parentName;
    std::vector<core::NameRef> requires;
    core::FileRef fileRef;
    u4 pathDepth;

    NamedDefinition() = default;
    NamedDefinition(const NamedDefinition &) = delete;
    NamedDefinition(NamedDefinition &&) = default;
    NamedDefinition &operator=(const NamedDefinition &) = delete;
    NamedDefinition &operator=(NamedDefinition &&) = default;
};

class DefTree {
public:
    UnorderedMap<core::NameRef, std::unique_ptr<DefTree>> children;

    // For definitions that define behavior we enforce that it is only from a single code location.
    // However some nodes may represent a name that is used in many places but where none define
    // behavior (e.g. a module that is only used for namespacing). In that case, deterministically
    // pick a single file to use for the definition based on NamedDefinition::preferredTo precedence
    // rules.
    std::vector<NamedDefinition> namedDefs;
    std::unique_ptr<NamedDefinition> nonBehaviorDef;
    std::vector<core::NameRef> nameParts;

    bool root() const;
    core::NameRef name() const;
    std::string path(core::Context ctx) const;
    std::string show(core::Context ctx, int level = 0) const; // Render the entire tree
    std::string fullName(core::Context) const;

    std::string renderAutoloadSrc(core::Context ctx, const AutoloaderConfig &) const;

    DefTree() = default;
    DefTree(const DefTree &) = delete;
    DefTree(DefTree &&) = default;
    DefTree &operator=(const DefTree &) = delete;
    DefTree &operator=(DefTree &&) = default;

private:
    core::FileRef file() const;
    void predeclare(core::Context ctx, std::string_view fullName, fmt::memory_buffer &buf) const;
    void requires(core::Context ctx, const AutoloaderConfig &, fmt::memory_buffer &buf) const;
    bool hasDifferentFile(core::FileRef) const;
    bool hasDef() const;
    const NamedDefinition &definition(core::Context) const;
    Definition::Type definitionType(core::Context) const;

    friend class DefTreeBuilder;
};

class DefTreeBuilder {
public:
    // Add all definitions in a parsed file to a `DefTree` root.
    static void addParsedFileDefinitions(core::Context, const AutoloaderConfig &, std::unique_ptr<DefTree> &root,
                                         ParsedFile &);
    static void addSingleDef(core::Context, const AutoloaderConfig &, std::unique_ptr<DefTree> &root, NamedDefinition);

    static DefTree merge(core::Context, DefTree lhs, DefTree rhs);
    static void collapseSameFileDefs(core::Context, const AutoloaderConfig &, DefTree &root);

private:
    static void updateNonBehaviorDef(core::Context, DefTree &node, NamedDefinition ndef);
};

class AutoloadWriter {
public:
    static void writeAutoloads(core::Context ctx, const AutoloaderConfig &, const std::string &path,
                               const DefTree &root);

private:
    static void write(core::Context ctx, const AutoloaderConfig &, const std::string &path,
                      UnorderedSet<std::string> &toDelete, const DefTree &node);
};

} // namespace sorbet::autogen
#endif // AUTOGEN_AUTOLOADER_H
