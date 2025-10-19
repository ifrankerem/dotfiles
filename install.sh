#!/usr/bin/env bash
set -euo pipefail

log() { printf "\033[1;32m[dotfiles]\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m[dotfiles]\033[0m %s\n" "$*"; }
err() { printf "\033[1;31m[dotfiles]\033[0m %s\n" "$*" >&2; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- 1) VS Code kullanıcı dizinini tespit et (Code / VSCodium + OS) ---
detect_code_user_dir() {
  local base
  case "$(uname -s)" in
    Linux*)
      # VS Code
      if [ -d "$HOME/.config/Code/User" ]; then echo "$HOME/.config/Code/User"; return 0; fi
      # VSCodium
      if [ -d "$HOME/.config/VSCodium/User" ]; then echo "$HOME/.config/VSCodium/User"; return 0; fi
      # Yoksa Code varsayılanı
      echo "$HOME/.config/Code/User"
      ;;
    Darwin*)
      # macOS
      # VS Code
      base="$HOME/Library/Application Support/Code/User"
      if [ -d "$base" ]; then echo "$base"; return 0; fi
      # VSCodium
      base="$HOME/Library/Application Support/VSCodium/User"
      if [ -d "$base" ]; then echo "$base"; return 0; fi
      # Yoksa Code varsayılanı
      echo "$HOME/Library/Application Support/Code/User"
      ;;
    *) echo "$HOME/.config/Code/User" ;;
  esac
}

CODE_USER_DIR="$(detect_code_user_dir)"
mkdir -p "$CODE_USER_DIR"

# --- 2) settings.jsonc kopyala ve link oluştur ---
SRC_SETTINGS="$SCRIPT_DIR/.config/Code/User/settings.jsonc"
DST_JSONC="$CODE_USER_DIR/settings.jsonc"
DST_JSON="$CODE_USER_DIR/settings.json"

if [ -f "$SRC_SETTINGS" ]; then
  ts="$(date +%Y%m%d-%H%M%S)"
  if [ -f "$DST_JSON" ] || [ -f "$DST_JSONC" ]; then
    log "Mevcut VS Code ayarları yedekleniyor…"
    [ -f "$DST_JSON" ]  && cp -f "$DST_JSON"  "$DST_JSON.bak.$ts"  || true
    [ -f "$DST_JSONC" ] && cp -f "$DST_JSONC" "$DST_JSONC.bak.$ts" || true
  fi

  log "settings.jsonc yerleştiriliyor → $DST_JSONC"
  mkdir -p "$(dirname "$DST_JSONC")"
  cp -f "$SRC_SETTINGS" "$DST_JSONC"

  # settings.json -> settings.jsonc symlink (VS Code iki ismi de okur)
  ln -sfn "$DST_JSONC" "$DST_JSON"
else
  warn "Kaynak ayar bulunamadı: $SRC_SETTINGS (atla)."
fi

# --- 3) code CLI (veya code-insiders / vscodium) tespit ---
detect_code_cli() {
  if command -v code >/dev/null 2>&1; then echo "code"; return 0; fi
  if command -v code-insiders >/dev/null 2>&1; then echo "code-insiders"; return 0; fi
  if command -v codium >/dev/null 2>&1; then echo "codium"; return 0; fi
  return 1
}

if CODE_CLI="$(detect_code_cli)"; then
  log "VS Code CLI: $CODE_CLI"
else
  warn "VS Code CLI bulunamadı (code / code-insiders / codium). Extensions kurulumu atlanacak."
  CODE_CLI=""
fi

# --- 4) Extensions kurulum ---
# Öncelik: dotfiles/extensions.txt → değilse varsayılan temel liste
EXT_LIST_FILE="$SCRIPT_DIR/extensions.txt"

DEFAULT_EXTS=(
  "ms-vscode.cpptools"            # C/C++ IntelliSense
  "ms-vscode.cpptools-extension-pack"
  "ms-vscode.cmake-tools"
  "twxs.cmake"
  "jeff-hykin.better-cpp-syntax"
  "keyhr.42-c-format"             # 42 c-format
  "ms-python.python"              # pip/norminette işleri için faydalı
  "pkief.material-icon-theme"     # simge seti
)

install_extensions() {
  local cli="$1"
  shift
  local exts=("$@")
  for ext in "${exts[@]}"; do
    [ -n "$ext" ] || continue
    log "→ $ext"
    "$cli" --install-extension "$ext" --force >/dev/null 2>&1 || warn "Kurulamadı: $ext"
  done
}

if [ -n "$CODE_CLI" ]; then
  if [ -f "$EXT_LIST_FILE" ]; then
    log "extensions.txt bulundu, yükleniyor…"
    mapfile -t EXTS < <(grep -v '^\s*$' "$EXT_LIST_FILE" | sed 's/#.*//')
    install_extensions "$CODE_CLI" "${EXTS[@]}"
  else
    warn "extensions.txt yok. Temel önerilen eklentiler kurulacak."
    install_extensions "$CODE_CLI" "${DEFAULT_EXTS[@]}"
  fi
else
  warn "CLI yok → eklenti kurulumu atlandı."
fi

log "Bitti ✅  (Ayarlar: $CODE_USER_DIR)"
