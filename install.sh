#!/data/data/com.termux/files/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LIB_DIR="$SCRIPT_DIR/lib"
szf="File Size of"
tsize=$(stty size | cut -d ' ' -f 2)
pkgsize=$(apt-cache pkgnames | wc -l)

FILES=(pbanner progress fmenu confzsh)

for f in "${FILES[@]}"; do
  if [[ -f "$LIB_DIR/$f" ]]; then
    . "$LIB_DIR/$f"
  else
    echo "Warning: $LIB_DIR/$f not found"
  fi
done
# ===== Parse Termux color theme from ~/.termux/colors.properties =====
conf() {
  export FZF_DEFAULT_OPTS=""
  COLOR_FILE="$HOME/.termux/colors.properties"

  if [[ -f "$COLOR_FILE" ]]; then
    declare -A color
    while IFS='=' read -r key value; do
      [[ $key =~ ^#.*$ || -z $key ]] && continue
      color[$key]="$value"
    done <"$COLOR_FILE"

    export FZF_DEFAULT_OPTS="--color=fg:${color[foreground]},bg:${color[background]},hl:${color[color4]},fg+:${color[foreground]},bg+:${color[color0]},hl+:#98c379,prompt:#61afef,pointer:#e5c07b,marker:#56b6c2  --reverse --height=10 --no-info --pointer=' '"
  else
    export FZF_DEFAULT_OPTS="--color=hl+:#98c379,prompt:#61afef,pointer:#e5c07b,marker:#56b6c2 --reverse --height=10 --no-info --pointer=' '"
  fi
}

install_packages() {
  # package list
  packages=(curl fd figlet ruby boxes gum bat logo-ls lsd eza zsh timg)

  echo -e "\n[🔧] Installing required packages...\n"

  for pkg in "${packages[@]}"; do
    if command -v "$pkg" >/dev/null 2>&1; then
      echo "[✔] $pkg already installed"
    else
      echo "[➕] Installing $pkg ..."
      pkg install -y "$pkg"
    fi
  done
# ---- Python dependencies for tools ----
if command -v python >/dev/null 2>&1; then
  if python - <<'EOF' >/dev/null 2>&1
import requests
EOF
  then
    echo "[✔] Python package 'requests' already installed"
  else
    echo "[➕] Installing Python package 'requests'..."
    if command -v pip >/dev/null 2>&1; then
      pip install -q --user requests --no-warn-script-location \
        || python -m pip install --user requests --no-warn-script-location
    else
      python -m pip install --user requests --no-warn-script-location
    fi

    # verify install
    if python - <<'EOF' >/dev/null 2>&1
import requests
EOF
    then
      echo "[✔] Python package 'requests' installed successfully"
    else
      echo "[✘] Failed to install Python package 'requests'"
    fi
  fi
else
  echo "[⚠️] Python not found. Skipping Python dependencies."
fi
  # Check for lolcat
  if command -v lolcat >/dev/null 2>&1; then
    echo "[✔] lolcat already installed"
  else
    echo "[➕] Installing lolcat via gem..."
    gem install lolcat
    if command -v lolcat >/dev/null 2>&1; then
      echo "[✔] lolcat installed successfully"
    else
      echo "[✘] lolcat installation failed"
    fi
  fi

  # Download custom figlet font (pixelfont)
  FONT_PATH="$PREFIX/share/figlet/pixelfont.flf"
  if [[ ! -f "$FONT_PATH" ]]; then
    echo "[➕] Downloading pixelfont.flf ..."
    curl -L \
      https://raw.githubusercontent.com/imegeek/figlet-fonts/master/pixelfont.flf \
      -o "$FONT_PATH"
    echo "[✔] Font saved to $FONT_PATH"
  else
    echo "[✔] pixelfont.flf already exists"
  fi

  # Install Nerd Font (UbuntuMono Nerd Font)
  nerdflink="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.4.0/UbuntuMono.zip"
  FONT_DIR="$HOME/.termux"
  mkdir -p "$FONT_DIR"

  if [[ -f "$FONT_DIR/font.ttf" ]]; then
    echo "[✔] Nerd Font already installed at $FONT_DIR/font.ttf"
  else
    TMPDIR=$(mktemp -d)

    echo "[➕] Downloading Nerd Font (UbuntuMono)..."
    curl -L "$nerdflink" -o "$TMPDIR/UbuntuMono.zip"

    echo "[🎨] Installing Nerd Font to $FONT_DIR/font.ttf ..."
    unzip -p "$TMPDIR/UbuntuMono.zip" "UbuntuMonoNerdFontMono-Regular.ttf" >"$FONT_DIR/font.ttf"

    rm -rf "$TMPDIR"

    echo "[✔] Nerd Font installed at $FONT_DIR/font.ttf"
    echo "[ℹ] Restart Termux app to apply new font."
  fi

  # Demo text with lolcat if available
  echo -e "\n[🎨] Demo text:\n"
  if command -v lolcat >/dev/null 2>&1; then
    echo "Installed!" | figlet -f pixelfont | lolcat
  else
    echo "lolcat not Installed!" | figlet -f pixelfont
  fi
  # chsh -s zsh
  # termux-reload-settings
}

# Run function
quick_install() {
  echo -e "\033[1;32m[✔] Starting quick install...\033[0m"
  install_packages

  if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
    echo -e "\033[1;32m[✔] Installing Oh-my-zsh...\033[0m"
    install_oh_my_zsh
  else
    echo -e "\033[1;32m[✔] Oh-my-zsh already installed\033[0m"
  fi

  if command -v zsh >/dev/null 2>&1; then
    chsh -s zsh
  fi

  echo -e "\033[1;36m[ℹ] Running Theader setup...\033[0m"
  setup_theader
  echo -e "\033[1;36m[ℹ] Installing default ZSH plugins...\033[0m"
  install_default_zsh_plugins
  echo -e "\033[1;32m[✔] Quick install complete. Restart Termux or run: zsh\033[0m"
}

menu_main() {

  while true; do
    conf
    banner > ${user}
    cat "${user}"
    echo ""
    choice=$(
      printf "1. Quick Install\n2. Manual Install\n3. Exit" |
        fzf --prompt="Use ↑/↓ to navigate, Enter to select: " --exit-0
    )

    case $choice in
      "1. Quick Install")
        quick_install
        sleep 1
        ;;
      "2. Manual Install")
        menu_manual_install
        ;;
      "3. Exit")
        echo -e "\033[1;31m[✘] Exiting...\033[0m"
        break
        ;;
      *)
        break
        ;;
    esac
  done
}

