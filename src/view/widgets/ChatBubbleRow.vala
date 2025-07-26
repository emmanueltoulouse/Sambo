using Gtk;
using Adw;

namespace Sambo {
    /**
     * Widget représentant une bulle de message dans l'interface de chat
     */
    public class ChatBubbleRow : Gtk.Box {
        private TextView content_text_view;
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
            bubble_box.set_hexpand(true);  // Étendre horizontalement
            bubble_box.set_halign(Align.FILL);  // Remplir l'espace disponible

            // Créer un TextView sélectionnable pour le contenu du message
            content_text_view = new TextView();
            stderr.printf("🟡 CHATBUBBLEROW: content_text_view créé avec: '%s'\n", message.content ?? "(vide)");
            content_text_view.editable = false;  // En lecture seule
            content_text_view.cursor_visible = false;  // Pas de curseur
            content_text_view.wrap_mode = Gtk.WrapMode.WORD_CHAR;
            content_text_view.add_css_class("bubble-text");
            content_text_view.set_size_request(-1, -1);  // Ajustement automatique
            content_text_view.set_hexpand(true);  // Étendre horizontalement
            content_text_view.set_halign(Align.FILL);  // Remplir l'espace disponible

            // Obtenir le buffer pour définir le contenu
            var buffer = content_text_view.get_buffer();

            // Convertir le contenu Markdown et l'appliquer
            string formatted_content = convert_markdown_to_pango(message.content ?? "");
            stderr.printf("🎨 MARKDOWN: '%s' -> '%s'\n",
                message.content ?? "(vide)", formatted_content);

            try {
                buffer.create_tag("markdown", "wrap-mode", Pango.WrapMode.WORD_CHAR);

                // Pour l'instant, utiliser le texte brut - nous améliorerons le formatage plus tard
                buffer.set_text(message.content ?? "", -1);
            } catch (Error e) {
                warning("Erreur lors de la définition du contenu du TextView: %s", e.message);
                buffer.set_text(message.content ?? "", -1);
            }

            // Ajouter le menu contextuel personnalisé
            setup_context_menu();

            // Créer le libellé pour l'horodatage
            time_label = new Label(message.get_formatted_stats());
            stderr.printf("🟡 CHATBUBBLEROW: time_label créé\n");
            time_label.add_css_class("bubble-time");
            time_label.set_halign(is_user ? Align.END : Align.START);

