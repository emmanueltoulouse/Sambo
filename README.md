# Sambo

![Icône Sambo](Sambo.png)

## Description

Sambo est un éditeur de texte avancé moderne développé avec GTK4 et Vala. Il offre une interface utilisateur moderne et intuitive pour l'édition de texte avec des fonctionnalités avancées.

## Fonctionnalités

- ✨ Interface moderne avec GTK4
- 📝 Éditeur de texte avancé avec coloration syntaxique
- 🔍 Explorateur de fichiers intégré
- 💬 Interface de communication intégrée
- ⚙️ Fenêtre de préférences personnalisable
- 🎨 Thèmes et styles personnalisables
- 🌐 Support de l'internationalisation

## Installation

### Prérequis

- Vala (`valac`)
- Meson
- GTK4
- GLib

### Compilation

1. Clonez le repository :
```bash
git clone <url-du-repository>
cd Sambo
```

2. Configurez le projet :
```bash
meson setup build
```

3. Compilez l'application :
```bash
meson compile -C build
```

4. Lancez l'application :
```bash
./build/Sambo
```

## Utilisation

### Interface principale

L'application propose une interface moderne avec :
- Une barre d'en-tête avec les actions principales
- Un éditeur de texte central
- Une barre latérale avec l'explorateur de fichiers
- Une vue de communication pour les interactions

### Workflow recommandé

1. **Ouverture de fichiers** : Utilisez l'explorateur de fichiers ou les raccourcis clavier
2. **Édition** : L'éditeur principal supporte la coloration syntaxique
3. **Communication** : Utilisez la vue de communication pour les interactions avec l'IA
4. **Préférences** : Personnalisez l'application via le menu des préférences

## Architecture

Le projet suit une architecture MVC (Model-View-Controller) :

```
src/
├── Application.vala          # Point d'entrée de l'application
├── controller/              # Contrôleurs
├── model/                   # Modèles de données
├── view/                    # Vues et interfaces utilisateur
└── ...
```

## Développement

### Structure du projet

- `src/` - Code source Vala
- `data/` - Ressources (icônes, CSS, etc.)
- `po/` - Fichiers de traduction
- `docs/` - Documentation
- `scripts/` - Scripts utilitaires

### Tâches disponibles

Le projet inclut plusieurs tâches VS Code configurées :

- **build** : Compile le projet
- **run** : Lance l'application
- **Compil et Execute** : Compile et lance en une fois
- **clean** : Nettoie le dossier de build
- **lint** : Vérifie le style du code

## Licence

© 2023 Cabinet ETO - Licence GPL 3.0

## Contact

- Site Web : [https://cabineteto.com](https://cabineteto.com)
- Développé par Cabinet ETO

---

![Icône Sambo](Sambo.png)

*Sambo - Éditeur de texte avancé pour une productivité moderne*
