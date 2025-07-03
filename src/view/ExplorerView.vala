/* ExplorerView.vala
 *
 * Copyright 2023
 */

using Gtk;
using Gdk;
using GLib;
using Adw;
using Gee;
// Import du widget ExtensionFilterChips
// using Sambo;    // removed: conflicts with the namespace defined below

// Gio est déjà disponible via GLib, pas besoin de l'importer séparément

namespace Sambo {
    // Classes nécessaires pour l'explorateur de fichiers

    /**
     * Classe pour stocker les informations sur les extensions de fichiers
     */
    public class ExtensionInfo : GLib.Object {
        public string extension { get; set; }
        public string label { get; set; }

        public ExtensionInfo(string extension, string label) {
            this.extension = extension;
            this.label = label;
        }
    }

    /**
     * Vue pour afficher et gérer les favoris
     */
    public class FavoritesView : Gtk.Box {
        private ApplicationController controller;

        // Signal émis lorsqu'un favori est sélectionné
        public signal void favorite_selected(string path);

        public FavoritesView(ApplicationController controller) {
            Object(orientation: Orientation.VERTICAL, spacing: 6);
            this.controller = controller;

            var label = new Label("Favoris");
            label.add_css_class("title-4");
            this.append(label);

            var scroll = new ScrolledWindow();
            scroll.set_vexpand(true);

            var listbox = new ListBox();
            listbox.add_css_class("navigation-sidebar");

            scroll.set_child(listbox);
            this.append(scroll);

            // Initialiser les favoris
            refresh_favorites();
        }

        /**
         * Rafraîchit la liste des favoris
         */
        public void refresh_favorites() {
            // À implémenter correctement selon la structure du modèle
            // Cette implémentation est un placeholder
        }
    }

    /**
     * Vue pour afficher et gérer l'historique récent
     */
    public class RecentHistoryView : Gtk.Box {
        private ApplicationController controller;

        // Signal émis lorsqu'un élément d'historique est sélectionné
        public signal void history_item_selected(string path);

        public RecentHistoryView(ApplicationController controller) {
            Object(orientation: Orientation.VERTICAL, spacing: 6);
            this.controller = controller;

            var label = new Label("Historique");
            label.add_css_class("title-4");
            this.append(label);

            var scroll = new ScrolledWindow();
            scroll.set_vexpand(true);

            var listbox = new ListBox();
            listbox.add_css_class("navigation-sidebar");

            scroll.set_child(listbox);
            this.append(scroll);

            // Initialiser l'historique
            refresh_history();
        }

        /**
         * Rafraîchit la liste de l'historique
         */
        public void refresh_history() {
            // À implémenter correctement selon la structure du modèle
            // Cette implémentation est un placeholder
        }
    }

    /**
     * Extension de la classe ApplicationController pour ajouter des méthodes d'accès
     */
    public class ApplicationControllerExtension {
        // Champ statique pour stocker le modèle explorateur
        private static ExplorerModel? _explorer_model = null;

        // Méthode d'accès au modèle explorateur
        public static ExplorerModel get_explorer_model(ApplicationController controller) {
            // Utiliser un champ statique pour stocker le modèle au lieu d'accéder à une propriété inexistante
            if (_explorer_model != null) {
                return _explorer_model;
            } else {
                // Create a new model if none exists
                var model = new ExplorerModel(controller);
                _explorer_model = model;
                return model;
            }
        }
    }

    public class ExplorerView : Gtk.Box {
        public signal void file_selected(string path);
        public signal void directory_changed(string path);

        private ApplicationController controller;
        private ExplorerModel? model;

        // UI Components
        private Box toolbar;
        private GLib.ListStore list_store;
        private ListView list_view;
        private Button ext_filter_button;
        private Popover? ext_filter_popover = null;
        private ExtensionFilterChips? ext_filter_chips = null;
        private HashSet<string> selected_extensions = new HashSet<string>();
        private ConfigManager config_manager;
        private string current_path;

        public ExplorerView(ExplorerModel? model_param) {
            Object(orientation: Gtk.Orientation.VERTICAL, spacing: 0);

            this.model = model_param;

            // Sécurité en cas de modèle null
            if (this.model != null) {
                this.controller = model.get_controller();
                this.config_manager = controller.get_config_manager();
            } else {
                warning("ExplorerModel est NULL dans ExplorerView");
                // Provide dummy or default values for ApplicationModel and Gtk.Application
                this.controller = new ApplicationController(null, (Gtk.Application)GLib.Application.get_default());
                this.config_manager = new ConfigManager();
            }

            // Initialiser le chemin actuel (HOME par défaut)
            current_path = Environment.get_home_dir();

            // Styles de base
            this.add_css_class("view");
            this.set_margin_start(12);
            this.set_margin_end(12);
            this.set_margin_top(12);
            this.set_margin_bottom(12);

            // Chargement des extensions sauvegardées
            load_saved_extensions();

            // Barre d'outils simplifiée
            create_toolbar();

            // Liste des fichiers
            create_file_list();

            // Charger le contenu initial
            refresh_directory_content();
        }

