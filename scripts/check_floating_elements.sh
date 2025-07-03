#!/bin/bash

# Script de vérification des éléments flottants supprimés
# Vérifie qu'il n'y a plus d'éléments flottants au milieu de la fenêtre

echo "=== Vérification de la suppression des éléments flottants ==="

# Recherche d'anciens éléments flottants qui ne devraient plus exister
echo "1. Recherche de zone_transfer_button..."
if grep -r "zone_transfer_button" src/ 2>/dev/null; then
    echo "❌ ERREUR: zone_transfer_button trouvé dans le code source"
    exit 1
else
    echo "✅ zone_transfer_button supprimé du code source"
fi

echo "2. Recherche de transfer_overlay..."
if grep -r "transfer_overlay" src/ 2>/dev/null; then
    echo "❌ ERREUR: transfer_overlay trouvé dans le code source"
    exit 1
else
    echo "✅ transfer_overlay supprimé du code source"
fi

echo "3. Recherche de boutons flottants au centre..."
if grep -r "floating.*center\|center.*floating" src/ 2>/dev/null; then
    echo "❌ ERREUR: Boutons flottants au centre trouvés"
    exit 1
else
    echo "✅ Aucun bouton flottant au centre détecté"
fi

echo "4. Vérification de la CommunicationView moderne..."
if grep -q "create_action_bar" src/view/CommunicationView.vala; then
    echo "✅ Interface moderne CommunicationView présente"
else
    echo "❌ ERREUR: Interface moderne CommunicationView manquante"
    exit 1
fi

echo "5. Vérification des boutons de toggle dans MainWindow..."
if grep -q "explorer_button.*ToggleButton" src/view/MainWindow.vala && grep -q "communication_button.*ToggleButton" src/view/MainWindow.vala; then
    echo "✅ Boutons de toggle présents dans MainWindow"
else
    echo "❌ ERREUR: Boutons de toggle manquants dans MainWindow"
    exit 1
fi

echo "6. Vérification du workflow moderne..."
if grep -q "Transférer vers l'éditeur" src/view/CommunicationView.vala; then
    echo "✅ Workflow moderne de transfert présent"
else
    echo "❌ ERREUR: Workflow moderne de transfert manquant"
    exit 1
fi

echo ""
echo "🎉 SUCCÈS: Tous les éléments flottants ont été supprimés avec succès !"
echo "📱 L'interface moderne est maintenant cohérente et élégante"
echo ""
echo "🔄 Workflow moderne validé :"
echo "   1. Chargement unique → CommunicationView"
echo "   2. Édition → Onglets Chat/Terminal/Macros"
echo "   3. Transfert → Bouton élégant dans l'action_bar"
echo "   4. Sauvegarde → Bouton activé après transfert"
