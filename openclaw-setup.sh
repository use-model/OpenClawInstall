#!/usr/bin/env bash
set -uo pipefail

# ============================================================
# OpenClaw (🦞) + UseModel One-Click Setup Script
# ============================================================

API_BASE="${USEMODEL_API_BASE:-https://api.use-model.com}"
OPENCLAW_CONFIG_DIR="$HOME/.openclaw"
OPENCLAW_CONFIG="$OPENCLAW_CONFIG_DIR/openclaw.json"
TOKEN=""
API_KEY=""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

print_banner() {
  echo ""
  echo -e "${RED}${BOLD}"
  echo '    🦞 ╔═══════════════════════════════════════════════╗'
  echo '       ║                                               ║'
  echo '       ║   ░█▀█░█▀█░█▀▀░█▀█░█▀▀░█░░░█▀█░█░█░░░░░░   ║'
  echo '       ║   ░█░█░█▀▀░█▀▀░█░█░█░░░█░░░█▀█░█▄█░░░░░░   ║'
  echo '       ║   ░▀▀▀░▀░░░▀▀▀░▀░▀░▀▀▀░▀▀▀░▀░▀░▀░▀░░░░░░   ║'
  echo '       ║              × UseModel Setup                  ║'
  echo '       ║                                               ║'
  echo '       ╚═══════════════════════════════════════════════╝'
  echo -e "${NC}"
  echo -e "  ${DIM}One-click setup for OpenClaw with UseModel LLM provider${NC}"
  echo ""
}

info()    { echo -e "  ${CYAN}📋 $*${NC}"; }
success() { echo -e "  ${GREEN}✅ $*${NC}"; }
warn()    { echo -e "  ${YELLOW}⚠️  $*${NC}"; }
error()   { echo -e "  ${RED}❌ $*${NC}"; }
step()    { echo -e "\n  ${MAGENTA}${BOLD}$*${NC}"; }

# Escape special characters for JSON string values
json_escape() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  s="${s//$'\r'/\\r}"
  s="${s//$'\t'/\\t}"
  echo "$s"
}

# Wrapper around curl that shows errors instead of hiding them
api_call() {
  local method="$1" url="$2" data="${3:-}" auth="${4:-}"
  local -a args=(-s -w "\n%{http_code}" --max-time 30 -X "$method" "$url" -H "Content-Type: application/json")
  local errtmp

  if [ -n "$auth" ]; then
    args+=(-H "Authorization: Bearer $auth")
  fi
  if [ -n "$data" ]; then
    args+=(-d "$data")
  fi

  errtmp=$(mktemp)
  local result
  result=$(curl "${args[@]}" 2>"$errtmp") || true
  local exit_code=${PIPESTATUS[0]:-$?}

  if [ $exit_code -ne 0 ] || [ -z "$result" ]; then
    local curl_err
    curl_err=$(cat "$errtmp")
    rm -f "$errtmp"
    printf "CURL_ERROR: %s\n000" "${curl_err:-curl exited with code $exit_code}"
    return
  fi

  rm -f "$errtmp"
  echo "$result"
}

