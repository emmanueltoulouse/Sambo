using Gtk;
using Gdk;
using Adw;

namespace Sambo {
    /**
     * Boîte de dialogue pour la comparaison de fichiers texte
     */
    public class DialogFileComparer : Adw.Window {
        private ApplicationController controller;

        private string left_file_path;
        private string right_file_path;

        private TextView left_text_view;
        private TextView right_text_view;
        private ScrolledWindow left_scroll;
        private ScrolledWindow right_scroll;

        // Nouvelles propriétés pour les statistiques et navigation
        private int total_lines;
        private int different_lines;
        private int added_lines;
        private int removed_lines;
        private Label stats_label;
        private Gee.ArrayList<int> diff_line_positions;
        private int current_diff_index = -1;

        // Options d'affichage
        private bool show_line_numbers = true;
        private bool ignore_whitespace = false;
        private bool show_identical_lines = true;

        // Tags pour les TextBuffers
        private TextTag diff_added_tag;
        private TextTag diff_removed_tag;
        private TextTag diff_changed_tag;

        /**
         * Crée une nouvelle fenêtre de comparaison de fichiers
         */
        public DialogFileComparer(ApplicationController controller, string left_file_path, string right_file_path) {
            Object(
                title: "Comparaison de fichiers",
                default_width: 900,
                default_height: 700
            );

            this.controller = controller;
            this.left_file_path = left_file_path;
            this.right_file_path = right_file_path;

            diff_line_positions = new Gee.ArrayList<int>();

            // Créer l'interface
            create_ui();

            // Charger le contenu des fichiers
            load_file_content();
        }

