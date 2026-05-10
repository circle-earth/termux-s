#!/data/data/com.termux/files/usr/bin/env bash

set -u

CONFIG_DIR="$HOME/.local/bin"
ENV_FILE="$CONFIG_DIR/.env"
GROQ_MODELS_URL="https://api.groq.com/openai/v1/models"
GROQ_CHAT_URL="https://api.groq.com/openai/v1/chat/completions"

die() {
  echo "[✘] $1"
  exit 1
}

ensure_git_repo() {
  local out cwd ans
  if out="$(git rev-parse --is-inside-work-tree 2>&1)"; then
    [[ "$out" == "true" ]] && return 0
  fi

  cwd="$(pwd)"
  if [[ "${out,,}" == *"dubious ownership"* || "${out,,}" == *"safe.directory"* ]]; then
    echo "⚠️ Git blocked this repository due to ownership/safe.directory restriction."
    echo "👉 Trust this directory by running:"
    echo "   git config --global --add safe.directory \"$cwd\""
    read -r -p "👉 Auto-fix now? (y/n): " ans
    if [[ "${ans,,}" == "y" || "${ans,,}" == "yes" ]]; then
      git config --global --add safe.directory "$cwd"
      echo "✅ Directory trusted. Re-run \`ac\`."
    fi
    exit 1
  fi

  echo "[✘] You are not inside a git repository."
  echo "👉 Run \`ac\` from a git repo directory."
  exit 1
}

looks_like_groq_key() {
  local key="$1"
  if [[ "$key" != gsk_* ]]; then
    echo "[✘] Invalid key format. Groq API keys must start with 'gsk_'."
    return 1
  fi
  if (( ${#key} < 40 || ${#key} > 80 )); then
    echo "[✘] Invalid key length. This does not look like a Groq API key."
    return 1
  fi
  return 0
}

curl_status_body() {
  local url="$1"
  shift
  local tmp status
  tmp="$(mktemp)"
  status="$(curl -sS -o "$tmp" -w "%{http_code}" "$@" "$url" 2>/dev/null)" || {
    rm -f "$tmp"
    return 1
  }
  printf '%s\n' "$status"
  cat "$tmp"
  rm -f "$tmp"
}

is_groq_key_valid() {
  local key="$1" response status
  if ! response="$(curl_status_body "$GROQ_MODELS_URL" -H "Authorization: Bearer $key" --connect-timeout 10 --max-time 10)"; then
    echo "⚠️ Network error. Could not verify API key right now."
    return 2
  fi

  status="$(printf '%s\n' "$response" | sed -n '1p')"
  case "$status" in
    200) return 0 ;;
    401|403) return 1 ;;
    *)
      echo "⚠️ Groq API responded with status $status."
      return 1
      ;;
  esac
}

set_api_key_interactive() {
  local key ans
  mkdir -p "$CONFIG_DIR"

  while true; do
    read -r -p "🔑 Enter Groq API key: " key
    key="${key#"${key%%[![:space:]]*}"}"
    key="${key%"${key##*[![:space:]]}"}"

    looks_like_groq_key "$key" || continue

    if is_groq_key_valid "$key"; then
      printf 'GROQ_API_KEY=%s\n' "$key" >"$ENV_FILE"
      chmod 600 "$ENV_FILE"
      echo "[✔] API key verified and saved locally."
      break
    else
      case "$?" in
        1)
          echo "[✘] This API key is invalid or expired."
          read -r -p "🔁 Try another key? (y/n): " ans
          [[ "${ans,,}" == "y" || "${ans,,}" == "yes" ]] || {
            echo "🚫 API key not changed."
            return
          }
          ;;
        2)
          read -r -p "💾 Save anyway? (y/n): " ans
          if [[ "${ans,,}" == "y" || "${ans,,}" == "yes" ]]; then
            printf 'GROQ_API_KEY=%s\n' "$key" >"$ENV_FILE"
            chmod 600 "$ENV_FILE"
            echo "⚠️ API key saved without verification."
            break
          fi
          echo "🔁 Try again later."
          return
          ;;
      esac
    fi
  done
}

load_api_key() {
  local key
  if [[ -f "$ENV_FILE" ]]; then
    key="$(sed -n 's/^GROQ_API_KEY=//p' "$ENV_FILE" | tail -n 1)"
    [[ -n "$key" ]] && {
      printf '%s\n' "$key"
      return 0
    }
  fi
  echo "[✘] API key not set."
  echo "👉 Run: cak   (to set/change API key)"
  exit 1
}

