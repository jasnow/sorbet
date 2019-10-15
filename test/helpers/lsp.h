#ifndef TEST_HELPERS_LSP_H
#define TEST_HELPERS_LSP_H

#include "main/lsp/LSPMessage.h"
#include "main/lsp/json_types.h"
#include "main/lsp/wrapper.h"

namespace sorbet::test {
using namespace sorbet::realmain::lsp;

std::string filePathToUri(std::string_view prefixUrl, std::string_view filePath);

std::string uriToFilePath(std::string_view prefixUrl, std::string_view uri);

/** Creates the parameters to the `initialize` message, which advertises the client's capabilities. */
std::unique_ptr<InitializeParams>
makeInitializeParams(std::variant<std::string, JSONNullObject> rootPath,
                     std::variant<std::string, JSONNullObject> rootUri, bool supportsMarkdown,
                     std::optional<std::unique_ptr<SorbetInitializationOptions>> initOptions);

/** Create an LSPMessage containing a textDocument/definition request. */
std::unique_ptr<LSPMessage> makeDefinitionRequest(int id, std::string_view uri, int line, int character);

/** Create an LSPMessage containing a textDocument/didChange request. */
std::unique_ptr<LSPMessage> makeDidChange(std::string_view uri, std::string_view contents, int version);

/** Checks that we are properly advertising Sorbet LSP's capabilities to clients. */
void checkServerCapabilities(const ServerCapabilities &capabilities);

/** Asserts that the LSPMessage is a ResponseMessage with the given id. */
void assertResponseMessage(int expectedId, const LSPMessage &response);

/** Asserts that the LSPMessage is a ResponseMessage with an error of the given code and that
 * contains the given message. */
void assertResponseError(int code, std::string_view msg, const LSPMessage &response);

/** Asserts that the LSPMessage is a NotificationMessage with the given method. */
void assertNotificationMessage(const LSPMethod expectedMethod, const LSPMessage &response);

/** Retrieves the PublishDiagnosticsParam from a publishDiagnostics message, if applicable. Non-fatal fails and returns
 * an empty optional if it cannot be found. */
std::optional<PublishDiagnosticsParams *> getPublishDiagnosticParams(NotificationMessage &notifMsg);

/** Use the LSPWrapper to make a textDocument/completion request.
 */
std::unique_ptr<CompletionList> doTextDocumentCompletion(LSPWrapper &lspWrapper, const Range &range, int &nextId,
                                                         std::string_view filename, std::string_view uriPrefix);

/** Sends boilerplate initialization / initialized messages to start a new LSP session. */
std::vector<std::unique_ptr<LSPMessage>>
initializeLSP(std::string_view rootPath, std::string_view rootUri, LSPWrapper &lspWrapper, int &nextId,
              bool supportsMarkdown = true,
              std::optional<std::unique_ptr<SorbetInitializationOptions>> initOptions = std::nullopt);

} // namespace sorbet::test
#endif // TEST_HELPERS_LSP_H
