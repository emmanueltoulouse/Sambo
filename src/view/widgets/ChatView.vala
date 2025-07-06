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
        private Button sampling_params_button;
        private Label model_label;
        private Label status_label;
        private Adw.ToastOverlay toast_overlay;
        private string current_model = "";
        private bool is_processing = false;

        // Paramètres de sampling actuels
        private Llama.SamplingParams current_sampling_params;

        // Message en cours de génération pour le streaming
        private ChatMessage? current_ai_message = null;
        private ChatBubbleRow? current_ai_bubble = null;

        /**
         * Crée une nouvelle vue de chat
         */
        public ChatView(ApplicationController controller) {
            Object(orientation: Orientation.VERTICAL, spacing: 6);
            this.controller = controller;

            // Initialiser les paramètres de sampling par défaut
            init_default_sampling_params();

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

            // Bouton de paramètres de sampling
            sampling_params_button = new Button();
            sampling_params_button.add_css_class("sampling-params-button");
            sampling_params_button.add_css_class("flat");

            // Créer un conteneur pour l'icône et le texte du bouton de paramètres
            var params_button_content = new Box(Orientation.HORIZONTAL, 6);

            // Icône des paramètres (utilise l'icône de réglages)
            var params_icon = new Image.from_icon_name("preferences-system-symbolic");
            params_icon.set_icon_size(IconSize.NORMAL);
            params_icon.add_css_class("params-icon");

            // Label pour les paramètres
            var params_label = new Label("Paramètres");
            params_label.add_css_class("params-label");

            params_button_content.append(params_icon);
            params_button_content.append(params_label);

            sampling_params_button.set_child(params_button_content);
            sampling_params_button.set_tooltip_text("Configurer les paramètres de génération");

            // Connecter le signal
            sampling_params_button.clicked.connect(on_sampling_params_clicked);

            // Ajouter le bouton des paramètres à la toolbar
            toolbar.append(sampling_params_button);

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

            // Créer et ajouter le message de l'utilisateur
            var user_message = new ChatMessage(text, ChatMessage.SenderType.USER);
            add_message(user_message);

            // Effacer le champ de saisie
            message_entry.set_text("");

            // Lancer la génération IA
            generate_ai_response(text);
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

        /**
         * Gestionnaire pour le clic sur le bouton de paramètres de sampling
         */
        private void on_sampling_params_clicked() {
            show_sampling_params_dialog();
        }

        /**
         * Affiche la fenêtre de dialogue des paramètres de sampling
         */
        private void show_sampling_params_dialog() {
            // Obtenir la fenêtre parent
            var parent_window = this.get_root() as Gtk.Window;

            // Créer la fenêtre de dialogue
            var dialog = new Adw.Window();
            dialog.set_title("Paramètres de génération");
            dialog.set_default_size(400, 500);
            dialog.set_modal(true);
            dialog.set_transient_for(parent_window);

            // Créer la boîte principale qui contient tout
            var main_box = new Box(Orientation.VERTICAL, 0);

            // Créer la barre d'en-tête
            var header_bar = new Adw.HeaderBar();
            header_bar.set_title_widget(new Gtk.Label("Paramètres de génération"));

            // Bouton de fermeture
            var close_button = new Button.with_label("Fermer");
            close_button.add_css_class("suggested-action");
            close_button.clicked.connect(() => {
                dialog.close();
            });
            header_bar.pack_end(close_button);

            // Bouton de réinitialisation
            var reset_button = new Button.with_label("Réinitialiser");
            reset_button.clicked.connect(() => {
                reset_sampling_params();
            });
            header_bar.pack_start(reset_button);

            main_box.append(header_bar);

            // Créer le contenu principal
            var content_box = new Box(Orientation.VERTICAL, 0);
            content_box.set_margin_start(24);
            content_box.set_margin_end(24);
            content_box.set_margin_top(24);
            content_box.set_margin_bottom(24);

            // Créer les groupes de paramètres
            var sampling_group = create_sampling_group();
            var generation_group = create_generation_group();
            var advanced_group = create_advanced_group();

            content_box.append(sampling_group);
            content_box.append(generation_group);
            content_box.append(advanced_group);

            // Créer une zone de défilement pour le contenu
            var scroll_view = new ScrolledWindow();
            scroll_view.set_policy(PolicyType.NEVER, PolicyType.AUTOMATIC);
            scroll_view.set_child(content_box);
            scroll_view.set_vexpand(true);

            main_box.append(scroll_view);

            dialog.set_content(main_box);
            dialog.present();
        }

        /**
         * Crée le groupe de paramètres de sampling
         */
        private Adw.PreferencesGroup create_sampling_group() {
            var group = new Adw.PreferencesGroup();
            group.set_title("Paramètres de sampling");
            group.set_description("Contrôlez la créativité et la randomness de la génération");

            // Température (0.0 - 2.0)
            var temp_row = new Adw.SpinRow.with_range(0.0, 2.0, 0.1);
            temp_row.set_title("Température");
            temp_row.set_subtitle("Contrôle la créativité (0.1 = déterministe, 1.0 = équilibré, 2.0 = très créatif)");
            temp_row.set_value(0.7);
            group.add(temp_row);

            // Top-P (0.0 - 1.0)
            var top_p_row = new Adw.SpinRow.with_range(0.0, 1.0, 0.05);
            top_p_row.set_title("Top-P (nucleus sampling)");
            top_p_row.set_subtitle("Limite les tokens à considérer selon leur probabilité cumulative");
            top_p_row.set_value(0.9);
            group.add(top_p_row);

            // Top-K (1 - 100)
            var top_k_row = new Adw.SpinRow.with_range(1, 100, 1);
            top_k_row.set_title("Top-K");
            top_k_row.set_subtitle("Nombre maximum de tokens à considérer");
            top_k_row.set_value(40);
            group.add(top_k_row);

            return group;
        }

        /**
         * Crée le groupe de paramètres de génération
         */
        private Adw.PreferencesGroup create_generation_group() {
            var group = new Adw.PreferencesGroup();
            group.set_title("Paramètres de génération");
            group.set_description("Contrôlez la longueur et la structure des réponses");

            // Max tokens (1 - 4096)
            var max_tokens_row = new Adw.SpinRow.with_range(1, 4096, 1);
            max_tokens_row.set_title("Tokens maximum");
            max_tokens_row.set_subtitle("Longueur maximale de la réponse générée");
            max_tokens_row.set_value(512);
            group.add(max_tokens_row);

            // Repetition penalty (0.0 - 2.0)
            var rep_penalty_row = new Adw.SpinRow.with_range(0.0, 2.0, 0.05);
            rep_penalty_row.set_title("Pénalité de répétition");
            rep_penalty_row.set_subtitle("Évite les répétitions (1.0 = aucune pénalité, 1.1 = recommandé)");
            rep_penalty_row.set_value(1.1);
            group.add(rep_penalty_row);

            // Frequency penalty (-2.0 - 2.0)
            var freq_penalty_row = new Adw.SpinRow.with_range(-2.0, 2.0, 0.1);
            freq_penalty_row.set_title("Pénalité de fréquence");
            freq_penalty_row.set_subtitle("Réduit la probabilité des tokens fréquents");
            freq_penalty_row.set_value(0.0);
            group.add(freq_penalty_row);

            // Presence penalty (-2.0 - 2.0)
            var presence_penalty_row = new Adw.SpinRow.with_range(-2.0, 2.0, 0.1);
            presence_penalty_row.set_title("Pénalité de présence");
            presence_penalty_row.set_subtitle("Encourage l'utilisation de nouveaux concepts");
            presence_penalty_row.set_value(0.0);
            group.add(presence_penalty_row);

            return group;
        }

        /**
         * Crée le groupe de paramètres avancés
         */
        private Adw.PreferencesGroup create_advanced_group() {
            var group = new Adw.PreferencesGroup();
            group.set_title("Paramètres avancés");
            group.set_description("Options pour utilisateurs expérimentés");

            // Seed (-1 pour aléatoire, ou valeur fixe)
            var seed_row = new Adw.SpinRow.with_range(-1, 999999999, 1);
            seed_row.set_title("Seed aléatoire");
            seed_row.set_subtitle("Graine pour la génération (-1 = aléatoire)");
            seed_row.set_value(-1);
            group.add(seed_row);

            // Context length (512 - 8192)
            var context_row = new Adw.SpinRow.with_range(512, 8192, 128);
            context_row.set_title("Longueur du contexte");
            context_row.set_subtitle("Taille de la fenêtre de contexte du modèle");
            context_row.set_value(2048);
            group.add(context_row);

            // Switch pour streaming
            var streaming_row = new Adw.SwitchRow();
            streaming_row.set_title("Streaming");
            streaming_row.set_subtitle("Afficher la réponse en temps réel pendant la génération");
            streaming_row.set_active(true);
            group.add(streaming_row);

            return group;
        }

        /**
         * Réinitialise tous les paramètres de sampling aux valeurs par défaut
         */
        private void reset_sampling_params() {
            init_default_sampling_params();

            var toast = new Adw.Toast("Paramètres réinitialisés aux valeurs par défaut");
            toast.set_timeout(2);
            toast_overlay.add_toast(toast);
        }

        /**
         * Initialise les paramètres de sampling par défaut
         */
        private void init_default_sampling_params() {
            current_sampling_params = Llama.SamplingParams() {
                temperature = 0.7f,
                top_p = 0.9f,
                top_k = 40,
                max_tokens = 512,
                repetition_penalty = 1.1f,
                frequency_penalty = 0.0f,
                presence_penalty = 0.0f,
                seed = -1,
                context_length = 2048,
                stream = true
            };
        }

        /**
         * Met à jour les paramètres de sampling depuis la fenêtre de dialogue
         */
        private void update_sampling_params_from_dialog(
            Adw.SpinRow temp_row,
            Adw.SpinRow top_p_row,
            Adw.SpinRow top_k_row,
            Adw.SpinRow max_tokens_row,
            Adw.SpinRow rep_penalty_row,
            Adw.SpinRow freq_penalty_row,
            Adw.SpinRow presence_penalty_row,
            Adw.SpinRow seed_row,
            Adw.SpinRow context_row,
            Adw.SwitchRow streaming_row
        ) {
            current_sampling_params.temperature = (float)temp_row.get_value();
            current_sampling_params.top_p = (float)top_p_row.get_value();
            current_sampling_params.top_k = (int)top_k_row.get_value();
            current_sampling_params.max_tokens = (int)max_tokens_row.get_value();
            current_sampling_params.repetition_penalty = (float)rep_penalty_row.get_value();
            current_sampling_params.frequency_penalty = (float)freq_penalty_row.get_value();
            current_sampling_params.presence_penalty = (float)presence_penalty_row.get_value();
            current_sampling_params.seed = (int)seed_row.get_value();
            current_sampling_params.context_length = (int)context_row.get_value();
            current_sampling_params.stream = streaming_row.get_active();
        }

        /**
         * Callback pour le streaming de tokens depuis llama.cpp
         */
        private static void on_token_received(string token, void* user_data) {
            // En Vala, on ne peut pas directement utiliser void* vers une instance
            // On va utiliser un signal global à la place
        }

        /**
         * Signal pour la réception de tokens
         */
        public signal void token_received(string token);

        /**
         * Callback statique pour le wrapper C
         */
        private static void static_token_callback(string token, void* user_data, void* closure_data) {
            // Récupérer l'instance depuis l'adresse
            unowned ChatView chat_view = (ChatView) user_data;

            // Émettre le signal dans le thread principal
            Idle.add(() => {
                chat_view.token_received(token);
                return Source.REMOVE;
            });
        }

        /**
         * Ajoute un token au message AI en cours
         */
        private void append_token_to_current_message(string token) {
            if (current_ai_message != null && current_ai_bubble != null) {
                current_ai_message.append_text(token);
                current_ai_bubble.update_content();

                // Défiler vers le bas
                Timeout.add(10, () => {
                    var vadj = scroll.get_vadjustment();
                    if (vadj != null) {
                        vadj.set_value(vadj.get_upper());
                    }
                    return false;
                });
            }
        }        /**
         * Génère une réponse IA avec les paramètres actuels
         */
        private void generate_ai_response(string user_prompt) {
            if (is_processing) {
                return;
            }

            is_processing = true;

            // Vérifier qu'un modèle est chargé
            var model_manager = ModelManager.get_instance();
            if (!model_manager.is_model_ready()) {
                show_error_toast("Aucun modèle chargé", "Veuillez d'abord sélectionner un modèle IA");
                is_processing = false;
                return;
            }

            // Créer un message IA vide pour le streaming
            current_ai_message = new ChatMessage("", ChatMessage.SenderType.AI);
            current_ai_bubble = new ChatBubbleRow(current_ai_message);
            message_container.append(current_ai_bubble);

            // Connecter le signal de token reçu
            this.token_received.connect(append_token_to_current_message);

            // Défiler vers le bas
            Timeout.add(50, () => {
                var vadj = scroll.get_vadjustment();
                if (vadj != null) {
                    vadj.set_value(vadj.get_upper());
                }
                return false;
            });

            // Lancer la génération dans un thread séparé
            Thread.create<void*>(() => {
                bool success = Llama.generate(
                    user_prompt,
                    &current_sampling_params,
                    static_token_callback,
                    this
                );

                // Signaler la fin de génération dans le thread principal
                Idle.add(() => {
                    on_generation_completed(success);
                    return Source.REMOVE;
                });

                return null;
            }, false);
        }        /**
         * Appelé à la fin de la génération
         */
        private void on_generation_completed(bool success) {
            is_processing = false;

            // Déconnecter le signal
            this.token_received.disconnect(append_token_to_current_message);

            current_ai_message = null;
            current_ai_bubble = null;

            if (!success) {
                show_error_toast("Erreur de génération", "La génération a échoué");
            }
        }

        /**
         * Affiche un toast d'erreur
         */
        private void show_error_toast(string title, string message) {
            var toast = new Adw.Toast(@"$title : $message");
            toast.set_timeout(5);
            toast_overlay.add_toast(toast);
        }
    }
}
