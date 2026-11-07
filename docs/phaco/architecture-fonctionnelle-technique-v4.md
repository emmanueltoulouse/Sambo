# SAMBO / PHACO
## Architecture fonctionnelle, technique, cybersécurité et sécurité maritime

**Version : 4.0 — 7 novembre 2026**  
**Statut : architecture fonctionnelle consolidée, à expertiser**  
**Cible initiale : PHACO (Bénéteau Évasion 32), solution générique réutilisable sur d'autres navires.**  
**Responsabilités : Emmanuel Toulouse, chef de projet ; Embryon SAMBO, assistance technique.**

> **Important :** les fonctionnalités décrites sont une *cible*. Les prototypes de laboratoire ne constituent pas une installation qualifiée pour la navigation. La commande des équipements critiques et les communications de détresse exigent des dispositifs autonomes, une analyse de risques et des essais spécifiques.

## 1. Vision et principes

SAMBO est une plateforme intelligente locale, modulaire et ouverte, destinée à assister la navigation en solitaire ou en équipage réduit, superviser les équipements du bord, gérer le confort et les ressources, maintenir le lien avec les proches et contribuer à la détection des crises.

Principes fondamentaux :
1. Autorité finale du capitaine et maintien des commandes manuelles.
2. Séparation de l'IA (interprétation/propositions) et des contrôleurs déterministes (autorisation/sûreté/exécution).
3. Fonctionnement local pour les fonctions essentielles ; Internet facultatif et intermittent.
4. Défaillance de SAMBO sans perte des moyens essentiels de navigation, sécurité ou secours.
5. Architecture multi-navire : composants génériques, équipements décrits par profils et configuration PHACO spécifique.
6. Traçabilité des commandes, de leurs auteurs, des données et des résultats ; informations incertaines et périmées explicitement signalées.
7. Principe de moindre privilège, défense en profondeur et tests avant toute interaction physique sensible.

## 2. Architecture logique

```text
Voix (wake word / STT / Voice ID)      GNOME Vala/GTK4      Web tactile/PWA
                 \                         |                    /
                  +------- API commune authentifiée ------------+
                                     |
                            Orchestrateur Vala/GLib
                              /             \
                    Intentions/LLM       Services et journal
                              \             /
                       Authentification / AAA
                                     |
                       Règles de sûreté déterministes
                                     |
                 Passerelle d'actions à privilèges minimaux
                    /               |                \
             Signal K/NMEA     Home Assistant     Services techniques
                    |               |                |
            Navigation (lecture   Confort         Énergie/eau/
             seule d'abord)                       équipements
```

Les agents (Ollama / Qwen3.5 9B, éventuels OpenClaw/Hermes) ne disposent **d'aucun accès de contournement** aux actionneurs. Les confirmations sont liées à des identités et actions vérifiées côté serveur, jamais à des affirmations libres d'un client ou LLM. Une transmission de commande ne vaut pas exécution : distinguer *demandée, validée, envoyée, acquittée, observée*.

### Modules conceptuels

`sambo-core`, `sambo-identity`, `sambo-aaa`, `sambo-intent`, `sambo-voice`, `sambo-gnome`, `sambo-web`, `sambo-nautical`, `sambo-energy`, `sambo-equipment`, `sambo-comfort`, `sambo-logbook`, `sambo-safety`, `sambo-cyber`, `sambo-audit`, `sambo-connect`, `sambo-adapters`. Ces noms définissent les domaines visés, **pas des bibliothèques déjà implémentées**.

## 3. Laboratoire et portabilité matérielle

| Machine | Système et matériel connus | Rôle |
|---|---|---|
| A9 | GEEKOM A9 Max, Ubuntu, Ryzen AI 9 HX 370, 32 Go, SSD 2 To | STT/voix, Ollama, interprétation, orchestration Vala et développement |
| X1 | Debian 13, Docker, NAS | Home Assistant, Jellyfin, Gitea, stockage et services |
| X2 | ACE Magician AM06 Pro, Debian 13.3, Ryzen 7 5700U, 32 Go | Agents, workflows et expérimentations |
| R7 | Lenovo C930, Ubuntu | Tests des interfaces GNOME/Web, clients distants, résilience |

LAN laboratoire connu : A9 `192.168.50.1`, X1 `192.168.50.11`, X2 `192.168.50.12`. R7 dépend du réseau de test. A9 assure une fonction de routage vers Internet. Le plan d'implantation embarquée reste à définir au regard de la consommation, des vibrations, de l'humidité et des dépendances électriques. Les quatre machines de laboratoire ne constituent **pas** une nomenclature d'embarquement.

