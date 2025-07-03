/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2025 Your Name <your.email@example.com>
 */

using Gtk;
using Adw;
using Sambo.HuggingFace;

namespace Sambo.View.Windows {

    public class HuggingFaceModelsWindow : Adw.Window {
        private ApplicationController controller;
        private HuggingFaceAPI api;
        private Gee.ArrayList<HuggingFaceModel> current_models;
        private HuggingFaceModel? selected_model;
        private Gee.ArrayList<HuggingFaceFile> selected_files;
        private string current_search_query = "";

        // Interface utilisateur
        private Adw.HeaderBar header_bar;
        private Adw.ToastOverlay toast_overlay;

        // Liste des modèles
        private Gtk.SearchEntry search_entry;
        private Gtk.Spinner search_spinner;
        private Gtk.Label models_status_label;
        private Gtk.ListBox models_list;
        private Gtk.Button refresh_button;

        // Filtres et tri
        private Gtk.DropDown sort_dropdown;
        private Gtk.DropDown library_dropdown;
        private Gtk.DropDown pipeline_dropdown;
        private Gtk.Entry tags_entry;

        // Détails du modèle sélectionné
        private Gtk.Paned split_view;
        private Gtk.ScrolledWindow details_scroll;
        private Gtk.Box details_box;
        private Gtk.Label model_title_label;
        private Gtk.Label model_description_label;
        private Gtk.Label model_info_label;
        private Gtk.ListBox files_list;
        private Gtk.Button download_button;
        private Gtk.Label total_size_label;
        private Gtk.Button back_button;

        // Telechargement
        private uint search_timeout_id = 0;

        public HuggingFaceModelsWindow(ApplicationController controller) {
            this.controller = controller;

            api = new HuggingFaceAPI();
            current_models = new Gee.ArrayList<HuggingFaceModel>();
            selected_files = new Gee.ArrayList<HuggingFaceFile>();

            setup_ui();
        }

        private void setup_ui() {
            this.title = "Modèles HuggingFace";
            this.default_width = 1100;
            this.default_height = 700;

            // Toast overlay principal
            toast_overlay = new Adw.ToastOverlay();
            this.content = toast_overlay;

            // Configurer la clé API si elle est disponible
            var api_key = controller.get_config_manager().get_string("AI", "huggingface_api_key", "");
            if (api_key.length > 0) {
                api.set_api_key(api_key);
                show_toast("Clé API HuggingFace configurée - Accès complet aux modèles");
            } else {
                // Afficher l'information sur l'accès limité
                show_api_status_info();
            }

            setup_models_page();
            load_popular_models();
        }

        private void setup_models_page() {
            var main_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);

            // Header bar
            header_bar = new Adw.HeaderBar();
            header_bar.title_widget = new Adw.WindowTitle("Modeles HuggingFace", "Parcourir et telecharger des modeles IA");

            // Bouton des préférences
            var preferences_button = new Gtk.Button.from_icon_name("preferences-system-symbolic");
            preferences_button.tooltip_text = "Ouvrir les préférences";
            preferences_button.clicked.connect(() => {
                show_toast("Ouvrez les préférences via le menu principal pour configurer la clé API HuggingFace");
            });
            header_bar.pack_start(preferences_button);

            // Bouton d'actualisation
            refresh_button = new Gtk.Button.from_icon_name("view-refresh-symbolic");
            refresh_button.tooltip_text = "Actualiser la liste";
            refresh_button.clicked.connect(load_popular_models);
            header_bar.pack_end(refresh_button);

            main_box.append(header_bar);

            // Configuration du Paned
            split_view = new Gtk.Paned(Gtk.Orientation.HORIZONTAL);
            split_view.hexpand = true;
            split_view.vexpand = true;
            split_view.position = 400; // Largeur initiale de la sidebar

            // Sidebar avec la liste des modèles
            setup_models_sidebar();

            // Contenu principal avec les détails
            setup_model_details();

            main_box.append(split_view);

            toast_overlay.child = main_box;
        }

        private void setup_models_sidebar() {
            var sidebar_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);

            // Barre de recherche
            var search_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
            search_box.margin_top = 12;
            search_box.margin_bottom = 12;
            search_box.margin_start = 12;
            search_box.margin_end = 12;

            search_entry = new Gtk.SearchEntry();
            search_entry.placeholder_text = "Rechercher des modèles...";
            search_entry.hexpand = true;
            search_entry.search_changed.connect(on_search_changed);

            search_spinner = new Gtk.Spinner();
            search_spinner.visible = false;

