/* CommunicationView.vala
 *
 * Copyright 2023
 */

using Gtk;

namespace Sambo {
    /**
     * Vue pour la zone de communication de l'application
     */
    public class CommunicationView : Gtk.Box {
        private ApplicationController controller;
        private Notebook notebook;
        private ChatView chat_view;
        private TerminalView terminal_view;
        private Box action_bar;
        private Label status_label;
        private Label execution_time_label;
        
        // Variables pour le chronomètre
        private int64 start_time = 0;
        private uint timer_source_id = 0;

        public CommunicationView(ApplicationController controller) {
            Object(orientation: Orientation.VERTICAL, spacing: 6);

            this.controller = controller;

            // Ajout d'un encadrement pour la visibilité
            var frame = new Frame(null);
            frame.set_margin_start(6);
            frame.set_margin_end(6);
            frame.set_margin_top(6);
            frame.set_margin_bottom(6);

            // Panneau interne pour le contenu de la zone de communication
            var content_box = new Box(Orientation.VERTICAL, 6);

            // Chargement du CSS personnalisé
            load_css();

            // Notebook pour les trois onglets de communication
            notebook = new Notebook();
            notebook.set_vexpand(true);

            // Onglet Chat IA avec notre nouveau widget de chat
            chat_view = new ChatView(controller);
            notebook.append_page(chat_view, new Label("Chat IA"));

            // Onglet Terminal avec notre nouveau widget de terminal
            terminal_view = new TerminalView(controller);
            notebook.append_page(terminal_view, new Label("Terminal"));

            // SUPPRESSION DU CODE REDONDANT DE L'ONGLET TERMINAL ICI

            // Onglet Macros
            var macro_box = new Box(Orientation.VERTICAL, 6);
            var macro_view = new TextView();
            macro_view.set_vexpand(true);

            var macro_scroll = new ScrolledWindow();
            macro_scroll.set_child(macro_view);
            macro_box.append(macro_scroll);

            var macro_actions_box = new Box(Orientation.HORIZONTAL, 6);
            macro_actions_box.append(new Button.with_label("Nouvelle macro"));
            macro_actions_box.append(new Button.with_label("Exécuter"));
            macro_actions_box.append(new Button.with_label("Enregistrer"));
            macro_box.append(macro_actions_box);

            notebook.append_page(macro_box, new Label("Macros"));

            // Connecter le signal de changement d'onglet avec gestion améliorée du focus
            notebook.switch_page.connect((page, page_num) => {
                print("Changement d'onglet vers %d\n", (int)page_num);

                // Retarder un peu la prise de focus pour s'assurer que l'onglet est bien activé
                Timeout.add(100, () => {
                    if (page_num == 0) { // Chat
                        print("Donner le focus à chat_view\n");
                        chat_view.grab_focus();
                    } else if (page_num == 1) { // Terminal
                        print("Donner le focus à terminal_view\n");
                        terminal_view.focus_entry();
                        // Vérifiez l'état de l'entrée
                        terminal_view.check_entry_state();
                    }
                    return Source.REMOVE;
                });
            });

            content_box.append(notebook);

            // Créer la barre d'actions moderne
            create_action_bar();
            content_box.append(action_bar);

            frame.set_child(content_box);
            this.append(frame);

            // Écouter les nouveaux messages du modèle
            controller.subscribe_to_messages((message) => {
                // Ajouter le message à la vue de chat
                var chat_message = new ChatMessage(message, ChatMessage.SenderType.AI);
                chat_view.add_message(chat_message);
            });
        }

