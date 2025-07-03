#!/bin/bash

# Définition des couleurs pour améliorer la lisibilité
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
RESET='\033[0m'

# Demander le chemin du meson.build et du répertoire src
echo -e "${BLUE}Configuration de la vérification${RESET}"
read -e -p "Chemin du fichier meson.build (par défaut: ./meson.build): " MESON_PATH
MESON_PATH=${MESON_PATH:-"./meson.build"}

read -e -p "Chemin du répertoire src à vérifier (par défaut: ./src): " SRC_PATH
SRC_PATH=${SRC_PATH:-"./src"}

# Vérifier que les chemins existent
if [ ! -f "$MESON_PATH" ]; then
    echo -e "${RED}Erreur: Le fichier meson.build n'existe pas à l'emplacement spécifié: $MESON_PATH${RESET}"
    exit 1
fi

if [ ! -d "$SRC_PATH" ]; then
    echo -e "${RED}Erreur: Le répertoire src n'existe pas à l'emplacement spécifié: $SRC_PATH${RESET}"
    exit 1
fi

echo -e "\n${BOLD}Vérification des fichiers entre meson.build et le projet${RESET}"
echo -e "${BLUE}Utilisation de: ${RESET}"
echo -e "  - Fichier meson.build: ${YELLOW}$MESON_PATH${RESET}"
echo -e "  - Répertoire source: ${YELLOW}$SRC_PATH${RESET}\n"

# Création de fichiers temporaires pour l'analyse
TEMP_DIR=$(mktemp -d)
ACTUAL_FILES="$TEMP_DIR/actual_vala_files.txt"
DECLARED_FILES="$TEMP_DIR/declared_vala_files.txt"
MISSING_IN_MESON="$TEMP_DIR/missing_in_meson.txt"
MISSING_IN_REALITY="$TEMP_DIR/missing_in_reality.txt"

# Obtenir le répertoire du projet à partir du chemin meson.build
PROJECT_DIR=$(dirname "$MESON_PATH")

# Étape 1: Trouver tous les fichiers .vala dans le projet
echo -e "${BLUE}Étape 1: ${RESET}Recherche des fichiers .vala dans le projet..."
find "$SRC_PATH" -name "*.vala" | sort > "$ACTUAL_FILES"
ACTUAL_COUNT=$(wc -l < "$ACTUAL_FILES")
echo -e "  → $ACTUAL_COUNT fichiers .vala trouvés\n"

# Étape 2: Extraire les fichiers .vala déclarés dans meson.build
echo -e "${BLUE}Étape 2: ${RESET}Extraction des fichiers déclarés dans meson.build..."
grep -o "'src/.*\.vala'" "$MESON_PATH" | tr -d "'" | sort > "$DECLARED_FILES"
DECLARED_COUNT=$(wc -l < "$DECLARED_FILES")
echo -e "  → $DECLARED_COUNT fichiers .vala déclarés\n"

# Étape 3: Comparer les deux listes
echo -e "${BLUE}Étape 3: ${RESET}Comparaison des fichiers..."

# Préparer les fichiers pour la comparaison
sed "s|^$PROJECT_DIR/||" "$ACTUAL_FILES" > "$TEMP_DIR/actual_relative.txt"

# Fichiers présents mais non déclarés dans meson.build
comm -23 "$TEMP_DIR/actual_relative.txt" "$DECLARED_FILES" > "$MISSING_IN_MESON"
MISSING_IN_MESON_COUNT=$(wc -l < "$MISSING_IN_MESON")

# Fichiers déclarés dans meson.build mais inexistants
comm -13 "$TEMP_DIR/actual_relative.txt" "$DECLARED_FILES" > "$MISSING_IN_REALITY"
MISSING_IN_REALITY_COUNT=$(wc -l < "$MISSING_IN_REALITY")

# Affichage des résultats pour les fichiers Vala
echo -e "${YELLOW}╔═════════════════════════════════════════════════════════╗${RESET}"
echo -e "${YELLOW}║ FICHIERS VALA PRÉSENTS MAIS NON DÉCLARÉS DANS MESON.BUILD ║${RESET}"
echo -e "${YELLOW}╚═════════════════════════════════════════════════════════╝${RESET}"

