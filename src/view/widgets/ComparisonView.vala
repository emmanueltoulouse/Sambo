using Gtk;
using Gdk;

namespace Sambo {
    /**
     * Widget pour afficher deux répertoires côte à côte pour comparaison
     */
    public class ComparisonView : Gtk.Box {
        private ApplicationController controller;
        private string left_path;
        private string right_path;

        // Les deux listes de fichiers
        private GLib.ListStore left_store;
        private GLib.ListStore right_store;

        private ListView left_list_view;
        private ListView right_list_view;

        // Filtres
        private CustomFilter left_filter;
        private CustomFilter right_filter;

        // Actions de comparaison
        private Button copy_to_left_button;
        private Button copy_to_right_button;
        private Button diff_button;
        private Button refresh_button;
        private ToggleButton show_identical_button;

        // Statistiques de comparaison
        private Label stats_label;
        private int total_files = 0;
        private int identical_files = 0;
        private int different_files = 0;
        private int only_left_files = 0;
        private int only_right_files = 0;

        // Boutons pour les opérations multiples
        private Button sync_all_button;
        private MenuButton filter_button;
        private Button pin_button;

        // Signal émis lorsqu'un fichier est sélectionné pour différence
        public signal void file_diff_requested(string left_file, string right_file);

        // Signal émis lorsqu'on veut quitter le mode comparaison
        public signal void exit_comparison_requested();

        // Signal émis lorsqu'on veut épingler l'onglet de comparaison
        public signal void pin_tab_requested();

        /**
         * Crée une nouvelle vue de comparaison
         */
        public ComparisonView(ApplicationController controller, string left_path, string right_path) {
            Object(orientation: Orientation.VERTICAL, spacing: 6);

            this.controller = controller;
            this.left_path = left_path;
            this.right_path = right_path;

            // Initialiser les listes de fichiers
            left_store = new GLib.ListStore(typeof(FileItemModel));
            right_store = new GLib.ListStore(typeof(FileItemModel));

            // Configurer les filtres
            setup_filters();

            // Créer l'interface
            create_ui();

            // Charger le contenu initial
            load_directory_content();
        }

        /**
         * Configure les filtres pour les deux listes
         */
        private void setup_filters() {
            // Filtre pour masquer les fichiers identiques si demandé
            left_filter = new CustomFilter((obj) => {
                bool show_identical = show_identical_button.get_active();
                var file_item = obj as FileItemModel;

                if (file_item == null) {
                    return false;
                }

                // Si on montre tous les fichiers, pas besoin de filtrer
                if (show_identical) {
                    return true;
                }

                // Vérifier si ce fichier existe dans la liste de droite
                string filename = file_item.name;
                bool found_identical = false;

                for (uint i = 0; i < right_store.get_n_items(); i++) {
                    var right_item = right_store.get_item(i) as FileItemModel;
                    if (right_item != null && right_item.name == filename) {
                        // Vérifier si les fichiers sont identiques (taille + date)
                        if (right_item.size == file_item.size &&
                            right_item.modified_time.compare(file_item.modified_time) == 0) {
                            found_identical = true;
                            break;
                        }
                    }
                }

                // Retourner true si pas identique ou si c'est un dossier
                return !found_identical || file_item.is_directory();
            });

            // Filtre pour la liste de droite (même logique)
            right_filter = new CustomFilter((obj) => {
                bool show_identical = show_identical_button.get_active();
                var file_item = obj as FileItemModel;

                if (file_item == null) {
                    return false;
                }

                if (show_identical) {
                    return true;
                }

                string filename = file_item.name;
                bool found_identical = false;

                for (uint i = 0; i < left_store.get_n_items(); i++) {
                    var left_item = left_store.get_item(i) as FileItemModel;
                    if (left_item != null && left_item.name == filename) {
                        if (left_item.size == file_item.size &&
                            left_item.modified_time.compare(file_item.modified_time) == 0) {
                            found_identical = true;
                            break;
                        }
                    }
                }

                return !found_identical || file_item.is_directory();
            });
        }