        private void create_toolbar() {
            toolbar = new Box(Orientation.HORIZONTAL, 6);
            toolbar.add_css_class("toolbar");

            // Filtre par extension
            ext_filter_button = new Button.from_icon_name("edit-find-symbolic");
            ext_filter_button.set_tooltip_text(_("Filtrer par extension"));
            ext_filter_button.add_css_class("flat");

            // Bouton dossier parent
            var up_button = new Button.from_icon_name("go-up-symbolic");
            up_button.set_tooltip_text(_("Dossier parent"));
            up_button.add_css_class("flat");

            // Bouton actualiser
            var refresh_button = new Button.from_icon_name("view-refresh-symbolic");
            refresh_button.set_tooltip_text(_("Actualiser"));
            refresh_button.add_css_class("flat");

            // Bouton accueil
            var home_button = new Button.from_icon_name("user-home-symbolic");
            home_button.set_tooltip_text(_("Dossier personnel"));
            home_button.add_css_class("flat");

            // Connecter les signaux
            up_button.clicked.connect(() => {
                File parent = File.new_for_path(current_path).get_parent();
                if (parent != null) {
                    current_path = parent.get_path();
                    if (model != null) model.navigate_to(current_path);
                    refresh_directory_content();
                    directory_changed(current_path);
                }
            });

            refresh_button.clicked.connect(() => {
                if (model != null) model.refresh();
                refresh_directory_content();
            });

            home_button.clicked.connect(() => {
                string home = Environment.get_home_dir();
                current_path = home;
                if (model != null) model.navigate_to(home);
                refresh_directory_content();
                directory_changed(home);
            });

            // Configurer le filtre par extensions
            ext_filter_button.clicked.connect(() => {
                if (ext_filter_popover == null) {
                    // Récupérer les extensions disponibles dans le dossier courant
                    Gee.List<ExtensionInfo> available_extensions = new Gee.ArrayList<ExtensionInfo>();
                    if (model != null) {
                        var model_extensions = model.get_available_extensions_with_labels();
                        foreach (var ext_info in model_extensions) {
                            available_extensions.add(new ExtensionInfo(ext_info.extension, ext_info.label));
                        }
                    }

                    // Créer le widget de filtrage
                    ext_filter_chips = new ExtensionFilterChips(available_extensions);
                    ext_filter_chips.set_selected_extensions(selected_extensions);

                    ext_filter_chips.extension_selected.connect((ext, selected) => {
                        if (selected) {
                            selected_extensions.add(ext);
                        } else {
                            selected_extensions.remove(ext);
                        }
                        apply_extension_filter();
                        save_selected_extensions();
                    });

                    // Configurer le popover
                    ext_filter_popover = new Popover();
                    ext_filter_popover.set_parent(ext_filter_button);
                    ext_filter_popover.set_child(ext_filter_chips);
                    ext_filter_popover.set_size_request(320, 400);
                }
                ext_filter_popover.popup();
            });

            // Ajouter les boutons à la barre d'outils
            toolbar.append(up_button);
            toolbar.append(home_button);
            toolbar.append(refresh_button);
            toolbar.append(ext_filter_button);

            // Dans la méthode create_toolbar(), ajoute le bouton :
            var open_button = new Button.from_icon_name("document-open-symbolic");
            open_button.set_tooltip_text(_("Ouvrir un fichier"));
            toolbar.append(open_button);

            // Ajoute la logique d'ouverture de fichier :
            open_button.clicked.connect(() => {
                var open_dialog = new FileDialog();
                open_dialog.set_title(_("Ouvrir un fichier"));

                var filter = new FileFilter();
                filter.add_mime_type("text/plain");
                filter.add_mime_type("text/markdown");
                filter.add_mime_type("text/html");
                filter.add_pattern("*.txt");
                filter.add_pattern("*.md");
                filter.add_pattern("*.html");
                var filters = new GLib.ListStore(typeof(FileFilter));
                filters.append(filter);
                open_dialog.set_filters(filters);

                // Récupérer la fenêtre principale pour le parent du dialogue
                var main_window = this.get_root() as Gtk.Window;
                open_dialog.open.begin(main_window, null, (obj, res) => {
                    try {
                        var file = open_dialog.open.end(res);
                        if (file != null) {
                            // Appeler la logique pivot du contrôleur
                            var controller = this.controller;
                            if (controller != null) {
                                controller.handle_file_open_request(file.get_path());
                            }
                        }
                    } catch (Error e) {
                        warning("Erreur lors de l'ouverture du fichier via dialogue: %s", e.message);
                    }
                });
            });

            this.append(toolbar);
        }

        private void create_file_list() {
            // Modèle de liste
            list_store = new GLib.ListStore(typeof(FileItemModel));

            // Factory pour la ListView
            var factory = new SignalListItemFactory();

            factory.setup.connect((setup_item) => {
                var list_item = setup_item as ListItem;

                var box = new Box(Orientation.HORIZONTAL, 12);
                box.set_margin_start(6);
                box.set_margin_end(6);
                box.set_margin_top(3);
                box.set_margin_bottom(3);

                var icon = new Image();
                icon.set_pixel_size(24);
                box.append(icon);

                var name_label = new Label("");
                name_label.set_halign(Align.START);
                name_label.set_hexpand(true);
                box.append(name_label);

                list_item.set_child(box);
            });

            factory.bind.connect((bind_item) => {
                var list_item = bind_item as ListItem;
                var file_item = list_item.get_item() as FileItemModel;
                var box = list_item.get_child() as Box;

                // Trouver l'icône et le label
                unowned Image? icon = null;
                unowned Label? name_label = null;

                unowned Widget? child = box.get_first_child();
                while (child != null) {
                    if (child is Image) {
                        icon = child as Image;
                    } else if (child is Label) {
                        name_label = child as Label;
                    }
                    child = child.get_next_sibling();
                }

                // Mettre à jour l'icône
                if (icon != null && file_item != null) {
                    if (file_item.icon != null) {
                        icon.set_from_gicon(file_item.icon);
                    } else if (file_item.is_directory()) {
                        icon.set_from_icon_name("folder");
                    } else {
                        icon.set_from_icon_name("text-x-generic");
                    }
                }

                // Mettre à jour le nom
                if (name_label != null && file_item != null) {
                    if (file_item.is_directory()) {
                        name_label.set_markup("<b>" + GLib.Markup.escape_text(file_item.name) + "</b>");
                    } else {
                        name_label.set_text(file_item.name);
                    }
                }
            });

            // Configuration du modèle et de la vue
            var selection_model = new SingleSelection(list_store);
            list_view = new ListView(selection_model, factory);
            list_view.add_css_class("file-list");

            // Gestionnaire de sélection
            list_view.activate.connect((pos) => {
                var selection = list_view.get_model() as SingleSelection;
                if (selection == null) return;

                var file_item = selection.get_selected_item() as FileItemModel;
                if (file_item == null) return;

                if (file_item.is_directory()) {
                    current_path = file_item.path;
                    if (model != null) model.navigate_to(file_item.path);
                    refresh_directory_content();
                    directory_changed(file_item.path);
                } else {
                    file_selected(file_item.path);
                }
            });

            // ScrolledWindow
            var scroll = new ScrolledWindow();
            scroll.set_policy(PolicyType.AUTOMATIC, PolicyType.AUTOMATIC);
            scroll.set_vexpand(true);
            scroll.set_hexpand(true);
            scroll.set_child(list_view);

            this.append(scroll);
        }

