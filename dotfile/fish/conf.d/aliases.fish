# =========[ logo-ls aliases Setup ]=========

if type -q logo-ls
    alias l "logo-ls"
    alias ls "logo-ls"
    alias l. "logo-ls -d .*"
    alias la "logo-ls -A"
    alias ll "logo-ls -al"
    alias ll. "logo-ls -ald .*"
else
    alias l "ls --color=auto"
    alias ls "ls --color=auto"
    alias l. "ls --color=auto -d .*"
    alias la "ls --color=auto -a"
    alias ll "ls --color=auto -Fhl"
    alias ll. "ls --color=auto -Fhl -d .*"
end

# =========[ Replace cat with bat Setup ]=========
if type -q bat
    alias cat "bat --decorations=never --paging=never"
end

# =========[ Safety aliases ]=========
alias cp "cp -i"
alias ln "ln -i"
alias mv "mv -i"
alias rm "rm -i"

# =========[ Neovim Text Editor ]=========
if type -q nvim
    alias nv "nvim"
end
