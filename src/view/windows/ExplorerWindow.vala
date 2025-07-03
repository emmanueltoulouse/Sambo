using Gtk;
using Adw;
using GLib;

namespace Sambo {
    /**
     * Fenêtre indépendante pour l'explorateur de fichiers
     * Permet d'utiliser l'explorateur séparément de la fenêtre principale
     */
    public class ExplorerWindow : Adw.ApplicationWindow {
        private ApplicationController controller;
        private ExplorerView explorer_view;
        private Adw.ToastOverlay toast_overlay;

        // Signaux pour la communication avec la fenêtre principale
        public signal void file_activated(string path);
        public signal void directory_changed(string path);

        // Constructeur amélioré
        public ExplorerWindow(Adw.Application app, ApplicationController controller) {
            Object(
                application: app,
                title: _("Sambo Explorateur"),
                default_width: 350,
                default_height: 600
            );

            this.controller = controller;


            // Initialiser l'interface directement
            setup_ui();
            setup_actions();
            load_config();

            // Style de la fenêtre pour les bords arrondis
            this.add_css_class("rounded");

            // Personnaliser l'apparence des onglets
            customize_tab_appearance();

            // Gestionnaires d'événements
            this.map.connect(on_map);
            this.close_request.connect(() => {
                return on_close_request();
            });


            // AJOUTER: S'assurer que la fenêtre est visible lors de sa création
            this.show();
        }

        /**
         * Initialise l'interface utilisateur avec le style de l'éditeur
         */
        private void setup_ui() {
            // Créer un overlay pour les notifications toast comme dans l'éditeur
            toast_overlay = new Adw.ToastOverlay();

            // Boîte principale avec les mêmes marges que l'éditeur
            var main_box = new Box(Orientation.VERTICAL, 0);

            // En-tête avec style cohérent avec l'éditeur
            var header_bar = new Adw.HeaderBar();
            header_bar.add_css_class("flat");

            // Boutons de la barre d'outils
            var refresh_button = new Button.from_icon_name("view-refresh-symbolic");
            refresh_button.add_css_class("flat");
            refresh_button.set_tooltip_text(_("Rafraîchir"));
            header_bar.pack_start(refresh_button);

            var search_button = new ToggleButton();
            search_button.set_icon_name("system-search-symbolic");
            search_button.add_css_class("flat");
            search_button.set_tooltip_text(_("Rechercher"));
            header_bar.pack_start(search_button);

            var up_button = new Button.from_icon_name("go-up-symbolic");
            up_button.add_css_class("flat");
            up_button.set_tooltip_text(_("Dossier parent"));
            header_bar.pack_start(up_button);

            // Menu d'options
            var menu_button = new MenuButton();
            menu_button.set_icon_name("view-more-symbolic");
            menu_button.add_css_class("flat");
            menu_button.set_tooltip_text(_("Options"));
            menu_button.set_menu_model(build_app_menu());
            header_bar.pack_end(menu_button);

            main_box.append(header_bar);

            // Ajouter un libellé de vérification
            var verification_box = new Box(Orientation.HORIZONTAL, 0);
            verification_box.add_css_class("view");
            verification_box.set_margin_start(12);
            verification_box.set_margin_end(12);
            verification_box.set_margin_top(12);
            verification_box.set_margin_bottom(6);

            var verification_label = new Label(_("Explorateur détaché - Design harmonisé"));
            verification_label.add_css_class("title-4");
            verification_label.set_halign(Align.CENTER);
            verification_label.set_hexpand(true);

            verification_box.append(verification_label);
            main_box.append(verification_box);

            // Vue de l'explorateur
            var explorer_model = ApplicationControllerExtension.get_explorer_model(controller);

            explorer_view = new ExplorerView(explorer_model);

            // Styliser la vue de l'explorateur
            explorer_view.add_css_class("view");
            explorer_view.add_css_class("frame");
            explorer_view.set_margin_start(12);
            explorer_view.set_margin_end(12);
            explorer_view.set_margin_bottom(12);

            main_box.append(explorer_view);

            // Définir le contenu de la fenêtre
            toast_overlay.set_child(main_box);
            this.set_content(toast_overlay);

            // Connecter les signaux des boutons
            refresh_button.clicked.connect(() => {
                var model = ApplicationControllerExtension.get_explorer_model(controller);
                model.refresh();
            });

            up_button.clicked.connect(() => {
                navigate_to_parent();
            });

            search_button.toggled.connect(() => {
                toggle_search(search_button.active);
            });

            // Connecter les signaux de l'explorateur
            if (explorer_view != null) {
                //explorer_view.file_selected.connect((path) => {
                //    file_activated(path);
                //});

                explorer_view.directory_changed.connect((path) => {
                    directory_changed(path);
                });
            }
        }

