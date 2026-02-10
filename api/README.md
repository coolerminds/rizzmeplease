# RizzMePlease API

FastAPI backend for the RizzMePlease iOS text coaching app.

Production base path is expected to be served at `https://rizzmeow.com/api/v1`
via reverse proxy to this FastAPI app.

## Quick Start

### 1. Install dependencies

```bash
cd api
python3 -m venv .venv
source .venv/bin/activate
python -m pip install --upgrade pip
pip install -e ".[dev]"
```

Or with uv:

```bash
uv venv
source .venv/bin/activate
uv pip install -e ".[dev]"
```

### 2. Configure environment

```bash
cp .env.example .env
# Edit .env with your keys
```

Required environment variables:

- `OPENAI_API_KEY` or `XAI_API_KEY` - Set one provider key (OpenAI or xAI/Grok)
- `OPENAI_BASE_URL` - Defaults to `https://api.openai.com/v1`
- `XAI_BASE_URL` - Defaults to `https://api.x.ai/v1`
- `OPENAI_MODEL` - Model name to call for your selected provider
- `SUPABASE_URL` - Your Supabase project URL
- `SUPABASE_KEY` - Supabase anon key
- `SUPABASE_SERVICE_KEY` - Supabase service role key
- `JWT_SECRET` - Random string for JWT signing (generate with `openssl rand -hex 32`)

### 3. Set up database

Run `schema.sql` in your Supabase SQL Editor to create tables.

### 4. Run the server

```bash
# Development with auto-reload
uvicorn src.main:app --reload --port 8000

# Or using the main module
python -m src.main
```

### 5. Test the API

Open http://localhost:8000/docs for interactive Swagger documentation.

### 6. Smoke tests

```bash
# Direct xAI/Grok connectivity (treats 402 no-credit as soft pass)
python scripts/grok_smoke_test.py

# End-to-end local API smoke test (auth + suggestions)
python scripts/api_suggestions_smoke.py --base-url http://127.0.0.1:8000
```

## API Endpoints

| Method | Endpoint                 | Description                    |
| ------ | ------------------------ | ------------------------------ |
| POST   | `/api/v1/auth/anonymous` | Create anonymous user, get JWT |
| POST   | `/api/v1/suggestions`    | Generate reply suggestions     |
| POST   | `/api/v1/coach/analyze`  | Analyze conversation           |
| POST   | `/api/v1/feedback`       | Submit outcome feedback        |
| GET    | `/api/v1/history`        | Get conversation history       |
| DELETE | `/api/v1/user/data`      | Delete all user data           |

## Project Structure

```
api/
├── src/
│   ├── main.py              # FastAPI app entry point
│   ├── config.py            # Settings from environment
│   ├── models/
│   │   └── schemas.py       # Pydantic models
│   ├── routes/
│   │   ├── auth.py          # Authentication
│   │   ├── suggestions.py   # Suggestion generation
│   │   ├── coach.py         # Coach analysis
│   │   ├── feedback.py      # Outcome feedback
│   │   ├── history.py       # Conversation history
│   │   └── user.py          # User data management
│   ├── services/
│   │   ├── ai_service.py    # OpenAI/xAI integration
│   │   └── database.py      # Supabase operations
│   └── middleware/
│       ├── auth.py          # JWT authentication
│       └── rate_limit.py    # Rate limiting
├── tests/                   # Test files
├── deploy/
│   └── digitalocean/        # systemd/nginx/scripts for DO deployment
├── schema.sql              # Database schema
├── pyproject.toml          # Python project config
└── .env.example            # Environment template
```

## Development

### Run tests

```bash
pytest
```

### Type checking

```bash
mypy src
```

### Linting

```bash
ruff check src
ruff format src
```

## Deployment

### DigitalOcean (recommended for `rizzmeow.com/api`)

Deployment assets are in `deploy/digitalocean/`:

- `bootstrap_droplet.sh`
- `deploy_update.sh`
- `rizzmeplease-api.service`
- `nginx-rizzmeow.conf`

Bootstrap on droplet:

```bash
sudo -i
cd /tmp
git clone https://github.com/<your-org>/<your-repo>.git
cd <your-repo>/api/deploy/digitalocean
chmod +x bootstrap_droplet.sh deploy_update.sh
APP_ROOT=/opt/rizzmeplease \
REPO_URL=https://github.com/<your-org>/<your-repo>.git \
REPO_BRANCH=main \
CERTBOT_EMAIL=you@rizzmeow.com \
./bootstrap_droplet.sh
```

Update deployment later:

```bash
cd /opt/rizzmeplease/api/deploy/digitalocean
sudo ./deploy_update.sh
```

### Docker (optional)

```dockerfile
FROM python:3.11-slim
WORKDIR /app
COPY . .
RUN pip install -e .
CMD ["uvicorn", "src.main:app", "--host", "0.0.0.0", "--port", "8000"]
```

## iOS Integration

Set API base URL to:

```swift
https://rizzmeow.com/api/v1
```

For local phone testing, point Debug builds to:

```text
http://<your-mac-lan-ip>:8000/api/v1
```
