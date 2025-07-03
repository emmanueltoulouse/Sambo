# IntaText - Contexte de développement

## Vue d'ensemble de l'application
- **Objectif**: Un éditeur de texte moderne boosté à l'IA
- **Technologies**: GTK4.1, Libadwaita, Vala, compatible avec GNOME 48
- **Architecture**: Pattern MVC (Modèle-Vue-Contrôleur)
- **Expérience utilisateur**: Interface élégante, intuitive et hautement personnalisable

## Structure du projet
- `src/`: Code source Vala
  - `ui/`: Composants d'interface utilisateur
  - `models/`: Classes de données
  - `controllers/`: Logique de l'application
  - `view/`: Composants visuels principaux
  - `view/widgets/`: Widgets personnalisés
- `data/`: Ressources (schémas, UI XML, icons)
- `build/`: Dossier de compilation (généré par Meson)

## Conventions de code
- Indentation: 4 espaces
- Nommage: CamelCase pour classes, snake_case pour méthodes
- Organisation: une classe par fichier
- Commentaires: Documentation claire et complète, en français
- Qualité: Code élégant, maintenable et optimisé

## Modules principaux

### 1. Interface principale (MainWindow)
- **Layout**: Structure en trois zones
  - Explorer: Panneau de navigation de fichiers (gauche)
  - Editor: Zone d'édition principale (centre)
  - Communication: Zone de communication (bas)
- **HeaderBar**: Avec menu hamburger contenant options et sous-menus

### 2. Explorateur de fichiers
- Structure à onglets pour naviguer entre différentes vues
- Vues interchangeables (liste, icônes, détails)
- Navigation par fil d'Ariane interactif
- Filtres et recherche avancée
- Prévisualisation de fichiers

### 3. Éditeur de texte
- Édition avec enrichissements visuels
- Système de tags et formatage
- Support pour différents formats (Markdown, HTML, etc.)
- Conservation des balises originales durant tout le processus d'édition

### 4. Zone de communication (3 onglets)
- **Chat IA**: Interface conversationnelle avec un assistant IA
  - Bulles de conversation stylisées
  - Historique des messages
- **Terminal**: Terminal intégré pour commandes
  - Prompt personnalisé
  - Historique de commandes
  - Autocomplétion
- **Macros**: Création et exécution de macros
  - Éditeur de macros
  - Gestion de scripts

### 5. Fenêtre de préférences (multi-onglets)
- **Général**: Options globales de l'application
- **Éditeur**: Personnalisation de l'éditeur
- **Explorateur**: Configuration de l'explorateur
- **Communication**: Paramètres des outils de communication
- **Thèmes**: Personnalisation visuelle
- **Extensions**: Gestion des modules additionnels

### 6. Menu hamburger
- **Fichier**: Nouveau, Ouvrir, Sauvegarder, Exporter...
- **Édition**: Copier, Coller, Rechercher...
- **Affichage**: Thèmes, Zoom, Panneaux...
- **Outils**: Macros, Extensions, Terminal...
- **IA**: Commandes relatives à l'intelligence artificielle
- **Aide**: Documentation, À propos, Mise à jour...

## Conseils de développement
- Prioriser l'expérience utilisateur et l'élégance de l'interface
- Suivre les dernières recommandations de conception GTK4 et GNOME 48
- Optimiser les performances pour une utilisation fluide
- Adopter une approche modulaire et extensible
- Documenter clairement chaque fonctionnalité
- tous les parametres seront regroupé dans une fenetre de parametre accesible depuis le menu hamburger de l'aplication
- devant chaque blocs de code, il faut mettre dans un champ clicable, le nom du fichier source concerné par ce bloc


## Informations pour les prompts
Lors de la rédaction de prompts pour GitHub Copilot, inclure:
- La référence au module concerné
- Le pattern de conception utilisé
- Les widgets GTK4 spécifiques impliqués
- Les interactions avec d'autres composants
- Les contraintes d'interface utilisateur