        /**
         * Active ou désactive la recherche
         */
        private void toggle_search(bool active) {
            if (active) {
                var search_bar = get_search_bar();
                if (search_bar != null) {
                    search_bar.set_visible(true);
                    search_bar.set_search_mode(true);

                    // Trouver l'entrée de recherche et la focus
                    var search_entry = find_search_entry(search_bar);
                    if (search_entry != null) {
                        search_entry.grab_focus();
                    }
                }
            } else {
                var search_bar = get_search_bar();
                if (search_bar != null) {
                    search_bar.set_visible(false);
                    search_bar.set_search_mode(false);

                    // Effacer la recherche
                    var search_entry = find_search_entry(search_bar);
                    if (search_entry != null) {
                        search_entry.set_text("");
                    }
                }
            }
        }

        /**
         * Trouve la barre de recherche dans la vue explorateur
         */
        private Gtk.SearchBar? get_search_bar() {
            // Parcourir les enfants de explorer_view pour trouver SearchBar
            var child = explorer_view.get_first_child();
            while (child != null) {
                if (child is Gtk.SearchBar) {
                    return child as Gtk.SearchBar;
                }
                // Vérifier aussi dans les conteneurs
                if (child is Gtk.Box) {
                    var search_bar = find_widget_in_container(child, typeof(Gtk.SearchBar)) as Gtk.SearchBar;
                    if (search_bar != null) {
                        return search_bar;
                    }
                }
                child = child.get_next_sibling();
            }
            return null;
        }

        /**
         * Trouve l'entrée de recherche dans la barre de recherche
         */
        private Gtk.SearchEntry? find_search_entry(Gtk.SearchBar search_bar) {
            var child = search_bar.get_first_child();
            while (child != null) {
                if (child is Gtk.SearchEntry) {
                    return child as Gtk.SearchEntry;
                }
                // Vérifier aussi dans les conteneurs
                if (child is Gtk.Box) {
                    var search_entry = find_widget_in_container(child, typeof(Gtk.SearchEntry)) as Gtk.SearchEntry;
                    if (search_entry != null) {
                        return search_entry;
                    }
                }
                child = child.get_next_sibling();
            }
            return null;
        }

        /**
         * Recherche récursivement un widget dans un conteneur
         */
        private Gtk.Widget? find_widget_in_container(Gtk.Widget container, Type widget_type) {
            // Check if this widget has any children
            var child = container.get_first_child();
            if (child == null) {
                return null;
            }

            // Continue searching through the children
            child = container.get_first_child();
            while (child != null) {
                if (child.get_type().is_a(widget_type)) {
                    return child;  // Return the child if it's the right type
                }

                // Check if this child has its own children
                if (child.get_first_child() != null) {
                    var result = find_widget_in_container(child, widget_type);
                    if (result != null) {
                        return result;
                    }
                }

                child = child.get_next_sibling();
            }

            return null;
        }

        /**
         * Navigue vers le dossier parent
         */
        private void navigate_to_parent() {
            var model = ApplicationControllerExtension.get_explorer_model(controller);
            var current_dir = model.get_current_directory();

            if (current_dir != null) {
                var parent_dir = current_dir.get_parent();
                if (parent_dir != null) {
                    model.navigate_to(parent_dir.get_path());
                } else {
                    // Si nous sommes à la racine, afficher un toast
                    show_toast(_("Vous êtes déjà au niveau le plus haut"));
                }
            }
        }

        /**
         * Affiche un toast avec le message donné
         */
        private void show_toast(string message) {
            var toast = new Adw.Toast(message);
            toast.set_timeout(2);
            toast_overlay.add_toast(toast);
        }

        /**
         * Construit le menu de l'application
         */
        private GLib.MenuModel build_app_menu() {
            var menu = new GLib.Menu();

            // Menu Fichier
            var file_menu = new GLib.Menu();
            file_menu.append(_("Nouveau dossier"), "win.new-folder");
            file_menu.append(_("Actualiser"), "win.refresh");

            // Menu Affichage
            var view_menu = new GLib.Menu();
            view_menu.append(_("Afficher les fichiers cachés"), "win.show-hidden");
            view_menu.append(_("Prévisualisation"), "win.show-preview");

            // Menu Outils
            var tools_menu = new GLib.Menu();
            tools_menu.append(_("Recherche avancée"), "win.advanced-search");

            // Ajout des menus principaux
            menu.append_submenu(_("Fichier"), file_menu);
            menu.append_submenu(_("Affichage"), view_menu);
            menu.append_submenu(_("Outils"), tools_menu);

            return menu;
        }

