---
quick_id: 20260810-loop5-legacy-style-route-leakage
status: complete
---

# Legacy Style Route Leakage

## ALL STYLE ENDPOINT-SELECTION CONDITIONS

- `lib/widgets/ahvi_stylist_chat.dart`: `calendarReq != null` selects
  `/api/module-chat`; this is a calendar escape, not a legacy Style route.
- `lib/widgets/ahvi_stylist_chat.dart`: `isCanonicalStyleConversation` is true
  for `style` and `daily_wear`.
- `keepLegacyStyleText` selects `/api/text` when any of these is true:
  `isClosestStyleAction`, `isWardrobeAction`, `isBoardActionPhrase`, or
  `_isSpecializedStyleRequest(trimmed)`.
- `styleModules.contains(widget.moduleContext) && !isPlanPackRequest` is the
  legacy `sendChatQuery` fallback. It covers the retained dedicated `wardrobe`
  module and the explicit action families above.
- `lib/chat.dart`: `_requestMoreStyleBoards()` always calls `sendChatQuery`
  for explicit More Looks / different shoes board actions.
- `lib/chat.dart`: `styleViaText` selects `/api/text` for
  `isStyleModule && isClosestAction` only after this loop's fix.
- `lib/home.dart`: the old generic `_handleQuery()` calls `sendChatQuery`
  without a Style module context. Current Style entry points open the canonical
  Style sheet instead, so this is not an active Style conversation route.
- `lib/services/backend_service.dart`: `sendChatQuery()` is the explicit
  `/api/text` client; `sendModuleChat()` is the explicit `/api/module-chat`
  client.

## INTENTIONAL / UNINTENDED MATRIX

| Condition | Example | Endpoint | Classification | Coverage |
|---|---|---|---|---|
| `isClosestStyleAction` | Show closest option | `/api/text` | INTENTIONAL | backend legacy action tests |
| `isWardrobeAction` | Use my wardrobe for coffee date | `/api/text` | LEGACY BUT STILL REQUIRED | wardrobe action tests |
| `isBoardActionPhrase` | Show me another look / Shuffle | `/api/text` | INTENTIONAL | board mutation and more-options tests |
| `_isSpecializedStyleRequest` | Style this shirt | `/api/text` on Style sheet | INTENTIONAL | Style This contract/render tests |
| `widget.moduleContext == wardrobe` fallback | Wardrobe recommendation | `/api/text` | LEGACY BUT STILL REQUIRED | wardrobe style service tests |
| `isClarificationAnswer` in `chat.dart` before this loop | I have a warm undertone | `/api/text` | UNINTENDED | Loop 4 regression evidence |
| `isClarificationAnswer` in Style sheet | Any ordinary answer | `/api/module-chat` since Loop 4 | not a legacy route | endpoint-selection regression test |
| old Home `_handleQuery` | legacy overlay suggestion | `/api/text` | DEAD/UNREACHABLE for active Style | no active Style caller |

No UNKNOWN route was changed.

## ROOT CAUSE(S)

`lib/chat.dart` retained the old combined selector
`isClosestAction || isClarificationAnswer` after Loop 4 corrected the reusable
Style sheet. That left the older ChatScreen as a second ordinary clarification
leak. The legacy branch also supplied rich text-route parameters, while the
canonical branch supplies module history and structured context.

## LEGACY ROUTES RETAINED

- Closest-option actions.
- Wardrobe override actions and the dedicated Wardrobe module fallback.
- Explicit board mutations and More Looks / different shoes actions.
- Style This on the reusable Style sheet.

## LEGACY ROUTES REMOVED

- Ordinary Style clarification answers from `lib/chat.dart`.

## COLOUR REFUSAL EXPLANATION

RUNTIME EVIDENCE REQUIRED. Current Flutter parity tests route both Home and
Style Me colour advice through `/api/module-chat`, retain the four-turn history,
and return useful mocked advice. Source inspection finds no remaining colour-
specific predicate that selects `/api/text`. If reproduced on device, capture
the request id, endpoint, module/domain, message, history, context,
`response_mode`, `intent`, `resolved_context`, and response message fields.

## FILES CHANGED

- `lib/chat.dart`: remove clarification from the legacy selector.
- `test/style_endpoint_selection_test.dart`: endpoint, payload, and retained
  legacy-action source contracts.
- `.planning/quick/20260810-loop5-legacy-style-route-leakage/SUMMARY.md`:
  forensic and verification record.
- `.planning/STATE.md`: quick-task state entry.

## BEHAVIOUR BEFORE

The older `ChatScreen` sent an ordinary clarification answer to `/api/text`,
even when the conversation was already in Style context. That route could
lose canonical conversation resolution before the next turn.

## BEHAVIOUR AFTER

Both active Style surfaces keep ordinary follow-ups on `/api/module-chat` with
history and structured context. Only proven explicit legacy action families
remain on `/api/text`.

