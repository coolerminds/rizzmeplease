# iMessage Extension Scaffolding Outline

## Goal
Ship an in-thread iMessage extension flow that:
- reads current thread context available to `MSConversation`
- lets the user choose goal/tone/relationship and add extra context
- generates ranked reply drafts from private backend
- inserts selected draft into compose field (user sends manually)
- logs feedback for personalization

## Phase 1 Scope (Scaffold Now)
- Extension UI flow (compact + expanded)
- Relationship selector
- Extra context input
- Request payload updates (iOS + API)
- Backend schema + prompt wiring
- Draft insertion hook

## File-by-File Outline

### `/Volumes/4tb slow/devOPs/rizzmeplease/rizzmeplease/Models.swift`
- Add `RelationshipType` enum:
  - `friend`
  - `stranger`
  - `professional`
  - `dating`
- Extend `SuggestionRequest` with:
  - `relationshipType: String`
  - `extraContext: String?`
  - `threadContext: [SuggestionRequest.ConversationData.MessageData]?`

### `/Volumes/4tb slow/devOPs/rizzmeplease/rizzmeplease/APIService.swift`
- Add extension-oriented suggestion call:
  - `generateThreadSuggestions(messages:goal:tone:relationshipType:extraContext:threadContext:)`
- Keep shared auth and idempotency behavior.
- Reuse current POST `/suggestions` endpoint with extended payload.

### `/Volumes/4tb slow/devOPs/rizzmeplease/rizzmeplease MessagesExtension/MessagesViewController.swift`
- Host SwiftUI extension view with `UIHostingController`.
- Parse available recent messages from active `MSConversation`.
- Support compact controls:
  - goal
  - tone
  - relationship type
  - extra context
- On generate: call API and render ranked suggestions.
- On insert: call `conversation.insertText(selectedDraft)`.
- Do not auto-send.

### `/Volumes/4tb slow/devOPs/rizzmeplease/rizzmeplease MessagesExtension/TextCoachApp.swift`
- Keep app bootstrap unchanged.
- If needed, add shared model or helper access points for extension-safe networking.

### `/Volumes/4tb slow/devOPs/rizzmeplease/api/src/models/schemas.py`
- Extend `SuggestionRequest` with:
  - `relationship_type: Optional[str]`
  - `thread_context: Optional[ConversationData]` (or list of message items)
- Keep existing validation limits.

### `/Volumes/4tb slow/devOPs/rizzmeplease/api/src/services/ai_service.py`
- Inject relationship + extra context into system/user prompt builders.
- Add guardrails by relationship type (professional vs dating, etc.).
- Maintain JSON output schema compatibility.

## Request/Response Contract (Phase 1)

### Request (`POST /api/v1/suggestions`)
- `conversation.messages[]` (current user-provided content)
- `goal`
- `tone`
- `relationship_type` (new)
- `context` / `extra_context` (new; short free text)
- `thread_context.messages[]` (new optional)

### Response
- Keep existing response shape.
- Suggestions remain ranked and include rationale.

## Extension UX States
- `Idle`: controls visible, no suggestions yet.
- `Loading`: generating suggestions.
- `Loaded`: ranked list + insert actions.
- `Error`: retry + preserve entered context.

## Privacy and Safety Defaults
- User-invoked only; no background scraping.
- Upload only context needed for generation.
- Prefer short retention for raw thread text.
- Keep “delete my data” API path available.

## Phase 2 (After Scaffold)
- Capture feedback from extension:
  - selected suggestion
  - edited text delta
  - optional outcome later
- Re-ranking by acceptance history + relationship type.

## Phase 3 (Later)
- Optional media suggestion intent:
  - “consider sending a photo” recommendations only
  - no automatic media access or auto-send

## Definition of Done for Scaffold
- Extension UI compiles and runs in Messages.
- Relationship type + extra context are selectable.
- Suggestions generate with extended request payload.
- Selected suggestion inserts into compose box.
- Backend accepts and uses new context fields without breaking existing app flows.