        private void refresh_directory_content() {
            // Si le modèle est null, charger directement depuis le système de fichiers
            ArrayList<FileItemModel> items = new ArrayList<FileItemModel>();

            if (model != null && current_path != null) {
                // Tenter d'obtenir le contenu via le modèle
                var model_items = model.get_directory_content(current_path);
                if (model_items != null) {
                    items.add_all(model_items);
                } else {
                    // Fallback: charger directement
                    items = get_directory_items_fallback(current_path);
                }
            } else if (current_path != null) {
                // Pas de modèle, charger directement
                items = get_directory_items_fallback(current_path);
            } else {
                // Chemin null, utiliser HOME
                current_path = Environment.get_home_dir();
                items = get_directory_items_fallback(current_path);
            }

            // Mettre à jour la liste
            list_store.remove_all();

            // Trier les items (dossiers d'abord, puis alphabétiquement)
            items.sort((a, b) => {
                if (a.is_directory() && !b.is_directory()) return -1;
                if (!a.is_directory() && b.is_directory()) return 1;
                return a.name.collate(b.name);
            });

            foreach (var item in items) {
                // Appliquer le filtre pour fichiers cachés
                if (!item.is_hidden) {
                    // Appliquer le filtre d'extension
                    if (should_show_item(item)) {
                        list_store.append(item);
                    }
                }
            }
        }

        private ArrayList<FileItemModel> get_directory_items_fallback(string dir_path) {
            var items = new ArrayList<FileItemModel>();
            var directory = File.new_for_path(dir_path);

            try {
                var enumerator = directory.enumerate_children(
                    "standard::*",
                    FileQueryInfoFlags.NONE
                );

                FileInfo info;
                while ((info = enumerator.next_file()) != null) {
                    string name = info.get_name();
                    string path = Path.build_filename(dir_path, name);
                    FileType type = info.get_file_type();

                    var item = new FileItemModel();
                    item.name = name;
                    item.path = path;
                    item.file_type = type;
                    item.is_hidden = name.has_prefix(".");
                    item.icon = info.get_icon();

                    items.add(item);
                }
            } catch (Error e) {
                warning("Erreur lors de l'accès au dossier %s: %s", dir_path, e.message);
            }

            return items;
        }

        private bool should_show_item(FileItemModel item) {
            // Toujours montrer les dossiers
            if (item.is_directory()) return true;

            // Si aucune extension n'est sélectionnée, montrer tous les fichiers
            if (selected_extensions.size == 0) return true;

            // Filtrer par extension
            string ext = item.get_extension();
            return ext != null && selected_extensions.contains(ext);
        }

        private void apply_extension_filter() {
            refresh_directory_content();
        }

        private void load_saved_extensions() {
            selected_extensions.clear();

            if (config_manager != null) {
                string extensions_str = config_manager.get_string("Explorer", "filtered_extensions", "");
                if (extensions_str != "") {
                    string[] exts = extensions_str.split(";");
                    foreach (string ext in exts) {
                        if (ext.strip() != "") {
                            selected_extensions.add(ext.strip());
                        }
                    }
                }
            }
        }

        public void save_selected_extensions() {
            if (config_manager == null) return;

            if (selected_extensions.size == 0) {
                config_manager.set_string("Explorer", "filtered_extensions", "");
                return;
            }

            StringBuilder extensions_str = new StringBuilder();
            foreach (string ext in selected_extensions) {
                extensions_str.append(ext);
                extensions_str.append(";");
            }

            config_manager.set_string("Explorer", "filtered_extensions", extensions_str.str);
            config_manager.save();
        }

        public void navigate_to_directory(string path) {
            current_path = path;
            if (model != null) {
                model.navigate_to(path);
            }
            refresh_directory_content();
            directory_changed(path);
        }

        public void refresh() {
            refresh_directory_content();
        }
    }

    public class ExplorerTabView : Gtk.Box {
        // Signal émis lorsqu'un fichier est sélectionné
        public signal void file_selected(string path);

        private ApplicationController controller;
        private ExplorerTabModel tab_model;
        private ScrolledWindow scroll;
        private ListView list_view;
        private GLib.ListStore list_store;
        private StringFilter name_filter;
        private CustomFilter hidden_filter;
        private FilterListModel filter_model;
        private Set<string> extension_filter = new HashSet<string>();

        // Widget du fil d'Ariane
        private BreadcrumbWidget breadcrumb_widget;

        // Prévisualisation
        private FilePreviewWidget? preview_widget = null;
        private bool show_preview = true;
        private Paned content_paned;