        /**
         * Crée l'interface utilisateur
         */
        private void create_ui() {
            // Barre d'outils pour les actions de comparaison
            var toolbar = new Box(Orientation.HORIZONTAL, 6);
            toolbar.set_margin_start(6);
            toolbar.set_margin_end(6);
            toolbar.set_margin_top(6);
            toolbar.set_margin_bottom(6);

            // Bouton pour afficher/masquer les fichiers identiques
            show_identical_button = new ToggleButton();
            show_identical_button.set_label(_("Afficher les fichiers identiques"));
            show_identical_button.set_active(true);
            show_identical_button.toggled.connect(on_show_identical_toggled);

            // Bouton de rafraîchissement
            refresh_button = new Button.from_icon_name("view-refresh-symbolic");
            refresh_button.set_tooltip_text(_("Rafraîchir"));
            refresh_button.clicked.connect(on_refresh_clicked);

            // Bouton de filtrage
            filter_button = new MenuButton();
            filter_button.set_icon_name("view-filter-symbolic");
            filter_button.set_tooltip_text(_("Filtres"));
            filter_button.set_menu_model(build_filter_menu());

            // Bouton pour synchroniser tous les fichiers
            sync_all_button = new Button.with_label(_("Synchroniser"));
            sync_all_button.set_tooltip_text(_("Synchroniser les fichiers différents"));
            sync_all_button.clicked.connect(on_sync_all_clicked);

            // Bouton pour épingler l'onglet de comparaison
            pin_button = new Button.from_icon_name("view-pin-symbolic");
            pin_button.set_tooltip_text(_("Épingler cet onglet"));
            pin_button.clicked.connect(() => {
                pin_tab_requested();
            });

            // Bouton pour comparer les fichiers sélectionnés
            diff_button = new Button.with_label(_("Comparer"));
            diff_button.set_sensitive(false);
            diff_button.clicked.connect(on_diff_clicked);

            // Boutons pour copier les fichiers
            copy_to_left_button = new Button.with_label(_("← Copier"));
            copy_to_left_button.set_sensitive(false);
            copy_to_left_button.clicked.connect(on_copy_to_left_clicked);

            copy_to_right_button = new Button.with_label(_("Copier →"));
            copy_to_right_button.set_sensitive(false);
            copy_to_right_button.clicked.connect(on_copy_to_right_clicked);

            // Bouton pour quitter le mode comparaison
            var exit_button = new Button.with_label(_("Quitter la comparaison"));
            exit_button.clicked.connect(() => {
                exit_comparison_requested();
            });

            // Ajouter les boutons à la barre d'outils
            toolbar.append(show_identical_button);
            toolbar.append(refresh_button);
            toolbar.append(filter_button);
            toolbar.append(sync_all_button);
            toolbar.append(pin_button);

            var spacer = new Label("");
            spacer.set_hexpand(true);
            toolbar.append(spacer);

            toolbar.append(copy_to_left_button);
            toolbar.append(diff_button);
            toolbar.append(copy_to_right_button);
            toolbar.append(exit_button);

            this.append(toolbar);

            // Affichage des chemins avec des étiquettes distinctives pour chaque côté
            var paths_box = new Box(Orientation.HORIZONTAL, 6);
            paths_box.set_margin_start(6);
            paths_box.set_margin_end(6);

            var left_panel = new Box(Orientation.VERTICAL, 0);
            left_panel.set_hexpand(true);

            var left_title = new Label("");
            left_title.set_markup(_("<b>Dossier source:</b>"));
            left_title.set_halign(Align.START);
            left_title.add_css_class("comparison-header");
            left_panel.append(left_title);

            var left_path_label = new Label(left_path);
            left_path_label.set_ellipsize(Pango.EllipsizeMode.START);
            left_path_label.set_halign(Align.START);
            left_path_label.set_hexpand(true);
            left_path_label.set_tooltip_text(left_path);
            left_panel.append(left_path_label);

            var right_panel = new Box(Orientation.VERTICAL, 0);
            right_panel.set_hexpand(true);

            var right_title = new Label("");
            right_title.set_markup(_("<b>Dossier comparé:</b>"));
            right_title.set_halign(Align.START);
            right_title.add_css_class("comparison-header");
            right_panel.append(right_title);

            var right_path_label = new Label(right_path);
            right_path_label.set_ellipsize(Pango.EllipsizeMode.START);
            right_path_label.set_halign(Align.START);
            right_path_label.set_hexpand(true);
            right_path_label.set_tooltip_text(right_path);
            right_panel.append(right_path_label);

            paths_box.append(left_panel);
            paths_box.append(right_panel);

            this.append(paths_box);

            // Panneau principal pour les deux listes côte à côte
            var paned = new Paned(Orientation.HORIZONTAL);
            paned.set_wide_handle(true);
            paned.set_vexpand(true);

            // Liste gauche
            var left_scroll = new ScrolledWindow();
            left_scroll.set_vexpand(true);

            var left_filter_model = new FilterListModel(left_store, left_filter);
            left_list_view = create_list_view(left_filter_model, true);
            left_scroll.set_child(left_list_view);

            // Liste droite
            var right_scroll = new ScrolledWindow();
            right_scroll.set_vexpand(true);

            var right_filter_model = new FilterListModel(right_store, right_filter);
            right_list_view = create_list_view(right_filter_model, false);
            right_scroll.set_child(right_list_view);

            // Ajouter les listes au panneau
            paned.set_start_child(left_scroll);
            paned.set_end_child(right_scroll);
            paned.set_position(400); // Position initiale du séparateur

            this.append(paned);

            // Barre d'état avec statistiques
            var status_box = new Box(Orientation.HORIZONTAL, 6);
            status_box.set_margin_start(6);
            status_box.set_margin_end(6);
            status_box.set_margin_top(6);
            status_box.set_margin_bottom(6);

            stats_label = new Label("");
            stats_label.set_halign(Align.START);
            stats_label.set_hexpand(true);
            stats_label.add_css_class("diff-stats");

            status_box.append(stats_label);

            this.append(status_box);
        }

