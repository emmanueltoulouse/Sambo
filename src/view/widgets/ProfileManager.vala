using Gtk;
using Adw;

namespace Sambo {
    /**
     * Gestionnaire de profils d'inférence avec design moderne
     */
    public class ProfileManager : Adw.Window {
        private ApplicationController controller;
        private ConfigManager config_manager;
        private Adw.HeaderBar header_bar;
        private Adw.ViewStack view_stack;
        private Adw.ViewSwitcherTitle view_switcher_title;
        private Adw.ToastOverlay toast_overlay;
        private Adw.Leaflet leaflet;

        // Page de liste des profils
        private Adw.StatusPage empty_state_page;
        private Gtk.ListBox profiles_list;
        private Gtk.SearchEntry search_entry;
        private Button add_profile_button;
        private Adw.ActionRow selected_profile_row;
        private Gtk.Stack content_stack;

        // Page de détails
        private Adw.PreferencesPage details_page;
        private string? selected_profile_id;
        private InferenceProfile? current_profile;

        public signal void profile_selected(string profile_id);

        public ProfileManager(ApplicationController controller) {
            Object(
                title: "Profils d'inférence",
                default_width: 900,
                default_height: 700,
                modal: true
            );

            this.controller = controller;
            this.config_manager = controller.get_config_manager();
            this.selected_profile_id = null;
            this.current_profile = null;

            setup_modern_ui();
            refresh_profiles();

            // Connecter les signaux
            config_manager.profiles_changed.connect(refresh_profiles);
        }

        private void setup_modern_ui() {
            // Toast overlay principal
            toast_overlay = new Adw.ToastOverlay();
            set_content(toast_overlay);

            // Leaflet pour l'interface adaptative avec transitions fluides
            leaflet = new Adw.Leaflet();
            leaflet.set_can_navigate_back(true);
            leaflet.set_can_navigate_forward(true);
            leaflet.set_can_unfold(true);
            leaflet.set_homogeneous(false);
            leaflet.set_transition_type(Adw.LeafletTransitionType.SLIDE);
            leaflet.set_vexpand(true);
            leaflet.set_hexpand(true);
            toast_overlay.set_child(leaflet);

            // Ajouter des classes CSS pour animations
            add_css_class("profile-manager-window");
            leaflet.add_css_class("profile-leaflet");

            // Header bar moderne
            setup_header_bar();

            // Page principale avec liste des profils
            setup_main_page();

            // Page de détails
            setup_details_page();
        }

        private void setup_header_bar() {
            header_bar = new Adw.HeaderBar();
            header_bar.add_css_class("flat");
            header_bar.add_css_class("profile-header");

            // Titre avec icône et gradient
            var title_box = new Box(Orientation.HORIZONTAL, 8);
            var title_icon = new Image.from_icon_name("user-info-symbolic");
            title_icon.add_css_class("profile-title-icon");
            title_box.append(title_icon);

            var title_label = new Label("Profils d'inférence");
            title_label.add_css_class("heading");
            title_label.add_css_class("profile-title");
            title_box.append(title_label);

            header_bar.set_title_widget(title_box);

            // Bouton d'ajout avec animation
            add_profile_button = new Button();
            add_profile_button.set_icon_name("list-add-symbolic");
            add_profile_button.set_tooltip_text("Créer un nouveau profil");
            add_profile_button.add_css_class("suggested-action");
            add_profile_button.add_css_class("profile-add-button");
            add_profile_button.clicked.connect(on_create_profile);
            header_bar.pack_end(add_profile_button);

            // Bouton de menu avec style moderne
            var menu_button = new MenuButton();
            menu_button.set_icon_name("view-more-symbolic");
            menu_button.set_tooltip_text("Options avancées");
            menu_button.add_css_class("profile-menu-button");

            var menu = new GLib.Menu();
            menu.append("✨ Profil par défaut", "win.create_default_profile");
            menu.append("📁 Importer un profil", "win.import_profile");
            menu.append("💾 Exporter les profils", "win.export_profiles");
            menu.append("🔄 Réinitialiser", "win.reset_profiles");
            menu_button.set_menu_model(menu);

            header_bar.pack_end(menu_button);
        }

