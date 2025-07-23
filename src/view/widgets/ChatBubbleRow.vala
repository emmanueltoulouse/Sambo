using Gtk;
using Adw;

namespace Sambo {
    /**
     * Widget représentant une bulle de message dans l'interface de chat
     */
    public class ChatBubbleRow : Gtk.Box {
        private Label content_label;
        private Label time_label;
        private ChatMessage message;

        // Optimisations UI
        private uint update_timeout_id = 0;     // ID du timeout pour debouncing
        private int64 last_update_time = 0;     // Timestamp dernière mise à jour
        private bool pending_update = false;    // Mise à jour en attente

        /**
         * Propriété publique pour accéder au message
         */
        public ChatMessage get_message() {
            return message;
        }

        /**
         * Crée une nouvelle bulle de message
         */
        public ChatBubbleRow(ChatMessage message) {
            Object(orientation: Orientation.VERTICAL, spacing: 3);

            stderr.printf("🟡 CHATBUBBLEROW: Début construction\n");

            // Vérification de sécurité
            if (message == null) {
                stderr.printf("❌ CHATBUBBLEROW: Message NULL passé au constructeur\n");
                warning("ChatBubbleRow: Message NULL passé au constructeur");
                return;
            }

            stderr.printf("🟡 CHATBUBBLEROW: Message reçu: '%s'\n", message.content ?? "(vide)");

            this.message = message;

            // Configuration en fonction du type d'émetteur
            bool is_user = (message.sender == ChatMessage.SenderType.USER);

            // Configuration visuelle de la boîte
            this.margin_start = is_user ? 50 : 12;
            this.margin_end = is_user ? 12 : 50;
            this.margin_top = 6;
            this.margin_bottom = 6;
            this.halign = is_user ? Align.END : Align.START;

            // Ajouter les classes CSS pour styliser
            this.add_css_class("chat-bubble");
            this.add_css_class(is_user ? "user-bubble" : "ai-bubble");

            // Conteneur pour le contenu avec un style de bulle
            var bubble_box = new Box(Orientation.VERTICAL, 3);
            stderr.printf("🟡 CHATBUBBLEROW: bubble_box créé\n");
            bubble_box.add_css_class("bubble-content");

            // Créer le libellé pour le contenu du message
            content_label = new Label("");
            stderr.printf("🟡 CHATBUBBLEROW: content_label créé avec: '%s'\n", message.content ?? "(vide)");
            content_label.wrap = true;
            content_label.wrap_mode = Pango.WrapMode.WORD_CHAR;
            content_label.xalign = 0;
            content_label.max_width_chars = 40;
            content_label.add_css_class("bubble-text");
            
            // Activer le markup Pango pour supporter les balises de formatage
            content_label.use_markup = true;
            
            // Convertir le contenu Markdown en markup Pango
            string formatted_content = convert_markdown_to_pango(message.content ?? "");
            stderr.printf("🎨 MARKDOWN: '%s' -> '%s'\n", 
                message.content ?? "(vide)", formatted_content);
            content_label.set_markup(formatted_content);

            // Créer le libellé pour l'horodatage
            time_label = new Label(message.get_formatted_stats());
            stderr.printf("🟡 CHATBUBBLEROW: time_label créé\n");
            time_label.add_css_class("bubble-time");
            time_label.set_halign(is_user ? Align.END : Align.START);

            // Ajouter les libellés au conteneur de bulle
            bubble_box.append(content_label);
            bubble_box.append(time_label);
            stderr.printf("🟡 CHATBUBBLEROW: Labels ajoutés à bubble_box\n");

            // Ajouter la bulle à la boîte principale
            this.append(bubble_box);
            stderr.printf("✅ CHATBUBBLEROW: Construction terminée - bubble_box ajouté au widget principal\n");
        }

