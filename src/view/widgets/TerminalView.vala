/* TerminalView.vala
 *
 * Copyright 2023 Cabinet ETO
 */

using Gtk;
using Gdk;

namespace Sambo {
    /**
     * Widget pour l'interface terminal intégrée
     */
    public class TerminalView : Gtk.Box {
        private ApplicationController controller;
        private TextView terminal_view;
        private TextBuffer buffer;
        private string current_command = "";
        private int command_start_offset = 0;

        // Le prompt qui sera affiché
        private const string PROMPT = "sambo> ";

        /**
         * Crée une nouvelle vue de terminal
         */
        public TerminalView(ApplicationController controller) {
            Object(orientation: Orientation.VERTICAL, spacing: 0);

            this.controller = controller;

            // Ajouter la classe CSS
            this.add_css_class("terminal-view");

            // Terminal avec zone de texte éditable
            terminal_view = new TextView();
            terminal_view.set_monospace(true);
            terminal_view.set_wrap_mode(WrapMode.WORD_CHAR);
            terminal_view.set_vexpand(true);
            terminal_view.add_css_class("terminal-output");

            buffer = terminal_view.get_buffer();

            // Créer un style pour le texte du terminal
            var css_provider = new CssProvider();
            try {
                css_provider.load_from_string("""
                    textview.terminal {
                        background-color: #1e1e1e;
                        color: #f0f0f0;
                        font-family: monospace;
                        caret-color: #f0f0f0;
                    }
                    .prompt {
                        color: #4ec9b0;
                        font-weight: bold;
                    }
                    .input {
                        color: #f0f0f0;
                    }
                    .output {
                        color: #dcdcaa;
                    }
                    .error {
                        color: #f14c4c;
                    }
                """);

                terminal_view.add_css_class("terminal");
                var display = Display.get_default();
                if (display != null) {
                    StyleContext.add_provider_for_display(display, css_provider, STYLE_PROVIDER_PRIORITY_APPLICATION);
                }
            } catch (Error e) {
                warning("Erreur lors du chargement du CSS: %s", e.message);
            }

            var scroll = new ScrolledWindow();
            scroll.set_policy(PolicyType.AUTOMATIC, PolicyType.AUTOMATIC);
            scroll.set_child(terminal_view);
            this.append(scroll);

            // Configurer les événements clavier pour la saisie
            var key_controller = new Gtk.EventControllerKey();
            terminal_view.add_controller(key_controller);
            key_controller.key_pressed.connect(on_key_press);

            // S'assurer que le terminal est éditable, mais seulement après le prompt
            terminal_view.set_editable(true);
            terminal_view.set_cursor_visible(true);

            // Connecter au signal d'insertion de texte pour limiter l'édition
            buffer.insert_text.connect(on_insert_text);
            buffer.delete_range.connect(on_delete_range);

            // Connecter au signal changed pour détecter les changements de texte
            buffer.changed.connect(on_buffer_changed);

            // Afficher le message d'accueil
            print_welcome_message();

            // S'abonner au signal d'exécution de commande
            controller.subscribe_to_terminal_commands(on_command_executed);

            // Donner le focus au terminal
            this.realize.connect(() => {
                terminal_view.grab_focus();
                set_cursor_to_end();
            });
        }

        /**
         * Place le curseur à la fin du buffer
         */
        private void set_cursor_to_end() {
            TextIter end;
            buffer.get_end_iter(out end);
            buffer.place_cursor(end);

            // Amélioration du défilement pour s'assurer qu'il fonctionne toujours
            terminal_view.scroll_to_iter(end, 0.0, true, 0.0, 1.0);

            // Défilement supplémentaire via un timeout pour garantir que l'interface est mise à jour
            Timeout.add(50, () => {
                var adj = terminal_view.get_vadjustment();
                if (adj != null) {
                    adj.set_value(adj.get_upper() - adj.get_page_size());

                    // Deuxième essai après une courte attente
                    Timeout.add(100, () => {
                        adj.set_value(adj.get_upper());
                        return false;
                    });
                }
                return false;
            });
        }

        /**
         * Affiche le message d'accueil du terminal
         */
        private void print_welcome_message() {
            TextIter end_iter;
            buffer.get_end_iter(out end_iter);

            buffer.insert_markup(ref end_iter,
                "<span foreground='#4ec9b0'>Sambo Terminal v0.1.0</span>\n" +
                "<span foreground='#dcdcaa'>Tapez 'help' pour voir les commandes disponibles.</span>\n\n", -1);

            show_prompt();
        }

        /**
         * Affiche le prompt et configure le début de la commande
         */
        private void show_prompt() {
            TextIter end_iter;
            buffer.get_end_iter(out end_iter);

            buffer.insert_markup(ref end_iter, "<span foreground='#4ec9b0'>" + PROMPT + "</span>", -1);

            // Mémoriser la position de début de commande
            buffer.get_end_iter(out end_iter);
            command_start_offset = end_iter.get_offset();

            // Réinitialiser la commande courante
            current_command = "";

            // Placer le curseur à la fin
            set_cursor_to_end();
        }

