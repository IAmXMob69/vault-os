#!/usr/bin/env bash
# Pip-Boy 3000 shell theme for bash
# Sourced from ~/.bashrc

# Guard: interactive only
[[ $- != *i* ]] && return

# ── Colors (truecolor green phosphor) ──────────────────────────
export PIPBOY_G=$'\033[38;2;46;242;106m'
export PIPBOY_D=$'\033[38;2;27;107;56m'
export PIPBOY_B=$'\033[1m'
export PIPBOY_R=$'\033[0m'
export PIPBOY_WARN=$'\033[38;2;255;200;50m'

# ── dircolors ──────────────────────────────────────────────────
if [[ -r "$HOME/.config/pipboy/dircolors" ]] && command -v dircolors >/dev/null 2>&1; then
  eval "$(dircolors -b "$HOME/.config/pipboy/dircolors")"
fi

# Force greener less/man if possible
export LESS_TERMCAP_mb=$'\033[1;32m'
export LESS_TERMCAP_md=$'\033[1;32m'
export LESS_TERMCAP_me=$'\033[0m'
export LESS_TERMCAP_se=$'\033[0m'
export LESS_TERMCAP_so=$'\033[30;42m'
export LESS_TERMCAP_ue=$'\033[0m'
export LESS_TERMCAP_us=$'\033[4;32m'
export GROFF_NO_SGR=1

# ── Prompt ─────────────────────────────────────────────────────
# Example:
#   ┌─[ PIP-BOY 3000 ]─[ dweller@host ]─[ ~/Games ]
#   └─►
__pipboy_prompt() {
  local exit_code=$?
  local g='\[\033[38;2;46;242;106m\]'
  local d='\[\033[38;2;27;107;56m\]'
  local b='\[\033[1m\]'
  local r='\[\033[0m\]'
  local w='\[\033[38;2;255;180;40m\]'
  local path="${PWD/#$HOME/\~}"
  # Truncate long paths
  if (( ${#path} > 40 )); then
    path="…/${path##*/}"
  fi
  local status=""
  if (( exit_code != 0 )); then
    status="${w}!${exit_code}${d}─"
  fi
  PS1="${d}+=${g}${b}[ PIP-BOY 3000 ]${r}${d}-${status}${g}[ \u@\h ]${d}-${g}[ ${path} ]${r}\n${d}+-${g}>${r} "
  PS2="${d}| ${g}...${r} "
}

PROMPT_COMMAND="__pipboy_prompt${PROMPT_COMMAND:+; $PROMPT_COMMAND}"

# ── Aliases ────────────────────────────────────────────────────
alias ls='ls --color=auto'
alias ll='ls -lah --color=auto'
alias la='ls -A --color=auto'
alias grep='grep --color=auto'
alias pipboy-status='"$HOME/.config/pipboy/status.sh"'
alias pipboy-banner='source "$HOME/.config/pipboy/banner.sh"'
alias pipboy-amber='"$HOME/.config/pipboy/switch-theme.sh" amber'
alias pipboy-green='"$HOME/.config/pipboy/switch-theme.sh" green'
alias vault='cd "$HOME/Games/gog/fallout-new-vegas-ultimate-edition" 2>/dev/null || cd "$HOME/Games" || cd'
alias vault-os='$HOME/.local/bin/vault-os'
alias vault-status='$HOME/.local/bin/vault-os status'
alias vault-doctor='$HOME/.local/bin/vault-os doctor'

# ── Help ───────────────────────────────────────────────────────
help-pipboy() {
  cat <<EOF
${PIPBOY_G}${PIPBOY_B}PIP-BOY 3000 - TERMINAL COMMANDS${PIPBOY_R}
${PIPBOY_D}--------------------------------${PIPBOY_R}
  pipboy-banner     Re-run boot sequence
  pipboy-status     System / radiation-style stats
  pipboy-green      Classic green phosphor
  pipboy-amber      Amber Pip-Boy variant
  vault             Jump to Fallout NV install
  vault-os          Control plane (status/doctor/apply)
  vault-status      Quick health check
  vault-doctor      Repair theme/panels

  Theme files: ~/.config/pipboy/
  Terminal:    ~/.config/xfce4/terminal/terminalrc
${PIPBOY_D}--------------------------------${PIPBOY_R}
EOF
}

# ── Boot banner (once per terminal session) ────────────────────
if [[ -z "${PIPBOY_BOOTED:-}" && -t 1 ]]; then
  export PIPBOY_BOOTED=1
  # Skip banner in nested shells / vscode / dumb terms
  if [[ -z "${VSCODE_INJECTION:-}" && "${TERM:-}" != "dumb" && -z "${PIPBOY_NO_BANNER:-}" ]]; then
    # shellcheck source=/dev/null
    source "$HOME/.config/pipboy/banner.sh"
  fi
fi
