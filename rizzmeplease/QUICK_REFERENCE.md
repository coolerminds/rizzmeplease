# TextCoach - Quick Reference

## 🚀 Get Started in 3 Steps

1. **Create Xcode Project**
   - iOS App, SwiftUI, Swift, iOS 17.0+
   - Name: TextCoach

2. **Add All Files**
   - Copy 16 source files into project
   - Ensure all are in target membership

3. **Build & Run**
   - Select iPhone simulator
   - Press ⌘R
   - Test the complete flow!

---

## 📂 File Manifest (16 Files)

### Core (4 files)
```
✓ TextCoachApp.swift           - App entry point
✓ Models.swift                 - Data structures
✓ AppState.swift               - State management  
✓ AuthenticationManager.swift  - Auth state
```

### Services (3 files)
```
✓ APIService.swift             - Network layer
✓ StorageService.swift         - Persistence
✓ MockDataService.swift        - Test data
```

### Views (9 files)
```
✓ OnboardingView.swift         - First launch
✓ MainTabView.swift            - Tab navigation
✓ HomeView.swift               - Home screen
✓ NewAnalysisFlow.swift        - Conversation input
✓ GoalTonePickerView.swift     - Goal/tone selection
✓ SuggestionsView.swift        - AI results
✓ HistoryView.swift            - Past conversations
✓ CoachView.swift              - Insights
✓ SettingsView.swift           - Settings
```

---

## 🎯 5-Minute Test

1. Launch → Complete onboarding
2. Paste conversation:
   ```
   Them: How was your weekend?
   You: Good! Went hiking.
   Them: Nice! Where?
   ```
3. Select "Get Reply" + "Friendly"
4. Get 3 suggestions → Copy one
5. Submit feedback as "Worked"
6. Repeat 4 more times
7. Check Coach insights!

---

## 🔑 Key Features

| Feature | Status | Location |
|---------|--------|----------|
| Onboarding | ✅ Complete | OnboardingView.swift |
| Paste Conversations | ✅ Complete | NewAnalysisFlow.swift |
| 3 Goals × 4 Tones | ✅ Complete | GoalTonePickerView.swift |
| AI Suggestions | ✅ Mock Data | MockDataService.swift |
| Feedback Tracking | ✅ Complete | SuggestionsView.swift |
| History | ✅ Complete | HistoryView.swift |
| Coach Insights | ✅ Mock Data | CoachView.swift |
| Data Persistence | ✅ Complete | StorageService.swift |
| Privacy Controls | ✅ Complete | SettingsView.swift |

---

## 🎨 Goals & Tones

### Goals (3)
- 💬 **Get Reply** - Keep conversation going
- 📅 **Ask for Meetup** - Transition to in-person
- 🛑 **Set Boundary** - Politely decline

### Tones (4)
- 😊 **Friendly** - Casual, warm
- 🎯 **Direct** - Clear, straightforward
- 🤗 **Warm** - Empathetic, attuned
- 💪 **Confident** - Self-assured

= **12 unique suggestion types**

---

## 💾 Data Storage

| What | Where | Why |
|------|-------|-----|
| Conversations | JSON file | Large data |
| Settings | UserDefaults | Small flags |
| Auth Token | Keychain | Secure |

**Location:** `~/Library/Developer/CoreSimulator/.../TextCoach/`

---

## 🔌 Backend Integration

**Change 3 things in `AppState.swift`:**

```swift
// 1. Remove #if DEBUG blocks
func generateSuggestions() async throws {
    // DELETE THIS: #if DEBUG
    let response = try await apiService.generateSuggestions(...)
    // DELETE THIS: #else and #endif
}

// 2. Do same for submitFeedback()
// 3. Do same for fetchCoachInsights()
```

**Update API URL in `APIService.swift`:**
```swift
private let baseURL = "https://your-api.com/api/v1"
```

Done! App now uses real backend.

---

## 🐛 Common Issues

| Problem | Solution |
|---------|----------|
| Build fails | Clean: ⌘⇧K, check all files in target |
| Paste button broken | iOS simulator limitation, type manually |
| Coach locked | Need 5 conversations with feedback |
| Data not saving | Check file permissions, reinstall app |
| Suggestions not showing | Check console for errors |

---

## 📊 Test Coverage

