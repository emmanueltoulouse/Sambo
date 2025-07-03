# Guide de Contribution à Sambo

Merci de votre intérêt pour contribuer à Sambo ! Ce guide vous aidera à contribuer efficacement au projet.

## Comment Contribuer

### 1. Prérequis
- Git installé sur votre système
- Vala (valac) installé
- Meson build system installé
- GTK4 et ses dépendances
- Un compte GitHub

### 2. Fork et Clone
```bash
# Fork le projet sur GitHub puis clone votre fork
git clone https://github.com/VOTRE_USERNAME/Sambo.git
cd Sambo

# Ajouter le dépôt original comme remote upstream
git remote add upstream https://github.com/emmanueltoulouse/Sambo.git
```

### 3. Créer une Branche
```bash
# Créer une nouvelle branche pour votre feature/fix
git checkout -b feature/ma-nouvelle-feature
# ou
git checkout -b fix/correction-bug
```

### 4. Développement

#### Structure du Projet
- `src/` - Code source principal (Vala)
- `src/model/` - Classes de modèle de données
- `src/view/` - Composants d'interface utilisateur
- `src/controller/` - Logique de contrôle
- `data/` - Fichiers de ressources, schémas, CSS
- `docs/` - Documentation
- `scripts/` - Scripts utilitaires

#### Conventions de Code
- Utilisez l'indentation avec des espaces (4 espaces)
- Suivez les conventions Vala standard
- Écrivez des commentaires clairs en français ou anglais
- Utilisez des noms descriptifs pour les variables et fonctions

#### Tests et Validation
```bash
# Vérifier les dépendances et compiler
meson setup build
meson compile -C build

# Lancer l'application pour tester
./build/Sambo

# Vérifier le style du code
find src -name '*.vala' | xargs -n1 uncrustify -c .uncrustify.cfg --check
```

### 5. Committer vos Changements
```bash
# Ajouter vos fichiers modifiés
git add .

# Committer avec un message descriptif
git commit -m "feat: ajouter nouvelle fonctionnalité X"
# ou
git commit -m "fix: corriger le bug Y"
# ou
git commit -m "docs: mettre à jour la documentation Z"
```

#### Format des Messages de Commit
Utilisez le format conventional commits :
- `feat:` pour une nouvelle fonctionnalité
- `fix:` pour une correction de bug
- `docs:` pour la documentation
- `style:` pour le formatage du code
- `refactor:` pour le refactoring
- `test:` pour les tests
- `chore:` pour les tâches de maintenance

### 6. Pousser et Créer une Pull Request
```bash
# Pousser votre branche
git push origin feature/ma-nouvelle-feature

# Puis créer une Pull Request sur GitHub
```

### 7. Synchroniser avec le Dépôt Principal
```bash
# Récupérer les dernières modifications
git fetch upstream
git checkout main
git merge upstream/main

# Mettre à jour votre fork
git push origin main
```

## Règles de Contribution

### Issues
- Vérifiez d'abord si une issue similaire n'existe pas déjà
- Utilisez un titre descriptif et clair
- Fournissez le maximum de détails (version, OS, étapes de reproduction)
- Ajoutez des labels appropriés

### Pull Requests
- Une PR = une fonctionnalité ou un fix
- Décrivez clairement ce que fait votre PR
- Référencez les issues liées (ex: "Fixes #123")
- Assurez-vous que le code compile sans erreur
- Testez votre code avant de soumettre

### Code Review
- Soyez respectueux et constructif
- Expliquez vos suggestions
- Soyez ouvert aux commentaires et suggestions

## Aide et Support

Si vous avez des questions :
- Ouvrez une issue avec le label "question"
- Consultez la documentation dans `docs/`
- Regardez les exemples dans le code existant

## Licence

En contribuant, vous acceptez que vos contributions soient sous la même licence que le projet.

Merci de contribuer à Sambo ! 🚀
