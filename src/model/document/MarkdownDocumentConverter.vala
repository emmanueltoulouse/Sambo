using Gee;

namespace Sambo.Document {
    public class MarkdownDocumentConverter : Object, DocumentConverter {
        // Lors de la conversion Markdown -> PivotDocument (to_pivot)
        public PivotDocument to_pivot(string content, string path) {
            var pivot = new PivotDocument();
            pivot.source_path = path;
            pivot.source_format = "md";

            // --- Extraction des métadonnées de style si présentes ---
            foreach (string line in content.split("\n")) {
                if (line.strip().has_prefix("<!--") && line.contains("font:")) {
                    var meta = line.strip().replace("<!--", "").replace("-->", "").strip();
                    foreach (string part in meta.split(";")) {
                        var kv = part.strip().split(":");
                        if (kv.length == 2) {
                            string key = kv[0].strip();
                            string val = kv[1].strip();
                            if (key == "font") pivot.meta_font_family = val;
                            else if (key == "size") pivot.meta_font_size = int.parse(val);
                            else if (key == "color") pivot.meta_font_color = val;
                        }
                    }
                }
            }

            // Traitement ligne par ligne
            var lines = content.split("\n");
            bool in_code = false;
            StringBuilder code_buf = null;
            string code_lang = "";
            var para_buf = new StringBuilder();

            void flush_paragraph() {
                var text = para_buf.str.strip();
                if (text.length > 0) {
                    var para = new PivotParagraph();
                    para.segments = parse_inline_formatting(text);
                    pivot.children.add(para);
                    para_buf.truncate(0);
                }
            }

            foreach (string raw in lines) {
                string t = raw.strip();
                // Bloc de code
                if (!in_code && t.has_prefix("```")) {
                    flush_paragraph();
                    in_code = true;
                    code_lang = t.substring(3).strip();
                    code_buf = new StringBuilder();
                    continue;
                }
                if (in_code) {
                    if (t == "```") {
                        pivot.children.add(new PivotCodeBlock() { language = code_lang, code = code_buf.str });
                        in_code = false;
                    } else {
                        code_buf.append(raw + "\n");
                    }
                    continue;
                }
                // Vide -> fin de paragraphe
                if (t == "") {
                    flush_paragraph();
                    continue;
                }
                // Titre
                if (t.has_prefix("#")) {
                    flush_paragraph();
                    int level = 0;
                    while (level < t.length && t[level] == '#') level++;
                    if (level > 0 && level <= 6 && t.length > level && t[level] == ' ') {
                        string heading_text = t.substring(level).strip();
                        pivot.children.add(new PivotHeading() { level = level, text = heading_text });
                        continue;
                    }
                }
                // Citation
                if (t.has_prefix(">")) {
                    flush_paragraph();
                    var linesq = raw.split("\n");
                    var quote = new StringBuilder();
                    foreach (string lq in linesq) {
                        string r = lq.strip();
                        if (r.has_prefix(">")) quote.append(r.substring(1).strip() + " ");
                        else quote.append(r + " ");
                    }
                    pivot.children.add(new PivotQuote() { text = quote.str.strip() });
                    continue;
                }
                // Liste non ordonnée
                if (t.has_prefix("* ") || t.has_prefix("- ") || t.has_prefix("+ ")) {
                    flush_paragraph();
                    var list = new PivotList() { ordered = false };
                    var items = raw.split("\n");
                    foreach (string li in items) {
                        string ri = li.strip();
                        if (ri.has_prefix("* ") || ri.has_prefix("- ") || ri.has_prefix("+ ")) {
                            list.items.add(new PivotListItem() { text = ri.substring(2).strip() });
                        }
                    }
                    pivot.children.add(list);
                    continue;
                }
                // Texte standard
                para_buf.append(raw + "\n");
            }
            // Flush restant
            if (in_code) {
                pivot.children.add(new PivotCodeBlock() { language = code_lang, code = code_buf.str });
            } else {
                flush_paragraph();
            }

            // Le return doit être HORS de la boucle foreach
            return pivot;
        }

