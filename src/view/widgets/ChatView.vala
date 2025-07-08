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
        private Button profile_selector_button;
        private Button profile_manager_button;
        private Button cancel_generation_button;
        private Label profile_label;
        private Label status_label;
        private Adw.ToastOverlay toast_overlay;
        private Gtk.ProgressBar progress_bar; // Indicateur de progression
        private bool is_processing = false;

        // Profil d'inférence actuel
        private InferenceProfile? current_profile = null;

        // Message en cours de génération pour le streaming
        private ChatMessage? current_ai_message = null;
        private ChatBubbleRow? current_ai_bubble = null;

        /**
         * Crée une nouvelle vue de chat
         */
        public ChatView(ApplicationController controller) {
            Object(orientation: Orientation.VERTICAL, spacing: 6);
            this.controller = controller;

            // Charger le profil sélectionné
            load_current_profile();

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

            // Connecter aux signaux de configuration
            var config = controller.get_config_manager();
            config.profiles_changed.connect(on_profiles_changed);

            // Message de bienvenue
            var welcome = new ChatMessage("Bonjour ! Comment puis-je vous aider aujourd'hui ?", ChatMessage.SenderType.AI);
            add_message(welcome);
        }

        /**
         * Charge le profil actuellement sélectionné
         */
        private void load_current_profile() {
            var config = controller.get_config_manager();
            current_profile = config.get_selected_profile();
            update_profile_display();
        }

        /**
         * Met à jour l'affichage du profil
         */
        private void update_profile_display() {
            if (current_profile != null) {
                profile_label.set_text(current_profile.title);
                status_label.set_text("Profil : " + current_profile.title);
            } else {
                profile_label.set_text("Aucun profil");
                status_label.set_text("Aucun profil d'inférence sélectionné");
            }
        }

        /**
         * Callback pour les changements de profils
         */
        private void on_profiles_changed() {
            load_current_profile();
        }

        /**
         * Crée la barre d'outils spécifique au chat
         */
        private void create_chat_toolbar() {
            var toolbar = new Box(Orientation.HORIZONTAL, 6);
            toolbar.add_css_class("chat-toolbar");

            // Bouton de sélection de profil
            profile_selector_button = new Button();
            profile_selector_button.add_css_class("profile-selector-button");
            profile_selector_button.add_css_class("flat");

            // Créer un conteneur pour l'icône et le texte
            var button_content = new Box(Orientation.HORIZONTAL, 6);

            // Icône du profil
            var profile_icon = new Image.from_icon_name("user-info-symbolic");
            profile_icon.set_icon_size(IconSize.NORMAL);
            profile_icon.add_css_class("profile-icon");

            // Label pour le profil actuel
            profile_label = new Label("Aucun profil");
            profile_label.add_css_class("profile-label");

            // Icône de dropdown
            var dropdown_icon = new Image.from_icon_name("pan-down-symbolic");
            dropdown_icon.set_icon_size(IconSize.NORMAL);
            dropdown_icon.add_css_class("dropdown-icon");

            button_content.append(profile_icon);
            button_content.append(profile_label);
            button_content.append(dropdown_icon);

            profile_selector_button.set_child(button_content);
            profile_selector_button.set_tooltip_text("Sélectionner un profil d'inférence");

            // Connecter le signal
            profile_selector_button.clicked.connect(on_profile_selector_clicked);

            // Ajouter le bouton à la toolbar
            toolbar.append(profile_selector_button);

            // Bouton de gestion des profils
            profile_manager_button = new Button();
            profile_manager_button.add_css_class("profile-manager-button");
            profile_manager_button.add_css_class("flat");

            // Créer un conteneur pour l'icône et le texte du bouton de gestion
            var manager_button_content = new Box(Orientation.HORIZONTAL, 6);

            // Icône de gestion
            var manager_icon = new Image.from_icon_name("preferences-system-symbolic");
            manager_icon.set_icon_size(IconSize.NORMAL);
            manager_icon.add_css_class("manager-icon");

            // Label pour la gestion
            var manager_label = new Label("Gérer les profils");
            manager_label.add_css_class("manager-label");

            manager_button_content.append(manager_icon);
            manager_button_content.append(manager_label);

            profile_manager_button.set_child(manager_button_content);
            profile_manager_button.set_tooltip_text("Gérer les profils d'inférence");

            // Connecter le signal
            profile_manager_button.clicked.connect(on_profile_manager_clicked);

            // Ajouter le bouton de gestion à la toolbar
            toolbar.append(profile_manager_button);

            // Spacer pour pousser les éléments vers la droite si nécessaire
            var spacer = new Box(Orientation.HORIZONTAL, 0);
            spacer.set_hexpand(true);
            toolbar.append(spacer);

            // Bouton d'annulation de génération
            cancel_generation_button = new Button();
            cancel_generation_button.add_css_class("cancel-generation-button");
            cancel_generation_button.add_css_class("destructive-action");
            cancel_generation_button.set_icon_name("process-stop-symbolic");
            cancel_generation_button.set_tooltip_text("Arrêter la génération en cours");
            cancel_generation_button.set_visible(false); // Masqué par défaut
            cancel_generation_button.clicked.connect(on_cancel_generation_clicked);
            toolbar.append(cancel_generation_button);

            // Ajouter la toolbar à la vue principale
            this.append(toolbar);
        }

        /**
         * Gestionnaire pour le clic sur le sélecteur de profil
         */
        private void on_profile_selector_clicked() {
            show_profile_selection_popover();
        }

        /**
         * Gestionnaire pour le clic sur le gestionnaire de profils
         */
        private void on_profile_manager_clicked() {
            var manager = new ProfileManager(controller);
            manager.profile_selected.connect((profile_id) => {
                load_current_profile();
                manager.close();
            });
            manager.present();
        }

        /**
         * Affiche le popover de sélection des profils
         */
        private void show_profile_selection_popover() {
            var popover = new Gtk.Popover();
            popover.set_parent(profile_selector_button);
            popover.set_position(Gtk.PositionType.BOTTOM);

            // Obtenir la liste des profils
            var config = controller.get_config_manager();
            var profiles = config.get_all_profiles();

            // Créer le conteneur principal
            var main_box = new Box(Orientation.VERTICAL, 6);
            main_box.set_margin_start(12);
            main_box.set_margin_end(12);
            main_box.set_margin_top(12);
            main_box.set_margin_bottom(12);

            // Titre du popover
            var title_label = new Label("Sélection du profil d'inférence");
            title_label.add_css_class("heading");
            title_label.set_margin_bottom(12);
            main_box.append(title_label);

            // Créer la liste des profils
            var profiles_box = new Box(Orientation.VERTICAL, 3);
            profiles_box.add_css_class("profiles-list");

            if (profiles.size == 0) {
                // Aucun profil disponible
                var no_profile_label = new Label("Aucun profil disponible");
                no_profile_label.add_css_class("dim-label");
                no_profile_label.set_margin_top(20);
                no_profile_label.set_margin_bottom(20);
                profiles_box.append(no_profile_label);

                // Bouton pour créer un profil
                var create_button = new Button.with_label("Créer un profil");
                create_button.add_css_class("suggested-action");
                create_button.clicked.connect(() => {
                    popover.popdown();
                    on_profile_manager_clicked();
                });
                profiles_box.append(create_button);
            } else {
                // Ajouter les profils existants
                foreach (var profile in profiles) {
                    var profile_button = create_profile_button(profile, popover);
                    profiles_box.append(profile_button);
                }

                // Séparateur
                var separator = new Separator(Orientation.HORIZONTAL);
                separator.set_margin_top(6);
                separator.set_margin_bottom(6);
                profiles_box.append(separator);

                // Bouton pour gérer les profils
                var manage_button = new Button.with_label("Gérer les profils...");
                manage_button.add_css_class("flat");
                manage_button.clicked.connect(() => {
                    popover.popdown();
                    on_profile_manager_clicked();
                });
                profiles_box.append(manage_button);
            }

            main_box.append(profiles_box);

            var scrolled = new ScrolledWindow();
            scrolled.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);
            scrolled.set_max_content_height(400);
            scrolled.set_min_content_width(300);
            scrolled.set_child(main_box);

            popover.set_child(scrolled);
            popover.popup();
        }

        /**
         * Crée un bouton pour un profil dans le popover
         */
        private Widget create_profile_button(InferenceProfile profile, Gtk.Popover popover) {
            var button = new Button();
            button.add_css_class("profile-item-button");
            button.add_css_class("flat");

            // Contenu du bouton
            var button_content = new Box(Orientation.HORIZONTAL, 8);
            button_content.set_margin_start(8);
            button_content.set_margin_end(8);
            button_content.set_margin_top(6);
            button_content.set_margin_bottom(6);

            // Icône de statut
            var status_icon = new Image();
            if (current_profile != null && current_profile.id == profile.id) {
                status_icon.set_from_icon_name("emblem-ok-symbolic");
                status_icon.add_css_class("success");
            } else {
                status_icon.set_from_icon_name("user-info-symbolic");
            }
            status_icon.set_icon_size(IconSize.NORMAL);

            // Informations du profil
            var info_box = new Box(Orientation.VERTICAL, 2);
            info_box.set_hexpand(true);

            var title_label = new Label(profile.title);
            title_label.add_css_class("profile-title");
            title_label.set_xalign(0);
            info_box.append(title_label);

            if (profile.comment != "") {
                var comment_label = new Label(profile.comment);
                comment_label.add_css_class("caption");
                comment_label.add_css_class("dim-label");
                comment_label.set_xalign(0);
                info_box.append(comment_label);
            }

            button_content.append(status_icon);
            button_content.append(info_box);

            button.set_child(button_content);

            // Connecter le signal de clic
            button.clicked.connect(() => {
                var config = controller.get_config_manager();
                config.select_profile(profile.id);
                popover.popdown();
                show_toast("Profil sélectionné : " + profile.title);
            });

            return button;
        }

        /**
         * Gestionnaire pour l'envoi d'un message
         */
        private void on_send_message() {
            if (is_processing)
                return;

            // Vérifier qu'un profil est sélectionné
            if (current_profile == null) {
                show_toast("Veuillez sélectionner un profil d'inférence avant d'envoyer un message");
                return;
            }

            // Valider le profil
            if (!current_profile.is_valid()) {
                var errors = current_profile.get_validation_errors();
                var error_message = "Profil invalide :\n" + string.joinv("\n", errors);
                show_toast(error_message);
                return;
            }

            string text = message_entry.get_text();
            if (text == "")
                return;

            // Créer et ajouter le message de l'utilisateur
            var user_message = new ChatMessage(text, ChatMessage.SenderType.USER);
            add_message(user_message);

            // Effacer le champ de saisie
            message_entry.set_text("");

            // Lancer la génération IA avec le profil sélectionné
            generate_ai_response_with_profile(text);
        }

        /**
         * Génère une réponse IA en utilisant le profil actuel
         */
        private void generate_ai_response_with_profile(string user_message) {
            if (current_profile == null) {
                show_toast("Aucun profil sélectionné");
                return;
            }

            is_processing = true;
            status_label.set_text("Génération en cours...");

            // Afficher les indicateurs de progression et le bouton d'annulation
            progress_bar.set_visible(true);
            progress_bar.pulse(); // Animation de progression indéterminée
            cancel_generation_button.set_visible(true);
            send_button.set_sensitive(false);
            message_entry.set_sensitive(false);

            // Démarrer l'animation de progression
            var progress_timeout = Timeout.add(100, () => {
                if (is_processing) {
                    progress_bar.pulse();
                    return true; // Continuer l'animation
                }
                return false; // Arrêter l'animation
            });

            // Créer le message IA (vide pour le moment)
            current_ai_message = new ChatMessage("", ChatMessage.SenderType.AI);
            current_ai_bubble = new ChatBubbleRow(current_ai_message);
            message_container.append(current_ai_bubble);

            // Faire défiler vers le bas
            scroll_to_bottom();

            // Créer les paramètres de sampling depuis le profil
            var sampling_params = create_sampling_params_from_profile(current_profile);

            // Préparer le contexte complet avec le prompt système
            string full_context = prepare_context_with_profile(user_message);

            // Générer la réponse avec le vrai moteur d'IA
            generate_real_ai_response(full_context, sampling_params);
        }

        /**
         * Crée les paramètres de sampling depuis le profil
         */
        private Llama.SamplingParams create_sampling_params_from_profile(InferenceProfile profile) {
            return Llama.SamplingParams() {
                temperature = profile.temperature,
                top_p = profile.top_p,
                top_k = profile.top_k,
                max_tokens = profile.max_tokens,
                repetition_penalty = profile.repetition_penalty,
                frequency_penalty = profile.frequency_penalty,
                presence_penalty = profile.presence_penalty,
                seed = profile.seed,
                context_length = profile.context_length,
                stream = profile.stream
            };
        }

        /**
         * Prépare le contexte complet avec le prompt système du profil
         */
        private string prepare_context_with_profile(string user_message) {
            var context = new StringBuilder();

            // Ajouter le prompt système du profil
            context.append("### Instructions système\n");
            context.append(current_profile.prompt);
            context.append("\n\n### Assistant\n");
            context.append("Bonjour ! Je suis prêt à vous aider.\n\n");
            context.append("### Utilisateur\n");
            context.append(user_message);
            context.append("\n\n### Assistant\n");

            return context.str;
        }

        /**
         * Génère une réponse IA réelle en utilisant le moteur d'IA
         */
        private void generate_real_ai_response(string context, Llama.SamplingParams params) {
            // Vérifier qu'un modèle est chargé
            var model_manager = controller.get_model_manager();
            if (!model_manager.is_model_ready()) {
                // Tenter de charger le modèle du profil
                if (current_profile.model_path != "" && FileUtils.test(current_profile.model_path, FileTest.EXISTS)) {
                    if (!model_manager.load_model(current_profile.model_path)) {
                        show_error_response("❌ Impossible de charger le modèle : " + current_profile.model_path);
                        return;
                    }
                } else {
                    show_error_response("❌ Modèle non trouvé : " + current_profile.model_path);
                    return;
                }
            }

            // Générer la réponse avec streaming
            controller.generate_ai_response(context, params, (partial_response, is_finished) => {
                if (current_ai_message != null && current_ai_bubble != null) {
                    current_ai_message.content = partial_response;
                    current_ai_bubble.update_content();
                    scroll_to_bottom();

                    if (is_finished) {
                        is_processing = false;
                        status_label.set_text("Profil : " + current_profile.title);
                        current_ai_message = null;
                        current_ai_bubble = null;

                        // Masquer les indicateurs de progression et réactiver l'envoi
                        progress_bar.set_visible(false);
                        cancel_generation_button.set_visible(false);
                        send_button.set_sensitive(true);
                        message_entry.set_sensitive(true);
                    }
                }
            });
        }

        /**
         * Affiche un message d'erreur dans le chat
         */
        private void show_error_response(string error_message) {
            if (current_ai_message != null && current_ai_bubble != null) {
                current_ai_message.content = error_message;
                current_ai_bubble.update_content();
                scroll_to_bottom();
            }

            is_processing = false;
            status_label.set_text("❌ Erreur");
            current_ai_message = null;
            current_ai_bubble = null;

            // Masquer les indicateurs de progression et réactiver l'envoi
            progress_bar.set_visible(false);
            cancel_generation_button.set_visible(false);
            send_button.set_sensitive(true);
            message_entry.set_sensitive(true);

            show_toast(error_message);
        }

        /**
         * Fait défiler vers le bas de la conversation
         */
        private void scroll_to_bottom() {
            var vadj = scroll.get_vadjustment();
            vadj.set_value(vadj.get_upper() - vadj.get_page_size());
        }

        /**
         * Affiche un toast de notification
         */
        private void show_toast(string message) {
            var toast = new Adw.Toast(message);
            toast.set_timeout(4);
            toast_overlay.add_toast(toast);
        }

        /**
         * Crée la barre d'état en bas de la zone chat
         */
        private Box create_status_bar() {
            var status_bar = new Box(Orientation.HORIZONTAL, 6);
            status_bar.add_css_class("chat-status-bar");

            // Label pour le statut
            status_label = new Label("Aucun profil sélectionné");
            status_label.add_css_class("status-label");
            status_label.set_xalign(0);
            status_label.set_hexpand(true);

            status_bar.append(status_label);

            // Barre de progression (masquée par défaut)
            progress_bar = new Gtk.ProgressBar();
            progress_bar.add_css_class("generation-progress");
            progress_bar.set_text("Génération en cours...");
            progress_bar.set_show_text(true);
            progress_bar.set_visible(false);
            progress_bar.set_size_request(200, -1);

            status_bar.append(progress_bar);

            return status_bar;
        }

        /**
         * Ajoute un nouveau message à la conversation
         */
        public void add_message(ChatMessage message) {
            // Vérification de sécurité
            if (message == null) {
                warning("Tentative d'ajout d'un message null");
                return;
            }

            // Créer et ajouter la bulle de message
            var bubble = new ChatBubbleRow(message);
            message_container.append(bubble);

            // Faire défiler vers le bas
            Idle.add(() => {
                scroll_to_bottom();
                return Source.REMOVE;
            });
        }

        /**
         * Rafraîchit la sélection de profil depuis la configuration
         */
        public void refresh_profile_selection() {
            load_current_profile();

            // Si un profil est maintenant chargé, préparer le modèle
            if (current_profile != null) {
                prepare_model_for_profile();
            }
        }

        /**
         * Prépare le modèle IA pour le profil actuel
         */
        private void prepare_model_for_profile() {
            if (current_profile == null || current_profile.model_path == "") {
                return;
            }

            var model_manager = controller.get_model_manager();

            // Vérifier si le modèle du profil est déjà chargé
            if (!model_manager.is_model_ready() ||
                model_manager.get_current_model_name() != Path.get_basename(current_profile.model_path)) {

                // Charger le modèle du profil si nécessaire
                if (FileUtils.test(current_profile.model_path, FileTest.EXISTS)) {
                    model_manager.load_model(current_profile.model_path);
                } else {
                    // Modèle introuvable, mais ne pas afficher de message de debug
                }
            }
        }

        /**
         * Gestionnaire du bouton d'annulation de génération
         */
        private void on_cancel_generation_clicked() {
            var model_manager = controller.get_model_manager();
            model_manager.cancel_generation();

            // Forcer la mise à jour de l'état immédiatement
            force_unlock_ui();

            // Marquer le message AI actuel comme annulé
            if (current_ai_message != null) {
                current_ai_message.content = "⏹️ Génération annulée par l'utilisateur";
                current_ai_message.update_content();
            }

            show_toast("⏹️ Génération annulée");

            // Triple sécurité pour s'assurer que l'interface est débloquée
            Timeout.add(100, () => {
                force_unlock_ui();
                return false;
            });

            Timeout.add(500, () => {
                force_unlock_ui();
                return false;
            });

            Timeout.add(1000, () => {
                force_unlock_ui();
                return false;
            });
        }

        /**
         * Force le débloquage de l'interface utilisateur
         */
        private void force_unlock_ui() {
            is_processing = false;
            status_label.set_text("Prêt");
            progress_bar.set_visible(false);
            cancel_generation_button.set_visible(false);
            send_button.set_sensitive(true);
            message_entry.set_sensitive(true);

            // Nettoyer les références
            current_ai_message = null;
            current_ai_bubble = null;
        }
    }
}
