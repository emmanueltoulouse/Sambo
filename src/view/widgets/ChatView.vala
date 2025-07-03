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
        private Label model_label;
        private Label status_label;
        private Adw.ToastOverlay toast_overlay;
        private string current_model = "";
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

            // Créer le conteneur principal avec ToastOverlay
            var main_content = new Box(Orientation.VERTICAL, 0);
            main_content.append(scroll);
            main_content.append(input_box);
            
            // Créer la barre d'état
            var status_bar = create_status_bar();
            main_content.append(status_bar);

            // Créer le ToastOverlay et y ajouter le contenu principal
            toast_overlay = new Adw.ToastOverlay();
            toast_overlay.set_child(main_content);

            // Ajouter le ToastOverlay à la vue principale
            this.append(toast_overlay);

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
            model_label = new Label("Modèles");
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
            show_model_selection_popover();
        }

        /**
         * Affiche le popover de sélection des modèles avec arborescence interactive
         */
        private void show_model_selection_popover() {
            var popover = new Gtk.Popover();
            popover.set_parent(model_selector_button);
            popover.set_position(Gtk.PositionType.BOTTOM);

            // Obtenir l'arborescence des modèles
            var config = controller.get_config_manager();
            var models_tree = config.get_models_tree();

            // Créer le conteneur principal
            var main_box = new Box(Orientation.VERTICAL, 6);
            main_box.set_margin_start(8);
            main_box.set_margin_end(8);
            main_box.set_margin_top(8);
            main_box.set_margin_bottom(8);

            // Titre du popover
            var title_label = new Label("Sélection du modèle IA");
            title_label.add_css_class("heading");
            title_label.add_css_class("model-selector-title");
            title_label.set_margin_bottom(12);
            main_box.append(title_label);

            // Créer l'arborescence
            var tree_container = new Box(Orientation.VERTICAL, 0);
            tree_container.add_css_class("model-tree");

            // Vérifier s'il y a des erreurs
            if (models_tree.has_error()) {
                // Afficher l'interface d'erreur
                create_error_interface(tree_container, models_tree, popover);
            } else if (models_tree.children.size == 0) {
                // Afficher un message si aucun modèle n'est trouvé (cas de secours)
                var no_model_label = new Label("Aucun modèle disponible");
                no_model_label.add_css_class("dim-label");
                no_model_label.set_margin_top(20);
                no_model_label.set_margin_bottom(20);
                tree_container.append(no_model_label);
            } else {
                // Construire l'arborescence interactive
                foreach (var root_child in models_tree.children) {
                    var tree_widget = create_tree_node_widget(root_child, 0, popover);
                    tree_container.append(tree_widget);
                }
            }

            main_box.append(tree_container);

            var scrolled = new ScrolledWindow();
            scrolled.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);
            scrolled.set_max_content_height(500);
            scrolled.set_min_content_width(450);
            scrolled.set_min_content_height(300);
            scrolled.set_child(main_box);

            popover.set_child(scrolled);
            popover.popup();
        }

        /**
         * Crée un widget pour un nœud de l'arborescence
         */
        private Widget create_tree_node_widget(ConfigManager.ModelNode node, int depth, Gtk.Popover popover) {
            if (node.is_file) {
                // Créer un widget pour un fichier modèle
                return create_model_file_widget(node, depth, popover);
            } else {
                // Créer un widget pour un dossier (Expander)
                return create_folder_expander_widget(node, depth, popover);
            }
        }

        /**
         * Crée un widget Expander pour un dossier
         */
        private Widget create_folder_expander_widget(ConfigManager.ModelNode node, int depth, Gtk.Popover popover) {
            // Créer un conteneur vertical pour le dossier et ses enfants
            var folder_container = new Box(Orientation.VERTICAL, 2);
            
            // Créer le bouton de dossier avec icône personnalisée
            var folder_button = new Button();
            folder_button.add_css_class("model-folder-button");
            folder_button.add_css_class("flat");
            folder_button.add_css_class(@"folder-depth-$(depth > 4 ? 4 : depth)");
            
            // Contenu du bouton (icône + nom)
            var button_content = new Box(Orientation.HORIZONTAL, 8);
            button_content.set_margin_start(8 + depth * 16);
            button_content.set_margin_end(8);
            button_content.set_margin_top(4);
            button_content.set_margin_bottom(4);
            
            // Icône de dossier (fermé par défaut)
            var folder_icon = new Image.from_icon_name("folder-symbolic");
            folder_icon.set_icon_size(IconSize.NORMAL);
            folder_icon.add_css_class("folder-toggle-icon");
            
            // Label du nom du dossier
            var folder_label = new Label(node.name);
            folder_label.set_xalign(0);
            folder_label.set_hexpand(true);
            folder_label.add_css_class("folder-label");
            
            button_content.append(folder_icon);
            button_content.append(folder_label);
            folder_button.set_child(button_content);

            // Créer le conteneur pour les enfants (initialement caché)
            var children_box = new Box(Orientation.VERTICAL, 2);
            children_box.add_css_class("model-folder-content");
            children_box.set_visible(false); // Fermé par défaut
            
            // Ajouter tous les enfants
            foreach (var child in node.children) {
                var child_widget = create_tree_node_widget(child, depth + 1, popover);
                children_box.append(child_widget);
            }

            // État d'ouverture du dossier
            bool is_expanded = false;
            
            // Connecter le signal de clic pour ouvrir/fermer
            folder_button.clicked.connect(() => {
                is_expanded = !is_expanded;
                children_box.set_visible(is_expanded);
                
                // Changer l'icône selon l'état
                if (is_expanded) {
                    folder_icon.set_from_icon_name("folder-open-symbolic");
                } else {
                    folder_icon.set_from_icon_name("folder-symbolic");
                }
            });
            
            folder_container.append(folder_button);
            folder_container.append(children_box);
            
            return folder_container;
        }

        /**
         * Crée un widget pour un fichier modèle
         */
        private Widget create_model_file_widget(ConfigManager.ModelNode node, int depth, Gtk.Popover popover) {
            var button = new Button();
            button.add_css_class("model-file-button");
            button.add_css_class("flat");
            button.set_margin_start(depth * 16);

            var content_box = new Box(Orientation.HORIZONTAL, 8);
            content_box.set_margin_start(8);
            content_box.set_margin_end(8);
            content_box.set_margin_top(4);
            content_box.set_margin_bottom(4);

            // Icône de sélection (checkmark si sélectionné)
            var check_icon = new Image.from_icon_name("object-select-symbolic");
            check_icon.set_visible(node.full_path == current_model);
            check_icon.add_css_class("model-check");

            // Icône du modèle
            var model_icon = new Image.from_icon_name("applications-science-symbolic");
            model_icon.set_icon_size(IconSize.NORMAL);
            model_icon.add_css_class("model-item-icon");

            // Créer le label avec taille et nom
            string display_text = node.size_str.length > 0 ? @"$(node.size_str) - $(node.name)" : node.name;
            var name_label = new Label(display_text);
            name_label.set_xalign(0);
            name_label.set_hexpand(true);
            name_label.add_css_class("model-item-label");

            content_box.append(check_icon);
            content_box.append(model_icon);
            content_box.append(name_label);
            button.set_child(content_box);

            // Connecter le signal de sélection
            button.clicked.connect(() => {
                select_model(node.full_path);
                popover.popdown();
            });

            return button;
        }

        /**
         * Sélectionne un modèle avec chargement llama.cpp
         */
        private void select_model(string model_path) {
            // Afficher le statut de chargement
            status_label.set_text("Chargement du modèle...");
            status_label.add_css_class("status-loading");
            
            // Extraire le nom du fichier pour l'affichage
            string display_name = Path.get_basename(model_path);
            print("Tentative de sélection du modèle : %s (chemin : %s)\n", display_name, model_path);
            
            // Afficher un toast de chargement
            show_loading_toast(display_name);
            
            // Obtenir l'instance du gestionnaire de modèles
            var model_manager = ModelManager.get_instance();
            
            // Connecter les signaux pour les retours
            model_manager.model_loaded.connect(on_model_loaded);
            model_manager.model_load_failed.connect(on_model_load_failed);
            
            // Charger le modèle de manière asynchrone pour éviter de bloquer l'interface
            Timeout.add(100, () => {
                bool success = model_manager.load_model(model_path);
                
                if (success) {
                    current_model = model_path;
                } else {
                    // L'erreur sera gérée par le signal model_load_failed
                }
                
                return Source.REMOVE;
            });
        }
        
        /**
         * Affiche un toast pendant le chargement
         */
        private void show_loading_toast(string model_name) {
            string toast_message = @"⏳ Chargement de '$model_name'...";
            
            var toast = new Adw.Toast(toast_message);
            toast.set_timeout(3); // 3 secondes
            toast.set_priority(Adw.ToastPriority.NORMAL);
            
            // Afficher le toast
            toast_overlay.add_toast(toast);
            
            print("Toast de chargement affiché : %s\n", toast_message);
        }
        
        /**
         * Gestionnaire appelé quand un modèle est chargé avec succès
         */
        private void on_model_loaded(string model_path, string model_name) {
            var model_manager = ModelManager.get_instance();
            
            // Mettre à jour la barre d'état avec succès
            string status_text;
            if (model_manager.is_in_simulation_mode()) {
                status_text = @"Modèle prêt (simulation) : $model_name";
            } else {
                status_text = @"Modèle prêt : $model_name";
            }
            
            status_label.set_text(status_text);
            status_label.remove_css_class("status-loading");
            status_label.remove_css_class("status-error");
            status_label.add_css_class("status-success");
            
            // Créer et afficher le toast de confirmation
            show_model_ready_toast(model_name, model_manager.is_in_simulation_mode());
            
            if (model_manager.is_in_simulation_mode()) {
                print("Modèle simulé chargé et prêt : %s\n", model_name);
            } else {
                print("Modèle chargé et prêt pour l'inférence : %s\n", model_name);
            }
        }
        
        /**
         * Affiche un toast de confirmation que le modèle est prêt
         */
        private void show_model_ready_toast(string model_name, bool is_simulation) {
            string toast_message;
            string icon_name;
            
            if (is_simulation) {
                toast_message = @"✨ Modèle '$model_name' prêt en mode simulation";
                icon_name = "applications-science-symbolic";
            } else {
                toast_message = @"🚀 Modèle '$model_name' prêt pour l'inférence";
                icon_name = "emblem-ok-symbolic";
            }
            
            // Créer le toast avec l'icône
            var toast = new Adw.Toast(toast_message);
            toast.set_timeout(4); // 4 secondes
            toast.set_priority(Adw.ToastPriority.HIGH);
            
            // Ajouter une action optionnelle "Tester"
            toast.set_button_label("Tester");
            toast.set_action_name("app.test-model");
            
            // Afficher le toast
            toast_overlay.add_toast(toast);
            
            print("Toast affiché : %s\n", toast_message);
        }
         /**
         * Gestionnaire appelé en cas d'échec de chargement
         */
        private void on_model_load_failed(string model_path, string error_message) {
            // Afficher l'erreur dans la barre d'état
            string model_name = Path.get_basename(model_path);
            status_label.set_text(@"Erreur lors du chargement : $model_name");
            status_label.remove_css_class("status-loading");
            status_label.remove_css_class("status-success");
            status_label.add_css_class("status-error");

            // Afficher un toast d'erreur
            show_model_error_toast(model_name, error_message);
            
            // Afficher une dialog d'erreur détaillée après un délai
            Timeout.add(2000, () => {
                show_model_error_dialog(model_name, error_message);
                return Source.REMOVE;
            });
            
            warning("Échec du chargement du modèle %s : %s", model_name, error_message);
        }
        
        /**
         * Affiche un toast d'erreur pour le chargement de modèle
         */
        private void show_model_error_toast(string model_name, string error_message) {
            string toast_message = @"❌ Échec du chargement de '$model_name'";
            
            var toast = new Adw.Toast(toast_message);
            toast.set_timeout(6); // 6 secondes pour les erreurs
            toast.set_priority(Adw.ToastPriority.HIGH);
            
            // Ajouter une action "Détails"
            toast.set_button_label("Détails");
            toast.set_action_name("app.show-error-details");
            
            // Afficher le toast
            toast_overlay.add_toast(toast);
            
            print("Toast d'erreur affiché : %s\n", toast_message);
        }
        
        /**
         * Affiche une dialog d'erreur pour les problèmes de chargement de modèle
         */
        private void show_model_error_dialog(string model_name, string error_message) {
            var dialog = new Gtk.MessageDialog(
                null,
                Gtk.DialogFlags.MODAL,
                Gtk.MessageType.ERROR,
                Gtk.ButtonsType.OK,
                "Erreur de chargement du modèle"
            );
            
            dialog.format_secondary_text(
                @"Le modèle '$model_name' n'a pas pu être chargé.\n\n" +
                @"Détails de l'erreur :\n$error_message\n\n" +
                "Vérifications possibles :\n" +
                "• Le fichier n'est pas corrompu\n" +
                "• Le format est supporté (.gguf, .bin, .safetensors)\n" +
                "• Vous avez suffisamment de mémoire RAM\n" +
                "• Les permissions de lecture sont correctes"
            );
            
            dialog.response.connect(() => {
                dialog.destroy();
            });
            
            dialog.present();
        }

        /**
         * Crée la barre d'état en bas de la zone chat
         */
        private Box create_status_bar() {
            var status_bar = new Box(Orientation.HORIZONTAL, 6);
            status_bar.add_css_class("chat-status-bar");

            // Label pour le statut
            status_label = new Label("Aucun modèle sélectionné");
            status_label.add_css_class("status-label");
            status_label.set_xalign(0);
            status_label.set_hexpand(true);

            status_bar.append(status_label);
            return status_bar;
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

        /**
         * Crée l'interface d'erreur avec messages détaillés et boutons d'action
         */
        private void create_error_interface(Box container, ConfigManager.ModelNode root, Gtk.Popover popover) {
            // Conteneur principal pour l'erreur
            var error_box = new Box(Orientation.VERTICAL, 12);
            error_box.set_margin_start(16);
            error_box.set_margin_end(16);
            error_box.set_margin_top(16);
            error_box.set_margin_bottom(16);
            error_box.add_css_class("model-error-container");

            // Icône d'erreur
            var error_icon = new Image.from_icon_name("dialog-warning-symbolic");
            error_icon.set_icon_size(IconSize.LARGE);
            error_icon.add_css_class("model-error-icon");
            error_box.append(error_icon);

            // Titre de l'erreur
            var error_title = new Label("Problème de configuration des modèles");
            error_title.add_css_class("heading");
            error_title.add_css_class("model-error-title");
            error_title.set_justify(Gtk.Justification.CENTER);
            error_box.append(error_title);

            // Message détaillé selon le type d'erreur
            string action_text = "";
            string button_text = "";
            bool show_config_button = true;

            switch (root.error_message) {
                case "AUCUN_REPERTOIRE_CONFIGURE":
                    action_text = "Vous devez configurer un répertoire où sont stockés vos modèles IA.";
                    button_text = "Configurer le répertoire";
                    break;
                case "REPERTOIRE_INEXISTANT":
                    action_text = "Le répertoire configuré pour les modèles n'existe pas sur votre système.";
                    button_text = "Changer le répertoire";
                    break;
                case "PAS_UN_DOSSIER":
                    action_text = "Le chemin configuré n'est pas un dossier valide.";
                    button_text = "Corriger la configuration";
                    break;
                case "ERREUR_SCAN":
                    action_text = "Une erreur s'est produite lors de la lecture du répertoire des modèles.";
                    button_text = "Vérifier les permissions";
                    break;
                case "AUCUN_MODELE_TROUVE":
                    action_text = "Le répertoire configuré ne contient aucun modèle compatible.";
                    button_text = "Changer le répertoire";
                    show_config_button = true;
                    break;
                default:
                    action_text = "Une erreur inconnue s'est produite.";
                    button_text = "Configurer";
                    break;
            }

            // Message d'action
            var action_label = new Label(action_text);
            action_label.set_wrap(true);
            action_label.set_wrap_mode(Pango.WrapMode.WORD_CHAR);
            action_label.set_justify(Gtk.Justification.CENTER);
            action_label.add_css_class("model-error-action");
            error_box.append(action_label);

            // Détails de l'erreur
            if (root.error_details != "") {
                var details_label = new Label(root.error_details);
                details_label.set_wrap(true);
                details_label.set_wrap_mode(Pango.WrapMode.WORD_CHAR);
                details_label.set_justify(Gtk.Justification.CENTER);
                details_label.add_css_class("model-error-details");
                details_label.set_selectable(true); // Permet de copier le chemin
                error_box.append(details_label);
            }

            // Boutons d'action
            var button_box = new Box(Orientation.HORIZONTAL, 8);
            button_box.set_halign(Gtk.Align.CENTER);
            button_box.set_margin_top(8);

            if (show_config_button) {
                // Bouton principal d'action
                var config_button = new Button.with_label(button_text);
                config_button.add_css_class("suggested-action");
                config_button.add_css_class("model-error-button");
                config_button.clicked.connect(() => {
                    open_model_configuration();
                    popover.popdown();
                });
                button_box.append(config_button);
            }

            // Bouton pour utiliser les modèles par défaut
            if (root.error_message == "AUCUN_MODELE_TROUVE" || root.error_message == "AUCUN_REPERTOIRE_CONFIGURE") {
                var default_button = new Button.with_label("Utiliser les modèles par défaut");
                default_button.add_css_class("model-error-button");
                default_button.clicked.connect(() => {
                    use_default_models(popover);
                });
                button_box.append(default_button);
            }

            // Bouton Annuler
            var cancel_button = new Button.with_label("Annuler");
            cancel_button.add_css_class("model-error-button");
            cancel_button.clicked.connect(() => {
                popover.popdown();
            });
            button_box.append(cancel_button);

            error_box.append(button_box);
            container.append(error_box);
        }

        /**
         * Ouvre la configuration des modèles (temporaire - affiche un message)
         */
        private void open_model_configuration() {
            // TODO: Implémenter l'ouverture des préférences/configuration
            print("TODO: Ouvrir la configuration des modèles\n");
            
            // Pour l'instant, afficher un message informatif
            var dialog = new Gtk.MessageDialog(
                null,
                Gtk.DialogFlags.MODAL,
                Gtk.MessageType.INFO,
                Gtk.ButtonsType.OK,
                "Configuration des modèles"
            );
            dialog.format_secondary_text(
                "Pour configurer un répertoire de modèles :\n\n" +
                "1. Créez un dossier pour vos modèles IA\n" +
                "2. Téléchargez des modèles (.gguf, .bin, .safetensors)\n" +
                "3. Configurez le chemin dans les paramètres de l'application\n\n" +
                "Exemple de répertoire :\n" +
                "~/Documents/ModelsIA/\n" +
                "  ├── llama/\n" +
                "  │   └── llama-2-7b.gguf\n" +
                "  └── mistral/\n" +
                "      └── mistral-7b.gguf"
            );
            
            dialog.response.connect(() => {
                dialog.destroy();
            });
            
            dialog.present();
        }

        /**
         * Utilise les modèles par défaut (simulés)
         */
        private void use_default_models(Gtk.Popover popover) {
            // Pour l'instant, sélectionner un modèle par défaut simulé
            select_model("GPT-4 (par défaut)");
            popover.popdown();
            
            print("Utilisation des modèles par défaut\n");
        }
    }
}
