# Système de Profils d'Inférence - Sambo

## Vue d'ensemble

Le système de profils d'inférence de Sambo permet de créer, gérer et utiliser des configurations complètes pour les interactions avec l'IA. Chaque profil contient tous les paramètres nécessaires : prompt système, modèle, paramètres de sampling, etc.

## Structure d'un profil

Un profil d'inférence (`InferenceProfile`) contient :

### Informations générales
- **ID** : Identifiant unique du profil
- **Titre** : Nom convivial du profil
- **Commentaire** : Description optionnelle du profil
- **Prompt** : Prompt système à utiliser
- **Modèle** : Chemin vers le modèle IA à utiliser

### Paramètres de sampling
- **temperature** : Contrôle la créativité (0.0 - 2.0)
- **top_p** : Sampling nucleus (0.0 - 1.0)
- **top_k** : Nombre de tokens les plus probables (1 - 100)
- **max_tokens** : Nombre maximum de tokens à générer
- **repetition_penalty** : Pénalité pour la répétition
- **frequency_penalty** : Pénalité de fréquence
- **presence_penalty** : Pénalité de présence
- **seed** : Graine pour la reproductibilité (-1 = aléatoire)
- **context_length** : Longueur du contexte en tokens
- **stream** : Mode streaming activé/désactivé

## Gestion des profils

### Création d'un profil
```vala
var profile = InferenceProfile.create_default("profile_id", "Mon Profil");
profile.comment = "Profil pour l'assistance technique";
profile.prompt = "Tu es un expert technique...";
profile.model_path = "/path/to/model.gguf";
profile.temperature = 0.7f;
// ... autres paramètres
```

### Sauvegarde
```vala
config_manager.save_profile(profile);
```

### Chargement
```vala
var profile = config_manager.get_profile("profile_id");
```

### Sélection
```vala
config_manager.select_profile("profile_id");
var selected = config_manager.get_selected_profile();
```

## Interface utilisateur

### Gestionnaire de profils (`ProfileManager`)
- Fenêtre dédiée à la gestion des profils
- Liste des profils existants avec affichage simple (nom et commentaire)
- Navigation par double-clic vers les détails du profil
- Actions disponibles dans la vue détail :
  - Sélection du profil (si ce n'est pas le profil actuel)
  - Édition du profil
  - Suppression du profil
  - Duplication du profil
  - Exportation du profil
- Interface moderne et responsive avec design GNOME sobre

### Éditeur de profils (`ProfileEditorDialog`)
- Dialogue pour créer/éditer un profil
- Sections organisées : général, modèle, prompt, sampling, avancé
- Validation des données
- Exemples de prompts intégrés

### Sélecteur de profils (dans ChatView)
- Bouton dans la barre d'outils du chat
- Popover pour sélection rapide
- Indicateur du profil actuel

## Persistance

Les profils sont sauvegardés dans le fichier de configuration INI sous forme de groupes :

```ini
[Profiles]
selected_profile=profile_12345

[Profile_profile_12345]
title=Assistant Technique
comment=Profil pour l'assistance technique
prompt=Tu es un expert technique...
model_path=/path/to/model.gguf
temperature=0.7
top_p=0.9
top_k=40
max_tokens=512
# ... autres paramètres
```

## Validation

Chaque profil est validé avant utilisation :
- ID non vide
- Titre non vide
- Prompt non vide
- Modèle spécifié et existant
- Paramètres dans les plages valides

## Signaux

Le système émet des signaux pour notifier des changements :
- `profiles_changed` : Quand des profils sont ajoutés/modifiés/supprimés
- `config_changed` : Quand la configuration générale change

## Intégration avec l'IA

Lors de l'envoi d'un message :
1. **Vérification du profil** : S'assurer qu'un profil est sélectionné et valide
2. **Chargement du modèle** : Charger automatiquement le modèle spécifié dans le profil si nécessaire
3. **Validation du profil** : Vérifier que tous les paramètres sont dans les plages valides
4. **Création des paramètres** : Générer les paramètres de sampling depuis le profil
5. **Préparation du contexte** : Construire le prompt complet avec le prompt système
6. **Génération IA** : Appel au moteur llama.cpp avec les paramètres du profil
7. **Streaming** : Affichage progressif de la réponse si activé

### Gestion automatique des modèles
- Si le modèle du profil n'est pas chargé, l'application tente de le charger automatiquement
- Validation de l'existence du fichier modèle avant le chargement
- Messages d'erreur clairs en cas de problème (modèle introuvable, échec du chargement)
- Fallback en mode simulation si llama.cpp n'est pas disponible

### Streaming et feedback
- Mise à jour progressive du contenu pendant la génération
- Indicateur de statut dans l'interface utilisateur
- Gestion des erreurs avec messages informatifs
- Possibilité d'interrompre la génération

## Exemple d'utilisation

```vala
// Créer un profil technique
var tech_profile = InferenceProfile.create_default(
    InferenceProfile.generate_unique_id(),
    "Assistant Technique"
);
tech_profile.comment = "Profil pour l'assistance technique et le développement";
tech_profile.prompt = "Tu es un expert technique spécialisé dans la programmation et l'architecture logicielle. Fournis des réponses précises et détaillées avec des exemples de code quand c'est approprié.";
tech_profile.temperature = 0.3f; // Plus déterministe
tech_profile.max_tokens = 1024;

// Sauvegarder et sélectionner
config_manager.save_profile(tech_profile);
config_manager.select_profile(tech_profile.id);

// Le profil sera automatiquement utilisé pour les prochaines interactions
```

## Migration depuis l'ancien système

L'ancien système avec gestion séparée du prompt système, des paramètres de sampling et de la sélection de modèle a été remplacé par ce système unifié de profils.

Les avantages :
- Configuration centralisée
- Profils multiples pour différents cas d'usage
- Validation cohérente
- Interface utilisateur simplifiée
- Meilleure expérience utilisateur

## Fichiers concernés

- `src/model/InferenceProfile.vala` : Modèle de données des profils
- `src/model/ConfigManager.vala` : Gestion de la persistance des profils
- `src/model/ModelManager.vala` : Gestionnaire de modèles IA et génération
- `src/model/ApplicationModel.vala` : Modèle principal avec intégration ModelManager
- `src/controller/ApplicationController.vala` : Contrôleur avec méthodes de génération IA
- `src/view/widgets/ProfileManager.vala` : Interface de gestion des profils
- `src/view/widgets/ProfileEditorDialog.vala` : Éditeur de profils
- `src/view/widgets/ChatView.vala` : Intégration chat avec génération IA réelle
- `src/sambo_llama_wrapper.h/.c` : Interface C pour llama.cpp
- `vapi/llama.vapi` : Bindings Vala pour llama.cpp