        /**
         * Convertit les balises Markdown en markup Pango
         */
        private string convert_markdown_to_pango(string markdown_text) {
            if (markdown_text == null || markdown_text.length == 0) {
                return "";
            }
            
            string result = markdown_text;
            
            try {
                // Échapper d'abord les caractères spéciaux XML
                result = GLib.Markup.escape_text(result);
                
                // Titre 1 : # Texte -> <span size="x-large" weight="bold">Texte</span>
                var h1_regex = new Regex("^# (.+)$", RegexCompileFlags.MULTILINE);
                result = h1_regex.replace(result, -1, 0, "<span size=\"x-large\" weight=\"bold\">\\1</span>");
                
                // Titre 2 : ## Texte -> <span size="large" weight="bold">Texte</span>
                var h2_regex = new Regex("^## (.+)$", RegexCompileFlags.MULTILINE);
                result = h2_regex.replace(result, -1, 0, "<span size=\"large\" weight=\"bold\">\\1</span>");
                
                // Listes à puces AVANT italique : - element ou * element -> • element
                var bullet_regex1 = new Regex("^- (.+)$", RegexCompileFlags.MULTILINE);
                result = bullet_regex1.replace(result, -1, 0, "• \\1");
                var bullet_regex2 = new Regex("^\\* (.+)$", RegexCompileFlags.MULTILINE);
                result = bullet_regex2.replace(result, -1, 0, "• \\1");
                
                // Listes numérotées : 1. element -> 1. element (avec espacement)
                var numbered_regex = new Regex("^([0-9]+)\\. (.+)$", RegexCompileFlags.MULTILINE);
                result = numbered_regex.replace(result, -1, 0, "\\1. \\2");
                
                // Gras : **texte** ou __texte__ -> <b>texte</b>
                var bold_regex1 = new Regex("\\*\\*([^*]+)\\*\\*");
                result = bold_regex1.replace(result, -1, 0, "<b>\\1</b>");
                var bold_regex2 = new Regex("__([^_]+)__");
                result = bold_regex2.replace(result, -1, 0, "<b>\\1</b>");
                
                // Italique : *texte* ou _texte_ -> <i>texte</i> (après gras et listes pour éviter conflit)
                var italic_regex1 = new Regex("\\*([^*]+)\\*");
                result = italic_regex1.replace(result, -1, 0, "<i>\\1</i>");
                var italic_regex2 = new Regex("_([^_]+)_");
                result = italic_regex2.replace(result, -1, 0, "<i>\\1</i>");
                
            } catch (RegexError e) {
                stderr.printf("⚠️  CHATBUBBLEROW: Erreur regex lors de la conversion Markdown: %s\n", e.message);
                // En cas d'erreur, retourner le texte original échappé
                return GLib.Markup.escape_text(markdown_text);
            }
            
            return result;
        }

        /**
         * Met à jour le contenu affiché avec optimisations (debouncing pour streaming)
         */
        public void update_content() {
            stderr.printf("[TRACE][IN] CHATBUBBLEROW: update_content appelé\n");

            var current_time = get_monotonic_time();

            // Debouncing : éviter les mises à jour trop fréquentes (max 30 FPS = 33ms)
            if (current_time - last_update_time < 33000) {
                // Planifier une mise à jour différée si pas déjà planifiée
                if (!pending_update) {
                    pending_update = true;

                    // Annuler le timeout précédent s'il existe
                    if (update_timeout_id != 0) {
                        Source.remove(update_timeout_id);
                    }

                    // Planifier la mise à jour dans 33ms
                    update_timeout_id = Timeout.add(33, () => {
                        execute_content_update();
                        update_timeout_id = 0;
                        pending_update = false;
                        return Source.REMOVE;
                    });
                }
                return;
            }

            // Mise à jour immédiate si assez de temps s'est écoulé
            execute_content_update();
        }

        /**
         * Exécute réellement la mise à jour du contenu
         */
        private void execute_content_update() {
            if (content_label != null && message != null) {
                stderr.printf("[TRACE][IN] CHATBUBBLEROW: Mise à jour du contenu: '%s'\n",
                    message.content.length > 50 ? message.content.substring(0, 50) + "..." : message.content ?? "(vide)");

                // Convertir le contenu Markdown en markup Pango
                string formatted_content = convert_markdown_to_pango(message.content ?? "");
                stderr.printf("🎨 MARKDOWN UPDATE: '%s' -> '%s'\n", 
                    message.content ?? "(vide)", formatted_content);
                
                // Optimisation : éviter les appels set_markup inutiles
                if (content_label.get_text() != (message.content ?? "")) {
                    try {
                        content_label.set_markup(formatted_content);
                        last_update_time = get_monotonic_time();
                        stderr.printf("[TRACE][OUT] CHATBUBBLEROW: Contenu mis à jour avec markup\n");
                    } catch (GLib.MarkupError e) {
                        stderr.printf("⚠️  CHATBUBBLEROW: Erreur markup, utilisation du texte brut: %s\n", e.message);
                        content_label.set_text(message.content ?? "");
                    }
                }

                // Mettre à jour aussi les statistiques si disponibles
                if (time_label != null) {
                    time_label.set_text(message.get_formatted_stats());
                }

                stderr.printf("[TRACE][OUT] CHATBUBBLEROW: Contenu mis à jour avec succès\n");
            } else {
                stderr.printf("[TRACE][IN] CHATBUBBLEROW: ERREUR - content_label ou message est null\n");
            }
        }

        /**
         * Met à jour les statistiques de traitement affichées
         */
        public void update_processing_stats(int tokens, double duration) {
            if (message != null) {
                message.set_processing_stats(tokens, duration);
                if (time_label != null) {
                    time_label.set_text(message.get_formatted_stats());
                    stderr.printf("📊 CHATBUBBLEROW: Statistiques mises à jour: %d tokens, %.2fs\n", tokens, duration);
                }
            }
        }
    }
}
