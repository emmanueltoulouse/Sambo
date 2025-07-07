#!/bin/bash

# Script pour lancer Sambo en supprimant les warnings GTK non critiques
# Utilisé pour avoir une sortie propre lors des tests

# Définir les variables d'environnement pour réduire les warnings
export G_MESSAGES_DEBUG=""
export GTK_DEBUG=""

# Supprimer les warnings GTK spécifiques via un filtre
if [ -f ./build/Sambo ]; then
    GSETTINGS_SCHEMA_DIR=/usr/local/share/glib-2.0/schemas ./build/Sambo 2>&1 | \
    grep -v "Gtk-WARNING.*Trying to measure GtkBox.*for height.*but it needs at least" | \
    grep -v "Gtk-CRITICAL.*gtk_label_set_text.*assertion.*failed" | \
    grep -v "Theme parser error.*No property named" | \
    grep -v "Theme parser error.*Percentages are not allowed here" | \
    grep -v "load: control token.*is not marked as EOG" | \
    sed 's/^[[:space:]]*//g' | \
    cat
else
    echo "L'application n'est pas compilée. Exécutez d'abord 'build'."
    exit 1
fi