        /**
         * Crée l'interface utilisateur
         */
        private void create_ui() {
            var main_box = new Box(Orientation.VERTICAL, 0);

            // En-tête avec information sur les fichiers
            var header_bar = new Adw.HeaderBar();
            var title_widget = new Label(_("Comparaison de fichiers"));
            title_widget.add_css_class("title");
            header_bar.set_title_widget(title_widget);

            // Bouton pour ignorer les espaces blancs
            var whitespace_button = new ToggleButton();
            whitespace_button.set_icon_name("format-indent-less-symbolic");
            whitespace_button.set_tooltip_text(_("Ignorer les espaces blancs"));
            whitespace_button.toggled.connect(() => {
                ignore_whitespace = whitespace_button.get_active();
                load_file_content();
            });
            header_bar.pack_start(whitespace_button);

            // Bouton pour afficher/masquer les numéros de ligne
            var line_numbers_button = new ToggleButton();
            line_numbers_button.set_icon_name("view-list-symbolic");
            line_numbers_button.set_active(show_line_numbers);
            line_numbers_button.set_tooltip_text(_("Afficher les numéros de ligne"));
            line_numbers_button.toggled.connect(() => {
                show_line_numbers = line_numbers_button.get_active();
                update_line_numbers();
            });
            header_bar.pack_start(line_numbers_button);

            // Bouton pour afficher/masquer les lignes identiques
            var identical_lines_button = new ToggleButton();
            identical_lines_button.set_icon_name("view-filter-symbolic");
            identical_lines_button.set_active(show_identical_lines);
            identical_lines_button.set_tooltip_text(_("Afficher les lignes identiques"));
            identical_lines_button.toggled.connect(() => {
                show_identical_lines = identical_lines_button.get_active();
                load_file_content(); // Recharger avec les nouvelles options
            });
            header_bar.pack_start(identical_lines_button);

            var close_button = new Button.with_label(_("Fermer"));
            close_button.clicked.connect(() => { this.destroy(); });
            header_bar.pack_end(close_button);

            // Bouton pour exporter en HTML
            var export_button = new Button.from_icon_name("document-save-symbolic");
            export_button.set_tooltip_text(_("Exporter le rapport de comparaison"));
            export_button.clicked.connect(export_comparison_report);
            header_bar.pack_end(export_button);

            main_box.append(header_bar);

            // Barre de navigation entre les différences
            var navigation_box = new Box(Orientation.HORIZONTAL, 6);
            navigation_box.set_margin_start(6);
            navigation_box.set_margin_end(6);
            navigation_box.set_margin_top(6);
            navigation_box.set_margin_bottom(6);

            var nav_label = new Label(_("Navigation:"));
            nav_label.set_halign(Align.START);

            var prev_diff_button = new Button.from_icon_name("go-up-symbolic");
            prev_diff_button.add_css_class("diff-navigation-button");
            prev_diff_button.set_tooltip_text(_("Différence précédente"));
            prev_diff_button.clicked.connect(navigate_to_previous_diff);

            var next_diff_button = new Button.from_icon_name("go-down-symbolic");
            next_diff_button.add_css_class("diff-navigation-button");
            next_diff_button.set_tooltip_text(_("Différence suivante"));
            next_diff_button.clicked.connect(navigate_to_next_diff);

            stats_label = new Label("");
            stats_label.set_halign(Align.END);
            stats_label.set_hexpand(true);

            navigation_box.append(nav_label);
            navigation_box.append(prev_diff_button);
            navigation_box.append(next_diff_button);
            navigation_box.append(stats_label);

            main_box.append(navigation_box);

            // Affichage des chemins avec des étiquettes plus informatives
            var paths_box = new Box(Orientation.HORIZONTAL, 6);
            paths_box.set_margin_start(6);
            paths_box.set_margin_end(6);
            paths_box.set_margin_bottom(6);

            var left_panel = new Box(Orientation.VERTICAL, 0);
            left_panel.set_hexpand(true);

            var left_title = new Label("");
            left_title.set_markup(_("<b>Fichier source:</b>"));
            left_title.set_halign(Align.START);
            left_title.add_css_class("diff-panel-title");
            left_panel.append(left_title);

            var left_path_label = new Label(left_file_path);
            left_path_label.set_ellipsize(Pango.EllipsizeMode.START);
            left_path_label.set_halign(Align.START);
            left_path_label.set_tooltip_text(left_file_path);
            left_panel.append(left_path_label);

            var right_panel = new Box(Orientation.VERTICAL, 0);
            right_panel.set_hexpand(true);

            var right_title = new Label("");
            right_title.set_markup(_("<b>Fichier comparé:</b>"));
            right_title.set_halign(Align.START);
            right_title.add_css_class("diff-panel-title");
            right_panel.append(right_title);

            var right_path_label = new Label(right_file_path);
            right_path_label.set_ellipsize(Pango.EllipsizeMode.START);
            right_path_label.set_halign(Align.START);
            right_path_label.set_tooltip_text(right_file_path);
            right_panel.append(right_path_label);

            paths_box.append(left_panel);
            paths_box.append(right_panel);

            main_box.append(paths_box);

            // Panneau principal pour les deux textes côte à côte
            var paned = new Paned(Orientation.HORIZONTAL);
            paned.set_wide_handle(true);
            paned.set_vexpand(true);

            // Texte de gauche avec gestion des numéros de ligne
            var left_box = new Box(Orientation.HORIZONTAL, 0);
            left_box.set_hexpand(true);

            left_scroll = new ScrolledWindow();
            left_scroll.set_vexpand(true);
            left_scroll.set_hexpand(true);

            left_text_view = new TextView();
            left_text_view.set_editable(false);
            left_text_view.set_wrap_mode(WrapMode.NONE);
            left_text_view.set_monospace(true);
            left_text_view.add_css_class("diff-view");

            // Configuration des tags pour la colorisation
            var left_buffer = left_text_view.get_buffer();
            diff_removed_tag = left_buffer.create_tag("diff-removed", "background", "rgba(240, 143, 143, 0.3)");
            diff_changed_tag = left_buffer.create_tag("diff-changed", "background", "rgba(240, 240, 143, 0.3)");

            left_scroll.set_child(left_text_view);
            left_box.append(left_scroll);

            // Texte de droite avec gestion des numéros de ligne
            var right_box = new Box(Orientation.HORIZONTAL, 0);
            right_box.set_hexpand(true);

            right_scroll = new ScrolledWindow();
            right_scroll.set_vexpand(true);
            right_scroll.set_hexpand(true);

            right_text_view = new TextView();
            right_text_view.set_editable(false);
            right_text_view.set_wrap_mode(WrapMode.NONE);
            right_text_view.set_monospace(true);
            right_text_view.add_css_class("diff-view");

            // Configuration des tags pour la colorisation
            var right_buffer = right_text_view.get_buffer();
            diff_added_tag = right_buffer.create_tag("diff-added", "background", "rgba(143, 240, 143, 0.3)");
            right_buffer.create_tag("diff-changed", "background", "rgba(240, 240, 143, 0.3)");

            right_scroll.set_child(right_text_view);
            right_box.append(right_scroll);

            // Ajouter les zones de texte au panneau
            paned.set_start_child(left_box);
            paned.set_end_child(right_box);
            paned.set_position(450); // Position initiale du séparateur

            main_box.append(paned);

            // Synchroniser le défilement entre les deux zones
            setup_scroll_sync();

            this.content = main_box;
        }

