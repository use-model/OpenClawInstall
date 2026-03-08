# 🦞 OpenClaw + UseModel One-Click Setup Script

[中文版](./README_CN.md)

## What is this?

A one-click setup script that configures [OpenClaw](https://github.com/openclaw) to use [UseModel](https://use-model.com) as the LLM provider. Run one command, and you're ready to go.

**🎁 Every new account gets $1 free credits — start using AI models immediately!**

## Features

- ✅ Auto-detects and installs Node.js (nvm / fnm / brew)
- ✅ Register or login to UseModel account
- ✅ Auto-creates API key (valid for 1 year)
- ✅ Configures OpenClaw with UseModel provider
- ✅ Installs OpenClaw CLI if not present
- ✅ Merges with existing OpenClaw config (preserves your settings)

## Quick Start

```bash
curl -fsSL https://use-model.com/scripts/openclaw-setup.sh | bash
```

Or download and run manually:

```bash
git clone https://github.com/user/use-model.git
cd use-model/scripts
chmod +x openclaw-setup.sh
./openclaw-setup.sh
```

## Screenshots

![Setup Screenshot](./screenshots/step1-banner.png)

The script walks you through the entire setup process:

1. **Environment Check** — Verifies Node.js, curl, and API connectivity
2. **Login or Register** — Use an existing account or create a new one (new accounts receive **$1 free credits**)
3. **API Key Creation** — Automatically creates and stores an API key
4. **Setup Complete** — Shows your API endpoint, default model, API key, balance, and next steps

## What the script does (step by step)

| Step | Action |
|------|--------|
| **1. Environment Check** | Verifies `curl` and `Node.js >= 22` are installed. Offers to install Node.js via nvm, fnm, or brew if missing. Checks UseModel API connectivity. |
| **2. Authentication** | Login or register a UseModel account. New registrations include email verification and **$1 bonus credits**. |
| **3. API Key** | Creates an API key named "OpenClaw" (valid 1 year). Reuses existing key if found in local config. |
| **4. Configure OpenClaw** | Writes/merges `~/.openclaw/openclaw.json` with UseModel provider settings. Backs up existing config if needed. |
| **5. Summary** | Installs OpenClaw CLI if needed, sets gateway mode to local, and shows next steps. |

## Default Configuration

After setup, your `~/.openclaw/openclaw.json` will include:

```json
{
  "models": {
    "mode": "merge",
    "providers": {
      "usemodel": {
        "baseUrl": "https://api.use-model.com/v1",
        "apiKey": "sk-...",
        "api": "openai-completions",
        "models": [
          {
            "id": "minimax-m2.5",
            "name": "MiniMax M2.5",
            "contextWindow": 128000,
            "maxTokens": 32000
          }
        ]
      }
    }
  },
  "agents": {
    "defaults": {
      "model": {
        "primary": "usemodel/minimax-m2.5"
      }
    }
  }
}
```

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `USEMODEL_API_BASE` | `https://api.use-model.com` | UseModel API base URL |

## Requirements

- **curl** — for API requests
- **Node.js >= 22** — required by OpenClaw (script can install it for you)
- **jq** (optional) — for merging with existing config

## After Setup

```bash
# Start the gateway
openclaw gateway
```

## Test Your API Key

```bash
curl https://api.use-model.com/v1/chat/completions \
  -H "Authorization: Bearer YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"model":"minimax-m2.5","messages":[{"role":"user","content":"hello"}]}'
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| `Cannot reach UseModel API` | Check your network connection. Try setting `USEMODEL_API_BASE` if using a custom endpoint. |
| Node.js install needs restart | Run `source ~/.bashrc` or `source ~/.zshrc`, then re-run the script. |
| Permission denied on npm install | The script will auto-retry with `sudo`. |
| Config merge failed | Install `jq` for proper config merging: `brew install jq` or `apt install jq`. |

## License

MIT

---

🦞 Powered by [UseModel](https://use-model.com)
