using Gtk;
using Gdk;

namespace Sambo {
    /**
     * Widget de prévisualisation de fichier affichant un aperçu
     * du contenu d'un fichier sélectionné dans l'explorateur
     */
    public class FilePreviewWidget : Gtk.Box {
        private Image file_icon;
        private Label title_label;
        private Label info_label;
        private Box header_box;
        private Stack preview_stack;
        private TextView text_view;
        private TextBuffer buffer;
        private Picture image_view;
        private ScrolledWindow text_scroll;
        private Box placeholder_box;
        private ApplicationController controller;

        /**
         * Crée un nouveau widget de prévisualisation de fichier
         */
        public FilePreviewWidget() {
            Object(orientation: Orientation.VERTICAL, spacing: 6);

            // En-tête avec icône et informations
            header_box = new Box(Orientation.HORIZONTAL, 6);
            header_box.set_margin_start(6);
            header_box.set_margin_end(6);
            header_box.set_margin_top(6);

            title_label = new Label("");
            title_label.set_halign(Align.START);
            title_label.add_css_class("preview-title");

            info_label = new Label("");
            info_label.set_halign(Align.START);
            info_label.add_css_class("preview-info");

            var title_box = new Box(Orientation.HORIZONTAL, 6);
            file_icon = new Image();
            file_icon.set_pixel_size(32);
            title_box.append(file_icon);

            var labels_box = new Box(Orientation.VERTICAL, 2);
            labels_box.append(title_label);
            labels_box.append(info_label);
            title_box.append(labels_box);

            header_box.append(title_box);
            this.append(header_box);

            // Séparateur
            var separator = new Separator(Orientation.HORIZONTAL);
            this.append(separator);

            // Zone de contenu avec stack
            preview_stack = new Stack();
            preview_stack.set_vexpand(true);

            // Vue pour les fichiers texte
            text_scroll = new ScrolledWindow();
            text_scroll.set_policy(PolicyType.AUTOMATIC, PolicyType.AUTOMATIC);

            buffer = new TextBuffer(null);
            text_view = new TextView.with_buffer(buffer);
            text_view.set_editable(false);
            text_view.set_wrap_mode(Gtk.WrapMode.WORD);
            text_view.set_monospace(true);
            text_view.add_css_class("preview-text");

            text_scroll.set_child(text_view);
            preview_stack.add_named(text_scroll, "text");

            // Vue pour les images
            image_view = new Picture();
            image_view.keep_aspect_ratio = true;
            var image_scroll = new ScrolledWindow();
            image_scroll.set_policy(PolicyType.AUTOMATIC, PolicyType.AUTOMATIC);
            image_scroll.set_child(image_view);
            preview_stack.add_named(image_scroll, "image");

            // Vue pour les fichiers non prévisualisables
            placeholder_box = new Box(Orientation.VERTICAL, 6);
            placeholder_box.set_valign(Align.CENTER);
            placeholder_box.set_halign(Align.CENTER);

            var placeholder_icon = new Image.from_icon_name("dialog-information-symbolic");
            placeholder_icon.set_pixel_size(48);

            var placeholder_label = new Label("Prévisualisation non disponible");
            placeholder_label.add_css_class("dim-label");
            placeholder_label.add_css_class("title-3");

            placeholder_box.append(placeholder_icon);
            placeholder_box.append(placeholder_label);
            preview_stack.add_named(placeholder_box, "placeholder");

            this.append(preview_stack);

            // Afficher le placeholder par défaut
            preview_stack.set_visible_child_name("placeholder");
        }

        /**
         * Initialise le contrôleur
         *
         * @param controller Le contrôleur de l'application
         */
        public void set_controller(ApplicationController controller) {
            this.controller = controller;
        }

