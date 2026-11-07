# SAMBO / PHACO
## Plan directeur de développement et de suivi

**Version 0.1 — 7 novembre 2026**  
**Document associé :** [Architecture fonctionnelle et technique v4](../architecture-fonctionnelle-technique-v4.md)  
**Chef de projet :** Emmanuel Toulouse  
**Équipe technique :** Embryon SAMBO (assistant ChatGPT, interventions à la demande du chef de projet)

> **Objectif** : implémenter et valider en laboratoire l'ensemble du périmètre fonctionnel SAMBO, tout en garantissant une architecture générique réutilisable sur d'autres navires. PHACO est la première configuration de référence et non un cas codé en dur.

## 1. Organisation et règles de travail

- Le chef de projet définit les besoins et priorités, arbitre les choix et valide le résultat métier.
- L'équipe technique prépare architecture détaillée, code, tests, documentation, scripts et intégration ; elle privilégie l'automatisation et les outils connectés.
- Langages prioritaires : **Vala**, puis **C**, puis **Python** lorsqu'indispensable (notamment bibliothèques IA). Autres langages si contrainte explicite (interface Web, workflows).
- Chaque changement sensible est isolé dans une branche et présenté en pull request ; pas de fusion sans validation.
- Tests unitaires et de non-régression exécutés lorsque l'environnement le permet ; les tests non exécutés ou non démontrables sont déclarés explicitement.
- Revue cybersécurité et sécurité maritime intégrée, particulièrement pour tout système pouvant agir sur un équipement.
- Documents et exigences suivis par GitHub ; tâches via Issues ; propositions et commentaires via Pull Requests.
- Une étape métier à la fois ; validation du chef de projet avant la suivante. Les sous-opérations techniques peuvent être automatisées ensemble.

## 2. Gouvernance documentaire

| Document | Rôle | Validation |
|---|---|---|
| Architecture v4 | Référence fonctionnelle et cible technique | Chef de projet après revue |
| Plan directeur v0.1 | Chantiers, jalons, priorités et suivi | Chef de projet |
| ADR (Architecture Decision Record) | Décisions structurantes, options et arbitrages | Chef de projet |
| Registre de risques | Cyber, sûreté, techniques, exploitation et résiduels | Chef de projet |
| Plans/rapports de tests | Critères, exécution, résultats, non-régressions | Équipe technique puis chef de projet |
| Profils de navire | Équipements, zones, protocoles, seuils et restrictions | Chef de projet / responsable du navire |

Une proposition d'expert peut être conservée dans une Issue même si elle n'est pas acceptée. Les commentaires de revue ne valent pas validation automatique.

## 3. Chantiers du projet

| ID | Chantier | Livrables principaux | Priorité | État initial |
|---|---|---|---|---|
| S00 | Audit du laboratoire | Inventaires A9, X1, X2, R7, dépôts, services et dépendances | P0 | À faire |
| S01 | Architecture logicielle | Modèle de données, API, contrats d'événements et adaptateurs | P0 | À faire |
| S02 | Cybersécurité et AAA | Identités, droits, risques, segmentation et durcissement | P0 | À faire |
| S03 | Orchestration Vala | Routage, événements, erreurs, services, tests | P0 | Prototype partiel à auditer |
| S04 | Chaîne vocale | Wake word, STT, Voice ID, TTS, commandes communes | P1 | Prototypes partiels |
| S05 | Interfaces GNOME/Web | UI tactile, tableaux de bord, commandes, droits | P1 | À faire |
| S06 | Simulateur de navire | Capteurs et équipements simulés, pannes, scénarios | P0 | À faire |
| S07 | Navigation | Signal K, NMEA, carte, instruments et alarmes | P1 | À faire |
| S08 | Confort multizone | Éclairage, audio, chauffage/climatisation des 3 postes | P1 | À faire |
| S09 | Énergie | Batteries, production, charge, autonomie, délestage | P1 | À faire |
| S10 | Équipements techniques | Groupe électrogène, chauffe-eau, dessalinisateur | P2 | À faire |
| S11 | Journal de bord | Acquisition, dictée/saisie, traçabilité, synthèse, export | P1 | Spécification retenue |
| S12 | PHACO Connect | Hébergement, publication filtrée, accès famille, confidentialité | P2 | À faire |
| S13 | SAMBO Safety | Veille solitaire, crises, alertes, procédures, tests | P0 conception / P2 intégration | À faire |
| S14 | Communications | Réseaux, interphonie, multimédia, Internet intermittent | P2 | Partiellement existant |
| S15 | Validation transverse | CI, tests, non-régression, résilience, cyber, sûreté | Transversal | À structurer |
| S16 | Portabilité multi-navire | Profils, configuration, adaptateurs, documentation de déploiement | Transversal | À définir |

**P0** : fondations indispensables ; **P1** : fonctions principales ; **P2** : intégrations spécialisées ; **transversal** : présent dans chaque chantier.

## 4. Jalons proposés

