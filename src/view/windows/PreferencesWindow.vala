namespace Sambo {
    using Gtk;

    public class PreferencesWindow : Adw.PreferencesWindow {
        private ApplicationController controller;
        private ConfigManager config;

        public PreferencesWindow(ApplicationController controller) {
            Object(
                title: _("Préférences"),
                default_width: 800,
                default_height: 600,
                modal: true,
                destroy_with_parent: true,
                transient_for: controller.get_main_window()
            );

            this.controller = controller;
            this.config = controller.get_config_manager();

            setup_ui();
        }

        private void setup_ui() {
            // Page Général
            add_page_general();

            // Page Éditeur
            add_page_editor();

            // Page Explorateur
            add_page_explorer();

            // Page Communication
            add_page_communication();

            // Page Affichage (NOUVEAU)
            add_page_display();

            // Page IA
            add_page_ai();

            // Page Thèmes
            add_page_theme();

            // Page Extensions
            add_page_extensions();
        }

        private void add_page_general() {
            var general_page = new Adw.PreferencesPage();
            general_page.set_title(_("Général"));
            general_page.set_icon_name("preferences-system-symbolic");

            // --- Groupe Démarrage ---
            var startup_group = new Adw.PreferencesGroup();
            startup_group.set_title(_("Démarrage"));

            // Ouvrir le dernier fichier au démarrage
            var startup_row = new Adw.ActionRow();
            startup_row.set_title(_("Ouvrir le dernier fichier au démarrage"));
            var startup_switch = new Gtk.Switch();
            startup_switch.set_active(config.get_boolean("General", "open_last_file", true));
            startup_switch.set_valign(Gtk.Align.CENTER);
            startup_row.add_suffix(startup_switch);
            startup_group.add(startup_row);

            // Dossier de travail par défaut
            var folder_row = new Adw.ActionRow();
            folder_row.set_title(_("Dossier de travail par défaut"));
            var folder_button = new Gtk.Button.with_label(config.get_string("General", "default_folder", _("Choisir...")));
            folder_button.set_valign(Gtk.Align.CENTER);
            folder_row.add_suffix(folder_button);
            startup_group.add(folder_row);

            // Nombre maximum de fichiers récents
            var recent_row = new Adw.ActionRow();
            recent_row.set_title(_("Nombre maximum de fichiers récents"));
            var recent_spin = new Gtk.SpinButton.with_range(1, 50, 1);
            recent_spin.set_value(config.get_integer("General", "max_recent_files", 10));
            recent_row.add_suffix(recent_spin);
            startup_group.add(recent_row);

            general_page.add(startup_group);

            // --- Groupe Interface ---
            var interface_group = new Adw.PreferencesGroup();
            interface_group.set_title(_("Interface"));

            // Langue de l'interface
            var language_row = new Adw.ActionRow();
            language_row.set_title(_("Langue de l'interface"));
            var language_list = new Gtk.StringList({"Français", "English", "Español"});
            var language_dropdown = new Gtk.DropDown(language_list, null);
            language_dropdown.set_selected(config.get_integer("General", "language", 0));
            language_row.add_suffix(language_dropdown);
            interface_group.add(language_row);

            // Format de la date/heure
            var dateformat_row = new Adw.ActionRow();
            dateformat_row.set_title(_("Format de la date/heure"));
            var dateformat_list = new Gtk.StringList({ "24h", "12h", "Automatique" });
            var dateformat_dropdown = new Gtk.DropDown(dateformat_list, null);
            dateformat_dropdown.set_selected(config.get_integer("General", "time_format", 0));
            dateformat_row.add_suffix(dateformat_dropdown);
            interface_group.add(dateformat_row);

            // Barre de statut
            var statusbar_row = new Adw.ActionRow();
            statusbar_row.set_title(_("Afficher la barre de statut"));
            var statusbar_switch = new Gtk.Switch();
            statusbar_switch.set_active(config.get_boolean("General", "show_statusbar", true));
            statusbar_switch.set_valign(Gtk.Align.CENTER);
            statusbar_row.add_suffix(statusbar_switch);
            interface_group.add(statusbar_row);

            // Raccourcis clavier
            var shortcuts_row = new Adw.ActionRow();
            shortcuts_row.set_title(_("Afficher les raccourcis clavier"));
            var shortcuts_switch = new Gtk.Switch();
            shortcuts_switch.set_active(config.get_boolean("General", "show_shortcuts", true));
            shortcuts_switch.set_valign(Gtk.Align.CENTER);
            shortcuts_row.add_suffix(shortcuts_switch);
            interface_group.add(shortcuts_row);

            // Mode compact
            var compact_row = new Adw.ActionRow();
            compact_row.set_title(_("Mode compact"));
            var compact_switch = new Gtk.Switch();
            compact_switch.set_active(config.get_boolean("General", "compact_mode", false));
            compact_switch.set_valign(Gtk.Align.CENTER);
            compact_row.add_suffix(compact_switch);
            interface_group.add(compact_row);

            general_page.add(interface_group);

            // --- Groupe Conseils et sauvegarde ---
            var tips_group = new Adw.PreferencesGroup();
            tips_group.set_title(_("Conseils et sauvegarde"));

            // Afficher les conseils au démarrage
            var tips_row = new Adw.ActionRow();
            tips_row.set_title(_("Afficher les conseils au démarrage"));
            var tips_switch = new Gtk.Switch();
            tips_switch.set_active(config.get_boolean("General", "show_tips", true));
            tips_switch.set_valign(Gtk.Align.CENTER);
            tips_row.add_suffix(tips_switch);
            tips_group.add(tips_row);

            // Sauvegarde automatique
            var autosave_row = new Adw.ActionRow();
            autosave_row.set_title(_("Activer la sauvegarde automatique"));
            var autosave_switch = new Gtk.Switch();
            autosave_switch.set_active(config.get_boolean("General", "autosave", false));
            autosave_switch.set_valign(Gtk.Align.CENTER);
            autosave_row.add_suffix(autosave_switch);
            var autosave_spin = new Gtk.SpinButton.with_range(1, 60, 1);
            autosave_spin.set_value(config.get_integer("General", "autosave_interval", 5));
            autosave_spin.set_tooltip_text(_("Intervalle (minutes)"));
            autosave_row.add_suffix(autosave_spin);
            tips_group.add(autosave_row);

            general_page.add(tips_group);

            this.add(general_page);

            // Connecter les signaux
            startup_switch.notify["active"].connect(() => {
                config.set_boolean("General", "open_last_file", startup_switch.active);
                config.save();
            });
            folder_button.clicked.connect(() => {
                var dialog = new Gtk.FileDialog();
                dialog.set_title(_("Choisir un dossier de travail"));
                dialog.select_folder.begin(this, null, (obj, res) => {
                    try {
                        var folder = dialog.select_folder.end(res);
                        if (folder != null) {
                            string path = folder.get_path();
                            folder_button.set_label(path);
                            config.set_string("General", "default_folder", path);
                            config.save();
                        }
                    } catch (Error e) {
                        warning("Erreur lors de la sélection du dossier: %s", e.message);
                    }
                });
            });
            recent_spin.value_changed.connect(() => {
                config.set_integer("General", "max_recent_files", (int)recent_spin.get_value());
                config.save();
            });
            language_dropdown.notify["selected"].connect(() => {
                config.set_integer("General", "language", (int)language_dropdown.get_selected());
                config.save();
            });
            dateformat_dropdown.notify["selected"].connect(() => {
                config.set_integer("General", "time_format", (int)dateformat_dropdown.get_selected());
                config.save();
            });
            statusbar_switch.notify["active"].connect(() => {
                config.set_boolean("General", "show_statusbar", statusbar_switch.active);
                config.save();
            });
            shortcuts_switch.notify["active"].connect(() => {
                config.set_boolean("General", "show_shortcuts", shortcuts_switch.active);
                config.save();
            });
            compact_switch.notify["active"].connect(() => {
                config.set_boolean("General", "compact_mode", compact_switch.active);
                config.save();
            });
            tips_switch.notify["active"].connect(() => {
                config.set_boolean("General", "show_tips", tips_switch.active);
                config.save();
            });
            autosave_switch.notify["active"].connect(() => {
                config.set_boolean("General", "autosave", autosave_switch.active);
                autosave_spin.set_sensitive(autosave_switch.active);
                config.save();
            });
            autosave_spin.value_changed.connect(() => {
                config.set_integer("General", "autosave_interval", (int)autosave_spin.get_value());
                config.save();
            });
            // TODO: Ajouter les commutateurs pour confirm_switch et updates_switch
            /*
            confirm_switch.notify["active"].connect(() => {
                config.set_boolean("General", "confirm_quit", confirm_switch.active);
                config.save();
            });
            updates_switch.notify["active"].connect(() => {
                config.set_boolean("General", "auto_updates", updates_switch.active);
                config.save();
            });
            */
        }

        private void add_page_editor() {
            var editor_page = new Adw.PreferencesPage();
            editor_page.set_title(_("Éditeur"));
            editor_page.set_icon_name("text-editor-symbolic");

            var editor_group = new Adw.PreferencesGroup();
            editor_group.set_title(_("Paramètres d'édition"));

            var line_numbers_row = new Adw.ActionRow();
            line_numbers_row.set_title(_("Afficher les numéros de ligne"));
            var line_numbers_switch = new Gtk.Switch();
            line_numbers_switch.set_active(config.get_boolean("Editor", "show_line_numbers", true));
            line_numbers_switch.set_valign(Gtk.Align.CENTER);
            line_numbers_row.add_suffix(line_numbers_switch);
            editor_group.add(line_numbers_row);

            var wrap_lines_row = new Adw.ActionRow();
            wrap_lines_row.set_title(_("Retour à la ligne automatique"));
            var wrap_lines_switch = new Gtk.Switch();
            wrap_lines_switch.set_active(config.get_boolean("Editor", "wrap_lines", true));
            wrap_lines_switch.set_valign(Gtk.Align.CENTER);
            wrap_lines_row.add_suffix(wrap_lines_switch);
            editor_group.add(wrap_lines_row);

            editor_page.add(editor_group);
            add(editor_page);

            // Connecter les signaux
            line_numbers_switch.notify["active"].connect(() => {
                config.set_boolean("Editor", "show_line_numbers", line_numbers_switch.active);
                config.save();
            });

            wrap_lines_switch.notify["active"].connect(() => {
                config.set_boolean("Editor", "wrap_lines", wrap_lines_switch.active);
                config.save();
            });
        }

        private void add_page_explorer() {
            var explorer_page = new Adw.PreferencesPage();
            explorer_page.set_title(_("Explorateur"));
            explorer_page.set_icon_name("folder-symbolic");

            var display_group = new Adw.PreferencesGroup();
            display_group.set_title(_("Affichage"));

            // --- Option Fichiers Cachés ---
            var show_hidden_row = new Adw.ActionRow();
            show_hidden_row.set_title(_("Afficher les fichiers cachés"));
            var show_hidden_switch = new Gtk.Switch();
            show_hidden_switch.set_valign(Gtk.Align.CENTER);
            // Lire l'état initial depuis le modèle (qui lit la config)
            var explorer_model = ApplicationControllerExtension.get_explorer_model(controller);
            show_hidden_switch.set_active(explorer_model.show_hidden_files);
            // Connecter le changement au modèle
            show_hidden_switch.state_set.connect((state) => {
                explorer_model.show_hidden_files = state; // Le setter du modèle sauvegarde la config
                return true;
            });
            show_hidden_row.add_suffix(show_hidden_switch);
            show_hidden_row.set_activatable_widget(show_hidden_switch);
            display_group.add(show_hidden_row);

            // --- Option Fil d'Ariane ---
            var breadcrumb_row = new Adw.ActionRow();
            breadcrumb_row.set_title(_("Afficher le fil d'Ariane"));
            breadcrumb_row.set_subtitle(_("Affiche le chemin de navigation dans l'explorateur"));

            var breadcrumb_switch = new Gtk.Switch();
            breadcrumb_switch.set_valign(Gtk.Align.CENTER);
            breadcrumb_switch.set_active(explorer_model.breadcrumb_enabled); // Lire depuis le modèle

            breadcrumb_switch.state_set.connect((state) => {
                // Mettre à jour le modèle directement
                explorer_model.breadcrumb_enabled = state;
                // Sauvegarder la configuration
                config.set_boolean("Explorer", "breadcrumb_enabled", state);
                config.save();
                return false; // Important pour que le switch change visuellement d'état
            });
            breadcrumb_row.add_suffix(breadcrumb_switch);
            display_group.add(breadcrumb_row);

            // *** NOUVEAU : Option Barre de Recherche ***
            var search_bar_row = new Adw.ActionRow();
            search_bar_row.set_title(_("Afficher la barre de recherche"));
            var search_bar_switch = new Gtk.Switch();
            search_bar_switch.set_active(explorer_model.search_bar_enabled); // Lire depuis le modèle
            search_bar_switch.set_valign(Gtk.Align.CENTER);

            search_bar_switch.state_set.connect((state) => {
                // Mettre à jour le modèle directement
                explorer_model.search_bar_enabled = state;
                // Sauvegarder la configuration
                config.set_boolean("Explorer", "search_bar_enabled", state);
                config.save();
                return false; // Important
            });
            search_bar_row.add_suffix(search_bar_switch);
            display_group.add(search_bar_row);
            // *** FIN NOUVEAU ***

            explorer_page.add(display_group);

            this.add(explorer_page);
        }

        private void add_page_communication() {
            var comm_page = new Adw.PreferencesPage();
            comm_page.set_title(_("Communication"));
            comm_page.set_icon_name("mail-message-new-symbolic");



            var terminal_group = new Adw.PreferencesGroup();
            terminal_group.set_title(_("Terminal"));

            var custom_prompt_row = new Adw.ActionRow();
            custom_prompt_row.set_title(_("Invite personnalisée"));
            var custom_prompt_switch = new Gtk.Switch();
            custom_prompt_switch.set_active(config.get_boolean("Terminal", "custom_prompt", false));
            custom_prompt_switch.set_valign(Gtk.Align.CENTER);
            custom_prompt_row.add_suffix(custom_prompt_switch);
            terminal_group.add(custom_prompt_row);

            comm_page.add(terminal_group);
            add(comm_page);

            // Connecter les signaux
            custom_prompt_switch.notify["active"].connect(() => {
                config.set_boolean("Terminal", "custom_prompt", custom_prompt_switch.active);
                config.save();
            });
        }

        private void add_page_display() {
            var display_page = new Adw.PreferencesPage();
            display_page.set_title(_("Affichage"));
            display_page.set_icon_name("preferences-desktop-display-symbolic");

            var editor_group = new Adw.PreferencesGroup();
            editor_group.set_title(_("Éditeur - Apparence par défaut"));

            // Sélecteur de police
            var font_row = new Adw.ActionRow();
            font_row.set_title(_("Police de l'éditeur"));
            var font_button = new Gtk.FontButton();
            string font_ini = config.get_string("Editor", "font_family", "Sans");
            font_button.set_font(font_ini);
            font_row.add_suffix(font_button);
            editor_group.add(font_row);

            // Sélecteur de taille
            var size_row = new Adw.ActionRow();
            size_row.set_title(_("Taille de police"));
            int size_ini = config.get_integer("Editor", "font_size", 12);
            var size_spin = new Gtk.SpinButton.with_range(6, 48, 1);
            size_spin.set_value(size_ini);
            size_row.add_suffix(size_spin);
            editor_group.add(size_row);

            // Sélecteur de couleur
            var color_row = new Adw.ActionRow();
            color_row.set_title(_("Couleur du texte"));
            var color_button = new Gtk.ColorButton();
            Gdk.RGBA color_ini = Gdk.RGBA();
            color_ini.parse(config.get_string("Editor", "font_color", "#222222"));
            color_button.set_rgba(color_ini);
            color_row.add_suffix(color_button);
            editor_group.add(color_row);

            display_page.add(editor_group);
            add(display_page);

            // --- Connexion des signaux pour sauvegarde et application immédiate ---
            font_button.notify["font"].connect(() => {
                string font = font_button.get_font();
                config.set_string("Editor", "font_family", font);
                config.save();
                controller.apply_editor_style_from_preferences();
            });
            size_spin.value_changed.connect(() => {
                int size = (int)size_spin.get_value();
                config.set_integer("Editor", "font_size", size);
                config.save();
                controller.apply_editor_style_from_preferences();
            });
            color_button.color_set.connect(() => {
                Gdk.RGBA color = color_button.get_rgba();
                config.set_string("Editor", "font_color", color.to_string());
                config.save();
                controller.apply_editor_style_from_preferences();
            });
        }

        private void add_page_theme() {
            var theme_page = new Adw.PreferencesPage();
            theme_page.set_title(_("Thèmes"));
            theme_page.set_icon_name("preferences-desktop-appearance-symbolic");

            var appearance_group = new Adw.PreferencesGroup();
            appearance_group.set_title(_("Apparence"));

            var dark_mode_row = new Adw.ActionRow();
            dark_mode_row.set_title(_("Mode sombre"));
            var dark_mode_switch = new Gtk.Switch();
            dark_mode_switch.set_active(config.get_boolean("Theme", "dark_mode", false));
            dark_mode_switch.set_valign(Gtk.Align.CENTER);
            dark_mode_row.add_suffix(dark_mode_switch);
            appearance_group.add(dark_mode_row);

            var accent_color_row = new Adw.ActionRow();
            accent_color_row.set_title(_("Couleur d'accentuation"));

            var accent_button = new Gtk.ColorButton();
            Gdk.RGBA accent_color = Gdk.RGBA();
            accent_color.parse(config.get_string("Theme", "accent_color", "#3584e4"));
            accent_button.set_rgba(accent_color);
            accent_button.set_valign(Gtk.Align.CENTER);
            accent_color_row.add_suffix(accent_button);
            appearance_group.add(accent_color_row);

            theme_page.add(appearance_group);
            add(theme_page);

            // Connecter les signaux
            dark_mode_switch.notify["active"].connect(() => {
                config.set_boolean("Theme", "dark_mode", dark_mode_switch.active);
                config.save();

                // Appliquer immédiatement le thème
                var style_manager = Adw.StyleManager.get_default();
                style_manager.color_scheme = dark_mode_switch.active ?
                    Adw.ColorScheme.FORCE_DARK : Adw.ColorScheme.FORCE_LIGHT;
            });

            accent_button.color_set.connect(() => {
                Gdk.RGBA color = accent_button.get_rgba();
                string color_string = color.to_string();
                config.set_string("Theme", "accent_color", color_string);
                config.save();
                // TODO: Appliquer la couleur d'accentuation
            });
        }

        private void add_page_extensions() {
            var extensions_page = new Adw.PreferencesPage();
            extensions_page.set_title(_("Extensions"));
            extensions_page.set_icon_name("application-x-addon-symbolic");

            // Placeholder pour la future gestion des extensions
            var placeholder_group = new Adw.PreferencesGroup();
            placeholder_group.set_title(_("Extensions disponibles"));
            placeholder_group.set_description(_("Aucune extension n'est actuellement installée"));

            extensions_page.add(placeholder_group);
            add(extensions_page);
        }

        /**
         * Crée et configure l'onglet des préférences générales d'interface
         */
        private Adw.PreferencesPage create_interface_page() {
            var page = new Adw.PreferencesPage();
            page.set_title(_("Interface"));
            page.set_icon_name("preferences-desktop-display-symbolic");

            // Groupe général
            var general_group = new Adw.PreferencesGroup();
            general_group.set_title(_("Général"));
            page.add(general_group);

            // Option pour l'explorateur détaché
            var detached_row = new Adw.ActionRow();
            detached_row.set_title(_("Explorateur détaché"));
            detached_row.set_subtitle(_("Afficher l'explorateur dans une fenêtre séparée"));

            var detached_switch = new Gtk.Switch();
            detached_switch.set_active(controller.is_using_detached_explorer());
            detached_switch.set_valign(Gtk.Align.CENTER);

            // MODIFIER: Correction du gestionnaire d'événement pour sauvegarder le paramètre
            detached_switch.state_set.connect((state) => {
                // Modifier le paramètre via le contrôleur
                controller.set_detached_explorer(state);

                // Informer l'utilisateur qu'un redémarrage est nécessaire
                var dialog = new Adw.AlertDialog(
                    _("Redémarrage nécessaire"),
                    _("Ce changement nécessite un redémarrage de l'application pour prendre effet.")
                );
                dialog.add_response("ok", _("OK"));
                dialog.present(this.get_root() as Gtk.Window);

                return true; // Accepter le changement d'état
            });

            detached_row.add_suffix(detached_switch);
            detached_row.set_activatable_widget(detached_switch);
            general_group.add(detached_row);

            // Autres options...
            return page;
        }

        private void add_page_ai() {
            var ai_page = new Adw.PreferencesPage();
            ai_page.set_title(_("IA"));
            ai_page.set_icon_name("applications-science-symbolic");

            // --- Groupe Modèles IA ---
            var models_group = new Adw.PreferencesGroup();
            models_group.set_title(_("Modèles IA"));
            models_group.set_description(_("Configuration pour la gestion des modèles d'intelligence artificielle. La clé API est optionnelle mais recommandée."));

            // Clé API HuggingFace
            var api_key_row = new Adw.PasswordEntryRow();
            api_key_row.set_title(_("Clé API HuggingFace (optionnelle)"));
            api_key_row.set_text(config.get_string("AI", "huggingface_token", ""));

            // Bouton de validation de la clé
            var validate_button = new Gtk.Button.from_icon_name("network-wireless-symbolic");
            validate_button.set_valign(Gtk.Align.CENTER);
            validate_button.set_tooltip_text(_("Valider la clé API"));
            validate_button.add_css_class("flat");

            var status_icon = new Gtk.Image.from_icon_name("dialog-question-symbolic");
            status_icon.set_valign(Gtk.Align.CENTER);
            status_icon.set_tooltip_text(_("Statut de la connexion"));

            api_key_row.add_suffix(validate_button);
            api_key_row.add_suffix(status_icon);
            models_group.add(api_key_row);

            // Lien vers la création de token
            var hf_help_row = new Adw.ActionRow();
            hf_help_row.set_title(_("Obtenir une clé API"));
            var hf_link_button = new Gtk.LinkButton.with_label("https://huggingface.co/settings/tokens", _("Créer un token sur HuggingFace"));
            hf_link_button.set_valign(Gtk.Align.CENTER);
            hf_help_row.add_suffix(hf_link_button);
            models_group.add(hf_help_row);

            // Répertoire des modèles
            var models_dir_row = new Adw.ActionRow();
            models_dir_row.set_title(_("Répertoire de base des modèles"));
            models_dir_row.set_subtitle(_("Emplacement où sont stockés les modèles IA téléchargés"));

            var current_models_dir = config.get_string("AI", "models_base_directory",
                Path.build_filename(Environment.get_home_dir(), ".local", "share", "sambo", "models"));

            var models_dir_button = new Gtk.Button.with_label(Path.get_basename(current_models_dir));
            models_dir_button.set_valign(Gtk.Align.CENTER);
            models_dir_button.clicked.connect(() => {
                var file_dialog = new Gtk.FileDialog();
                file_dialog.set_modal(true);
                file_dialog.set_title(_("Choisir le répertoire des modèles"));

                file_dialog.select_folder.begin(this, null, (obj, res) => {
                    try {
                        var file = file_dialog.select_folder.end(res);
                        if (file != null) {
                            var path = file.get_path();
                            config.set_string("AI", "models_base_directory", path);
                            models_dir_button.set_label(Path.get_basename(path));
                        }
                    } catch (Error e) {
                        warning("Erreur lors de la sélection du répertoire: %s", e.message);
                    }
                });
            });
            models_dir_row.add_suffix(models_dir_button);
            models_group.add(models_dir_row);

            // Nombre de modèles à charger
            var models_limit_row = new Adw.ActionRow();
            models_limit_row.set_title(_("Nombre de modèles à charger"));
            models_limit_row.set_subtitle(_("Nombre maximum de modèles affichés (25-1000)"));

            var models_limit_spin = new Gtk.SpinButton.with_range(25, 1000, 25);
            models_limit_spin.set_value(config.get_integer("AI", "models_limit", 50));
            models_limit_spin.set_valign(Gtk.Align.CENTER);
            models_limit_row.add_suffix(models_limit_spin);
            models_group.add(models_limit_row);

            // Option pour n'afficher que les modèles téléchargeables
            var downloadable_only_row = new Adw.ActionRow();
            downloadable_only_row.set_title(_("Afficher uniquement les modèles téléchargeables"));
            downloadable_only_row.set_subtitle(_("Masquer les modèles sans fichiers téléchargeables ou avec restrictions"));

            var downloadable_only_switch = new Gtk.Switch();
            downloadable_only_switch.set_active(config.get_boolean("AI", "show_downloadable_only", false));
            downloadable_only_switch.set_valign(Gtk.Align.CENTER);
            downloadable_only_row.add_suffix(downloadable_only_switch);
            models_group.add(downloadable_only_row);

            // Option pour le nombre de téléchargements simultanés
            var concurrent_downloads_row = new Adw.ActionRow();
            concurrent_downloads_row.set_title(_("Téléchargements simultanés"));
            concurrent_downloads_row.set_subtitle(_("Nombre de fichiers téléchargés en parallèle (1-6)"));

            var concurrent_downloads_spin = new Gtk.SpinButton.with_range(1, 6, 1);
            concurrent_downloads_spin.set_value(config.get_integer("AI", "max_concurrent_downloads", 3));
            concurrent_downloads_spin.set_valign(Gtk.Align.CENTER);
            concurrent_downloads_row.add_suffix(concurrent_downloads_spin);
            models_group.add(concurrent_downloads_row);

            // Timeout de génération
            var timeout_row = new Adw.ActionRow();
            timeout_row.set_title(_("Timeout de génération"));
            timeout_row.set_subtitle(_("Délai d'attente maximum pour la génération (0 = infini)"));

            var timeout_spin = new Gtk.SpinButton.with_range(0, 300, 5);
            timeout_spin.set_value(config.get_generation_timeout());
            timeout_spin.set_valign(Gtk.Align.CENTER);
            timeout_spin.set_tooltip_text(_("Timeout en secondes (0 pour pas de limite)"));
            timeout_row.add_suffix(timeout_spin);

            // Label pour afficher "infini" quand c'est 0
            var timeout_label = new Gtk.Label("");
            timeout_label.set_valign(Gtk.Align.CENTER);
            timeout_label.add_css_class("dim-label");
            timeout_row.add_suffix(timeout_label);

            // Fonction pour mettre à jour le label
            void update_timeout_label() {
                int value = (int)timeout_spin.get_value();
                if (value == 0) {
                    timeout_label.set_text(_("(infini)"));
                } else {
                    timeout_label.set_text(_("%d sec").printf(value));
                }
            }
            update_timeout_label();

            timeout_spin.value_changed.connect(() => {
                update_timeout_label();
                config.set_generation_timeout((int)timeout_spin.get_value());
                config.save();
            });

            models_group.add(timeout_row);

            ai_page.add(models_group);

            // --- Connecter les signaux ---

            // Signal pour la clé API
            api_key_row.changed.connect(() => {
                config.set_string("AI", "huggingface_token", api_key_row.get_text());
            });

            // Signal pour le nombre de modèles
            models_limit_spin.value_changed.connect(() => {
                config.set_integer("AI", "models_limit", (int)models_limit_spin.get_value());
            });

            // Signal pour l'option "modèles téléchargeables uniquement"
            downloadable_only_switch.notify["active"].connect(() => {
                config.set_boolean("AI", "show_downloadable_only", downloadable_only_switch.get_active());
            });

            // Signal pour le nombre de téléchargements simultanés
            concurrent_downloads_spin.value_changed.connect(() => {
                config.set_integer("AI", "max_concurrent_downloads", (int)concurrent_downloads_spin.get_value());
            });

            add(ai_page);
        }
    }
}