        /**
         * Configure les actions de la fenêtre
         */
        private void setup_actions() {
            // Action pour créer un nouvel onglet
            var new_tab_action = new SimpleAction("new-tab", null);
            new_tab_action.activate.connect(() => {
                var model = ApplicationControllerExtension.get_explorer_model(controller);
                model.navigate_to(Environment.get_home_dir());
            });

            // Action pour la recherche avancée
            var advanced_search_action = new SimpleAction("advanced-search", null);
            advanced_search_action.activate.connect(() => {
                var file_dialog = new FileDialog();
                file_dialog.set_title(_("Sélectionnez un dossier pour la recherche"));

                var folder_filter = new FileFilter();
                folder_filter.add_mime_type("inode/directory");

                var filters = new GLib.ListStore(typeof(FileFilter));
                filters.append(folder_filter);
                file_dialog.set_filters(filters);

                file_dialog.select_folder.begin(this, null, (obj, res) => {
                    try {
                        var folder = file_dialog.select_folder.end(res);
                        if (folder != null) {
                            string folder_path = folder.get_path();
                            var model = ApplicationControllerExtension.get_explorer_model(controller);
                            model.navigate_to(folder_path);

                            var adv_dialog = new AdvancedSearchDialog(this, controller);
                            adv_dialog.set_search_folder(folder_path);
                            adv_dialog.present();
                        }
                    } catch (Error e) {
                        warning(_("Erreur lors de la sélection du dossier: %s"), e.message);
                    }
                });
            });

            // Action pour les préférences
            var preferences_action = new SimpleAction("preferences", null);
            preferences_action.activate.connect(() => {
                var dialog = new Adw.AlertDialog(
                    _("Préférences de l'explorateur"),
                    _("Cette fenêtre de préférences est en cours d'implémentation.")
                );
                dialog.add_response("ok", _("OK"));
                dialog.present(this);
            });

            // Action pour fermer la fenêtre
            var close_action = new SimpleAction("close", null);
            close_action.activate.connect(() => {
                this.close();
            });

            // Action pour actualiser
            var refresh_action = new SimpleAction("refresh", null);
            refresh_action.activate.connect(() => {
                var model = ApplicationControllerExtension.get_explorer_model(controller);
                model.refresh();
            });

            // Action pour afficher/masquer les fichiers cachés
            var show_hidden_action = new SimpleAction("show-hidden", null);
            show_hidden_action.activate.connect(() => {
                var config = controller.get_config_manager();
                bool current = config.get_boolean("Explorer", "show_hidden_files", false);
                config.set_boolean("Explorer", "show_hidden_files", !current);
                config.save();

                var model = ApplicationControllerExtension.get_explorer_model(controller);
                model.refresh();

                show_toast(current ? _("Fichiers cachés masqués") : _("Fichiers cachés affichés"));
            });

            // Ajouter les actions à la fenêtre
            this.add_action(new_tab_action);
            this.add_action(advanced_search_action);
            this.add_action(preferences_action);
            this.add_action(close_action);
            this.add_action(refresh_action);
            this.add_action(show_hidden_action);
        }

        /**
         * Gère la demande de fermeture de la fenêtre
         */
        private bool on_close_request() {
            // Masquer la fenêtre au lieu de la détruire
            this.hide();
            // Informer le contrôleur que la fenêtre est maintenant masquée
            // Cela mettra à jour l'état du bouton dans MainWindow
            controller.toggle_explorer_visibility(false);

            // Sauvegarder la configuration (peut être redondant si déjà fait ailleurs)
            save_config();

            // Retourner true pour empêcher la fermeture/destruction par défaut
            return true;
        }

        public override bool close_request() {
            // Sauvegarder la taille de la fenêtre avant fermeture
            int width, height;
            this.get_default_size(out width, out height);
            var config = controller.get_config_manager();
            config.set_integer("ExplorerWindow", "width", width);
            config.set_integer("ExplorerWindow", "height", height);
            config.save();
            return base.close_request();
        }

