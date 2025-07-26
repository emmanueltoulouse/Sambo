/* EditorView.vala
 *
 * Copyright 2023
 */

using Gtk;
using Sambo.Document;

namespace Sambo {
    public class EditorView : Gtk.Box {
        private ApplicationController controller;
        public PivotDocument? current_document;
        public WysiwygEditor wysiwyg_editor;
        private bool _has_unsaved_changes = false;
        private Gtk.Box content_box;
        public Gtk.Box toolbar_box;
        public Gtk.Box statusbar_box;
        private Gtk.Label status_label;
        private Gtk.Label position_label;
        private Gtk.Label provenance_label;

        public bool has_unsaved_changes {
            get { return _has_unsaved_changes; }
            set {
                if (_has_unsaved_changes != value) {
                    _has_unsaved_changes = value;
                    save_state_changed();
                    notify_property("has-unsaved-changes");
                }
            }
        }

        // Notifie les changements d'état de sauvegarde (peut être connecté à un signal ou utilisé pour mettre à jour l'UI)
        private void save_state_changed() {
            // Implémentez ici la logique à exécuter lorsque l'état de sauvegarde change,
            // par exemple, mettre à jour l'UI ou émettre un signal.
        }

        // --- Propriétés de style par onglet ---
        private int font_size = 14;
        private string font_family = "Monospace";
        private string font_color = "#222222";

        // --- Bouton et bulle de style ---
        private Gtk.Button style_button;
        private Gtk.Popover style_popover;

        // --- Listes pour les dropdowns ---
        private string[] fonts = {"Monospace", "Serif", "Sans-Serif", "Arial", "Times New Roman", "Courier New"};
        private string[] sizes = {"8", "9", "10", "11", "12", "14", "16", "18", "20", "22", "24", "28", "32", "36", "48", "72"};

        // --- Dropdowns pour les styles ---
        private Gtk.DropDown font_dropdown;
        private Gtk.DropDown size_dropdown;

        public EditorView(ApplicationController controller) {
            Object(orientation: Orientation.VERTICAL, spacing: 6);
            stderr.printf("🔍 EditorView.constructor: DÉBUT - Création nouvel EditorView\n");

            // Cadre autour de l'éditeur (coins arrondis selon le thème)
            var frame = new Gtk.Frame(null);
            frame.set_margin_start(6);
            frame.set_margin_end(6);
            frame.set_margin_top(6);
            frame.set_margin_bottom(6);
            frame.set_vexpand(true);
            frame.set_hexpand(true);

            // --- Barre d'icônes (toolbar) ---
            toolbar_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 2);
            toolbar_box.add_css_class("toolbar");
            // Nous allons maintenant créer des conteneurs pour chaque groupe logique
            // Groupe 1: Formatage de texte
            var text_group = new Box(Orientation.HORIZONTAL, 2);
            text_group.add_css_class("linked");

            // Ajouter les boutons de formatage de texte à ce groupe
            var bold_button = new Button.from_icon_name("format-text-bold-symbolic");
            bold_button.set_tooltip_text(_("Gras (Ctrl+B)"));
            bold_button.add_css_class("flat");

            var italic_button = new Button.from_icon_name("format-text-italic-symbolic");
            italic_button.set_tooltip_text(_("Italique (Ctrl+I)"));
            italic_button.add_css_class("flat");

            var underline_button = new Button.from_icon_name("format-text-underline-symbolic");
            underline_button.set_tooltip_text(_("Souligné (Ctrl+U)"));
            underline_button.add_css_class("flat");

            // 5. Barré (remplacement)
            var strikethrough_button = new Button.from_icon_name("edit-undo-symbolic");
            strikethrough_button.set_tooltip_text(_("Barré (Ctrl+-)"));
            strikethrough_button.add_css_class("flat");

            // Séparateur
            var separator1 = new Separator(Orientation.VERTICAL);
            separator1.add_css_class("toolbar-separator");

