namespace Sambo {
    /**
     * Modèle représentant un onglet dans l'explorateur de fichiers
     * Gère l'état d'un onglet, son historique de navigation et ses propriétés
     */
    public class ExplorerTabModel : Object {
        // Le titre de l'onglet
        public string title { get; set; default = ""; }

        // Indique si l'onglet est épinglé
        public bool is_pinned { get; set; default = false; }

        // Chemin actuel affiché dans l'onglet
        public string current_path { get; set; default = ""; }

        // Mode d'affichage actuel géré avec un setter notifiant le changement
        private ViewMode _view_mode = ViewMode.LIST;
        public ViewMode view_mode {
            get { return _view_mode; }
            set {
                if (_view_mode != value) {
                    _view_mode = value;
                    // Vous pouvez soit émettre ici un signal personnalisé,
                    // soit utiliser notify pour déclencher une réaction dans l'UI.
                    notify_property("view_mode");
                    view_mode_changed(value);
                }
            }
        }

        // Historique de navigation (chemins visités)
        private Gee.ArrayList<string> history;

        // Position actuelle dans l'historique (pour la navigation avant/arrière)
        private int history_position = -1;

        // Filtre de recherche actuel
        public string search_filter { get; set; default = ""; }

        // Propriété pour la visibilité de la prévisualisation
        public bool show_preview { get; set; default = true; }

        // Signal émis lorsque le mode d'affichage change
        public signal void view_mode_changed(ViewMode new_mode);

        // Propriétés pour le mode comparaison
        public bool comparison_mode_active { get; set; default = false; }
        public string comparison_path { get; set; default = ""; }

        // Signal émis lorsque le mode comparaison change
        public signal void comparison_mode_changed(bool active, string comparison_path);

        // Signal émis lorsque l'onglet est épinglé/désépinglé
        public signal void pin_state_changed(bool is_pinned);

        // Ajouter signal manquant pour les erreurs
        public signal void error_occurred(string message, string? details = null);

        // Ajouter un identifiant unique pour l'onglet
        private string _id;

        /**
         * Crée un nouvel onglet avec un chemin et un titre initial
         *
         * @param path Chemin initial
         * @param title Titre de l'onglet (si null, le nom du dossier sera utilisé)
         */
        public ExplorerTabModel(string path, string? title = null) {
            this.current_path = path;
            this._id = "tab_" + Random.next_int().to_string(); // Générer un ID unique

            // Si aucun titre n'est fourni, utiliser le nom du dossier
            if (title == null) {
                File file = File.new_for_path(path);
                this.title = file.get_basename();
            } else {
                this.title = title;
            }

            // Initialiser l'historique
            history = new Gee.ArrayList<string>();
            add_to_history(path);
        }

        /**
         * Ajoute un chemin à l'historique de navigation
         *
         * @param path Le chemin à ajouter
         */
        public void add_to_history(string path) {
            // Si nous ne sommes pas à la fin de l'historique, tronquer l'historique
            if (history_position < history.size - 1) {
                // Supprimer tous les éléments après la position actuelle
                while (history.size > history_position + 1) {
                    history.remove_at(history.size - 1);
                }
            }

            // Ajouter le nouveau chemin
            history.add(path);
            history_position = history.size - 1;
        }

        /**
         * Navigue vers un chemin spécifique
         *
         * @param path Le chemin vers lequel naviguer
         */
        public void navigate_to(string path) {
            // Mettre à jour le chemin actuel
            current_path = path;

            // Ajouter à l'historique seulement si différent du dernier
            if (history.size == 0 || history.get(history.size - 1) != path) {
                add_to_history(path);
            }
        }

        /**
         * Vérifie si la navigation en arrière est possible
         *
         * @return true si on peut naviguer en arrière, false sinon
         */
        public bool can_go_back() {
            return history_position > 0;
        }

        /**
         * Vérifie si la navigation en avant est possible
         *
         * @return true si on peut naviguer en avant, false sinon
         */
        public bool can_go_forward() {
            return history_position < history.size - 1;
        }

        /**
         * Navigue en arrière dans l'historique
         *
         * @return Le chemin vers lequel on a navigué, ou null si impossible
         */
        public string? go_back() {
            if (!can_go_back()) {
                return null;
            }

            history_position--;
            string path = history.get(history_position);
            current_path = path;

            return path;
        }

        /**
         * Navigue en avant dans l'historique
         *
         * @return Le chemin vers lequel on a navigué, ou null si impossible
         */
        public string? go_forward() {
            if (!can_go_forward()) {
                return null;
            }

            history_position++;
            string path = history.get(history_position);
            current_path = path;

            return path;
        }

        /**
         * Récupère tout l'historique de navigation de l'onglet
         *
         * @return La liste des chemins visités
         */
        public Gee.ArrayList<string> get_history() {
            return history;
        }

        /**
         * Efface l'historique de navigation
         */
        public void clear_history() {
            string current = current_path;
            history.clear();

            // Garder seulement le chemin courant
            history.add(current);
            history_position = 0;
        }

        /**
         * Récupère la position actuelle dans l'historique
         */
        public int get_history_position() {
            return history_position;
        }