        /**
         * Gestionnaire du signal map
         */
        private void on_map() {
            var model = ApplicationControllerExtension.get_explorer_model(controller);
            if (model.get_current_directory() != null) {
                model.refresh();
            } else {
                // Navigate to home directory if no path is set
                model.navigate_to(Environment.get_home_dir());
            }
        }

        /**
         * Charge les paramètres de configuration pour l'explorateur
         */
        private void load_config() {
            var config = controller.get_config_manager();

            // Restaurer la taille et la position de la fenêtre
            int width = config.get_integer("ExplorerWindow", "width", 800);
            int height = config.get_integer("ExplorerWindow", "height", 600);
            this.set_default_size(width, height);

            // --- AJOUT : Restaurer la position ---
            int pos_x = config.get_integer("ExplorerWindow", "pos_x", -1);
            int pos_y = config.get_integer("ExplorerWindow", "pos_y", -1);
            if (pos_x >= 0 && pos_y >= 0) {
                // Manual window positioning isn’t supported in GTK4/Libadwaita; ignoring saved position
            }

            // Restaurer d'autres paramètres si nécessaire
            if (config.get_boolean("Explorer", "remember_last_directory", true)) {
                string last_dir = config.get_string("Explorer", "last_directory", Environment.get_home_dir());
                if (FileUtils.test(last_dir, FileTest.IS_DIR)) {
                    var model = ApplicationControllerExtension.get_explorer_model(controller);
                    model.navigate_to(last_dir);
                }
            }
        }

        /**
         * Sauvegarde les paramètres de configuration
         */
        private void save_config() {
            var config = controller.get_config_manager();

            // Sauvegarder la taille de la fenêtre
            int width, height;
            this.get_default_size(out width, out height);
            config.set_integer("ExplorerWindow", "width", width);
            config.set_integer("ExplorerWindow", "height", height);

            // Sauvegarder le répertoire actuel
            var model = ApplicationControllerExtension.get_explorer_model(controller);
            var current_dir = model.get_current_directory();
            if (current_dir != null) {
                config.set_string("Explorer", "last_directory", current_dir.get_path());
            }

            config.save();
        }

        /**
         * Navigue vers un répertoire dans l'explorateur
         */
        public void navigate_to_directory(string path) {
            if (explorer_view != null) {
                explorer_view.navigate_to_directory(path);
            }
        }

        /**
         * Retourne la vue explorateur
         */
        public ExplorerView get_explorer_view() {
            return explorer_view;
        }

        /**
         * Personnalise l'apparence des onglets pour qu'ils ressemblent à ceux de l'éditeur
         */
        private void customize_tab_appearance() {
            // Trouver la barre d'onglets dans explorer_view
            unowned Gtk.Box? tab_bar = null;

            var child = explorer_view.get_first_child();
            while (child != null) {
                if (child is Gtk.Box && child.get_name() == "tab_bar") {
                    tab_bar = child as Gtk.Box;
                    break;
                }
                child = child.get_next_sibling();
            }

            if (tab_bar != null) {
                // Ajouter les classes CSS pour qu'elle ressemble à celle de l'éditeur
                tab_bar.add_css_class("inline-toolbar");
                tab_bar.add_css_class("toolbar");

                tab_bar.set_margin_start(6);
                tab_bar.set_margin_end(6);
                tab_bar.set_margin_top(6);
                tab_bar.set_margin_bottom(0);

                var tab_button = tab_bar.get_first_child();
                while (tab_button != null) {
                    if (tab_button is Gtk.ToggleButton) {
                        tab_button.add_css_class("flat");
                        tab_button.add_css_class("tab-button");
                    }
                    tab_button = tab_button.get_next_sibling();
                }
            }
        }

        // MODIFIER: S'assurer que la fenêtre est affichée correctement
        public void initialize() {
            // Code existant...

            // AJOUTER: S'assurer que la fenêtre est bien présentée
            this.present();
        }
    }

    /**
     * Dialogue de recherche avancée
     */
    public class AdvancedSearchDialog : Adw.Window {
        private ApplicationController controller;
        private string search_folder = "";

        // Widgets pour l'interface
        private Entry search_entry;
        private CheckButton case_sensitive_check;
        private CheckButton regex_check;
        private CheckButton search_content_check;
        private Entry extension_filter_entry;
        private Button search_button;
        private Gtk.Spinner spinner;