        public ExplorerTabView(ApplicationController controller, ExplorerTabModel tab_model) {
            Object(orientation: Orientation.VERTICAL, spacing: 0); // Espacement 0 pour coller les éléments

            this.controller = controller;
            this.tab_model = tab_model;

                  var explorer_model = ApplicationControllerExtension.get_explorer_model(controller);

            // Fil d'Ariane - Créer et ajouter, puis gérer la visibilité
            breadcrumb_widget = new BreadcrumbWidget(controller);
            breadcrumb_widget.path_selected.connect((path) => {
                explorer_model.navigate_to(path);
            });
            // Ajouter le widget au layout (sera caché/montré par set_visible)
            this.append(breadcrumb_widget);

            // *** NOUVEAU : Définir la visibilité initiale et connecter le signal ***
            breadcrumb_widget.set_visible(explorer_model.breadcrumb_enabled);
            if (explorer_model != null && explorer_model is GLib.Object) {
                explorer_model.breadcrumb_enabled_changed.connect(update_breadcrumb_visibility);
            } else {
                warning("ExplorerTabView: explorer_model est NULL ou n'est pas un GObject lors de la connexion breadcrumb_enabled_changed");
            }
            // Mettre à jour le chemin initial si visible
            if (explorer_model.breadcrumb_enabled) {
                breadcrumb_widget.set_path(tab_model.current_path);
            }
            // *** FIN NOUVEAU ***

            // Séparateur (reste inchangé)
            var separator = new Separator(Orientation.HORIZONTAL);
            this.append(separator);

            // Créer le modèle de liste et les filtres (reste inchangé)
            list_store = new GLib.ListStore(typeof(FileItemModel));
            setup_filters(); // Crée hidden_filter

            // Panneau divisé pour liste + prévisualisation (reste inchangé)
            content_paned = new Paned(Orientation.HORIZONTAL);
            // ... (configuration content_paned) ...

            // Configuration de la vue liste (reste inchangé)
            setup_list_view();
            content_paned.set_start_child(scroll);

            // Créer et ajouter le widget de prévisualisation (reste inchangé)
            // ... (configuration preview_widget) ...
            this.append(content_paned);


            // *** NOUVEAU : Appliquer l'état initial du filtre caché et connecter le signal ***
            set_show_hidden(explorer_model.show_hidden_files); // Appliquer l'état initial
            if (explorer_model != null && explorer_model is GLib.Object) {
                explorer_model.show_hidden_files_changed.connect(set_show_hidden);
            } else {
                warning("ExplorerTabView: explorer_model est NULL ou n'est pas un GObject lors de la connexion show_hidden_files_changed");
            }
            // *** FIN NOUVEAU ***


            // Charger le contenu initial
            load_directory_content();

            // Configurer la sélection pour la prévisualisation (reste inchangé)
            // ...

            // S'abonner aux changements de chemin dans le modèle d'onglet
            if (tab_model != null && tab_model is GLib.Object) {
                tab_model.notify["current-path"].connect(() => {
                    load_directory_content();

                    // Mettre à jour le fil d'Ariane si actif et visible
                    if (explorer_model.breadcrumb_enabled) {
                        breadcrumb_widget.set_path(tab_model.current_path);
                    }
                });
            } else {
                warning("ExplorerTabView: tab_model est NULL ou n'est pas un GObject lors de la connexion du signal");
            }

            // ... (fin du constructeur) ...
        }

        private void setup_filters() {
            // Filtre par nom (pour la recherche)
            name_filter = new StringFilter(null);
            name_filter.set_expression(new PropertyExpression(typeof(FileItemModel), null, "name"));
            name_filter.set_ignore_case(true);
            name_filter.set_match_mode(StringFilterMatchMode.SUBSTRING);

            // Filtre personnalisé pour les types de fichiers (si nécessaire)
            // type_filter = new CustomFilter(null);

            // Filtre pour les fichiers cachés - Initialisé avec une fonction par défaut
            // La fonction réelle sera définie par set_show_hidden()
            hidden_filter = new CustomFilter((obj) => {
                 var file_item = obj as FileItemModel;
                 // Comportement par défaut (par ex. masquer les cachés)
                 return file_item != null && !file_item.is_hidden;
            });

            // Combinaison des filtres dans un modèle filtré
            // Le filtre initial sera défini par set_show_hidden et filter_items
            filter_model = new FilterListModel(list_store, null);
        }

        private void setup_list_view() {
            // Créer un conteneur de défilement
            scroll = new ScrolledWindow();
            scroll.set_policy(PolicyType.AUTOMATIC, PolicyType.AUTOMATIC);
            scroll.set_vexpand(true);
            scroll.set_hexpand(true);
            scroll.add_css_class("view");

            // Créer la liste
            list_view = new ListView(null, null);
            list_view.add_css_class("file-list");
            list_view.add_css_class("background");  // Pour le fond blanc comme l'éditeur

            // Factory pour afficher les éléments
            var factory = new SignalListItemFactory();
            factory.setup.connect(on_setup_listitem);
            factory.bind.connect(on_bind_listitem);

            // Sélection
            var selection = new SingleSelection(filter_model);

            // S'assurer que la sélection est bien mise à jour lorsqu'un élément est sélectionné
            selection.selection_changed.connect((position, n_items) => {
                on_selection_changed(position, n_items);
                // Mettre à jour l'UI ou faire d'autres actions nécessaires lors d'un clic simple
            });

            // Créer la vue liste
            list_view = new ListView(selection, factory);
            list_view.add_css_class("file-list");

            // Connecter le signal d'activation (double-clic)
            list_view.activate.connect(on_item_activated);

            // Ajouter un contrôleur pour le clic droit (menu contextuel)
            var right_click_controller = new GestureClick();
            right_click_controller.set_button(3);  // Bouton droit
            right_click_controller.pressed.connect(on_right_click);
            list_view.add_controller(right_click_controller);

            // Ajouter un contrôleur pour le clic gauche standard
            var left_click_controller = new GestureClick();
            left_click_controller.set_button(1);  // Bouton gauche
            left_click_controller.released.connect((n_press, x, y) => {
                if (n_press == 1) {
                    // Clic simple - La sélection est déjà gérée par SingleSelection
                    // Vous pouvez ajouter d'autres comportements ici si nécessaire
                } else if (n_press == 2) {
                    // Double-clic - Simuler un signal d'activation
                    // Obtenir l'élément sur lequel on a cliqué
                    var selection_model = list_view.get_model() as SingleSelection;
                    if (selection_model != null) {
                        var file_item = selection_model.get_selected_item() as FileItemModel;
                        if (file_item != null) {
                            // Appeler directement on_item_activated
                            on_item_activated(selection_model.get_selected());
                        }
                    }
                }
            });
            list_view.add_controller(left_click_controller);

            // Ajouter la vue à la zone de défilement
            scroll.set_child(list_view);

            // Ajouter la prise en charge du glisser-déposer
            setup_drag_and_drop();

            // IMPORTANT: S'assurer que list_view est visible
            list_view.set_visible(true);
            scroll.set_visible(true);


            // Ne pas ajouter scroll ici, il sera ajouté via content_paned
            // Supprimer cette ligne qui cause l'erreur gtk_box_append
            // append(scroll);
        }