            // -- Titres --
            // 7. Titres (remplacement)
            var heading_menu_button = new MenuButton();
            heading_menu_button.set_icon_name("format-text-size-symbolic");
            heading_menu_button.set_tooltip_text(_("Titres"));
            heading_menu_button.add_css_class("flat");

            var headings_menu = new GLib.Menu();
            headings_menu.append(_("Titre 1"), "win.heading(1)");
            headings_menu.append(_("Titre 2"), "win.heading(2)");
            headings_menu.append(_("Titre 3"), "win.heading(3)");
            headings_menu.append(_("Normal"), "win.heading(0)");
            heading_menu_button.set_menu_model(headings_menu);

            // Séparateur
            var separator2 = new Separator(Orientation.VERTICAL);
            separator2.add_css_class("toolbar-separator");

            // -- Couleurs --
            var color_button = new Button.from_icon_name("color-select-symbolic");
            color_button.set_tooltip_text(_("Couleur du texte"));
            color_button.add_css_class("flat");

            var highlight_button = new Button.from_icon_name("highlight-filled-symbolic");
            highlight_button.set_tooltip_text(_("Surlignage"));
            highlight_button.add_css_class("flat");

            text_group.append(bold_button);
            text_group.append(italic_button);
            text_group.append(underline_button);
            text_group.append(strikethrough_button);
            text_group.append(separator1);
            text_group.append(heading_menu_button);
            text_group.append(separator2);
            text_group.append(color_button);
            text_group.append(highlight_button);

            // Ajouter directement le groupe à la toolbar
            toolbar_box.append(text_group);

            // Groupe 2: Paragraphes et listes
            var para_group = new Box(Orientation.HORIZONTAL, 2);
            para_group.add_css_class("linked");

            // Ajouter les boutons de paragraphe à ce groupe
            var align_left_button = new Button.from_icon_name("format-justify-left-symbolic");
            align_left_button.set_tooltip_text(_("Aligné à gauche"));
            align_left_button.add_css_class("flat");

            var align_center_button = new Button.from_icon_name("format-justify-center-symbolic");
            align_center_button.set_tooltip_text(_("Centré"));
            align_center_button.add_css_class("flat");

            var align_right_button = new Button.from_icon_name("format-justify-right-symbolic");
            align_right_button.set_tooltip_text(_("Aligné à droite"));
            align_right_button.add_css_class("flat");

            var align_justify_button = new Button.from_icon_name("format-justify-fill-symbolic");
            align_justify_button.set_tooltip_text(_("Justifié"));
            align_justify_button.add_css_class("flat");

            // Séparateur
            var separator3 = new Separator(Orientation.VERTICAL);
            separator3.add_css_class("toolbar-separator");

            var bullet_list_button = new Button.from_icon_name("format-list-unordered-symbolic");
            bullet_list_button.set_tooltip_text(_("Liste à puces"));
            bullet_list_button.add_css_class("flat");

            var numbered_list_button = new Button.from_icon_name("format-list-ordered-symbolic");
            numbered_list_button.set_tooltip_text(_("Liste numérotée"));
            numbered_list_button.add_css_class("flat");

            var indent_button = new Button.from_icon_name("format-indent-more-symbolic");
            indent_button.set_tooltip_text(_("Augmenter l'indentation"));
            indent_button.add_css_class("flat");

            // 12. Outdent (remplacement)
            var outdent_button = new Button.from_icon_name("go-previous-symbolic");
            outdent_button.set_tooltip_text(_("Diminuer l'indentation"));
            outdent_button.add_css_class("flat");

            var quote_button = new Button.from_icon_name("format-quote-symbolic");
            quote_button.set_tooltip_text(_("Citation"));
            quote_button.add_css_class("flat");

            para_group.append(align_left_button);
            para_group.append(align_center_button);
            para_group.append(align_right_button);
            para_group.append(align_justify_button);
            para_group.append(separator3);
            para_group.append(bullet_list_button);
            para_group.append(numbered_list_button);
            para_group.append(indent_button);
            para_group.append(outdent_button);
            para_group.append(quote_button);

            // Ajouter directement le groupe à la toolbar
            toolbar_box.append(para_group);

