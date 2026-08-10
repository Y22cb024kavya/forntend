# Loop 4 Forensic Trace

## Turn 1

`_AhviStylistChatSheetState._sendMessage()` records
`I need something for tomorrow` in `_chatHistory`. It is an ordinary
canonical Style conversation and uses `BackendService.sendModuleChat()` with
`domain: style`, history, and `canonicalStyleContext`.

The canonical backend context resolver recognizes `tomorrow`. Because no
occasion/activity is known yet, the response may request clarification.

## Turn 2

The frontend scans the prior assistant response in
`_pendingStyleClarificationPrompt()`. When the response is an occasion
clarification, `I have a badminton game` becomes `isClarificationAnswer`.

Before this fix, `keepLegacyStyleText` included `isClarificationAnswer`, so the
request used `BackendService.sendChatQuery()` and `/api/text` instead of the
canonical module-chat path. The request carried text/history and legacy
clarification fields, but the legacy backend execution did not thread
`date_context`, `activity`, `activity_type`, or the resolved referent into the
Style reasoning call.

## Turn 3

`show visual inspiration for this` can remain attached to the stale pending
clarification because only rendered boards or a fresh clarification response
updated `_clarificationResolvedByCards`. It could therefore continue through
the legacy `/api/text` seam. The backend legacy occasion helper defaults
unknown context to `today`, while generic archetype selection can produce
Refined Weekend / Contemporary Classic directions rather than badminton
compatible directions.

## Backend Evidence

The canonical `/api/module-chat` path already resolves activity aliases,
relative dates, history, and referents in
`services/style_conversation_context.py`, and passes them to
`style_reasoning_engine.reason()`. The engine already has court-sport
compatibility filtering and safe fallbacks. The legacy `/api/text` path is the
context-loss seam; no backend change is required for this narrow fix.

## Fix and Validation

- Removed ordinary `isClarificationAnswer` from the legacy Style routing gate.
- Kept closest-option, wardrobe, board-mutation, and Style This actions on
  their existing dedicated path.
- Marked pending clarification resolved after a non-clarification response.
- Added a three-turn frontend integration regression. It confirms all turns
  use `domain: style` and `/api/module-chat`, no legacy request is made, and
  the final visual directions render.
- Backend continuity/activity/archetype/coherence tests: 67 passed.
- Flutter Style/chat/board suite: 108 passed.
- Affected frontend analyzer: 7 pre-existing findings, zero errors.
- No backend source or deployment change was made.

The mandatory correction matrix also found that the existing backend resolver
needed two narrow continuity improvements: recognize `dinner` as an occasion,
and clear superseded activity/occasion dimensions only for explicit correction
phrases. Existing semantic referent labels remain specific while current date
context is applied.

After that fix, the backend continuity/activity/archetype/coherence suite
passed 71 tests with two dependency warnings.