json_escape() {
  sed ':a;N;$!ba;s/\\/\\\\/g;s/"/\\"/g;s/\r/\\r/g;s/\t/\\t/g;s/\n/\\n/g'
}

json_unescape_basic() {
  sed 's/\\"/"/g;s/\\\\/\\/g;s/\\n/ /g;s/\\r//g;s/\\t/ /g'
}

extract_commit_message() {
  sed -n 's/.*"content"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1 | json_unescape_basic
}

print_boxed_message() {
  local message="$1" length
  length=$(( ${#message} + 4 ))
  printf '\n\033[1;36m╔'
  printf '═%.0s' $(seq 1 "$length")
  printf '╗\n║  %s  ║\n╚' "$message"
  printf '═%.0s' $(seq 1 "$length")
  printf '╝\033[0m\n\n'
}

generate_smart_message() {
  local diff="$1" api_key="$2" escaped_diff payload_file response status body message
  escaped_diff="$(printf '%s' "$diff" | json_escape)"
  payload_file="$(mktemp)"

  cat >"$payload_file" <<EOF
{"model":"llama-3.3-70b-versatile","messages":[{"role":"system","content":"You are a Senior Developer. Write a commit message explaining the intent. RULES: Avoid generic words. Use professional verbs like Polish, Update, Patch, Integrate, Optimize. Max 100 chars. No quotes. No prefixes."},{"role":"user","content":"Diff:\\n$escaped_diff"}],"temperature":0.6,"max_tokens":60}
EOF

  if ! response="$(curl_status_body "$GROQ_CHAT_URL" \
    -H "Authorization: Bearer $api_key" \
    -H "Content-Type: application/json" \
    --connect-timeout 10 \
    --max-time 30 \
    --data-binary "@$payload_file")"; then
    rm -f "$payload_file"
    printf 'Error: Connection Failed\n'
    return
  fi
  rm -f "$payload_file"

  status="$(printf '%s\n' "$response" | sed -n '1p')"
  body="$(printf '%s\n' "$response" | sed '1d')"

  if [[ "$status" != "200" ]]; then
    printf 'Error: API Error (%s)\n' "$status"
    return
  fi

  message="$(printf '%s' "$body" | extract_commit_message | tr -d '"')"
  [[ -n "$message" ]] && printf '%s\n' "$message" || printf 'Error: Empty API Response\n'
}

edit_message() {
  local current="$1" edited
  if [[ -t 0 ]]; then
    read -e -i "$current" -r -p "Edit message: " edited
  else
    read -r -p "Edit message: " edited
  fi
  printf '%s\n' "$edited"
}

commit_and_push() {
  local message="$1"
  git commit -m "$message" || return 1
  echo "🚀 Pushing to GitHub..."
  if git push; then
    echo "[✔] All Done!"
  else
    echo "[✘] Push Failed. Check your git remote/auth."
    return 1
  fi
}

main() {
  local prog api_key diff message confirm new_msg unstage
  prog="$(basename "$0")"

  if [[ "$prog" == "cak" || "${1:-}" == "--set-key" ]]; then
    set_api_key_interactive
    return
  fi

  command -v curl >/dev/null 2>&1 || die "curl is required."
  ensure_git_repo
  api_key="$(load_api_key)"

  git add .
  diff="$(git diff --cached)"
  if [[ -z "$diff" ]]; then
    echo "[✘] No changes found to commit!"
    return
  fi

  echo " ⚡ Analyzing code..."
  while true; do
    message="$(generate_smart_message "$diff" "$api_key")"
    print_boxed_message "$message"

    echo "[y] Confirm & Push   [r] Regenerate   [e] Edit   [n] Cancel"
    read -r -p "Choice: " confirm

    case "${confirm,,}" in
      y|yes|"")
        commit_and_push "$message"
        break
        ;;
      r)
        echo "♻️  Generating new variation..."
        ;;
      e)
        new_msg="$(edit_message "$message")"
        commit_and_push "$new_msg"
        break
        ;;
      *)
        read -r -p "Unstage files? (y/n): " unstage
        if [[ "${unstage,,}" == "y" || "${unstage,,}" == "yes" ]]; then
          git reset
        fi
        echo "🚫 Cancelled."
        break
        ;;
    esac
  done
}

main "$@"
