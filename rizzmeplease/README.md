# TextCoach iOS App

AI-powered text message coach that helps users improve conversation outcomes through intelligent suggestions and pattern analysis.

## Features

### ✨ Core Functionality
- **Reply Generator**: Get 3 AI-generated message suggestions tailored to your goal and tone
- **Conversation Coach**: Unlock personalized insights after providing feedback on 5+ conversations
- **Outcome Tracking**: Track what works with simple feedback (Worked / No Response / Negative)
- **Privacy-First**: Local-only mode, encrypted storage, delete data anytime

### 🎯 Goals
- **Get Reply**: Keep the conversation going naturally
- **Ask for Meetup**: Transition from text to in-person
- **Set Boundary**: Politely decline or establish limits

### 🎨 Tones
- **Friendly**: Casual, warm, approachable
- **Direct**: Clear, straightforward
- **Warm**: Empathetic, emotionally attuned
- **Confident**: Self-assured, decisive

## Architecture

### iOS App (SwiftUI)
- **UI Layer**: SwiftUI views with NavigationStack and tab-based navigation
- **State Management**: ObservableObject pattern with `@EnvironmentObject`
- **Local Storage**: JSON file storage for conversations, UserDefaults for settings
- **Secure Storage**: Keychain for authentication tokens
- **Network**: URLSession with async/await for API calls

### Backend API (Not Included)
The app expects a REST API at `https://api.textcoach.app/api/v1` with these endpoints:

- `POST /suggestions` - Generate message suggestions
- `POST /feedback` - Submit outcome feedback
- `POST /coach/analyze` - Get personalized insights
- `GET /history` - Fetch conversation history
- `DELETE /user/data` - Delete all user data

See the implementation blueprint in the initial design document for full API specs.

## Project Structure

```
TextCoach/
├── TextCoachApp.swift           # App entry point
├── Models.swift                 # Data models and API schemas
├── AppState.swift               # Main app state manager
├── APIService.swift             # Backend API client
├── StorageService.swift         # Local persistence
├── AuthenticationManager.swift  # Auth state management
└── Views/
    ├── OnboardingView.swift     # Initial onboarding flow
    ├── MainTabView.swift        # Tab navigation container
    ├── HomeView.swift           # Home screen with CTA
    ├── NewAnalysisFlow.swift    # Multi-step analysis flow
    ├── GoalTonePickerView.swift # Goal and tone selection
    ├── SuggestionsView.swift    # Display AI suggestions
    ├── HistoryView.swift        # Past conversations list
    ├── CoachView.swift          # Insights and recommendations
    └── SettingsView.swift       # Settings and privacy
```

## Getting Started

### Requirements
- Xcode 15.0+
- iOS 17.0+
- Swift 5.9+

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourorg/textcoach-ios.git
   cd textcoach-ios
   ```

2. **Open in Xcode**
   ```bash
   open TextCoach.xcodeproj
   ```

3. **Configure Backend URL** (optional)
   
   Update the `baseURL` in `APIService.swift` to point to your backend:
   ```swift
   private let baseURL = "https://your-api-url.com/api/v1"
   ```

4. **Run the App**
   - Select a simulator or device
   - Press Cmd+R to build and run

### MVP Testing Mode

The app currently runs in **MVP testing mode** with:
- Mock authentication (no real login required)
- Local data storage only
- API calls will fail gracefully (backend not implemented)
- Full UI flow functional for testing

To test the complete flow:
1. Complete onboarding
2. Paste a conversation (use example format)
3. Select goal and tone
4. View generated suggestions (mock data)
5. Mark suggestion as used
6. Provide feedback
7. Check Coach insights after 5 conversations

## Key Components

### AppState
Central state manager that coordinates:
- Conversation creation and management
- API calls (suggestions, feedback, coach insights)
- Local data persistence
- Error handling

### APIService
REST API client with:
- JSON encoding/decoding with snake_case conversion
- JWT authentication via Keychain
- Idempotency key support for retries
- Error response parsing

### StorageService
Local persistence using:
- JSON file storage for conversations
- UserDefaults for settings
- Keychain for sensitive tokens

### Views
SwiftUI views following Apple's design patterns:
- NavigationStack for navigation
- Sheet presentations for modals
- List and ScrollView for content
- Custom reusable components

## Privacy & Security

### Data Protection
- ✅ All data encrypted at rest
- ✅ TLS 1.3 for network communication
- ✅ Keychain storage for tokens
- ✅ Optional local-only mode
- ✅ User-initiated data deletion

### Privacy Features
- Explicit consent during onboarding
- Clear privacy policy
- No tracking or analytics (MVP)
- Transparent data usage
- Easy data deletion

## Testing

### Manual Testing Checklist
- [ ] Onboarding flow completion
- [ ] Conversation paste and parsing
- [ ] Goal and tone selection
- [ ] Suggestion display and copy
- [ ] Feedback submission
- [ ] History view and filtering
- [ ] Coach insights (after 5 feedback)
- [ ] Settings toggle (local-only mode)
- [ ] Data deletion
- [ ] Logout

### Unit Tests (To Be Added)
```swift
import Testing

@Suite("AppState Tests")
struct AppStateTests {
    @Test("Start new conversation")
    func startNewConversation() async throws {
        let appState = AppState()
        let messages = [
            Message(sender: .them, text: "Hey"),
            Message(sender: .you, text: "Hi")
        ]
        appState.startNewConversation(messages: messages)
        #expect(appState.currentConversation?.messages.count == 2)
    }
}
```

## Development Roadmap

### Phase 1: MVP (Current)
- ✅ Core UI implementation
- ✅ Local data persistence
- ✅ API service layer
- ⏳ Backend integration
- ⏳ TestFlight deployment

### Phase 2: Polish
- Enhanced error handling
- Offline support with queue
- Push notifications for feedback reminders
- Improved conversation parsing
- Analytics integration

### Phase 3: Advanced Features
- iMessage extension
- Share extension
- Widget support
- Advanced coach insights
- Custom goal creation

## API Integration

To connect to a real backend:

1. **Update API URL**
   ```swift
   // In APIService.swift
   private let baseURL = "https://your-api.com/api/v1"
   ```

2. **Implement Authentication**
   ```swift
   // Replace mock token in AuthenticationManager.swift
   func login(email: String, password: String) async throws {
       let response = try await authAPI.login(email: email, password: password)
       try KeychainService.shared.saveToken(response.token)
       isAuthenticated = true
   }
   ```

3. **Add Error Handling**
   ```swift
   // Handle specific error codes
   catch let error as APIError {
       switch error.error.code {
       case "RATE_LIMIT_EXCEEDED":
           showRateLimitAlert()
       case "VALIDATION_ERROR":
           showValidationError(error.error.message)
       default:
           showGenericError()
       }
   }
   ```

## Contributing

### Code Style
- Follow Swift API Design Guidelines
- Use SwiftUI best practices
- Add comments for complex logic
- Keep functions focused and small

### Pull Request Process
1. Create feature branch from `main`
2. Implement changes with tests
3. Update documentation
4. Submit PR with description

## License

Copyright © 2026 TextCoach. All rights reserved.

## Support

- 📧 Email: support@textcoach.app
- 🐛 Issues: GitHub Issues
- 📖 Docs: [docs.textcoach.app](https://docs.textcoach.app)

## Credits

Built with:
- SwiftUI for UI
- Swift Concurrency for async operations
- Foundation for data handling
- Security framework for Keychain

---

**Note**: This is an MVP implementation. Backend API and AI integration are required for full functionality. The app currently operates with mock data for UI testing and development.