        /**
         * Configure un nouvel élément de liste
         */
        private void on_setup_listitem(Object object) {
            var list_item = object as ListItem;

            var box = new Box(Orientation.HORIZONTAL, 12);
            box.set_margin_start(6);
            box.set_margin_end(6);
            box.set_margin_top(3);
            box.set_margin_bottom(3);

            var icon = new Image();
            icon.set_pixel_size(24);
            icon.set_data("type", "icon");

            var name_label = new Label("");
            name_label.set_halign(Align.START);
            name_label.set_hexpand(true);
            name_label.set_data("type", "name");

            box.append(icon);
            box.append(name_label);

            list_item.set_child(box);
        }

        /**
         * Lie un élément de liste à un élément de fichier
         */
        private void on_bind_listitem(Object object) {
            var list_item = object as ListItem;
            var box = list_item.get_child() as Box;
            var file_item = list_item.get_item() as FileItemModel;

            if (file_item == null || box == null) return;

            // Trouver les widgets par leur donnée associée en utilisant get_first_child et get_next_sibling
            Gtk.Image? icon = null;
            Label? name_label = null;

            var child = box.get_first_child();
            while (child != null) {
                if (child.get_data<string>("type") == "icon") {
                    icon = child as Image;
                } else if (child.get_data<string>("type") == "name") {
                    name_label = child as Label;
                }
                child = child.get_next_sibling();
            }

            // Mettre à jour l'icône
            if (icon != null) {
                if (file_item.icon != null) {
                    icon.set_from_gicon(file_item.icon);
                } else if (file_item.is_directory()) {
                    icon.set_from_icon_name("folder");
                } else {
                    icon.set_from_icon_name("text-x-generic");
                }
            }

            // Mettre à jour le nom
            if (name_label != null) {
                if (file_item.is_directory()) {
                    // Rendre le texte en gras pour les dossiers
                    name_label.set_markup("<b>" + GLib.Markup.escape_text(file_item.name) + "</b>");
                } else {
                    name_label.set_text(file_item.name);
                }
            }
        }

        /**
         * Configure le glisser-déposer pour la vue liste
         */
        private void setup_drag_and_drop() {
            // Source de données pour le glisser-déposer
            var drag_source = new DragSource();
            drag_source.set_actions(Gdk.DragAction.COPY | Gdk.DragAction.MOVE);

            // Configurer la fonction qui fournit les données à glisser
            drag_source.prepare.connect((source, x, y) => {
                var selection = list_view.get_model() as SingleSelection;
                if (selection == null) return null;

                var file_item = selection.get_selected_item() as FileItemModel;
                if (file_item == null) return null;

                // Créer une valeur contenant le chemin du fichier
                var content = Value(typeof(string));
                content.set_string(file_item.path);

                // Configurer les données pour la liaison
                var content_provider = new Gdk.ContentProvider.for_value(content);

                // Définir l'image qui sera utilisée pendant le glisser
                var paintable = get_file_icon_paintable(file_item);

                // Get the native surface from the widget
                var native = list_view.get_native();
                if (native == null) return null;

                var surface = native.get_surface();
                if (surface == null) return null;

                // Get the current device from the display
                var display = surface.get_display();
                var seat = display.get_default_seat();
                if (seat == null) return null;

                var device = seat.get_pointer();
                if (device == null) return null;

                // Start the drag operation with all required parameters
                Gdk.Drag.begin(
                    surface,
                    device,
                    content_provider,
                    Gdk.DragAction.COPY | Gdk.DragAction.MOVE,
                    x, y
                );
                return content_provider;
            });

            // Ajouter la source à la vue liste
            list_view.add_controller(drag_source);

            // Destination du glisser-déposer
            var drop_target = new DropTarget(Type.STRING, Gdk.DragAction.COPY | Gdk.DragAction.MOVE);

            // Gérer le signal de déposer
            drop_target.drop.connect((value, x, y) => {
                // Récupérer le chemin du fichier
                string? source_path = value.get_string();
                if (source_path == null) return false;

                // Obtenir le chemin de destination (emplacement actuel)
                string dest_dir = tab_model.current_path;
                string file_name = Path.get_basename(source_path);
                string dest_path = Path.build_filename(dest_dir, file_name);

                // Ne rien faire si on dépose au même endroit
                if (source_path == dest_path) return false;

                // Gérer la copie ou le déplacement du fichier
                try {
                    var source_file = File.new_for_path(source_path);
                    var dest_file = File.new_for_path(dest_path);

                    if (source_file.query_exists()) {
                        // Si le fichier de destination existe déjà, demander confirmation
                        if (dest_file.query_exists()) {
                            // Utiliser FileError.FAILED au lieu de FileError.EXISTS qui n'existe pas
                            throw new FileError.FAILED(_("Un fichier du même nom existe déjà."));
                        }

                        // Pour une opération de copie
                        source_file.copy(dest_file, FileCopyFlags.NONE);

                        // Rafraîchir la vue
                        refresh();
                    }
                    return true;
                } catch (Error e) {
                    // Afficher un message d'erreur
                    var toast = new Adw.Toast(_("Erreur: ") + e.message);
                    toast.set_timeout(3);
                    var toast_overlay = get_ancestor(typeof(Adw.ToastOverlay)) as Adw.ToastOverlay;
                    if (toast_overlay != null) {
                        toast_overlay.add_toast(toast);
                    }
                }
                return false;
            });

            // Ajouter la cible à la vue liste
            list_view.add_controller(drop_target);
        }

        /**
         * Obtient une représentation Paintable de l'icône du fichier
         */
        private Gdk.Paintable? get_file_icon_paintable(FileItemModel file_item) {
            try {
                if (file_item.icon != null) {
                    var theme = Gtk.IconTheme.get_for_display(Gdk.Display.get_default());
                    var paintable = theme.lookup_by_gicon(file_item.icon, 32, 1, Gtk.TextDirection.NONE, 0);
                    return paintable;
                } else if (file_item.is_directory()) {
                    var theme = Gtk.IconTheme.get_for_display(Gdk.Display.get_default());
                    var paintable = theme.lookup_icon("folder", null, 32, 1, Gtk.TextDirection.NONE, 0);
                    return paintable;
                } else {
                    var theme = Gtk.IconTheme.get_for_display(Gdk.Display.get_default());
                    var paintable = theme.lookup_icon("text-x-generic", null, 32, 1, Gtk.TextDirection.NONE, 0);
                    return paintable;
                }
            } catch (Error e) {
                warning("Erreur lors de la création de l'icône pour le glisser-déposer: %s", e.message);
                return null;
            }
        }