        private void setup_main_page() {
            var main_page = new Box(Orientation.VERTICAL, 0);
            main_page.set_size_request(400, -1);
            main_page.add_css_class("profile-main-page");
            main_page.set_vexpand(true);
            main_page.set_hexpand(true);

            // Header bar pour la page principale
            main_page.append(header_bar);

            // Barre de recherche moderne avec icône
            var search_bar = new Gtk.SearchBar();
            search_bar.add_css_class("profile-search-bar");

            var search_box = new Box(Orientation.HORIZONTAL, 8);
            var search_icon = new Image.from_icon_name("system-search-symbolic");
            search_icon.add_css_class("dim-label");
            search_box.append(search_icon);

            search_entry = new Gtk.SearchEntry();
            search_entry.set_placeholder_text("🔍 Rechercher un profil...");
            search_entry.search_changed.connect(on_search_changed);
            search_entry.add_css_class("profile-search-entry");
            search_box.append(search_entry);

            search_bar.set_child(search_box);
            main_page.append(search_bar);

            // Conteneur pour la liste avec état vide
            content_stack = new Gtk.Stack();
            content_stack.set_vhomogeneous(false);
            content_stack.set_transition_type(Gtk.StackTransitionType.SLIDE_LEFT_RIGHT);
            content_stack.set_transition_duration(300);
            content_stack.add_css_class("profile-content-stack");
            content_stack.set_vexpand(true);
            content_stack.set_hexpand(true);

            // État vide élégant avec design moderne
            empty_state_page = new Adw.StatusPage();
            empty_state_page.set_icon_name("user-available-symbolic");
            empty_state_page.set_title("Aucun profil d'inférence");
            empty_state_page.set_description("Créez votre premier profil pour commencer à utiliser l'IA avec des paramètres personnalisés.\n\nUn profil contient toutes les informations nécessaires : le modèle, les paramètres de génération, et les instructions système.");
            empty_state_page.add_css_class("profile-empty-state");

            var create_first_button = new Button.with_label("✨ Créer mon premier profil");
            create_first_button.add_css_class("suggested-action");
            create_first_button.add_css_class("pill");
            create_first_button.add_css_class("profile-create-first");
            create_first_button.set_halign(Align.CENTER);
            create_first_button.clicked.connect(on_create_profile);
            empty_state_page.set_child(create_first_button);

            content_stack.add_named(empty_state_page, "empty");

            // Liste des profils avec défilement et animations
            var scrolled = new ScrolledWindow();
            scrolled.set_policy(PolicyType.NEVER, PolicyType.AUTOMATIC);
            scrolled.set_vexpand(true);
            scrolled.add_css_class("profile-scrolled");

            profiles_list = new Gtk.ListBox();
            profiles_list.add_css_class("boxed-list");
            profiles_list.add_css_class("profile-list");
            profiles_list.set_selection_mode(SelectionMode.SINGLE);

            // Gérer le double-clic uniquement avec GestureClick
            var click_controller = new Gtk.GestureClick();
            click_controller.set_button(1);
            click_controller.pressed.connect((n_press, x, y) => {
                if (n_press == 2) {
                    print("Double-clic détecté - Navigation vers les détails\n");
                    var row = profiles_list.get_row_at_y((int)y);
                    if (row != null) {
                        on_profile_row_double_clicked(row);
                    }
                }
            });
            profiles_list.add_controller(click_controller);

            scrolled.set_child(profiles_list);

            content_stack.add_named(scrolled, "list");
            main_page.append(content_stack);

            // Profil actuellement sélectionné (bannière moderne)
            setup_current_profile_banner(main_page);

            leaflet.append(main_page);
        }

        private void setup_current_profile_banner(Box parent) {
            var current_banner = new Adw.Banner("🎯 Profil actuel : Aucun sélectionné");
            current_banner.set_revealed(true);
            current_banner.add_css_class("profile-current-banner");

            var select_button = new Button.with_label("🎯 Sélectionner ce profil");
            select_button.add_css_class("flat");
            select_button.add_css_class("profile-select-button");
            select_button.clicked.connect(() => {
                if (selected_profile_id != null) {
                    config_manager.select_profile(selected_profile_id);
                    profile_selected.emit(selected_profile_id);
                    show_toast("✅ Profil sélectionné avec succès");
                    update_current_profile_banner();
                }
            });
            // Note: Adw.Banner ne supporte plus add_button dans la nouvelle version
            // current_banner.add_button(select_button);

            parent.append(current_banner);
        }

