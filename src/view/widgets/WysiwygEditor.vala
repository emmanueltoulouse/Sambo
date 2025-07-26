using Gtk;
using Sambo.Document;

namespace Sambo {
    public class WysiwygEditor : Gtk.TextView {
        private new Gtk.TextBuffer buffer;
        private PivotDocument? pivot_doc;

        private Gtk.TextTag tag_bold;
        private Gtk.TextTag tag_italic;
        private Gtk.TextTag tag_heading1;
        private Gtk.TextTag tag_heading2;
        private Gtk.TextTag tag_heading3;
        private Gtk.TextTag tag_code;
        private Gtk.TextTag tag_quote;
        private Gtk.TextTag tag_strikethrough;
        private Gtk.TextTag tag_link;
        private Gtk.TextTag tag_list;
        private Gtk.TextTag tag_underline;

        private Gtk.CssProvider css_provider;

        public signal void document_changed(PivotDocument doc);
        public signal void buffer_changed();

        public WysiwygEditor() {
            Object();

            // Zone d'édition
            this.set_wrap_mode(Gtk.WrapMode.WORD_CHAR);
            this.set_monospace(false);
            this.set_vexpand(true);
            this.set_hexpand(true);
            buffer = this.get_buffer();

            // Forcer le fond blanc
            this.set_css_classes({"wysiwyg-editor-textview"});
            var css = new Gtk.CssProvider();
            css.load_from_string(".wysiwyg-editor-textview { background-color: #fff; }");
            Gtk.StyleContext.add_provider_for_display(Gdk.Display.get_default(), css, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

            // Initialisation de tous les tags utilisés
            tag_bold = buffer.create_tag("bold", "weight", Pango.Weight.BOLD);
            tag_italic = buffer.create_tag("italic", "style", Pango.Style.ITALIC);
            tag_heading1 = buffer.create_tag("h1", "scale", 1.8, "weight", Pango.Weight.BOLD);
            tag_heading2 = buffer.create_tag("h2", "scale", 1.5, "weight", Pango.Weight.BOLD);
            tag_heading3 = buffer.create_tag("h3", "scale", 1.2, "weight", Pango.Weight.BOLD);
            tag_code = buffer.create_tag("code",
                                        "family", "monospace",
                                        "background", "#f5f5f5",
                                        "paragraph-background", "#f5f5f5",
                                        "left-margin", 20,
                                        "right-margin", 20);
            tag_quote = buffer.create_tag("quote",
                                         "left-margin", 30,
                                         "style", Pango.Style.ITALIC,
                                         "foreground", "#555555",
                                         "paragraph-background", "#eeeeee",
                                         "background", "#eeeeee");
            tag_strikethrough = buffer.create_tag("strikethrough", "strikethrough", true);
            tag_underline = buffer.create_tag("underline", "underline", Pango.Underline.SINGLE);
            tag_link = buffer.create_tag("link",
                                        "underline", Pango.Underline.SINGLE,
                                        "foreground", "#0066cc");
            tag_list = buffer.create_tag("list", "left-margin", 20);

            buffer.changed.connect(() => {
                buffer_changed();
            });
        }

        // Exemple d'utilisation sécurisée d'un tag
        public void apply_bold() {
            TextIter start, end;
            if (buffer.get_selection_bounds(out start, out end)) {
                if (tag_bold != null)
                    buffer.apply_tag(tag_bold, start, end);
            }
        }

        public void apply_italic() {
            TextIter start, end;
            if (buffer.get_selection_bounds(out start, out end)) {
                if (tag_italic != null)
                    buffer.apply_tag(tag_italic, start, end);
            }
        }

        public void apply_heading(int level) {
            TextIter start, end;
            if (buffer.get_selection_bounds(out start, out end)) {
                if (level == 1 && tag_heading1 != null) {
                    buffer.apply_tag(tag_heading1, start, end);
                } else if (level == 2 && tag_heading2 != null) {
                    buffer.apply_tag(tag_heading2, start, end);
                } else if (level >= 3 && tag_heading3 != null) {
                    buffer.apply_tag(tag_heading3, start, end);
                }
            }
        }

        public void apply_code() {
            TextIter start, end;
            if (buffer.get_selection_bounds(out start, out end)) {
                if (tag_code != null)
                    buffer.apply_tag(tag_code, start, end);
            }
        }

        public void apply_quote() {
            TextIter start, end;
            if (buffer.get_selection_bounds(out start, out end)) {
                if (tag_quote != null)
                    buffer.apply_tag(tag_quote, start, end);
            }
        }

        public void apply_format(TextFormatting format) {
            TextIter start, end;
            if (buffer.get_selection_bounds(out start, out end)) {
                switch (format) {
                    case TextFormatting.UNDERLINE:
                        if (tag_underline != null)
                            buffer.apply_tag(tag_underline, start, end);
                        break;
                    case TextFormatting.STRIKETHROUGH:
                        if (tag_strikethrough != null)
                            buffer.apply_tag(tag_strikethrough, start, end);
                        break;
                    default:
                        break;
                }
            }
        }

        public void insert_list(bool ordered) {
            var list = new PivotList();
            list.ordered = ordered;

            // Créer quelques éléments par défaut
            for (int i = 0; i < 3; i++) {
                var item = new PivotListItem();
                item.text = "";
                list.items.add(item);
            }

            // Obtenir la position actuelle du curseur
            TextIter iter;
            buffer.get_iter_at_mark(out iter, buffer.get_insert());

            // Insérer à l'emplacement actuel
            TextIter start = iter;

            // Insérer un marqueur pour le début de la liste
            TextMark list_start = buffer.create_mark(null, iter, true);

            // Insérer chaque élément de la liste
            foreach (var item in list.items) {
                if (ordered) {
                    buffer.insert(ref iter, "%d. ".printf(list.items.index_of(item) + 1), -1);
                } else {
                    buffer.insert(ref iter, "• ", -1);
                }
                buffer.insert(ref iter, "\n", -1);
            }

            // Appliquer un style spécial à toute la liste
            TextIter end = iter;
            TextIter list_iter;
            buffer.get_iter_at_mark(out list_iter, list_start);
            buffer.apply_tag(tag_list, list_iter, end);

            // Supprimer le marqueur
            buffer.delete_mark(list_start);
        }

        public void insert_code_block() {
            // Créer un bloc de code vide
            var code_block = new PivotCodeBlock();
            code_block.language = "";
            code_block.code = "";

            // Obtenir la position actuelle du curseur
            TextIter iter;
            buffer.get_iter_at_mark(out iter, buffer.get_insert());

            // S'assurer qu'on est sur une nouvelle ligne
            if (!iter.starts_line()) {
                buffer.insert(ref iter, "\n", -1);
            }

            // Marque pour le début du bloc de code
            TextMark code_start = buffer.create_mark(null, iter, true);

            // Insérer le texte par défaut
            buffer.insert(ref iter, "[language]\n", -1);
            buffer.insert(ref iter, "// Votre code ici\n", -1);

            // Obtenir l'itérateur pour la fin du bloc
            TextIter start;
            buffer.get_iter_at_mark(out start, code_start);

            // Appliquer le style de bloc de code
            buffer.apply_tag(tag_code, start, iter);

            // Supprimer le marqueur
            buffer.delete_mark(code_start);
        }

        public void insert_link(string url, string text) {
            // Créer un lien pivot
            var link = new PivotLink();
            link.href = url;
            link.text = text;

            // Obtenir la position actuelle du curseur
            TextIter iter;
            buffer.get_iter_at_mark(out iter, buffer.get_insert());

            // Marque pour le début du lien
            TextMark link_start = buffer.create_mark(null, iter, true);

            // Insérer le texte du lien
            buffer.insert(ref iter, text, -1);

            // Appliquer le style de lien
            TextIter start;
            buffer.get_iter_at_mark(out start, link_start);

            // Créer un tag pour les liens si nécessaire
            if (tag_link == null) {
                tag_link = buffer.create_tag("link",
                    "underline", Pango.Underline.SINGLE,
                    "foreground", "#0066cc");
            }

            buffer.apply_tag(tag_link, start, iter);

            // Stocker l'URL pour le lien (pourrait être fait avec les données utilisateur du tag)

            // Supprimer le marqueur
            buffer.delete_mark(link_start);
        }

        public void insert_image(string path, string alt_text) {
            // Créer une image pivot
            var image = new PivotImage();
            image.src = path;
            image.alt = alt_text;

            // Obtenir la position actuelle du curseur
            TextIter iter;
            buffer.get_iter_at_mark(out iter, buffer.get_insert());

            // Pour l'instant, insérer juste une représentation textuelle
            buffer.insert(ref iter, "[Image: " + alt_text + "]", -1);

            // Note: Une implémentation complète nécessiterait d'utiliser GtkTextChildAnchor
            // pour insérer un widget d'image dans le TextView
        }

        public void insert_table(int rows, int cols) {
            // Créer une table pivot
            var table = new PivotTable();

            // Initialiser avec des cellules vides
            for (int i = 0; i < rows; i++) {
                var row = new Gee.ArrayList<string>();
                for (int j = 0; j < cols; j++) {
                    row.add("");
                }
                table.rows.add(row);
            }

            // Obtenir la position actuelle du curseur
            TextIter iter;
            buffer.get_iter_at_mark(out iter, buffer.get_insert());

            // Insérer un représentation ASCII simple de la table
            buffer.insert(ref iter, "\n", -1);

            // Marque pour le début de la table
            TextMark table_start = buffer.create_mark(null, iter, true);

            // En-têtes
            string header_row = "|";
            string separator_row = "|";

            // Utiliser la variable 'cols' passée en argument
            for (int j = 0; j < cols; j++) {
                header_row += " Colonne " + (j + 1).to_string() + " |";
                separator_row += " -------- |";
            }

            buffer.insert(ref iter, header_row + "\n", -1);
            buffer.insert(ref iter, separator_row + "\n", -1);

            // Lignes de données
            // Utiliser la variable 'rows' passée en argument
            for (int i = 1; i < rows; i++) {
                string data_row = "|";
                // Utiliser la variable 'cols' passée en argument
                for (int j = 0; j < cols; j++) {
                    data_row += "          |"; // Cellule vide par défaut
                }
                buffer.insert(ref iter, data_row + "\n", -1);
            }

            buffer.insert(ref iter, "\n", -1);

            // Appliquer un tag spécifique si nécessaire (optionnel)
            // TextIter table_end = iter;
            // TextIter start_iter;
            // buffer.get_iter_at_mark(out start_iter, table_start);
            // buffer.apply_tag(tag_table, start_iter, table_end);

            buffer.delete_mark(table_start);

            // Note: Une implémentation complète nécessiterait une interface utilisateur
            // plus sophistiquée pour l'édition de tableau
        }

        public void load_pivot_document(PivotDocument document) {
            stderr.printf("🔍 WysiwygEditor.load_pivot_document: DÉBUT - Document: %s\n",
                document != null ? "NON-NULL" : "NULL");

            this.pivot_doc = document;
            render_pivot_to_buffer(document);
            buffer.set_modified(false);

            stderr.printf("🔍 WysiwygEditor.load_pivot_document: FIN\n");
        }

        private void render_pivot_to_buffer(PivotDocument doc) {
            stderr.printf("🔍 WysiwygEditor.render_pivot_to_buffer: DÉBUT\n");
            stderr.printf("🔍 WysiwygEditor.render_pivot_to_buffer: Widget visible: %s, parent: %s\n",
                this.get_visible() ? "OUI" : "NON",
                this.get_parent() != null ? "OUI" : "NON");

            buffer.set_text("", 0); // Vider le buffer

            stderr.printf("🔍 WysiwygEditor.render_pivot_to_buffer: APRÈS buffer.set_text - Widget visible: %s\n",
                this.get_visible() ? "OUI" : "NON");

            stderr.printf("🔍 Buffer vidé - Enfants: %d\n",
                doc != null && doc.children != null ? doc.children.size : 0);

            if (doc == null || doc.children.size == 0) {
                stderr.printf("🔍 Document null ou sans enfants, sortie\n");
                return; // Document vide
            }

            TextIter iter;
            buffer.get_start_iter(out iter);

            foreach (PivotNode node in doc.children) {
                if (node is PivotHeading) {
                    var heading = (PivotHeading)node;

                    // Créer une marque pour le début du texte
                    TextMark start_mark = buffer.create_mark(null, iter, true);

                    // Insérer le texte
                    buffer.insert(ref iter, heading.text + "\n\n", -1);

                    // Obtenir de nouveaux itérateurs valides à partir des marques
                    TextIter start, end;
                    buffer.get_iter_at_mark(out start, start_mark);
                    end = start;
                    end.forward_chars(heading.text.length);

                    // Appliquer le tag approprié
                    if (heading.level == 1) {
                        buffer.apply_tag(tag_heading1, start, end);
                    } else if (heading.level == 2) {
                        buffer.apply_tag(tag_heading2, start, end);
                    } else if (heading.level >= 3) {
                        buffer.apply_tag(tag_heading3, start, end);
                    }

                    // Supprimer la marque qui n'est plus nécessaire
                    buffer.delete_mark(start_mark);
                }
                else if (node is PivotParagraph) {
                    var para = (PivotParagraph)node;

                    // Marque pour le début du paragraphe
                    TextMark para_start = buffer.create_mark(null, iter, true);

                    // Pour chaque segment, appliquer le style approprié
                    foreach (var segment in para.segments) {
                        TextMark segment_start = buffer.create_mark(null, iter, true);
                        buffer.insert(ref iter, segment.text, -1);
                        TextIter seg_start, seg_end;
                        buffer.get_iter_at_mark(out seg_start, segment_start);
                        seg_end = iter;

                        // Appliquer tous les styles présents
                        if (segment.has_format(TextFormatting.BOLD))
                            buffer.apply_tag(tag_bold, seg_start, seg_end);
                        if (segment.has_format(TextFormatting.ITALIC))
                            buffer.apply_tag(tag_italic, seg_start, seg_end);
                        if (segment.has_format(TextFormatting.STRIKETHROUGH)) {
                            if (tag_strikethrough == null)
                                tag_strikethrough = buffer.create_tag("strikethrough", "strikethrough", true);
                            buffer.apply_tag(tag_strikethrough, seg_start, seg_end);
                        }
                        if (segment.has_format(TextFormatting.UNDERLINE)) {
                            if (tag_underline != null)
                                buffer.apply_tag(tag_underline, seg_start, seg_end);
                        }
                        if (segment.has_format(TextFormatting.CODE))
                            buffer.apply_tag(tag_code, seg_start, seg_end);

                        buffer.delete_mark(segment_start);
                    }

                    // Ajouter deux sauts de ligne après le paragraphe
                    buffer.insert(ref iter, "\n\n", -1);

                    // Supprimer la marque du paragraphe
                    buffer.delete_mark(para_start);
                }
                else if (node is PivotList) {
                    var list = (PivotList)node;
                    foreach (var item in list.items) {
                        // Insérer l'élément de liste avec un symbole ou un numéro
                        buffer.insert(ref iter, "• " + item.text + "\n", -1);
                    }
                    buffer.insert(ref iter, "\n", -1);
                }
                else if (node is PivotCodeBlock) {
                    var code = (PivotCodeBlock)node;

                    // Insérer une ligne vide avant si nécessaire
                    if (!iter.starts_line() && iter.get_line() > 0) {
                        buffer.insert(ref iter, "\n", -1);
                    }

                    // Marque pour le début du bloc de code
                    TextMark code_start = buffer.create_mark(null, iter, true);

                    // Insérer une indication de langage si disponible
                    if (code.language != null && code.language != "") {
                        buffer.insert(ref iter, "[" + code.language + "]\n", -1);
                    }

                    // Insérer le code avec préservation des sauts de ligne
                    buffer.insert(ref iter, code.code, -1);

                    // Ajouter un saut de ligne après le code
                    if (!iter.ends_line()) {
                        buffer.insert(ref iter, "\n", -1);
                    }
                    buffer.insert(ref iter, "\n", -1);

                    // Récupérer un itérateur valide pour le début
                    TextIter start;
                    buffer.get_iter_at_mark(out start, code_start);

                    // Appliquer le formatage au bloc de code
                    buffer.apply_tag(tag_code, start, iter);

                    // Supprimer la marque
                    buffer.delete_mark(code_start);
                }
                else if (node is PivotQuote) {
                    var quote = (PivotQuote)node;

                    // Insérer une ligne vide avant si nécessaire
                    if (!iter.starts_line() && iter.get_line() > 0) {
                        buffer.insert(ref iter, "\n", -1);
                    }

                    // Marque pour le début de la citation
                    TextMark quote_start = buffer.create_mark(null, iter, true);

                    // Insérer la citation (avec préfixe visuel)
                    buffer.insert(ref iter, "❝ " + quote.text, -1);

                    // Ajouter un saut de ligne après la citation
                    if (!iter.ends_line()) {
                        buffer.insert(ref iter, "\n", -1);
                    }
                    buffer.insert(ref iter, "\n", -1);

                    // Récupérer un itérateur valide pour le début
                    TextIter start;
                    buffer.get_iter_at_mark(out start, quote_start);

                    // Appliquer le formatage à la citation
                    buffer.apply_tag(tag_quote, start, iter);

                    // Supprimer la marque
                    buffer.delete_mark(quote_start);
                }
                else if (node is PivotTable) {
                    var table = (PivotTable)node;
                    TextIter current_iter;
                    buffer.get_iter_at_offset(out current_iter, buffer.get_char_count());

                    buffer.insert(ref current_iter, "\n--- TABLEAU ---\n", -1);
                    // Déterminer le nombre de colonnes (à partir de la première ligne si elle existe)
                    int num_cols = 0;
                    if (table.rows.size > 0 && table.rows[0] != null) {
                        num_cols = table.rows[0].size;
                    }

                    // En-têtes (simplifié)
                    string header_row = "|";
                    string separator_row = "|";
                    for (int j = 0; j < num_cols; j++) {
                        header_row += " Col %d |".printf(j + 1);
                        separator_row += " ----- |";
                    }
                    buffer.insert(ref current_iter, header_row + "\n", -1);
                    buffer.insert(ref current_iter, separator_row + "\n", -1);

                    // Données
                    foreach (var row in table.rows) {
                        string data_row = "|";
                        if (row != null) {
                            for (int j = 0; j < num_cols; j++) {
                                // Accéder à la cellule en vérifiant les limites
                                string? cell_text = (j < row.size && row[j] != null) ? row[j] : "";
                                string padded_cell = (cell_text ?? "");
                                if (padded_cell.length < 5) {
                                    padded_cell = padded_cell + string.nfill(5 - padded_cell.length, ' ');
                                }
                                data_row += " %s |".printf(padded_cell);
                            }
                        }
                        buffer.insert(ref current_iter, data_row + "\n", -1);
                    }
                    buffer.insert(ref current_iter, "--- FIN TABLEAU ---\n\n", -1);
                }
            }

            stderr.printf("🔍 WysiwygEditor.render_pivot_to_buffer: FIN\n");
        }

        /**
         * Convertit le contenu actuel du buffer en document pivot
         * Cette méthode est l'inverse de render_pivot_to_buffer
         */
        public PivotDocument get_pivot_document() {
            // Utiliser le document pivot existant comme base ou en créer un nouveau
            var doc = pivot_doc ?? new PivotDocument();

            // Effacer le contenu existant
            doc.children.clear();

            // Obtenir le texte complet du buffer avec les balises
            TextIter start, end;
            buffer.get_bounds(out start, out end);

            // Traiter le contenu par paragraphes
            string full_text = buffer.get_text(start, end, true);
            string[] paragraphs = full_text.split("\n\n");

            foreach (string para_text in paragraphs) {
                // Ignorer les paragraphes vides
                if (para_text.strip() == "")
                    continue;

                // Détecter les titres (par leur taille dans le buffer)
                bool is_heading1 = false;
                bool is_heading2 = false;
                bool is_heading3 = false;
                bool is_code = false;
                bool is_quote = false;

                // Vérifier les balises appliquées pour déterminer le type de contenu
                TextIter para_start, para_end;
                if (find_paragraph_bounds(para_text, out para_start, out para_end)) {
                    // Vérifier les tags appliqués au paragraphe
                    SList<weak TextTag> tags = para_start.get_tags();
                    foreach (weak TextTag tag in tags) {
                        if (tag == tag_heading1) is_heading1 = true;
                        else if (tag == tag_heading2) is_heading2 = true;
                        else if (tag == tag_heading3) is_heading3 = true;
                        else if (tag == tag_code) is_code = true;
                        else if (tag == tag_quote) is_quote = true;
                    }
                }

                // Créer le nœud approprié selon le type détecté
                if (is_heading1 || is_heading2 || is_heading3) {
                    var heading = new PivotHeading();
                    heading.text = para_text.strip();
                    heading.level = is_heading1 ? 1 : (is_heading2 ? 2 : 3);
                    doc.children.add(heading);
                }
                else if (is_code) {
                    var code_block = new PivotCodeBlock();
                    // Essayer de détecter le langage s'il est spécifié
                    string[] code_lines = para_text.split("\n");
                    if (code_lines.length > 0 && code_lines[0].has_prefix("[") && code_lines[0].has_suffix("]")) {
                        code_block.language = code_lines[0].substring(1, code_lines[0].length - 2);
                        // Retirer la ligne de langage
                        code_block.code = string.joinv("\n", code_lines[1:code_lines.length]);
                    } else {
                        code_block.code = para_text;
                    }
                    doc.children.add(code_block);
                }
                else if (is_quote) {
                    var quote = new PivotQuote();
                    // Retirer le préfixe "❝ " si présent
                    if (para_text.has_prefix("❝ "))
                        quote.text = para_text.substring(2);
                    else
                        quote.text = para_text;
                    doc.children.add(quote);
                }
                else if (para_text.contains("•") && para_text.contains("\n")) {
                    // Probablement une liste à puces
                    var list = new PivotList();
                    list.ordered = false;
                    string[] list_items = para_text.split("\n");
                    foreach (string item_text in list_items) {
                        string trimmed = item_text.strip();
                        if (trimmed.has_prefix("•")) {
                            var list_item = new PivotListItem();
                            list_item.text = trimmed.substring(1).strip(); // Retirer le bullet
                            list.items.add(list_item);
                        }
                    }
                    if (list.items.size > 0) {
                        doc.children.add(list);
                        continue;
                    }
                }

                // Paragraphe standard avec formatage
                var pivot_para = new PivotParagraph();
                pivot_para.segments = extract_formatted_segments(para_text, para_start, para_end);
                doc.children.add(pivot_para);
            }

            return doc;
        }

        /**
         * Trouve les limites d'un paragraphe dans le buffer - Méthode améliorée
         */
        private bool find_paragraph_bounds(string para_text, out TextIter start, out TextIter end) {
            buffer.get_start_iter(out start);
            buffer.get_end_iter(out end);

            // Approche plus sûre : au lieu de rechercher le texte exact,
            // rechercher ligne par ligne
            TextIter iter;
            buffer.get_start_iter(out iter);

            while (!iter.is_end()) {
                TextIter line_start = iter;
                TextIter line_end = iter;

                line_end.forward_to_line_end();

                // Extraire la ligne
                string line_text = buffer.get_text(line_start, line_end, false);

                // Si la ligne contient le début du paragraphe
                if (line_text.contains(para_text.substring(0, int.min(para_text.length, 30)))) {
                    start = line_start;

                    // Avancer d'autant de caractères qu'il y a dans para_text (approximativement)
                    TextIter potential_end = start;
                    potential_end.forward_chars(para_text.length);

                    // Ne pas dépasser la fin du buffer
                    if (potential_end.compare(end) > 0) {
                        potential_end = end;
                    }

                    end = potential_end;
                    return true;
                }

                // Passer à la ligne suivante
                if (!iter.forward_line()) {
                    break;
                }
            }

            // Paragraphe non trouvé, retourner les itérateurs du début et de la fin
            return false;
        }

        /**
         * Extrait les segments de texte formatés d'un paragraphe - Méthode améliorée
         */
        private Gee.List<TextSegment> extract_formatted_segments(string text, TextIter para_start, TextIter para_end) {
            var segments = new Gee.ArrayList<TextSegment>();

            // Si on n'a pas trouvé les limites précises ou si les itérateurs sont invalides, créer un segment simple
            if (para_start.equal(para_end) || para_start.get_buffer() != buffer || para_end.get_buffer() != buffer) {
                segments.add(new TextSegment(text));
                return segments;
            }

            // Protection contre les boucles infinies
            int max_iterations = text.length * 2;  // Limite raisonnable
            int iteration_count = 0;

            // Diviser le paragraphe en segments selon le formatage
            TextIter current = para_start;
            while (!current.equal(para_end) && iteration_count < max_iterations) {
                iteration_count++;

                TextIter segment_end = current;
                bool has_tag = segment_end.has_tag(tag_bold) || segment_end.has_tag(tag_italic) ||
                              segment_end.has_tag(tag_strikethrough) || segment_end.has_tag(tag_code);

                // Avancer caractère par caractère jusqu'à un changement de format ou la fin du paragraphe
                int safety_counter = 0;
                int max_safety = 1000;  // Limite de sécurité supplémentaire

                while (!segment_end.equal(para_end) && safety_counter < max_safety) {
                    safety_counter++;

                    bool current_has_tag = segment_end.has_tag(tag_bold) || segment_end.has_tag(tag_italic) ||
                                          segment_end.has_tag(tag_strikethrough) || segment_end.has_tag(tag_code);

                    // Si le formatage change, arrêter
                    if (has_tag != current_has_tag) {
                        break;
                    }

                    // Avancer d'un caractère
                    if (!segment_end.forward_char()) {
                        break;  // Fin du buffer
                    }
                }

                // Si on a atteint la limite de sécurité, passer à la fin du paragraphe
                if (safety_counter >= max_safety) {
                    warning("Limite de sécurité atteinte lors de l'extraction des segments formatés");
                    segment_end = para_end;
                }

                // Extraire ce segment de texte
                string segment_text = buffer.get_text(current, segment_end, false);

                // Détecter le formatage appliqué
                var formats = new Gee.HashSet<TextFormatting>();
                if (current.has_tag(tag_bold))
                    formats.add(TextFormatting.BOLD);
                if (current.has_tag(tag_italic))
                    formats.add(TextFormatting.ITALIC);
                if (current.has_tag(tag_strikethrough))
                    formats.add(TextFormatting.STRIKETHROUGH);
                if (current.has_tag(tag_code))
                    formats.add(TextFormatting.CODE);
                if (current.has_tag(tag_underline) || buffer.get_tag_table().lookup("underline") != null)
                    formats.add(TextFormatting.UNDERLINE);

                // Créer le segment
                segments.add(new TextSegment(segment_text, formats));

                // Passer au segment suivant
                current = segment_end;
            }

            // Si on a atteint la limite ou si aucun segment n'a été extrait, créer un segment par défaut
            if (iteration_count >= max_iterations || segments.size == 0) {
                warning("Limite d'itérations atteinte ou aucun segment trouvé. Création d'un segment par défaut.");
                segments.clear();
                segments.add(new TextSegment(text));
            }

            return segments;
        }

        /**
         * Analyse et applique le formatage inline dans un paragraphe
         */
        private void apply_inline_formatting(TextIter start_iter, int length, string text) {
            // Formatage gras - recherche des séquences **texte**
            int pos = 0;
            while ((pos = text.index_of("**", pos)) != -1) {
                int end_pos = text.index_of("**", pos + 2);
                if (end_pos != -1) {
                    TextIter bold_start = start_iter;
                    bold_start.forward_chars(pos);

                    TextIter bold_end = start_iter;
                    bold_end.forward_chars(end_pos + 2); // +2 pour inclure les **

                    buffer.apply_tag(tag_bold, bold_start, bold_end);

                    pos = end_pos + 2;
                } else {
                    break;
                }
            }

            // Formatage italique - recherche des séquences *texte*
            pos = 0;
            while ((pos = text.index_of("*", pos)) != -1) {
                if (pos > 0 && text[pos-1] == '*') {
                    // Ignorer les ** déjà traités pour le gras
                    pos++;
                    continue;
                }

                int end_pos = text.index_of("*", pos + 1);
                if (end_pos != -1 && (end_pos + 1 >= text.length || text[end_pos+1] != '*')) {
                    TextIter italic_start = start_iter;
                    italic_start.forward_chars(pos);

                    TextIter italic_end = start_iter;
                    italic_end.forward_chars(end_pos + 1); // +1 pour inclure le *

                    buffer.apply_tag(tag_italic, italic_start, italic_end);

                    pos = end_pos + 1;
                } else {
                    pos++;
                }
            }
        }

        public void set_style(int size, string family, string color) {
            if (css_provider == null) {
                css_provider = new Gtk.CssProvider();
                Gtk.StyleContext.add_provider_for_display(
                    Gdk.Display.get_default(),
                    css_provider,
                    Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
                );
            }
            var css_string = """
                textview {
                    font-family: '%s';
                    font-size: %dpx;
                    color: %s;
                }
            """.printf(family, size, color);
            css_provider.load_from_string(css_string);
        }

        public bool has_selection() {
            TextIter start, end;
            return buffer.get_selection_bounds(out start, out end);
        }

        public void apply_font_to_selection(string font_family) {
            TextIter start, end;
            if (buffer.get_selection_bounds(out start, out end)) {
                var tag = buffer.create_tag(null, "font-desc", font_family);
                buffer.apply_tag(tag, start, end);
            }
        }

        public void apply_font_size_to_selection(int size) {
            TextIter start, end;
            if (buffer.get_selection_bounds(out start, out end)) {
                var tag = buffer.create_tag(null, "size-points", size);
                buffer.apply_tag(tag, start, end);
            }
        }

        public void apply_color_to_selection(string color) {
            TextIter start, end;
            if (buffer.get_selection_bounds(out start, out end)) {
                var tag = buffer.create_tag(null, "foreground", color);
                buffer.apply_tag(tag, start, end);
            }
        }

        // --- Méthodes avancées pour les nouveaux blocs insérables ---
        /** Insère un bloc info/astuce/avertissement */
        public void insert_callout_info() {}
        /** Insère une liste de tâches à cocher */
        public void insert_todo_list() {}
        /** Insère un séparateur personnalisé */
        public void insert_separator_custom() {}
        /** Insère une citation multi-niveaux */
        public void insert_quote_multilevel() {}
        /** Insère un bloc d’alerte/erreur */
        public void insert_alert_block() {}
        /** Insère un bloc de code interactif */
        public void insert_code_interactive() {}
        /** Insère un bloc de référence/source */
        public void insert_reference_block() {}
        /** Insère un bloc repliable/accordéon */
        public void insert_collapsible_block() {}
        /** Insère une chronologie */
        public void insert_timeline() {}
        /** Insère un bloc graphique/diagramme */
        public void insert_chart_block() {}
        /** Insère une variable dynamique */
        public void insert_dynamic_variable() {}
        /** Insère un commentaire/feedback */
        public void insert_comment_block() {}

        // Returns the current cursor position as line and column (zero-based)
        public void get_cursor_position(out int line, out int column) {
            var buffer = this.get_buffer();
            Gtk.TextIter iter;
            buffer.get_iter_at_mark(out iter, buffer.get_insert());
            line = iter.get_line();
            column = iter.get_line_offset();
        }
    }
}
