Voici un plan d’implémentation progressif, découpé en phases indépendantes, pour transformer IntaText en une application capable de gérer des documents complexes avec un langage pivot et une édition WYSIWYG.

---

## **Phase 1 : Refactoring et préparation du socle**

- **Objectif** : Préparer l’architecture pour accueillir le langage pivot et les modules de conversion.
- Création d’un module central de gestion des conversions (interfaces, gestionnaire de convertisseurs).
- Ajout d’un format pivot simple (ex : XML ou ODF simplifié) et d’un modèle de document interne.
- Refactoring de l’explorateur pour qu’il passe par ce module lors de l’ouverture d’un fichier.
- **Test** : Ouvrir un fichier texte simple, vérifier que le contenu est converti dans le pivot et affiché dans l’éditeur (même si l’édition reste basique).

---

## **Phase 2 : Intégration d’un éditeur WYSIWYG**

- **Objectif** : Permettre l’édition visuelle du document pivot.
- Intégration d’un composant WebView avec un éditeur WYSIWYG (ex : CKEditor, ProseMirror).
- Mise en place de la communication entre le modèle pivot et l’éditeur (chargement/sauvegarde du contenu).
- **Test** : Charger un document pivot, l’éditer visuellement, sauvegarder les modifications dans le pivot.

---

## **Phase 3 : Conversion entrée/sortie pour formats simples**

- **Objectif** : Gérer l’import/export de formats courants (TXT, HTML, Markdown).
- Développement de convertisseurs pour ces formats (vers et depuis le pivot).
- Ajout de la logique d’export dans l’interface (menu ou bouton).
- **Test** : Importer un fichier TXT/HTML/Markdown, l’éditer, puis l’exporter dans un autre format simple.

---

## **Phase 4 : Support des formats complexes (ODF, PDF)**

- **Objectif** : Ajouter la gestion des formats bureautiques et PDF.
- Intégration de bibliothèques spécialisées (librevenge, Poppler, LibreOfficeKit).
- Développement de convertisseurs ODF/PDF ↔ pivot.
- Gestion des styles, images, tableaux, métadonnées.
- **Test** : Importer un ODT ou PDF, vérifier la fidélité de la conversion, éditer, exporter dans un autre format complexe.

---

## **Phase 5 : Scénarios avancés et robustesse**

- **Objectif** : Finaliser l’expérience utilisateur et la robustesse.
- Gestion des erreurs de conversion, des cas limites, et des pertes de données.
- Ajout de la prévisualisation/export direct depuis l’éditeur.
- Optimisation des performances et de la gestion mémoire.
- **Test** : Scénarios réels d’utilisation (PDF → édition → ODT, ODT → édition → PDF, etc.), tests de stress sur de gros documents.

---

**Chaque phase est autonome, testable et exécutable indépendamment.**  
À la fin de chaque étape, l’application reste fonctionnelle et peut être utilisée pour valider les choix techniques avant d’aller plus loin.