        private void setup_details_page() {
            details_page = new Adw.PreferencesPage();
            details_page.set_title("Détails du profil");
            details_page.set_icon_name("user-info-symbolic");
            details_page.add_css_class("profile-details-page");

            var scrolled_details = new ScrolledWindow();
            scrolled_details.set_policy(PolicyType.NEVER, PolicyType.AUTOMATIC);
            scrolled_details.set_child(details_page);
            scrolled_details.set_vexpand(true);
            scrolled_details.set_hexpand(true);
            scrolled_details.add_css_class("profile-details-scrolled");

            var details_box = new Box(Orientation.VERTICAL, 0);
            details_box.add_css_class("profile-details-box");
            details_box.set_vexpand(true);
            details_box.set_hexpand(true);
            details_box.set_size_request(-1, 500); // Assurer une hauteur minimale

            // Header bar pour les détails avec design moderne
            var details_header = new Adw.HeaderBar();
            details_header.add_css_class("flat");
            details_header.add_css_class("profile-details-header");
            details_header.set_show_end_title_buttons(false);

            var back_button = new Button();
            back_button.set_icon_name("go-previous-symbolic");
            back_button.set_tooltip_text("Retour à la liste");
            back_button.add_css_class("profile-back-button");
            back_button.clicked.connect(() => {
                leaflet.navigate(Adw.NavigationDirection.BACK);
            });
            details_header.pack_start(back_button);

            // Titre avec icône
            var title_box = new Box(Orientation.HORIZONTAL, 8);
            var title_icon = new Image.from_icon_name("user-info-symbolic");
            title_icon.add_css_class("accent");
            title_box.append(title_icon);

            var title_label = new Label("Détails du profil");
            title_label.add_css_class("heading");
            title_box.append(title_label);

            details_header.set_title_widget(title_box);

            // Boutons d'actions avec icônes modernes
            var edit_button = new Button.with_label("✏️ Éditer");
            edit_button.add_css_class("suggested-action");
            edit_button.add_css_class("profile-edit-button");
            edit_button.clicked.connect(on_edit_profile);
            details_header.pack_end(edit_button);

            var delete_button = new Button();
            delete_button.set_icon_name("user-trash-symbolic");
            delete_button.add_css_class("destructive-action");
            delete_button.add_css_class("profile-delete-button");
            delete_button.set_tooltip_text("Supprimer ce profil");
            delete_button.clicked.connect(on_delete_profile);
            details_header.pack_end(delete_button);

            // Bouton de sélection rapide
            var quick_select_button = new Button.with_label("🎯 Sélectionner");
            quick_select_button.add_css_class("flat");
            quick_select_button.add_css_class("profile-quick-select");
            quick_select_button.clicked.connect(() => {
                if (selected_profile_id != null) {
                    config_manager.select_profile(selected_profile_id);
                    profile_selected.emit(selected_profile_id);
                    show_toast("✅ Profil sélectionné");
                    update_current_profile_banner();
                }
            });
            details_header.pack_end(quick_select_button);

            details_box.append(details_header);
            details_box.append(scrolled_details);
            
            // S'assurer que la ScrolledWindow prend toute la hauteur disponible
            scrolled_details.set_vexpand(true);
            scrolled_details.set_hexpand(true);
            scrolled_details.set_size_request(-1, 400); // Hauteur minimale pour éviter les warnings

            leaflet.append(details_box);
        }

        private void refresh_profiles() {
            // Vider la liste actuelle
            while (profiles_list.get_first_child() != null) {
                profiles_list.remove(profiles_list.get_first_child());
            }

            var profiles = config_manager.get_all_profiles();
            var selected_profile = config_manager.get_selected_profile();

            // Gérer l'état vide
            if (profiles.size == 0) {
                content_stack.set_visible_child_name("empty");
                add_profile_button.set_visible(false);
            } else {
                content_stack.set_visible_child_name("list");
                add_profile_button.set_visible(true);

                // Ajouter les profils avec un design moderne
                foreach (var profile in profiles) {
                    var row = create_modern_profile_row(profile);
                    profiles_list.append(row);
                }
            }

            update_current_profile_banner();
        }