        /**
         * Gère les événements clavier pour contrôler la saisie
         */
        private bool on_key_press(Gtk.EventControllerKey controller, uint keyval, uint keycode, Gdk.ModifierType state) {
            // Gérer la touche Entrée pour exécuter la commande
            if (keyval == Gdk.Key.Return || keyval == Gdk.Key.KP_Enter) {
                TextIter start, end;
                buffer.get_iter_at_offset(out start, command_start_offset);
                buffer.get_end_iter(out end);

                string command = buffer.get_text(start, end, false);
                current_command = command;

                // Ajouter un saut de ligne
                buffer.insert(ref end, "\n", 1);

                // Exécuter la commande
                execute_command(command);

                return true;
            }

            return false;
        }

        /**
         * Filtre l'insertion de texte pour ne permettre que la saisie après le prompt
         */
        private void on_insert_text(TextIter location, string text, int len) {
            // Bloquer l'insertion si c'est avant la position de début de commande
            if (location.get_offset() < command_start_offset) {
                GLib.Signal.stop_emission_by_name(buffer, "insert-text");

                // Insérer le texte à la fin à la place
                TextIter end;
                buffer.get_end_iter(out end);
                buffer.insert(ref end, text, len);
            }
        }

        /**
         * Filtre la suppression de texte pour empêcher la suppression du prompt
         */
        private void on_delete_range(TextIter start, TextIter end) {
            // Si on essaie de supprimer avant le début de commande, bloquer
            if (start.get_offset() < command_start_offset) {
                GLib.Signal.stop_emission_by_name(buffer, "delete-range");
            }
        }

        /**
         * Détecte les changements dans le buffer et met à jour la commande courante
         */
        private void on_buffer_changed() {
            TextIter start, end;
            buffer.get_iter_at_offset(out start, command_start_offset);
            buffer.get_end_iter(out end);

            current_command = buffer.get_text(start, end, false);
        }

        /**
         * Affiche la réponse et défile automatiquement vers le bas
         */
        private void display_response_and_scroll(string response) {
            TextIter end;
            buffer.get_end_iter(out end);
            buffer.insert_markup(ref end, "<span foreground='#dcdcaa'>" + response + "</span>\n", -1);

            // Afficher le prompt pour une nouvelle commande
            show_prompt();

            // Défiler vers le bas de façon robuste
            scroll_to_bottom();
        }

        /**
         * S'assure que le terminal défile jusqu'en bas
         */
        private void scroll_to_bottom() {
            // Défiler immédiatement une première fois
            TextIter end;
            buffer.get_end_iter(out end);
            terminal_view.scroll_to_iter(end, 0.0, true, 0.0, 1.0);

            // Puis utiliser plusieurs déferlements avec délais croissants
            int[] delays = { 10, 50, 150, 300 };

            foreach (int delay in delays) {
                Timeout.add(delay, () => {
                    TextIter end_iter;
                    buffer.get_end_iter(out end_iter);
                    terminal_view.scroll_to_iter(end_iter, 0.0, true, 0.0, 1.0);

                    var adj = terminal_view.get_vadjustment();
                    if (adj != null) {
                        adj.set_value(adj.get_upper());
                    }
                    return false;
                });
            }
        }

        /**
         * Exécute une commande entrée dans le terminal
         */
        private void execute_command(string command) {
            if (command == "")
                return;

            string response = "";

            // Commandes simples pour tester
            switch (command) {
                case "hello":
                    response = "Hello World!";
                    break;

                case "help":
                    response = "Commandes disponibles:\n" +
                              "  hello   - Affiche Hello World\n" +
                              "  help    - Affiche cette aide\n" +
                              "  clear   - Efface le terminal\n" +
                              "  date    - Affiche la date et l'heure actuelles\n" +
                              "  version - Affiche la version de l'application";
                    break;

                case "clear":
                    buffer.set_text("", -1);
                    show_prompt();
                    scroll_to_bottom();
                    return;

                case "date":
                    var now = new DateTime.now_local();
                    response = now.format("%c");
                    break;

                case "version":
                    response = "Sambo v0.1.0";
                    break;

                default:
                    response = "Commande inconnue: " + command;
                    break;
            }

            // Utiliser la nouvelle méthode pour afficher la réponse et défiler
            display_response_and_scroll(response);
        }

        /**
         * Appelée quand une commande est exécutée via le contrôleur
         */
        private void on_command_executed(string command, string output) {
            if (output == "CLEAR_TERMINAL") {
                buffer.set_text("", -1);
                print_welcome_message();
                scroll_to_bottom();
                return;
            }

            // Afficher la commande
            TextIter end;
            buffer.get_end_iter(out end);
            buffer.insert(ref end, command + "\n", -1);

            // Afficher le résultat
            if (output != "") {
                buffer.get_end_iter(out end);
                buffer.insert_markup(ref end, "<span foreground='#dcdcaa'>" + output + "</span>\n", -1);
            }

            // Afficher un nouveau prompt
            show_prompt();

            // Utiliser notre méthode robuste de défilement
            scroll_to_bottom();
        }

        /**
         * Méthode publique pour donner le focus au terminal
         */
        public void focus_entry() {
            terminal_view.grab_focus();
            set_cursor_to_end();
        }

        /**
         * Vérifie l'état d'édition du terminal
         */
        public bool check_entry_state() {
            bool can_focus = terminal_view.get_can_focus();
            bool is_editable = terminal_view.get_editable();

                  return can_focus && is_editable;
        }
    }
}