### J0 — Référentiel et état de départ
- Vérifier accès et arborescence GitHub, sans modifier le code existant.
- Publier architecture et plan directeur sur une branche de revue.
- Recueillir les remarques de Gérard Bigot ; ouvrir des Issues pour les propositions retenues.
- Auditer les quatre machines et les sources de code de l'orchestrateur, de la chaîne vocale et du provisioning.
- Établir les écarts entre prototypes et architecture cible.

**Acceptation :** inventaire sourcé, documents accessibles, remarques traçables, risques initiaux identifiés.

### J1 — Socle générique de commande
- Définir contrat d'API versionné et identité utilisateur/terminal/zone.
- Mettre en place moteur de permissions et contrôles déterministes.
- Créer un simulateur de navire et de commandes sans actionneurs physiques.
- Tester authentification, rejets, expirations, replay, concurrence et audit.

**Acceptation :** tests unitaires et intégration reproductibles ; aucun contournement connu des contrôles dans le périmètre testé.

### J2 — Interfaces et chaîne vocale
- Unifier les commandes voix et GNOME/Web sur la même API.
- Tableaux de bord timonerie/postes 1 et 2 ; affichage des données simulées.
- TTS, retours d'états distincts (demandé/autorisé/transmis/observé).

**Acceptation :** même commande, même politique d'autorisation, quelle que soit l'interface ; tests de déconnexion.

### J3 — Supervision nautique et technique en lecture seule
- Intégration Signal K et capteurs disponibles.
- Tableau de bord navigation ; énergie, eau et équipements.
- Gestion des données périmées, incohérentes, manquantes.

**Acceptation :** diagnostics de validité et résilience ; aucune commande physique.

### J4 — Journal, confort et portail
- Journal automatique et manuel avec correction tracée.
- Confort des trois zones sur dispositifs simulés puis validés.
- PHACO Connect avec publication volontaire et synchronisation sortante.

**Acceptation :** confidentialité et tests des modes hors ligne, sans accès du portail aux commandes.

### J5 — Crises, résilience et équipements sensibles
- Analyse de dangers, stratégie de veille solitaire et alertes indépendantes.
- Scénarios de panne et fausses alertes.
- Intégration progressive de systèmes techniques avec interverrouillages constructeur.

**Acceptation :** procédures, preuves d'essais, critères de repli, validation métier et de sûreté. La commande nautique critique reste dans une démarche de qualification séparée.

## 5. Format d'une Issue

Chaque tâche devra comporter :
- Identifiant et chantier (`Sxx`), objectif métier, contexte et dépendances.
- Résultat démontrable, périmètre et exclusions.
- Priorité et responsable.
- Critères d'acceptation (tests fonctionnels et sécurité).
- Risques/impact multi-navire.
- Documents ou PR associés.
- État : **À étudier → À faire → En cours → En revue → À tester → Validé** ; **Bloqué** si nécessaire.

Ne pas considérer une tâche « terminée » parce qu'un fichier compile : vérifier comportement, stabilité, absence de régression connue, documentation, sécurité et validation.

## 6. Réunions et revue de situation

### À chaque séance
1. Dernier livrable et tests réels.
2. Tâche métier et blocages.
3. Résultat proposé au chef de projet.
4. Décision, puis étape suivante après « ok ».

### Hebdomadaire
- Avancement par chantier, issues et PR ouvertes/fermées.
- Changements acceptés/rejetés avec raisons.
- Tests passés/échoués/non exécutés.
- Risques nouveaux, sécurité cyber et maritime.
- Priorités et dépendances pour la semaine suivante.

### À chaque jalon
- Démonstration métier, résultats de tests et preuves.
- Mise à jour du registre de risques et de la documentation.
- Validation explicite du chef de projet.

## 7. Portabilité

Architecture générique `SAMBO Core` ; modèle `SAMBO Vessel` décrivant équipements, capteurs, zones, protocoles, permissions, conditions d'exploitation ; `PHACO` comme premier profil. Le logiciel ne doit pas intégrer des numéros de poste, adresses IP, seuils ou types de matériels PHACO en dur. Les adaptateurs et la configuration devront permettre d'ajouter d'autres navires sans réécrire l'orchestrateur ou le contrôleur de sûreté.

## 8. Risques à instruire en priorité

1. Dépendance à une machine de calcul IA pour la sûreté.
2. Alimentation électrique et modes dégradés.
3. Surface d'attaque des tablettes, agents et passerelles NMEA.
4. Fausses alertes / absence de détection d'homme à la mer.
5. Démarrage automatique du groupe, incendie, CO, tension et interverrouillages.
6. Disponibilité/connectivité de PHACO Connect et confidentialité de la position.
7. Complexité globale et capacité de maintenance.
8. Ambiguïté du dépôt GitHub Sambo existant (application Vala/GTK historique à auditer avant réorganisation).

---

**Revue demandée à Gérard Bigot :** commenter l'ordre des chantiers, proposer un périmètre minimal utile, identifier les risques sous-estimés et suggérer des mécanismes de validation indépendants pour les fonctions nautiques sensibles. La validation des recommandations reste une décision d'Emmanuel Toulouse.