        private Adw.ActionRow create_modern_profile_row(InferenceProfile profile) {
            var row = new Adw.ActionRow();
            row.add_css_class("profile-row");

            // Icône de statut simple
            var status_icon = new Image();
            var selected_profile = config_manager.get_selected_profile();
            if (selected_profile != null && selected_profile.id == profile.id) {
                status_icon.set_from_icon_name("emblem-default-symbolic");
                status_icon.add_css_class("success");
                status_icon.add_css_class("profile-active-icon");
                row.add_css_class("profile-row-active");
            } else {
                status_icon.set_from_icon_name("user-available-symbolic");
                status_icon.add_css_class("dim-label");
                status_icon.add_css_class("profile-inactive-icon");
                row.add_css_class("profile-row-inactive");
            }
            status_icon.set_pixel_size(24);
            row.add_prefix(status_icon);

            // Titre principal de la row
            row.set_title(profile.title);

            // Commentaire comme sous-titre (affichage simple)
            if (profile.comment != "") {
                row.set_subtitle(profile.comment);
            }

            // Badge "Actuel" si c'est le profil sélectionné
            if (selected_profile != null && selected_profile.id == profile.id) {
                var active_badge = new Gtk.Label("🎯 Actuel");
                active_badge.add_css_class("caption");
                active_badge.add_css_class("profile-active-badge");
                active_badge.set_valign(Align.CENTER);
                row.add_suffix(active_badge);
            }

            // Flèche pour indiquer la navigation vers les détails
            var arrow = new Image.from_icon_name("go-next-symbolic");
            arrow.add_css_class("dim-label");
            arrow.add_css_class("profile-arrow");
            arrow.set_valign(Align.CENTER);
            row.add_suffix(arrow);

            // Stocker l'ID du profil dans les données de la row
            row.set_data("profile_id", profile.id);
            
            // Note: Ne pas rendre la row activable car on veut seulement le double-clic
            // row.set_activatable(true);

            return row;
        }

        private void on_profile_row_double_clicked(Gtk.ListBoxRow? row) {
            if (row == null) {
                print("Erreur : row est null\n");
                return;
            }

            try {
                var action_row = (Adw.ActionRow) row;
                selected_profile_id = action_row.get_data<string>("profile_id");

                if (selected_profile_id == null) {
                    print("Erreur : ID du profil non trouvé\n");
                    return;
                }

                current_profile = config_manager.get_profile(selected_profile_id);

                if (current_profile != null) {
                    print(@"Ouverture des détails du profil : $(current_profile.title)\n");

                    // Utiliser Idle.add pour éviter les blocages
                    Idle.add(() => {
                        show_profile_details(current_profile);
                        leaflet.navigate(Adw.NavigationDirection.FORWARD);
                        return false;
                    });
                } else {
                    print(@"Erreur : Profil introuvable avec l'ID : $(selected_profile_id)\n");
                    show_toast("❌ Profil introuvable");
                }
            } catch (Error e) {
                print(@"Erreur lors de l'ouverture des détails : $(e.message)\n");
                show_toast("❌ Erreur lors de l'ouverture des détails");
            }
        }

