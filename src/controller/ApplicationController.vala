using Sambo.Document;

namespace Sambo {
    public class ApplicationController : Object {
        // Signal for message notification
        public signal void message_received(string message);

        // Signal pour notifier les commandes de terminal
        public signal void terminal_command_signal(string command, string output);

        private ApplicationModel? model;
        private Gtk.Application application;
        private ExplorerWindow? explorer_window = null;
        private MainWindow? main_window = null;
        private bool use_detached_explorer = false;
        private ExplorerView? active_explorer_view = null;

        public ApplicationController(ApplicationModel? model, Gtk.Application application) {
            this.model = model;
            this.application = application;
        }

        public void set_model(ApplicationModel model) {
            this.model = model;
        }

        public void load_configuration() {
            model.config_manager.load();
        }

        public void save_configuration() {
            model.config_manager.save();
        }

        /**
         * Subscribe to receive messages from the controller
         * @param callback Function to call when a new message is received
         */
        public void subscribe_to_messages(owned MessageCallback callback) {
            message_received.connect((msg) => callback(msg));
        }

        /**
         * S'abonne aux commandes du terminal
         * @param callback Fonction à appeler quand une commande est exécutée
         */
        public void subscribe_to_terminal_commands(owned TerminalCommandCallback callback) {
            terminal_command_signal.connect((cmd, output) => callback(cmd, output));
        }

        /**
         * Exécute une commande dans le terminal
         * @param command La commande à exécuter
         */
        public void execute_terminal_command(string command) {
            // Déléguer au modèle
            model.communication.execute_terminal_command(command);
        }

        /**
         * Rafraîchit la vue de l'explorateur
         */
        public void refresh_explorer() {
            // Émettre un signal que les vues peuvent écouter
            explorer_view_changed();
        }

        /**
         * Signal émis lorsque la vue de l'explorateur doit être mise à jour
         */
        public signal void explorer_view_changed();

        /**
         * S'abonner aux changements de la vue explorateur
         * @param callback Fonction à appeler quand la vue change
         */
        public void subscribe_to_explorer_changes(owned ExplorerViewCallback callback) {
            explorer_view_changed.connect(() => callback());
        }

        // Define the delegate type for message callbacks
        public delegate void MessageCallback(string message);

        // Type de délégué pour les callbacks de commandes terminal
        public delegate void TerminalCommandCallback(string command, string output);

        /**
         * Type de délégué pour les callbacks de changement de l'explorateur
         */
        public delegate void ExplorerViewCallback();

        /**
         * Sauvegarde les favoris dans le fichier de configuration
         * @return true si la sauvegarde a réussi, false sinon
         */
        public bool save_favorites() {
            try {
                // Obtenir le dossier de configuration de l'application
                string config_dir = Environment.get_user_config_dir() + "/sambo";

                // Créer le dossier si nécessaire
                if (!FileUtils.test(config_dir, FileTest.EXISTS)) {
                    if (DirUtils.create_with_parents(config_dir, 0755) == -1) {
                        throw new FileError.FAILED("Impossible de créer le dossier de configuration");
                    }
                }

                // Vérifier que le dossier est accessible en écriture
                if (!FileUtils.test(config_dir, FileTest.IS_DIR) ||
                    !FileUtils.test(config_dir, FileTest.IS_EXECUTABLE)) {
                    throw new FileError.PERM("Le dossier de configuration n'est pas accessible en écriture");
                }

                // Sauvegarder les favoris
                string favorites_file = Path.build_filename(config_dir, "favorites.txt");
                if (!model.explorer.save_favorites_to_file(favorites_file)) {
                    throw new FileError.FAILED("Échec de la sauvegarde des favoris");
                }

                return true;
            } catch (Error e) {
                warning("Erreur lors de la sauvegarde des favoris: %s", e.message);
                // On pourrait ici émettre un signal ou afficher une notification pour informer l'utilisateur
                return false;
            }
        }

        /**
         * Charge les favoris depuis le fichier de configuration
         * @return true si le chargement a réussi, false sinon
         */
        public bool load_favorites() {
            try {
                // Obtenir le chemin du fichier de favoris
                string favorites_file = Path.build_filename(
                    Environment.get_user_config_dir(),
                    "sambo",
                    "favorites.txt"
                );

                // Charger les favoris s'ils existent
                if (FileUtils.test(favorites_file, FileTest.EXISTS)) {
                    if (!model.explorer.load_favorites_from_file(favorites_file)) {
                        throw new FileError.FAILED("Échec du chargement des favoris");
                    }
                    return true;
                }
                return false; // Fichier inexistant, mais pas d'erreur
            } catch (Error e) {
                warning("Erreur lors du chargement des favoris: %s", e.message);
                return false;
            }
        }

        /**
         * Connecter les signaux pour la gestion des favoris
         */
        private void connect_favorites_signals() {
            // Rafraîchir la vue des favoris quand on change d'onglet
            model.explorer.file_selected_for_edit.connect(() => {
                save_favorites();

                // Rafraîchir la vue des favoris si elle existe
                var main_window = get_main_window();
                if (main_window != null) {
                    var explorer_view = main_window.get_explorer_view();
                    if (explorer_view != null) {
                        // Émettre le signal pour rafraîchir l'explorateur
                        explorer_view_changed();
                    }
                }
            });
        }

