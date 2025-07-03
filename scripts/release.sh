#!/bin/bash
# Script de release automatique pour Sambo

set -e

# Vérifier que nous sommes sur la branche main
current_branch=$(git rev-parse --abbrev-ref HEAD)
if [ "$current_branch" != "main" ]; then
    echo "❌ Erreur: Vous devez être sur la branche 'main' pour créer une release"
    exit 1
fi

# Vérifier que le working directory est propre
if [ -n "$(git status --porcelain)" ]; then
    echo "❌ Erreur: Le working directory n'est pas propre"
    git status
    exit 1
fi

# Demander le type de version
echo "🏷️  Quel type de release voulez-vous créer ?"
echo "1. Patch (0.0.X) - Corrections de bugs"
echo "2. Minor (0.X.0) - Nouvelles fonctionnalités"
echo "3. Major (X.0.0) - Changements majeurs"
read -p "Choisissez (1-3): " choice

case $choice in
    1) bump_type="patch" ;;
    2) bump_type="minor" ;;
    3) bump_type="major" ;;
    *) echo "❌ Choix invalide"; exit 1 ;;
esac

# Récupérer la version actuelle depuis meson.build
current_version=$(grep "version:" meson.build | cut -d "'" -f 2)
echo "Version actuelle: $current_version"

# Calculer la nouvelle version (version simplifiée)
IFS='.' read -r major minor patch <<< "$current_version"
case $bump_type in
    "patch") new_version="$major.$minor.$((patch + 1))" ;;
    "minor") new_version="$major.$((minor + 1)).0" ;;
    "major") new_version="$((major + 1)).0.0" ;;
esac

echo "Nouvelle version: $new_version"
read -p "Confirmer la création de la version $new_version ? (y/N): " confirm

if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
    echo "❌ Release annulée"
    exit 1
fi

# Mettre à jour la version dans meson.build
sed -i "s/version: '$current_version'/version: '$new_version'/" meson.build

# Créer un commit de version
git add meson.build
git commit -m "bump: version $new_version"

# Créer le tag
git tag -a "v$new_version" -m "Release version $new_version"

# Pousser les changements
git push origin main
git push origin "v$new_version"

echo "✅ Release $new_version créée avec succès !"
echo "🔗 Créez maintenant une release sur GitHub: https://github.com/emmanueltoulouse/Sambo/releases/new"