        /**
         * Configure la synchronisation de défilement entre les deux vues
         */
        private void setup_scroll_sync() {
            var left_vadjustment = left_scroll.get_vadjustment();
            var right_vadjustment = right_scroll.get_vadjustment();

            bool updating_left = false;
            bool updating_right = false;

            left_vadjustment.value_changed.connect(() => {
                if (!updating_left) {
                    updating_right = true;
                    right_vadjustment.set_value(left_vadjustment.get_value());
                    updating_right = false;
                }
            });

            right_vadjustment.value_changed.connect(() => {
                if (!updating_right) {
                    updating_left = true;
                    left_vadjustment.set_value(right_vadjustment.get_value());
                    updating_left = false;
                }
            });
        }

        /**
         * Charge le contenu des fichiers et effectue la comparaison
         */
        private void load_file_content() {
            try {
                // Réinitialiser les statistiques
                total_lines = 0;
                different_lines = 0;
                added_lines = 0;
                removed_lines = 0;
                diff_line_positions.clear();
                current_diff_index = -1;

                // Charger le contenu des fichiers
                string left_content;
                string right_content;
                FileUtils.get_contents(left_file_path, out left_content);
                FileUtils.get_contents(right_file_path, out right_content);

                // Découper en lignes
                string[] left_lines = left_content.split("\n");
                string[] right_lines = right_content.split("\n");

                total_lines = int.max(left_lines.length, right_lines.length);

                // Si on ignore les espaces blancs, normaliser les lignes
                if (ignore_whitespace) {
                    for (int i = 0; i < left_lines.length; i++) {
                        left_lines[i] = normalize_whitespace(left_lines[i]);
                    }

                    for (int i = 0; i < right_lines.length; i++) {
                        right_lines[i] = normalize_whitespace(right_lines[i]);
                    }
                }

                // Préparer le texte à afficher dans chaque vue avec numéros de ligne
                StringBuilder left_text = new StringBuilder();
                StringBuilder right_text = new StringBuilder();

                // Comparer et construire l'affichage
                compare_and_build_display(left_lines, right_lines, left_text, right_text);

                // Mettre à jour les TextViews
                left_text_view.get_buffer().set_text(left_text.str);
                right_text_view.get_buffer().set_text(right_text.str);

                // Mettre en évidence les différences
                highlight_differences(left_lines, right_lines);

                // Mettre à jour les statistiques
                update_statistics();

            } catch (Error e) {
                warning("Erreur lors du chargement des fichiers pour comparaison: %s", e.message);

                // Afficher l'erreur dans les vues
                left_text_view.get_buffer().set_text("Erreur: " + e.message);
                right_text_view.get_buffer().set_text("Erreur: " + e.message);
            }
        }

        /**
         * Normalise les espaces blancs dans une ligne
         */
        private string normalize_whitespace(string line) {
            // Remplacer les tabulations par des espaces
            string result = line.replace("\t", " ");

            // Supprimer les espaces au début et à la fin
            result = result.strip();

            // Remplacer les séquences d'espaces par un seul espace
            while (result.contains("  ")) {
                result = result.replace("  ", " ");
            }

            return result;
        }