        /**
         * Obtient l'icône correspondant au mode d'affichage actuel
         *
         * @return Le nom de l'icône symbolique
         */
        public string get_view_mode_icon() {
            switch (view_mode) {
                case ViewMode.LIST:
                    return "view-list-symbolic";
                case ViewMode.ICONS:
                    return "view-grid-symbolic";
                case ViewMode.COMPACT:
                    return "view-paged-symbolic";
                default:
                    return "view-list-symbolic";
            }
        }

        /**
         * Vérifie si un chemin est présent dans l'historique
         *
         * @param path Le chemin à vérifier
         * @return true si le chemin est dans l'historique, false sinon
         */
        public bool is_in_history(string path) {
            foreach (string history_path in history) {
                if (history_path == path) {
                    return true;
                }
            }
            return false;
        }

        /**
         * Se déplace à une position spécifique de l'historique
         *
         * @param position La position cible dans l'historique
         * @return Le chemin à cette position ou null si la position est invalide
         */
        public string? go_to_history_position(int position) {
            if (position < 0 || position >= history.size) {
                return null;
            }

            history_position = position;
            string path = history.get(position);
            current_path = path;

            return path;
        }

        /**
         * Supprime les doublons de l'historique
         * Garde uniquement la dernière occurrence de chaque chemin
         */
        public void deduplicate_history() {
            var new_history = new Gee.ArrayList<string>();
            var path_set = new Gee.HashSet<string>();

            // Parcourir l'historique en sens inverse pour ne garder que les dernières occurrences
            for (int i = history.size - 1; i >= 0; i--) {
                string path = history.get(i);
                if (!path_set.contains(path)) {
                    // Insérer au début pour maintenir l'ordre chronologique
                    new_history.insert(0, path);
                    path_set.add(path);
                }
            }

            // Mettre à jour l'historique et la position
            history = new_history;
            history_position = history.size - 1;
        }

        /**
         * Limite la taille de l'historique au nombre spécifié
         * Supprime les entrées les plus anciennes
         *
         * @param max_size Nombre maximum d'éléments dans l'historique
         */
        public void trim_history(int max_size = 50) {
            if (history.size <= max_size) {
                return;
            }

            // Calculer combien d'éléments supprimer
            int to_remove = history.size - max_size;

            // Supprimer les éléments les plus anciens
            for (int i = 0; i < to_remove; i++) {
                history.remove_at(0);
            }

            // Ajuster la position si nécessaire
            history_position = int.max(0, history_position - to_remove);
        }

        /**
         * Sauvegarde les paramètres spécifiques à l'onglet
         * @param config_manager Le gestionnaire de configuration
         * @param tab_id L'identifiant unique de l'onglet
         */
        public void save_to_config(ConfigManager config_manager, string tab_id) {
            // Sauvegarder la préférence de prévisualisation
            config_manager.set_boolean("ExplorerTab_" + tab_id, "show_preview", show_preview);

            // Sauvegarder l'état du mode comparaison
            config_manager.set_boolean("ExplorerTab_" + tab_id, "comparison_mode_active", comparison_mode_active);
            config_manager.set_string("ExplorerTab_" + tab_id, "comparison_path", comparison_path);
        }

        /**
         * Charge les paramètres spécifiques à l'onglet
         * @param config_manager Le gestionnaire de configuration
         * @param tab_id L'identifiant unique de l'onglet
         */
        public void load_from_config(ConfigManager config_manager, string tab_id) {
            // Charger la préférence de prévisualisation
            show_preview = config_manager.get_boolean("ExplorerTab_" + tab_id, "show_preview", true);

            // Charger l'état du mode comparaison
            comparison_mode_active = config_manager.get_boolean("ExplorerTab_" + tab_id, "comparison_mode_active", false);
            comparison_path = config_manager.get_string("ExplorerTab_" + tab_id, "comparison_path", "");
        }

        /**
         * Active ou désactive le mode comparaison
         *
         * @param active Si true, active le mode comparaison
         * @param path Le chemin du dossier à comparer (ignoré si active est false)
         */
        public void set_comparison_mode(bool active, string? path = null) {
            if (active && path != null) {
                comparison_mode_active = true;
                comparison_path = path;
            } else {
                comparison_mode_active = false;
                comparison_path = "";
            }

            // Émettre le signal pour informer la vue
            comparison_mode_changed(comparison_mode_active, comparison_path);
        }

        /**
         * Épingle ou désépingle l'onglet
         *
         * @param pinned Si true, épingle l'onglet, sinon le désépingle
         */
        public void set_pinned(bool pinned) {
            if (is_pinned != pinned) {
                is_pinned = pinned;
                pin_state_changed(is_pinned);
            }
        }

        /**
         * Bascule l'état épinglé de l'onglet
         *
         * @return Le nouvel état d'épinglage
         */
        public bool toggle_pinned() {
            is_pinned = !is_pinned;
            pin_state_changed(is_pinned);
            return is_pinned;
        }

        // Ajouter méthode pour obtenir le nom d'affichage
        public string get_display_name() {
            return title;
        }

        // Ajouter méthode pour obtenir l'identifiant
        public string get_id() {
            return _id;
        }

        // Ajouter méthode pour signaler une erreur
        public void report_error(string message, string? details = null) {
            error_occurred(message, details);
        }
    }
}