        /**
         * Crée une nouvelle boîte de dialogue de recherche avancée
         */
        public AdvancedSearchDialog(Adw.ApplicationWindow parent, ApplicationController controller) {
            Object(
                transient_for: parent,
                title: _("Recherche avancée"),
                modal: true,
                width_request: 450,
                height_request: 350
            );

            this.controller = controller;

            create_ui();
        }

        /**
         * Définit le dossier de recherche
         */
        public void set_search_folder(string folder) {
            this.search_folder = folder;

            // Mettre à jour le titre avec le dossier
            this.set_title(_("Rechercher dans: %s").printf(Path.get_basename(folder)));
        }

        /**
         * Crée l'interface utilisateur
         */
        private void create_ui() {
            var content_box = new Box(Orientation.VERTICAL, 12);
            content_box.set_margin_top(12);
            content_box.set_margin_bottom(12);
            content_box.set_margin_start(12);
            content_box.set_margin_end(12);

            // Zone de recherche
            var search_box = new Box(Orientation.VERTICAL, 6);

            var search_label = new Label(_("Rechercher:"));
            search_label.set_halign(Align.START);

            search_entry = new Entry();
            search_entry.set_placeholder_text(_("Terme de recherche..."));
            search_entry.set_hexpand(true);

            search_box.append(search_label);
            search_box.append(search_entry);

            // Options de recherche
            var options_box = new Box(Orientation.VERTICAL, 6);
            options_box.set_margin_top(6);

            var options_label = new Label(_("Options de recherche:"));
            options_label.set_halign(Align.START);

            case_sensitive_check = new CheckButton.with_label(_("Respecter la casse"));
            regex_check = new CheckButton.with_label(_("Utiliser des expressions régulières"));
            search_content_check = new CheckButton.with_label(_("Rechercher dans le contenu des fichiers"));

            options_box.append(options_label);
            options_box.append(case_sensitive_check);
            options_box.append(regex_check);
            options_box.append(search_content_check);

            // Filtres d'extension
            var filter_box = new Box(Orientation.VERTICAL, 6);
            filter_box.set_margin_top(6);

            var filter_label = new Label(_("Filtrer par extension (séparées par des virgules):"));
            filter_label.set_halign(Align.START);

            extension_filter_entry = new Entry();
            extension_filter_entry.set_placeholder_text(_("txt, md, c, h, vala..."));

            filter_box.append(filter_label);
            filter_box.append(extension_filter_entry);

            // Boutons d'action
            var button_box = new Box(Orientation.HORIZONTAL, 6);
            button_box.set_margin_top(12);
            button_box.set_halign(Align.END);

            spinner = new Gtk.Spinner();

            var cancel_button = new Button.with_label(_("Annuler"));
            cancel_button.clicked.connect(() => {
                this.close();
            });

            search_button = new Button.with_label(_("Rechercher"));
            search_button.add_css_class("suggested-action");
            search_button.clicked.connect(start_search);

            button_box.append(spinner);
            button_box.append(cancel_button);
            button_box.append(search_button);

            // Assembler l'interface
            content_box.append(search_box);
            content_box.append(options_box);
            content_box.append(filter_box);
            content_box.append(button_box);

            this.set_content(content_box);
        }

        /**
         * Démarre la recherche
         */
        private void start_search() {
            string search_term = search_entry.get_text();
            if (search_term.strip() == "") {
                // Afficher une alerte si aucun terme de recherche
                var alert = new Adw.AlertDialog(
                    _("Terme de recherche requis"),
                    _("Veuillez entrer un terme à rechercher.")
                );
                alert.add_response("ok", _("OK"));
                alert.present(this);
                return;
            }

            // Désactiver l'interface pendant la recherche
            search_button.set_sensitive(false);
            spinner.start();

            // Lancer la recherche dans un thread pour ne pas bloquer l'interface
            new Thread<void*> ("search_thread", () => {
                // Simuler une recherche (à remplacer par la vraie implémentation)
                Thread.usleep(1000000); // 1 seconde

                // Le résultat final doit être traité dans le thread principal
                Idle.add(() => {
                    // Réactiver l'interface
                    search_button.set_sensitive(true);
                    spinner.stop();

                    // Afficher un résultat factice pour démonstration
                    var alert = new Adw.AlertDialog(
                        _("Résultats de recherche"),
                        _("Recherche terminée pour \"%s\".\nImplémentation réelle à venir.").printf(search_term)
                    );
                    alert.add_response("ok", _("OK"));
                    alert.present(this);

                    return false; // Ne pas répéter
                });

                return null;
            });
        }
    }
}