        /**
         * Compare les lignes et construit l'affichage de manière optimisée
         * pour gérer de grands fichiers
         */
        private void compare_and_build_display(string[] left_lines, string[] right_lines,
                                               StringBuilder left_text, StringBuilder right_text) {
            // Longueur maximale du numéro de ligne pour le formatage
            int max_line_number = int.max(left_lines.length, right_lines.length);
            int line_number_width = max_line_number.to_string().length;

            int max_lines = int.max(left_lines.length, right_lines.length);
            int visible_lines = 0;

            // Réserver la capacité pour éviter les réallocations
            int est_line_length = 50; // Longueur moyenne estimée d'une ligne
            int est_capacity = max_lines * (line_number_width + est_line_length + 3);

            for (int i = 0; i < max_lines; i++) {
                // Traitement par lots pour améliorer les performances
                if (i % 1000 == 0 && i > 0) {
                    // Autoriser la mise à jour de l'interface
                    var context = MainContext.default();
                    while (context.pending()) {
                        context.iteration(false);
                    }
                }

                string left_line = i < left_lines.length ? left_lines[i] : "";
                string right_line = i < right_lines.length ? right_lines[i] : "";

                bool lines_different = left_line != right_line;

                // Si les lignes sont différentes, incrémenter le compteur et stocker la position
                if (lines_different) {
                    different_lines++;

                    // S'il s'agit d'une ligne présente seulement à gauche (supprimée)
                    if (i >= right_lines.length || (i < right_lines.length && right_lines[i] == "")) {
                        removed_lines++;
                    }
                    // S'il s'agit d'une ligne présente seulement à droite (ajoutée)
                    else if (i >= left_lines.length || (i < left_lines.length && left_lines[i] == "")) {
                        added_lines++;
                    }

                    diff_line_positions.add(i);
                }

                // Si on n'affiche pas les lignes identiques et que les lignes sont identiques, les sauter
                if (!show_identical_lines && !lines_different && left_line != "" && right_line != "") {
                    continue;
                }

                visible_lines++;

                // Ajouter la ligne à la vue de gauche
                if (i < left_lines.length) {
                    if (show_line_numbers) {
                        left_text.append_printf("%*d | %s\n", line_number_width, i+1, left_lines[i]);
                    } else {
                        left_text.append_printf("%s\n", left_lines[i]);
                    }
                } else {
                    // Ligne vide à gauche pour aligner avec la droite
                    if (show_line_numbers) {
                        left_text.append_printf("%*s | \n", line_number_width, "");
                    } else {
                        left_text.append_printf("\n");
                    }
                }

                // Ajouter la ligne à la vue de droite
                if (i < right_lines.length) {
                    if (show_line_numbers) {
                        right_text.append_printf("%*d | %s\n", line_number_width, i+1, right_lines[i]);
                    } else {
                        right_text.append_printf("%s\n", right_lines[i]);
                    }
                } else {
                    // Ligne vide à droite pour aligner avec la gauche
                    if (show_line_numbers) {
                        right_text.append_printf("%*s | \n", line_number_width, "");
                    } else {
                        right_text.append_printf("\n");
                    }
                }
            }

            // Mettre à jour les compteurs de statistiques
            total_lines = max_lines;
        }

        /**
         * Met à jour l'affichage des numéros de ligne
         */
        private void update_line_numbers() {
            // Cette méthode nécessite de recharger tout le contenu
            load_file_content();
        }