            search_box.append(search_entry);
            search_box.append(search_spinner);
            sidebar_box.append(search_box);

            // Label de statut des modèles
            models_status_label = new Gtk.Label("");
            models_status_label.add_css_class("dim-label");
            models_status_label.margin_start = 12;
            models_status_label.margin_end = 12;
            models_status_label.margin_bottom = 6;
            models_status_label.halign = Gtk.Align.START;
            sidebar_box.append(models_status_label);

            // Interface de filtres
            setup_filters_ui(sidebar_box);

            // Liste des modèles
            var models_scrolled = new Gtk.ScrolledWindow();
            models_scrolled.vexpand = true;

            models_list = new Gtk.ListBox();
            models_list.add_css_class("boxed-list");
            models_list.margin_start = 12;
            models_list.margin_end = 12;
            models_list.margin_bottom = 12;
            models_list.set_selection_mode(Gtk.SelectionMode.SINGLE);
            models_list.row_selected.connect(on_model_selected);

            models_scrolled.child = models_list;
            sidebar_box.append(models_scrolled);

            split_view.start_child = sidebar_box;
        }        private void setup_model_details() {
            details_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);

            // Status page par défaut
            var status_page = create_status_page("Selectionnez un modele", "Choisissez un modele dans la liste pour voir ses details");

            // Scroll pour les détails
            details_scroll = new Gtk.ScrolledWindow();
            details_scroll.vexpand = true;
            details_scroll.child = status_page;

            details_box.append(details_scroll);

            split_view.end_child = details_box;
        }

        private void setup_filters_ui(Gtk.Box parent_box) {
            var filters_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 6);
            filters_box.margin_start = 12;
            filters_box.margin_end = 12;
            filters_box.margin_bottom = 6;

            // Première ligne : Tri et Format
            var filters_row1 = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);

            // Tri
            var sort_label = new Gtk.Label("Tri:");
            sort_label.add_css_class("dim-label");
            sort_label.halign = Gtk.Align.START;
            filters_row1.append(sort_label);

            var sort_strings = new Gtk.StringList(null);
            sort_strings.append("Populaires");
            sort_strings.append("Récents");
            sort_strings.append("Modifiés");
            sort_strings.append("Likes");
            sort_strings.append("Alphabétique");

            sort_dropdown = new Gtk.DropDown(sort_strings, null);
            sort_dropdown.selected = 0; // Populaires par défaut
            sort_dropdown.hexpand = true;
            sort_dropdown.notify["selected"].connect(on_filters_changed);
            filters_row1.append(sort_dropdown);

            // Format
            var library_label = new Gtk.Label("Format:");
            library_label.add_css_class("dim-label");
            library_label.halign = Gtk.Align.START;
            filters_row1.append(library_label);

            var library_strings = new Gtk.StringList(null);
            library_strings.append("Tous");
            library_strings.append("GGUF");
            library_strings.append("SafeTensors");
            library_strings.append("PyTorch");
            library_strings.append("ONNX");
            library_strings.append("Transformers");

            library_dropdown = new Gtk.DropDown(library_strings, null);
            library_dropdown.selected = 0; // Tous par défaut
            library_dropdown.hexpand = true;
            library_dropdown.notify["selected"].connect(on_filters_changed);
            filters_row1.append(library_dropdown);

            filters_box.append(filters_row1);

            // Deuxième ligne : Type et Tags
            var filters_row2 = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);

            // Type de tâche
            var pipeline_label = new Gtk.Label("Type:");
            pipeline_label.add_css_class("dim-label");
            pipeline_label.halign = Gtk.Align.START;
            filters_row2.append(pipeline_label);

            var pipeline_strings = new Gtk.StringList(null);
            pipeline_strings.append("Tous");
            pipeline_strings.append("Génération texte");
            pipeline_strings.append("Classification");
            pipeline_strings.append("Traduction");
            pipeline_strings.append("Reconnaissance vocale");
            pipeline_strings.append("Conversationnel");

            pipeline_dropdown = new Gtk.DropDown(pipeline_strings, null);
            pipeline_dropdown.selected = 0; // Tous par défaut
            pipeline_dropdown.hexpand = true;
            pipeline_dropdown.notify["selected"].connect(on_filters_changed);
            filters_row2.append(pipeline_dropdown);

            // Tags personnalisés
            var tags_label = new Gtk.Label("Tags:");
            tags_label.add_css_class("dim-label");
            tags_label.halign = Gtk.Align.START;
            filters_row2.append(tags_label);

            tags_entry = new Gtk.Entry();
            tags_entry.placeholder_text = "7b,chat,instruct...";
            tags_entry.hexpand = true;
            tags_entry.changed.connect(on_filters_changed);
            filters_row2.append(tags_entry);

            filters_box.append(filters_row2);

            parent_box.append(filters_box);
        }

        private void on_filters_changed() {
            stdout.printf("[DEBUG] Filtres changés - déclenchement de la recherche\n");
            // Déclencher une nouvelle recherche avec les filtres actuels
            if (search_timeout_id > 0) {
                Source.remove(search_timeout_id);
            }

            search_timeout_id = Timeout.add(500, () => {
                search_timeout_id = 0;
                perform_filtered_search();
                return false;
            });
        }
        private Adw.StatusPage create_status_page(string title, string description) {
            var status_page = new Adw.StatusPage();
            status_page.title = title;
            status_page.description = description;
            status_page.icon_name = "system-search-symbolic";
            return status_page;
        }





        private void load_popular_models() {
            perform_filtered_search();
        }

        private void perform_filtered_search() {
            refresh_button.sensitive = false;
            search_spinner.spinning = true;
            search_spinner.visible = true;

            // Récupérer les paramètres des filtres
            var query = search_entry.get_text().strip();
            var limit = controller.get_config_manager().get_integer("AI", "models_limit", 50);

            // Tri
            var sort_params = get_sort_params();
            var sort = sort_params[0];
            var direction = sort_params[1];

            // Filtres
            var library = get_library_filter();
            var pipeline_tag = get_pipeline_filter();
            var tags = tags_entry.get_text().strip();

            // Debug: afficher les filtres appliqués
            stdout.printf("[DEBUG] Filtres appliqués:\n");
            stdout.printf("  - Query: %s\n", query.length > 0 ? query : "null");
            stdout.printf("  - Library: %s\n", library ?? "null");
            stdout.printf("  - Pipeline: %s\n", pipeline_tag ?? "null");
            stdout.printf("  - Tags: %s\n", tags.length > 0 ? tags : "null");
            stdout.printf("  - Sort: %s (%s)\n", sort, direction);
            stdout.printf("  - Limit: %d\n", limit);

            if (query.length > 0) {
                models_status_label.label = @"Recherche de \"$(query)\" avec filtres...";
            } else {
                models_status_label.label = "Chargement des modèles avec filtres...";
            }

            api.search_models_with_filters_async.begin(
                query.length > 0 ? query : null,
                limit,
                sort,
                direction,
                library,
                pipeline_tag,
                tags.length > 0 ? tags : null,
                on_filtered_search_completed
            );
        }

        private string[] get_sort_params() {
            switch (sort_dropdown.selected) {
                case 0: return {"downloads", "-1"}; // Populaires
                case 1: return {"created_at", "-1"}; // Récents
                case 2: return {"modified", "-1"}; // Modifiés
                case 3: return {"likes", "-1"}; // Likes
                case 4: return {"author", "1"}; // Alphabétique
                default: return {"downloads", "-1"};
            }
        }

        private string? get_library_filter() {
            switch (library_dropdown.selected) {
                case 0: return null; // Tous
                case 1: return "gguf"; // GGUF
                case 2: return "safetensors"; // SafeTensors
                case 3: return "pytorch"; // PyTorch
                case 4: return "onnx"; // ONNX
                case 5: return "transformers"; // Transformers
                default: return null;
            }
        }

        private string? get_pipeline_filter() {
            switch (pipeline_dropdown.selected) {
                case 0: return null; // Tous
                case 1: return "text-generation"; // Génération texte
                case 2: return "text-classification"; // Classification
                case 3: return "translation"; // Traduction
                case 4: return "automatic-speech-recognition"; // Reconnaissance vocale
                case 5: return "conversational"; // Conversationnel
                default: return null;
            }
        }

        private void on_filtered_search_completed(Object? obj, AsyncResult res) {
            try {
                var models = api.search_models_with_filters_async.end(res);
                display_models(models);
                refresh_button.sensitive = true;
                search_spinner.spinning = false;
                search_spinner.visible = false;
            } catch (Error e) {
                var improved_message = improve_error_message(e.message);
                show_error("Erreur lors de la recherche filtrée : " + improved_message);
                stdout.printf("[HuggingFaceModelsWindow] Erreur recherche filtrée: %s\n", e.message);
                refresh_button.sensitive = true;
                search_spinner.spinning = false;
                search_spinner.visible = false;
            }
        }

        private void on_search_changed() {
            if (search_timeout_id != 0) {
                Source.remove(search_timeout_id);
            }

            search_timeout_id = Timeout.add(500, on_search_timeout);
        }

        private bool on_search_timeout() {
            search_timeout_id = 0;
            perform_filtered_search();
            return false;
        }

        private void display_models(Gee.List<HuggingFaceModel> models) {
            // Appliquer le filtre "modèles téléchargeables uniquement" si activé
            var config = controller.get_config_manager();
            bool show_downloadable_only = config.get_boolean("AI", "show_downloadable_only", false);

            var filtered_models = new Gee.ArrayList<HuggingFaceModel>();

            foreach (var model in models) {
                if (show_downloadable_only) {
                    // Filtrer uniquement les modèles téléchargeables
                    if (model.is_downloadable()) {
                        filtered_models.add(model);
                    }
                } else {
                    // Afficher tous les modèles
                    filtered_models.add(model);
                }
            }

            current_models.clear();
            current_models.add_all(filtered_models);

            // Debug: afficher les IDs des premiers modèles pour vérifier le filtrage
            stdout.printf("[DEBUG] Modèles reçus (%d), après filtrage téléchargeables (%d):\n",
                         models.size, filtered_models.size);
            int count = 0;
            foreach (var model in filtered_models) {
                if (count < 10) { // Afficher seulement les 10 premiers
                    stdout.printf("  - %s (téléchargeable: %s)\n", model.id,
                                 model.is_downloadable() ? "oui" : "non");
                }
                count++;
                if (count >= 10) break;
            }

            // Vider la liste actuelle
            var child = models_list.get_first_child();
            while (child != null) {
                var next = child.get_next_sibling();
                models_list.remove(child);
                child = next;
            }

            if (filtered_models.size == 0) {
                var no_results = new Adw.ActionRow();
                if (show_downloadable_only && models.size > 0) {
                    no_results.title = "Aucun modèle téléchargeable trouvé";
                    no_results.subtitle = "Désactivez le filtre 'modèles téléchargeables uniquement' dans les préférences";
                } else {
                    no_results.title = "Aucun modèle trouvé";
                    no_results.subtitle = "Essayez avec d'autres termes de recherche";
                }
                models_list.append(no_results);

                string status_msg;
                if (show_downloadable_only && models.size > 0) {
                    status_msg = "%d modèle(s) trouvé(s), 0 téléchargeable(s)".printf(models.size);
                } else {
                    status_msg = "Aucun modèle trouvé";
                }
                models_status_label.label = status_msg;
                return;
            }

            // Ajouter les nouveaux modèles
            foreach (var model in filtered_models) {
                var row = create_model_row(model);
                models_list.append(row);
            }

            // Mettre à jour le statut avec informations de filtrage
            var query = search_entry.get_text().strip();
            var limit = controller.get_config_manager().get_integer("AI", "models_limit", 50);

            string status_msg;
            if (query.length > 0) {
                if (show_downloadable_only && models.size != filtered_models.size) {
                    status_msg = @"$(filtered_models.size) modèle(s) téléchargeable(s) trouvé(s) pour \"$(query)\" ($(models.size) au total)";
                } else if (filtered_models.size >= limit) {
                    status_msg = @"$(filtered_models.size) modèles trouvés pour \"$(query)\" ($(limit) premiers affichés)";
                } else {
                    status_msg = @"$(filtered_models.size) modèle(s) trouvé(s) pour \"$(query)\"";
                }
            } else {
                if (show_downloadable_only && models.size != filtered_models.size) {
                    status_msg = @"$(filtered_models.size) modèle(s) téléchargeable(s) chargé(s) ($(models.size) au total)";
                } else if (filtered_models.size >= limit) {
                    status_msg = @"$(filtered_models.size) modèles chargés ($(limit) premiers)";
                } else {
                    status_msg = @"$(filtered_models.size) modèles chargés";
                }
            }
            models_status_label.label = status_msg;
            show_toast(@"$(filtered_models.size) modèle(s) affiché(s)");
        }

        private Gtk.ListBoxRow create_model_row(HuggingFaceModel model) {
            var row = new Adw.ActionRow();
            row.title = model.id;
            row.set_data("model", model);
            
            // Configurer l'ellipsize pour éviter les avertissements GTK
            row.title_lines = 1;
            row.subtitle_lines = 1;

            // Sous-titre avec informations
            var subtitle = @"Par $(model.author) • $(model.downloads) telechargements";
            if (model.likes > 0) {
                subtitle += @" • $(model.likes) likes";
            }
            row.subtitle = subtitle;

            // Icône selon le statut
            var icon = new Gtk.Image.from_icon_name(model.private_model ? "channel-secure-symbolic" : "folder-symbolic");
            row.add_prefix(icon);

            // Tags (limités à 2-3 pour ne pas surcharger)
            if (model.tags.length > 0) {
                var tags_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
                tags_box.halign = Gtk.Align.END;

                int count = 0;
                foreach (var tag in model.tags) {
                    if (count >= 2) break;

                    var tag_label = new Gtk.Label(tag);
                    tag_label.add_css_class("tag");
                    tag_label.add_css_class("caption");
                    tags_box.append(tag_label);
                    count++;
                }

                if (count > 0) {
                    row.add_suffix(tags_box);
                }
            }

            // Flèche pour indiquer qu'on peut cliquer
            var arrow = new Gtk.Image.from_icon_name("go-next-symbolic");
            row.add_suffix(arrow);

            return row;
        }        private void on_model_selected(Gtk.ListBoxRow? row) {
            if (row == null) {
                // Masquer les détails
                details_scroll.child = create_status_page("Selectionnez un modele", "Choisissez un modele dans la liste pour voir ses details");
                selected_model = null;
                return;
            }

            var action_row = row as Adw.ActionRow;
            if (action_row == null) return;

            var model = action_row.get_data<HuggingFaceModel>("model");
            if (model == null) return;

            selected_model = model;
            load_model_details();
        }

        private void load_model_details() {
            if (selected_model == null) return;

            // Créer le contenu des détails
            var details_content = new Gtk.Box(Gtk.Orientation.VERTICAL, 24);
            details_content.margin_top = 24;
            details_content.margin_bottom = 24;
            details_content.margin_start = 24;
            details_content.margin_end = 24;

            // En-tête du modèle
            var header_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 12);

            model_title_label = new Gtk.Label(selected_model.id);
            model_title_label.add_css_class("title-1");
            model_title_label.halign = Gtk.Align.START;
            model_title_label.wrap = true;

            model_description_label = new Gtk.Label(selected_model.description ?? "Pas de description disponible");
            model_description_label.add_css_class("body");
            model_description_label.halign = Gtk.Align.START;
            model_description_label.wrap = true;
            model_description_label.lines = 3;

            var info_text = @"Auteur: $(selected_model.author)\n";
            info_text += @"Telechargements: $(selected_model.downloads)\n";
            info_text += @"Likes: $(selected_model.likes)\n";
            
            // Afficher la date de création si disponible
            if (selected_model.created_at != null) {
                info_text += @"Date de creation: $(selected_model.created_at.format("%d/%m/%Y à %H:%M"))\n";
            }
            
            // Afficher la date de dernière modification si disponible
            if (selected_model.last_modified != null) {
                info_text += @"Derniere modification: $(selected_model.last_modified.format("%d/%m/%Y à %H:%M"))\n";
            }
            
            info_text += @"Visibilite: $(selected_model.private_model ? "Prive" : "Public")";

            model_info_label = new Gtk.Label(info_text);
            model_info_label.add_css_class("dim-label");
            model_info_label.halign = Gtk.Align.START;
            model_info_label.wrap = true;

            header_box.append(model_title_label);
            header_box.append(model_description_label);
            header_box.append(model_info_label);

            // Tags
            if (selected_model.tags.length > 0) {
                var tags_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
                tags_box.margin_top = 12;

                foreach (var tag in selected_model.tags) {
                    var tag_label = new Gtk.Label(tag);
                    tag_label.add_css_class("tag");
                    tag_label.add_css_class("caption");
                    tags_box.append(tag_label);
                }

                header_box.append(tags_box);
            }

            details_content.append(header_box);

            // Séparateur
            var separator = new Gtk.Separator(Gtk.Orientation.HORIZONTAL);
            details_content.append(separator);

            // Section des fichiers
            var files_section = new Gtk.Box(Gtk.Orientation.VERTICAL, 12);

            var files_label = new Gtk.Label("Fichiers du modèle");
            files_label.add_css_class("title-3");
            files_label.halign = Gtk.Align.START;
            files_section.append(files_label);

            // Liste des fichiers
            files_list = new Gtk.ListBox();
            files_list.add_css_class("boxed-list");
            files_list.set_selection_mode(Gtk.SelectionMode.NONE);

            var files_scroll = new Gtk.ScrolledWindow();
            files_scroll.max_content_height = 300;
            files_scroll.propagate_natural_height = true;
            files_scroll.child = files_list;

            files_section.append(files_scroll);

            // Information sur le répertoire de destination
            var destination_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 8);
            destination_box.halign = Gtk.Align.CENTER;
            destination_box.add_css_class("dim-label");

            var folder_icon = new Gtk.Image.from_icon_name("folder-symbolic");
            folder_icon.set_icon_size(Gtk.IconSize.NORMAL);

            var config = controller.get_config_manager();
            var models_dir = config.get_string("AI", "models_directory", "");
            var destination_label = new Gtk.Label("");

            if (models_dir == null || models_dir.length == 0) {
                destination_label.set_text("Destination : Non configuré");
                destination_label.add_css_class("error");
            } else {
                destination_label.set_text(@"Destination : $(models_dir)");
            }

            destination_box.append(folder_icon);
            destination_box.append(destination_label);
            files_section.append(destination_box);

            // Barre d'informations de telechargement
            var download_info_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 12);
            download_info_box.halign = Gtk.Align.CENTER;

            total_size_label = new Gtk.Label("Chargement des fichiers...");
            total_size_label.add_css_class("dim-label");

            download_button = new Gtk.Button.with_label("Telecharger");
            download_button.add_css_class("suggested-action");
            download_button.clicked.connect(on_download_clicked);
            download_button.sensitive = false;

            download_info_box.append(total_size_label);
            download_info_box.append(download_button);

            files_section.append(download_info_box);
            details_content.append(files_section);

            // Remplacer le contenu du scroll
            details_scroll.child = details_content;

            // Charger les fichiers du modèle
            load_model_files();
        }

        private void load_model_files() {
            if (selected_model == null) return;

            // Afficher un indicateur de chargement
            total_size_label.label = "Chargement des fichiers...";

            load_model_files_async.begin();
        }

        /**
         * Méthode asynchrone pour charger les fichiers d'un modèle
         */
        private async void load_model_files_async() {
            if (selected_model == null) return;

            try {
                var files = yield api.get_model_files_async(selected_model.id);

                Idle.add(on_model_files_loaded_idle);
                // Stocker les fichiers pour le callback
                this.set_data("loaded_files", files);
            } catch (Error e) {
                // Stocker l'erreur pour le callback
                this.set_data("load_error", e.message);
                Idle.add(on_model_files_error_idle);
            }
        }

        /**
         * Callback pour le succès du chargement des fichiers (remplace lambda Idle.add)
         */
        private bool on_model_files_loaded_idle() {
            var files = this.get_data<Gee.List<HuggingFaceFile>>("loaded_files");
            if (files != null) {
                display_model_files(files);
            }
            return false;
        }

        /**
         * Callback pour les erreurs de chargement des fichiers (remplace lambda Idle.add)
         */
        private bool on_model_files_error_idle() {
            var error_message = this.get_data<string>("load_error");
            if (error_message != null) {
                var improved_message = improve_error_message(error_message);
                show_error("Erreur lors du chargement des fichiers : " + improved_message);
                stdout.printf("[HuggingFaceModelsWindow] Erreur chargement fichiers: %s\n", error_message);
                total_size_label.label = "Erreur lors du chargement des fichiers";
            }
            return false;
        }

        /**
         * Callback pour la sélection/désélection des fichiers (remplace lambda check.toggled)
         */
        private void on_file_check_toggled(Gtk.CheckButton check) {
            var file = check.get_data<HuggingFaceFile>("file");
            if (file == null) return;

            if (check.active) {
                if (!selected_files.contains(file)) {
                    selected_files.add(file);
                }
            } else {
                selected_files.remove(file);
            }
            update_download_info();
        }

        private void update_download_info() {
            int64 total_size = 0;
            foreach (var file in selected_files) {
                total_size += file.size;
            }

            // Vérifier l'état du répertoire de téléchargement
            string? validation_error = validate_models_directory();
            bool directory_valid = (validation_error == null);

            if (selected_files.size == 0) {
                total_size_label.label = "Aucun fichier sélectionné";
                download_button.sensitive = false;
            } else if (!directory_valid) {
                var size_str = format_size(total_size);
                total_size_label.label = @"$(selected_files.size) fichier(s) • $(size_str) - ⚠️ Répertoire invalide";
                download_button.sensitive = false;

                // Ajouter une classe CSS pour colorer en rouge
                total_size_label.add_css_class("error");
            } else {
                var size_str = format_size(total_size);
                total_size_label.label = @"$(selected_files.size) fichier(s) • $(size_str)";
                download_button.sensitive = true;

                // Retirer la classe d'erreur si elle était présente
                total_size_label.remove_css_class("error");
            }
        }

        private string format_size(int64 size) {
            if (size < 1024) return @"$(size) B";
            if (size < 1024 * 1024) return @"$((size / 1024)) KB";
            if (size < 1024 * 1024 * 1024) return @"$((size / (1024 * 1024))) MB";
            return @"$((size / (1024 * 1024 * 1024))) GB";
        }

        private void on_download_clicked() {
            if (selected_model == null || selected_files.size == 0) return;

            // Valider le répertoire de téléchargement avant de continuer
            string? validation_error = validate_models_directory();
            if (validation_error != null) {
                // Afficher une erreur et bloquer le téléchargement
                var error_dialog = new Adw.MessageDialog(this,
                    "Répertoire de téléchargement invalide",
                    validation_error);

                error_dialog.add_response("ok", "OK");
                error_dialog.add_response("preferences", "Ouvrir les préférences");
                error_dialog.set_response_appearance("preferences", Adw.ResponseAppearance.SUGGESTED);

                error_dialog.response.connect((response) => {
                    if (response == "preferences") {
                        // Ouvrir les préférences IA
                        open_preferences_ai();
                    }
                });

                error_dialog.present();
                return;
            }

            // Calculer la taille totale
            int64 total_size = 0;
            foreach (var file in selected_files) {
                total_size += file.size;
            }

            // Créer et afficher la boîte de dialogue de confirmation
            var dialog = new Adw.MessageDialog(this,
                "Confirmer le telechargement",
                @"Telecharger $(selected_files.size) fichier(s) du modele $(selected_model.id) ?\n\nTaille totale : $(format_size(total_size))");

            dialog.add_response("cancel", "Annuler");
            dialog.add_response("download", "Telecharger");
            dialog.set_response_appearance("download", Adw.ResponseAppearance.SUGGESTED);

            dialog.response.connect((response) => {
                if (response == "download") {
                    start_download();
                }
            });

            dialog.present();
        }

        private void start_download() {
            if (selected_model == null || selected_files.size == 0) return;

            // Creer et afficher la fenetre de telechargement
            var download_window = new HuggingFaceDownloadWindow(this, selected_model, selected_files, controller);
            download_window.present();
        }

        private void show_error(string message) {
            stdout.printf("[TRACE] HuggingFaceModelsWindow ERROR: %s\n", message);
            var toast = new Adw.Toast(message);

            // Augmenter le timeout pour les erreurs importantes
            if ("429" in message) {
                toast.timeout = 10; // Plus long pour les erreurs de limite de taux
            } else if ("401" in message || "403" in message) {
                toast.timeout = 8; // Messages de configuration API
            } else {
                toast.timeout = 5; // Autres erreurs
            }

            toast_overlay.add_toast(toast);
        }

        private void show_toast(string message) {
            stdout.printf("[TRACE] HuggingFaceModelsWindow TOAST: %s\n", message);
            var toast = new Adw.Toast(message);
            toast.timeout = 3;
            toast_overlay.add_toast(toast);
        }

        /**
         * Méthode pour afficher un message de succès (toast)
         */
        public void show_success(string message) {
            var toast = new Adw.Toast(message);
            toast.timeout = 3;
            toast_overlay.add_toast(toast);
        }

        /**
         * Améliore le message d'erreur pour une meilleure expérience utilisateur
         */
        private string improve_error_message(string error_message) {
            // Pour les toasts, on veut des messages plus courts
            if ("429" in error_message) {
                if ("Ajoutez une clé API" in error_message) {
                    return "Limite dépassée - Ajoutez une clé API ou patientez";
                } else {
                    return "Limite dépassée - Patientez quelques minutes";
                }
            } else if ("401" in error_message) {
                return "Clé API invalide - Vérifiez vos préférences";
            } else if ("403" in error_message) {
                return "Accès interdit - Vérifiez vos préférences";
            } else if ("500" in error_message || "502" in error_message || "503" in error_message) {
                return "Serveur indisponible - Réessayez plus tard";
            }
            return error_message;
        }

        /**
         * Affiche un message informatif sur l'état de la clé API
         */
        private void show_api_status_info() {
            var config_manager = controller.get_config_manager();
            var api_token = config_manager.get_string("AI", "huggingface_api_key", "");

            if (api_token == null || api_token.length == 0) {
                var info_message = "Accès limité à l'API HuggingFace. Ajoutez une clé API dans les préférences pour un accès complet et éviter les limitations.";
                show_toast(info_message);
            }
        }

        /**
         * Méthode pour valider le répertoire de téléchargement
         */
        private string? validate_models_directory() {
            var config = controller.get_config_manager();
            var models_dir = config.get_string("AI", "models_directory", "");

            // Vérifier si un répertoire est configuré
            if (models_dir == null || models_dir.length == 0) {
                return "Aucun répertoire de modèles n'est configuré. Veuillez configurer un répertoire dans les préférences IA.";
            }

            // Vérifier si le répertoire existe
            var dir_file = File.new_for_path(models_dir);
            if (!dir_file.query_exists()) {
                return @"Le répertoire configuré n'existe pas : $(models_dir)\nVeuillez créer le répertoire ou en choisir un autre dans les préférences IA.";
            }

            // Vérifier si c'est bien un répertoire
            try {
                var file_info = dir_file.query_info(FileAttribute.STANDARD_TYPE, FileQueryInfoFlags.NONE);
                if (file_info.get_file_type() != FileType.DIRECTORY) {
                    return @"Le chemin configuré n'est pas un répertoire : $(models_dir)\nVeuillez choisir un répertoire valide dans les préférences IA.";
                }
            } catch (Error e) {
                return @"Erreur lors de la vérification du répertoire : $(e.message)\nVeuillez vérifier les permissions ou choisir un autre répertoire.";
            }

            // Vérifier les permissions d'écriture
            if (!FileUtils.test(models_dir, FileTest.IS_DIR) || !FileUtils.test(models_dir, FileTest.IS_EXECUTABLE)) {
                return @"Permissions insuffisantes pour écrire dans : $(models_dir)\nVeuillez vérifier les permissions du répertoire.";
            }

            return null; // Tout est OK
        }

        /**
         * Affichage des fichiers d'un modèle dans la liste
         */
        private void display_model_files(Gee.List<HuggingFaceFile> files) {
            selected_files.clear();

            // Vider la liste actuelle
            var child = files_list.get_first_child();
            while (child != null) {
                var next = child.get_next_sibling();
                files_list.remove(child);
                child = next;
            }

            foreach (var file in files) {
                var row = create_file_row(file);
                files_list.append(row);

                // Par défaut, sélectionner tous les fichiers
                selected_files.add(file);
            }

            update_download_info();
        }

        /**
         * Créer une ligne pour afficher un fichier
         */
        private Gtk.ListBoxRow create_file_row(HuggingFaceFile file) {
            var row = new Gtk.ListBoxRow();
            row.set_data("file", file);
            row.selectable = false;

            var box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 12);
            box.margin_top = 6;
            box.margin_bottom = 6;
            box.margin_start = 12;
            box.margin_end = 12;

            var check = new Gtk.CheckButton();
            check.active = true; // Par défaut, tous les fichiers sont sélectionnés
            check.set_data("file", file);
            check.toggled.connect(on_file_check_toggled);

            var info_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 3);
            info_box.hexpand = true;

            var name_label = new Gtk.Label(file.filename);
            name_label.halign = Gtk.Align.START;
            name_label.ellipsize = Pango.EllipsizeMode.MIDDLE;

            var details_text = file.get_formatted_size();
            if (file.oid.length > 8) {
                details_text += @" • $(file.oid[0:8])";
            }

            var details_label = new Gtk.Label(details_text);
            details_label.add_css_class("dim-label");
            details_label.add_css_class("caption");
            details_label.halign = Gtk.Align.START;

            info_box.append(name_label);
            info_box.append(details_label);

            // Icône selon le type de fichier
            var icon_name = get_file_icon(file.filename);
            var icon = new Gtk.Image.from_icon_name(icon_name);

            box.append(check);
            box.append(icon);
            box.append(info_box);

            row.child = box;
            return row;
        }

        /**
         * Obtenir l'icône selon le type de fichier
         */
        private string get_file_icon(string filename) {
            if (filename.has_suffix(".bin") || filename.has_suffix(".safetensors")) {
                return "applications-science-symbolic";
            } else if (filename.has_suffix(".json")) {
                return "text-x-generic-symbolic";
            } else if (filename.has_suffix(".md")) {
                return "text-x-generic-symbolic";
            } else if (filename.has_suffix(".txt")) {
                return "text-x-generic-symbolic";
            }
            return "text-x-generic-symbolic";
        }

        private void open_preferences_ai() {
            // Créer et afficher la fenêtre des préférences avec focus sur l'onglet IA
            var prefs_window = new PreferencesWindow(controller);
            prefs_window.present();

            stdout.printf("[TRACE] Ouverture des préférences IA depuis la validation du répertoire\n");
        }

    }
}