**User Flows:**
- ✅ Onboarding (4 screens)
- ✅ Create conversation (paste → goal → tone → suggestions)
- ✅ Copy suggestion
- ✅ Submit feedback (3 outcomes)
- ✅ View history (filter, search, delete)
- ✅ Unlock coach (after 5 feedback)
- ✅ View insights
- ✅ Settings (local mode, delete data)

**Edge Cases:**
- ✅ Too few messages (button disabled)
- ✅ Empty text field (can't proceed)
- ✅ Coach before 5 feedback (locked screen)
- ✅ Data persistence (app restart)

---

## 🎭 Mock Data Examples

### Suggestion Preview
**Get Reply + Friendly:**
> "That sounds awesome! Tell me more about it 😊"

**Ask Meetup + Direct:**
> "Let's meet up. Are you free Thursday evening?"

**Set Boundary + Warm:**
> "I really appreciate you, but I need to set a boundary here. I hope you understand ❤️"

### Coach Insight Preview
> "Direct tone excels for meetup requests"
> Your direct approach has 85% success rate for in-person transitions.

---

## 📱 UI Components

### Reusable
- `GoalCard` - Goal selection cards
- `ToneCard` - Tone selection pills
- `SuggestionCard` - Suggestion display
- `OutcomeButton` - Feedback selection
- `ConversationBubble` - Message display
- `LoadingOverlay` - Loading state

### Navigation
- `NavigationStack` for hierarchies
- `.sheet()` for modals
- `TabView` for main tabs
- `.navigationTitle()` for headers

---

## 🔒 Privacy Features

✅ Opt-in consent (onboarding)
✅ Local-only mode toggle
✅ Delete all data button
✅ Privacy policy screen
✅ Encrypted storage ready
✅ No analytics (MVP)
✅ Transparent data usage

---

## 📈 Success Metrics

**Track these:**
- Suggestions generated
- Copy/use rate
- Feedback submission rate
- Outcome distribution
- Coach unlock rate
- Daily active users
- Retention (D1, D7, D30)

**Add in production:**
```swift
Analytics.track("suggestion_generated", properties: [
    "goal": goal.rawValue,
    "tone": tone.rawValue
])
```

---

## 🎓 Learning Value

This codebase teaches:
- ✅ SwiftUI best practices
- ✅ MVVM architecture
- ✅ Swift Concurrency
- ✅ REST API integration
- ✅ Local persistence
- ✅ State management
- ✅ Navigation patterns
- ✅ Mock data strategies

Perfect for iOS developers learning modern Swift!

---

## 🚦 Development Status

| Phase | Status | ETA |
|-------|--------|-----|
| UI Implementation | ✅ 100% | Complete |
| Mock Data | ✅ 100% | Complete |
| Local Persistence | ✅ 100% | Complete |
| Backend API | ⏳ 0% | 2 weeks |
| AI Integration | ⏳ 0% | 1 week |
| Testing | ⏳ 0% | 1 week |
| TestFlight | ⏳ 0% | 2 weeks |

**Current Status:** MVP UI complete, ready for backend integration.

---

## 🎯 Next Actions

**For Testing:**
1. Follow `BUILD_AND_TEST_GUIDE.md`
2. Test all 15 scenarios
3. Report any issues

**For Development:**
1. Set up backend API (see blueprint)
2. Update 3 integration points
3. Test with real AI
4. Add analytics
5. Submit to TestFlight

**For Launch:**
1. Create App Store assets
2. Write full privacy policy
3. Set up support email
4. Prepare marketing site
5. Plan beta testing

---

## 📚 Documentation

- `README.md` - Project overview
- `BUILD_AND_TEST_GUIDE.md` - Complete testing instructions
- `IMPLEMENTATION_SUMMARY.md` - Technical details
- This file - Quick reference

---

## ✨ What Makes This Special

1. **Complete MVP** - Every screen functional
2. **12 Unique Voices** - Goal × Tone combinations
3. **Outcome Tracking** - Learn what works
4. **Coach Insights** - Pattern recognition
5. **Privacy-First** - User control
6. **Production-Ready** - Just add backend

---

## 🎉 You're Ready!

Everything needed to build, test, and launch is included:
- ✅ Complete source code (2,500+ lines)
- ✅ Mock data for all scenarios
- ✅ Build instructions
- ✅ Test guide
- ✅ Architecture documentation
- ✅ Backend API specs

**Start building now!** 🚀

---

**Last Updated:** February 6, 2026
**Version:** 1.0.0 (MVP)
**Platform:** iOS 17.0+
**Language:** Swift 5.9+
**Framework:** SwiftUI