if [ "$MISSING_IN_MESON_COUNT" -eq 0 ]; then
  echo -e "${GREEN}✓ Tous les fichiers .vala sont déclarés dans meson.build${RESET}"
else
  echo -e "${RED}$MISSING_IN_MESON_COUNT fichier(s) .vala non déclaré(s) dans meson.build:${RESET}"
  while read -r file; do
    echo -e "  - ${RED}$file${RESET}"
  done < "$MISSING_IN_MESON"
fi
echo

echo -e "${YELLOW}╔═════════════════════════════════════════════════════════╗${RESET}"
echo -e "${YELLOW}║ FICHIERS DÉCLARÉS DANS MESON.BUILD MAIS INEXISTANTS      ║${RESET}"
echo -e "${YELLOW}╚═════════════════════════════════════════════════════════╝${RESET}"

if [ "$MISSING_IN_REALITY_COUNT" -eq 0 ]; then
  echo -e "${GREEN}✓ Tous les fichiers déclarés dans meson.build existent${RESET}"
else
  echo -e "${RED}$MISSING_IN_REALITY_COUNT fichier(s) déclaré(s) mais inexistant(s):${RESET}"
  while read -r file; do
    echo -e "  - ${RED}$file${RESET}"
  done < "$MISSING_IN_REALITY"
fi
echo

# Étape 4: Vérifier les fichiers de ressources
echo -e "${YELLOW}╔═════════════════════════════════════════════════════════╗${RESET}"
echo -e "${YELLOW}║ VÉRIFICATION DES FICHIERS DE RESSOURCES                  ║${RESET}"
echo -e "${YELLOW}╚═════════════════════════════════════════════════════════╝${RESET}"

# Fonction pour vérifier l'existence d'un fichier
check_file() {
  if [ -f "$PROJECT_DIR/$1" ]; then
    echo -e "  ${GREEN}✓ $1 existe${RESET}"
    return 0
  else
    echo -e "  ${RED}✗ $1 MANQUANT${RESET}"
    return 1
  fi
}

RESOURCES_MISSING=0

# Vérification des fichiers de ressources
check_file "data/sambo.gresource.xml" || ((RESOURCES_MISSING++))
check_file "data/icons/hicolor/scalable/apps/com.cabineteto.Sambo.png" || ((RESOURCES_MISSING++))
check_file "data/com.cabineteto.Sambo.desktop.in" || ((RESOURCES_MISSING++))

# Résumé final
echo -e "\n${BLUE}════════════════════════════════════════════════════════════${RESET}"
echo -e "${BOLD}RÉSUMÉ DE LA VÉRIFICATION${RESET}"
echo -e "${BLUE}════════════════════════════════════════════════════════════${RESET}"

echo -e "• ${BOLD}Fichiers .vala dans le projet:${RESET} $ACTUAL_COUNT"
echo -e "• ${BOLD}Fichiers .vala dans meson.build:${RESET} $DECLARED_COUNT"

if [ "$MISSING_IN_MESON_COUNT" -eq 0 ] && [ "$MISSING_IN_REALITY_COUNT" -eq 0 ] && [ "$RESOURCES_MISSING" -eq 0 ]; then
  echo -e "\n${GREEN}✓ Tous les fichiers sont correctement déclarés et présents!${RESET}"
else
  echo -e "\n${RED}ACTION REQUISE:${RESET}"
  [ "$MISSING_IN_MESON_COUNT" -gt 0 ] && echo -e "  - ${RED}$MISSING_IN_MESON_COUNT fichier(s) à ajouter dans meson.build${RESET}"
  [ "$MISSING_IN_REALITY_COUNT" -gt 0 ] && echo -e "  - ${RED}$MISSING_IN_REALITY_COUNT fichier(s) à créer ou à retirer de meson.build${RESET}"
  [ "$RESOURCES_MISSING" -gt 0 ] && echo -e "  - ${RED}$RESOURCES_MISSING fichier(s) de ressources manquant(s)${RESET}"
fi

# Nettoyage
rm -rf "$TEMP_DIR"
echo -e "\n${BLUE}Vérification terminée.${RESET}"
