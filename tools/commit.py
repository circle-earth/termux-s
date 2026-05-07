#!/usr/bin/env python3
import os
import subprocess
import json
import sys
import readline
from pathlib import Path

# ---- dependency guard ----
try:
    import requests
except ImportError:
    print("[✘] Missing dependency: requests")
    print("👉 Install: pip install --user requests")
    sys.exit(1)

# ---- config paths ----
CONFIG_DIR = Path.home() / ".local" / "bin"
ENV_FILE = CONFIG_DIR / ".env"

# ---------- Git Repo Guard (safe.directory aware) ----------
def ensure_git_repo():
    try:
        out = subprocess.check_output(
            ['git', 'rev-parse', '--is-inside-work-tree'],
            stderr=subprocess.STDOUT,
            text=True
        ).strip()
        if out != "true":
            raise RuntimeError("Not inside repo")
    except subprocess.CalledProcessError as e:
        msg = (e.output or "").lower()
        cwd = os.getcwd()

        if "dubious ownership" in msg or "safe.directory" in msg:
            print("⚠️ Git blocked this repository due to ownership/safe.directory restriction.")
            print("👉 Trust this directory by running:")
            print(f'   git config --global --add safe.directory "{cwd}"')
            ans = input("👉 Auto-fix now? (y/n): ").lower()
            if ans in ("y", "yes"):
                subprocess.run(['git', 'config', '--global', '--add', 'safe.directory', cwd])
                print("✅ Directory trusted. Re-run `ac`.")
            sys.exit(1)

        print("[✘] You are not inside a git repository.")
        print("👉 Run `ac` from a git repo directory.")
        sys.exit(1)

# ---------- API Key Handling ----------
def looks_like_groq_key(key: str) -> bool:
    if not key.startswith("gsk_"):
        print("[✘] Invalid key format. Groq API keys must start with 'gsk_'.")
        return False
    if len(key) < 40 or len(key) > 80:
        print("[✘] Invalid key length. This does not look like a Groq API key.")
        return False
    return True

def is_groq_key_valid(key: str):
    url = "https://api.groq.com/openai/v1/models"
    headers = {"Authorization": f"Bearer {key}"}
    try:
        r = requests.get(url, headers=headers, timeout=10)
        if r.status_code == 200:
            return True
        elif r.status_code in (401, 403):
            return False
        else:
            print(f"⚠️ Groq API responded with status {r.status_code}.")
            return False
    except requests.exceptions.RequestException:
        print("⚠️ Network error. Could not verify API key right now.")
        return None  # network issue

def set_api_key_interactive():
    CONFIG_DIR.mkdir(parents=True, exist_ok=True)

    while True:
        key = input("🔑 Enter Groq API key: ").strip()

        if not looks_like_groq_key(key):
            continue

        validity = is_groq_key_valid(key)

        if validity is True:
            ENV_FILE.write_text(f"GROQ_API_KEY={key}\n")
            os.chmod(ENV_FILE, 0o600)
            print("[✔] API key verified and saved locally.")
            break

        elif validity is False:
            print("[✘] This API key is invalid or expired.")
            if input("🔁 Try another key? (y/n): ").lower() not in ("y", "yes"):
                print("🚫 API key not changed.")
                return

        else:
            print("⚠️ Could not verify key due to network issue.")
            if input("💾 Save anyway? (y/n): ").lower() in ("y", "yes"):
                ENV_FILE.write_text(f"GROQ_API_KEY={key}\n")
                os.chmod(ENV_FILE, 0o600)
                print("⚠️ API key saved without verification.")
                break
            else:
                print("🔁 Try again later.")
                return

def load_api_key():
    if ENV_FILE.exists():
        for line in ENV_FILE.read_text().splitlines():
            if line.startswith("GROQ_API_KEY="):
                return line.split("=", 1)[1].strip()
    print("[✘] API key not set.")
    print("👉 Run: cak   (to set/change API key)")
    sys.exit(1)

# ---------- Git helpers ----------
def get_git_diff():
    try:
        diff = subprocess.check_output(['git', 'diff', '--cached'], text=True).strip()
        return diff
    except Exception:
        return None

def input_with_prefill(prompt, text):
    def hook():
        readline.insert_text(text)
        readline.redisplay()
    readline.set_pre_input_hook(hook)
    result = input(prompt)
    readline.set_pre_input_hook(None)
    return result

def print_boxed_message(message):
    length = len(message) + 4
    print("\n\033[1;36m" + "╔" + "═" * length + "╗")
    print(f"║  {message}  ║")
    print("╚" + "═" * length + "╝" + "\033[0m\n")

# ---------- Groq Commit Message ----------
def generate_smart_message(diff, api_key):
    url = "https://api.groq.com/openai/v1/chat/completions"
    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json"
    }

    system_instruction = """
You are a Senior Developer. Write a commit message explaining the intent.
RULES:
1. AVOID generic words like "", "".
2. USE professional verbs: "Polish", "Update", "Patch", "Integrate", "Optimize".
3. Max 100 chars. No quotes. No prefixes.
"""

    data = {
        "model": "llama-3.3-70b-versatile",
        "messages": [
            {"role": "system", "content": system_instruction},
            {"role": "user", "content": f"Diff:\n{diff}"}
        ],
        "temperature": 0.6,
        "max_tokens": 60
    }

    try:
        r = requests.post(url, headers=headers, json=data, timeout=30)
        if r.status_code == 200:
            return r.json()['choices'][0]['message']['content'].strip().replace('"', '')
        else:
            return f"Error: API Error ({r.status_code})"
    except Exception:
        return "Error: Connection Failed"

# ---------- Main ----------
def main():
    import argparse
    parser = argparse.ArgumentParser(add_help=False)
    parser.add_argument("--set-key", action="store_true")
    args, _ = parser.parse_known_args()

    prog = os.path.basename(sys.argv[0])

    # cak command OR --set-key flag
    if prog == "cak" or args.set_key:
        set_api_key_interactive()
        return

    ensure_git_repo()
    api_key = load_api_key()

    subprocess.run(['git', 'add', '.'])

    diff = get_git_diff()
    if not diff:
        print("[✘] No changes found to commit!")
        return

    print(" ⚡ Analyzing code...")

    while True:
        message = generate_smart_message(diff, api_key)
        print_boxed_message(message)

        print("[y] Confirm & Push   [r] Regenerate   [e] Edit   [n] Cancel")
        confirm = input("Choice: ").lower()

        if confirm in ("y", "yes", ""):
            subprocess.run(['git', 'commit', '-m', message])
            print("🚀 Pushing to GitHub...")
            push_result = subprocess.run(['git', 'push'])

            if push_result.returncode == 0:
                print("[✔] All Done!")
            else:
                print("[✘] Push Failed. Check your git remote/auth.")
            break

        elif confirm in ("r",):
            print("♻️  Generating new variation...")
            continue

        elif confirm in ("e",):
            new_msg = input_with_prefill("Edit message: ", message)
            subprocess.run(['git', 'commit', '-m', new_msg])
            print("🚀 Pushing to GitHub...")
            subprocess.run(['git', 'push'])
            print("[✔] All Done!")
            break

        else:
            if input("Unstage files? (y/n): ").lower() in ("y", "yes"):
                subprocess.run(['git', 'reset'])
            print("🚫 Cancelled.")
            break

if __name__ == "__main__":
    main()
