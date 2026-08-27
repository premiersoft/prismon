#!/bin/sh
# Instala o prismon CLI a partir do GitHub Releases (repo público, sem auth).
#
# Uso:
#   curl -fsSL https://raw.githubusercontent.com/premiersoft/prismon/main/install.sh | sh
#   PRISMON_VERSION=0.1.0 sh install.sh   # versão específica
#
# Variáveis:
#   PRISMON_VERSION      versão sem o "v" (default: latest)
#   PRISMON_INSTALL_DIR  default: ~/.local/bin
set -eu

REPO="premiersoft/prismon"
INSTALL_DIR="${PRISMON_INSTALL_DIR:-$HOME/.local/bin}"
# Forma com $HOME literal, para o rc não ficar preso ao caminho absoluto atual.
case "$INSTALL_DIR" in
  "$HOME"/*) INSTALL_DIR_LITERAL="\$HOME${INSTALL_DIR#"$HOME"}" ;;
  *) INSTALL_DIR_LITERAL="$INSTALL_DIR" ;;
esac
# Mesmo marcador que o CLI grava em path_entry.go: os dois reconhecem o bloco um
# do outro e nenhum duplica a linha.
PATH_MARKER="# added by prismon-install"

log() { printf 'prismon-install: %s\n' "$*" >&2; }
fail() { printf 'prismon-install: erro: %s\n' "$*" >&2; exit 1; }

detect_platform() {
  os="$(uname -s | tr '[:upper:]' '[:lower:]')"
  arch="$(uname -m)"
  case "$os" in
    darwin|linux) ;;
    *) fail "sistema $os não suportado por este script (no Windows, baixe o .zip do release)" ;;
  esac
  case "$arch" in
    x86_64|amd64) arch="amd64" ;;
    arm64|aarch64) arch="arm64" ;;
    *) fail "arquitetura $arch não suportada" ;;
  esac
  printf '%s_%s' "$os" "$arch"
}

resolve_version() {
  if [ -n "${PRISMON_VERSION:-}" ]; then
    printf '%s' "$PRISMON_VERSION"
    return
  fi
  curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" \
    | sed -n 's/.*"tag_name": *"v\{0,1\}\([^"]*\)".*/\1/p' | head -1
}

main() {
  platform="$(detect_platform)"
  version="$(resolve_version)"
  [ -n "$version" ] || fail "não foi possível resolver a versão (nenhum release em https://github.com/$REPO/releases)"
  log "versão $version, plataforma $platform"

  bundle="prismon_${version}_${platform}.tar.gz"
  url="https://github.com/$REPO/releases/download/v${version}/${bundle}"
  tmpdir="$(mktemp -d)"
  trap 'rm -rf "$tmpdir"; rm -f "${staged:-}" 2>/dev/null || true' EXIT

  log "baixando $url"
  curl -fsSL "$url" -o "$tmpdir/$bundle" || fail "download falhou — confira se o release v$version tem o asset $bundle"

  tar -xzf "$tmpdir/$bundle" -C "$tmpdir" -O prismon > "$tmpdir/prismon-bin" \
    || fail "pacote não contém o binário prismon"

  mkdir -p "$INSTALL_DIR"
  # Escrita atômica em arquivo novo + rename. Um `cp` direto seguiria o symlink
  # do layout versionado (~/.prismon/versions/<v>/prismon) e sobrescreveria um
  # Mach-O assinado in-place: o macOS invalida a assinatura em cache do inode e
  # mata qualquer execução com SIGKILL ("zsh: killed").
  staged="$INSTALL_DIR/.prismon.install.$$"
  rm -f "$staged"
  cp "$tmpdir/prismon-bin" "$staged"
  chmod +x "$staged"
  xattr -d com.apple.quarantine "$staged" 2>/dev/null || true

  if command -v shasum >/dev/null 2>&1; then
    sums_url="https://github.com/$REPO/releases/download/v${version}/prismon_${version}_checksums.txt"
    if curl -fsSL "$sums_url" -o "$tmpdir/checksums.txt" 2>/dev/null; then
      expected="$(grep "  $bundle\$" "$tmpdir/checksums.txt" | awk '{print $1}')"
      actual="$(shasum -a 256 "$tmpdir/$bundle" | awk '{print $1}')"
      if [ -n "$expected" ] && [ "$expected" != "$actual" ]; then
        rm -f "$staged"
        fail "checksum não confere (esperado $expected, obtido $actual)"
      fi
      [ -n "$expected" ] && log "checksum ok"
    fi
  fi

  mv -f "$staged" "$INSTALL_DIR/prismon"

  log "instalado em $INSTALL_DIR/prismon"

  case ":$PATH:" in
    *":$INSTALL_DIR:"*)
      log "rode: prismon"
      return
      ;;
  esac

  # ~/.local/bin não é PATH default no macOS nem em boa parte das distros. Até a
  # 0.5.10 o script só avisava e mandava rodar `prismon` na linha seguinte, o que
  # levava direto a "command not found" numa máquina do zero. Sob `curl | sh` não
  # há stdin interativo para perguntar, então gravamos o export no rc do shell.
  case "${SHELL:-}" in
    */fish) primary_rc="$HOME/.config/fish/config.fish" ;;
    */bash) primary_rc="$HOME/.bashrc" ;;
    *) primary_rc="$HOME/.zshrc" ;;
  esac
  [ "$primary_rc" = "$HOME/.config/fish/config.fish" ] && mkdir -p "$HOME/.config/fish"

  wrote=""
  for rc in "$primary_rc" "$HOME/.zshrc" "$HOME/.bashrc" "$HOME/.bash_profile" "$HOME/.config/fish/config.fish"; do
    [ -e "$rc" ] || [ "$rc" = "$primary_rc" ] || continue
    case " $wrote " in *" $rc "*) continue ;; esac
    if [ -e "$rc" ] && grep -q "$PATH_MARKER" "$rc" 2>/dev/null; then
      wrote="$wrote $rc"
      continue
    fi
    case "$rc" in
      *config.fish) line="set -gx PATH \"$INSTALL_DIR_LITERAL\" \$PATH" ;;
      *) line="export PATH=\"$INSTALL_DIR_LITERAL:\$PATH\"" ;;
    esac
    {
      printf '\n%s\n' "$PATH_MARKER"
      printf '%s\n' "$line"
    } >> "$rc" 2>/dev/null && wrote="$wrote $rc"
  done

  if [ -n "$wrote" ]; then
    log "PATH configurado em:$wrote"
  else
    log "aviso: não foi possível editar seu rc para configurar o PATH"
  fi
  # O script roda num processo filho e não altera o PATH do shell que o chamou:
  # sem esta linha o usuário volta a esbarrar em "command not found".
  log "rode agora:  export PATH=\"$INSTALL_DIR:\$PATH\" && prismon"
  log "(em terminais novos, só: prismon)"
}

main "$@"
