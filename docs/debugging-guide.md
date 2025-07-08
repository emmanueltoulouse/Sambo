# Guide de Débogage - Sambo

## Scripts de Lancement Propre

Pour éviter l'encombrement des warnings GTK non critiques lors du développement et des tests, plusieurs scripts sont disponibles :

### Scripts Disponibles

1. **`./scripts/run-sambo-quiet.sh`** - Filtre les warnings GTK de layout
   - Supprime les warnings "Trying to measure GtkBox"
   - Supprime les erreurs d'assertion GTK non critiques
   - Garde les messages importants de l'application

2. **`./scripts/run-sambo-minimal.sh`** - Sortie ultra-minimale
   - Supprime tous les warnings GTK
   - Supprime les logs de chargement du modèle llama.cpp
   - Idéal pour les démonstrations et présentations

### Tâches VS Code

Les tâches suivantes sont disponibles dans VS Code :

- **`run-quiet`** : Lance avec filtrage des warnings GTK
- **`run-minimal`** : Lance avec sortie minimale
- **`run`** : Lance normal (avec tous les logs)

### Types de Messages Filtrés

#### Warnings GTK Supprimés
- Messages de layout : "Trying to measure GtkBox for height..."
- Erreurs d'assertion : "gtk_label_set_text: assertion failed"
- Erreurs CSS : "Theme parser error", "No property named"

#### Messages llama.cpp Supprimés (mode minimal)
- Chargement du modèle : "llama_model_loader"
- Informations du modèle : "print_info"
- Initialisation du contexte : "llama_context"
- Traces de debug système

### Utilisation Recommandée

**Développement quotidien :**
```bash
./scripts/run-sambo-quiet.sh
```

**Démonstrations :**
```bash
./scripts/run-sambo-minimal.sh
```

**Débogage avancé :**
```bash
# Utiliser le lancement normal
./build/Sambo
```

### Variables d'Environnement Utiles

Pour un contrôle plus fin des logs :

```bash
# Désactiver complètement les messages GTK de debug
export G_MESSAGES_DEBUG=""
export GTK_DEBUG=""

# Désactiver les logs llama.cpp
export LLAMA_LOG_DISABLE=1

# Lancer l'application
./build/Sambo
```

## Problèmes Résolus

### Warnings GTK de Layout
- **Problème** : Messages répétitifs "Trying to measure GtkBox for height X, but it needs at least 463"
- **Cause** : Contraintes de taille insuffisantes dans ProfileManager
- **Solution** :
  - Ajout de `set_size_request(-1, 500)` pour le details_box
  - Ajout de `set_size_request(-1, 400)` pour la ScrolledWindow
  - Mise à jour CSS avec des min-height appropriées

### Warnings CSS
- **Problème** : "No property named max-height", "Percentages are not allowed here"
- **Cause** : Propriétés CSS non supportées par GTK
- **Solution** : Remplacement par des propriétés équivalentes (min-height, valeurs en pixels)

### Logs Verbeux llama.cpp
- **Problème** : Sortie très verbeuse lors du chargement des modèles
- **Solution** : Scripts de filtrage pour les différents cas d'usage

## Métriques de Performance

Les scripts de filtrage permettent de réduire significativement le volume de sortie :

- **Mode normal** : ~500-1000 lignes de logs au démarrage
- **Mode quiet** : ~100-200 lignes (filtrage GTK)
- **Mode minimal** : ~10-20 lignes (messages essentiels uniquement)

Cette réduction améliore la lisibilité et permet de se concentrer sur les messages vraiment importants lors du développement.