        /**
         * Gère l'activation d'un élément (double-clic ou Entrée)
         */
        private void on_item_activated(uint position) {

            var selection = list_view.get_model() as SingleSelection;
            if (selection == null) {
                return;
            }

            var file_item = selection.get_selected_item() as FileItemModel;
            if (file_item == null) {
                return;
            }

                  if (file_item.is_directory()) {
                // Pour les dossiers, utiliser directement le modèle pour naviguer
                var explorer_model = ApplicationControllerExtension.get_explorer_model(controller);
                if (explorer_model != null) {
                    bool result = explorer_model.navigate_to(file_item.path);
                } else {
                }
            } else {
                // Pour les fichiers, émettre le signal pour l'ouverture
                file_selected(file_item.path);
            }
        }

        /**
         * Filtre les éléments affichés selon un texte de recherche et l'état des fichiers cachés.
         */
        public void filter_items(string filter_text) {
            // Mettre à jour le filtre de nom
            name_filter.set_search(filter_text);

            // Créer un filtre combiné (nom ET fichiers cachés)
            // EveryFilter requiert que TOUS les filtres retournent true
            var every_filter = new EveryFilter();

            // Ajouter le filtre de nom seulement s'il y a du texte
            if (filter_text != "") {
                 every_filter.append(name_filter);
            }

            // Toujours ajouter le filtre des fichiers cachés (sa logique interne détermine quoi montrer)
            every_filter.append(hidden_filter);

            // Appliquer le filtre combiné (ou juste hidden_filter si pas de recherche)
            if (filter_text == "" && every_filter.get_n_items() == 1) {
                 // Si pas de recherche, appliquer juste le filtre caché
                 filter_model.set_filter(hidden_filter);
            } else if (every_filter.get_n_items() > 0) {
                 // Sinon appliquer le filtre combiné
                 filter_model.set_filter(every_filter);
            } else {
                 // Si aucun filtre (ne devrait pas arriver avec hidden_filter), montrer tout
                 filter_model.set_filter(null);
            }
        }

        /**
         * Gère le clic droit pour afficher un menu contextuel
         */
        private void on_right_click(int n_press, double x, double y) {
            // Vérifier si un élément est sélectionné
            var selection = list_view.get_model() as SingleSelection;
            if (selection == null) return;

            var file_item = selection.get_selected_item() as FileItemModel;
            if (file_item == null) return;

            // Créer le menu
            var menu = new PopoverMenu.from_model(build_context_menu(file_item));

            // Positionner et afficher le menu
            menu.set_parent(list_view);
            Gdk.Rectangle rect = {};
            rect.x = (int)x;
            rect.y = (int)y;
            rect.width = 1;
            rect.height = 1;
            menu.set_pointing_to(rect);
            menu.popup();
        }

        /**
         * Construit le menu contextuel pour un fichier
         */
        private GLib.MenuModel build_context_menu(FileItemModel file_item) {
            var menu = new GLib.Menu();

            // Éléments communs du menu
            var common_section = new GLib.Menu();

            if (file_item.is_directory()) {
                // Options spécifiques aux dossiers
                common_section.append(_("Ouvrir"), "win.open-folder");
                common_section.append(_("Ouvrir dans un nouvel onglet"), "win.open-folder-new-tab");
            } else {
                // Options spécifiques aux fichiers
                common_section.append(_("Ouvrir"), "win.open-file");
                common_section.append(_("Ouvrir avec..."), "win.open-with");
            }

            // Ajouter aux favoris
            var explorer_model = ApplicationControllerExtension.get_explorer_model(controller);
            if (explorer_model != null && !explorer_model.is_favorite(file_item.path)) {
                common_section.append(_("Ajouter aux favoris"), "win.add-to-favorites");
            } else {
                common_section.append(_("Retirer des favoris"), "win.remove-from-favorites");
            }

            // Éléments pour copier/couper/coller
            var edit_section = new GLib.Menu();
            edit_section.append(_("Copier"), "win.copy-file");
            edit_section.append(_("Couper"), "win.cut-file");

            // Désactiver coller si le presse-papiers est vide
            edit_section.append(_("Coller"), "win.paste-file");

            // Éléments pour renommer/supprimer
            var modify_section = new GLib.Menu();
            modify_section.append(_("Renommer"), "win.rename-file");
            modify_section.append(_("Supprimer"), "win.delete-file");

            // Éléments pour les propriétés
            var properties_section = new GLib.Menu();
            properties_section.append(_("Propriétés"), "win.file-properties");

            // Assembler le menu
            menu.append_section(null, common_section);
            menu.append_section(null, edit_section);
            menu.append_section(null, modify_section);
            menu.append_section(null, properties_section);

            // Connecter les actions
            setup_context_menu_actions(file_item);

            return menu;
        }