        /**
         * Construit le menu de filtrage
         */
        private GLib.MenuModel build_filter_menu() {
            var menu = new Menu();

            // Options de filtrage
            var section_filter = new Menu();
            section_filter.append(_("Afficher uniquement les fichiers uniques"), "win.filter-unique");
            section_filter.append(_("Afficher uniquement les fichiers différents"), "win.filter-different");
            section_filter.append(_("Afficher tous les fichiers"), "win.filter-all");

            // Options d'affichage
            var section_view = new Menu();
            section_view.append(_("Trier par nom"), "win.sort-name");
            section_view.append(_("Trier par taille"), "win.sort-size");
            section_view.append(_("Trier par date"), "win.sort-date");

            menu.append_section(null, section_filter);
            menu.append_section(null, section_view);

            // Actions pour le menu
            setup_filter_actions();

            return menu;
        }

        /**
         * Configure les actions pour le menu de filtrage
         */
        private void setup_filter_actions() {
            var window = get_root() as Window;
            if (window == null) return;

            // Action pour filtrer uniquement les fichiers uniques
            var filter_unique_action = new SimpleAction("filter-unique", null);
            filter_unique_action.activate.connect(() => {
                show_identical_button.set_active(false);
                apply_filters();
            });

            // Action pour filtrer uniquement les fichiers différents
            var filter_different_action = new SimpleAction("filter-different", null);
            filter_different_action.activate.connect(() => {
                show_identical_button.set_active(false);
                apply_filters();
            });

            // Action pour afficher tous les fichiers
            var filter_all_action = new SimpleAction("filter-all", null);
            filter_all_action.activate.connect(() => {
                show_identical_button.set_active(true);
                apply_filters();
            });

            // Actions de tri
            var sort_name_action = new SimpleAction("sort-name", null);
            sort_name_action.activate.connect(() => {
                sort_files_by("name");
            });

            var sort_size_action = new SimpleAction("sort-size", null);
            sort_size_action.activate.connect(() => {
                sort_files_by("size");
            });

            var sort_date_action = new SimpleAction("sort-date", null);
            sort_date_action.activate.connect(() => {
                sort_files_by("date");
            });

            // Utiliser ActionMap pour ajouter les actions à la fenêtre
            ActionMap action_map = window as ActionMap;
            if (action_map != null) {
                action_map.add_action(filter_unique_action);
                action_map.add_action(filter_different_action);
                action_map.add_action(filter_all_action);
                action_map.add_action(sort_name_action);
                action_map.add_action(sort_size_action);
                action_map.add_action(sort_date_action);
            }
        }