        /**
         * Met en évidence les différences entre les deux fichiers
         */
        private void highlight_differences(string[] left_lines, string[] right_lines) {
            var left_buffer = left_text_view.get_buffer();
            var right_buffer = right_text_view.get_buffer();

            // Calcul de la largeur des numéros de ligne pour le décalage
            int line_offset = 0;
            if (show_line_numbers) {
                int max_line_number = int.max(left_lines.length, right_lines.length);
                int line_number_width = max_line_number.to_string().length;
                line_offset = line_number_width + 3; // +3 pour " | "
            }

            int max_lines = int.max(left_lines.length, right_lines.length);
            int left_line_index = 0;
            int right_line_index = 0;

            for (int i = 0; i < max_lines; i++) {
                string left_line = i < left_lines.length ? left_lines[i] : "";
                string right_line = i < right_lines.length ? right_lines[i] : "";

                // Vérifier si les lignes sont différentes
                if (left_line != right_line) {
                    // S'il s'agit d'une ligne présente seulement à gauche (supprimée)
                    if (i >= right_lines.length || right_line == "") {
                        TextIter start_iter, end_iter;
                        get_line_iters(left_buffer, left_line_index, line_offset, out start_iter, out end_iter);
                        left_buffer.apply_tag(diff_removed_tag, start_iter, end_iter);
                    }
                    // S'il s'agit d'une ligne présente seulement à droite (ajoutée)
                    else if (i >= left_lines.length || left_line == "") {
                        TextIter start_iter, end_iter;
                        get_line_iters(right_buffer, right_line_index, line_offset, out start_iter, out end_iter);
                        right_buffer.apply_tag(diff_added_tag, start_iter, end_iter);
                    }
                    // Les deux lignes existent mais sont différentes
                    else {
                        TextIter left_start, left_end;
                        get_line_iters(left_buffer, left_line_index, line_offset, out left_start, out left_end);
                        left_buffer.apply_tag(diff_changed_tag, left_start, left_end);

                        TextIter right_start, right_end;
                        get_line_iters(right_buffer, right_line_index, line_offset, out right_start, out right_end);
                        right_buffer.apply_tag(diff_changed_tag, right_start, right_end);
                    }
                }

                // Si on n'affiche pas les lignes identiques et que les lignes sont identiques, ne pas incrémenter
                // les compteurs de lignes affichées
                if (!show_identical_lines && left_line == right_line && left_line != "") {
                    continue;
                }

                // Incrémenter les indices de ligne pour les buffers
                if (i < left_lines.length) left_line_index++;
                if (i < right_lines.length) right_line_index++;
            }
        }

        /**
         * Obtient les itérateurs de début et de fin d'une ligne visible
         * avec prise en compte du décalage pour les numéros de ligne
         */
        private void get_line_iters(TextBuffer buffer, int visible_line, int line_offset,
                                    out TextIter start, out TextIter end) {
            buffer.get_iter_at_line(out start, visible_line);
            buffer.get_iter_at_line(out end, visible_line);

            // Déplacer le début après le numéro de ligne et séparateur si nécessaire
            if (line_offset > 0) {
                start.forward_chars(line_offset);
            }

            if (!end.ends_line()) {
                end.forward_to_line_end();
            }
        }

        /**
         * Met à jour les statistiques de comparaison
         */
        private void update_statistics() {
            string stats_text = _("Lignes: %d  •  Différences: %d  •  Ajouts: %d  •  Suppressions: %d")
                               .printf(total_lines, different_lines, added_lines, removed_lines);
            stats_label.set_text(stats_text);
            stats_label.add_css_class("diff-stats");
        }

        /**
         * Navigue vers la différence suivante
         */
        private void navigate_to_next_diff() {
            if (diff_line_positions.size == 0) return;

            current_diff_index++;
            if (current_diff_index >= diff_line_positions.size) {
                current_diff_index = 0; // Boucler au début
            }

            scroll_to_diff_line(diff_line_positions[current_diff_index]);
        }

        /**
         * Navigue vers la différence précédente
         */
        private void navigate_to_previous_diff() {
            if (diff_line_positions.size == 0) return;

            current_diff_index--;
            if (current_diff_index < 0) {
                current_diff_index = diff_line_positions.size - 1; // Boucler à la fin
            }

            scroll_to_diff_line(diff_line_positions[current_diff_index]);
        }

        /**
         * Fait défiler les vues vers une ligne spécifique
         */
        private void scroll_to_diff_line(int line) {
            // Calculer la position de la ligne dans le buffer
            int visible_line = calculate_visible_line_position(line);
            if (visible_line < 0) return; // Ligne non visible (filtrée)

            TextIter left_iter, right_iter;
            left_text_view.get_buffer().get_iter_at_line(out left_iter, visible_line);
            right_text_view.get_buffer().get_iter_at_line(out right_iter, visible_line);

            // Faire défiler les deux vues
            left_text_view.scroll_to_iter(left_iter, 0.2, false, 0, 0.5);
            right_text_view.scroll_to_iter(right_iter, 0.2, false, 0, 0.5);
        }

