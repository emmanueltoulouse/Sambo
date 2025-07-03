/* Application.vala
 *
 * Copyright 2023
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the            // Bon : le contrôleur lit la config AVANT la création de la fenêtre principale
            controller.init();
            main_window = new MainWindow(this, controller, controller.is_using_detached_explorer());U General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

using Gtk;
using Adw;

namespace Sambo {
    public class Application : Adw.Application {
        private MainWindow main_window;
        private ApplicationModel model;
        private ApplicationController controller;
        // Stockage direct de l'icône en tant que propriété de classe
        private Gdk.Texture? custom_icon = null;

        public Application() {
            Object(
                application_id: "com.cabineteto.Sambo",
                flags: ApplicationFlags.FLAGS_NONE
            );

            // Traces détaillées sur la résolution d'icône dash/barre
            var theme = Gtk.IconTheme.get_for_display(Gdk.Display.get_default());
            stdout.printf("[TRACE] Thème GTK courant: %s\n", theme.get_theme_name());
            string[] search_paths = theme.get_search_path();
            foreach (var p in search_paths) {
                stdout.printf("[TRACE] Chemin de recherche du thème: %s\n", p);
            }
            stdout.printf("[TRACE] Recherche de l'icône dash dans les chemins standards...\n");
            string[] icon_paths = {
                "./data/icons/hicolor/scalable/apps/com.cabineteto.Sambo.png",
                "/usr/share/icons/hicolor/scalable/apps/com.cabineteto.Sambo.png",
                "/usr/local/share/icons/hicolor/scalable/apps/com.cabineteto.Sambo.png",
                Environment.get_home_dir() + "/.local/share/icons/hicolor/scalable/apps/com.cabineteto.Sambo.png"
            };
            foreach (var path in icon_paths) {
                if (FileUtils.test(path, FileTest.EXISTS)) {
                    stdout.printf("[TRACE] Icône dash trouvée: %s\n", path);
                } else {
                    stdout.printf("[TRACE] Icône dash absente: %s\n", path);
                }
            }
            // Test de lookup effectif dans le thème GTK (GTK4)
            var info = theme.lookup_icon("com.cabineteto.Sambo", null, 64, 1, Gtk.TextDirection.NONE, 0);
            if (info != null) {
                stdout.printf("[TRACE] lookup_icon: trouvé dans le thème (type: %s)\n", info.get_type().name());
            } else {
                stdout.printf("[TRACE] lookup_icon: NON trouvé dans le thème\n");
            }

            // Vérifier s'il y a une icône personnalisée dans le home directory
            string home_icon = Path.build_filename(Environment.get_home_dir(), "com.cabineteto.Sambo.png");
            if (FileUtils.test(home_icon, FileTest.EXISTS)) {
                try {
                    custom_icon = Gdk.Texture.from_file(File.new_for_path(home_icon));
                    stdout.printf("[TRACE] Application: custom_icon chargée depuis %s\n", home_icon);
                } catch (Error e) {
                    stdout.printf("[TRACE] Application: Erreur chargement custom_icon: %s\n", e.message);
                }
            } else {
                stdout.printf("[TRACE] Application: custom_icon NON trouvée dans %s\n", home_icon);
            }

            // S'assurer que les ressources sont correctement initialisées
            ensure_resources();

            // Charger les styles CSS
            load_css();
        }

        /**
         * S'assure que les ressources de l'application sont correctement initialisées
         */
        private void ensure_resources() {
            // Implémentation réelle ou supprimer la méthode si inutile
            // Par exemple, initialiser des resources GResource
        }

        private void load_css() {
            try {
                var css_provider = new Gtk.CssProvider();
                css_provider.load_from_string("""
                    .rounded {
                        border-radius: 12px;
                    }

                    .tab-button {
                        padding: 6px 12px;
                        margin: 2px;
                        border-radius: 6px;
                    }

                    .tab-button:checked {
                        background-color: alpha(currentColor, 0.15);
                    }

                    /* Styles pour l'explorateur détaché */
                    .explorer-header {
                        font-weight: bold;
                    }

                    /* Autres styles existants... */
                """);

                // Appliquer le CSS
                Gtk.StyleContext.add_provider_for_display(
                    Gdk.Display.get_default(),
                    css_provider,
                    Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
                );

                print("Styles CSS chargés\n");
            } catch (Error e) {
                warning("Erreur lors du chargement du CSS: %s", e.message);
            }
        }

        protected override void activate() {
            // Initialise le contrôleur d'abord
            controller = new ApplicationController(null, this);

            // Initialise le modèle avec le contrôleur
            model = new ApplicationModel(controller);

            // Mettre à jour le contrôleur avec le modèle
            controller.set_model(model);

            // Charge la configuration depuis le fichier INI
            controller.load_configuration();

            // Bon : le contrôleur lit la config AVANT la création de la fenêtre principale
            controller.init();
            main_window = new MainWindow(this, controller, controller.is_using_detached_explorer());
            controller.set_main_window(main_window);

            // Si nous avons une icône personnalisée, l'appliquer à l'application
            if (custom_icon != null) {
                // Dans GTK4, on définit l'icône au niveau de l'application
                Gtk.IconTheme.get_for_display(Gdk.Display.get_default())
                    .add_resource_path("/com/cabineteto/Sambo/icons");
                // L'icône sera utilisée automatiquement par les fenêtres de l'application
            }

            // AJOUT: Appeler initialize pour charger les favoris, etc.
            controller.initialize();

            // Présenter la fenêtre principale
            main_window.present();

            // Appliquer le style éditeur dès le démarrage
            controller.apply_editor_style_from_preferences();

            // Appeler la connexion des signaux APRÈS que toutes les fenêtres
            // (y compris ExplorerWindow potentiellement créée dans init) soient prêtes.
            // Utiliser un court délai pour être sûr que tout est dessiné.
            Timeout.add(100, () => {
                controller.connect_explorer_signals();
                return false; // Exécuter une seule fois
            });
        }

        public static int main(string[] args) {
            Adw.init();
            var app = new Sambo.Application();
            return app.run(args);
        }
    }
}
