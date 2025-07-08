#!/bin/bash

# Script de vérification et correction du code Sambo
# Vérifie les problèmes courants et propose des corrections

echo "=== Vérification du code Sambo ==="
echo ""

# 1. Vérifier les TODOs et les marquer
echo "1. Vérification des TODOs et éléments à compléter..."
grep -r "TODO\|FIXME\|XXX\|HACK" src/ --include="*.vala" | head -10
echo ""

# 2. Vérifier les warnings potentiels
echo "2. Vérification des warnings potentiels..."
echo "Cherche les déclarations de variables non utilisées..."
grep -r "var [a-zA-Z_][a-zA-Z0-9_]*.*=" src/ --include="*.vala" | grep -v "=" | head -5
echo ""

# 3. Vérifier les erreurs de style
echo "3. Vérification du style de code..."
echo "Vérifie les lignes trop longues (>120 caractères)..."
find src/ -name "*.vala" -exec awk 'length > 120 {print FILENAME ":" NR ":" $0}' {} \; | head -5
echo ""

# 4. Vérifier les imports manquants
echo "4. Vérification des imports..."
echo "Cherche les classes GTK utilisées sans imports explicites..."
grep -r "new Gtk\." src/ --include="*.vala" | head -5
echo ""

# 5. Vérifier les méthodes deprecated
echo "5. Vérification des méthodes deprecated..."
grep -r "deprecated\|deprecation" src/ --include="*.vala" | head -5
echo ""

# 6. Vérifier les null checks manquants
echo "6. Vérification des null checks..."
echo "Cherche les accès potentiels à des variables non vérifiées..."
grep -r "\.get_\|\.set_" src/ --include="*.vala" | grep -v "if.*!=" | head -5
echo ""

# 7. Compilation clean
echo "7. Test de compilation..."
cd "$(dirname "$0")/.."
if meson compile -C build 2>&1 | grep -E "(warning|error)" | head -10; then
    echo "Des warnings ou erreurs ont été détectés lors de la compilation."
else
    echo "✅ Compilation réussie sans warnings ni erreurs"
fi

echo ""
echo "=== Vérification terminée ==="