        /**
         * Obtient la fenêtre principale de l'application
         * @return La fenêtre principale ou null
         */
        public MainWindow? get_main_window() {
            unowned List<Gtk.Window> windows = application.get_windows();
            foreach (var window in windows) {
                if (window is MainWindow) {
                    return window as MainWindow;
                }
            }
            return null;
        }

        /**
         * Initialise l'application
         */
        public void initialize() {
            // Charger les favoris depuis le fichier de configuration
            load_favorites();

            // Connecter les signaux pour la gestion des favoris
            connect_favorites_signals();
        }

        /**
         * Finaliser avant la fermeture de l'application
         */
        public void finalize_app() {
            // Sauvegarder les favoris
            save_favorites();

            // Sauvegarder les emplacements récents
            model.explorer.save_to_config(get_config_manager());

            // Sauvegarder l'état des extensions filtrées depuis la vue active
            var active_view = use_detached_explorer ?
                 explorer_window?.get_explorer_view() :
                 main_window?.get_explorer_view();
             if (active_view != null) {
                 // Call save_selected_extensions with no arguments as per its signature
                 active_view.save_selected_extensions();
             }

            // S'assurer que toutes les modifications de config sont écrites
            get_config_manager().save();
        }

        /**
         * Obtient le gestionnaire de configuration
         * @return Le gestionnaire de configuration
         */
        public ConfigManager get_config_manager() {
            return model.config_manager;
        }

        // Modifier la méthode d'initialisation
        public void init() {
            var config_manager = get_config_manager();
            // Utiliser la clé standardisée "Display", "use_detached_explorer"
            bool config_value = config_manager.get_boolean("Display", "use_detached_explorer", false);
            use_detached_explorer = config_value;

            // NE PAS créer la fenêtre principale ici, elle est déjà créée dans Application.vala
            // main_window = new MainWindow(application, this);  <-- SUPPRIMER CETTE LIGNE

            // Si le mode détaché est activé, créer la fenêtre d'explorateur séparée
            if (use_detached_explorer) {
                if (explorer_window == null) { // Évite recréation
                     explorer_window = new ExplorerWindow(application as Adw.Application, this);
                     // Ne pas appeler present() ici, laisser restore_window_state décider
                }
            }

            // NE PAS présenter la fenêtre principale ici, c'est déjà fait dans Application.vala
            // main_window.present();  <-- SUPPRIMER CETTE LIGNE

            // Configuration de la barre d'outils
            var toolbar = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
            toolbar.add_css_class("toolbar");
            toolbar.add_css_class("view");
            toolbar.set_margin_top(6);
            toolbar.set_margin_start(12);
            toolbar.set_margin_end(12);
            toolbar.set_margin_bottom(6);

            // Boutons de navigation
            var back_button = new Gtk.Button.from_icon_name("go-previous-symbolic");
            back_button.add_css_class("flat");
            back_button.set_tooltip_text(_("Précédent"));
            back_button.clicked.connect(() => {
                model.explorer.go_back();
            });

            var forward_button = new Gtk.Button.from_icon_name("go-next-symbolic");
            forward_button.add_css_class("flat");
            forward_button.set_tooltip_text(_("Suivant"));
            forward_button.clicked.connect(() => {
                model.explorer.go_forward();
            });

            var up_button = new Gtk.Button.from_icon_name("go-up-symbolic");
            up_button.add_css_class("flat");
            up_button.set_tooltip_text(_("Dossier parent"));
            up_button.clicked.connect(() => {
                model.explorer.navigate_to_parent();
            });

            // Bouton pour actualiser
            var refresh_button = new Gtk.Button.from_icon_name("view-refresh-symbolic");
            refresh_button.add_css_class("flat");
            refresh_button.set_tooltip_text(_("Actualiser"));
            refresh_button.clicked.connect(() => {
                model.explorer.refresh();
            });

            // Ajouter les boutons à la barre d'outils
            toolbar.append(back_button);
            toolbar.append(forward_button);
            toolbar.append(up_button);
            toolbar.append(refresh_button);

            // Ajouter la barre d'outils à l'interface
            if (main_window != null) {
                // Access the header bar directly if it's accessible
                var header_bar = main_window.get_header_bar();
                if (header_bar != null) {
                    header_bar.pack_start(toolbar);
                } else {
                    warning("Could not access header bar in main window");
                }
            }
        }