            // Ajouter les widgets au conteneur de bulle
            bubble_box.append(content_text_view);
            bubble_box.append(time_label);
            stderr.printf("🟡 CHATBUBBLEROW: Widgets ajoutés à bubble_box\n");

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
         * Met à jour le contenu affiché avec optimisations et protection thread-safe
         */
        public void update_content() {
            stderr.printf("[TRACE][IN] CHATBUBBLEROW: update_content appelé\n");

            // Vérifications de base avant traitement
            if (this.is_floating()) {
                stderr.printf("[ERROR] CHATBUBBLEROW: Widget détaché du parent\n");
                return;
            }

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

                    // Planifier la mise à jour dans 33ms avec protection
                    update_timeout_id = Timeout.add(33, () => {
                        if (!this.is_floating()) {
                            execute_content_update();
                        } else {
                            stderr.printf("[WARNING] CHATBUBBLEROW: Widget détaché pendant le timeout\n");
                        }
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
         * Exécute réellement la mise à jour du contenu avec protection maximale
         */
        private void execute_content_update() {
            stderr.printf("[TRACE][IN] CHATBUBBLEROW: execute_content_update démarré\n");
            
            // Vérifications de sécurité critiques
            if (content_text_view == null) {
                stderr.printf("[ERROR] CHATBUBBLEROW: content_text_view est null\n");
                return;
            }
            
            if (message == null) {
                stderr.printf("[ERROR] CHATBUBBLEROW: message est null\n");
                return;
            }
            
            // Vérifier que le widget n'est pas détruit
            if (content_text_view.is_floating()) {
                stderr.printf("[ERROR] CHATBUBBLEROW: content_text_view est détaché du parent\n");
                return;
            }

            try {
                stderr.printf("[TRACE][IN] CHATBUBBLEROW: Mise à jour du contenu: '%s'\n",
                    message.content != null && message.content.length > 50 ? 
                    message.content.substring(0, 50) + "..." : message.content ?? "(vide)");

                // Obtenir le buffer du TextView avec protection
                var buffer = content_text_view.get_buffer();
                if (buffer == null) {
                    stderr.printf("[ERROR] CHATBUBBLEROW: buffer du TextView est null\n");
                    return;
                }

                // Protection contre les accès concurrents au buffer
                string new_content = message.content ?? "";
                
                // Vérifier si le buffer est valide avant de l'utiliser
                if (buffer.is_floating()) {
                    stderr.printf("[ERROR] CHATBUBBLEROW: buffer du TextView est détaché\n");
                    return;
                }

                // Optimisation : éviter les appels inutiles avec protection
                TextIter start, end;
                buffer.get_bounds(out start, out end);
                string current_text = buffer.get_text(start, end, false);

                if (current_text != new_content) {
                    // Mise à jour thread-safe du buffer
                    try {
                        buffer.set_text(new_content, -1);
                        last_update_time = get_monotonic_time();
                        stderr.printf("[TRACE][OUT] CHATBUBBLEROW: Contenu mis à jour dans TextView\n");
                    } catch (Error buffer_error) {
                        stderr.printf("[ERROR] CHATBUBBLEROW: Erreur mise à jour buffer: %s\n", buffer_error.message);
                        // Tentative de récupération avec contenu minimal
                        try {
                            buffer.set_text(new_content.length > 1000 ? new_content.substring(0, 1000) + "..." : new_content, -1);
                        } catch (Error recovery_error) {
                            stderr.printf("[ERROR] CHATBUBBLEROW: Échec récupération buffer: %s\n", recovery_error.message);
                        }
                    }
                } else {
                    stderr.printf("[TRACE] CHATBUBBLEROW: Contenu identique, pas de mise à jour nécessaire\n");
                }

                // Mettre à jour aussi les statistiques si disponibles (avec protection)
                if (time_label != null && !time_label.is_floating()) {
                    try {
                        string stats = message.get_formatted_stats();
                        time_label.set_text(stats);
                    } catch (Error stats_error) {
                        stderr.printf("[ERROR] CHATBUBBLEROW: Erreur mise à jour stats: %s\n", stats_error.message);
                    }
                }

                stderr.printf("[TRACE][OUT] CHATBUBBLEROW: Contenu mis à jour avec succès\n");
                
            } catch (Error global_error) {
                stderr.printf("[ERROR] CHATBUBBLEROW: Erreur critique dans execute_content_update: %s\n", global_error.message);
                // En cas d'erreur critique, désactiver les futures mises à jour
                content_text_view = null;
            }
        }

        /**
         * Configure le menu contextuel pour la sélection et la copie
         */
        private void setup_context_menu() {
            // Créer un contrôleur de geste pour le clic droit
            var right_click_gesture = new GestureClick();
            right_click_gesture.set_button(3); // Bouton droit de la souris

            right_click_gesture.pressed.connect((n_press, x, y) => {
                show_context_menu(x, y);
            });

            content_text_view.add_controller(right_click_gesture);
        }

        /**
         * Affiche le menu contextuel pour copier le texte sélectionné
         */
        private void show_context_menu(double x, double y) {
            var buffer = content_text_view.get_buffer();

            // Vérifier s'il y a du texte sélectionné
            TextIter start, end;
            bool has_selection = buffer.get_selection_bounds(out start, out end);

            // Créer le menu
            var menu = new GLib.Menu();

            if (has_selection) {
                // Si du texte est sélectionné, ajouter l'option "Copier la sélection"
                menu.append(_("Copier la sélection"), "bubble.copy-selection");
            }

            // Toujours ajouter l'option "Copier tout le message"
            menu.append(_("Copier tout le message"), "bubble.copy-all");

            // Créer et configurer le popover menu
            var popover = new PopoverMenu.from_model(menu);
            popover.set_parent(content_text_view);

            // Ajouter des classes CSS pour un style amélioré
            popover.add_css_class("context-menu-popover");

            // Positionner le menu à l'endroit du clic
            Gdk.Rectangle rect = {};
            rect.x = (int)x;
            rect.y = (int)y;
            rect.width = 1;
            rect.height = 1;
            popover.set_pointing_to(rect);

            // Configurer les actions
            setup_menu_actions();

            // Afficher le menu
            popover.popup();
        }

        /**
         * Configure les actions du menu contextuel
         */
        private void setup_menu_actions() {
            var action_group = new SimpleActionGroup();

            // Action pour copier la sélection
            var copy_selection_action = new SimpleAction("copy-selection", null);
            copy_selection_action.activate.connect(() => {
                copy_selected_text();
            });
            action_group.add_action(copy_selection_action);

            // Action pour copier tout le message
            var copy_all_action = new SimpleAction("copy-all", null);
            copy_all_action.activate.connect(() => {
                copy_all_text();
            });
            action_group.add_action(copy_all_action);

            // Ajouter le groupe d'actions au widget
            content_text_view.insert_action_group("bubble", action_group);
        }

        /**
         * Copie le texte sélectionné dans le presse-papiers
         */
        private void copy_selected_text() {
            var buffer = content_text_view.get_buffer();
            TextIter start, end;

            if (buffer.get_selection_bounds(out start, out end)) {
                string selected_text = buffer.get_text(start, end, false);

                var clipboard = Gdk.Display.get_default().get_clipboard();
                clipboard.set_text(selected_text);

                stderr.printf("📋 CHATBUBBLEROW: Texte sélectionné copié: '%s'\n", selected_text);
            }
        }

        /**
         * Copie tout le contenu du message dans le presse-papiers
         */
        private void copy_all_text() {
            var buffer = content_text_view.get_buffer();
            TextIter start, end;
            buffer.get_bounds(out start, out end);

            string all_text = buffer.get_text(start, end, false);

            var clipboard = Gdk.Display.get_default().get_clipboard();
            clipboard.set_text(all_text);

            stderr.printf("📋 CHATBUBBLEROW: Tout le message copié: '%s'\n", all_text);
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