        /**
         * Trie les fichiers selon le critère spécifié
         */
        private void sort_files_by(string criteria) {
            // Fonction de comparaison à utiliser
            GLib.CompareDataFunc<Object> compare_func;

            switch (criteria) {
                case "size":
                    compare_func = (a, b) => {
                        var file_a = a as FileItemModel;
                        var file_b = b as FileItemModel;

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

                        if (file_a.is_directory() && !file_b.is_directory())
                            return -1;
                        if (!file_a.is_directory() && file_b.is_directory())
                            return 1;

                        return file_a.modified_time.compare(file_b.modified_time);
                    };
                    break;

                case "name":
                default:
                    compare_func = (a, b) => {
                        var file_a = a as FileItemModel;
                        var file_b = b as FileItemModel;

                        if (file_a.is_directory() && !file_b.is_directory())
                            return -1;
                        if (!file_a.is_directory() && file_b.is_directory())
                            return 1;

                        return file_a.name.collate(file_b.name);
                    };
                    break;
            }

            // Appliquer le tri
            left_store.sort(compare_func);
            right_store.sort(compare_func);
        }

        /**
         * Crée une vue liste avec les colonnes appropriées
         */
        private ListView create_list_view(ListModel model, bool is_left) {
            // Factory pour afficher les éléments
            var factory = new SignalListItemFactory();
            factory.setup.connect((obj) => {
                var list_item = obj as ListItem;
                var box = new Box(Orientation.HORIZONTAL, 6);
                box.set_margin_start(6);
                box.set_margin_end(6);
                box.set_margin_top(3);
                box.set_margin_bottom(3);

                var icon = new Image();
                icon.set_pixel_size(16);

                var name_label = new Label("");
                name_label.set_halign(Align.START);
                name_label.set_hexpand(true);

                var size_label = new Label("");
                size_label.set_halign(Align.END);
                size_label.set_width_chars(10);

                var date_label = new Label("");
                date_label.set_halign(Align.END);
                date_label.set_width_chars(16);

                box.append(icon);
                box.append(name_label);
                box.append(size_label);
                box.append(date_label);

                list_item.set_child(box);
            });

            factory.bind.connect((obj) => {
                var list_item = obj as ListItem;
                var box = list_item.get_child() as Box;
                var file_item = list_item.get_item() as FileItemModel;

                if (file_item == null || box == null)
                    return;

                // Récupérer les widgets
                var icon = box.get_first_child() as Image;
                var name_label = icon.get_next_sibling() as Label;
                var size_label = name_label.get_next_sibling() as Label;
                var date_label = size_label.get_next_sibling() as Label;

                // Mise à jour des widgets
                if (file_item.icon != null) {
                    icon.set_from_gicon(file_item.icon);
                } else if (file_item.is_directory()) {
                    icon.set_from_icon_name("folder");
                } else {
                    icon.set_from_icon_name("text-x-generic");
                }

                // Mettre en gras les dossiers
                if (file_item.is_directory()) {
                    name_label.set_markup("<b>" + GLib.Markup.escape_text(file_item.name) + "</b>");
                } else {
                    name_label.set_text(file_item.name);
                }

                // Afficher la taille formatée et la date
                size_label.set_text(file_item.get_formatted_size());
                date_label.set_text(file_item.get_formatted_modified_time());

                // Colorer différemment les fichiers différents
                string? status = get_comparison_status(file_item, is_left);
                if (status != null) {
                    if (status == "only_here") {
                        box.add_css_class("comparison-only-here");
                    } else if (status == "different") {
                        box.add_css_class("comparison-different");
                    } else if (status == "identical") {
                        box.add_css_class("comparison-identical");
                    }
                }
            });

            // Sélection
            var selection = new SingleSelection(model);
            selection.selection_changed.connect(() => {
                update_buttons();
            });

            var list_view = new ListView(selection, factory);
            list_view.add_css_class("file-list");

            // Support du double-clic pour comparer les fichiers
            var gesture_click = new GestureClick();
            gesture_click.set_button(1);  // Bouton gauche
            gesture_click.released.connect((n_press, x, y) => {
                if (n_press == 2) {  // Double-clic
                    var item_selection = list_view.get_model() as SingleSelection;
                    if (item_selection == null) return;

                    var item = item_selection.get_selected_item() as FileItemModel;
                    if (item != null && !item.is_directory()) {
                        // Trouver le fichier correspondant dans l'autre liste
                        var other_store = is_left ? right_store : left_store;
                        FileItemModel? other_item = null;

                        for (uint i = 0; i < other_store.get_n_items(); i++) {
                            var file = other_store.get_item(i) as FileItemModel;
                            if (file != null && file.name == item.name && !file.is_directory()) {
                                other_item = file;
                                break;
                            }
                        }

                        // Si l'autre fichier existe, comparer les deux
                        if (other_item != null) {
                            string left_file = is_left ? item.path : other_item.path;
                            string right_file = is_left ? other_item.path : item.path;
                            file_diff_requested(left_file, right_file);
                        }
                    }
                }
            });
            list_view.add_controller(gesture_click);

            return list_view;
        }