        private void show_profile_details(InferenceProfile profile) {
            // Vider la page de détails de manière sécurisée
            var children = new List<Gtk.Widget>();
            for (var child = details_page.get_first_child(); child != null; child = child.get_next_sibling()) {
                children.prepend(child);
            }

            foreach (var child in children) {
                if (child is Adw.PreferencesGroup) {
                    details_page.remove((Adw.PreferencesGroup)child);
                }
            }

            // Groupe d'informations générales avec design moderne
            var general_group = new Adw.PreferencesGroup();
            general_group.set_title("✨ Informations générales");
            general_group.set_description("Détails du profil d'inférence");
            general_group.add_css_class("profile-general-group");

            var title_row = new Adw.ActionRow();
            title_row.set_title("Nom du profil");
            title_row.set_subtitle(profile.title);
            var title_icon = new Image.from_icon_name("text-x-generic-symbolic");
            title_icon.add_css_class("accent");
            title_row.add_prefix(title_icon);

            // Badge de statut
            var selected_profile = config_manager.get_selected_profile();
            if (selected_profile != null && selected_profile.id == profile.id) {
                var active_badge = new Gtk.Label("🎯 Actuel");
                active_badge.add_css_class("caption");
                active_badge.add_css_class("profile-active-badge");
                title_row.add_suffix(active_badge);
            }

            general_group.add(title_row);

            if (profile.comment != "") {
                var comment_row = new Adw.ActionRow();
                comment_row.set_title("Description");
                comment_row.set_subtitle(profile.comment);
                var comment_icon = new Image.from_icon_name("text-x-script-symbolic");
                comment_icon.add_css_class("dim-label");
                comment_row.add_prefix(comment_icon);
                general_group.add(comment_row);
            }

            var model_row = new Adw.ActionRow();
            model_row.set_title("Modèle d'IA");
            var model_name = profile.model_path != "" ? "🤖 " + Path.get_basename(profile.model_path) : "⚠️ Aucun modèle sélectionné";
            model_row.set_subtitle(model_name);
            var model_icon = new Image.from_icon_name("applications-science-symbolic");
            model_icon.add_css_class(profile.model_path != "" ? "success" : "warning");
            model_row.add_prefix(model_icon);
            general_group.add(model_row);

            details_page.add(general_group);

            // Groupe des paramètres principaux avec indicateurs visuels
            var main_params_group = new Adw.PreferencesGroup();
            main_params_group.set_title("🎛️ Paramètres principaux");
            main_params_group.set_description("Paramètres de base pour la génération");
            main_params_group.add_css_class("profile-params-group");

            add_parameter_row(main_params_group, "Température", profile.temperature.to_string("%.2f"), "Contrôle la créativité (0.0 = déterministe, 1.0+ = créatif)", get_temperature_color(profile.temperature));
            add_parameter_row(main_params_group, "Top-P", profile.top_p.to_string("%.2f"), "Sampling nucléaire (0.0-1.0)", "accent");
            add_parameter_row(main_params_group, "Top-K", profile.top_k.to_string(), "Nombre de tokens considérés", "accent");
            add_parameter_row(main_params_group, "Tokens max", profile.max_tokens.to_string(), "Longueur maximale de la réponse", "accent");

            details_page.add(main_params_group);

            // Groupe des paramètres avancés avec expander
            var advanced_group = new Adw.PreferencesGroup();
            advanced_group.set_title("⚙️ Paramètres avancés");
            advanced_group.set_description("Options avancées pour un contrôle fin");
            advanced_group.add_css_class("profile-advanced-group");

            add_parameter_row(advanced_group, "Pénalité répétition", profile.repetition_penalty.to_string("%.2f"), "Évite les répétitions", "warning");
            add_parameter_row(advanced_group, "Pénalité fréquence", profile.frequency_penalty.to_string("%.2f"), "Réduit les mots fréquents", "warning");
            add_parameter_row(advanced_group, "Pénalité présence", profile.presence_penalty.to_string("%.2f"), "Encourage la nouveauté", "warning");
            add_parameter_row(advanced_group, "Graine (seed)", profile.seed == -1 ? "🎲 Aléatoire" : profile.seed.to_string(), "Reproductibilité", "accent");
            add_parameter_row(advanced_group, "Contexte", profile.context_length.to_string() + " tokens", "Taille du contexte", "accent");

            var stream_row = new Adw.ActionRow();
            stream_row.set_title("Mode streaming");
            stream_row.set_subtitle(profile.stream ? "🟢 Réponse progressive" : "🔴 Réponse complète");
            var stream_icon = new Image.from_icon_name(profile.stream ? "media-playback-start-symbolic" : "media-playback-pause-symbolic");
            stream_icon.add_css_class(profile.stream ? "success" : "error");
            stream_row.add_prefix(stream_icon);
            advanced_group.add(stream_row);

            details_page.add(advanced_group);

            // Groupe du prompt avec preview stylé
            var prompt_group = new Adw.PreferencesGroup();
            prompt_group.set_title("💬 Prompt système");
            prompt_group.set_description("Instructions données à l'IA");
            prompt_group.add_css_class("profile-prompt-group");

            var prompt_row = new Adw.ExpanderRow();
            prompt_row.set_title("Voir le prompt complet");
            prompt_row.set_subtitle(profile.prompt.length > 100 ?
                "📝 " + profile.prompt.substring(0, 100) + "..." :
                "📝 " + profile.prompt);
            var prompt_icon = new Image.from_icon_name("text-x-script-symbolic");
            prompt_icon.add_css_class("accent");
            prompt_row.add_prefix(prompt_icon);

            var prompt_content = new Gtk.Label(profile.prompt);
            prompt_content.set_wrap(true);
            prompt_content.set_xalign(0);
            prompt_content.set_margin_start(12);
            prompt_content.set_margin_end(12);
            prompt_content.set_margin_top(12);
            prompt_content.set_margin_bottom(12);
            prompt_content.add_css_class("monospace");
            prompt_content.add_css_class("card");
            prompt_content.add_css_class("profile-prompt-content");

            prompt_row.add_row(prompt_content);
            prompt_group.add(prompt_row);

            details_page.add(prompt_group);

            // Groupe d'actions rapides
            var actions_group = new Adw.PreferencesGroup();
            actions_group.set_title("🚀 Actions rapides");
            actions_group.set_description("Opérations courantes sur ce profil");
            actions_group.add_css_class("profile-actions-group");

            var current_selected_profile = config_manager.get_selected_profile();
            bool is_current_profile = (current_selected_profile != null && current_selected_profile.id == profile.id);

            // Bouton de sélection (seulement si ce n'est pas le profil actuel)
            if (!is_current_profile) {
                var select_row = new Adw.ActionRow();
                select_row.set_title("Sélectionner ce profil");
                select_row.set_subtitle("Définir comme profil actif pour les conversations");
                var select_icon = new Image.from_icon_name("emblem-default-symbolic");
                select_icon.add_css_class("success");
                select_row.add_prefix(select_icon);
                select_row.set_activatable(true);
                select_row.activated.connect(() => {
                    config_manager.select_profile(profile.id);
                    profile_selected.emit(profile.id);
                    show_toast("✅ Profil sélectionné : " + profile.title);
                    refresh_profiles(); // Actualiser l'affichage
                    show_profile_details(profile); // Actualiser les détails
                });
                actions_group.add(select_row);
            }

            // Bouton d'édition
            var edit_row = new Adw.ActionRow();
            edit_row.set_title("Éditer ce profil");
            edit_row.set_subtitle("Modifier les paramètres et configurations");
            var edit_icon = new Image.from_icon_name("edit-symbolic");
            edit_icon.add_css_class("accent");
            edit_row.add_prefix(edit_icon);
            edit_row.set_activatable(true);
            edit_row.activated.connect(() => {
                on_edit_profile_by_id(profile.id);
            });
            actions_group.add(edit_row);

            // Bouton de suppression
            var delete_row = new Adw.ActionRow();
            delete_row.set_title("Supprimer ce profil");
            delete_row.set_subtitle("Supprimer définitivement ce profil");
            var delete_icon = new Image.from_icon_name("user-trash-symbolic");
            delete_icon.add_css_class("destructive-action");
            delete_row.add_prefix(delete_icon);
            delete_row.set_activatable(true);
            delete_row.activated.connect(() => {
                on_delete_profile_by_id(profile.id);
            });
            actions_group.add(delete_row);

            var duplicate_row = new Adw.ActionRow();
            duplicate_row.set_title("Dupliquer ce profil");
            duplicate_row.set_subtitle("Créer une copie pour modification");
            var duplicate_icon = new Image.from_icon_name("edit-copy-symbolic");
            duplicate_icon.add_css_class("accent");
            duplicate_row.add_prefix(duplicate_icon);
            duplicate_row.set_activatable(true);
            duplicate_row.activated.connect(() => {
                var new_profile = InferenceProfile.create_default(
                    InferenceProfile.generate_unique_id(),
                    profile.title + " (copie)"
                );
                new_profile.copy_from(profile);
                new_profile.id = InferenceProfile.generate_unique_id();
                config_manager.save_profile(new_profile);
                show_toast("✨ Profil dupliqué avec succès");
            });
            actions_group.add(duplicate_row);

            var export_row = new Adw.ActionRow();
            export_row.set_title("Exporter ce profil");
            export_row.set_subtitle("Sauvegarder dans un fichier");
            var export_icon = new Image.from_icon_name("document-save-symbolic");
            export_icon.add_css_class("accent");
            export_row.add_prefix(export_icon);
            export_row.set_activatable(true);
            actions_group.add(export_row);

            details_page.add(actions_group);
        }