            // Groupe 3: Éléments spéciaux
            var special_group = new Box(Orientation.HORIZONTAL, 2);
            special_group.add_css_class("linked");

            // Ajouter les boutons spéciaux à ce groupe
            var code_button = new Button.from_icon_name("utilities-terminal-symbolic");
            code_button.set_tooltip_text(_("Bloc de code"));
            code_button.add_css_class("flat");

            var inline_code_button = new Button.from_icon_name("system-run-symbolic");
            inline_code_button.set_tooltip_text(_("Code en ligne"));
            inline_code_button.add_css_class("flat");

            var table_button = new Button.from_icon_name("view-grid-symbolic");
            table_button.set_tooltip_text(_("Insérer un tableau"));
            table_button.add_css_class("flat");

            var image_button = new Button.from_icon_name("insert-image-symbolic");
            image_button.set_tooltip_text(_("Insérer une image"));
            image_button.add_css_class("flat");

            var link_button = new Button.from_icon_name("insert-link-symbolic");
            link_button.set_tooltip_text(_("Insérer un lien"));
            link_button.add_css_class("flat");

            var hr_button = new Button.from_icon_name("view-more-horizontal-symbolic");
            hr_button.set_tooltip_text(_("Séparateur horizontal"));
            hr_button.add_css_class("flat");

            // Séparateur
            var separator4 = new Separator(Orientation.VERTICAL);
            separator4.add_css_class("toolbar-separator");

            // 16. Formule (remplacement)
            var formula_button = new Button.from_icon_name("accessories-calculator-symbolic");
            formula_button.set_tooltip_text(_("Insérer une formule mathématique"));
            formula_button.add_css_class("flat");

            var clear_format_button = new Button.from_icon_name("edit-clear-all-symbolic");
            clear_format_button.set_tooltip_text(_("Effacer le formatage"));
            clear_format_button.add_css_class("flat");

            special_group.append(code_button);
            special_group.append(inline_code_button);
            special_group.append(table_button);
            special_group.append(image_button);
            special_group.append(link_button);
            special_group.append(hr_button);
            special_group.append(separator4);
            special_group.append(formula_button);
            special_group.append(clear_format_button);

            // Ajouter directement le groupe à la toolbar
            toolbar_box.append(special_group);

            // --- Construction du panneau principal (créé tôt pour éviter les erreurs) ---
            content_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 6);

            // Créer l'éditeur WYSIWYG
            wysiwyg_editor = new WysiwygEditor();
            wysiwyg_editor.set_vexpand(true);
            wysiwyg_editor.set_hexpand(true);

            // Détecter les modifications dans le buffer
            wysiwyg_editor.buffer_changed.connect(() => {
                this.has_unsaved_changes = true; // Déclenche l'émission du signal save_state_changed
            });

            // Connecter les signaux des boutons
            bold_button.clicked.connect(() => {
                wysiwyg_editor.apply_bold();
            });

            italic_button.clicked.connect(() => {
                wysiwyg_editor.apply_italic();
            });

            underline_button.clicked.connect(() => {
                wysiwyg_editor.apply_format(TextFormatting.UNDERLINE);
            });

            strikethrough_button.clicked.connect(() => {
                wysiwyg_editor.apply_format(TextFormatting.STRIKETHROUGH);
            });

            quote_button.clicked.connect(() => {
                wysiwyg_editor.apply_quote();
            });

            code_button.clicked.connect(() => {
                wysiwyg_editor.insert_code_block();
            });

            inline_code_button.clicked.connect(() => {
                wysiwyg_editor.apply_code();
            });

            bullet_list_button.clicked.connect(() => {
                wysiwyg_editor.insert_list(false);
            });

            numbered_list_button.clicked.connect(() => {
                wysiwyg_editor.insert_list(true);
            });

            link_button.clicked.connect(() => {
                show_link_dialog();
            });

            image_button.clicked.connect(() => {
                show_image_dialog();
            });

            table_button.clicked.connect(() => {
                show_table_dialog();
            });