        /**
         * Charge le contenu des deux répertoires
         */
        private void load_directory_content() {
            // Réinitialiser les compteurs
            total_files = 0;
            identical_files = 0;
            different_files = 0;
            only_left_files = 0;
            only_right_files = 0;

            // Charger le contenu du répertoire de gauche
            left_store.remove_all();
            try {
                load_directory(left_path, left_store);
            } catch (Error e) {
                warning("Erreur lors du chargement du répertoire gauche: %s", e.message);
            }

            // Charger le contenu du répertoire de droite
            right_store.remove_all();
            try {
                load_directory(right_path, right_store);
            } catch (Error e) {
                warning("Erreur lors du chargement du répertoire droit: %s", e.message);
            }

            // Analyser les différences pour les statistiques
            calculate_statistics();

            // Mettre à jour l'affichage
            apply_filters();

            // Mettre à jour les statistiques dans l'interface
            update_statistics_label();
        }

        /**
         * Calcule les statistiques de comparaison entre les deux répertoires
         */
        private void calculate_statistics() {
            total_files = 0;
            identical_files = 0;
            different_files = 0;
            only_left_files = 0;
            only_right_files = 0;

            // Parcourir le répertoire de gauche
            for (uint i = 0; i < left_store.get_n_items(); i++) {
                var left_item = left_store.get_item(i) as FileItemModel;
                if (left_item == null) continue;

                total_files++;

                bool found = false;

                // Chercher le fichier correspondant à droite
                for (uint j = 0; j < right_store.get_n_items(); j++) {
                    var right_item = right_store.get_item(j) as FileItemModel;
                    if (right_item != null && right_item.name == left_item.name) {
                        found = true;

                        // Vérifier si identique (taille et date)
                        if (right_item.size == left_item.size &&
                            right_item.modified_time.compare(left_item.modified_time) == 0) {
                            identical_files++;
                        } else {
                            different_files++;
                        }

                        break;
                    }
                }

                if (!found) {
                    only_left_files++;
                }
            }

            // Parcourir le répertoire de droite pour trouver les fichiers uniquement présents à droite
            for (uint i = 0; i < right_store.get_n_items(); i++) {
                var right_item = right_store.get_item(i) as FileItemModel;
                if (right_item == null) continue;

                bool found = false;

                for (uint j = 0; j < left_store.get_n_items(); j++) {
                    var left_item = left_store.get_item(j) as FileItemModel;
                    if (left_item != null && left_item.name == right_item.name) {
                        found = true;
                        break;
                    }
                }

                if (!found) {
                    only_right_files++;
                    total_files++; // Ajouter au total car non compté précédemment
                }
            }
        }