        private void add_parameter_row(Adw.PreferencesGroup group, string title, string value, string? description, string icon_class) {
            var row = new Adw.ActionRow();
            row.set_title(title);
            row.set_subtitle(value);
            if (description != null && description != "") {
                row.set_subtitle(description + " : " + value);
            }

            var icon = new Image.from_icon_name("preferences-system-symbolic");
            icon.add_css_class(icon_class);
            row.add_prefix(icon);

            group.add(row);
        }

        private string get_temperature_color(float temperature) {
            if (temperature < 0.3) return "success";  // Vert pour déterministe
            if (temperature < 0.7) return "accent";   // Bleu pour équilibré
            if (temperature < 1.2) return "warning";  // Orange pour créatif
            return "error";  // Rouge pour très créatif
        }

        private void update_current_profile_banner() {
            var current_profile = config_manager.get_selected_profile();

            // Chercher la bannière dans la page principale
            var main_page = (Box)leaflet.get_first_child();
            var banner = (Adw.Banner)main_page.get_last_child();

            if (current_profile != null) {
                banner.set_title("🎯 Profil actuel : " + current_profile.title);
                banner.set_revealed(true);
                banner.add_css_class("profile-current-banner-active");
            } else {
                banner.set_title("⚠️ Aucun profil sélectionné");
                banner.set_revealed(true);
                banner.add_css_class("profile-current-banner-warning");
            }
        }