menu_manual_install() {
  choice=$(
    printf "1. Install packages\n2. Setup\n3. Back" |
      fzf --prompt="Manual Install ➤ " --exit-0
  )

  case $choice in
    "1. Install packages")
      echo -e "\033[1;32m[✔] Installing packages...\033[0m"
      install_packages
      sleep 1
      ;;
    "2. Setup")
      menu_setup
      ;;
    "3. Back")
      return
      ;;
  esac
}

menu_setup() {
  choice=$(
    printf "1. Zsh\n2. Fish (coming soon)" |
      sed 's/2\. Fish (coming soon)/2. Fish \x1b[31m(\x1b[33mcoming soon\x1b[31m)\x1b[0m/' |
      fzf --prompt="Setup option ➤ " --ansi --exit-0
  )

  case $choice in
    "1. Zsh")
      menu_zsh_setup
      # echo -e "\033[1;34m[ℹ] Setting up Zsh...\033[0m"
      sleep 1
      ;;
    "2. Fish (coming soon)")
      echo -e "\033[1;33m[⚠] Fish setup is coming soon!\033[0m"
      sleep 1
      ;;
  esac
}

menu_zsh_setup() {
  # Check if oh-my-zsh is installed
  if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
    # Not installed → only show setup option
    local subchoice
    subchoice=$(
      printf "1. Install Oh-my-zsh" |
        fzf --prompt="Zsh Setup ➤ " --ansi --exit-0
    )
    case $subchoice in
      "1. Install Oh-my-zsh")
        echo -e "\033[1;32m[✔] Installing Oh-my-zsh...\033[0m"
        install_oh_my_zsh
        chsh -s zsh
        ;;
    esac
  else
    # Already installed → show main options
    local main_options="1. Oh-my-zsh (Plugins Manager)\n2. Theader setup"

    local subchoice
    subchoice=$(
      printf "%b" "$main_options" |
        fzf --prompt="Zsh Options ➤ " --ansi --exit-0
    )

    case $subchoice in
      "1. Oh-my-zsh (Plugins Manager)")
        # Plugins Manager submenu
        local plugin_line
        plugin_line=$(sed -n 's/^plugins=(\(.*\))/\1/p' "$ZSHRC" | tr -d ' ')

        local pm_options="1. Add Zsh Plugins"
        # Show remove option only if plugins exist
        if [[ -n "$plugin_line" ]]; then
          pm_options+="\n2. Remove Plugins"
        fi

        local pm_choice
        pm_choice=$(
          printf "%b" "$pm_options" |
            fzf --prompt="Plugins Manager ➤ " --ansi --exit-0
        )

        case $pm_choice in
          "1. Add Zsh Plugins")
            echo -e "\033[1;34m[ℹ] Opening Add Plugins...\033[0m"
            fzf_add_plugin
            ;;
          "2. Remove Plugins")
            echo -e "\033[1;31m[⚠] Removing Zsh Plugins...\033[0m"
            remove_zsh_plugin
            ;;
        esac
        ;;
      "2. Theader setup")
        echo -e "\033[1;36m[ℹ] Running Theader setup...\033[0m"
        # Your Theader setup logic
        menu_theader_setup
        ;;
    esac
  fi
}

