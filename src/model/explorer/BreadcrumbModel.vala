using GLib;
using Gee;

namespace Sambo {
    /**
     * Segment représentant une partie du chemin dans le fil d'Ariane
     */
    public class BreadcrumbSegment : Object {
        public string name { get; set; }       // Nom affiché pour ce segment
        public string path { get; set; }       // Chemin complet jusqu'à ce segment
        public GLib.Icon? icon { get; set; default = null; }  // Icône associée (optionnelle)

        /**
         * Crée un nouveau segment de fil d'Ariane
         *
         * @param name Le nom à afficher
         * @param path Le chemin complet
         * @param icon L'icône à afficher (optionnelle)
         */
        public BreadcrumbSegment(string name, string path, GLib.Icon? icon = null) {
            this.name = name;
            this.path = path;
            this.icon = icon;
        }
    }

    /**
     * Modèle représentant un fil d'Ariane pour la navigation dans les dossiers
     * Permet de générer et gérer les segments du chemin pour l'interface
     */
    public class BreadcrumbModel : Object {
        // Liste des segments de chemin
        private Gee.ArrayList<BreadcrumbSegment> segments;

        // Chemin courant complet
        public string current_path { get; private set; default = ""; }

        // Signal émis quand le chemin est modifié
        public signal void path_changed(string new_path);

        /**
         * Crée un nouveau modèle de fil d'Ariane
         *
         * @param initial_path Le chemin initial à représenter
         */
        public BreadcrumbModel(string initial_path = "") {
            segments = new Gee.ArrayList<BreadcrumbSegment>();

            if (initial_path != "") {
                set_path(initial_path);
            }
        }

        /**
         * Définit un nouveau chemin pour le fil d'Ariane
         *
         * @param path Le nouveau chemin complet
         */
        public void set_path(string path) {
            // Si c'est le même chemin, ne rien faire
            if (path == current_path) {
                return;
            }

            // Mettre à jour le chemin courant
            current_path = path;

            // Recréer les segments
            parse_path(path);

            // Émettre le signal de changement
            path_changed(path);
        }

        /**
         * Parse un chemin et crée les segments correspondants
         *
         * @param path Le chemin à parser
         */
        private void parse_path(string path) {
            // *** NOUVEAU : Conserver le chemin original ***
            string original_path = path;
            // *** FIN NOUVEAU ***

            segments.clear();

            // Cas spécial pour la racine (inchangé)
            if (path == "/" || path == "") {
                var icon = new ThemedIcon("drive-harddisk");
                segments.add(new BreadcrumbSegment("/", "/", icon));
                return;
            }

            // Ajouter le segment racine (inchangé)
            var root_icon = new ThemedIcon("drive-harddisk");
            segments.add(new BreadcrumbSegment("/", "/", root_icon));

            // Variable pour le chemin restant à traiter après le home
            string path_to_split = path;
            bool processed_home = false;

            // Cas spécial pour le home
            string home_path = Environment.get_home_dir();
            if (path.has_prefix(home_path)) {
                processed_home = true;
                // Ajouter le segment "Accueil" (inchangé)
                var home_icon = new ThemedIcon("user-home");
                segments.add(new BreadcrumbSegment("Accueil", home_path, home_icon));

                // Si c'est exactement le home, on s'arrête là (inchangé)
                if (path == home_path) {
                    return;
                }

                // Préparer le chemin restant pour le split
                string remaining_path = path.substring(home_path.length);
                if (remaining_path.has_prefix("/")) {
                    remaining_path = remaining_path.substring(1);
                }
                // *** MODIFIÉ : Utiliser une nouvelle variable pour le split ***
                path_to_split = remaining_path;
                // *** FIN MODIFIÉ ***
            }

            // Découper le chemin approprié (soit le chemin complet, soit ce qui reste après home)
            string[] parts = path_to_split.split("/");
            // *** MODIFIÉ : 'current' doit être basé sur le chemin absolu ou relatif initial ***
            // Si on a traité le home, le chemin relatif commence sans '/', sinon on regarde le chemin original
            string current = processed_home ? "" : (original_path.has_prefix("/") ? "/" : "");
            // *** FIN MODIFIÉ ***

            foreach (string part in parts) {
                if (part == "")
                    continue;

                // Construire le chemin cumulatif partiel (logique inchangée)
                if (current == "/") {
                    current = "/" + part;
                } else if (current == "") {
                    current = part;
                } else {
                    current = current + "/" + part;
                }

                // Construire le chemin absolu pour ce segment
                string absolute_path;
                // *** MODIFIÉ : Utiliser original_path pour vérifier ***
                bool original_path_was_absolute = original_path.has_prefix("/");
                // *** FIN MODIFIÉ ***

                if (original_path_was_absolute) {
                    // Si original absolu, 'current' représente la partie après la racine '/'
                    // Il faut reconstruire depuis la racine
                    absolute_path = "/" + current;
                } else if (processed_home) {
                    // Si on a traité le home, 'current' est relatif au home
                    absolute_path = Path.build_filename(home_path, current);
                } else {
                    // Cas rare: chemin relatif non basé sur home (ne devrait pas arriver avec navigate_to)
                    absolute_path = current; // Hypothèse: current est le chemin complet
                }


                // *** AJOUT LOGS ET VALIDATION (inchangé) ***
                string segment_name = part;
                string segment_path = absolute_path;

                if (!segment_name.validate()) {
                    warning("BreadcrumbModel: Nom de segment non UTF-8 détecté: '%s' (partie de '%s')", segment_name, original_path);
                }
                if (segment_path == null || segment_path == "") {
                     warning("BreadcrumbModel: Chemin absolu calculé vide pour segment '%s' (partie de '%s'). 'current' était '%s'. Original absolu: %s",
                             segment_name, original_path, current, original_path_was_absolute.to_string());
                }
                // *** FIN AJOUT ***


                // Ajouter un segment pour cette partie (inchangé)
                var folder_icon = new ThemedIcon("folder");
                segments.add(new BreadcrumbSegment(segment_name, segment_path, folder_icon));
            }
        }

