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
        private Button? send_to_editor_button = null; // Ajout d'un bouton pour transférer vers l'éditeur

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

            // Créer un bouton pour transférer le contenu vers l'éditeur
            // Le bouton n'est visible que pour les réponses de l'IA
            if (!is_user) {
                send_to_editor_button = new Button();
                stderr.printf("🟡 CHATBUBBLEROW: Bouton éditeur créé\n");
                send_to_editor_button.set_icon_name("document-edit-symbolic");
                send_to_editor_button.add_css_class("flat");
                send_to_editor_button.set_tooltip_text(_("Transférer vers l'éditeur"));
                send_to_editor_button.set_halign(Align.END);
                send_to_editor_button.set_valign(Align.CENTER);
                send_to_editor_button.clicked.connect(on_send_to_editor);

                var button_box = new Box(Orientation.HORIZONTAL, 0);
                stderr.printf("🟡 CHATBUBBLEROW: button_box créé\n");
                button_box.set_halign(Align.END);
                button_box.append(send_to_editor_button);
                bubble_box.append(button_box);
                stderr.printf("🟡 CHATBUBBLEROW: Bouton ajouté à bubble_box\n");
            }

            // Ajouter la bulle à la boîte principale
            this.append(bubble_box);
            stderr.printf("✅ CHATBUBBLEROW: Construction terminée - bubble_box ajouté au widget principal\n");
        }

        /**
         * Gère le clic sur le bouton "Transférer vers l'éditeur"
         */
        private void on_send_to_editor() {
            // Trouver la fenêtre principale
            var app_window = this.get_root() as Gtk.Window;
            if (app_window == null) return;

            // Trouver le premier MainWindow dans les parents
            unowned Gtk.Window? main_window = app_window;

            // Créer un gestionnaire de documents
            var doc_manager = Sambo.Document.DocumentConverterManager.get_instance();

            try {
                // Créer un document pivot à partir du contenu du message
                var doc = doc_manager.create_document_from_content(message.content, "", "md");

                // Trouver une référence à la MainWindow
                if (app_window is MainWindow) {
                    var main = (MainWindow) app_window;
                    // Ouvrir le document dans un nouvel onglet
                    main.open_document_in_tab(doc, "");

                    // Afficher un toast
                    var toast = new Adw.Toast(_("Message transféré vers l'éditeur"));
                    toast.set_timeout(3);
                    main.add_toast(toast);
                } else {
                    // Essayer de trouver la MainWindow dans l'application
                    var app = GLib.Application.get_default() as Gtk.Application;
                    if (app != null) {
                        foreach (var window in app.get_windows()) {
                            if (window is MainWindow) {
                                var main = (MainWindow) window;
                                main.open_document_in_tab(doc, "");

                                // Afficher un toast
                                var toast = new Adw.Toast(_("Message transféré vers l'éditeur"));
                                toast.set_timeout(3);
                                main.add_toast(toast);
                                break;
                            }
                        }
                    }
                }
            } catch (Error e) {
                warning("Erreur lors du transfert vers l'éditeur : %s", e.message);
            }
        }

        /**
         * Met à jour le contenu affiché (pour le streaming)
         */
        public void update_content() {
            stderr.printf("[TRACE][IN] CHATBUBBLEROW: update_content appelé\n");
            if (content_label != null && message != null) {
                stderr.printf("[TRACE][IN] CHATBUBBLEROW: Mise à jour du contenu: '%s'\n",
                    message.content.length > 50 ? message.content.substring(0, 50) + "..." : message.content ?? "(vide)");
                stderr.printf("[TRACE][OUT] CHATBUBBLEROW: Appel content_label.set_text()\n");
                content_label.set_text(message.content);
                stderr.printf("[TRACE][OUT] CHATBUBBLEROW: Contenu mis à jour avec succès\n");
            } else {
                stderr.printf("[TRACE][IN] CHATBUBBLEROW: ERREUR - content_label ou message est null\n");
            }
        }
    }
}
