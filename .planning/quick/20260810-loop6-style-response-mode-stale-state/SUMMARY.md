---
quick_id: 20260810-loop6-style-response-mode-stale-state
status: complete
---

# Style Response-Mode and Stale-State Enforcement

## ROOT CAUSE

No equivalent stale-board production leak remains in the active Style surfaces.
The relevant historical failure class is now centralized behind
`AhviResponsePolicy`: board payloads are parsed and selected only when the
current response mode authorizes them. Loop 6 added transition coverage rather
than changing production behavior.

## CURRENT RESPONSE AUTHORITY

- `AhviResponsePolicy.fromResponse()` reads `response_mode` first, then falls
  back to `route`, `mode`, and `intent` for older envelopes.
- `canRenderBoards()` authorizes only current board modes and requires a valid
  anchor for `style_this`.
- `AhviChatResponseRendererRegistry.select()` chooses the current renderer from
  the policy and current payload.
- `parseAhviResponse()` extracts visual directions, Style This directions,
  wardrobe boards, and visual boards only through `canRenderBoards()`.
- Both `ahvi_stylist_chat.dart` and `chat.dart` use the same response policy
  before attaching board data to the current assistant message.

| Mode | Authority | Renderer | Board fallback |
|---|---|---|---|
| `text_only` | `response_mode` | text | none; fail closed |
| `clarification` | `response_mode` or clarification route/type | text/clarification bubble | none |
| `visual_inspiration` | `response_mode` or legacy route | visual directions/editorial board | current aliases only |
| `wardrobe_recommendation` | `response_mode` or wardrobe route | wardrobe/editorial board | current aliases only |
| `style_this` | response mode/route plus validated anchor | anchored Style This board | no board without anchor |
| `build_outfit` | response mode/route | Build Outfit board | current aliases only |
| board revision | current board-operation response route/action | revised board | dedicated mutation path only |
| `error` | `response_mode` or error route | error/text | none |

Legacy fallback is used only when `response_mode` is absent or unknown. A
recognized suppressed mode cannot be overridden by board JSON. The existing
`style_advice + board_policy=recommendation` internal visual-direction contract
remains intentional and unchanged.

## STALE STATE PATHS FOUND

- Previous boards remain in `_messages` / `_ChatMessage` / `_SheetMessage` as
  conversation history. They are rendered only as their own historical
  assistant messages.
- `_lastStyleContext` and `_runningMemory` are request context, not renderer
  authority.
- Persisted sessions restore rich historical messages, including boards, but do
  not attach them to a later response.
- `_requestMoreStyleBoards()` intentionally merges a new explicit board action
  into the source board message. This is retained More Looks behavior, not a
  text-response leak.
- No current-board global, cached board payload, module keyword, or loader state
  was found to select a board for a later text/clarification response.

## FILES CHANGED

- `test/style_current_turn_renderer_test.dart`: current-turn mode and stale
  board regression coverage.
- `.planning/quick/20260810-loop6-style-response-mode-stale-state/SUMMARY.md`:
  forensic and verification record.
- `.planning/STATE.md`: quick-task state entry.

No production frontend, backend, endpoint, ranking, Style This, Build Outfit,
or Daily Wear source was changed.

## BEHAVIOUR BEFORE

The renderer already contained the correct policy gates, but there was no
focused regression proving board payloads accidentally attached to a later
text/clarification turn could not win over the current mode.

## BEHAVIOUR AFTER

The current response mode is explicitly tested as the renderer authority:

- text/advice/information responses render text only;
- clarification responses render no board;
- visual responses render current boards;
- prior boards remain visible as history only;
- visual -> text -> visual transitions render board, text, new board.

## TEXT_ONLY HANDLING

`response_mode=text_only` suppresses every board alias, even when stale
`style_boards`, `rendered_boards`, `outfits`, `visual_directions`, or a legacy
visual intent are present.

## CLARIFICATION HANDLING

`response_mode=clarification` is text-primary and suppresses current-turn
boards. Clarification lifecycle flags are updated from the current response,
while a rendered current board resolves any pending clarification.

## VISUAL HANDLING

`visual_inspiration`, `wardrobe_recommendation`, `style_this`, and
`build_outfit` retain their authorized board paths. Style This still requires a
validated anchor and existing board controls remain unchanged.

## BOARD HISTORY HANDLING

Historical board messages remain in the conversation list and persisted
session. The current renderer receives the current response payload only; no
previous board is copied into a text response.

## REQUEST ISOLATION

Both primary chat surfaces invalidate and recapture an
`AhviSessionGenerationGuard` token for normal sends. Responses also carry a
client request ID where supported. Late responses are rejected before state is
updated. More Looks retains its dedicated guarded action behavior and was not
changed because no reproducible renderer overwrite was found.

## LOADING STATE

Primary Style loading is neutral: the reusable Style sheet uses the general
processing context, and `chat.dart` uses `AhviProcessingContext.general`.
`Curating your look` is not selected from `moduleContext` before the backend
response. Daily Wear Loop 2 code was not modified.

## VISUAL -> TEXT TEST

Passed in `style_current_turn_renderer_test.dart`: a dinner board followed by
colour-analysis text renders text only, even with the old board attached as a
stale alias.

## TEXT -> VISUAL TEST

Passed: text-only advice followed by visual inspiration renders the current
visual board.

## VISUAL -> TEXT -> VISUAL TEST

Passed: board, explanation text, and a distinct new board resolve to
`visual_directions`, `text`, and `visual_directions` respectively.

## FOCUSED TESTS

- Current-turn renderer tests: `6 passed`.
- Response policy/parser/Home/Style/endpoint/lifecycle set: `94 passed`.
- Dedicated board rendering and mutation set: `18 passed`.
- Backend conversation continuity: `13 passed`.

## BROADER TESTS

No backend source was changed. Loop 3-5 continuity coverage remains green.
Existing unrelated backend module-route tests still depend on unavailable local
Ollama/Appwrite services and were not modified.

## ANALYZER

`flutter analyze` on the affected Style frontend scope completed with `59`
pre-existing warning/info findings and no errors. Findings are unused members,
style suggestions, deprecated API use, and async/lint recommendations.

## PATCH-CAUSED FAILURES

None.

## PRE-EXISTING FINDINGS

- Generated Flutter registrant files remain dirty and untouched.
- `build-integrated-1.0.2-3/` remains untracked and untouched.
- Backend audit report remains untracked and untouched.
- Analyzer findings predate this loop.
- No runtime device reproduction of the historical stale-board symptom was
  available.

## DIFF REVIEW

`git diff --check` passed. Only the focused test and planning records are
intended changes. No generated files or unrelated dirty files are staged.

## COMMIT SHA

`6ef4229` (`test(style): enforce current-turn renderer authority`).

## GIT STATUS

Expected unrelated status remains: generated registrant modifications and
untracked `build-integrated-1.0.2-3/`. The backend audit report remains
untracked in its separate repository.

## DEPLOYED

NO

## PRODUCTION TRAFFIC CHANGED

NO

## READY FOR LOOP 7

YES