        /**
         * Crée la barre d'actions moderne et élégante
         */
        private void create_action_bar() {
            action_bar = new Box(Orientation.HORIZONTAL, 12);
            action_bar.add_css_class("communication-action-bar");
            action_bar.set_margin_start(12);
            action_bar.set_margin_end(12);
            action_bar.set_margin_top(8);
            action_bar.set_margin_bottom(8);

            // Zone de statut à gauche
            status_label = new Label("Prêt pour l'édition");
            status_label.add_css_class("communication-status");
            status_label.set_halign(Align.START);
            status_label.set_hexpand(true);
            action_bar.append(status_label);

                        // Label pour afficher le temps d'exécution (8 caractères, à droite)
            execution_time_label = new Label("--:--");
            execution_time_label.add_css_class("execution-time");
            execution_time_label.set_visible(true);
            execution_time_label.set_size_request(60, -1); // Largeur fixe pour 8 caractères

            // Ajouter les styles CSS
            var css_provider = new CssProvider();
            try {
                css_provider.load_from_string("""
                    .communication-action-bar {
                        background: linear-gradient(to bottom,
                            alpha(@headerbar_bg_color, 0.95),
                            alpha(@headerbar_bg_color, 0.9));
                        border-top: 1px solid alpha(@borders, 0.5);
                        border-radius: 0 0 8px 8px;
                        box-shadow: inset 0 1px 0 alpha(@borders, 0.1);
                    }

                    .communication-status {
                        font-size: 0.9em;
                        color: alpha(@foreground_color, 0.7);
                        font-style: italic;
                    }

                    .execution-time {
                        font-size: 0.85em;
                        color: alpha(@foreground_color, 0.8);
                        font-family: monospace;
                        font-weight: 500;
                        background: alpha(@accent_color, 0.1);
                        padding: 2px 6px;
                        border-radius: 4px;
                        border: 1px solid alpha(@accent_color, 0.2);
                    }

                    .communication-action-bar button {
                        min-height: 32px;
                        padding: 4px 12px;
                        border-radius: 6px;
                    }

                    .communication-action-bar button.suggested-action {
                        background: linear-gradient(to bottom, @accent_color, shade(@accent_color, 0.9));
                        color: white;
                        font-weight: 600;
                    }

                    .communication-action-bar button.suggested-action:hover {
                        background: linear-gradient(to bottom, shade(@accent_color, 1.1), @accent_color);
                        box-shadow: 0 2px 4px alpha(@accent_color, 0.3);
                    }
                """);

                var display = Gdk.Display.get_default();
                Gtk.StyleContext.add_provider_for_display(display, css_provider,
                    Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
            } catch (Error e) {
                warning("Erreur lors du chargement du CSS pour action_bar: %s", e.message);
            }
        }

        /**
         * Met à jour le statut affiché dans la barre d'actions
         */
        private void update_status(string message, bool is_success = true) {
            status_label.set_text(message);
            if (is_success) {
                status_label.remove_css_class("error-status");
                status_label.add_css_class("success-status");
            } else {
                status_label.remove_css_class("success-status");
                status_label.add_css_class("error-status");
            }

            // Retirer le statut après 3 secondes
            Timeout.add_seconds(3, () => {
                status_label.set_text("Prêt pour l'édition");
                status_label.remove_css_class("success-status");
                status_label.remove_css_class("error-status");
                return false;
            });
        }

        /**
         * Charge le fichier CSS personnalisé pour les bulles et autres éléments d'interface
         */
        private void load_css() {
            var provider = new CssProvider();

            try {
                var display = Gdk.Display.get_default();
                var css_file = File.new_for_uri("resource:///com/cabineteto/Sambo/style.css");
                provider.load_from_file(css_file);

                Gtk.StyleContext.add_provider_for_display(display, provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
            } catch (Error e) {
                warning("Impossible de charger le CSS: %s", e.message);
            }
        }

        /**
         * Rafraîchit la sélection de profil dans le ChatView
         */
        public void refresh_profile_selection() {
            if (chat_view != null) {
                chat_view.refresh_profile_selection();
            }
        }

        /**
         * Démarre le chronomètre pour mesurer le temps d'exécution
         */
        public void start_execution_timer() {
            start_time = get_monotonic_time();
            execution_time_label.set_text("00:00.00");
            
            // Arrêter le timer précédent s'il existe
            if (timer_source_id != 0) {
                Source.remove(timer_source_id);
                timer_source_id = 0;
            }
            
            // Démarrer un nouveau timer qui se met à jour toutes les 10ms
            timer_source_id = Timeout.add(10, update_execution_timer);
        }

        /**
         * Arrête le chronomètre et affiche le temps final
         */
        public void stop_execution_timer() {
            if (timer_source_id != 0) {
                Source.remove(timer_source_id);
                timer_source_id = 0;
            }
            
            if (start_time > 0) {
                int64 elapsed_microseconds = get_monotonic_time() - start_time;
                string final_time = format_execution_time(elapsed_microseconds);
                execution_time_label.set_text(final_time);
                start_time = 0;
            }
        }

        /**
         * Remet à zéro le chronomètre
         */
        public void reset_execution_timer() {
            if (timer_source_id != 0) {
                Source.remove(timer_source_id);
                timer_source_id = 0;
            }
            start_time = 0;
            execution_time_label.set_text("00:00.00");
        }

        /**
         * Met à jour l'affichage du temps d'exécution
         */
        private bool update_execution_timer() {
            if (start_time > 0) {
                int64 elapsed_microseconds = get_monotonic_time() - start_time;
                string time_text = format_execution_time(elapsed_microseconds);
                execution_time_label.set_text(time_text);
                return true; // Continuer le timer
            }
            return false; // Arrêter le timer
        }

        /**
         * Formate le temps d'exécution en format MM:SS.CC (8 caractères)
         */
        private string format_execution_time(int64 microseconds) {
            double seconds = microseconds / 1000000.0;
            int minutes = (int)(seconds / 60);
            double remaining_seconds = seconds % 60.0;
            
            // Limiter à 99 minutes maximum pour tenir en 8 caractères
            if (minutes > 99) {
                return "99:59.99";
            }
            
            return "%02d:%05.2f".printf(minutes, remaining_seconds);
        }

        /**
         * Exécute une commande dans le terminal
         * Cette méthode n'est plus utilisée car nous utilisons maintenant TerminalView
         */
        private void execute_command(string command, TextView terminal_view) {
            // La méthode est conservée mais n'est plus utilisée
            // Vous pouvez la supprimer ou la déplacer dans la classe TerminalView
        }
    }
}