## 4. Trois postes embarqués et interfaces

**Timonerie, poste 1 et poste 2** disposeront chacun d'une tablette, d'éclairage, de haut-parleurs, et d'une gestion de chauffage/climatisation ; acquisition vocale locale à étudier. Les zones possèdent leur température, consigne, lumière, volume/source audio, alertes et profil d'affichage. Les capacités réelles de climatisation indépendante dépendront de l'installation physique.

- **Timonerie** : priorité instruments, cartographie, alarmes, état du pilote et moteur.
- **Postes 1 et 2** : navigation consultable, confort, énergie, journal, communication, supervision.
- **Client natif** : Vala, GTK4/libadwaita sous GNOME, y compris administration et diagnostic.
- **Client tablette** : Web local responsive/PWA pour Android et autres navigateurs. Un développement Android natif reste optionnel.
- **Matériel** : recherche de tablettes durcies IP68, lisibles dehors, faible consommation, alimentation/montage sûrs, entretien possible, occasion envisageable. Galaxy Tab Active3 8 pouces étudiée mais vieillissante ; écran plus grand à envisager en timonerie.

Les deux interfaces de commande et la voix utilisent **exactement la même API, les mêmes droits et contrôles**. Elles doivent détecter les liens interrompus et éviter tout rejeu de commande. Un mode de lecture hors ligne signalera la fraîcheur des données.

## 5. Voix, identité, IA et contrôle

Chaîne cible : réveil → capture → STT → identification vocale → interprétation → AAA → contrôle de sûreté → confirmation éventuelle → adaptation/exécution → vérification de résultat → audit → retour vocal/visuel.

Technologies expérimentées : openWakeWord, PyAudio, Faster-Whisper, SpeechBrain ECAPA-TDNN ; synthèse locale Piper prévue ; Ollama/Qwen3.5 9B disponible. Le provisioning Vala/SQLite gère les rôles **patron, équipier, invité**. La biométrie vocale reste expérimentale : elle ne doit pas être la seule preuve d'identité pour une commande critique. Un ordre doit référencer utilisateur, terminal, zone, cible, action, paramètres typés, horodatage, expiration, contexte et identifiant unique. Les ordres concurrents doivent être arbitrés ; priorité à la commande locale physique.

## 6. Navigation et informations nautiques

Sources prévues : GNSS, NMEA 0183/NMEA 2000, AIS, cap, COG/SOG, vitesse surface, profondeur, vent, moteur et pilote automatique. **Signal K** est candidat comme agrégateur ; **OpenCPN et AvNav** comme solutions de cartographie à intégrer plutôt qu'à réécrire. Tout relevé doit identifier sa source, son heure, son unité, sa référence (vrai/magnétique, profondeur sous sonde/quille), son état de validité.

Supervisions ciblées : route, écart, profondeur, AIS/CPA/TCPA, mouillage, météo, alarmes. AIS n'est pas exhaustif ; la veille, les instruments indépendants et le RIPAM/COLREG restent indispensables. **NMEA est en lecture seule par défaut.** Les commandes du pilote et a fortiori de la propulsion sont exclues de la première exploitation ; toute activation future requiert analyse de risques, interverrouillages, contrôle des capteurs, reprise manuelle et essais sur banc.

## 7. Confort et automatismes des zones

- Éclairage : marche/arrêt, variation, scènes jour/nuit/lecture/repos ; feux réglementaires et éclairage d'urgence indépendants.
- Chauffage/climatisation/ventilation : consignes par zone, températures, humidité, occupation, budget énergétique et sécurités de l'installation.
- Audio multizone : réponses SAMBO, interphonie, musique, livres audio, appels et alertes avec priorité aux événements de sécurité ; Snapcast à étudier, Jellyfin conservé. Les avertisseurs critiques restent autonomes.
- Modes contextuels : **navigation, mouillage, port, nuit, absence, urgence**, avec automatismes non critiques et contrôles stricts.

## 8. Énergie, eau et équipements

Supervision : batteries, solaire, alternateur, alimentation quai, groupe électrogène, tension, puissance, courants, autonomie estimée avec hypothèses. Délestage **déterministe** par catégories (critique, important, différable, confort). Aucune coupure d'un système de sécurité par simple optimisation énergétique.

