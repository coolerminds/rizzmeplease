# DigitalOcean Deployment (rizzmeow.com/api)

This folder contains production deployment assets for running the FastAPI API
behind Nginx + systemd on a DigitalOcean Ubuntu droplet.

## What this sets up

- FastAPI app on `127.0.0.1:8000` via `uvicorn` (systemd service)
- Nginx reverse proxy for `https://rizzmeow.com/api/*`
- Certbot TLS for `rizzmeow.com` and `www.rizzmeow.com`

## Files

- `bootstrap_droplet.sh`:
  - Installs system packages
  - Clones/pulls repo
  - Creates Python venv
  - Installs API package
  - Installs systemd + nginx configs
  - Starts service + nginx
  - Optionally runs certbot
- `deploy_update.sh`:
  - Pull latest code
  - Reinstall deps in venv
  - Restart systemd service
  - Run local health check
- `rizzmeplease-api.service`: systemd service template
- `nginx-rizzmeow.conf`: nginx site template

## Quick usage on droplet

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

After bootstrap:

1. Edit `/opt/rizzmeplease/api/.env` with real production secrets.
2. Restart service:
   - `systemctl restart rizzmeplease-api`
3. Verify:
   - `curl -fsS http://127.0.0.1:8000/health`
   - `curl -fsS https://rizzmeow.com/api/health`

## Notes

- If the same domain already serves a frontend, merge the `/api/` location from
  `nginx-rizzmeow.conf` into your existing server block instead of replacing it.
- Keep only one AI provider key in `.env`:
  - Set `XAI_API_KEY` for Grok and leave `OPENAI_API_KEY` empty.
