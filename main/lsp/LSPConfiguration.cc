#include "main/lsp/LSPConfiguration.h"
#include "absl/strings/match.h"
#include "absl/strings/str_replace.h"
#include "common/FileOps.h"

using namespace std;

namespace sorbet::realmain::lsp {

constexpr string_view sorbetScheme = "sorbet:";
constexpr string_view httpsScheme = "https";

string getRootPath(const options::Options &opts, const shared_ptr<spdlog::logger> &logger) {
    if (opts.rawInputDirNames.size() != 1) {
        logger->error("Sorbet's language server requires a single input directory.");
        throw options::EarlyReturnWithCode(1);
    }
    return opts.rawInputDirNames.at(0);
}

LSPConfiguration::LSPConfiguration(const options::Options &opts, const shared_ptr<spdlog::logger> &logger,
                                   bool skipConfigatron, bool disableFastPath)
    : opts(opts), logger(logger), skipConfigatron(skipConfigatron), disableFastPath(disableFastPath),
      rootPath(getRootPath(opts, logger)) {}

void LSPConfiguration::configure(const InitializeParams &params) {
    if (auto rootUriString = get_if<string>(&params.rootUri)) {
        if (absl::EndsWith(*rootUriString, "/")) {
            rootUri = rootUriString->substr(0, rootUriString->length() - 1);
        } else {
            rootUri = *rootUriString;
        }
    }
    clientCompletionItemSnippetSupport = false;
    clientHoverMarkupKind = MarkupKind::Plaintext;
    if (params.capabilities->textDocument) {
        auto &textDocument = *params.capabilities->textDocument;
        if (textDocument->completion) {
            auto &completion = *textDocument->completion;
            if (completion->completionItem) {
                clientCompletionItemSnippetSupport = (*completion->completionItem)->snippetSupport.value_or(false);
            }
        }
        if (textDocument->hover) {
            auto &hover = *textDocument->hover;
            if (hover->contentFormat) {
                auto &contentFormat = *hover->contentFormat;
                clientHoverMarkupKind =
                    find(contentFormat.begin(), contentFormat.end(), MarkupKind::Markdown) != contentFormat.end()
                        ? MarkupKind::Markdown
                        : MarkupKind::Plaintext;
            }
        }
    }

    if (params.initializationOptions) {
        auto &initOptions = *params.initializationOptions;
        enableOperationNotifications = initOptions->supportsOperationNotifications.value_or(false);
        enableTypecheckInfo = initOptions->enableTypecheckInfo.value_or(false);
        enableSorbetURIs = initOptions->supportsSorbetURIs.value_or(false);
    }
}

unique_ptr<core::Loc> LSPConfiguration::lspPos2Loc(const core::FileRef fref, const Position &pos,
                                                   const core::GlobalState &gs) const {
    core::Loc::Detail reqPos;
    reqPos.line = pos.line + 1;
    reqPos.column = pos.character + 1;
    auto offset = core::Loc::pos2Offset(fref.data(gs), reqPos);
    return make_unique<core::Loc>(core::Loc(fref, offset, offset));
}

string LSPConfiguration::localName2Remote(string_view filePath) const {
    ENFORCE(absl::StartsWith(filePath, rootPath));
    string_view relativeUri = filePath.substr(rootPath.length());
    if (relativeUri.at(0) == '/') {
        relativeUri = relativeUri.substr(1);
    }

    // Special case: Root uri is '' (happens in Monaco)
    if (rootUri.length() == 0) {
        return string(relativeUri);
    }

    // Use a sorbet: URI if the file is not present on the client AND the client supports sorbet: URIs
    if (enableSorbetURIs && FileOps::isFileIgnored(rootPath, filePath, opts.lspDirsMissingFromClient, {})) {
        return absl::StrCat(sorbetScheme, relativeUri);
    }
    return absl::StrCat(rootUri, "/", relativeUri);
}

string LSPConfiguration::remoteName2Local(string_view uri) const {
    const bool isSorbetURI = absl::StartsWith(uri, sorbetScheme);
    if (!absl::StartsWith(uri, rootUri) && !enableSorbetURIs && !isSorbetURI) {
        logger->error("Unrecognized URI received from client: {}", uri);
        return string(uri);
    }

    const string_view root = isSorbetURI ? sorbetScheme : rootUri;
    const char *start = uri.data() + root.length();
    if (*start == '/') {
        ++start;
    }

    string path = string(start, uri.end());
    // Note: May be `https://` or `https%3A//`. VS Code URLencodes the : in sorbet:https:// paths.
    const bool isHttps = isSorbetURI && absl::StartsWith(path, httpsScheme) && path.length() > httpsScheme.length() &&
                         (path[httpsScheme.length()] == ':' || path[httpsScheme.length()] == '%');
    if (isHttps) {
        // URL decode the :
        return absl::StrReplaceAll(path, {{"%3A", ":"}});
    } else if (rootPath.length() > 0) {
        return absl::StrCat(rootPath, "/", path);
    } else {
        // Special case: Folder is '' (current directory)
        return path;
    }
}

core::FileRef LSPConfiguration::uri2FileRef(const core::GlobalState &gs, string_view uri) const {
    if (!absl::StartsWith(uri, rootUri) && !absl::StartsWith(uri, sorbetScheme)) {
        return core::FileRef();
    }
    auto needle = remoteName2Local(uri);
    return gs.findFileByPath(needle);
}

string LSPConfiguration::fileRef2Uri(const core::GlobalState &gs, core::FileRef file) const {
    string uri;
    if (!file.exists()) {
        uri = "???";
    } else {
        auto &messageFile = file.data(gs);
        if (messageFile.isPayload()) {
            if (enableSorbetURIs) {
                uri = absl::StrCat(sorbetScheme, messageFile.path());
            } else {
                uri = string(messageFile.path());
            }
        } else {
            uri = localName2Remote(file.data(gs).path());
        }
    }
    return uri;
}

unique_ptr<Location> LSPConfiguration::loc2Location(const core::GlobalState &gs, core::Loc loc) const {
    auto range = Range::fromLoc(gs, loc);
    if (range == nullptr) {
        return nullptr;
    }
    string uri = fileRef2Uri(gs, loc.file());
    if (loc.file().exists() && loc.file().data(gs).isPayload() && !enableSorbetURIs) {
        // This is hacky because VSCode appends #4,3 (or whatever the position is of the
        // error) to the uri before it shows it in the UI since this is the format that
        // VSCode uses to denote which location to jump to. However, if you append #L4
        // to the end of the uri, this will work on github (it will ignore the #4,3)
        //
        // As an example, in VSCode, on hover you might see
        //
        // string.rbi(18,7): Method `+` has specified type of argument `arg0` as `String`
        //
        // When you click on the link, in the browser it appears as
        // https://git.corp.stripe.com/stripe-internal/ruby-typer/tree/master/rbi/core/string.rbi#L18%2318,7
        // but shows you the same thing as
        // https://git.corp.stripe.com/stripe-internal/ruby-typer/tree/master/rbi/core/string.rbi#L18
        uri = fmt::format("{}#L{}", uri, loc.position(gs).first.line);
    }
    return make_unique<Location>(uri, std::move(range));
}

bool LSPConfiguration::isFileIgnored(std::string_view filePath) const {
    return FileOps::isFileIgnored(rootPath, filePath, opts.absoluteIgnorePatterns, opts.relativeIgnorePatterns);
}

} // namespace sorbet::realmain::lsp