        /**
         * Configure les actions du menu contextuel
         */
        private void setup_context_menu_actions(FileItemModel file_item) {
            var window = this.get_root() as Gtk.ApplicationWindow;
            if (window == null) return;

            // Récupérer le modèle via la méthode d'extension
            var explorer_model = ApplicationControllerExtension.get_explorer_model(controller);
            if (explorer_model == null) return;

            // Action pour ouvrir un dossier
            var open_folder_action = new SimpleAction("open-folder", null);
            open_folder_action.activate.connect(() => {
                explorer_model.navigate_to(file_item.path);
            });

            // Action pour ouvrir un dossier dans un nouvel onglet
            var open_folder_new_tab_action = new SimpleAction("open-folder-new-tab", null);
            open_folder_new_tab_action.activate.connect(() => {
                explorer_model.add_tab(new ExplorerTabModel(file_item.path, file_item.name));
            });

            // Action pour ouvrir un fichier
            var open_file_action = new SimpleAction("open-file", null);
            open_file_action.activate.connect(() => {
                explorer_model.select_file_for_edit(file_item);
            });

            // Action pour ouvrir avec
            var open_with_action = new SimpleAction("open-with", null);
            open_with_action.activate.connect(() => {
                // Ici, on pourrait ouvrir une boîte de dialogue pour choisir l'application
                // Pour l'exemple, on utilisera simplement l'ouverture par défaut

                try {
                    var file = File.new_for_path(file_item.path);
                    AppInfo.launch_default_for_uri(file.get_uri(), null);
                } catch (Error e) {
                    warning("Erreur lors de l'ouverture avec une autre application: %s", e.message);
                }
            });

            // Action pour ajouter aux favoris
            var add_to_favorites_action = new SimpleAction("add-to-favorites", null);
            add_to_favorites_action.activate.connect(() => {
                explorer_model.add_to_favorites(file_item.path);
                // Montrer une notification
                var toast = new Adw.Toast("Ajouté aux favoris");
                toast.set_timeout(3);
                var toast_overlay = get_ancestor(typeof(Adw.ToastOverlay)) as Adw.ToastOverlay;
                if (toast_overlay != null) {
                    toast_overlay.add_toast(toast);
                }
            });

            // Action pour retirer des favoris
            var remove_from_favorites_action = new SimpleAction("remove-from-favorites", null);
            remove_from_favorites_action.activate.connect(() => {
                explorer_model.remove_from_favorites(file_item.path);
                // Montrer une notification
                var toast = new Adw.Toast("Supprimé des favoris");
                toast.set_timeout(3);
                var toast_overlay = get_ancestor(typeof(Adw.ToastOverlay)) as Adw.ToastOverlay;
                if (toast_overlay != null) {
                    toast_overlay.add_toast(toast);
                }
            });

            // Utiliser ActionMap pour ajouter les actions à la fenêtre
            ActionMap action_map = window as ActionMap;
            if (action_map != null) {
                action_map.add_action(open_folder_action);
                action_map.add_action(open_folder_new_tab_action);
                action_map.add_action(open_file_action);
                action_map.add_action(open_with_action);
                action_map.add_action(add_to_favorites_action);
                action_map.add_action(remove_from_favorites_action);
            }
        }

        /**
         * Gère la sélection d'un élément pour la prévisualisation
         */
        private void on_selection_changed(uint position, uint n_items) {
            if (!show_preview || preview_widget == null) return;

            var selection = list_view.get_model() as SingleSelection;
            if (selection == null) return;

            var file_item = selection.get_selected_item() as FileItemModel;

            if (file_item != null) {
                // Essayer d'appeler preview_file si elle existe
                try {
                    // Si cette méthode existe, elle sera appelée
                    preview_widget.preview_file(file_item);
                } catch (Error e) {
                    // Si preview_file n'existe pas, afficher un message d'erreur
                    // et assurer que l'erreur est gérée correctement
                    warning("Impossible de prévisualiser le fichier: %s", e.message);
                    // Méthode de secours pour effacer la prévisualisation
                    preview_widget.clear();
                }
            } else {
                preview_widget.clear();
            }
        }

        /**
         * Charge le contenu du répertoire actuel
         */
        private void load_directory_content() {
            var explorer_model = ApplicationControllerExtension.get_explorer_model(controller);
            if (explorer_model != null) {
                // Le modèle get_directory_content ne devrait PAS filtrer les fichiers cachés lui-même.
                // Il retourne tous les fichiers, le filtrage se fait dans la VUE via filter_model.
                var items = explorer_model.get_directory_content(tab_model.current_path);

                // Mettre à jour la liste (avant filtrage par filter_model)
                list_store.remove_all();
                foreach (var item in items) {
                    list_store.append(item);
                }
                // Le FilterListModel se mettra à jour automatiquement.
            }
        }

        /**
         * Gestionnaire pour le bouton effacer la recherche
         */
        private void on_clear_clicked() {
            // Effacer le filtre de recherche
            filter_items("");

            // Si nous sommes en mode recherche, retourner au dossier normal
            refresh();
        }

        /**
         * Rafraîchit l'affichage
         */
        public void refresh() {
            load_directory_content();
        }

        /**
         * Retourne le chemin actuel
         */
        public string get_current_path() {
            return tab_model.current_path;
        }

        /**
         * Vérifie si l'onglet est épinglé
         */
        public bool is_pinned() {
            return tab_model.is_pinned;
        }

        /**
         * Configure l'option d'affichage des fichiers cachés en mettant à jour le filtre.
         */
        public void set_show_hidden(bool show_hidden) {
            // Mettre à jour la logique interne du filtre existant
            hidden_filter.set_filter_func((obj) => {
                var file_item = obj as FileItemModel;
                if (file_item == null) return false; // Important

                // La propriété file_item.is_hidden est true si le nom commence par '.'
                // Retourne true (montrer l'élément) si :
                // 1. L'option show_hidden est activée (on montre tout)
                // OU
                // 2. L'élément n'est PAS caché (son nom ne commence pas par '.')
                return show_hidden || !file_item.is_hidden;
            });

            // Notifier le FilterListModel que la logique du CustomFilter a changé.
            // hidden_filter.changed(Gtk.FilterChange.DIFFERENT); // On va remplacer ça

            // *** NOUVEAU : Réappliquer explicitement le filtrage complet ***
            // Récupérer le texte de recherche actuel pour le réappliquer
            var current_search_text = name_filter.search ?? "";
            filter_items(current_search_text);
            // *** FIN NOUVEAU ***
        }

