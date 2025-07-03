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