        private string process_inline_formatting(string text) {
            // Ici vous pouvez implémenter la détection des éléments inline
            // comme **gras**, *italique*, etc.
            // Pour l'instant, on retourne le texte tel quel
            return text;
        }

        public string from_pivot(PivotDocument pivot) {
            StringBuilder builder = new StringBuilder();

            // --- Écriture des métadonnées si présentes ---
            if (pivot.meta_font_family != null || pivot.meta_font_size != null || pivot.meta_font_color != null) {
                builder.append("<!--");
                if (pivot.meta_font_family != null)
                    builder.append(" font:%s;".printf(pivot.meta_font_family));
                if (pivot.meta_font_size != null)
                    builder.append(" size:%d;".printf(pivot.meta_font_size));
                if (pivot.meta_font_color != null)
                    builder.append(" color:%s;".printf(pivot.meta_font_color));
                builder.append(" -->\n\n");
            }

            builder.append(pivot.to_markdown());
            return builder.str;
        }

        private Gee.List<TextSegment> parse_inline_formatting(string text) {
            return parse_inline_recursive(text, new Gee.HashSet<TextFormatting>());
        }

        private Gee.List<TextSegment> parse_inline_recursive(string text, Gee.HashSet<TextFormatting> active_formats) {
            var segments = new Gee.ArrayList<TextSegment>();
            int i = 0;
            while (i < text.length) {
                // Cherche le prochain marqueur
                int next = text.length;
                string? found_marker = null;
                string[] markers = { "**", "*", "~~", "`", "__" };  // Ajout de __ pour soulignement
                foreach (var marker in markers) {
                    int idx = text.index_of(marker, i);
                    if (idx != -1 && idx < next) {
                        next = idx;
                        found_marker = marker;
                    }
                }

                // Texte avant le marqueur (ou tout le texte s'il n'y a pas de marqueur)
                if (found_marker == null) {
                    if (i < text.length) {
                        var copy = new Gee.HashSet<TextFormatting>();
                        copy.add_all(active_formats);
                        segments.add(new TextSegment(text.substring(i), copy));
                    }
                    break;
                }

                // Ajouter le segment avant le marqueur
                if (next > i) {
                    var copy = new Gee.HashSet<TextFormatting>();
                    copy.add_all(active_formats);
                    segments.add(new TextSegment(text.substring(i, next - i), copy));
                }

                // Chercher la fin du marqueur
                int close = text.index_of(found_marker, next + found_marker.length);
                if (close == -1) {
                    // Pas de fin de marqueur, considérer le reste comme texte brut
                    var copy = new Gee.HashSet<TextFormatting>();
                    copy.add_all(active_formats);
                    segments.add(new TextSegment(text.substring(next), copy)); // inclut le marqueur de début
                    break;
                }

                // Le texte entre les marqueurs avec le format appliqué
                var new_formats = new Gee.HashSet<TextFormatting>();
                new_formats.add_all(active_formats);

                // IMPORTANT: Détecter correctement le format
                switch (found_marker) {
                    case "**": new_formats.add(TextFormatting.BOLD); break;
                    case "*": new_formats.add(TextFormatting.ITALIC); break;
                    case "~~": new_formats.add(TextFormatting.STRIKETHROUGH); break;
                    case "`": new_formats.add(TextFormatting.CODE); break;
                    case "__": new_formats.add(TextFormatting.UNDERLINE); break;
                }

                // CORRECTION IMPORTANTE: Ajouter directement un segment avec le texte entre les marqueurs
                // au lieu de faire une récursion qui peut garder les marqueurs
                string content_between = text.substring(next + found_marker.length, close - next - found_marker.length);
                segments.add(new TextSegment(content_between, new_formats));

                // Avancer après le marqueur de fin
                i = close + found_marker.length;
            }
            return segments;
        }
    }
}