        /**
         * Prévisualise un fichier
         * @param file Le fichier à prévisualiser
         */
        public void preview_file(FileItemModel file) {
            if (file == null) {
                clear();
                return;
            }

            // Mettre à jour l'icône et les informations
            title_label.set_text(file.name);

            // Formater les informations du fichier
            string info_text = "";
            if (file.is_directory()) {
                info_text = "Dossier";
            } else {
                info_text = file.get_formatted_size() + " - Modifié " + file.get_formatted_modified_time();
            }
            info_label.set_text(info_text);

            // Mettre à jour l'icône
            if (file.icon != null) {
                file_icon.set_from_gicon(file.icon);
            } else if (file.is_directory()) {
                file_icon.set_from_icon_name("folder");
            } else {
                file_icon.set_from_icon_name("text-x-generic");
            }

            // Essayer de prévisualiser le contenu
            if (file.is_directory()) {
                // Pas de prévisualisation pour les dossiers
                preview_stack.set_visible_child_name("placeholder");
            } else {
                // Déterminer le type de fichier
                try {
                    var file_info = File.new_for_path(file.path).query_info(
                        "standard::content-type", FileQueryInfoFlags.NONE);
                    string content_type = file_info.get_content_type();

                    if (content_type.contains("image/")) {
                        // Prévisualiser l'image
                        try {
                            var pixbuf = new Gdk.Pixbuf.from_file(file.path);
                            image_view.set_pixbuf(pixbuf);
                            preview_stack.set_visible_child_name("image");
                        } catch (Error e) {
                            warning("Erreur lors du chargement de l'image: %s", e.message);
                            preview_stack.set_visible_child_name("placeholder");
                        }
                    } else if (content_type.contains("text/") ||
                              content_type.contains("application/json") ||
                              content_type.contains("application/xml")) {
                        // Prévisualiser le texte
                        try {
                            string text;
                            FileUtils.get_contents(file.path, out text);

                            // Limiter la taille du texte prévisualisé pour les performances
                            if (text.length > 10000) {
                                text = text.substring(0, 10000) + "\n\n[...] Le fichier est trop grand pour être affiché en entier.";
                            }

                            buffer.set_text(text, -1);
                            preview_stack.set_visible_child_name("text");
                        } catch (Error e) {
                            warning("Erreur lors de la lecture du fichier: %s", e.message);
                            preview_stack.set_visible_child_name("placeholder");
                        }
                    } else {
                        // Type de fichier non prévisualisable
                        preview_stack.set_visible_child_name("placeholder");
                    }
                } catch (Error e) {
                    warning("Erreur lors de la détermination du type de fichier: %s", e.message);
                    preview_stack.set_visible_child_name("placeholder");
                }
            }
        }

        /**
         * Efface la prévisualisation
         */
        public void clear() {
            title_label.set_text("");
            info_label.set_text("");
            file_icon.clear();
            buffer.set_text("", 0);
            preview_stack.set_visible_child_name("placeholder");
        }

        /**
         * Définit l'état vide avec un message
         */
        public void set_empty_state(string message) {
            var placeholder_label = new Label(message);
            placeholder_label.add_css_class("dim-label");
            placeholder_label.add_css_class("title-3");
            placeholder_box.append(placeholder_label);
            preview_stack.set_visible_child_name("placeholder");

            title_label.set_label("");
            info_label.set_label("");
            file_icon.clear();
        }

        /**
         * Affiche un aperçu du fichier spécifié
         */
        public void show_preview(FileItemModel file_item) {
            // Mettre à jour l'en-tête
            title_label.set_markup("<b>" + GLib.Markup.escape_text(file_item.name) + "</b>");

            string info_text = "";
            if (!file_item.is_directory()) {
                info_text = file_item.get_formatted_size() + " - " + file_item.get_formatted_modified_time();
            } else {
                info_text = "Dossier - " + file_item.get_formatted_modified_time();
            }

            info_label.set_label(info_text);

            // Mettre à jour l'icône
            try {
                if (file_item.icon != null) {
                    file_icon.set_from_gicon(file_item.icon);
                } else if (file_item.is_directory()) {
                    file_icon.set_from_icon_name("folder");
                } else {
                    file_icon.set_from_icon_name("text-x-generic");
                }
            } catch (Error e) {
                warning("Erreur lors de la définition de l'icône: %s", e.message);
                file_icon.set_from_icon_name("text-x-generic");
            }

            // Si c'est un dossier, montrer un message spécial
            if (file_item.is_directory()) {
                set_empty_state("Dossier: " + file_item.name + "\n\nContient des éléments que vous pouvez explorer.");
                return;
            }

            // Pour les fichiers texte, charger le contenu
            if (is_previewable_text_file(file_item)) {
                try {
                    // Vérifier que le contrôleur est initialisé
                    if (controller == null) {
                        set_empty_state("Erreur: Contrôleur non initialisé");
                        return;
                    }

                    // Lire le contenu du fichier directement
                    string content;
                    try {
                        FileUtils.get_contents(file_item.path, out content);

                        // Limiter la taille du texte prévisualisé pour les performances
                        if (content.length > 10000) {
                            content = content.substring(0, 10000) + "\n\n[...] Le fichier est trop grand pour être affiché en entier.";
                        }
                    } catch (Error e) {
                        set_empty_state("Erreur lors de la lecture du fichier: " + e.message);
                        return;
                    }

                    if (content != null) {
                        buffer.set_text(content, -1);
                        apply_syntax_highlighting(file_item.get_extension());
                        preview_stack.set_visible_child_name("text");
                    } else {
                        set_empty_state("Impossible de générer un aperçu pour ce fichier.");
                    }
                } catch (Error e) {
                    set_empty_state("Erreur lors du chargement de l'aperçu: " + e.message);
                }
            } else {
                set_empty_state("L'aperçu n'est pas disponible pour ce type de fichier.");
            }
        }