# t-header setup
menu_theader_setup() {
  local theader_dir="$HOME/.config/theader"

  # Check if Theader is installed (directory exists)
  if [[ ! -d "$theader_dir" ]]; then
    # Not installed → only show setup option
    local subchoice
    subchoice=$(
      printf "1. Setup Theader" |
        fzf --prompt="Theader Setup ➤ " --ansi --exit-0
    )
    case $subchoice in
      "1. Setup Theader")
        echo -e "\033[1;32m[✔] Setting up Theader...\033[0m"
        setup_theader
        ;;
    esac
  else
    # Already installed → show options
    local main_options="1. Change Logo\n2. Change Title\n3. Change Keyboard\n4. Change ZSH Theme\n5. Remove Theader"

    local subchoice
    subchoice=$(
      printf "%b" "$main_options" |
        fzf --prompt="Theader Options ➤ " --ansi --exit-0
    )

    case $subchoice in
      "1. Change Logo")
        echo -e "\033[1;34m[ℹ] Changing Logo...\033[0m"
        c_logo
        ;;
      "2. Change Title")
        echo -e "\033[1;34m[ℹ] Changing Title...\033[0m"
        type_title
        ;;
      "3. Change Keyboard")
        echo -e "\033[1;34m[ℹ] Changing Keyboard Layout...\033[0m"
        key_properties
        ;;
      "4. Change ZSH Theme")
        echo -e "\033[1;34m[ℹ] Changing ZSH Theme...\033[0m"
        c_theme
        ;;
      "5. Remove Theader")
        echo -e "\033[1;31m[⚠] Removing Theader...\033[0m"
        remove_theader
        ;;
    esac
  fi
}
# theader setup function
setup_theader() {
  theader_dir="$HOME/.config/theader"
  TEMPLATE="$ZSH/templates/zshrc.zsh-template"

  if [ -f "$ZSHRC" ]; then
    line_count=$(wc -l <"$ZSHRC")
    line_104=$(sed -n '104p' "$ZSHRC")

    if [ "$line_count" -gt 104 ] && [[ "$line_104" != *"oh-my-zsh"* ]]; then
      echo "⚠️  .zshrc has $line_count lines and line 104 lacks 'oh-my-zsh', creating backup..."
      cp "$ZSHRC" "$ZSHRC.backup.$(date +%Y%m%d%H%M%S)"

      old_plugins=$(grep "^plugins=" "$ZSHRC" | head -n1)

      if [ -n "$old_plugins" ]; then
        echo "🔗 Found old plugins: $old_plugins"

        # template copy
        cp "$TEMPLATE" "$ZSHRC"

        # template plugins replace
        sed -i "s/^plugins=(git)/$old_plugins/" "$ZSHRC"
        echo "✅ New .zshrc created with preserved plugins"
      else
        echo "⚠️ No plugins line found in old .zshrc, using default"
        cp "$TEMPLATE" "$ZSHRC"
      fi
    else
      echo ".zshrc has $line_count lines or already contains 'oh-my-zsh' at line 104, no reset needed."
    fi
  else
    cp "$TEMPLATE" "$ZSHRC"

    sed -i 's/plugins=(git)/plugins=()/' "$ZSHRC"
    echo "✅ Default .zshrc created"
  fi
  create_custom_theme
  change_zsh_theme "unstop"
  cp "$SCRIPT_DIR"/dotfile/.* "$HOME"/

  if ! grep -q 'source "$HOME/.profile"' "$HOME/.zshrc" 2>/dev/null; then
    cat >>"$HOME/.zshrc" <<'EOF'

HISTSIZE=100000
SAVEHIST=100000
export USER=$(whoami)
source "$HOME/.profile"
banner >> "${user}"
cat "${user}"
EOF
  fi

  if ! grep -q 'source "$HOME/.profile"' "$HOME/.zprofile" 2>/dev/null; then
    printf '\n# profile source\nsource "$HOME/.profile"\n' >>"$HOME/.zprofile"
  fi

  sed -i '/# theader aliases start/,/# theader aliases end/d' "$HOME/.zshrc" 2>/dev/null || true
  cat >>"$HOME/.zshrc" <<'EOF'

# theader aliases start
source "$HOME/.profile"
unalias l ls l. la ll ll. lsg lag llg ils ila ill ilsg ilag illg 2>/dev/null

case "${ZSH_THEME:-}" in
  unstop)
    if command -v logo-ls >/dev/null 2>&1; then
      alias l='logo-ls'
      alias ls='logo-ls'
      alias l.='logo-ls -d .*'
      alias la='logo-ls -A'
      alias ll='logo-ls -al'
      alias ll.='logo-ls -ald .*'
      alias lsg='logo-ls -D'
      alias lag='logo-ls -AD'
      alias llg='logo-ls -alD'
      alias ils='logo-ls'
      alias ila='logo-ls -A'
      alias ill='logo-ls -al'
      alias ilsg='logo-ls -D'
      alias ilag='logo-ls -AD'
      alias illg='logo-ls -alD'
    fi
    ;;
  robbyrussell|rubbyrossel|rubyrossel)
    if command -v eza >/dev/null 2>&1; then
      alias l='eza --icons=always --group-directories-first'
      alias ls='eza --icons=always --group-directories-first'
      alias l.='eza -d .* --icons=always --group-directories-first'
      alias la='eza -A --icons=always --group-directories-first'
      alias ll='eza -al --icons=always --group-directories-first --git'
      alias ll.='eza -ald .* --icons=always --group-directories-first --git'
      alias lsg='eza --tree --level=2 --icons=always --group-directories-first'
      alias lag='eza -A --tree --level=2 --icons=always --group-directories-first'
      alias llg='eza -al --tree --level=2 --icons=always --group-directories-first --git'
      alias ils='eza --icons=always --group-directories-first'
      alias ila='eza -A --icons=always --group-directories-first'
      alias ill='eza -al --icons=always --group-directories-first --git'
      alias ilsg='eza --tree --level=2 --icons=always --group-directories-first'
      alias ilag='eza -A --tree --level=2 --icons=always --group-directories-first'
      alias illg='eza -al --tree --level=2 --icons=always --group-directories-first --git'
    fi
    ;;