- **Groupe électrogène** : états, heures, défauts, température, puissance, carburant, demandes de démarrage/arrêt envisagées. Interverrouillages indépendants contre risques électriques, mécaniques, thermiques et CO ; pas de commande automatique sans validation.
- **Chauffe-eau** : température, consigne/état, planification selon énergie, alarmes ; thermostats et sécurité pression indépendants.
- **Dessalinisateur** : production, débit, pression, conductivité/qualité, filtres, rinçage, consommation et maintenance. Respect impératif des séquences constructeur et rejet autonome d'eau non conforme.
- Autres : pompes de cale et bilges, réservoirs, réfrigération, fuites et maintenance.

## 9. SAMBO Logbook : journal de bord intelligent

Service indépendant `sambo-logbook` avec stockage local. Acquisition périodique et sur événements de données **disponibles et validées** : heure/position, route/cap/vitesse, vent, profondeur, moteur, production/consommation, eau, équipements, escales et alarmes. Distinction entre historique haute fréquence et entrées du journal.

Enrichissements par le capitaine : voix, clavier/tactile, notes, photos, fichiers et éventuellement audio. Chaque entrée : identifiant, date, source/auteur, type, confidentialité, références aux mesures. **Corrections tracées**, pas d'effacement silencieux. Synthèses quotidiennes et recherches par IA clairement distinguées des données d'origine. Exports et sauvegardes hors ligne. Le journal métier est distinct du journal d'audit cyber. Un éventuel statut réglementaire devra être étudié séparément.

## 10. PHACO Connect : portail familial hébergé

Site accessible à la famille (et éventuellement au public selon profil) avec carte de position publiée, route/escales, date de mise à jour, récits, photos, extraits *sélectionnés* du journal, messages et statut volontaire de bien-être du capitaine. La position publique peut être masquée, retardée ou approximée. **Aucune donnée médicale détaillée ni position exacte de secours publiée par défaut.** L'ancienneté des nouvelles est visible : silence réseau ≠ détresse.

Architecture : service local → filtrage/validation → synchronisation sortante différée → hébergement extérieur. **Aucun accès du portail aux API de commande du bateau.** Profils : public, famille, contacts d'urgence, administration ; minimisation, authentification et conservation bornée des données.

## 11. SAMBO Safety et veille solitaire

Détection, qualification et escalade de crises : homme à la mer, blessure/malaise, absence préoccupante, incendie/CO, voie d'eau, collision/échouement, pannes critiques. Déclenchement par voix, tablette et surtout **bouton physique indépendant**. L'IA générative n'a pas l'autorité de déclarer une détresse.

Veille solitaire : dispositif porté et/ou bouton SOS, état de présence/embarquement, contexte port/mouillage/navigation, réponses vocales/tactiles/physiques. **Perte Bluetooth ou silence ne prouvent pas un homme à la mer ni un malaise.** Alarmes et escalades internes de normal → attention → alerte → urgence → détresse, sans confusion avec les catégories réglementaires.

Communications à étudier : VHF marine canal 16/ASN, EPIRB, AIS MOB, balise personnelle, téléphone mobile, satellite, notification aux proches. Une « alerte automatique au CROSS » n'est **pas acquise** : protocole officiel, équipement qualifié, accords et validation de bout en bout sont à examiner. Le 196 concerne les appels téléphoniques depuis le littoral quand la couverture le permet ; en mer privilégier VHF et moyens adaptés. Hors France, tenir compte du MRCC compétent. Les dispositifs de détresse doivent rester indépendants des serveurs SAMBO.

Dossier d'urgence protégé : identité du navire, MMSI si disponible, équipements, équipage, contacts, position/horodatage, événements, et informations médicales uniquement volontaires et accessibles aux personnes autorisées. Journal chronologique d'incident, traçabilité des notifications et acquittements.

## 12. Cybersécurité et sûreté

Zones de confiance : (A) réseau nautique/OT, (B) autorisation et commande, (C) services techniques/domotique, (D) IA et agents, (E) interfaces clientes, (F) communication et Internet/portail. Flux strictement autorisés, moindre privilège, chiffrement, identification des équipements et services, secrets protégés, mises à jour contrôlées, durcissement et journaux résistants à l'altération.

Menaces : tablette compromise/volée, usurpation de voix, rejeu, faux messages NMEA/GNSS, prompt injection, agents détournés, Wi-Fi compromis, passage entre VLAN, déni de service, panne/compromission Home Assistant, mise à jour malveillante, publication excessive de données. Un pare-feu IP ne protège pas seul un bus NMEA 2000 contre les messages injectés localement.