# ----------------------------------------------------------
# Step 1: Environment checks
# ----------------------------------------------------------
install_node() {
  echo ""
  echo -e "  ${BOLD}Select Node.js installation method:${NC}"
  echo -e "    1) ${CYAN}nvm${NC}  (recommended - Node Version Manager)"
  echo -e "    2) ${CYAN}fnm${NC}  (Fast Node Manager)"
  echo -e "    3) ${CYAN}brew${NC} (Homebrew - macOS)"
  echo -e "    4) Skip (I'll install manually)"
  echo ""
  read -rp "  Choose (1/2/3/4): " method

  case "$method" in
    1)
      info "Installing Node.js 22 via nvm..."
      if ! command -v nvm &>/dev/null; then
        info "Installing nvm first..."
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
        export NVM_DIR="$HOME/.nvm"
        # shellcheck disable=SC1091
        [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
      fi
      nvm install 22
      nvm use 22
      ;;
    2)
      info "Installing Node.js 22 via fnm..."
      if ! command -v fnm &>/dev/null; then
        info "Installing fnm first..."
        curl -fsSL https://fnm.vercel.app/install | bash
        export PATH="$HOME/.local/share/fnm:$PATH"
        eval "$(fnm env)"
      fi
      fnm install 22
      fnm use 22
      ;;
    3)
      if ! command -v brew &>/dev/null; then
        error "Homebrew is not installed."
        echo -e "    Install from: ${CYAN}https://brew.sh${NC}"
        exit 1
      fi
      info "Installing Node.js 22 via Homebrew..."
      brew install node@22
      brew link node@22 --force --overwrite
      ;;
    4)
      error "Node.js >= 22 is required. Please install it and re-run this script."
      echo -e "    📥 Download from: ${CYAN}https://nodejs.org${NC}"
      exit 1
      ;;
    *)
      error "Invalid choice."
      exit 1
      ;;
  esac

  # Verify installation
  if ! command -v node &>/dev/null; then
    error "Node.js installation may require restarting your terminal."
    echo -e "    Run: ${CYAN}source ~/.bashrc${NC} or ${CYAN}source ~/.zshrc${NC}, then re-run this script."
    exit 1
  fi

  NODE_VERSION=$(node -v | sed 's/v//' | cut -d. -f1)
  if [ "$NODE_VERSION" -lt 22 ]; then
    error "Node.js >= 22 is required. Got: $(node -v)"
    exit 1
  fi

  success "Node.js $(node -v) installed successfully!"
}

check_environment() {
  step "🔍 Step 1: Environment Check"

  # Check curl
  if ! command -v curl &>/dev/null; then
    error "curl is required but not installed."
    exit 1
  fi

  # Check Node.js >= 22
  if ! command -v node &>/dev/null; then
    warn "Node.js is not installed. OpenClaw requires Node >= 22."
    install_node
  else
    NODE_VERSION=$(node -v | sed 's/v//' | cut -d. -f1)
    if [ "$NODE_VERSION" -lt 22 ]; then
      warn "Node.js >= 22 is required. Current version: $(node -v)"
      install_node
    else
      success "Node.js $(node -v)"
    fi
  fi

  # Check openclaw
  if ! command -v openclaw &>/dev/null; then
    warn "OpenClaw CLI not found."
    echo ""
    echo -e "    🦞 Install it with: ${BOLD}npm install -g openclaw@latest${NC}"
    echo ""
    read -rp "  Continue setup anyway? (y/N): " cont
    if [[ ! "$cont" =~ ^[Yy]$ ]]; then
      exit 0
    fi
  else
    success "OpenClaw CLI $(openclaw --version 2>/dev/null || echo 'installed')"
  fi

  # Check API connectivity
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "$API_BASE/api/models" 2>/dev/null || echo "000")
  if [ "$HTTP_CODE" = "000" ]; then
    error "Cannot reach UseModel API at $API_BASE"
    echo -e "    🌐 Check your network or set ${BOLD}USEMODEL_API_BASE${NC} env var."
    exit 1
  fi
  success "UseModel API reachable at $API_BASE"
}

# ----------------------------------------------------------
# Step 2: Login or Register
# ----------------------------------------------------------
authenticate() {
  step "🔐 Step 2: UseModel Account"
  echo ""
  echo -e "    1) 🔑 Login with existing account"
  echo -e "    2) 📝 Register new account"
  echo ""
  read -rp "  Choose (1/2): " choice

  case "$choice" in
    1) do_login ;;
    2) do_register ;;
    *)
      error "Invalid choice."
      exit 1
      ;;
  esac
}

read_password() {
  local prompt="$1"
  local password=""
  read -rsp "$prompt" password
  echo "" >&2
  echo "$password"
}