        /**
         * Méthode centrale pour afficher/masquer l'explorateur approprié.
         * Appelée par le bouton de MainWindow.
         */
        public void toggle_explorer_visibility(bool show) {

            if (use_detached_explorer) {
                // --- Mode Détaché ---

                // NE PAS TOUCHER À L'EXPLORATEUR INTÉGRÉ
                if (explorer_window == null) {
                    // Si la fenêtre n'existe pas (cas initial ou après fermeture), la recréer
                    if (show) {
                        explorer_window = new ExplorerWindow(application as Adw.Application, this);
                        this.active_explorer_view = explorer_window.get_explorer_view();
                        connect_explorer_signals(); // Reconnecter les signaux à la nouvelle vue
                        explorer_window.present();
                    }
                } else {
                    // La fenêtre existe, on l'affiche ou la masque
                    if (show) {
                        explorer_window.present();
                    } else {
                        explorer_window.hide(); // Utiliser hide() pour pouvoir la réafficher
                    }
                }
                // Mettre à jour l'état du bouton dans MainWindow
                main_window?.update_explorer_button_state(show);
            } else {
                // --- Mode Intégré ---
                // Demander à MainWindow de gérer son explorateur interne
                main_window?.set_integrated_explorer_visible(show);
                // L'état du bouton est géré directement dans set_integrated_explorer_visible
            }

            // Sauvegarder l'état souhaité (affiché/masqué)
            get_config_manager().set_boolean("Window", "show_explorer", show);
            get_config_manager().save();
        }

        /**
         * Connecte les signaux de l'explorateur ACTIF.
         * Doit être appelée après l'initialisation des fenêtres ET après un changement de mode.
         */
        public void connect_explorer_signals() {

            // D'abord, déterminer quelle est la vue active
            if (use_detached_explorer) {
                this.active_explorer_view = explorer_window?.get_explorer_view();
            } else {
                this.active_explorer_view = main_window?.get_explorer_view();
            }

            // Vérifications de sécurité robustes avant connexion
            if (active_explorer_view != null) {
                try {
                    active_explorer_view.file_selected.connect(on_file_selected_pivot);
                } catch (Error e) {
                    warning("Controller: Erreur lors de la connexion de file_selected: %s", e.message);
                }

                // Connecter aussi directory_changed si nécessaire pour synchroniser
                try {
                    active_explorer_view.directory_changed.connect((path) => {
                         // Mettre à jour le modèle ou d'autres vues si besoin
                         var model = ApplicationControllerExtension.get_explorer_model(this);
                         var current_dir = model.get_current_directory();
                         string? current_path = current_dir != null ? current_dir.get_path() : null;
                         if(current_path != path) {
                             model.navigate_to(path); // Assure la synchro si l'autre vue existe encore par erreur
                         }
                    });
                } catch (Error e) {
                    warning("Controller: Erreur lors de la connexion de directory_changed: %s", e.message);
                }

            } else {
                warning("Controller: Impossible de connecter les signaux, active_explorer_view est null.");
            }
        }

        // Méthode dédiée pour le signal file_selected (logique pivot)
        private void on_file_selected_pivot(string path) {
             try {
                 var converter_manager = DocumentConverterManager.get_instance();
                 PivotDocument? pivot_document = converter_manager.open_file_as_pivot(path);
                 if (pivot_document != null) {
                 } else {
                 }

                 // Check main_window first, then attempt to get editor_view (temporarily using controller's placeholder)
                 if (main_window != null) {
                     main_window.open_document_in_tab(pivot_document, path);
                 } else {
                     warning("DEBUG PIVOT: EditorView non disponible (main_window est null dans le contrôleur)!\n");
                 }
             } catch (Error e) {
                 warning("DEBUG PIVOT: ERREUR - %s\n", e.message);
             }
        }

        /**
         * Point d'entrée public pour demander l'ouverture d'un fichier via la logique pivot.
         * Appelé par exemple par le dialogue d'ouverture de fichier de MainWindow.
         */
        public void handle_file_open_request(string path) {
            // Appelle la méthode privée qui contient la logique pivot
            on_file_selected_pivot(path);
        }

        // Méthode pour que Application.vala puisse définir la référence à MainWindow
        public void set_main_window(MainWindow window) {
            this.main_window = window;
        }

        // Ajouter cette méthode pour savoir si on est en mode détaché
        public bool is_using_detached_explorer() {
            return use_detached_explorer;
        }

        // Ajouter cette méthode pour obtenir la fenêtre de l'explorateur détaché
        public ExplorerWindow? get_explorer_window() {
            return explorer_window;
        }

        /**
         * Définit si l'explorateur doit être utilisé en mode détaché
         * et sauvegarde ce paramètre dans la configuration
         */
        public void set_detached_explorer(bool value) {
            if (use_detached_explorer != value) {
                use_detached_explorer = value;
                // Sauvegarder avec la clé standardisée "Display", "use_detached_explorer"
                get_config_manager().set_boolean("Display", "use_detached_explorer", value);
                get_config_manager().save();
            }
        }

        /**
         * Applique le style éditeur (police, taille, couleur) à tous les onglets ouverts selon les préférences
         */
        public void apply_editor_style_from_preferences() {
            var config = get_config_manager();
            string font_family = config.get_string("Editor", "font_family", "Sans");
            int font_size = config.get_integer("Editor", "font_size", 12);
            string font_color = config.get_string("Editor", "font_color", "#222222");
            var main_win = get_main_window();
            if (main_win != null) {
                main_win.apply_editor_style_to_all_tabs(font_size, font_family, font_color);
            }
        }
    }
}
