# 🤖 Sambo - AI-Powered Text Editor

<div align="center">

![Sambo Logo](Sambo.png)

[![License: GPL-3.0](https://img.shields.io/badge/License-GPL--3.0-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![Built with GTK4](https://img.shields.io/badge/Built%20with-GTK4-green.svg)](https://gtk.org/)
[![Written in Vala](https://img.shields.io/badge/Written%20in-Vala-purple.svg)](https://vala.dev/)

*Un éditeur de texte moderne avec intelligence artificielle intégrée*

[🚀 Installation](#installation) • [📖 Documentation](#utilisation) • [🤝 Contribuer](#développement) • [📝 Licence](#licence)

</div>

## ✨ Fonctionnalités

🎯 **Interface Moderne**
- Interface utilisateur élégante avec GTK4/libadwaita
- Design adaptatif et thèmes personnalisables
- Navigation intuitive avec sidebar et onglets

🤖 **Intelligence Artificielle**
- Integration avec llama.cpp pour l'inférence locale
- Support des modèles GGUF, BIN et SafeTensors
- Profils d'inférence personnalisables
- Chat interactif avec l'IA
- Génération de texte en streaming

📝 **Édition Avancée**
- Éditeur de texte avec coloration syntaxique
- Support multi-formats (Markdown, code, etc.)
- Explorateur de fichiers intégré
- Gestion des projets

� **Extensibilité**
- Architecture modulaire MVC
- Configuration flexible via INI
- Support des extensions futures
- API de téléchargement de modèles Hugging Face

## 🖼️ Captures d'écran

<!-- TODO: Ajouter des captures d'écran -->
*Screenshots à venir*

## 🚀 Installation

### Prérequis

Assurez-vous d'avoir les dépendances suivantes installées :

```bash
# Ubuntu/Debian
sudo apt update
sudo apt install valac meson ninja-build libgtk-4-dev libadwaita-1-dev libgee-0.8-dev

# Fedora
sudo dnf install vala meson ninja-build gtk4-devel libadwaita-devel libgee-devel

# Arch Linux
sudo pacman -S vala meson ninja gtk4 libadwaita libgee
```

### 📦 Installation depuis les sources

1. **Clonez le repository :**
```bash
git clone https://github.com/votre-username/Sambo.git
cd Sambo
```

2. **Configurez et compilez :**
```bash
meson setup build
meson compile -C build
```

3. **Lancez l'application :**
```bash
./build/Sambo
```

### 🔧 Installation pour le développement

```bash
# Installation des dépendances de développement
sudo apt install uncrustify  # pour le formatage de code

# Tâches disponibles (VS Code)
# - build: Compile le projet
# - run: Lance l'application
# - Compil et Execute: Compile et lance
# - clean: Nettoie le build
# - lint: Vérifie le style du code
```

## 📖 Utilisation

### 🎯 Démarrage rapide

1. **Configuration initiale :**
   - Lancez Sambo
   - Allez dans Préférences → IA
   - Configurez le répertoire des modèles
   - Téléchargez un modèle compatible (GGUF recommandé)

2. **Utilisation de l'IA :**
   - Créez un profil d'inférence personnalisé
   - Chargez un modèle depuis le sélecteur
   - Commencez à chatter avec l'IA
   - Ajustez les paramètres selon vos besoins

### 🔧 Configuration avancée

#### Profils d'inférence
Les profils permettent de sauvegarder des configurations spécifiques :
- **Température** : Contrôle la créativité (0.1 = conservateur, 1.0 = créatif)
- **Top-P** : Filtrage des tokens par probabilité cumulative
- **Top-K** : Nombre de tokens candidats considérés
- **Max Tokens** : Longueur maximale de la réponse

#### Modèles supportés
- **GGUF** : Format recommandé pour llama.cpp
- **BIN** : Modèles binaires legacy
- **SafeTensors** : Format sécurisé

### 🗂️ Interface

**Zone principale :**
- Éditeur de texte avec coloration syntaxique
- Chat IA avec streaming en temps réel
- Explorateur de fichiers intégré

**Barres d'outils :**
- Actions rapides (nouveau, ouvrir, sauvegarder)
- Contrôles IA (modèle, profil, génération)
- Paramètres et préférences

## 🏗️ Architecture

Sambo suit une architecture MVC (Model-View-Controller) moderne :

```
src/
├── Application.vala              # Point d'entrée principal
├── controller/                   # Logique de contrôle
│   ├── ApplicationController.vala
│   └── ...
├── model/                       # Modèles de données
│   ├── ModelManager.vala        # Gestion des modèles IA
│   ├── ConfigManager.vala       # Configuration
│   ├── InferenceProfile.vala    # Profils d'inférence
│   └── ...
├── view/                        # Interface utilisateur
│   ├── widgets/                 # Composants UI
│   ├── windows/                 # Fenêtres
│   └── ...
└── vapi/                        # Bindings C
    └── llama.vapi              # Interface llama.cpp
```

### 🔌 Composants clés

- **ModelManager** : Gestion des modèles IA et inférence
- **ConfigManager** : Persistence des paramètres et profils
- **ChatView** : Interface de conversation avec l'IA
- **ProfileManager** : Gestion des profils d'inférence

## 🛠️ Développement

### Structure du projet

```
Sambo/
├── src/                    # Code source Vala
├── data/                   # Ressources (CSS, icônes, schémas)
├── po/                     # Fichiers de traduction
├── docs/                   # Documentation technique
├── scripts/                # Scripts utilitaires
├── vapi/                   # Bindings pour bibliothèques C
└── subprojects/            # Dépendances externes
```

### 🧪 Tests et qualité

```bash
# Vérification du style de code
meson compile -C build && find src -name '*.vala' | xargs uncrustify -c .uncrustify.cfg --check

# Nettoyage du projet
rm -rf build && meson setup build

# Compilation en mode debug
meson setup build --buildtype=debug
```

### 🤝 Contribuer

1. **Fork** le projet
2. **Créez** une branche pour votre fonctionnalité (`git checkout -b feature/amazing-feature`)
3. **Committez** vos changements (`git commit -m 'Add amazing feature'`)
4. **Pushez** vers la branche (`git push origin feature/amazing-feature`)
5. **Ouvrez** une Pull Request

#### 📝 Guidelines de contribution

- Suivez le style de code existant (Uncrustify)
- Documentez les nouvelles fonctionnalités
- Testez vos modifications
- Mettez à jour la documentation si nécessaire

## 🔗 Liens utiles

- 📚 [Documentation complète](docs/)
- 🐛 [Signaler un bug](https://github.com/votre-username/Sambo/issues)
- 💡 [Demander une fonctionnalité](https://github.com/votre-username/Sambo/issues)
- 🗨️ [Discussions](https://github.com/votre-username/Sambo/discussions)

## 📝 Licence

Ce projet est sous licence GPL-3.0. Voir le fichier [LICENSE](LICENSE) pour plus de détails.

## 👥 Équipe

**Développé par Cabinet ETO**
- 🌐 Site Web : [https://cabineteto.com](https://cabineteto.com)
- 📧 Contact : [contact@cabineteto.com](mailto:contact@cabineteto.com)

## 🙏 Remerciements

- [GTK Project](https://gtk.org/) pour le toolkit d'interface
- [llama.cpp](https://github.com/ggerganov/llama.cpp) pour l'inférence IA
- [Vala](https://vala.dev/) pour le langage de programmation
- La communauté open source pour les contributions

---

<div align="center">

**⭐ Si ce projet vous plaît, n'hésitez pas à lui donner une étoile !**

*Fait avec ❤️ par [Cabinet ETO](https://cabineteto.com)*

</div>