            // --- Groupe Style (à placer dans un FlowBoxChild ou directement dans toolbar_box) ---
            var style_group = new Box(Orientation.HORIZONTAL, 2);
            style_group.add_css_class("linked");

            // --- Police (Gtk.DropDown dynamique avec polices système) ---
            var display = Gdk.Display.get_default();
            var context = this.create_pango_context();
            Pango.FontFamily[] families;
            context.list_families(out families);
            fonts = {}; // Réinitialiser le tableau membre de la classe
            foreach (var fam in families) {
                fonts += fam.get_name();
            }
            // Convert array to list for sorting
            var fonts_list = new GLib.List<string>();
            foreach (var font in fonts) {
                fonts_list.append(font);
            }

            // Sort the list
            fonts_list.sort((a, b) => {
                return a.collate(b);
            });

            // Convert back to array
            fonts = {};
            foreach (var font in fonts_list) {
                fonts += font;
            }

            font_dropdown = new Gtk.DropDown.from_strings(fonts);
            font_dropdown.set_selected(find_index_in_array(fonts, font_family));
            style_group.append(font_dropdown);

            // --- Taille (Gtk.DropDown) ---
            size_dropdown = new Gtk.DropDown.from_strings(sizes);
            size_dropdown.set_selected(find_index_in_array(sizes, font_size.to_string()));
            style_group.append(size_dropdown);

            // --- Couleur (SplitButton moderne) ---
            var color_content = new Adw.ButtonContent();
            color_content.set_icon_name("color-select-symbolic");
            color_content.set_label(""); // Pas de texte, juste l'icône

            // Appliquer la couleur choisie à l'icône
            string icon_color = is_color_black(font_color) ? "#888888" : font_color;
            color_content.add_css_class("color-icon");
            color_content.set_css_classes({ "color-icon" });

            // Set icon color using a Gtk.StyleProvider and CSS
            var css_provider = new Gtk.CssProvider();
            string css = """
                .color-icon {
                    color: %s;
                }
            """.printf(icon_color);
            css_provider.load_from_data((uint8[]) css.data);
            Gtk.StyleContext.add_provider_for_display(
                Gdk.Display.get_default(),
                css_provider,
                Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
            );

            var color_split_button = new Adw.SplitButton();
            color_split_button.set_child(color_content);
            color_split_button.set_tooltip_text(_("Couleur du texte"));
            color_split_button.add_css_class("flat");
            color_split_button.clicked.connect(show_color_dialog);
            style_group.append(color_split_button);

            // Ajoute le groupe à la barre d'outils
            toolbar_box.append(style_group);

            // --- Connexions pour appliquer à la sélection uniquement ---
            if (font_dropdown != null) {
                font_dropdown.notify["selected"].connect(() => {
                    if (wysiwyg_editor.has_selection()) {
                        wysiwyg_editor.apply_font_to_selection(fonts[font_dropdown.get_selected()]);
                    }
                });
            } else {
                warning("EditorView: font_dropdown est NULL lors de la connexion du signal");
            }

            if (size_dropdown != null) {
                size_dropdown.notify["selected"].connect(() => {
                    if (wysiwyg_editor.has_selection()) {
                        wysiwyg_editor.apply_font_size_to_selection(int.parse(sizes[size_dropdown.get_selected()]));
                    }
                });
            } else {
                warning("EditorView: size_dropdown est NULL lors de la connexion du signal");
            }
            // La connexion pour la couleur se fera dans show_color_dialog

