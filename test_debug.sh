#!/bin/bash

echo "🔍 Script de test debug - Compilation et lancement"

# Compilation
echo "🔍 Compilation en cours..."
meson compile -C build

if [ $? -eq 0 ]; then
    echo "🔍 Compilation réussie, lancement de l'application avec debug..."
    # Lancement avec affichage forcé de stderr
    ./build/Sambo 2>&1 | tee debug_messages.log
else
    echo "❌ Erreur de compilation"
    exit 1
fi