        /**
         * Met à jour l'étiquette des statistiques dans l'interface
         */
        private void update_statistics_label() {
            string stats_text = _("Total: %d | Identiques: %d | Différents: %d | Uniques à gauche: %d | Uniques à droite: %d")
                .printf(total_files, identical_files, different_files, only_left_files, only_right_files);

            stats_label.set_text(stats_text);
        }

        /**
         * Charge le contenu d'un répertoire dans un ListStore
         */
        private void load_directory(string path, GLib.ListStore store) throws Error {
            var directory = File.new_for_path(path);
            var enumerator = directory.enumerate_children(
                "standard::*,time::modified,unix::mode",
                FileQueryInfoFlags.NONE
            );

            FileInfo info;
            while ((info = enumerator.next_file()) != null) {
                var file_path = Path.build_filename(path, info.get_name());
                var item = new FileItemModel.from_file_info(file_path, info);
                store.append(item);
            }

            // Trier: d'abord les dossiers, puis les fichiers, par ordre alphabétique
            store.sort((a, b) => {
                var file_a = a as FileItemModel;
                var file_b = b as FileItemModel;

                if (file_a.is_directory() && !file_b.is_directory())
                    return -1;
                if (!file_a.is_directory() && file_b.is_directory())
                    return 1;
                return file_a.name.collate(file_b.name);
            });
        }

        /**
         * Détermine le statut de comparaison d'un fichier
         * @return "only_here", "different", "identical" ou null
         */
        private string? get_comparison_status(FileItemModel file_item, bool is_left) {
            var store_to_check = is_left ? right_store : left_store;
            string file_name = file_item.name;

            bool found = false;
            bool identical = false;

            for (uint i = 0; i < store_to_check.get_n_items(); i++) {
                var other_item = store_to_check.get_item(i) as FileItemModel;
                if (other_item != null && other_item.name == file_name) {
                    found = true;

                    // Vérifier si les fichiers sont identiques (taille + date)
                    if (other_item.size == file_item.size &&
                        other_item.modified_time.compare(file_item.modified_time) == 0) {
                        identical = true;
                    }

                    break;
                }
            }

            if (!found) {
                return "only_here";
            } else if (identical) {
                return "identical";
            } else {
                return "different";
            }
        }

        /**
         * Met à jour l'état des boutons en fonction des sélections
         */
        private void update_buttons() {
            var left_selection = left_list_view.get_model() as SingleSelection;
            var right_selection = right_list_view.get_model() as SingleSelection;

            var left_item = left_selection.get_selected_item() as FileItemModel;
            var right_item = right_selection.get_selected_item() as FileItemModel;

            // Activer le bouton de comparaison si les deux côtés ont une sélection
            // et que ce ne sont pas des dossiers
            bool can_diff = left_item != null && right_item != null &&
                            !left_item.is_directory() && !right_item.is_directory();

            diff_button.set_sensitive(can_diff);

            // Activer le bouton de copie vers la gauche si un élément est sélectionné à droite
            copy_to_left_button.set_sensitive(right_item != null);

            // Activer le bouton de copie vers la droite si un élément est sélectionné à gauche
            copy_to_right_button.set_sensitive(left_item != null);
        }

        /**
         * Gestionnaire pour l'affichage des fichiers identiques
         */
        private void on_show_identical_toggled() {
            apply_filters();
        }

        /**
         * Applique les filtres aux deux listes
         */
        private void apply_filters() {
            left_filter.changed(FilterChange.DIFFERENT);
            right_filter.changed(FilterChange.DIFFERENT);
        }

        /**
         * Gestionnaire pour le bouton rafraîchir
         */
        private void on_refresh_clicked() {
            load_directory_content();
        }