do_login() {
  echo ""
  read -rp "  📧 Email: " email
  password=$(read_password "  🔒 Password: ")

  info "Logging in..."
  local safe_email safe_pass
  safe_email=$(json_escape "$email")
  safe_pass=$(json_escape "$password")

  RESPONSE=$(api_call POST "$API_BASE/api/auth/login" \
    "{\"email\":\"$safe_email\",\"password\":\"$safe_pass\"}")

  HTTP_CODE=$(echo "$RESPONSE" | tail -1)
  BODY=$(echo "$RESPONSE" | sed '$d')

  if [ "$HTTP_CODE" != "200" ]; then
    MSG=$(echo "$BODY" | grep -o '"error":"[^"]*"' | head -1 | cut -d'"' -f4 || true)
    if echo "$BODY" | grep -q "CURL_ERROR"; then
      error "Connection failed. curl error:"
      echo -e "    ${DIM}$(echo "$BODY" | head -1)${NC}"
    else
      error "Login failed: ${MSG:-HTTP $HTTP_CODE}"
    fi
    exit 1
  fi

  TOKEN=$(echo "$BODY" | grep -o '"token":"[^"]*"' | head -1 | cut -d'"' -f4 || true)
  if [ -z "$TOKEN" ]; then
    error "Failed to extract token from response."
    exit 1
  fi

  success "Logged in successfully! 🎉"
}

