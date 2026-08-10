# Loop 3 Forensic Trace

## Home Prompt Bar

`home.dart:_buildChatWrap()` renders `AhviChatPromptBar`. Its send callback
calls `_openChatWithPrompt(text)`, which calls
`showAhviStylistChatSheet(moduleContext: (_activeIntent ?? 'style'),
initialPrompt: text)`.

With the normal Style surface, the module is `style` and the prompt is
auto-sent by the sheet after the greeting.

## Style Me CTA

`home.dart:_buildStyleCard()` calls `_openModuleChat('style')`. That calls
`showAhviStylistChatSheet(moduleContext: 'style', initialPrompt: null)`.

Both calls enter `widgets/ahvi_stylist_chat.dart` and construct the same
`_AhviStylistChatSheet` with `moduleContext: style`.

## Shared Send Path

Both paths use `_AhviStylistChatSheetState._sendMessage()`:

- `_chatHistory` receives the user turn before the request.
- `styleActionContextFromValue()` returns null for ordinary colour questions.
- `keepLegacyStyleText` is false unless the prompt is Style This, a board
  action, a clarification answer, or another dedicated legacy action.
- `useCanonicalStyleModuleChat` is therefore true.
- `BackendService.sendModuleChat(domain: 'style', message: query,
  chatHistory: _chatHistory, context: canonicalStyleContext)` is used.
- The response is parsed by `AhviResponsePolicy`, then rendered as text or a
  board only when the canonical response permits it.

## Current Divergence

No semantic Home-versus-Style-Me divergence is present in the current source
for a fresh ordinary colour prompt. The only entry-point difference is
`initialPrompt`: Home auto-submits the supplied prompt; Style Me waits for the
user to submit it. Both requests otherwise share the same Style module path,
history construction, context construction, response policy, and renderer.

The reported refusal therefore cannot be attributed to a current frontend
entry-point split without a runtime/backend capture. It may originate from a
different deployed revision, backend response, or a non-fresh persisted user
session, but this must not be guessed into a frontend patch.

## Validation

- Home prompt and Style Me colour-advice parity test passed.
- Four-turn Style Me continuity test passed; every request retained the prior
  turns and used `domain: style`.
- Colour advice rendered text-only with no visual board.
- Final outfit request rendered the existing visual-direction board path.
- Existing Home Style Me suite passed: 8 tests.
- Broader Style/chat/board suite passed: 107 tests.
- Test analyzer: no issues.
- Affected source analyzer: 212 pre-existing warnings/info findings, no
  errors and no findings caused by this quick task.
- No production source, backend, routing, ranking, configuration, or
  deployment change was required.
