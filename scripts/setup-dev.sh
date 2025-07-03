#!/bin/bash
# Script d'installation et configuration de l'environnement de développement Sambo

set -e

echo "🚀 Configuration de l'environnement de développement Sambo"

# Vérifier les dépendances
echo "📋 Vérification des dépendances..."
missing_deps=()

command -v valac >/dev/null 2>&1 || missing_deps+=("valac")
command -v meson >/dev/null 2>&1 || missing_deps+=("meson")
command -v ninja >/dev/null 2>&1 || missing_deps+=("ninja-build")

if [ ${#missing_deps[@]} -ne 0 ]; then
    echo "❌ Dépendances manquantes: ${missing_deps[*]}"
    echo "Installez-les avec:"
    echo "sudo apt-get install ${missing_deps[*]}"
    exit 1
fi

# Configuration Git
echo "🔧 Configuration Git..."
git config core.hooksPath .githooks 2>/dev/null || true
chmod +x .githooks/pre-commit 2>/dev/null || true

# Initialiser les sous-modules
echo "📦 Initialisation des sous-modules..."
git submodule update --init --recursive 2>/dev/null || true

# Configuration du build
echo "🏗️  Configuration du build..."
if [ ! -d "build" ]; then
    meson setup build
    echo "✅ Build configuré dans le dossier 'build'"
else
    echo "✅ Dossier build existant"
fi

# Premier build
echo "🔨 Premier build..."
meson compile -C build

# Configuration des schémas GSettings
echo "⚙️  Configuration des schémas GSettings..."
mkdir -p ~/.local/share/glib-2.0/schemas
cp data/*.gschema.xml ~/.local/share/glib-2.0/schemas/ 2>/dev/null || true
glib-compile-schemas ~/.local/share/glib-2.0/schemas/ 2>/dev/null || true

echo ""
echo "✅ Configuration terminée avec succès !"
echo ""
echo "🎯 Commandes utiles :"
echo "  • Compiler: meson compile -C build"
echo "  • Lancer: ./build/Sambo"
echo "  • Nettoyer: rm -rf build"
echo "  • Tests: meson test -C build"
echo ""
echo "📖 Consultez CONTRIBUTING.md pour plus d'informations sur le développement"
