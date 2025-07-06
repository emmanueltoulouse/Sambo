# Nouvelles fonctionnalités - Gestion du prompt système

## 🎯 Fonctionnalités implémentées

### 1. Sauvegarde dans la configuration INI
- **Localisation** : `~/.config/sambo/config.ini`
- **Section** : `[AI]`
- **Clé** : `system_prompt`
- **Valeur par défaut** : `"Tu es un assistant IA utile et bienveillant. Réponds de manière claire et concise."`

### 2. Chargement au démarrage
- Le prompt système est automatiquement chargé depuis la configuration au démarrage de l'application
- Visible dans les logs : `Prompt système chargé : [contenu du prompt]`

### 3. Édition dans l'interface
- **Accès** : Chat IA → Paramètres → Voir le prompt → Éditer le prompt système
- **Interface** : Fenêtre dédiée avec éditeur de texte
- **Fonctionnalités** :
  - Zone de texte éditable avec défilement
  - Exemples de prompts prédéfinis (3 boutons)
  - Bouton "Réinitialiser" pour revenir au prompt par défaut
  - Bouton "Sauvegarder" pour enregistrer les modifications
  - Notification de confirmation lors de la sauvegarde

### 4. Affichage dans la fenêtre du prompt
- **Accès** : Chat IA → Paramètres → Voir le prompt
- **Fonctionnalités** :
  - Affichage du prompt complet structuré
  - Bouton "Copier" pour copier dans le presse-papiers
  - **NOUVEAU** : Bouton "Éditer le prompt système" pour accéder à l'éditeur
  - Statistiques (nombre de caractères et estimation des tokens)

## 🔧 Modifications techniques

### ConfigManager (`src/model/ConfigManager.vala`)
```vala
// Nouvelles méthodes
public string get_system_prompt()
public void set_system_prompt(string prompt)
```

### ChatView (`src/view/widgets/ChatView.vala`)
```vala
// Nouvelles méthodes
private void load_system_prompt()
private void save_system_prompt()
private void show_system_prompt_editor_dialog()

// Modifications
- Chargement automatique au démarrage
- Prompt système initialisé vide puis chargé depuis la config
- Bouton d'édition ajouté dans la fenêtre d'affichage du prompt
```

### Interface utilisateur
- **Éditeur de prompt** : Fenêtre modale avec éditeur de texte complet
- **Exemples prédéfinis** : 3 boutons pour des prompts types
- **Validation** : Sauvegarde avec notification
- **Navigation** : Accès depuis la fenêtre d'affichage du prompt

## 📝 Exemples de prompts intégrés

1. **Assistant général** (par défaut)
   ```
   Tu es un assistant IA utile et bienveillant. Réponds de manière claire et concise.
   ```

2. **Assistant technique**
   ```
   Tu es un assistant IA spécialisé en programmation et technologies. Fournis des réponses détaillées et techniques avec des exemples de code quand c'est approprié.
   ```

3. **Assistant créatif**
   ```
   Tu es un assistant IA créatif et inspirant. Aide à générer des idées originales et propose des solutions innovantes. Utilise un langage vivant et engageant.
   ```

## 🚀 Utilisation

1. **Pour modifier le prompt système** :
   - Aller dans Chat IA
   - Cliquer sur "Paramètres"
   - Cliquer sur "Voir le prompt"
   - Cliquer sur "Éditer le prompt système"
   - Modifier le texte ou utiliser un exemple
   - Cliquer sur "Sauvegarder"

2. **Persistance** :
   - Le prompt est automatiquement sauvegardé dans la configuration
   - Il sera rechargé au prochain démarrage de l'application
   - Visible dans les logs de démarrage

3. **Réinitialisation** :
   - Bouton "Réinitialiser" dans l'éditeur
   - Ou supprimer la clé `system_prompt` du fichier `config.ini`

## ✅ Tests réalisés

- ✅ Compilation sans erreur
- ✅ Démarrage de l'application
- ✅ Chargement du prompt par défaut au démarrage
- ✅ Sauvegarde automatique de la configuration
- ✅ Interface utilisateur fonctionnelle

## 🔄 Prochaines étapes possibles

- Historique des prompts utilisés
- Import/export de prompts
- Prompts par conversation
- Validation de la syntaxe des prompts
- Prévisualisation en temps réel
