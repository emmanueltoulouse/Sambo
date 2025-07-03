/* BreadcrumbWidget.vala
 *
 * Copyright 2023
 */

using Gtk;
using Gdk;

namespace Sambo {
    /**
     * Widget pour afficher et gérer le fil d'Ariane dans l'explorateur de fichiers
     */
    public class BreadcrumbWidget : Gtk.Box {
        private Gtk.Box breadcrumb_container;
        private BreadcrumbModel breadcrumb_model;
        private ApplicationController controller;

        // Signal émis lorsqu'un segment est sélectionné
        public signal void path_selected(string path);

        /**
         * Crée un nouveau widget de fil d'Ariane
         */
        public BreadcrumbWidget(ApplicationController controller) {
            Object(orientation: Orientation.HORIZONTAL, spacing: 0);

            this.controller = controller;
            this.breadcrumb_model = new BreadcrumbModel();

            // Configurer le conteneur principal
            breadcrumb_container = new Box(Orientation.HORIZONTAL, 2);
            breadcrumb_container.add_css_class("breadcrumb-container");
            breadcrumb_container.set_margin_start(6);
            breadcrumb_container.set_margin_end(6);
            breadcrumb_container.set_margin_top(6);
            breadcrumb_container.set_margin_bottom(6);

            // Appliquer le style spécifique du fil d'Ariane
            breadcrumb_container.add_css_class("green-breadcrumb");

            // Ajouter le conteneur au widget
            this.append(breadcrumb_container);

            // Connecter le signal de changement de chemin
            breadcrumb_model.path_changed.connect((path) => {
                path_selected(path);
            });
        }

        /**
         * Met à jour le fil d'Ariane avec un nouveau chemin
         */
        public void set_path(string path) {
            breadcrumb_model.set_path(path);
            update_ui();
        }

        /**
         * Obtient le chemin actuel du fil d'Ariane
         */
        public string get_path() {
            return breadcrumb_model.current_path;
        }

        /**
         * Met à jour l'interface utilisateur avec les segments actuels
         */
        private void update_ui() {
            // Vider le contenu existant
            var child = breadcrumb_container.get_first_child();
            while (child != null) {
                var next = child.get_next_sibling();
                breadcrumb_container.remove(child);
                child = next;
            }

            // Ajouter les segments
            var segments = breadcrumb_model.get_segments();

            for (int i = 0; i < segments.size; i++) {
                var segment = segments.get(i);

                // *** SIMPLIFICATION POUR TEST ***
                // Vérifier l'encodage/contenu du nom
                // Créer un bouton simple avec juste le label
                var button = new Button.with_label(segment.name);
                button.add_css_class("breadcrumb-button");
                button.set_tooltip_text(segment.path);
                // *** FIN SIMPLIFICATION ***

                // Marquer le dernier segment comme courant
                if (i == segments.size - 1) {
                    button.add_css_class("breadcrumb-current");
                    // Optionnel: Rendre le dernier segment non cliquable pour éviter re-navigation inutile
                    // button.set_sensitive(false);
                }

                // Capturer l'index pour le callback
                int idx = i;
                button.clicked.connect(() => {
                    if (breadcrumb_model != null) {
                         breadcrumb_model.navigate_to_segment(idx);
                    } else {
                    }
                });

                breadcrumb_container.append(button);

                // Ajouter un séparateur sauf pour le dernier élément
                if (i < segments.size - 1) {
                    var separator = new Label("›"); // Séparateur UTF-8
                    separator.add_css_class("breadcrumb-separator");
                    breadcrumb_container.append(separator);
                }
            }
        }
    }
}
