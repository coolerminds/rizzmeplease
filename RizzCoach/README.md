# RizzCoach SwiftUI Blueprint

This folder contains a SwiftUI/iOS17-ready blueprint that mirrors the provided React UI:

- Flat “vine” aesthetic, three tabs (Generate / History / Tips)
- Vibe and relationship chips, context inputs, token economy
- Mock reply generation (deterministic), StoreKit-stub purchases, optional SwiftData persistence with in-memory fallback for iOS 16

## Structure
- `RizzCoachApp.swift` entry point with optional SwiftData `modelContainer`
- `Models/` data types (`Vibe`, `Relationship`, `ReplyDraft`, `ConversationHistory`, `TokenLedgerEntry`, etc.)
- `State/` `RizzCoachState` ObservableObject for UI state, tokens, reply generation, persistence
- `Theme/` color tokens
- `Views/` root + tab views
- `Components/` reusable UI pieces (chips, grids, buttons, token shop)
- `Services/` stub reply & purchase services

## Usage
1. Create an Xcode iOS app (SwiftUI lifecycle, iOS 17+ for SwiftData).
2. Add these files preserving folders. If you need iOS 16, keep min target 17 but app will run on 16 with in-memory state.
3. Hook `ReplyService` to Grok/OpenAI by replacing `MockReplyService.generateReplies`.
4. Replace placeholder product IDs (`rizz.tokens.*`) in `TokenPack` with your StoreKit IDs.
5. Add assets/app icon as needed.