        /**
         * Obtient tous les segments du fil d'Ariane
         *
         * @return La liste des segments
         */
        public Gee.ArrayList<BreadcrumbSegment> get_segments() {
            return segments;
        }

        /**
         * Obtient un segment spécifique du fil d'Ariane
         *
         * @param index L'index du segment (à partir de 0)
         * @return Le segment ou null si l'index est invalide
         */
        public BreadcrumbSegment? get_segment(int index) {
            if (index < 0 || index >= segments.size) {
                return null;
            }
            return segments.get(index);
        }

        /**
         * Obtient le nombre de segments dans le fil d'Ariane
         *
         * @return Le nombre de segments
         */
        public int get_segment_count() {
            return segments.size;
        }

        /**
         * Construit et retourne une représentation textuelle du fil d'Ariane
         *
         * @param separator Le séparateur à utiliser entre les segments
         * @return Une chaîne représentant le chemin
         */
        public string to_string(string separator = " > ") {
            if (segments.size == 0) {
                return "";
            }

            StringBuilder builder = new StringBuilder();
            bool first = true;

            foreach (var segment in segments) {
                if (!first) {
                    builder.append(separator);
                }
                builder.append(segment.name);
                first = false;
            }

            return builder.str;
        }

        /**
         * Crée un chemin relatif entre deux segments du fil d'Ariane
         *
         * @param from_index Index du segment de départ
         * @param to_index Index du segment d'arrivée
         * @return Le chemin relatif ou null si invalide
         */
        public string? create_relative_path(int from_index, int to_index) {
            if (from_index < 0 || from_index >= segments.size ||
                to_index < 0 || to_index >= segments.size) {
                return null;
            }

            // Si on va vers un segment parent, remonter avec "../"
            if (from_index > to_index) {
                int levels_up = from_index - to_index;
                StringBuilder builder = new StringBuilder();

                for (int i = 0; i < levels_up; i++) {
                    builder.append("../");
                }

                return builder.str;
            }

            // Sinon, construire le chemin avec les noms des segments intermédiaires
            StringBuilder path_builder = new StringBuilder();
            for (int i = from_index + 1; i <= to_index; i++) {
                if (segments.get(i) != null) {
                    path_builder.append(segments.get(i).name);

                    if (i < to_index) {
                        path_builder.append("/");
                    }
                }
            }

            return path_builder.str;
        }

        /**
         * Navigue vers un segment spécifique du fil d'Ariane
         * Cette méthode émet le signal path_changed avec le nouveau chemin
         *
         * @param segment_index Index du segment vers lequel naviguer
         */
        public void navigate_to_segment(int segment_index) {
            if (segment_index < 0 || segment_index >= segments.size) {
                return;
            }

            var segment = segments.get(segment_index);
            if (segment == null) {
                return;
            }

            // Mettre à jour le chemin et émettre le signal
            set_path(segment.path);
        }
    }
}
