#!/bin/bash

# Script pour lancer Sambo avec une sortie minimale (uniquement erreurs critiques)
# Utilisé pour les démonstrations et tests rapides

# Définir les variables d'environnement pour réduire les warnings
export G_MESSAGES_DEBUG=""
export GTK_DEBUG=""

# Supprimer presque tous les messages sauf les erreurs critiques
if [ -f ./build/Sambo ]; then
    GSETTINGS_SCHEMA_DIR=/usr/local/share/glib-2.0/schemas ./build/Sambo 2>&1 | \
    grep -v "Gtk-WARNING" | \
    grep -v "Gtk-CRITICAL" | \
    grep -v "Theme parser error" | \
    grep -v "load: control token" | \
    grep -v "llama_model_loader:" | \
    grep -v "print_info:" | \
    grep -v "load:" | \
    grep -v "init_tokenizer:" | \
    grep -v "load_tensors:" | \
    grep -v "llama_context:" | \
    grep -v "llama_kv_cache_unified:" | \
    grep -v "ggml_gallocr_reserve_n:" | \
    grep -v "graph_reserve:" | \
    grep -v "register_backend:" | \
    grep -v "register_device:" | \
    grep -v "\[TRACE\]" | \
    sed 's/^[[:space:]]*//g' | \
    grep -v "^$" | \
    cat
else
    echo "❌ L'application n'est pas compilée. Exécutez d'abord 'build'."
    exit 1
fi
