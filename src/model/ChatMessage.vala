using GLib;
using Gtk;

namespace Sambo {
    /**
     * Représente un message dans une conversation de chat
     */
    public class ChatMessage : Object {
        // Type de l'émetteur
        public enum SenderType {
            USER,    // Message envoyé par l'utilisateur
            AI       // Message envoyé par l'IA
        }

        // Propriétés du message
        public string content { get; set; }
        public DateTime timestamp { get; set; }
        public SenderType sender { get; set; }

        // Propriétés pour les statistiques de traitement
        public int token_count { get; set; default = 0; }
        public double processing_duration { get; set; default = 0.0; } // en secondes
        public bool is_processing_complete { get; set; default = false; }
        public DateTime? completion_time { get; set; default = null; } // Heure de fin de traitement

        /**
         * Crée un nouveau message
         */
        public ChatMessage(string content, SenderType sender) {
            this.content = content;
            this.sender = sender;
            this.timestamp = new DateTime.now_local();
        }

        /**
         * Obtient l'horodatage formaté pour l'affichage
         */
        public string get_formatted_time() {
            return timestamp.format("%H:%M");
        }

        /**
         * Formate une durée en secondes au format hh:mm:ss
         */
        private string format_duration(double duration_seconds) {
            int total_seconds = (int) Math.round(duration_seconds);
            int hours = total_seconds / 3600;
            int minutes = (total_seconds % 3600) / 60;
            int seconds = total_seconds % 60;

            return "%02d:%02d:%02d".printf(hours, minutes, seconds);
        }

        /**
         * Obtient les statistiques de traitement formatées pour l'affichage
         */
        public string get_formatted_stats() {
            if (!is_processing_complete || sender == SenderType.USER) {
                return timestamp.format("%H:%M");
            }

            // Utiliser l'heure de fin de traitement si disponible, sinon l'heure du message
            DateTime display_time = completion_time ?? timestamp;
            string stats = display_time.format("%H:%M");

            if (token_count > 0) {
                stats += " • %d tokens".printf(token_count);
            }
            if (processing_duration > 0) {
                stats += " • " + format_duration(processing_duration);
            }

            return stats;
        }

        /**
         * Met à jour les statistiques de traitement
         */
        public void set_processing_stats(int tokens, double duration) {
            this.token_count = tokens;
            this.processing_duration = duration;
            this.is_processing_complete = true;
            this.completion_time = new DateTime.now_local(); // Enregistrer l'heure actuelle
            notify_property("token_count");
            notify_property("processing_duration");
            notify_property("is_processing_complete");
            notify_property("completion_time");
        }

        /**
         * Ajoute du texte au contenu existant (pour le streaming)
         */
        public void append_text(string text) {
            content += text;
        }

        /**
         * Met à jour le contenu du message et émet un signal de changement
         */
        public void update_content() {
            // Émet le signal de changement de propriété pour permettre la mise à jour de l'UI
            notify_property("content");
        }
    }

    /**
     * Widget représentant un message dans la conversation
     */
    public class ChatMessageWidget : Gtk.Box {
        public enum SenderType {
            USER,
            AI
        }

        public ChatMessageWidget(string text, SenderType sender) {
            Object(orientation: Orientation.HORIZONTAL, spacing: 6);

            // Configuration de base du conteneur de message
            var message_box = new Box(Orientation.VERTICAL, 3);
            message_box.set_margin_top(4);
            message_box.set_margin_bottom(4);
            message_box.set_margin_start(8);
            message_box.set_margin_end(8);

            // Texte du message
            var label = new Label(text);
            label.wrap = true;
            label.set_xalign(0);
            label.set_selectable(true);
            label.set_max_width_chars(50);

            message_box.append(label);

            // Encadrement du message
            var frame = new Frame(null);
            frame.set_child(message_box);

            // Styliser selon l'expéditeur
            if (sender == SenderType.USER) {
                this.set_halign(Align.END);
                frame.add_css_class("user-message");
                this.set_margin_start(50);
                this.set_margin_end(10);
            } else {
                this.set_halign(Align.START);
                frame.add_css_class("ai-message");
                this.set_margin_start(10);
                this.set_margin_end(50);
            }

            this.append(frame);
        }
    }
}
