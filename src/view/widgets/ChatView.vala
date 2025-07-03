using Gtk;
using Adw;

namespace Sambo {
    /**
     * Widget pour la vue complète du chat
     */
    public class ChatView : Gtk.Box {
        private ApplicationController controller;
        private ScrolledWindow scroll;
        private Box message_container;
        private Entry message_entry;
        private Button send_button;
        private Button model_selector_button;
        private bool is_processing = false;

        /**
         * Crée une nouvelle vue de chat
         */
        public ChatView(ApplicationController controller) {
            Object(orientation: Orientation.VERTICAL, spacing: 6);
            this.controller = controller;

            // Ajouter la classe CSS
            this.add_css_class("chat-view");

            // Créer la barre d'outils du chat
            create_chat_toolbar();

            // Conteneur pour les messages
            message_container = new Box(Orientation.VERTICAL, 10);
            message_container.set_vexpand(true);

            // Zone de défilement pour les messages
            scroll = new ScrolledWindow();
            scroll.set_vexpand(true);
            scroll.set_child(message_container);

            // Zone de saisie du message
            message_entry = new Entry();
            message_entry.set_placeholder_text("Votre message...");
            message_entry.set_hexpand(true);

            // Bouton d'envoi
            send_button = new Button.with_label("Envoyer");

            // Disposition horizontale pour l'entrée
            var input_box = new Box(Orientation.HORIZONTAL, 6);
            input_box.append(message_entry);
            input_box.append(send_button);

            // Connecter les signaux
            send_button.clicked.connect(on_send_message);
            message_entry.activate.connect(on_send_message);

            // Ajouter les widgets à la vue principale
            this.append(scroll);
            this.append(input_box);

            // Message de bienvenue
            var welcome = new ChatMessage("Bonjour ! Comment puis-je vous aider aujourd'hui ?", ChatMessage.SenderType.AI);
            add_message(welcome);
        }

        /**
         * Crée la barre d'outils spécifique au chat
         */
        private void create_chat_toolbar() {
            var toolbar = new Box(Orientation.HORIZONTAL, 6);
            toolbar.add_css_class("chat-toolbar");

            // Bouton de sélection de modèle
            model_selector_button = new Button();
            model_selector_button.add_css_class("model-selector-button");
            model_selector_button.add_css_class("flat");
            
            // Créer un conteneur pour l'icône et le texte
            var button_content = new Box(Orientation.HORIZONTAL, 6);
            
            // Icône du modèle (utilise l'icône brain ou cpu selon disponibilité)
            var model_icon = new Image.from_icon_name("applications-science-symbolic");
            model_icon.set_icon_size(IconSize.NORMAL);
            model_icon.add_css_class("model-icon");
            
            // Label pour le modèle actuel
            var model_label = new Label("GPT-4");
            model_label.add_css_class("model-label");
            
            // Icône de dropdown
            var dropdown_icon = new Image.from_icon_name("pan-down-symbolic");
            dropdown_icon.set_icon_size(IconSize.NORMAL);
            dropdown_icon.add_css_class("dropdown-icon");
            
            button_content.append(model_icon);
            button_content.append(model_label);
            button_content.append(dropdown_icon);
            
            model_selector_button.set_child(button_content);
            model_selector_button.set_tooltip_text("Sélectionner un modèle IA");
            
            // Connecter le signal (pour plus tard)
            model_selector_button.clicked.connect(on_model_selector_clicked);
            
            // Ajouter le bouton à la toolbar
            toolbar.append(model_selector_button);
            
            // Spacer pour pousser les éléments vers la droite si nécessaire
            var spacer = new Box(Orientation.HORIZONTAL, 0);
            spacer.set_hexpand(true);
            toolbar.append(spacer);
            
            // Ajouter la toolbar à la vue principale
            this.append(toolbar);
        }

        /**
         * Gestionnaire temporaire pour le clic sur le sélecteur de modèle
         */
        private void on_model_selector_clicked() {
            // TODO: Implémenter la logique de sélection de modèle
            print("Bouton de sélection de modèle cliqué\n");
        }

        /**
         * Ajoute un nouveau message à la conversation
         */
        public void add_message(ChatMessage message) {

            // Vérification de sécurité
            if (message == null) {
                warning("ChatView: Tentative d'ajout d'un message NULL");
                return;
            }

            if (message_container == null) {
                warning("ChatView: message_container est NULL");
                return;
            }

            // Créer un widget de bulle de chat à partir du message
            var bubble = new ChatBubbleRow(message);
            if (bubble == null) {
                warning("ChatView: Impossible de créer ChatBubbleRow");
                return;
            }

            // Ajouter la bulle au conteneur
            message_container.append(bubble);

            // Assurer que l'interface est mise à jour immédiatement
            while (GLib.MainContext.default().iteration(false)) { }

            // CORRECTION: Défiler vers le bas de manière plus fiable
            Timeout.add(50, () => {
                var vadj = scroll.get_vadjustment();
                if (vadj != null) {
                    // Défiler complètement vers le bas
                    vadj.set_value(vadj.get_upper());
                }

                //     Assurer une seconde fois que le défilement est effectué
                Timeout.add(50, () => {
                    if (vadj != null) {
                        vadj.set_value(vadj.get_upper());
                    }
                    return false;
                });

                return false;
            });
        }

        /**
         * Traite l'envoi d'un message
         */
        private void on_send_message() {
            if (is_processing)
                return;

            string text = message_entry.get_text();
            if (text == "")
                return;

            is_processing = true;

            // Créer et ajouter le message de l'utilisateur
            var user_message = new ChatMessage(text, ChatMessage.SenderType.USER);
            add_message(user_message);

            // Effacer le champ de saisie
            message_entry.set_text("");

            // Préparer la réponse
            string response;
            if (text.down().contains("bonjour") || text.down().contains("salut")) {
                response = "Bonjour ! Comment puis-je vous aider ?";
            } else if (text.down().contains("merci")) {
                response = "Avec plaisir !";
            } else if (text.down().contains("aide") || text.down().contains("help")) {
                response = "Je peux vous aider avec diverses tâches. N'hésitez pas à me poser une question.";
            } else {
                response = "J'ai bien reçu votre message : \"" + text + "\". Comment puis-je vous aider davantage ?";
            }

            // Ajouter un délai pour simuler le traitement
            Timeout.add(500, () => {
                // Créer et ajouter la réponse de l'IA
                var ai_message = new ChatMessage(response, ChatMessage.SenderType.AI);

                // Ajouter dans le thread principal
                Idle.add(() => {
                    add_message(ai_message);
                    is_processing = false;
                    return Source.REMOVE;
                });

                return Source.REMOVE;
            });
        }
    }
}