        private void show_profile_creation_wizard() {
            var wizard = new ProfileCreationWizard(this, controller);
            wizard.profile_created.connect((profile) => {
                config_manager.save_profile(profile);
                config_manager.select_profile(profile.id);
                show_toast("✨ Profil créé et sélectionné avec succès");
                refresh_profiles();
            });
            wizard.present();
        }

        private void import_profile_from_file() {
            var file_dialog = new FileDialog();
            file_dialog.set_title("Importer un profil");

            var filter = new FileFilter();
            filter.add_pattern("*.json");
            // Note: set_name n'existe plus dans GTK4, utilisons add_pattern avec un nom

            var filter_list = new GLib.ListStore(typeof(FileFilter));
            filter_list.append(filter);
            file_dialog.set_filters(filter_list);

            file_dialog.open.begin(this, null, (obj, res) => {
                try {
                    var file = file_dialog.open.end(res);
                    if (file != null) {
                        // Logique d'importation à implémenter
                        show_toast("📁 Importation de profil (fonctionnalité à venir)");
                    }
                } catch (Error e) {
                    show_toast("❌ Erreur lors de l'importation : " + e.message);
                }
            });
        }

        private void export_all_profiles() {
            var file_dialog = new FileDialog();
            file_dialog.set_title("Exporter tous les profils");

            file_dialog.save.begin(this, null, (obj, res) => {
                try {
                    var file = file_dialog.save.end(res);
                    if (file != null) {
                        // Logique d'exportation à implémenter
                        show_toast("💾 Exportation de profils (fonctionnalité à venir)");
                    }
                } catch (Error e) {
                    show_toast("❌ Erreur lors de l'exportation : " + e.message);
                }
            });
        }

        private void reset_all_profiles() {
            var dialog = new Adw.MessageDialog(this, "Réinitialiser tous les profils ?", null);
            dialog.set_body("Cette action supprimera définitivement tous les profils existants et créera un profil par défaut.\n\n⚠️ Cette action ne peut pas être annulée.");
            dialog.add_response("cancel", "Annuler");
            dialog.add_response("reset", "Réinitialiser");
            dialog.set_response_appearance("reset", Adw.ResponseAppearance.DESTRUCTIVE);
            dialog.set_default_response("cancel");
            dialog.set_close_response("cancel");

            dialog.response.connect((response) => {
                if (response == "reset") {
                    // Supprimer tous les profils
                    var profiles = config_manager.get_all_profiles();
                    foreach (var profile in profiles) {
                        config_manager.delete_profile(profile.id);
                    }

                    // Créer un profil par défaut
                    config_manager.ensure_default_profile();
                    show_toast("🔄 Profils réinitialisés avec succès");
                    refresh_profiles();
                }
            });

            dialog.present();
        }

