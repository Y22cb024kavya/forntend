---
quick_id: 20260810-loop8-style-board-mutation-integrity
status: complete
---

# Style Board Mutation Integrity

## KNOWN FAILURE

The historical failure was reproducible from source for the active Stylist
sheet. `replace the shoes with white sneakers` was not in the frontend's
legacy mutation gate, so it selected `/api/module-chat`. The frontend also
sent no `style_state`, leaving the backend without `board_id`, revision, or
board items. The mutation executor therefore could not establish authoritative
state before candidate selection.

## CURRENT MUTATION PATH

1. `ahvi_stylist_chat.dart` and `chat.dart` detect explicit board-mutation
   language using `isStyleBoardMutationPrompt()`.
2. The active rendered board is converted to compact `style_state` containing
   board identity, revision, items, policy, context, and protected IDs.
3. `BackendService.sendChatQuery()` sends that state to `/api/text`.
4. `/api/text` resolves semantic intent and calls the existing
   `handle_board_operation()` executor.
5. The executor reads authoritative durable state, replaces only target roles,
   validates provenance/identity/protected items, and creates the next revision.
6. The frontend stores the returned `style_state` on the new assistant message;
   current-turn policy selects and renders the returned board.

## EXACT FIXTURE RESULT

Board before: `top-1` White shirt, locked `outer-1` Navy jacket, `bottom-1`
Blue jeans, `shoe-1` Brown loafers, revision `1`.

Board after: `top-1`, locked `outer-1`, and `bottom-1` unchanged; `shoe-1`
removed and `shoe-white-2` White sneakers inserted as footwear, revision `2`.

The board source policy remains `wardrobe`; the replacement is a wardrobe
candidate. No Style Asset or catalogue ownership was inferred.

## MATRIX

- Exact white-sneaker mutation: passed through `/api/text` contract fixture.
- Equivalent replace/change/swap/give/keep phrasing: passed.
- Black footwear colour change: passed.
- Loafer-to-sneaker type change: passed.
- Shirt/top preservation: passed by unchanged item identity.
- White plus no-black constraint: passed.
- Navy blazer outerwear mutation: passed with footwear/top/bottom preserved.
- Follow-up mutation: passed from revision `2` to `3`; lineage parent revision
  is the newly mutated board, not the historical revision.
- No exact white sneaker available: returns `NO_VALID_REPLACEMENT`; it does not
  silently choose black sneakers or white loafers.

## BACKEND INTEGRITY

- Existing durable board ID/revision checks remain authoritative.
- Locked/protected item IDs remain unchanged.
- Existing source policy remains enforced.
- Required `color` and `footwear_type` constraints are now strict during
  candidate selection; other style constraints retain their existing ranking
  behavior.
- Style This and Build Outfit specialized modes remain rejected by the generic
  mutation executor. Kavya's Style This path was not changed.

## FRONTEND INTEGRITY

- Both active Style surfaces use the legacy `/api/text` mutation path.
- Existing canonical `/api/module-chat` routing remains unchanged for ordinary
  Style conversation.
- Board state is carried from the latest assistant board message, persisted in
  rich chat messages, and attached to the next mutation request.
- The response becomes a new current assistant board message; no historical
  board is mutated in place.
- Current-turn response policy and renderer tests select the returned revision
  and visible replacement board.

## LOOP 7 TRACE

Mutation traces now include `request_id`, endpoint, action/intent,
`board_id`, `board_revision`, response mode, board presence, context fields,
and deployed revision where available. Backend trace tests confirm the board
identity/revision fields are logged without logging board items, images, user
messages, tokens, or complete response bodies.

## TESTS

- Frontend mutation/endpoint/trace/current-turn focused set: `13 passed`.
- Frontend non-regression board, save/share, renderer, and policy set:
  `91 passed`.
- Backend mutation/trace set: `25 passed`.
- Backend conversation, More Options, renderer, and shuffle set: `90 passed`.
- Python compilation passed.
- `flutter analyze` on affected frontend files: no errors; `67` existing
  warning/info findings remain.
- `git diff --check`: passed.

## DEVICE

`adb` is unavailable. Device/UIAutomator validation is `PENDING`; no installed
APK or live backend revision was inspected.

## BOUNDARIES

No deployment, traffic, environment URL, Appwrite schema, Qdrant, R2,
generated Flutter, Style This, Build Outfit, generic classifier, or catalogue
pipeline changes were made.

## DEPLOYED

NO

## PRODUCTION TRAFFIC CHANGED

NO
