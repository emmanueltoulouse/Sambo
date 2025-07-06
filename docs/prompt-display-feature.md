# Fonctionnalité d'affichage du prompt

## Description

Cette fonctionnalité permet d'afficher le prompt complet qui sera envoyé au modèle d'IA dans une fenêtre dédiée. Elle est accessible via un bouton dans la fenêtre des paramètres d'inférence.

## Utilisation

1. **Accès à la fonctionnalité :**
   - Ouvrez l'onglet "Chat IA" dans l'interface principale
   - Cliquez sur le bouton "Paramètres" dans la barre d'outils du chat
   - Dans la fenêtre des paramètres qui s'ouvre, cliquez sur "Voir le prompt"

2. **Contenu affiché :**
   - Le prompt système configuré
   - L'historique complet de la conversation (messages utilisateur et réponses IA)
   - Le prompt de génération pour la prochaine réponse

3. **Fonctionnalités disponibles :**
   - **Copier** : Copie le prompt complet dans le presse-papiers
   - **Statistiques** : Affiche le nombre de caractères et une estimation du nombre de tokens
   - **Défilement** : Interface scrollable pour les longs prompts

## Structure du prompt

Le prompt affiché suit cette structure :

```
### Instructions système :
[Prompt système configuré]

### Utilisateur :
[Premier message utilisateur]

### Assistant :
[Première réponse de l'IA]

### Utilisateur :
[Deuxième message utilisateur]

### Assistant :
[Deuxième réponse de l'IA]

[...]

### Assistant :
[Prompt pour la prochaine réponse]
```

## Implémentation technique

### Fichiers concernés

- `src/view/widgets/ChatView.vala` : Interface utilisateur et logique principale
- `src/view/widgets/ChatBubbleRow.vala` : Getter pour accéder aux messages
- `src/model/ChatMessage.vala` : Modèle de données des messages

### Fonctions clés

1. **`show_current_prompt_dialog()`** : Affiche la fenêtre de dialogue avec le prompt
2. **`build_current_prompt()`** : Construit le prompt complet à partir de l'historique
3. **`get_message()`** dans `ChatBubbleRow` : Permet d'accéder au message depuis les widgets

### Flux de données

1. L'utilisateur clique sur "Voir le prompt"
2. `show_current_prompt_dialog()` est appelée
3. `build_current_prompt()` parcourt tous les messages dans `message_container`
4. Pour chaque `ChatBubbleRow`, récupère le message via `get_message()`
5. Construit le prompt final avec le formatage approprié
6. Affiche le prompt dans une fenêtre avec possibilité de copie

## Utilité

Cette fonctionnalité est particulièrement utile pour :

- **Débogage** : Vérifier exactement ce qui est envoyé au modèle
- **Optimisation** : Comprendre la structure du prompt pour l'améliorer
- **Transparence** : Voir comment le système construit le contexte de conversation
- **Analyse** : Estimer la consommation de tokens avant l'envoi

## Notes techniques

- Le prompt est construit en temps réel à chaque ouverture de la fenêtre
- L'estimation des tokens utilise le ratio approximatif de 1 token ≈ 4 caractères
- La fonctionnalité de copie utilise le presse-papiers système de GTK
- L'interface est responsive et s'adapte à différentes tailles de prompt