        /**
         * Configure l'option de tri
         */
        public void set_sort_by(string sort_by) {
            CompareDataFunc<Object> compare_func;

            switch (sort_by) {
                case "name":
                    compare_func = (a, b) => {
                        var file_a = a as FileItemModel;
                        var file_b = b as FileItemModel;

                        if (file_a == null || file_b == null)
                            return 0;

                        // Dossiers d'abord
                        if (file_a.is_directory() && !file_b.is_directory())
                            return -1;
                        if (!file_a.is_directory() && file_b.is_directory())
                            return 1;

                        return file_a.name.collate(file_b.name);
                    };
                    break;
                case "size":
                    compare_func = (a, b) => {
                        var file_a = a as FileItemModel;
                        var file_b = b as FileItemModel;

                        if (file_a == null || file_b == null)
                            return 0;

                        // Dossiers d'abord
                        if (file_a.is_directory() && !file_b.is_directory())
                            return -1;
                        if (!file_a.is_directory() && file_b.is_directory())
                            return 1;

                        return (int)(file_a.size - file_b.size);
                    };
                    break;
                case "date":
                    compare_func = (a, b) => {
                        var file_a = a as FileItemModel;
                        var file_b = b as FileItemModel;

                        if (file_a == null || file_b == null)
                            return 0;

                        // Dossiers d'abord
                        if (file_a.is_directory() && !file_b.is_directory())
                            return -1;
                        if (!file_a.is_directory() && file_b.is_directory())
                            return 1;

                        return file_a.modified_time.compare(file_b.modified_time);
                    };
                    break;
                case "type":
                    compare_func = (a, b) => {
                        var file_a = a as FileItemModel;
                        var file_b = b as FileItemModel;

                        if (file_a == null || file_b == null)
                            return 0;

                        // Dossiers d'abord
                        if (file_a.is_directory() && !file_b.is_directory())
                            return -1;
                        if (!file_a.is_directory() && file_b.is_directory())
                            return 1;

                        // Trier par extension, puis par nom
                        string ext_a = file_a.get_extension();
                        string ext_b = file_b.get_extension();

                        int ext_compare = ext_a.collate(ext_b);
                        if (ext_compare != 0)
                            return ext_compare;

                        return file_a.name.collate(file_b.name);
                    };
                    break;
                default:
                    // Par défaut, trier par nom
                    compare_func = (a, b) => {
                        var file_a = a as FileItemModel;
                        var file_b = b as FileItemModel;

                        if (file_a == null || file_b == null)
                            return 0;

                        if (file_a.is_directory() && !file_b.is_directory())
                            return -1;
                        if (!file_a.is_directory() && file_b.is_directory())
                            return 1;

                        return file_a.name.collate(file_b.name);
                    };
                    break;
            }

            // Appliquer le tri
            list_store.sort(compare_func);
        }

        /**
         * Configure la visibilité de la prévisualisation
         */
        public void set_preview_visible(bool visible) {
            show_preview = visible;
            if (visible) {
                if (preview_widget == null) {
                    preview_widget = new FilePreviewWidget();
                }
                content_paned.set_end_child(preview_widget);
            } else {
                content_paned.set_end_child(null);
            }
        }

        /**
         * Entre en mode recherche avec des résultats précalculés
         */
        public void enter_search_mode(Gee.ArrayList<FileItemModel> results, string search_path) {
            // Afficher les résultats dans la liste
            list_store.remove_all();
            foreach (var item in results) {
                list_store.append(item);
            }

            // Mettre à jour le titre pour indiquer qu'on est en mode recherche
            var header_box = this.get_first_child() as Box;
            if (header_box != null) {
                var title_label = header_box.get_first_child() as Label;
                if (title_label != null) {
                    title_label.set_markup("<b>Résultats de recherche dans: " + Path.get_basename(search_path) + "</b>");
                }
            }
        }

        /**
         * Helper method to find a child widget with a specific CSS class
         */
        private Gtk.Widget? find_child_by_css_class(Gtk.Widget container, string css_class) {
            var child = container.get_first_child();
            while (child != null) {
                if (child.has_css_class(css_class)) {
                    return child;
                }

                // Check recursively in this child
                var result = find_child_by_css_class(child, css_class);
                if (result != null) {
                    return result;
                }

                child = child.get_next_sibling();
            }
            return null;
        }

        private void update_breadcrumb(string path) {
            // Récupérer le modèle de fil d'Ariane
            var explorer_model = ApplicationControllerExtension.get_explorer_model(controller);
            var breadcrumb_model = explorer_model.get_active_breadcrumb();

            // Retrouver le conteneur de fil d'Ariane
            var breadcrumb_box = find_child_by_css_class(this, "breadcrumb-container") as Gtk.Box;
            if (breadcrumb_box == null) return;

            // Vider le contenu existant
            var child = breadcrumb_box.get_first_child();
            while (child != null) {
                var next = child.get_next_sibling();
                breadcrumb_box.remove(child);
                child = next;
            }

            // Ajouter les segments
            var segments = breadcrumb_model.get_segments();
            for (int i = 0; i < segments.size; i++) {
                var segment = segments.get(i);

                // Créer le bouton pour ce segment
                var button = new Button.with_label(segment.name);
                button.add_css_class("breadcrumb-button");
                button.set_tooltip_text(segment.path);

                // Capturer l'index pour le callback
                int idx = i;
                button.clicked.connect(() => {
                    breadcrumb_model.navigate_to_segment(idx);
                });

                breadcrumb_box.append(button);

                // Ajouter un séparateur sauf pour le dernier élément
                if (i < segments.size - 1) {
                    var separator = new Label("›");
                    separator.add_css_class("breadcrumb-separator");
                    breadcrumb_box.append(separator);
                }
            }
        }

        /**
         * Met à jour la visibilité du widget fil d'Ariane.
         * Simplifié pour juste utiliser set_visible.
         */
        private void update_breadcrumb_visibility(bool visible) {
            breadcrumb_widget.set_visible(visible);
            // Mettre à jour le chemin si on le rend visible
            if (visible) {
                 breadcrumb_widget.set_path(tab_model.current_path);
            }
        }

        public void set_extension_filter(Set<string> exts) {
            extension_filter = exts;
            filter_items_by_extension();
        }

        private void filter_items_by_extension() {
            // On applique le filtre d'extension en plus du filtre existant
            var every_filter = new EveryFilter();
            if (extension_filter != null && extension_filter.size > 0) {
                var ext_filter = new CustomFilter((obj) => {
                    var file_item = obj as FileItemModel;
                    if (file_item == null) return false;
                    var ext = file_item.get_extension();
                    return ext != null && extension_filter.contains(ext);
                });
                every_filter.append(ext_filter);
            }
            // Ajouter les autres filtres existants (nom, cachés)
            if (name_filter != null && name_filter.search != null && name_filter.search != "") {
                every_filter.append(name_filter);
            }
            every_filter.append(hidden_filter);
            if (every_filter.get_n_items() > 0)
                filter_model.set_filter(every_filter);
            else
                filter_model.set_filter(null);
        }
    }
}