        /**
         * Gestionnaire pour le bouton de synchronisation
         */
        private void on_sync_all_clicked() {
            // Créer une boîte de dialogue pour choisir la direction de synchronisation
            var dialog = new Adw.AlertDialog(
                _("Synchronisation des fichiers"),
                _("Dans quelle direction souhaitez-vous synchroniser les fichiers ?")
            );

            dialog.add_response("left_to_right", _("Gauche → Droite"));
            dialog.add_response("right_to_left", _("Droite → Gauche"));
            dialog.add_response("cancel", _("Annuler"));

            dialog.set_response_appearance("left_to_right", Adw.ResponseAppearance.SUGGESTED);
            dialog.set_response_appearance("right_to_left", Adw.ResponseAppearance.SUGGESTED);

            dialog.response.connect((response) => {
                if (response == "left_to_right") { // Gauche vers Droite
                    synchronize_files(true);
                } else if (response == "right_to_left") { // Droite vers Gauche
                    synchronize_files(false);
                }

                dialog.destroy();
            });

            dialog.present(this.get_root() as Gtk.Window);
        }

        /**
         * Synchronise les fichiers entre les deux répertoires
         * @param left_to_right Si true, synchronise de gauche à droite, sinon de droite à gauche
         */
        private void synchronize_files(bool left_to_right) {
            var source_store = left_to_right ? left_store : right_store;
            var target_path = left_to_right ? right_path : left_path;

            int success_count = 0;
            int error_count = 0;

            // Parcourir les fichiers
            for (uint i = 0; i < source_store.get_n_items(); i++) {
                var file_item = source_store.get_item(i) as FileItemModel;
                if (file_item == null || file_item.is_directory()) continue;

                string source_path = file_item.path;
                string target_file = Path.build_filename(target_path, file_item.name);

                try {
                    var source_file = File.new_for_path(source_path);
                    var target_file_obj = File.new_for_path(target_file);

                    // Vérifier si le fichier existe et s'il est différent
                    bool should_copy = true;

                    if (target_file_obj.query_exists()) {
                        var info = target_file_obj.query_info(
                            "standard::size,time::modified",
                            FileQueryInfoFlags.NONE
                        );

                        if (info.get_size() == file_item.size &&
                            info.get_modification_date_time().compare(file_item.modified_time) == 0) {
                            should_copy = false; // Les fichiers sont identiques
                        }
                    }

                    if (should_copy) {
                        source_file.copy(target_file_obj, FileCopyFlags.OVERWRITE, null, null);
                        success_count++;
                    }

                } catch (Error e) {
                    warning("Erreur lors de la synchronisation: %s", e.message);
                    error_count++;
                }
            }

            // Afficher un résumé
            var dialog = new Adw.AlertDialog(
                _("Synchronisation terminée"),
                _("Fichiers copiés: %d\nErreurs: %d").printf(success_count, error_count)
            );

            dialog.add_response("ok", _("OK"));
            dialog.set_response_appearance("ok", Adw.ResponseAppearance.SUGGESTED);

            dialog.response.connect(() => {
                dialog.destroy();
                load_directory_content(); // Rafraîchir l'affichage
            });

            dialog.present(this.get_root() as Gtk.Window);
        }

        /**
         * Gestionnaire pour le bouton de comparaison
         */
        private void on_diff_clicked() {
            var left_selection = left_list_view.get_model() as SingleSelection;
            var right_selection = right_list_view.get_model() as SingleSelection;

            var left_item = left_selection.get_selected_item() as FileItemModel;
            var right_item = right_selection.get_selected_item() as FileItemModel;

            if (left_item != null && right_item != null) {
                // Émettre le signal pour la comparaison
                file_diff_requested(left_item.path, right_item.path);
            }
        }

        /**
         * Gestionnaire pour le bouton de copie vers la gauche
         */
        private void on_copy_to_left_clicked() {
            // Obtenir le fichier sélectionné dans la liste de droite
            var right_selection = right_list_view.get_model() as SingleSelection;
            var right_item = right_selection.get_selected_item() as FileItemModel;

            if (right_item != null) {
                // Copier le fichier vers le répertoire de gauche
                string source_path = right_item.path;
                string dest_path = Path.build_filename(left_path, right_item.name);

                copy_file(source_path, dest_path);
            }
        }

