#!/bin/bash

# Script de lancement pour Sambo
# Assure que les bibliothèques llama.cpp et ggml sont trouvées

# Répertoire du script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Ajouter le répertoire des bibliothèques au LD_LIBRARY_PATH
export LD_LIBRARY_PATH="$SCRIPT_DIR/build/subprojects/llama:$LD_LIBRARY_PATH"

# Configuration optionnelle pour GSettings
export GSETTINGS_SCHEMA_DIR="$HOME/.local/share/glib-2.0/schemas:/usr/local/share/glib-2.0/schemas:$GSETTINGS_SCHEMA_DIR"

# Lancer l'application
exec "$SCRIPT_DIR/build/Sambo" "$@"
