#!/bin/bash

# Script pour simuler le chargement de fichier et capturer les logs
echo "=== DÉBUT TEST CHARGEMENT DE FICHIER ===" >> debug_output.log

# Attendre un moment pour que l'utilisateur puisse charger un fichier
echo "Chargez maintenant un fichier Markdown depuis l'explorateur de l'application..."
echo "Appuyez sur Entrée quand vous avez terminé le chargement."
read

echo "=== FIN TEST CHARGEMENT DE FICHIER ===" >> debug_output.log

# Afficher les messages de debug capturés pendant le chargement
echo "Messages de debug capturés :"
grep "🔍" debug_output.log | tail -20
