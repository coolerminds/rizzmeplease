# TextCoach iOS App - Build & Test Guide

## Quick Start (5 Minutes)

### 1. Create Xcode Project

```bash
# Open Xcode and create a new iOS App project
# Name: TextCoach
# Interface: SwiftUI
# Language: Swift
# Minimum Deployment: iOS 17.0
```

### 2. Add Files to Project

Copy all the provided source files into your Xcode project:

```
TextCoach/
├── TextCoachApp.swift
├── Models.swift
├── AppState.swift
├── APIService.swift
├── StorageService.swift
├── AuthenticationManager.swift
├── MockDataService.swift
└── Views/
    ├── OnboardingView.swift
    ├── MainTabView.swift
    ├── HomeView.swift
    ├── NewAnalysisFlow.swift
    ├── GoalTonePickerView.swift
    ├── SuggestionsView.swift
    ├── HistoryView.swift
    ├── CoachView.swift
    └── SettingsView.swift
```

### 3. Build and Run

- Select iPhone 15 Pro simulator
- Press ⌘R (or click Run button)
- App should launch with onboarding screen

---

## Complete Testing Flow

### Test 1: Onboarding (First Launch)

**Steps:**
1. Launch app
2. Swipe through 4 onboarding pages:
   - Welcome
   - Privacy
   - Features
   - Get Started
3. Toggle "I agree" switch
4. Tap "Get Started"

**Expected:** App navigates to Home tab with "Analyze Conversation" button

---

### Test 2: Create First Conversation Analysis

**Steps:**
1. Tap "Analyze Conversation" button
2. In text field, paste this example:

```
Them: Hey! How was your weekend?
You: Pretty good! Went hiking with some friends.
Them: Nice! Which trail did you do?
You: Mount Tamalpais. The weather was perfect.
Them: Oh cool! I've been wanting to check that out.
```

3. Verify it shows "Detected 5 messages"
4. Tap "Show Preview" to verify parsing
5. Tap "Next"

**Expected:** Goal & Tone picker screen appears

---

### Test 3: Select Goal and Tone

**Steps:**
1. Tap "Get Reply" card (should highlight)
2. Tap "Friendly" tone pill
3. Verify "Generate Suggestions" button is enabled and blue
4. Tap "Generate Suggestions"

**Expected:** 
- Loading spinner appears for ~2 seconds
- 3 suggestions appear with copy buttons

---

### Test 4: Copy and Mark Suggestion

**Steps:**
1. Read all 3 suggestions
2. Tap "Why this works" on Suggestion 2 to expand reasoning
3. Tap "Copy to Clipboard" on Suggestion 2
4. Verify button changes to "Copied!" with green background
5. Tap "Mark as Used" dropdown if it appears
6. Select Suggestion 2

**Expected:** 
- Clipboard contains suggestion text
- "How Did It Go?" button appears

---

### Test 5: Submit Feedback

**Steps:**
1. Tap "How Did It Go?" button
2. Tap "✅ Worked" outcome
3. Type in notes field: "They responded right away!"
4. Tap "Submit Feedback"

**Expected:**
- Returns to Home screen
- Conversation appears in "Recent Conversations"
- Shows green checkmark for outcome

---

### Test 6: Repeat for More Conversations

Create 4 more conversations with different combinations:

**Conversation 2:**
- Goal: Ask for Meetup
- Tone: Direct
- Outcome: Worked

**Conversation 3:**
- Goal: Set Boundary
- Tone: Warm
- Outcome: Worked

**Conversation 4:**
- Goal: Get Reply
- Tone: Confident
- Outcome: No Response

**Conversation 5:**
- Goal: Ask for Meetup
- Tone: Friendly
- Outcome: Worked

**Expected:** After 5th feedback submission, Coach tab badge changes from 🔒 to normal

---

### Test 7: View History

**Steps:**
1. Tap "History" tab
2. Verify all 5 conversations appear
3. Try filter segments:
   - All: Shows all 5
   - With Feedback: Shows all 5
   - Pending: Shows 0
4. Tap first conversation

**Expected:**
- Detail view shows original messages
- Shows all 3 suggestions
- Highlights used suggestion with checkmark
- Shows outcome with notes

---

### Test 8: Coach Insights

**Steps:**
1. Tap "Coach" tab
2. Verify insights are unlocked
3. Scroll through insights:
   - Stats overview showing 5 conversations
   - Pattern cards (tap to expand)
   - Recommendations
4. Tap refresh button in toolbar

**Expected:**
- Insights load with mock data
- Stats show 5 total, 5 feedback, success rate
- Multiple insight cards with your patterns
- Recommendations based on usage

---

### Test 9: Settings & Privacy

**Steps:**
1. Tap "Settings" tab
2. Toggle "Local-Only Mode" on
3. Toggle it back off
4. Scroll to "Your Data" section
5. Verify counts match (5 conversations, 5 feedback)
6. Tap "Privacy Policy"
7. Read policy and go back

**Expected:**
- Toggle works smoothly
- Counts are accurate
- Privacy policy is readable

---

### Test 10: Delete Conversation

**Steps:**
1. Go to History tab
2. Swipe left on any conversation
3. Tap "Delete"
4. Verify it's removed from list

**Expected:**
- Conversation deleted
- Count updates
- Other conversations remain

---

### Test 11: Regenerate Suggestions