        private void on_create_profile() {
            var dialog = new ProfileEditorDialog(this, controller, null);
            dialog.profile_saved.connect((profile) => {
                config_manager.save_profile(profile);
                show_toast("✨ Profil créé avec succès");
                refresh_profiles();
            });
            dialog.present();
        }

        private void on_edit_profile() {
            if (selected_profile_id == null || current_profile == null) return;

            var dialog = new ProfileEditorDialog(this, controller, current_profile);
            dialog.profile_saved.connect((updated_profile) => {
                config_manager.save_profile(updated_profile);
                show_toast("✅ Profil modifié avec succès");
                refresh_profiles();
                // Retourner à la liste après modification
                leaflet.navigate(Adw.NavigationDirection.BACK);
            });
            dialog.present();
        }

        private void on_delete_profile() {
            if (selected_profile_id == null || current_profile == null) return;

            var dialog = new Adw.MessageDialog(this, "Supprimer le profil ?", null);
            dialog.set_body("Êtes-vous sûr de vouloir supprimer définitivement le profil \"%s\" ?\n\nCette action ne peut pas être annulée.".printf(current_profile.title));
            dialog.add_response("cancel", "Annuler");
            dialog.add_response("delete", "Supprimer");
            dialog.set_response_appearance("delete", Adw.ResponseAppearance.DESTRUCTIVE);
            dialog.set_default_response("cancel");
            dialog.set_close_response("cancel");

            dialog.response.connect((response) => {
                if (response == "delete") {
                    if (config_manager.delete_profile(selected_profile_id)) {
                        show_toast("🗑️ Profil supprimé");
                        selected_profile_id = null;
                        current_profile = null;
                        leaflet.navigate(Adw.NavigationDirection.BACK);
                        refresh_profiles();
                    } else {
                        show_toast("❌ Erreur lors de la suppression");
                    }
                }
            });

            dialog.present();
        }

        private void on_edit_profile_by_id(string profile_id) {
            var profile = config_manager.get_profile(profile_id);
            if (profile != null) {
                var dialog = new ProfileEditorDialog(this, controller, profile);
                dialog.profile_saved.connect((saved_profile) => {
                    refresh_profiles();
                    show_toast("✅ Profil modifié avec succès");
                });
                dialog.present();
            }
        }

        private void on_delete_profile_by_id(string profile_id) {
            var profile = config_manager.get_profile(profile_id);
            if (profile == null) return;

            var dialog = new Adw.MessageDialog(this, "Supprimer le profil", null);
            dialog.set_body(@"Êtes-vous sûr de vouloir supprimer définitivement le profil \"$(profile.title)\" ?\n\nCette action est irréversible.");

            dialog.add_response("cancel", "Annuler");
            dialog.add_response("delete", "Supprimer");
            dialog.set_response_appearance("delete", Adw.ResponseAppearance.DESTRUCTIVE);
            dialog.set_default_response("cancel");
            dialog.set_close_response("cancel");

            dialog.response.connect((response) => {
                if (response == "delete") {
                    if (config_manager.delete_profile(profile_id)) {
                        refresh_profiles();
                        show_toast("🗑️ Profil supprimé");
                    } else {
                        show_toast("❌ Erreur lors de la suppression");
                    }
                }
            });

            dialog.present();
        }

        private void on_search_changed() {
            string search_text = search_entry.get_text().down();

            for (var child = profiles_list.get_first_child(); child != null; child = child.get_next_sibling()) {
                var row = (Adw.ActionRow) child;
                string title = row.get_title().down();
                string subtitle = row.get_subtitle() ?? "";
                subtitle = subtitle.down();

                bool visible = search_text == "" || title.contains(search_text) || subtitle.contains(search_text);
                row.set_visible(visible);
            }
        }

        private void show_toast(string message) {
            var toast = new Adw.Toast(message);
            toast.set_timeout(3);
            toast_overlay.add_toast(toast);
        }
    }
}
