#!/bin/bash

# Script pour supprimer les logs de débogage du projet Sambo
# Supprime les lignes print() utilisées pour le débogage

echo "Nettoyage des logs de débogage..."

# Fonction pour traiter un fichier
clean_file() {
    local file="$1"
    local temp_file=$(mktemp)

    # Supprimer les lignes de débogage spécifiques
    grep -v 'print(".*: ' "$file" > "$temp_file"

    # Vérifier si des changements ont été effectués
    if ! cmp -s "$file" "$temp_file"; then
        cp "$temp_file" "$file"
        echo "  ✓ Nettoyé: $file"
    fi

    rm "$temp_file"
}

# Traiter tous les fichiers .vala
find src -name "*.vala" -type f | while read -r file; do
    # Éviter les fichiers qui utilisent printf légitimement
    if [[ "$file" == *"PivotDocument.vala" ]] || \
       [[ "$file" == *"DialogFileComparer.vala" ]] || \
       [[ "$file" == *"FileItemModel.vala" ]] || \
       [[ "$file" == *"WysiwygEditor.vala" ]] || \
       [[ "$file" == *"TerminalView.vala" ]] || \
       [[ "$file" == *"ComparisonView.vala" ]] || \
       [[ "$file" == *"MarkdownDocumentConverter.vala" ]] || \
       [[ "$file" == *"ExplorerModel.vala" ]]; then
        echo "  ⏭️  Ignoré: $file (utilisation légitime de printf)"
        continue
    fi

    clean_file "$file"
done

echo "Nettoyage terminé !"