            // --- Barre de status ---
            statusbar_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 8);
            statusbar_box.add_css_class("editor-statusbar-box");

            provenance_label = new Gtk.Label("");
            provenance_label.set_halign(Gtk.Align.START);
            provenance_label.set_hexpand(false);
            provenance_label.add_css_class("editor-statusbar-provenance");
            statusbar_box.append(provenance_label);

            status_label = new Gtk.Label("");
            status_label.set_halign(Gtk.Align.START);
            status_label.set_hexpand(true);
            status_label.add_css_class("editor-statusbar-file");
            statusbar_box.append(status_label);

            position_label = new Gtk.Label("Ln 1, Col 1");
            position_label.set_halign(Gtk.Align.END);
            position_label.set_hexpand(false);
            position_label.add_css_class("editor-statusbar-label");
            statusbar_box.append(position_label);

            // --- Assembler le panneau principal avec architecture correcte ---
            stderr.printf("🔍 EditorView.constructor: Assemblage des widgets - toolbar_box: %s, wysiwyg_editor: %s, statusbar_box: %s\n",
                toolbar_box != null ? "OK" : "NULL",
                wysiwyg_editor != null ? "OK" : "NULL",
                statusbar_box != null ? "OK" : "NULL");

            // Structure corrigée: extraire toolbar et statusbar du scroll
            // 1. Toolbar en haut (fixe, ne scroll pas)
            content_box.append(toolbar_box);

            // 2. Zone d'édition avec scroll au centre (seul l'éditeur scroll)
            var editor_scroll = new ScrolledWindow();
            editor_scroll.set_policy(PolicyType.AUTOMATIC, PolicyType.AUTOMATIC);
            editor_scroll.set_vexpand(true);
            editor_scroll.set_hexpand(true);
            editor_scroll.set_child(wysiwyg_editor);
            content_box.append(editor_scroll);

            // 3. Statusbar en bas (fixe, ne scroll pas)
            content_box.append(statusbar_box);

            stderr.printf("🔍 EditorView.constructor: ARCHITECTURE CORRIGÉE - toolbar et statusbar maintenant FIXES\n");

            // Ajoute le contenu dans le cadre
            frame.set_child(content_box);

            // Ajoute le cadre à la box principale de l'EditorView
            this.append(frame);

            update_statusbar();

            stderr.printf("🔍 EditorView.constructor: FIN - Widgets assemblés et visibles\n");

            // Mets à jour la position du curseur en temps réel
            var buffer = wysiwyg_editor.get_buffer();
            if (buffer != null) {
                buffer.notify["cursor-position"].connect(() => {
                    update_cursor_position();
                });
            } else {
                warning("EditorView: Buffer de wysiwyg_editor est NULL");
            }
        }

        private void update_cursor_position() {
            int line, column;
            wysiwyg_editor.get_cursor_position(out line, out column);
            position_label.set_text("Ln %d, Col %d".printf(line + 1, column + 1));
        }

        // Méthodes déplacées en dehors du constructeur
        public void set_editor_style(int size, string family, string color) {
            this.font_size = size;
            this.font_family = family;
            this.font_color = color;
            wysiwyg_editor.set_style(size, family, color);
        }

        // --- Méthodes de la classe EditorView ---

        // Nouvelle méthode pour afficher le dialogue de couleur
        private async void show_color_dialog() {
            var dialog = new Gtk.ColorDialog();
            dialog.set_title(_("Choisir une couleur"));
            dialog.set_with_alpha(false); // Ou true si tu veux gérer la transparence

            try {
                // Obtenir la fenêtre parente
                var window = get_root() as Gtk.Window;
                if (window == null) return;

                // Afficher le dialogue et attendre le choix
                var color = yield dialog.choose_rgba(window, null, null);

                if (color != null) {
                    font_color = color.to_string();
                    // Appliquer à la sélection si elle existe
                    if (wysiwyg_editor.has_selection()) {
                        wysiwyg_editor.apply_color_to_selection(font_color);
                    }
                    // Optionnel: Mettre à jour l'icône du bouton pour refléter la couleur ?
                    // (Peut être complexe, l'icône standard est souvent suffisante)
                }
            } catch (Error e) {
                warning("Erreur lors du choix de la couleur: %s", e.message);
            }
        }

        // Placeholder for the link dialog method
        private void show_link_dialog() {
            warning("show_link_dialog() not implemented yet.");
            // TODO: Implement dialog to get URL and text, then call:
            // wysiwyg_editor.insert_link(url, text);
        }

        // Placeholder for the image dialog method
        private void show_image_dialog() {
            warning("show_image_dialog() not implemented yet.");
            // TODO: Implement dialog to get image source, then call:
            // wysiwyg_editor.insert_image(src);
        }

        // Placeholder for the table dialog method
        private void show_table_dialog() {
            warning("show_table_dialog() not implemented yet.");
            // TODO: Implement dialog to get rows/cols, then call:
            // wysiwyg_editor.insert_table(rows, cols);
        }


        private int find_index_in_array(string[] array, string value) {
            for (int i = 0; i < array.length; i++) {
                if (array[i] == value) {
                    return i;
                }
            }
            return 0; // Default to first item if not found
        }

        private void save_style_to_pivot(PivotDocument? doc, string family, int size, string color) {
            if (doc != null) {
                doc.meta_font_family = family;
                doc.meta_font_size = size;
                doc.meta_font_color = color;
            }
        }

        public enum DocumentSource {
            UNKNOWN,
            EXPLORER,
            CHAT,
            TERMINAL,
            MACRO,
            CLIPBOARD
        }

        private DocumentSource doc_source = DocumentSource.UNKNOWN;
        private string? current_file_path = null;

        // Méthode pour définir la provenance
        public void set_document_source(DocumentSource source) {
            doc_source = source;
            update_statusbar();
        }

        // Méthode pour définir le chemin du fichier
        public void set_current_file_path(string path) {
            current_file_path = path;
            update_statusbar();
        }

        // Mets à jour le titre de la fenêtre principale selon le fichier courant
        private void update_title() {
            var main_window = get_ancestor(typeof(MainWindow)) as MainWindow;
            if (main_window != null) {
                string title;
                if (current_file_path != null && current_file_path != "") {
                    title = Path.get_basename(current_file_path);
                } else {
                    title = _("Nouveau document");
                }
                main_window.set_title(title);
            }
        }

        // Mets à jour la barre d’état (nom du fichier)
        private void update_statusbar() {
            string provenance = "";
            switch (doc_source) {
                case DocumentSource.EXPLORER: provenance = _("Explorateur"); break;
                case DocumentSource.CHAT: provenance = _("Chat IA"); break;
                case DocumentSource.TERMINAL: provenance = _("Terminal"); break;
                case DocumentSource.MACRO: provenance = _("Macro"); break;
                case DocumentSource.CLIPBOARD: provenance = _("Presse-papiers"); break;
                default: provenance = _("Inconnu"); break;
            }

            string file_info = (current_file_path != null && current_file_path != "") ? current_file_path : _("Nouveau document");

            // Ajout du libellé "Origine :"
            provenance_label.set_text(_("Origine : ") + provenance);
            status_label.set_text(file_info);
            update_cursor_position();
        }

        // Mets à jour la barre d’état après chaque chargement/sauvegarde
        public void load_document(PivotDocument document) {
            stderr.printf("🔍 EditorView.load_document: DÉBUT - Document: %s\n", document != null ? "OUI" : "NON");
            stderr.printf("🔍 EditorView.load_document: Widgets visibles AVANT - toolbar_box: %s, wysiwyg_editor: %s, statusbar_box: %s\n",
                toolbar_box.get_visible() ? "OUI" : "NON",
                wysiwyg_editor.get_visible() ? "OUI" : "NON",
                statusbar_box.get_visible() ? "OUI" : "NON");

            current_document = document;
            wysiwyg_editor.load_pivot_document(document);
            has_unsaved_changes = false;
            update_statusbar();

            stderr.printf("🔍 EditorView.load_document: Widgets visibles APRÈS - toolbar_box: %s, wysiwyg_editor: %s, statusbar_box: %s\n",
                toolbar_box.get_visible() ? "OUI" : "NON",
                wysiwyg_editor.get_visible() ? "OUI" : "NON",
                statusbar_box.get_visible() ? "OUI" : "NON");

            // Vérifier les dimensions immédiates des widgets
            int toolbar_width = toolbar_box.get_width();
            int toolbar_height = toolbar_box.get_height();
            int editor_width = wysiwyg_editor.get_width();
            int editor_height = wysiwyg_editor.get_height();
            int statusbar_width = statusbar_box.get_width();
            int statusbar_height = statusbar_box.get_height();

            stderr.printf("📏 EditorView DIMENSIONS (immédiat) - toolbar: %dx%d, editor: %dx%d, statusbar: %dx%d\n",
                toolbar_width, toolbar_height, editor_width, editor_height, statusbar_width, statusbar_height);

            stderr.printf("🔍 EditorView.load_document: FIN\n");

            // Timer différé pour vérifier la visibilité ET les dimensions 3 secondes plus tard
            Timeout.add_seconds(3, () => {
                stderr.printf("🔍 EditorView.load_document: VÉRIFICATION DIFFÉRÉE (3s) - toolbar_box: %s, wysiwyg_editor: %s, statusbar_box: %s\n",
                    toolbar_box.get_visible() ? "OUI" : "NON",
                    wysiwyg_editor.get_visible() ? "OUI" : "NON",
                    statusbar_box.get_visible() ? "OUI" : "NON");

                // Vérifier les dimensions réelles des widgets
                int tb_width = toolbar_box.get_width();
                int tb_height = toolbar_box.get_height();
                int ed_width = wysiwyg_editor.get_width();
                int ed_height = wysiwyg_editor.get_height();
                int sb_width = statusbar_box.get_width();
                int sb_height = statusbar_box.get_height();

                stderr.printf("📏 EditorView DIMENSIONS (3s) - toolbar: %dx%d, editor: %dx%d, statusbar: %dx%d\n",
                    tb_width, tb_height, ed_width, ed_height, sb_width, sb_height);

                return false; // Ne pas répéter
            });
        }

        public bool save_document(string? path = null) {
            // Si aucun chemin n'est spécifié, utiliser le chemin actuel
            string save_path = path ?? current_file_path;

            // S'il n'y a toujours pas de chemin, demander à l'utilisateur
            if (save_path == null) {
                // Utiliser un bool pour stocker le résultat
                bool result = false;
                save_document_as.begin((obj, res) => {
                    result = save_document_as.end(res);
                });

                // Exécuter la boucle principale jusqu'à ce que l'opération asynchrone soit terminée
                var loop = new MainLoop();
                Timeout.add(100, () => {
                    if (loop.is_running())
                        loop.quit();
                    return Source.REMOVE;
                });
                loop.run();

                return result;
            }

            try {
                // Récupérer le document pivot depuis l'éditeur
                var pivot_doc = wysiwyg_editor.get_pivot_document();

                // Mettre à jour le chemin dans le document
                pivot_doc.source_path = save_path;

                // Détecter le format à partir de l'extension
                if (save_path.down().has_suffix(".pivot")) {
                    pivot_doc.source_format = "pivot";
                } else if (save_path.down().has_suffix(".md")) {
                    pivot_doc.source_format = "md";
                } else if (save_path.down().has_suffix(".html") || save_path.down().has_suffix(".htm")) {
                    pivot_doc.source_format = "html";
                } else if (save_path.down().has_suffix(".txt")) {
                    pivot_doc.source_format = "txt";
                } else {
                    // Format par défaut
                    pivot_doc.source_format = "txt";
                }

                // Sauvegarder via le gestionnaire de convertisseurs
                var converter_manager = DocumentConverterManager.get_instance();
                converter_manager.save_pivot_to_file(pivot_doc, save_path);

                // Mettre à jour le chemin du fichier actuel
                current_file_path = save_path;

                // Mettre à jour le titre
                update_title();

                // Marquer comme sauvegardé (implémenter un système pour suivre les modifications)
                has_unsaved_changes = false; // Déclenche l'émission du signal save_state_changed

                // Afficher une notification de succès
                var toast = new Adw.Toast(_("Document sauvegardé"));
                toast.set_timeout(2);

                // Obtenir la fenêtre principale pour afficher le toast
                var main_window = get_ancestor(typeof(MainWindow)) as MainWindow;
                if (main_window != null) {
                    main_window.add_toast(toast);
                }

                return true;
            } catch (Error e) {
                // Afficher un message d'erreur
                var dialog = new Adw.AlertDialog(
                    _("Erreur de sauvegarde"),
                    _("Impossible de sauvegarder le fichier: %s").printf(e.message)
                );
                dialog.add_response("ok", _("OK"));
                dialog.set_response_appearance("ok", Adw.ResponseAppearance.SUGGESTED);

                // Obtenir la fenêtre principale pour afficher le dialogue
                var main_window = get_ancestor(typeof(MainWindow)) as MainWindow;
                if (main_window != null) {
                    dialog.present(main_window);
                }

                return false;
            }
        }

        /**
         * Affiche une boîte de dialogue pour sauvegarder le document sous un nouveau nom
         */
        public async bool save_document_as() {
            // Utiliser FileDialog de GTK4
            var dialog = new FileDialog();
            dialog.set_title(_("Enregistrer le document"));

            // Proposer par défaut le même format que le document actuel
            string suggested_name = "document";
            string suggested_extension = ".txt";

            // Si le document a déjà un chemin, proposer le même nom
            if (current_file_path != null) {
                var file_name = Path.get_basename(current_file_path);
                suggested_name = file_name;
            }

            // Si le document a un format source, proposer la même extension
            if (current_document != null && current_document.source_format != null) {
                if (current_document.source_format == "md") {
                    suggested_extension = ".md";
                } else if (current_document.source_format == "html") {
                    suggested_extension = ".html";
                } else {
                    suggested_extension = ".txt";
                }
            }

            // Proposer un nom par défaut
            if (!suggested_name.contains(".")) {
                suggested_name += suggested_extension;
            }

            // Filtres pour les formats supportés
            var txt_filter = new FileFilter();
            txt_filter.add_mime_type("text/plain");
            txt_filter.name = _("Fichiers texte (*.txt)");

            var md_filter = new FileFilter();
            md_filter.add_mime_type("text/markdown");
            md_filter.name = _("Documents Markdown (*.md)");

            var html_filter = new FileFilter();
            html_filter.add_mime_type("text/html");
            html_filter.name = _("Documents HTML (*.html, *.htm)");

            var pivot_filter = new FileFilter();
            pivot_filter.add_mime_type("application/x-pivot");
            pivot_filter.add_pattern("*.pivot");
            pivot_filter.name = _("Fichiers Pivot (*.pivot)");

            var all_filter = new FileFilter();
            all_filter.add_mime_type("text/plain");
            all_filter.add_mime_type("text/markdown");
            all_filter.add_mime_type("text/html");
            all_filter.add_mime_type("application/x-pivot");
            all_filter.name = _("Tous les documents supportés");

            // Ajouter les filtres
            var filters = new GLib.ListStore(typeof(FileFilter));
            filters.append(all_filter);
            filters.append(md_filter);
            filters.append(html_filter);
            filters.append(txt_filter);
            filters.append(pivot_filter);
            dialog.set_filters(filters);

            // Proposer un nom par défaut
            dialog.set_initial_name(suggested_name);

            // Obtenir la fenêtre principale
            var main_window = get_ancestor(typeof(MainWindow)) as MainWindow;
            if (main_window == null) {
                return false;
            }

            try {
                var selected_file = yield dialog.save(main_window, null);
                if (selected_file != null) {
                    string path = selected_file.get_path();
                    return save_document(path);
                }
            } catch (Error e) {
                var alert = new Adw.AlertDialog(
                    _("Erreur de sauvegarde"),
                    _("Impossible de sauvegarder le fichier: %s").printf(e.message)
                );
                alert.add_response("ok", _("OK"));
                alert.set_response_appearance("ok", Adw.ResponseAppearance.SUGGESTED);
                alert.present(main_window);
            }
            return false;
        }

        private bool is_color_black(string color) {
            // Accepte #000, #000000, rgb(0,0,0), etc.
            string c = color.strip().down();
            return c == "#000" || c == "#000000" || c == "black" || c == "rgb(0,0,0)";
        }
    }
}