Approche risques : EBIOS Risk Manager/ISO 27005 pour les scénarios cyber ; analyse de dangers/défaillances et barrières indépendantes pour la sûreté physique. Scénarios dégradés : absence Internet, perte Wi-Fi/GNSS/serveur/tablette/IA/énergie, données incohérentes, perte des passerelles. Chaque fonction doit définir son état de repli et sa commande manuelle.

Référentiels à analyser **selon applicabilité** : ISO 27001/27002, NIST CSF, IEC 62443, série IEC 61162, lignes directrices OMI cybermaritimes, RIPAM/COLREG, Division 240 française et instructions constructeurs. Aucune certification n'est revendiquée.

## 13. Données, stockage et API

Catégories : télémétrie nautique, séries temporelles, états, commandes, utilisateurs, habilitations, configurations, alarmes, journal, audit, médias et données publiables. SQLite adapté aux sous-systèmes structurés locaux ; base de séries temporelles à sélectionner selon charge. Synchronisation intermittente avec idempotence, dédoublonnage, version, gestion des conflits, horodatage et **interdiction de rejouer automatiquement une commande physique expirée**. Protéger particulièrement biométrie, localisation, santé et contacts de secours.

## 14. Développement, validation et portabilité

Technologies privilégiées par le projet : **Vala → C → Python en dernier recours**, GTK4/libadwaita, Meson/Ninja, Git/GitHub, GitHub Actions ; Python conservé pour les bibliothèques IA si justifié. Services envisagés : HTTPS/JSON, WebSocket, MQTT non critique, Signal K, Home Assistant, Jellyfin.

Cycle : spécifier → simuler → coder → tests unitaires → intégration → tests de non-régression → revue cyber/sûreté → validation chef de projet → déploiement progressif. PHACO est le **premier profil de navire**, avec ses zones, équipements, seuils, connexions et permissions décrits en configuration plutôt qu'en dur.

## 15. État documenté au 7 novembre 2026

| Domaine | État |
|---|---|
| Laboratoire A9/X1/X2/R7 | Connu, à réauditer |
| Home Assistant, Jellyfin, Gitea sur X1 | Opérationnels lors des derniers contrôles |
| Wake word, capture, STT Faster-Whisper | Prototypes testés ; STT validé en laboratoire |
| SpeechBrain / Voice ID | Prototype testé, sécurité biométrique non validée |
| Provisioning Vala/SQLite | Fonctions CLI testées |
| Orchestrateur Vala | Socle initial compilé |
| Interpréteur d'intentions | Prototype initial |
| Ollama/Qwen3.5 9B | Installé, intégration bout en bout non validée |
| GNOME SAMBO, Web tactile, trois postes | À développer/intégrer |
| AAA complet, contrôleur de sûreté | À développer/intégrer |
| Signal K, NMEA, OpenCPN/AvNav | À intégrer |
| Énergie, confort, groupe, eau | À intégrer |
| Logbook | Spécification fonctionnelle retenue |
| PHACO Connect, SAMBO Safety | Architecture proposée, non déployés |
| Commandes physiques critiques / essais à bord | Non réalisés |

> Attention : le dépôt GitHub `emmanueltoulouse/Sambo` contient déjà une application Vala/GTK ; son périmètre, son historique et ses relations avec l'architecture nautique doivent être audités avant toute refonte. Ce document est publié **séparément** sous `docs/phaco/` et ne modifie pas le code.

## 16. Questions de revue externe

1. Comment isoler matériellement et logiquement les contrôleurs déterministes de l'IA ?
2. Quelle architecture embarquée réduit coût énergétique, complexité et points uniques de défaillance ?
3. L'approche Vala/GLib + clients GNOME/Web + API commune est-elle adaptée ?
4. Quels profils et contrats d'adaptateurs garantissent la réutilisation sur d'autres navires ?
5. Quelle stratégie de simulation et de tests de non-régression est suffisante ?
6. Comment sécuriser NMEA, les tablettes, Home Assistant, MQTT et les agents ?
7. Quels mécanismes indépendants de détresse, MOB et sécurité du navigateur solitaire recommander ?
8. Comment qualifier les fausses alertes et confirmer la réception effective d'une demande de secours ?
9. Quels interverrouillages pour groupe, dessalinisateur et autres équipements techniques ?
10. Quelle première version embarquée est réaliste et quels risques manquent à l'analyse ?

**Document préparé par Embryon SAMBO à la demande d'Emmanuel Toulouse. Proposition soumise à la revue de Gérard Bigot et à la validation du chef de projet.**