esac

if ! alias ls >/dev/null 2>&1; then
  if command -v lsd >/dev/null 2>&1; then
    alias l='lsd'
    alias ls='lsd'
    alias l.='lsd -d .*'
    alias la='lsd -A'
    alias ll='lsd -al'
    alias ll.='lsd -ald .*'
    alias lsg='lsd --tree'
    alias lag='lsd -A --tree'
    alias llg='lsd -al --tree'
    alias ils='lsd'
    alias ila='lsd -A'
    alias ill='lsd -al'
    alias ilsg='lsd --tree'
    alias ilag='lsd -A --tree'
    alias illg='lsd -al --tree'
  else
    alias l='ls --color=auto'
    alias ls='ls --color=auto'
    alias l.='ls --color=auto -d .*'
    alias la='ls --color=auto -A'
    alias ll='ls --color=auto -al'
    alias ll.='ls --color=auto -ald .*'
  fi
fi
# theader aliases end
EOF

  mkdir -p "$theader_dir"
  for d in bin logo tpt lib theader.cfg; do
    if [[ -e "$SCRIPT_DIR/$d" ]]; then
      cp -r "$SCRIPT_DIR/$d" "$theader_dir/"
    else
      echo "Warning: missing $SCRIPT_DIR/$d"
    fi
  done
  if [[ -f $SCRIPT_DIR/colors.properties ]]; then
    cp -r $SCRIPT_DIR/colors.properties $HOME/.termux/
  fi
  if [[ -f $theader_dir/bin/theader ]]; then
    install -Dm700 $theader_dir/bin/theader "$PREFIX"/bin/theader
    for i in clogo ctitle ctpro cztheme; do
      ln -sfr "$PREFIX"/bin/theader "$PREFIX"/bin/$i
    done
    echo "theader installed successfully ✅"
  else
    echo "Error: $theader_dir/bin/theader not found!"
  fi

