#!/bin/bash
# Script pour installer l'icône et le .desktop de Sambo dans les chemins standards système
set -e

ICON_SRC="data/icons/hicolor/scalable/apps/com.cabineteto.Sambo.png"
ICON_DST="/usr/share/icons/hicolor/scalable/apps/com.cabineteto.Sambo.png"
DESKTOP_SRC="build/com.cabineteto.Sambo.desktop"
DESKTOP_DST="/usr/share/applications/com.cabineteto.Sambo.desktop"

if [ $EUID -ne 0 ]; then
  echo "Ce script doit être lancé en tant que root (sudo)."
  exit 1
fi

# Copie de l'icône
install -Dm644 "$ICON_SRC" "$ICON_DST"
echo "[OK] Icône installée dans $ICON_DST"

# Copie du .desktop
install -Dm644 "$DESKTOP_SRC" "$DESKTOP_DST"
echo "[OK] Fichier desktop installé dans $DESKTOP_DST"

# Mise à jour du cache d'icônes
if command -v gtk-update-icon-cache >/dev/null; then
  gtk-update-icon-cache -f /usr/share/icons/hicolor
  echo "[OK] Cache d'icônes mis à jour."
else
  echo "[WARN] gtk-update-icon-cache non trouvé. Pensez à le lancer manuellement si besoin."
fi

echo "[INFO] Déconnectez/reconnectez votre session ou redémarrez le shell graphique pour voir l'icône dans le dash/barre."
