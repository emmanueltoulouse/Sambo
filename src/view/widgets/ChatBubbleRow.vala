using Gtk;
using Adw;

namespace Sambo {
    /**
     * Widget représentant une bulle de message dans l'interface de chat
     */
    public class ChatBubbleRow : Gtk.Box {
        private Label content_label;
        private Label time_label;
        private ChatMessage message;

        // Optimisations UI
        private uint update_timeout_id = 0;     // ID du timeout pour debouncing
        private int64 last_update_time = 0;     // Timestamp dernière mise à jour
        private bool pending_update = false;    // Mise à jour en attente

        /**
         * Propriété publique pour accéder au message
         */
        public ChatMessage get_message() {
            return message;
        }

        /**
         * Crée une nouvelle bulle de message
         */
        public ChatBubbleRow(ChatMessage message) {
            Object(orientation: Orientation.VERTICAL, spacing: 3);

            stderr.printf("🟡 CHATBUBBLEROW: Début construction\n");

            // Vérification de sécurité
            if (message == null) {
                stderr.printf("❌ CHATBUBBLEROW: Message NULL passé au constructeur\n");
                warning("ChatBubbleRow: Message NULL passé au constructeur");
                return;
            }

            stderr.printf("🟡 CHATBUBBLEROW: Message reçu: '%s'\n", message.content ?? "(vide)");

            this.message = message;

            // Configuration en fonction du type d'émetteur
            bool is_user = (message.sender == ChatMessage.SenderType.USER);

            // Configuration visuelle de la boîte
            this.margin_start = is_user ? 50 : 12;
            this.margin_end = is_user ? 12 : 50;
            this.margin_top = 6;
            this.margin_bottom = 6;
            this.halign = is_user ? Align.END : Align.START;

            // Ajouter les classes CSS pour styliser
            this.add_css_class("chat-bubble");
            this.add_css_class(is_user ? "user-bubble" : "ai-bubble");

            // Conteneur pour le contenu avec un style de bulle
            var bubble_box = new Box(Orientation.VERTICAL, 3);
            stderr.printf("🟡 CHATBUBBLEROW: bubble_box créé\n");
            bubble_box.add_css_class("bubble-content");

            // Créer le libellé pour le contenu du message
            content_label = new Label(message.content ?? "");
            stderr.printf("🟡 CHATBUBBLEROW: content_label créé avec: '%s'\n", message.content ?? "(vide)");
            content_label.wrap = true;
            content_label.wrap_mode = Pango.WrapMode.WORD_CHAR;
            content_label.xalign = 0;
            content_label.max_width_chars = 40;
            content_label.add_css_class("bubble-text");

            // Créer le libellé pour l'horodatage
            time_label = new Label(message.get_formatted_time());
            stderr.printf("🟡 CHATBUBBLEROW: time_label créé\n");
            time_label.add_css_class("bubble-time");
            time_label.set_halign(is_user ? Align.END : Align.START);

            // Ajouter les libellés au conteneur de bulle
            bubble_box.append(content_label);
            bubble_box.append(time_label);
            stderr.printf("🟡 CHATBUBBLEROW: Labels ajoutés à bubble_box\n");

            // Ajouter la bulle à la boîte principale
            this.append(bubble_box);
            stderr.printf("✅ CHATBUBBLEROW: Construction terminée - bubble_box ajouté au widget principal\n");
        }

        /**
         * Met à jour le contenu affiché avec optimisations (debouncing pour streaming)
         */
        public void update_content() {
            stderr.printf("[TRACE][IN] CHATBUBBLEROW: update_content appelé\n");

            var current_time = get_monotonic_time();

            // Debouncing : éviter les mises à jour trop fréquentes (max 30 FPS = 33ms)
            if (current_time - last_update_time < 33000) {
                // Planifier une mise à jour différée si pas déjà planifiée
                if (!pending_update) {
                    pending_update = true;

                    // Annuler le timeout précédent s'il existe
                    if (update_timeout_id != 0) {
                        Source.remove(update_timeout_id);
                    }

                    // Planifier la mise à jour dans 33ms
                    update_timeout_id = Timeout.add(33, () => {
                        execute_content_update();
                        update_timeout_id = 0;
                        pending_update = false;
                        return Source.REMOVE;
                    });
                }
                return;
            }

            // Mise à jour immédiate si assez de temps s'est écoulé
            execute_content_update();
        }

        /**
         * Exécute réellement la mise à jour du contenu
         */
        private void execute_content_update() {
            if (content_label != null && message != null) {
                stderr.printf("[TRACE][IN] CHATBUBBLEROW: Mise à jour du contenu: '%s'\n",
                    message.content.length > 50 ? message.content.substring(0, 50) + "..." : message.content ?? "(vide)");
                stderr.printf("[TRACE][OUT] CHATBUBBLEROW: Appel content_label.set_text()\n");

                // Optimisation : éviter les appels set_text inutiles
                string new_content = message.content ?? "";
                if (content_label.get_text() != new_content) {
                    content_label.set_text(new_content);
                    last_update_time = get_monotonic_time();
                }

                stderr.printf("[TRACE][OUT] CHATBUBBLEROW: Contenu mis à jour avec succès\n");
            } else {
                stderr.printf("[TRACE][IN] CHATBUBBLEROW: ERREUR - content_label ou message est null\n");
            }
        }
    }
}