        /**
         * Calcule la position d'une ligne logique dans le buffer visible actuel
         * en tenant compte du filtrage des lignes identiques
         */
        private int calculate_visible_line_position(int logical_line) {
            // Si toutes les lignes sont affichées, c'est simple
            if (show_identical_lines) {
                return logical_line;
            }

            // Sinon, il faut compter les lignes visibles jusqu'à la ligne logique demandée
            int visible_line = 0;

            try {
                // Charger le contenu des fichiers
                string left_content;
                string right_content;
                FileUtils.get_contents(left_file_path, out left_content);
                FileUtils.get_contents(right_file_path, out right_content);

                string[] left_lines = left_content.split("\n");
                string[] right_lines = right_content.split("\n");

                if (ignore_whitespace) {
                    for (int i = 0; i < left_lines.length; i++) {
                        left_lines[i] = normalize_whitespace(left_lines[i]);
                    }

                    for (int i = 0; i < right_lines.length; i++) {
                        right_lines[i] = normalize_whitespace(right_lines[i]);
                    }
                }

                for (int i = 0; i < logical_line && i < int.max(left_lines.length, right_lines.length); i++) {
                    string left_line = i < left_lines.length ? left_lines[i] : "";
                    string right_line = i < right_lines.length ? right_lines[i] : "";

                    // Si les lignes sont différentes ou vides, elles sont toujours visibles
                    if (left_line != right_line || left_line == "" || right_line == "") {
                        visible_line++;
                    }
                    // Sinon, on ne les compte pas car elles sont filtrées
                }

                return visible_line;

            } catch (Error e) {
                warning("Erreur lors du calcul de la position visible: %s", e.message);
                return -1;
            }
        }

        /**
         * Exporte le rapport de comparaison au format HTML
         */
        private void export_comparison_report() {
            // Remplacer FileChooserDialog déprécié par FileDialog
            var file_dialog = new FileDialog();
            file_dialog.set_title(_("Enregistrer le rapport de comparaison"));

            var file_name = File.new_build_filename(Environment.get_home_dir(), "rapport_comparaison.html");
            file_dialog.set_initial_file(file_name);

            // Utiliser l'API asynchrone au lieu de run()
            file_dialog.save.begin(this, null, (obj, res) => {
                try {
                    var file = file_dialog.save.end(res);
                    if (file != null) {
                        string filename = file.get_path();
                        try {
                            // Générer le rapport HTML
                            string html_content = generate_html_report();

                            // Écrire dans le fichier
                            FileUtils.set_contents(filename, html_content);

                            // Afficher une confirmation avec AlertDialog au lieu de MessageDialog
                            var info_dialog = new Adw.AlertDialog(
                                _("Rapport exporté"),
                                _("Rapport de comparaison exporté avec succès vers %s").printf(filename)
                            );
                            info_dialog.add_response("ok", _("OK"));
                            info_dialog.present(this);

                        } catch (Error e) {
                            // Afficher l'erreur avec AlertDialog
                            var error_dialog = new Adw.AlertDialog(
                                _("Erreur d'exportation"),
                                _("Erreur lors de l'exportation du rapport : %s").printf(e.message)
                            );
                            error_dialog.add_response("ok", _("OK"));
                            error_dialog.set_response_appearance("ok", Adw.ResponseAppearance.DESTRUCTIVE);
                            error_dialog.present(this);
                        }
                    }
                } catch (Error e) {
                    warning("Erreur lors de la sélection du fichier: %s", e.message);
                }
            });
        }

