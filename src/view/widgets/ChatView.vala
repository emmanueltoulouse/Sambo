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
        private bool is_generation_cancelled = false; // Flag pour l'annulation

        // Profil d'inférence actuel
        private InferenceProfile? current_profile = null;

        // Message en cours de génération pour le streaming
        private ChatMessage? current_ai_message = null;
        private ChatBubbleRow? current_ai_bubble = null;

        // Variables pour les statistiques de traitement
        private int64 generation_start_time = 0;
        private int token_count = 0;

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
            message_container.add_css_class("chat-messages-container"); // Debug CSS

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

            // Charger le profil sélectionné (APRÈS avoir créé les widgets)
            load_current_profile();

            // Connecter aux signaux de configuration
            var config = controller.get_config_manager();
            config.profiles_changed.connect(on_profiles_changed);

            // Message de bienvenue
            var welcome = new ChatMessage("Bonjour ! Comment puis-je vous aider aujourd'hui ?", ChatMessage.SenderType.AI);
            add_message(welcome);
        }

        // Modèle actuellement en cours de chargement pour éviter les doublons
        private string? loading_model_path = null;

        /**
         * Charge le profil actuellement sélectionné
         */
        private void load_current_profile() {
            var config = controller.get_config_manager();
            current_profile = config.get_selected_profile();
            update_profile_display();

            // Charger automatiquement le modèle du profil sélectionné
            if (current_profile != null && current_profile.model_path != null && current_profile.model_path != "") {
                var model_manager = controller.get_model_manager();

                // Éviter de recharger le même modèle s'il est déjà chargé ou en cours de chargement
                if (loading_model_path == current_profile.model_path ||
                    (model_manager.is_model_ready() && model_manager.get_current_model_path() == current_profile.model_path)) {
                    stderr.printf("[TRACE] ChatView: Modèle déjà chargé ou en cours de chargement: %s\n", current_profile.model_path);
                    return;
                }

                loading_model_path = current_profile.model_path;
                stderr.printf("[TRACE] ChatView: Chargement automatique du modèle: %s\n", current_profile.model_path);

                // Connecter aux signaux du ModelManager s'ils ne le sont pas déjà
                setup_model_manager_signals(model_manager);

                // Afficher le statut de chargement
                status_label.set_text("Chargement du modèle...");

                // Le résultat du chargement sera géré par les signaux model_loaded/model_load_failed
                model_manager.load_model(current_profile.model_path);
            }
        }

        // Flag pour éviter de connecter plusieurs fois les mêmes signaux
        private bool signals_connected = false;

        /**
         * Configure les signaux du ModelManager
         */
        private void setup_model_manager_signals(ModelManager model_manager) {
            // Éviter de connecter plusieurs fois les mêmes signaux
            if (signals_connected) return;
            signals_connected = true;

            // Signal de succès de chargement
            model_manager.model_loaded.connect((model_path, model_name) => {
                stderr.printf("[TRACE] ChatView: Modèle chargé avec succès: %s\n", model_name);
                loading_model_path = null; // Réinitialiser le flag de chargement
                show_toast(@"✅ Modèle chargé : $(model_name)");
                status_label.set_text(@"Modèle : $(model_name)");
            });

            // Signal d'échec de chargement
            model_manager.model_load_failed.connect((model_path, error_message) => {
                stderr.printf("[ERROR] ChatView: Échec du chargement du modèle: %s\n", error_message);
                loading_model_path = null; // Réinitialiser le flag de chargement
                string model_name = Path.get_basename(model_path);
                show_toast(@"❌ Échec du chargement : $(error_message)");
                // Afficher la raison de l'échec dans la barre d'état
                status_label.set_text(@"❌ Échec : $(error_message)");
            });
        }

        /**
         * Met à jour l'affichage du profil
         */
        private void update_profile_display() {
            // Vérifier que les labels sont créés avant de les mettre à jour
            if (profile_label == null) {
                return;
            }

            if (current_profile != null) {
                profile_label.set_text(current_profile.title);
                // Note: Ne pas modifier status_label ici, il est géré par les signaux de chargement du modèle
            } else {
                profile_label.set_text("Aucun profil");
                // Seulement si aucun profil n'est sélectionné, on peut mettre à jour le statut
                if (status_label != null) {
                    status_label.set_text("Aucun profil d'inférence sélectionné");
                }
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
         * Calcule la hauteur dynamique du popover selon le nombre de profils
         */
        private int calculate_dynamic_height(Gee.Collection<InferenceProfile> profiles) {
            // Hauteur de base pour le titre et les marges
            int base_height = 80; // Titre + marges + bouton gérer

            // Hauteur par profil (raisonnable)
            int item_height = 50; // Espace raisonnable par profil

            // Calculer la hauteur totale selon le nombre de profils
            int total_height = base_height + (profiles.size * item_height);

            // Debug : afficher les valeurs calculées
            stderr.printf("🎯 ChatView: Calcul hauteur VRAIMENT dynamique - Profils: %d, Base: %dpx, Par item: %dpx, Total calculé: %dpx\n",
                profiles.size, base_height, item_height, total_height);

            // Limites raisonnables :
            // - Minimum : 200px pour au moins un profil
            // - Maximum : 600px pour éviter les popover trop grands
            int final_height = int.max(200, int.min(600, total_height));

            stderr.printf("🎯 ChatView: Hauteur FINALE appliquée: %dpx (pour %d profils)\n", final_height, profiles.size);

            return final_height;
        }

        /**
         * Affiche le popover de sélection des profils
         */
        private void show_profile_selection_popover() {
            var popover = new Gtk.Popover();
            popover.set_parent(profile_selector_button);
            popover.set_position(Gtk.PositionType.BOTTOM);

            // Ajouter des classes CSS pour un style amélioré
            popover.add_css_class("profile-selection-popover");

            // Obtenir la liste des profils
            var config = controller.get_config_manager();
            var profiles = config.get_all_profiles();

            // Créer le conteneur principal
            var main_box = new Box(Orientation.VERTICAL, 6);
            main_box.set_margin_start(12);
            main_box.set_margin_end(12);
            main_box.set_margin_top(12);
            main_box.set_margin_bottom(12);

            // Titre du popover (fixe)
            var title_label = new Label("Sélection du profil d'inférence");
            title_label.add_css_class("heading");
            title_label.set_margin_bottom(12);
            main_box.append(title_label);

            // Créer la liste des profils (dans ScrolledWindow)
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
            }

            // ScrolledWindow SEULEMENT pour la liste des profils
            var scrolled = new ScrolledWindow();
            scrolled.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);

            // Calculer la hauteur dynamiquement selon le nombre d'éléments
            int dynamic_height = calculate_dynamic_height(profiles);
            scrolled.set_max_content_height(dynamic_height);
            scrolled.set_min_content_width(300);
            scrolled.set_child(profiles_box);

            main_box.append(scrolled);

            // Boutons de gestion (fixes - en bas)
            if (profiles.size > 0) {
                // Séparateur
                var separator = new Separator(Orientation.HORIZONTAL);
                separator.set_margin_top(6);
                separator.set_margin_bottom(6);
                main_box.append(separator);

                // Bouton pour gérer les profils
                var manage_button = new Button.with_label("Gérer les profils...");
                manage_button.add_css_class("flat");
                manage_button.clicked.connect(() => {
                    popover.popdown();
                    on_profile_manager_clicked();
                });
                main_box.append(manage_button);
            }

            // Laisser GTK gérer la hauteur automatiquement, juste définir la largeur
            popover.set_size_request(320, -1); // -1 = hauteur automatique
            popover.set_child(main_box);
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

            // Réinitialiser le flag d'annulation
            is_generation_cancelled = false;

            is_processing = true;
            status_label.set_text("Génération en cours...");

            // Démarrer le chronomètre dans le CommunicationView
            var parent_widget = this.get_parent();
            while (parent_widget != null && !(parent_widget is CommunicationView)) {
                parent_widget = parent_widget.get_parent();
            }
            if (parent_widget is CommunicationView) {
                ((CommunicationView)parent_widget).start_execution_timer();
            }

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

            // Initialiser les statistiques de traitement
            generation_start_time = get_monotonic_time();
            token_count = 0;

            // Faire défiler vers le bas
            scroll_to_bottom();

            // Créer les paramètres de sampling depuis le profil
            var sampling_params = create_sampling_params_from_profile(current_profile);

            // Préparer le contexte complet avec le prompt système
            string full_context = prepare_context_with_profile(user_message);

            // Générer la réponse avec le vrai moteur d'IA
            stderr.printf("[TRACE][OUT] CHATVIEW: Appel generate_real_ai_response avec callback\n");
            generate_real_ai_response(full_context, sampling_params);
        }

        /**
         * Crée les paramètres de sampling depuis le profil
         */
        private Llama.SamplingParams create_sampling_params_from_profile(InferenceProfile profile) {
            var params = Llama.SamplingParams() {
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

            stderr.printf("[TRACE][OUT] CHATVIEW: Paramètres créés - stream = %s\n",
                params.stream ? "TRUE" : "FALSE");
            stderr.printf("[TRACE][OUT] CHATVIEW: Profil stream = %s\n",
                profile.stream ? "TRUE" : "FALSE");

            return params;
        }

        /**
         * Prépare le contexte complet avec le prompt système du profil
         */
        private string prepare_context_with_profile(string user_message) {
            var context = new StringBuilder();

            // Utiliser le template personnalisé s'il est défini
            if (current_profile.template != null && current_profile.template.strip() != "") {
                // Remplacer les placeholders dans le template
                string template_text = current_profile.template;
                template_text = template_text.replace("{system}", current_profile.prompt);
                template_text = template_text.replace("{user}", user_message);
                template_text = template_text.replace("{assistant}", "");

                context.append(template_text);
            } else {
                // Utiliser le format de chat template par défaut pour Llama 3.2
                context.append("<|begin_of_text|><|start_header_id|>system<|end_header_id|>\n\n");
                context.append(current_profile.prompt);
                context.append("<|eot_id|><|start_header_id|>user<|end_header_id|>\n\n");
                context.append(user_message);
                context.append("<|eot_id|><|start_header_id|>assistant<|end_header_id|>\n\n");
            }

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
                        show_error_response("❌ **_Erreur de chargement de modèle_**\n\n**Cause :** Impossible de charger le modèle `" + current_profile.model_path + "`\n\n**Solution :** Vérifiez que le fichier de modèle est accessible et compatible.");
                        return;
                    }
                } else {
                    show_error_response("❌ **_Modèle introuvable_**\n\n**Cause :** Le fichier de modèle `" + current_profile.model_path + "` n'existe pas ou n'est pas accessible.\n\n**Solution :** Configurez un chemin de modèle valide dans les paramètres du profil.");
                    return;
                }
            }

            // Vérifier si on est en mode simulation (ce qui indique un problème)
            if (model_manager.is_in_simulation_mode()) {
                show_error_response("⚠️ **_Mode simulation détecté_**\n\n**Cause :** Le moteur d'IA ne peut pas fonctionner correctement avec le modèle actuel.\n\n**Solutions possibles :**\n• Vérifiez que le modèle est compatible avec votre système\n• Consultez les logs pour plus de détails\n• Essayez avec un autre modèle");
                return;
            }

            // Variable pour détecter les erreurs d'IA
            bool ai_error_detected = false;
            string ai_error_message = "";

            // Générer la réponse avec streaming
            stderr.printf("[TRACE][OUT] CHATVIEW: Appel controller.generate_ai_response avec callback\n");

            try {
                controller.generate_ai_response(context, params, (partial_response, is_finished) => {
                    stderr.printf("[TRACE][IN] CHATVIEW: Callback reçu - %d caractères, terminé: %s\n",
                        (int)partial_response.length, is_finished ? "OUI" : "NON");

                    // Protection contre les réponses null ou invalides
                    if (partial_response == null) {
                        stderr.printf("[ERROR] CHATVIEW: Réponse null reçue dans le callback\n");
                        partial_response = "";
                    }

                    // Limiter la taille de la trace pour éviter les problèmes de mémoire
                    string trace_content = partial_response.length > 50 ?
                        partial_response.substring(0, 50) + "..." : partial_response;
                    stderr.printf("[TRACE][IN] CHATVIEW: Contenu reçu: '%s'\n", trace_content);

                    // Détecter les réponses d'erreur ou de simulation
                    if (partial_response.contains("Je comprends votre question") ||
                        partial_response.contains("Mode simulation") ||
                        partial_response.contains("Voici une réponse simulée") ||
                        partial_response.contains("simulation") && partial_response.contains("paramètres")) {
                        ai_error_detected = true;
                        ai_error_message = "🤖 **_Réponse générique détectée_**\n\n**Cause :** Le modèle d'IA génère des réponses génériques au lieu de répondre à votre question.\n\n**Solutions possibles :**\n• Reformulez votre question de manière plus spécifique\n• Vérifiez le template de chat dans les paramètres du profil\n• Le modèle pourrait ne pas être adapté à ce type de question";
                    }

                    // Protection critique contre les erreurs de segmentation
                    try {
                        // Vérifier que l'interface n'a pas été détruite et qu'on traite toujours le bon message
                        if (current_ai_message != null && current_ai_bubble != null && !is_generation_cancelled) {
                            stderr.printf("[TRACE][IN] CHATVIEW: Interface disponible, mise à jour...\n");

                            // Vérification supplémentaire des pointeurs
                            if (current_ai_message.is_floating() == false && current_ai_bubble.is_floating() == false) {
                                // Si une erreur a été détectée, afficher le message d'erreur au lieu de la réponse
                                if (ai_error_detected && is_finished) {
                                    current_ai_message.content = ai_error_message;
                                } else if (!ai_error_detected) {
                                    // Mettre à jour le contenu du message seulement si pas d'erreur détectée
                                    current_ai_message.content = partial_response;
                                }

                                stderr.printf("[TRACE][OUT] CHATVIEW: Message mis à jour, appel update_content()\n");

                                // Utiliser une minuterie pour éviter les problèmes de concurrence
                                Idle.add(() => {
                                    if (current_ai_bubble != null && !current_ai_bubble.is_floating()) {
                                        current_ai_bubble.update_content();
                                    }
                                    return Source.REMOVE;
                                });
                            } else {
                                stderr.printf("[WARNING] CHATVIEW: Widgets détachés détectés, annulation de la mise à jour\n");
                            }
                        } else {
                            stderr.printf("[TRACE][IN] CHATVIEW: Interface non disponible ou génération annulée\n");
                        }
                    } catch (Error update_error) {
                        stderr.printf("[ERROR] CHATVIEW: Erreur lors de la mise à jour de l'interface: %s\n", update_error.message);

                        // Copier le message d'erreur pour l'utiliser dans le lambda
                        string error_message = update_error.message;
                        
                        // Afficher un message d'erreur sécurisé
                        Idle.add(() => {
                            show_error_response("💥 **_Erreur critique de l'interface_**\n\n**Cause :** Une erreur s'est produite lors de la mise à jour de la réponse IA.\n\n**Détails :** " + error_message + "\n\n**Solution :** Réessayez votre question. Si le problème persiste, redémarrez l'application.");
                            return Source.REMOVE;
                        });
                        return; // Sortir du callback en cas d'erreur
                    }

                    // Compter approximativement les tokens (estimation grossière)
                    token_count = (int)(partial_response.length / 4.0); // ~4 caractères par token

                    // Faire défiler vers le bas pour suivre la génération (de manière sécurisée)
                    Idle.add(() => {
                        try {
                            scroll_to_bottom();
                        } catch (Error scroll_error) {
                            stderr.printf("[ERROR] CHATVIEW: Erreur lors du défilement: %s\n", scroll_error.message);
                        }
                        return Source.REMOVE;
                    });

                    if (is_finished) {
                        stderr.printf("[TRACE][IN] CHATVIEW: Génération terminée - nettoyage\n");

                        try {
                            // Calculer la durée de traitement
                            int64 generation_end_time = get_monotonic_time();
                            double duration = (generation_end_time - generation_start_time) / 1000000.0; // en secondes

                            // Mettre à jour les statistiques dans la bulle
                            if (current_ai_bubble != null && !current_ai_bubble.is_floating()) {
                                current_ai_bubble.update_processing_stats(token_count, duration);
                            }

                            // Arrêter le chronomètre dans le CommunicationView
                            var parent_widget = this.get_parent();
                            while (parent_widget != null && !(parent_widget is CommunicationView)) {
                                parent_widget = parent_widget.get_parent();
                            }
                            if (parent_widget is CommunicationView) {
                                ((CommunicationView)parent_widget).stop_execution_timer();
                            }

                            // Génération terminée
                            is_processing = false;

                            // Statut différent selon s'il y a eu une erreur ou pas
                            if (ai_error_detected) {
                                if (status_label != null && !status_label.is_floating()) {
                                    status_label.set_text("⚠️ Réponse générique détectée");
                                }
                            } else {
                                if (status_label != null && !status_label.is_floating()) {
                                    status_label.set_text("Prêt"); // Statut neutre après génération
                                }
                            }

                            // Nettoyer les références
                            current_ai_message = null;
                            current_ai_bubble = null;

                            // Masquer les indicateurs de progression et réactiver l'envoi (de manière sécurisée)
                            if (progress_bar != null && !progress_bar.is_floating()) {
                                progress_bar.set_visible(false);
                            }
                            if (cancel_generation_button != null && !cancel_generation_button.is_floating()) {
                                cancel_generation_button.set_visible(false);
                            }
                            if (send_button != null && !send_button.is_floating()) {
                                send_button.set_sensitive(true);
                            }
                            if (message_entry != null && !message_entry.is_floating()) {
                                message_entry.set_sensitive(true);
                                message_entry.grab_focus();
                            }
                        } catch (Error finish_error) {
                            stderr.printf("[ERROR] CHATVIEW: Erreur lors de la finalisation: %s\n", finish_error.message);
                        }
                    }
                });
            } catch (Error generation_error) {
                stderr.printf("[ERROR] CHATVIEW: Erreur lors de la génération IA: %s\n", generation_error.message);
                show_error_response("🚨 **_Erreur de génération IA_**\n\n**Cause :** Une erreur critique s'est produite lors de la génération de la réponse.\n\n**Détails :** " + generation_error.message + "\n\n**Solutions :**\n• Réessayez votre question\n• Vérifiez que le modèle d'IA est correctement configuré\n• Redémarrez l'application si le problème persiste");
            }
        }

        /**
         * Affiche un message d'erreur dans le chat avec formatage en gras et italique
         */
        private void show_error_response(string error_message) {
            // Arrêter le chronomètre en cas d'erreur
            var parent_widget = this.get_parent();
            while (parent_widget != null && !(parent_widget is CommunicationView)) {
                parent_widget = parent_widget.get_parent();
            }
            if (parent_widget is CommunicationView) {
                ((CommunicationView)parent_widget).stop_execution_timer();
            }

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

            // Extraire le titre de l'erreur pour le toast (sans le formatage markdown)
            string toast_message = error_message;
            if (error_message.contains("**_") && error_message.contains("_**")) {
                // Extraire le titre entre **_ et _**
                int start = error_message.index_of("**_") + 3;
                int end = error_message.index_of("_**", start);
                if (end > start) {
                    toast_message = error_message.substring(start, end - start);
                }
            }
            show_toast(toast_message);
        }

        /**
         * Fait défiler vers le bas de la conversation
         */
        private void scroll_to_bottom() {
            stderr.printf("🔄 CHATVIEW: scroll_to_bottom appelé\n");
            var vadj = scroll.get_vadjustment();
            stderr.printf("🔄 CHATVIEW: vadj upper: %f, page_size: %f, value: %f\n",
                vadj.get_upper(), vadj.get_page_size(), vadj.get_value());
            vadj.set_value(vadj.get_upper() - vadj.get_page_size());
            stderr.printf("🔄 CHATVIEW: Nouveau value: %f\n", vadj.get_value());
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
            stderr.printf("🔵 CHATVIEW: add_message appelé\n");

            // Vérification de sécurité
            if (message == null) {
                stderr.printf("❌ CHATVIEW: Message null dans add_message\n");
                warning("Tentative d'ajout d'un message null");
                return;
            }

            stderr.printf("🔵 CHATVIEW: Création ChatBubbleRow pour message: '%s'\n", message.content ?? "(vide)");

            // Créer et ajouter la bulle de message
            var bubble = new ChatBubbleRow(message);

            stderr.printf("🔵 CHATVIEW: ChatBubbleRow créé, ajout au message_container\n");
            message_container.append(bubble);

            stderr.printf("🔵 CHATVIEW: Message ajouté au conteneur, nombre d'enfants: %u\n",
                message_container.get_first_child() != null ? 1 : 0);

            // Forcer l'affichage des widgets
            message_container.set_visible(true);
            bubble.set_visible(true);
            scroll.set_visible(true);

            stderr.printf("🔵 CHATVIEW: Visibilité forcée - container: %s, bubble: %s, scroll: %s\n",
                message_container.get_visible() ? "VISIBLE" : "MASQUÉ",
                bubble.get_visible() ? "VISIBLE" : "MASQUÉ",
                scroll.get_visible() ? "VISIBLE" : "MASQUÉ");

            // Faire défiler vers le bas
            Idle.add(() => {
                scroll_to_bottom();
                return Source.REMOVE;
            });

            stderr.printf("✅ CHATVIEW: add_message terminé\n");
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
            stderr.printf("🔍 ChatView.on_cancel_generation_clicked: DÉBUT\n");

            try {
                // Marquer la génération comme annulée
                is_generation_cancelled = true;

                // Arrêter le chronomètre en cas d'annulation
                var parent_widget = this.get_parent();
                while (parent_widget != null && !(parent_widget is CommunicationView)) {
                    parent_widget = parent_widget.get_parent();
                }
                if (parent_widget is CommunicationView) {
                    ((CommunicationView)parent_widget).stop_execution_timer();
                }

                // Forcer la mise à jour de l'état AVANT d'annuler
                force_unlock_ui();

                // Marquer le message AI actuel comme annulé
                if (current_ai_message != null) {
                    current_ai_message.content = "⏹️ Génération annulée par l'utilisateur";
                    if (current_ai_bubble != null) {
                        current_ai_bubble.update_content();
                    }
                }

                show_toast("⏹️ Génération annulée");

                // Annuler dans le ModelManager APRÈS avoir mis à jour l'UI
                // Avec protection contre les exceptions
                try {
                    var model_manager = controller.get_model_manager();
                    if (model_manager != null) {
                        stderr.printf("🔍 ChatView: Appel cancel_generation\n");
                        model_manager.cancel_generation();
                        stderr.printf("🔍 ChatView: cancel_generation terminé\n");
                    }
                } catch (Error e) {
                    stderr.printf("❌ ChatView: Erreur lors de l'annulation: %s\n", e.message);
                    // Continuer le traitement même en cas d'erreur
                }

                // Sécurité supplémentaire avec délai
                Timeout.add(500, () => {
                    force_unlock_ui();
                    return false;
                });

            } catch (Error e) {
                stderr.printf("❌ ChatView.on_cancel_generation_clicked: Erreur critique: %s\n", e.message);
                // En cas d'erreur critique, forcer le débloquage
                force_unlock_ui();
            }

            stderr.printf("🔍 ChatView.on_cancel_generation_clicked: FIN\n");
        }

        /**
         * Force le débloquage de l'interface utilisateur
         */
        private void force_unlock_ui() {
            is_processing = false;
            is_generation_cancelled = false; // Réinitialiser le flag d'annulation
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