        /**
         * Gestionnaire pour le bouton de copie vers la droite
         */
        private void on_copy_to_right_clicked() {
            // Obtenir le fichier sélectionné dans la liste de gauche
            var left_selection = left_list_view.get_model() as SingleSelection;
            var left_item = left_selection.get_selected_item() as FileItemModel;

            if (left_item != null) {
                // Copier le fichier vers le répertoire de droite
                string source_path = left_item.path;
                string dest_path = Path.build_filename(right_path, left_item.name);

                copy_file(source_path, dest_path);
            }
        }

        /**
         * Copie un fichier d'un chemin à un autre
         */
        private void copy_file(string source_path, string dest_path) {
            try {
                var source_file = File.new_for_path(source_path);
                var dest_file = File.new_for_path(dest_path);

                // Vérifier si le fichier existe déjà
                if (dest_file.query_exists()) {
                    // Demander confirmation pour l'écrasement
                    if (!confirm_dialog(
                        _("Confirmation de l'écrasement"),
                        _("Le fichier %s existe déjà. Voulez-vous l'écraser ?").printf(dest_path),
                        _("Écraser")
                    )) {
                        return;
                    }
                }

                // Copier le fichier
                source_file.copy(dest_file, FileCopyFlags.OVERWRITE, null, null);

                // Rafraîchir l'affichage
                load_directory_content();

            } catch (Error e) {
                warning("Erreur lors de la copie du fichier: %s", e.message);

                // Afficher une erreur
                error_dialog(
                    _("Erreur lors de la copie"),
                    _("Erreur lors de la copie: %s").printf(e.message)
                );
            }
        }

        /**
         * Affiche un dialogue de confirmation
         */
        private bool confirm_dialog(string title, string message, string confirm_text) {
            // Remplacer MessageDialog par Adw.AlertDialog (GTK4)
            var dialog = new Adw.AlertDialog(title, message);
            dialog.add_response("cancel", _("Annuler"));
            dialog.add_response("confirm", confirm_text);
            dialog.set_response_appearance("confirm", Adw.ResponseAppearance.SUGGESTED);

            bool confirmed = false;
            dialog.response.connect((response) => {
                confirmed = (response == "confirm");
            });

            dialog.present(this.get_root() as Gtk.Window);

            // Remplacer dialog.run() qui n'existe plus dans GTK4
            return confirmed;
        }

        /**
         * Affiche un dialogue d'avertissement
         */
        private void warning_dialog(string title, string message) {
            // Remplacer MessageDialog par Adw.AlertDialog (GTK4)
            var dialog = new Adw.AlertDialog(title, message);
            dialog.add_response("ok", _("OK"));

            dialog.present(this.get_root() as Gtk.Window);
        }

        /**
         * Affiche un dialogue d'erreur
         */
        private void error_dialog(string title, string message) {
            // Remplacer MessageDialog par Adw.AlertDialog (GTK4)
            var dialog = new Adw.AlertDialog(title, message);
            dialog.add_response("ok", _("OK"));
            dialog.set_response_appearance("ok", Adw.ResponseAppearance.DESTRUCTIVE);

            dialog.present(this.get_root() as Gtk.Window);
        }

        /**
         * Affiche une boîte de dialogue permettant de sauvegarder les modifications
         */
        private bool save_changes_dialog() {
            // Remplacer MessageDialog par Adw.AlertDialog (GTK4)
            var dialog = new Adw.AlertDialog(
                _("Sauvegarder les modifications ?"),
                _("Des modifications ont été apportées au fichier. Voulez-vous les sauvegarder avant de fermer ?")
            );
            dialog.add_response("cancel", _("Annuler"));
            dialog.add_response("discard", _("Ne pas sauvegarder"));
            dialog.add_response("save", _("Sauvegarder"));
            dialog.set_response_appearance("save", Adw.ResponseAppearance.SUGGESTED);
            dialog.set_response_appearance("discard", Adw.ResponseAppearance.DESTRUCTIVE);

            string response_id = "cancel"; // Valeur par défaut
            dialog.response.connect((response) => {
                response_id = response;
            });

            dialog.present(this.get_root() as Gtk.Window);

            // Remplacer dialog.run() qui n'existe plus
            return response_id == "save";
        }
    }
}
