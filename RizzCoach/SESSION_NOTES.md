# Session Notes — RizzCoach SwiftUI Blueprint (Feb 8, 2026)

## What was built
- Added a self-contained SwiftUI blueprint in `RizzCoach/` (18 files) mirroring the React/Figma UI:
  - Flat aesthetic, 3 tabs (Generate/History/Tips), vibe/relationship chips, token economy, deterministic mock replies.
  - Files: Theme/ColorTheme.swift; Models/DataModels.swift; State/RizzCoachState.swift; Services/ReplyService.swift, PurchaseService.swift; Views (ContentView, RizzHeaderView, RizzNavView, GenerateTabView, HistoryTabView, TipsTabView); Components (VibeCardsView, RelationshipPickerView, ContextInputView, ReplyCardsView, GenerateButtonView, TokenShopView); README.md.
- Reply generation: `MockReplyService` deterministic by vibe/relationship; placeholder hook to swap in Grok/OpenAI.
- Token system: starts 25; generate costs 3; watch-ad stub +5; purchase stub adds pack amount (StoreKit IDs placeholder `rizz.tokens.*`).
- Persistence: SwiftData models (TokenLedgerEntry, ConversationHistory) with in-memory fallback; needs iOS 17 for SwiftData, runs on 16 without persistence.
- Aesthetic: no shadows, radius 8, squared inputs, emoji accents; chip scale/ring on select; copy button swaps to “Copied” for 2s.

## How to integrate into the main app or Messages extension
1) Add `RizzCoach/` to the project; set target membership for desired targets.  
2) If you already have @main, don’t use `RizzCoachApp.swift`; instead host `ContentView().environmentObject(RizzCoachState())` from your existing entry point.  
3) For Messages extension: host `ContentView` inside `UIHostingController` in `MessagesViewController`, keep networking local or wire your extension API.  
4) Raise deploy target to iOS 17 to enable SwiftData, or strip `.modelContainer` usage to stay iOS 16 (will run in-memory only).  
5) Replace `MockReplyService` with real Grok/OpenAI call; replace StoreKit product IDs with real ones; ads are stubbed (watch-ad just +5 tokens).  

## Pending/Next Steps
- Decide target(s) to embed: main app vs extension, and set target membership accordingly.
- Wire real backend: implement `ReplyService.generateReplies` with Grok/OpenAI (URLSession + API key).
- Hook StoreKit 2 product IDs and flow; optional AdMob integration (currently stubbed).
- Add assets/app icon; adjust deployment target and build settings.
- Optional: add tests (state token math, deterministic mock replies, view snapshots).

## Paths
- Entry/root: `RizzCoach/ContentView.swift`, `RizzCoach/State/RizzCoachState.swift`
- Services to replace: `RizzCoach/Services/ReplyService.swift`, `RizzCoach/Services/PurchaseService.swift`
- UI components: `RizzCoach/Components/*.swift`