        /**
         * Génère un rapport HTML de la comparaison
         */
        private string generate_html_report() throws Error {
            // Charger le contenu des fichiers
            string left_content;
            string right_content;
            FileUtils.get_contents(left_file_path, out left_content);
            FileUtils.get_contents(right_file_path, out right_content);

            string[] left_lines = left_content.split("\n");
            string[] right_lines = right_content.split("\n");

            StringBuilder html = new StringBuilder();

            // En-tête HTML
            html.append("<!DOCTYPE html>\n<html>\n<head>\n");
            html.append("<meta charset=\"utf-8\">\n");
            html.append("<title>Rapport de comparaison</title>\n");
            html.append("<style>\n");
            html.append("body { font-family: Arial, sans-serif; margin: 20px; }\n");
            html.append("h1 { color: #333; }\n");
            html.append("table { border-collapse: collapse; width: 100%; }\n");
            html.append("th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }\n");
            html.append("tr:nth-child(even) { background-color: #f2f2f2; }\n");
            html.append(".diff-added { background-color: #d4ffdc; }\n");
            html.append(".diff-removed { background-color: #ffcaca; }\n");
            html.append(".diff-changed { background-color: #ffffcc; }\n");
            html.append(".line-number { color: #777; text-align: right; user-select: none; width: 40px; }\n");
            html.append("</style>\n");
            html.append("</head>\n<body>\n");

            // Titre et informations
            html.append("<h1>Rapport de comparaison de fichiers</h1>\n");
            html.append("<p><strong>Fichier source:</strong> " + GLib.Markup.escape_text(left_file_path) + "</p>\n");
            html.append("<p><strong>Fichier comparé:</strong> " + GLib.Markup.escape_text(right_file_path) + "</p>\n");

            // Statistiques
            html.append("<p><strong>Statistiques:</strong> ");
            html.append_printf("Total: %d lignes, ", total_lines);
            html.append_printf("Différences: %d, ", different_lines);
            html.append_printf("Ajouts: %d, ", added_lines);
            html.append_printf("Suppressions: %d", removed_lines);
            html.append("</p>\n");

            // Tableau de comparaison
            html.append("<table>\n");
            html.append("<tr><th>Ligne</th><th>Source</th><th>Ligne</th><th>Comparé</th></tr>\n");

            int max_lines = int.max(left_lines.length, right_lines.length);

            for (int i = 0; i < max_lines; i++) {
                string left_line = i < left_lines.length ? GLib.Markup.escape_text(left_lines[i]) : "";
                string right_line = i < right_lines.length ? GLib.Markup.escape_text(right_lines[i]) : "";

                // Déterminer le type de différence pour la colorisation
                string left_class = "";
                string right_class = "";

                if (i >= right_lines.length || right_lines[i] == "") {
                    left_class = " class=\"diff-removed\"";
                } else if (i >= left_lines.length || left_lines[i] == "") {
                    right_class = " class=\"diff-added\"";
                } else if (left_line != right_line) {
                    left_class = " class=\"diff-changed\"";
                    right_class = " class=\"diff-changed\"";
                }

                // Ne pas afficher les lignes identiques si l'option est activée
                if (!show_identical_lines && left_line == right_line && left_line != "") {
                    continue;
                }

                // Ajouter la ligne au tableau
                html.append("<tr>\n");

                // Ligne source
                html.append_printf("<td class=\"line-number\">%d</td>\n", i + 1);
                html.append_printf("<td%s>%s</td>\n", left_class, left_line);

                // Ligne comparée
                html.append_printf("<td class=\"line-number\">%d</td>\n", i + 1);
                html.append_printf("<td%s>%s</td>\n", right_class, right_line);

                html.append("</tr>\n");
            }

            html.append("</table>\n");

            // Pied de page
            html.append("<p><em>Généré par Sambo le " + new DateTime.now_local().format("%d/%m/%Y à %H:%M:%S") + "</em></p>\n");

            html.append("</body>\n</html>");

            return html.str;
        }

