/* ZoneTransferManager.vala
 *
 * Copyright 2025 Cabinet ETO
 *
 * Gestionnaire pour le transfert et la fusion des contenus
 * des zones ChatView et TerminalView vers l'EditorView
 */

using Gtk;

namespace Sambo {
    /**
     * Gestionnaire pour le transfert des contenus des zones vers l'éditeur
     */
    public class ZoneTransferManager : Object {
        private static ZoneTransferManager? instance = null;
        private ApplicationController controller;

        /**
         * Singleton pour obtenir l'instance unique
         */
        public static ZoneTransferManager get_instance(ApplicationController controller) {
            if (instance == null) {
                instance = new ZoneTransferManager(controller);
            }
            return instance;
        }

        /**
         * Constructeur privé pour le pattern singleton
         */
        private ZoneTransferManager(ApplicationController controller) {
            this.controller = controller;
        }

        /**
         * Extrait le contenu de la ChatView
         */
        public string extract_chat_content(ChatView? chat_view) {
            if (chat_view == null) {
                return "";
            }

            try {
                // Essayer d'accéder aux messages du chat pour extraction du contenu réel
                var content = new StringBuilder();
                content.append("# Historique du Chat IA\n\n");

                // Note: Pour l'instant, on simule l'extraction de quelques messages
                // Dans une implémentation complète, on accéderait aux messages via une méthode publique
                content.append("## Conversation\n\n");
                content.append("**Utilisateur** : Exemple de message utilisateur\n\n");
                content.append("**IA** : Voici une réponse d'exemple de l'assistant IA.\n\n");
                content.append("---\n\n");
                content.append("*Conversation extraite automatiquement*\n\n");

                return content.str;
            } catch (Error e) {
                warning("Erreur lors de l'extraction du contenu du chat : %s", e.message);
                return "# Contenu du Chat\n\n*Erreur lors de l'extraction du contenu*\n\n";
            }
        }

        /**
         * Extrait le contenu de la TerminalView
         */
        public string extract_terminal_content(TerminalView? terminal_view) {
            if (terminal_view == null) {
                return "";
            }

            try {
                // Essayer d'accéder au buffer du terminal pour extraction du contenu réel
                var content = new StringBuilder();
                content.append("# Historique du Terminal\n\n");
                content.append("```bash\n");

                // Note: Dans une implémentation complète, on accéderait au TextBuffer du TerminalView
                // pour extraire tout l'historique des commandes et des sorties
                content.append("# Simulation de l'historique du terminal\n");
                content.append("sambo> help\n");
                content.append("Commandes disponibles:\n");
                content.append("  hello   - Affiche Hello World\n");
                content.append("  help    - Affiche cette aide\n");
                content.append("  clear   - Efface le terminal\n");
                content.append("  date    - Affiche la date et l'heure actuelles\n");
                content.append("  version - Affiche la version de l'application\n\n");
                content.append("sambo> date\n");
                content.append(new DateTime.now_local().format("%c") + "\n\n");
                content.append("# ... autres commandes ...\n");

                content.append("```\n\n");
                content.append("*Historique extrait automatiquement*\n\n");

                return content.str;
            } catch (Error e) {
                warning("Erreur lors de l'extraction du contenu du terminal : %s", e.message);
                return "# Contenu du Terminal\n\n```bash\n# Erreur lors de l'extraction du contenu\n```\n\n";
            }
        }

        /**
         * Fusionne les contenus du chat et du terminal en format Markdown
         */
        public string merge_contents(string chat_content, string terminal_content) {
            var merged = new StringBuilder();

            merged.append("# Transfert des Zones de Communication\n\n");
            merged.append("*Généré automatiquement le " + new DateTime.now_local().format("%Y-%m-%d à %H:%M:%S") + "*\n\n");
            merged.append("---\n\n");

            // Ajouter le contenu du chat s'il n'est pas vide
            if (chat_content.length > 0 && chat_content.strip() != "") {
                merged.append(chat_content);
                merged.append("\n---\n\n");
            }

            // Ajouter le contenu du terminal s'il n'est pas vide
            if (terminal_content.length > 0 && terminal_content.strip() != "") {
                merged.append(terminal_content);
            }

            return merged.str;
        }

        /**
         * Transfère les contenus fusionnés vers l'éditeur via le système pivot
         */
        public bool transfer_to_editor(string merged_content) throws Error {
            if (merged_content.length == 0) {
                throw new IOError.INVALID_DATA("Aucun contenu à transférer");
            }

            try {
                // Utiliser le système DocumentConverterManager existant
                var doc_manager = Sambo.Document.DocumentConverterManager.get_instance();

                // Créer un document pivot à partir du contenu fusionné
                var pivot_doc = doc_manager.create_document_from_content(
                    merged_content,
                    "zones-transfer",
                    "md"
                );

                // TODO: Implémenter l'ouverture dans l'éditeur
                // Cela sera fait dans l'étape suivante avec l'intégration du contrôleur

                return true;
            } catch (Error e) {
                warning("Erreur lors du transfert vers l'éditeur : %s", e.message);
                throw e;
            }
        }

        /**
         * Méthode principale pour effectuer le transfert complet
         */
        public bool perform_zone_transfer(ChatView? chat_view, TerminalView? terminal_view) throws Error {
            try {
                // Extraire les contenus
                string chat_content = extract_chat_content(chat_view);
                string terminal_content = extract_terminal_content(terminal_view);

                // Vérifier qu'il y a du contenu à transférer
                if (chat_content.strip() == "" && terminal_content.strip() == "") {
                    throw new IOError.INVALID_DATA("Aucun contenu disponible dans les zones");
                }

                // Fusionner les contenus
                string merged_content = merge_contents(chat_content, terminal_content);

                // Transférer vers l'éditeur
                return transfer_to_editor(merged_content);
            } catch (Error e) {
                warning("Erreur lors du transfert des zones : %s", e.message);
                throw e;
            }
        }
    }
}
