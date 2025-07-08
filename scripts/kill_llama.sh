#!/bin/bash

# Script pour tuer brutalement les processus llama.cpp
# Utilisé en cas d'urgence quand l'arrêt normal ne fonctionne pas

echo "🔍 Recherche des processus llama.cpp..."

# Rechercher tous les processus contenant "llama" ou "Sambo"
LLAMA_PIDS=$(pgrep -f "llama" 2>/dev/null || true)
SAMBO_PIDS=$(pgrep -f "Sambo" 2>/dev/null || true)

if [ -n "$LLAMA_PIDS" ]; then
    echo "📋 Processus llama.cpp trouvés: $LLAMA_PIDS"
    for PID in $LLAMA_PIDS; do
        # Vérifier si le processus existe encore
        if kill -0 "$PID" 2>/dev/null; then
            echo "🛑 Arrêt du processus llama.cpp PID: $PID"
            kill -TERM "$PID" 2>/dev/null || true
            sleep 1

            # Si le processus refuse de s'arrêter, forcer
            if kill -0 "$PID" 2>/dev/null; then
                echo "💥 Forçage de l'arrêt du processus PID: $PID"
                kill -KILL "$PID" 2>/dev/null || true
            fi
        fi
    done
else
    echo "✅ Aucun processus llama.cpp trouvé"
fi

# Nettoyer les fichiers temporaires liés à llama.cpp
TEMP_FILES=$(find /tmp -name "*llama*" -type f 2>/dev/null || true)
if [ -n "$TEMP_FILES" ]; then
    echo "🧹 Nettoyage des fichiers temporaires llama.cpp..."
    echo "$TEMP_FILES" | xargs rm -f 2>/dev/null || true
fi

echo "✅ Nettoyage terminé"