## CANONICAL ROUTE MATRIX

| Intent | Expected endpoint | Actual endpoint | Context/history | Response mode |
|---|---|---|---|---|
| A. Style information | `/api/module-chat` | `/api/module-chat` | history plus module context | `text_only` |
| B. Style advice | `/api/module-chat` | `/api/module-chat` | history plus module context | `text_only` |
| C. Personalised advice | `/api/module-chat` | `/api/module-chat` | history plus Style context | `text_only` |
| D. Clarification answer | `/api/module-chat` | `/api/module-chat` | history plus Style context | `clarification` or resolved next mode |
| E. Wardrobe recommendation | `/api/module-chat` | `/api/module-chat` on canonical Style sheet | history, context, wardrobe | `wardrobe_recommendation` or `clarification` when a slot is missing |
| F. Activity follow-up | `/api/module-chat` | `/api/module-chat` | date/activity remains in history/context | `clarification` or `wardrobe_recommendation` |
| G. Visual Inspiration | `/api/module-chat` | `/api/module-chat` | history, carried context, referent | `visual_inspiration` |
| H. Style This | dedicated Style This contract | `/api/text` on Style sheet; module chat on old ChatScreen | anchor identity is explicit where supported | `style_this` |
| I. Build Outfit | `/api/module-chat` for chat | `/api/module-chat` | history and selected-item context | `wardrobe_recommendation` |
| J. Modify current board | canonical board operation | `/api/module-chat` for ordinary typed revisions; dedicated legacy mutation remains `/api/text` | current board/revision when supplied | `wardrobe_recommendation` or `text_only` |
| K. Explain | `/api/module-chat` | `/api/module-chat` | history and current context | `text_only` |
| L. Constraint | `/api/module-chat` | `/api/module-chat` | history plus constraint context | `wardrobe_recommendation` or `clarification` |
| M. Referent follow-up | canonical context pipeline | `/api/module-chat` for ordinary follow-up; legacy `/api/text` for explicit More Looks phrase | history/referent retained | `visual_inspiration` or `wardrobe_recommendation` |

## CONTEXT CONTINUITY

The canonical frontend client sends `history` and `context`/`context_data`, and
the Style sheet adds `current_memory`, `last_style_context`, and `style_context`.
The backend stamps `resolved_context`, `explicit_context`, `carried_context`,
`context_used`, `requires_clarification`, and diagnostics. Date, activity,
occasion, negative constraints, referents, and explicit corrections are covered
by the existing backend continuity tests.

## RESPONSE MODE

Canonical `/api/module-chat` supports `text_only`, `clarification`,
`visual_inspiration`, `wardrobe_recommendation`, `style_this`, and board mutation
responses through the existing response envelope. The legacy `/api/text`
contract remains parameter-rich for closest, wardrobe, and board actions. The
old ChatScreen canonical branch passes only its `styleContext` plus history;
it does not separately pass the reusable sheet's `last_style_context` field.
That is an existing contract gap, not redesigned in this loop.

## FOCUSED TESTS

- Flutter endpoint and lifecycle tests: `17 passed`.
- Frontend endpoint-selection, clarification, Home/Style Me, Daily Wear,
  response-policy, and board-render set: `71 passed`.
- Backend conversation context: `13 passed`.
- Backend board mutation: `14 passed`.
- Backend More Options: `55 passed`.

## BROADER TESTS

- The combined backend Style route command did not complete cleanly because
  the existing module-route suite invokes unavailable local Ollama and Appwrite
  services. The isolated failure was
  `test_text_chat_style_prompts_route_to_advice_first` with empty cards after
  provider fallback; it is unrelated to this frontend-only patch.

## ANALYZER

`flutter analyze lib/chat.dart lib/widgets/ahvi_stylist_chat.dart
lib/services/backend_service.dart` completed with `67` existing warning/info
findings and no endpoint-related errors. Findings are pre-existing unused
members, style lints, deprecated API use, and null-aware suggestions.

## PATCH-CAUSED FAILURES

None found.

## PRE-EXISTING FINDINGS

- Generated Flutter registrant files remain dirty and untouched.
- `build-integrated-1.0.2-3/` remains untracked and untouched.
- Backend audit report remains untracked and untouched.
- Analyzer findings listed above predate this patch.
- Local Ollama/Appwrite are unavailable for part of the backend module-route
  suite.

## DIFF REVIEW

`git diff --check` passed. Only `lib/chat.dart` and the focused endpoint test
are intended implementation/test changes; generated files and unrelated
untracked files were not staged.

## COMMIT SHA

`0257123` (`fix(style): eliminate legacy clarification leakage`).

## GIT STATUS

Expected unrelated status remains: generated registrant modifications,
untracked `build-integrated-1.0.2-3/`, and the pre-existing backend audit report.

## DEPLOYED

NO

## PRODUCTION TRAFFIC CHANGED

NO

## READY FOR LOOP 6

YES