do_register() {
  echo ""
  read -rp "  📧 Email: " email
  password=$(read_password "  🔒 Password (min 8 characters): ")

  if [ ${#password} -lt 8 ]; then
    error "Password must be at least 8 characters."
    exit 1
  fi

  info "Registering..."
  local safe_email safe_pass
  safe_email=$(json_escape "$email")
  safe_pass=$(json_escape "$password")

  RESPONSE=$(api_call POST "$API_BASE/api/auth/register" \
    "{\"email\":\"$safe_email\",\"password\":\"$safe_pass\"}")

  HTTP_CODE=$(echo "$RESPONSE" | tail -1)
  BODY=$(echo "$RESPONSE" | sed '$d')

  if [ "$HTTP_CODE" != "200" ] && [ "$HTTP_CODE" != "201" ]; then
    MSG=$(echo "$BODY" | grep -o '"error":"[^"]*"' | head -1 | cut -d'"' -f4 || true)
    if echo "$BODY" | grep -q "CURL_ERROR"; then
      error "Connection failed. curl error:"
      echo -e "    ${DIM}$(echo "$BODY" | head -1)${NC}"
    else
      error "Registration failed: ${MSG:-HTTP $HTTP_CODE}"
    fi
    exit 1
  fi

  success "Registration successful! 📬 Check your email for verification code."
  echo ""

  # Email verification loop
  MAX_ATTEMPTS=3
  for i in $(seq 1 $MAX_ATTEMPTS); do
    read -rp "  🔢 Enter verification code: " code

    RESPONSE=$(api_call POST "$API_BASE/api/auth/verify-email" \
      "{\"email\":\"$safe_email\",\"code\":\"$code\"}")

    HTTP_CODE=$(echo "$RESPONSE" | tail -1)
    BODY=$(echo "$RESPONSE" | sed '$d')

    if [ "$HTTP_CODE" = "200" ]; then
      TOKEN=$(echo "$BODY" | grep -o '"token":"[^"]*"' | head -1 | cut -d'"' -f4 || true)
      if [ -z "$TOKEN" ]; then
        error "Failed to extract token from verification response."
        exit 1
      fi
      success "Email verified! 💰 You received \$2 registration bonus!"
      return
    fi

    MSG=$(echo "$BODY" | grep -o '"error":"[^"]*"' | head -1 | cut -d'"' -f4 || true)
    if [ "$i" -lt "$MAX_ATTEMPTS" ]; then
      warn "Verification failed: ${MSG:-invalid code}. Try again ($i/$MAX_ATTEMPTS)."
    else
      error "Verification failed after $MAX_ATTEMPTS attempts."
      exit 1
    fi
  done
}

# ----------------------------------------------------------
# Step 3: Create API Key
# ----------------------------------------------------------
create_api_key() {
  step "🔑 Step 3: API Key"

  # Check for existing OpenClaw key in server + local config
  info "Checking for existing API key..."
  RESPONSE=$(api_call GET "$API_BASE/api/keys" "" "$TOKEN")
  HTTP_CODE=$(echo "$RESPONSE" | tail -1)
  BODY=$(echo "$RESPONSE" | sed '$d')

  if [ "$HTTP_CODE" = "200" ]; then
    EXISTING_KEY=$(echo "$BODY" | grep -o '"name":"OpenClaw"' || true)
    if [ -n "$EXISTING_KEY" ]; then
      # Key exists on server; try to read from local config
      if [ -f "$OPENCLAW_CONFIG" ] && command -v jq &>/dev/null; then
        LOCAL_KEY=$(jq -r '.models.providers.usemodel.apiKey // empty' "$OPENCLAW_CONFIG" 2>/dev/null || true)
        if [ -n "$LOCAL_KEY" ]; then
          API_KEY="$LOCAL_KEY"
          success "Using existing OpenClaw API key: ${API_KEY:0:12}..."
          return
        fi
      fi
      # Key on server but not in local config — create a new one
      warn "Existing key found but not in local config. Creating a new one..."
    fi
  fi

  # No existing key, create a new one
  info "Creating API key for OpenClaw..."

  RESPONSE=$(api_call POST "$API_BASE/api/keys" \
    '{"name":"OpenClaw","expiration":"365"}' "$TOKEN")

  HTTP_CODE=$(echo "$RESPONSE" | tail -1)
  BODY=$(echo "$RESPONSE" | sed '$d')

  if [ "$HTTP_CODE" != "200" ] && [ "$HTTP_CODE" != "201" ]; then
    MSG=$(echo "$BODY" | grep -o '"error":"[^"]*"' | head -1 | cut -d'"' -f4 || true)
    if echo "$BODY" | grep -q "CURL_ERROR"; then
      error "Connection failed. curl error:"
      echo -e "    ${DIM}$(echo "$BODY" | head -1)${NC}"
    else
      error "Failed to create API key: ${MSG:-HTTP $HTTP_CODE}"
    fi
    exit 1
  fi

  API_KEY=$(echo "$BODY" | grep -o '"key":"[^"]*"' | head -1 | cut -d'"' -f4 || true)
  if [ -z "$API_KEY" ]; then
    error "Failed to extract API key from response."
    exit 1
  fi

  success "API key created: ${API_KEY:0:12}... (valid for 1 year)"
}

# ----------------------------------------------------------
# Step 4: Configure OpenClaw
# ----------------------------------------------------------
configure_openclaw() {
  step "⚙️  Step 4: Configure OpenClaw"

  mkdir -p "$OPENCLAW_CONFIG_DIR"

  NEW_CONFIG='{
  "models": {
    "mode": "merge",
    "providers": {
      "usemodel": {
        "baseUrl": "'"$API_BASE"'/v1",
        "apiKey": "'"$API_KEY"'",
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
}'

  if [ -f "$OPENCLAW_CONFIG" ]; then
    # Try to merge with jq if available
    if command -v jq &>/dev/null; then
      info "Merging with existing config using jq..."

      MERGED=$(jq -s '
        .[0] as $existing |
        .[1] as $new |
        $existing
        | .models.mode = "merge"
        | .models.providers.usemodel = $new.models.providers.usemodel
        | .agents.defaults.model.primary = $new.agents.defaults.model.primary
      ' "$OPENCLAW_CONFIG" <(echo "$NEW_CONFIG") 2>/dev/null || true)

      if [ -n "$MERGED" ]; then
        echo "$MERGED" > "$OPENCLAW_CONFIG"
        success "Config merged successfully (existing settings preserved) 🔀"
        return
      else
        warn "jq merge failed, falling back to backup + overwrite."
      fi
    else
      warn "jq not found. Cannot merge configs."
    fi

    # Backup and overwrite
    BACKUP="$OPENCLAW_CONFIG.backup.$(date +%Y%m%d%H%M%S)"
    cp "$OPENCLAW_CONFIG" "$BACKUP"
    warn "Existing config backed up to: $BACKUP"
  fi

  echo "$NEW_CONFIG" > "$OPENCLAW_CONFIG"
  success "Config written to $OPENCLAW_CONFIG 📄"
}

# ----------------------------------------------------------
# Step 5: Summary
# ----------------------------------------------------------
print_summary() {
  echo ""
  echo -e "${GREEN}${BOLD}"
  echo '  🦞 ═══════════════════════════════════════════'
  echo '       Setup Complete! Happy Coding!'
  echo '     ═══════════════════════════════════════════'
  echo -e "${NC}"
  echo -e "  ${BOLD}📡 API Endpoint:${NC}  $API_BASE/v1"
  echo -e "  ${BOLD}🤖 Default Model:${NC} minimax-m2.5"
  echo -e "  ${BOLD}🔑 API Key:${NC}       ${API_KEY:0:12}..."
  echo -e "  ${BOLD}📄 Config File:${NC}   $OPENCLAW_CONFIG"

  # Fetch balance
  BALANCE_RESP=$(api_call GET "$API_BASE/api/credits/balance" "" "$TOKEN")
  BALANCE=$(echo "$BALANCE_RESP" | grep -o '"balance":[0-9.]*' | cut -d: -f2 || true)
  if [ -n "$BALANCE" ]; then
    echo -e "  ${BOLD}💰 Balance:${NC}       \$$BALANCE"
  fi

  # Auto install and launch OpenClaw
  if ! command -v openclaw &>/dev/null; then
    echo ""
    info "Installing OpenClaw CLI..."
    if npm install -g openclaw@latest 2>/dev/null; then
      : # success
    else
      warn "Permission denied. Retrying with sudo..."
      sudo npm install -g openclaw@latest
    fi
    if command -v openclaw &>/dev/null; then
      success "OpenClaw CLI installed! 🦞"
    else
      warn "OpenClaw install may need a new terminal session."
      echo -e "    Run manually: ${CYAN}npm install -g openclaw@latest${NC}"
    fi
  fi

  # Set gateway mode to local
  if command -v openclaw &>/dev/null; then
    openclaw config set gateway.mode local 2>/dev/null && \
      success "Gateway mode set to local"
  fi

  echo ""
  echo -e "  ${BOLD}🚀 Ready to go!${NC}"
  echo ""
  echo -e "  ${BOLD}Step 1:${NC} Start the gateway (keep this terminal running):"
  echo ""
  echo -e "    ${CYAN}sudo openclaw gateway${NC}"
  echo ""
  echo -e "  ${BOLD}Step 2:${NC} Open a ${BOLD}new terminal window${NC} and launch the dashboard:"
  echo ""
  echo -e "    ${CYAN}openclaw dashboard${NC}"
  echo ""
  echo -e "  The dashboard will print a URL like:"
  echo -e "    ${DIM}Dashboard URL: http://127.0.0.1:18789/#token=...${NC}"
  echo -e "  It will be ${BOLD}auto-copied${NC} to your clipboard and opened in your browser."
  echo ""
  echo -e "  ${DIM}🦞 Powered by UseModel — https://use-model.com${NC}"
  echo ""
}

# ----------------------------------------------------------
# Main
# ----------------------------------------------------------
main() {
  print_banner
  check_environment
  authenticate
  create_api_key
  configure_openclaw
  print_summary
}

main "$@"
