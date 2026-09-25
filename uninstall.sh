#!/bin/sh
# Desinstala o Prismon Guardian. O tipo "macOS app (PKG)" do Intune não tem
# assignment de Uninstall, então este script é entregue como shell script do
# Intune (ou rodado à mão com sudo).
#
# Uso:
#   sudo pkg/uninstall.sh            # remove o Guardian, preserva ~/.prismon
#   sudo pkg/uninstall.sh --purge    # remove também ~/.prismon de cada perfil
set -eu

PRISMON=/usr/local/bin/prismon
PKG_IDENTIFIER=ai.prismon.guardian
APP="/Applications/Prismon Guardian.app"
PURGE=""

if [ "${1:-}" = "--purge" ]; then
  PURGE=--purge
elif [ -n "${1:-}" ]; then
  echo "uso: uninstall.sh [--purge]" >&2
  exit 1
fi

if [ "$(id -u)" -ne 0 ]; then
  echo "prismon: rode como root (sudo)" >&2
  exit 1
fi

if [ -x "$PRISMON" ]; then
  if [ -n "$PURGE" ]; then
    "$PRISMON" machine cleanup --purge
  else
    "$PRISMON" machine cleanup
  fi
else
  echo "prismon: $PRISMON não está instalado — seguindo com a remoção do receipt" >&2
fi

launchctl bootout system/ai.prismon.proxyd >/dev/null 2>&1 || true
rm -rf "$APP"
rm -f /Library/LaunchAgents/ai.prismon.setup.plist
rm -f /Library/LaunchAgents/ai.prismon.orgca.plist
rm -f /Library/LaunchAgents/ai.prismon.setupretry.plist
rm -f /Library/LaunchDaemons/ai.prismon.proxyd.plist
rm -f /var/run/ai.prismon.proxyd.sock
pkgutil --forget "$PKG_IDENTIFIER" >/dev/null 2>&1 || true

echo "prismon: Guardian removido."
exit 0