        /**
         * Vérifie si un fichier est prévisualisable en mode texte
         */
        private bool is_previewable_text_file(FileItemModel file) {
            if (file.is_directory()) return false;

            string ext = file.get_extension().down();
            string mime = file.mime_type.down();

            // Types MIME texte
            if (mime.has_prefix("text/")) return true;

            // Autres formats textuels communs
            string[] text_extensions = {
                "txt", "md", "json", "xml", "html", "htm", "css", "js",
                "py", "c", "cpp", "h", "java", "cs", "php", "rb", "pl",
                "sh", "bash", "vala", "yaml", "yml", "ini", "conf", "cfg",
                "log", "sql", "csv", "tsv"
            };

            foreach (string text_ext in text_extensions) {
                if (ext == text_ext) return true;
            }

            return false;
        }

        /**
         * Applique la coloration syntaxique selon l'extension du fichier
         */
        private void apply_syntax_highlighting(string extension) {
            // Cette fonction sera développée dans une phase future
            // Pour l'instant, on peut ajouter une coloration basique

            TextTag keyword_tag = buffer.create_tag("keyword", "foreground", "#0000FF", "weight", Pango.Weight.BOLD);
            TextTag string_tag = buffer.create_tag("string", "foreground", "#AA2222");
            TextTag comment_tag = buffer.create_tag("comment", "foreground", "#227722", "style", Pango.Style.ITALIC);

            // Exemple simple pour quelques langages courants
            switch (extension.down()) {
                case "vala":
                case "cs":
                case "java":
                case "cpp":
                case "c":
                    highlight_keywords(buffer, new string[] {
                        "if", "else", "for", "while", "switch", "case", "default", "break",
                        "return", "new", "class", "public", "private", "protected", "static",
                        "void", "int", "string", "bool", "var", "const"
                    }, "keyword");
                    break;

                case "py":
                    highlight_keywords(buffer, new string[] {
                        "if", "else", "for", "while", "def", "class", "import",
                        "from", "return", "True", "False", "None"
                    }, "keyword");
                    break;

                case "js":
                    highlight_keywords(buffer, new string[] {
                        "if", "else", "for", "while", "function", "var", "let",
                        "const", "return", "new", "class", "true", "false", "null"
                    }, "keyword");
                    break;
            }
        }

        /**
         * Surligne toutes les occurences d'un mot-clé
         */
        private void highlight_keywords(TextBuffer buffer, string[] keywords, string tag_name) {
            string content = buffer.text;

            foreach (string keyword in keywords) {
                int pos = 0;

                while ((pos = content.index_of(keyword, pos)) != -1) {
                    // Vérifier que c'est bien un mot séparé
                    bool is_word_start = pos == 0 || !content[pos-1].isalnum();
                    bool is_word_end = pos + keyword.length >= content.length ||
                                      !content[pos + keyword.length].isalnum();

                    if (is_word_start && is_word_end) {
                        TextIter start, end;
                        buffer.get_iter_at_offset(out start, pos);
                        buffer.get_iter_at_offset(out end, pos + keyword.length);
                        buffer.apply_tag_by_name(tag_name, start, end);
                    }

                    // Avancer après cette occurrence
                    pos += keyword.length;
                }
            }
        }
    }
}