# Install commit tool (ac / cak)
mkdir -p "$PREFIX/bin"

TOOL_SRC="$SCRIPT_DIR/tools/commit.py"
TOOL_DST="$PREFIX/bin/ac"

if [[ -f "$TOOL_SRC" ]]; then
  install -Dm700 "$TOOL_SRC" "$TOOL_DST" || {
    echo "[✘] Failed to install ac"
    return 1
  }
  echo "✅ ac installed to $TOOL_DST"
else
  echo "[✘] Missing $TOOL_SRC"
  return 1
fi

# change-api-key helper
rm -f "$PREFIX/bin/cak"
ln -sfr "$TOOL_DST" "$PREFIX/bin/cak"

# refresh shell command cache
hash -r 2>/dev/null || true
}
# packages list must above 2000
if ((pkgsize < 2000)); then
  echo -ne "\033[31m\r[*] \033[4;32mPackage Update and Upgrade or change repo \e[0m\n"
  exit 1
fi
# ✅ Check fzf installed or not
if ! command -v fzf >/dev/null 2>&1; then
  echo -e "\033[31m[*] \033[4;32mfzf command not found!\033[0m"
  echo -e "\033[1;33mThis tool requires fzf to continue.\033[0m"
  read -r -p "👉 Install fzf now? [Y/n]: " ans

  # normalize input to lowercase
  ans="${ans,,}"

  case "$ans" in
    y|yes)
      echo "[➕] Installing fzf..."
      pkg install -y fzf
      if command -v fzf >/dev/null 2>&1; then
        echo "[✔] fzf installed successfully."
      else
        echo "[✘] fzf installation failed. Please install manually:"
        echo "    pkg install fzf -y"
        exit 1
      fi
      ;;
    n|no)
      echo "🚫 Installation cancelled by user."
      echo "👉 You can install later with: pkg install fzf -y"
      exit 1
      ;;
    *)
      echo "[✘] Invalid choice. Please answer y or n."
      exit 1
      ;;
  esac
fi

# Run main menu
menu_main