**Steps:**
1. Create new conversation
2. Choose goal and tone
3. Generate suggestions
4. Tap "Regenerate Suggestions"
5. Wait for new suggestions

**Expected:**
- Loading appears
- New suggestions generated (may be same in mock mode)
- Can regenerate multiple times

---

### Test 12: Edge Cases

**Test 12a: Too Few Messages**
1. Create analysis with only 1 line
2. Try to proceed

**Expected:** Next button disabled, can't proceed

**Test 12b: Coach Before 5 Feedback**
1. Delete conversations until < 5 with feedback
2. Go to Coach tab

**Expected:** Locked screen with progress indicator

**Test 12c: Empty Text Paste**
1. Start new analysis
2. Leave text field empty
3. Try to tap Next

**Expected:** Button disabled

---

### Test 13: Conversation Parsing

Test different formats:

```
Format 1:
Them: Hello
You: Hi there

Format 2:
Me: What's up?
Them: Not much

Format 3:
Just alternating lines without prefixes
This should still parse
Alternating between senders
```

**Expected:** All formats parse correctly with message count shown

---

### Test 14: Data Persistence

**Steps:**
1. Create 2 conversations with feedback
2. Force quit app (swipe up in app switcher)
3. Relaunch app

**Expected:**
- No onboarding (already completed)
- Home screen appears
- 2 conversations still in history
- Progress toward coach insights preserved

---

### Test 15: Logout & Clear Data

**Steps:**
1. Go to Settings
2. Scroll to bottom
3. Tap "Delete All My Data"
4. Confirm deletion
5. App logs out

**Expected:**
- Confirmation dialog appears
- After confirmation, all data cleared
- Returns to onboarding screen
- Starting fresh

---

## Known Limitations (MVP)

✅ **Working:**
- Complete UI flow
- Local data persistence
- Mock AI suggestions
- Feedback tracking
- Coach insights (mock)
- Conversation parsing

⚠️ **Not Implemented (Backend Required):**
- Real AI generation (uses mock data)
- Server-side history sync
- Real authentication (uses mock token)
- Cloud backup
- Push notifications

---

## Troubleshooting

### Build Errors

**"Cannot find type 'UIPasteboard'"**
- Ensure you're building for iOS target (not macOS)

**"Module compiled with Swift X, expected Swift Y"**
- Clean build folder: Product → Clean Build Folder (⌘⇧K)
- Delete derived data

**Views not found**
- Verify all view files are in Xcode project navigator
- Check Target Membership (File Inspector)

### Runtime Issues

**App crashes on launch**
- Check console for error messages
- Verify all @EnvironmentObject dependencies are provided
- Ensure TextCoachApp.swift is entry point

**Suggestions not appearing**
- Check Debug console for errors
- Verify MockDataService is included
- Ensure running in Debug configuration

**Data not persisting**
- Check app has file system permissions
- Look for Documents directory errors in console
- Try deleting and reinstalling app

**Coach tab always locked**
- Verify 5 conversations have outcome feedback
- Check feedbackProgress computed property
- Debug print conversation outcomes

---

## Development Tips

### Debugging State
Add this to any view to inspect state:

```swift
.onAppear {
    print("Conversations: \(appState.conversations.count)")
    print("Feedback count: \(appState.feedbackProgress)")
}
```

### Testing Specific Views
Create previews at bottom of view files:

```swift
#Preview {
    HomeView()
        .environmentObject(AppState())
        .environmentObject(AuthenticationManager())
}
```

### Resetting App State
Delete app from simulator and reinstall, or:

```swift
// In AppState.init(), temporarily add:
StorageService.shared.clearAll()
```

---

## Next Steps: Production Readiness

### 1. Backend Integration
- Replace mock data with real API calls
- Implement proper authentication
- Add error handling for network failures

### 2. Testing
- Write unit tests for Models and AppState
- Add UI tests for critical flows
- Test on real devices

### 3. Polish
- Add haptic feedback
- Improve error messages
- Add loading states
- Implement retry logic

### 4. Security
- Add certificate pinning
- Implement token refresh
- Add biometric authentication option

### 5. Analytics
- Track user flows
- Monitor error rates
- Measure feature usage

---

## File Checklist

Before building, ensure you have:

- [ ] TextCoachApp.swift (entry point)
- [ ] Models.swift (data structures)
- [ ] AppState.swift (state management)
- [ ] APIService.swift (network layer)
- [ ] StorageService.swift (persistence)
- [ ] AuthenticationManager.swift (auth)
- [ ] MockDataService.swift (test data)
- [ ] OnboardingView.swift
- [ ] MainTabView.swift
- [ ] HomeView.swift
- [ ] NewAnalysisFlow.swift
- [ ] GoalTonePickerView.swift
- [ ] SuggestionsView.swift
- [ ] HistoryView.swift
- [ ] CoachView.swift
- [ ] SettingsView.swift

All files should be added to the TextCoach target with proper membership.

---

## Success Criteria

The MVP is working correctly when:

1. ✅ User can complete onboarding
2. ✅ User can paste and parse conversations
3. ✅ User can select goal and tone
4. ✅ User receives 3 suggestions (mock)
5. ✅ User can copy suggestions
6. ✅ User can submit feedback
7. ✅ User can view history
8. ✅ Coach unlocks after 5 feedback
9. ✅ Data persists across app restarts
10. ✅ User can delete all data

If all tests pass, you have a working MVP ready for backend integration! 🎉
