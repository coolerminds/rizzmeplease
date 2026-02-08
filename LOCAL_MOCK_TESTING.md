# Local Mock Testing

## iMessage Extension Mock Mode
- Open the iMessage extension in a thread.
- Enable `Local Mock Mode`.
- Tap `Load Sample Transcript`.
- Choose goal/tone/relationship and tap `Generate Drafts`.
- Tap `Insert Draft`, then submit feedback from the `Suggestion Feedback` section.

In mock mode:
- No network calls are made for suggestions or feedback.
- Suggestions are generated from deterministic local mock data.
- Feedback events are logged locally in-memory in the extension session.

## Local API Testing Data
Use `/Volumes/4tb slow/devOPs/rizzmeplease/api/tests/mock_extension_payloads.json` as fixture payloads for:
- `POST /api/v1/suggestions`
- `POST /api/v1/feedback`

Example local API base URL in Debug builds:
- `http://127.0.0.1:8000/api/v1`