        /**
         * Charge et compare les deux fichiers
         */
        private void compare_files(string left_file_path, string right_file_path) {
            try {
                // Charger le contenu des fichiers
                string left_content;
                string right_content;

                FileUtils.get_contents(left_file_path, out left_content);
                FileUtils.get_contents(right_file_path, out right_content);

                // Référencer les buffers des TextViews
                var left_buffer = left_text_view.get_buffer();
                var right_buffer = right_text_view.get_buffer();

                // Prétraiter les textes (convertir en listes de lignes)
                string[] left_lines = left_content.split("\n");
                string[] right_lines = right_content.split("\n");

                // Comparer les deux ensembles de lignes
                // Nous intégrons cette fonctionnalité dans notre méthode actuelle
                // au lieu de faire appel à une méthode inexistante

                // Réinitialiser les compteurs de statistiques
                total_lines = int.max(left_lines.length, right_lines.length);
                different_lines = 0;
                added_lines = 0;
                removed_lines = 0;

                // Préparer les constructeurs de chaînes pour le texte formaté
                var left_builder = new StringBuilder();
                var right_builder = new StringBuilder();

                // Comparer et formater chaque ligne
                for (int i = 0; i < total_lines; i++) {
                    string left_line = i < left_lines.length ? left_lines[i] : "";
                    string right_line = i < right_lines.length ? right_lines[i] : "";

                    if (left_line != right_line) {
                        different_lines++;

                        if (i >= right_lines.length || right_line == "") {
                            removed_lines++;
                        } else if (i >= left_lines.length || left_line == "") {
                            added_lines++;
                        }
                    }

                    // Ajouter les lignes aux builders
                    left_builder.append(left_line + "\n");
                    right_builder.append(right_line + "\n");
                }

                // Appliquer les textes aux buffers
                left_buffer.set_text(left_builder.str);
                right_buffer.set_text(right_builder.str);

                // Traiter les événements UI en attente pour permettre l'affichage pendant le chargement
                var context = MainContext.default();
                while (context.pending()) {
                    context.iteration(false);
                }

                // Appliquer les styles de coloration aux différences
                highlight_differences(left_lines, right_lines);

                // Mettre à jour les statistiques dans l'interface
                update_statistics();
            } catch (Error e) {
                warning("Erreur lors de la comparaison des fichiers: %s", e.message);
            }
        }

        /**
         * Sauvegarde les modifications actuelles dans un fichier
         */
        private void save_file(bool save_left = true) {
            // Utiliser FileDialog au lieu de FileChooserDialog
            var file_dialog = new FileDialog();
            file_dialog.set_title(save_left ? _("Sauvegarder le fichier de gauche") : _("Sauvegarder le fichier de droite"));

            // Définir le fichier initial avec le chemin approprié
            string initial_path = save_left ? left_file_path : right_file_path;
            var initial_file = File.new_for_path(initial_path);
            file_dialog.set_initial_file(initial_file);

            // Utiliser l'API asynchrone au lieu de run()
            file_dialog.save.begin(this, null, (obj, res) => {
                try {
                    var file = file_dialog.save.end(res);
                    if (file != null) {
                        string path = file.get_path();
                        if (path != null) {
                            try {
                                // Récupérer le texte du buffer approprié
                                TextIter start, end;
                                string text;

                                // Accéder aux buffers via les TextViews
                                var left_buffer = left_text_view.get_buffer();
                                var right_buffer = right_text_view.get_buffer();

                                if (save_left) {
                                    left_buffer.get_bounds(out start, out end);
                                    text = left_buffer.get_text(start, end, true);
                                } else {
                                    right_buffer.get_bounds(out start, out end);
                                    text = right_buffer.get_text(start, end, true);
                                }

                                // Sauvegarder dans le fichier
                                FileUtils.set_contents(path, text);

                                // Afficher une confirmation
                                var info_dialog = new Adw.AlertDialog(
                                    _("Fichier sauvegardé"),
                                    _("Le fichier a été sauvegardé avec succès.")
                                );
                                info_dialog.add_response("ok", _("OK"));
                                info_dialog.present(this);
                            } catch (Error e) {
                                // Afficher une erreur
                                var error_dialog = new Adw.AlertDialog(
                                    _("Erreur de sauvegarde"),
                                    _("Impossible de sauvegarder le fichier: ") + e.message
                                );
                                error_dialog.add_response("ok", _("OK"));
                                error_dialog.set_response_appearance("ok", Adw.ResponseAppearance.DESTRUCTIVE);
                                error_dialog.present(this);
                            }
                        }
                    }
                } catch (Error e) {
                    warning("Erreur lors de la sélection du fichier: %s", e.message);
                }
            });
        }
    }
}
