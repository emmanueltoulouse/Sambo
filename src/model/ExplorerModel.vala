using Gee;

namespace Sambo {
    /**
     * Modèle principal pour l'explorateur de fichiers
     * Gère les chemins par défaut, les favoris et l'interaction avec le système de fichiers
     */
    public class ExplorerModel : Object {
        // Singleton instance
        private static ExplorerModel? _explorer_model = null;

        // Remplacer le singleton par l'injection de dépendances
        private Gee.List<ExplorerTabModel> tabs;
        private BookmarksManager bookmarks_manager;
        private HistoryManager history_manager;
        private SearchService search_service;
        private IconCache icon_cache;
        private ApplicationController controller;

        // Chemins par défaut
        private string documents_path;
        private string files_path;

        // Variables manquantes
        private Gee.ArrayList<string> favorites = new Gee.ArrayList<string>();
        private Gee.ArrayList<string> recent_locations = new Gee.ArrayList<string>();
        private BreadcrumbModel active_breadcrumb = new BreadcrumbModel();
        private string selected_file_path = "";

        // Cache pour les répertoires
        private HashTable<string, Gee.ArrayList<FileItemModel>> directory_cache =
            new HashTable<string, Gee.ArrayList<FileItemModel>>(str_hash, str_equal);
        private GLib.Queue<string> cache_keys = new GLib.Queue<string>();

        // Nombre maximum d'emplacements récents à conserver
        private const int MAX_RECENT_LOCATIONS = 10;
        private const int MAX_CACHE_ENTRIES = 20;

        // Option pour le fil d'Ariane
        private bool _breadcrumb_enabled = true;
        public bool breadcrumb_enabled {
            get { return _breadcrumb_enabled; }
            set {
                if (_breadcrumb_enabled != value) {
                    _breadcrumb_enabled = value;
                    // Notifier les observateurs du changement
                    breadcrumb_enabled_changed(_breadcrumb_enabled);
                    notify_property("breadcrumb-enabled"); // Notifier aussi via GObject
                }
            }
        }

        // Signal émis lorsque l'état du fil d'Ariane change
        public signal void breadcrumb_enabled_changed(bool enabled);

        // *** NOUVEAU : Propriété et signal pour les fichiers cachés ***
        private bool _show_hidden_files = false;
        public bool show_hidden_files {
            get { return _show_hidden_files; }
            set {
                if (_show_hidden_files != value) {
                    _show_hidden_files = value;
                    show_hidden_files_changed(_show_hidden_files);
                    notify_property("show-hidden-files");
                }
            }
        }
        // Signal émis lorsque l'état d'affichage des fichiers cachés change
        public signal void show_hidden_files_changed(bool show);
        // *** FIN NOUVEAU ***

        // *** NOUVEAU : Propriété et signal pour la barre de recherche ***
        private bool _search_bar_enabled = true; // Visible par défaut
        public bool search_bar_enabled {
            get { return _search_bar_enabled; }
            set {
                if (_search_bar_enabled != value) {
                    _search_bar_enabled = value;
                    search_bar_enabled_changed(_search_bar_enabled);
                    notify_property("search-bar-enabled");
                }
            }
        }
        // Signal émis lorsque l'état d'affichage de la barre de recherche change
        public signal void search_bar_enabled_changed(bool enabled);
        // *** FIN NOUVEAU ***

        // Signaux
        public signal void tab_added(ExplorerTabModel tab);
        public signal void tab_removed(ExplorerTabModel tab);
        public signal void active_tab_changed(ExplorerTabModel? tab);
        public signal void file_selected_for_edit(FileItemModel file);
        public signal void file_selected(string path);

        private ExplorerTabModel? _active_tab = null;
        private int active_tab_index = 0;

        public ExplorerTabModel? active_tab {
            get { return _active_tab; }
            set {
                if (_active_tab != value) {
                    _active_tab = value;
                    active_tab_changed(_active_tab);
                }
            }
        }

        private bool _initializing = false;

        public ExplorerModel(ApplicationController controller) {
            _initializing = true;

            this.controller = controller;
            tabs = new Gee.ArrayList<ExplorerTabModel>();
            bookmarks_manager = BookmarksManager.get_instance();
            history_manager = HistoryManager.get_instance();
            search_service = SearchService.get_instance();
            icon_cache = IconCache.get_instance();

            // Initialiser les chemins par défaut
            documents_path = Path.build_filename(Environment.get_home_dir(), "Documents");
            files_path = Environment.get_home_dir();

            // S'abonner aux changements des favoris et de l'historique
            bookmarks_manager.bookmarks_changed.connect(() => {
                update_bookmarks();
            });

            history_manager.history_changed.connect(() => {
                update_history();
            });

            // Configurer la surveillance des signets GNOME
            bookmarks_manager.setup_gnome_monitor();

            _initializing = false;
        }

        public bool is_initializing() {
            return _initializing;
        }

        public ApplicationController get_controller() {
            return controller;
        }

        public ExplorerTabModel create_tab(File? initial_location = null) {
            var location = initial_location ?? File.new_for_path(Environment.get_home_dir());
            var tab = new ExplorerTabModel(location.get_path());

            tabs.add(tab);
            tab_added(tab);

            if (tabs.size == 1) {
                active_tab = tab;
            }

            return tab;
        }

        public void close_tab(ExplorerTabModel tab) {
            int index = tabs.index_of(tab);

            if (index >= 0) {
                tabs.remove_at(index);
                tab_removed(tab);

                // Définir un nouvel onglet actif si nécessaire
                if (_active_tab == tab) {
                    if (tabs.size > 0) {
                        int new_index = int.min(index, tabs.size - 1);
                        active_tab = tabs[new_index];
                    } else {
                        active_tab = null;
                    }
                }
            }
        }

        public Gee.List<ExplorerTabModel> get_tabs() {
            return tabs;
        }

        public void add_to_bookmarks(File file) {
            bookmarks_manager.add_bookmark(file);
        }

        public void remove_from_bookmarks(File file) {
            bookmarks_manager.remove_bookmark(file);
        }

        public bool is_bookmarked(File file) {
            return bookmarks_manager.is_bookmarked(file);
        }

        public Gee.List<File> get_bookmarks() {
            return bookmarks_manager.get_all_bookmarks();
        }

        public void update_bookmarks() {
            bookmarks_manager.refresh_bookmarks();
        }

        public void add_to_history(File file) {
            history_manager.add_to_history(file);
        }

        public Gee.List<File> get_history() {
            return history_manager.get_history();
        }

        public void update_history() {
            history_manager.refresh_history();
        }

        public void search_files(File directory, string search_term, bool recursive = true) {
            search_service.search_in_directory(directory, search_term, recursive);
        }

        public Icon get_icon_for_file(File file) {
            return icon_cache.get_icon_for_file(file);
        }

        public void clear_icon_cache() {
            icon_cache.clear_cache();
        }

        /**
         * Initialise les onglets par défaut (Documents et Fichiers)
         * Cette méthode est désormais publique pour permettre la réinitialisation des onglets
         */
        public void init_default_tabs() {
            // Créer l'onglet "Documents"
            var documents_tab = new ExplorerTabModel(documents_path, "Documents");
            documents_tab.is_pinned = true;  // Épingler l'onglet Documents par défaut
            tabs.add(documents_tab);

            // Créer l'onglet "Fichiers"
            var files_tab = new ExplorerTabModel(files_path, "Fichiers");
            tabs.add(files_tab);

            // Définir l'onglet "Documents" comme actif par défaut
            active_tab_index = 0;
            active_tab = tabs.get(active_tab_index);

            // Mettre à jour le fil d'Ariane pour refléter le chemin de l'onglet actif
            if (active_tab != null) {
                active_breadcrumb.set_path(active_tab.current_path);
            }
        }

        /**
         * Définit l'onglet actif
         * @param index L'index de l'onglet à activer
         * @return true si l'onglet a été activé avec succès, false sinon
         */
        public bool set_active_tab_by_index(int index) {
            if (index < 0 || index >= tabs.size) {
                return false;
            }

            active_tab_index = index;
            active_tab = tabs.get(index);

            // Mettre à jour le fil d'Ariane pour refléter le chemin de l'onglet actif
            if (active_tab != null) {
                active_breadcrumb.set_path(active_tab.current_path);
            }

            return true;
        }

        /**
         * Obtient l'onglet actuellement actif
         * @return Le modèle de l'onglet actif, ou null si aucun onglet n'existe
         */
        public ExplorerTabModel? get_active_tab_by_index() {
            if (tabs.size == 0 || active_tab_index >= tabs.size) {
                return null;
            }

            return tabs.get(active_tab_index);
        }

        /**
         * Retourne le modèle du fil d'Ariane pour l'onglet actif
         * @return Le modèle du fil d'Ariane
         */
        public BreadcrumbModel get_active_breadcrumb() {
            return active_breadcrumb;
        }

        /**
         * Navigue vers un nouveau chemin dans l'onglet actif
         * @param path Le chemin vers lequel naviguer
         * @return true si la navigation a réussi, false sinon
         */
        public bool navigate_to(string path) {
            // Vérifier si le chemin existe
            var file = File.new_for_path(path);
            if (!file.query_exists()) {
                warning("Le chemin n'existe pas: %s", path);
                return false;
            }

            try {
                var file_info = file.query_info(FileAttribute.STANDARD_TYPE, FileQueryInfoFlags.NONE);

                // Si c'est un fichier, naviguer vers son répertoire parent et sélectionner le fichier
                if (file_info.get_file_type() == FileType.REGULAR) {
                    var parent = file.get_parent();
                    if (parent != null) {
                        // Naviguer vers le dossier parent
                        navigate_to_directory(parent.get_path());

                        // Sélectionner le fichier dans la vue (via signal ou autre méthode)
                        selected_file_path = path;
                        file_selected(path);

                        return true;
                    }
                } else if (file_info.get_file_type() == FileType.DIRECTORY) {
                    // C'est un répertoire, naviguer normalement
                    return navigate_to_directory(path);
                }
            } catch (Error e) {
                warning("Erreur lors de la vérification du type de fichier: %s", e.message);
            }

            return false;
        }

        // Ajouter cette méthode privée pour gérer la navigation vers les répertoires
        private bool navigate_to_directory(string path) {
            var tab = get_active_tab_by_index();
            if (tab == null) {
                return false;
            }

            // Vérifier si le chemin existe et est accessible
            if (!FileUtils.test(path, FileTest.EXISTS) || !FileUtils.test(path, FileTest.IS_DIR)) {
                warning("Le chemin n'existe pas ou n'est pas un répertoire: %s", path);
                return false;
            }

            // Mettre à jour le chemin de l'onglet
            tab.navigate_to(path);

            // Mettre à jour le fil d'Ariane
            active_breadcrumb.set_path(path);

            // Ajouter aux emplacements récents
            add_to_recent_locations(path);

            return true;
        }

        /**
         * Navigue en arrière dans l'historique de l'onglet actif
         * @return true si la navigation a réussi, false sinon
         */
        public bool go_back() {
            var tab = get_active_tab_by_index();
            if (tab == null || !tab.can_go_back()) {
                return false;
            }

            string? path = tab.go_back();
            if (path == null) {
                return false;
            }

            // Mettre à jour le fil d'Ariane
            active_breadcrumb.set_path(path);

            return true;
        }

        /**
         * Navigue en avant dans l'historique de l'onglet actif
         * @return true si la navigation a réussi, false sinon
         */
        public bool go_forward() {
            var tab = get_active_tab_by_index();
            if (tab == null || !tab.can_go_forward()) {
                return false;
            }

            string? path = tab.go_forward();
            if (path == null) {
                return false;
            }

            // Mettre à jour le fil d'Ariane
            active_breadcrumb.set_path(path);

            return true;
        }

        public bool can_go_back() {
            var tab = get_active_tab_by_index();
            return tab != null && tab.can_go_back();
        }

        public bool can_go_forward() {
            var tab = get_active_tab_by_index();
            return tab != null && tab.can_go_forward();
        }

        /**
         * Sélectionne un fichier pour l'édition
         * @param file Le fichier à ouvrir dans l'éditeur
         */
        public void select_file_for_edit(FileItemModel file) {
            // Si c'est un dossier, naviguer dedans au lieu de l'ouvrir
            if (file.is_directory()) {
                navigate_to(file.path);
                return;
            }

            // Émettre le signal que le fichier a été sélectionné pour l'édition
            file_selected_for_edit(file);
        }

        /**
         * Charge les paramètres depuis le gestionnaire de configuration
         * @param config_manager Le gestionnaire de configuration
         */
        public void load_from_config(ConfigManager config_manager) {
            documents_path = config_manager.get_string("Explorer", "documents_path", documents_path);
            files_path = config_manager.get_string("Explorer", "files_path", files_path);

            // Charger l'état du fil d'Ariane
            breadcrumb_enabled = config_manager.get_boolean("Explorer", "breadcrumb_enabled", true);

            // *** NOUVEAU : Charger l'état des fichiers cachés ***
            // Utiliser le setter pour déclencher la notification si nécessaire au démarrage
            this.show_hidden_files = config_manager.get_boolean("Explorer", "show_hidden_files", false);
            // *** FIN NOUVEAU ***

            // Charger les signets GNOME
            bookmarks_manager.setup_gnome_monitor();

            // *** NOUVEAU : Charger l'état de la barre de recherche ***
            this.search_bar_enabled = config_manager.get_boolean("Explorer", "search_bar_enabled", true);
            // *** FIN NOUVEAU ***

            // Charger les favoris
            string favorites_str = config_manager.get_string("Explorer", "favorites", "");
            if (favorites_str != "") {
                string[] favs = favorites_str.split(";");
                favorites.clear();
                foreach (string fav in favs) {
                    if (fav != "") {
                        favorites.add(fav);
                    }
                }
            }

            // Charger les emplacements récents
            string recents_str = config_manager.get_string("Explorer", "recent_locations", "");
            if (recents_str != "") {
                string[] recs = recents_str.split(";");
                recent_locations.clear();
                foreach (string rec in recs) {
                    if (rec != "") {
                        recent_locations.add(rec);
                    }
                }
            }

            // Recréer les onglets par défaut avec les chemins mis à jour
            tabs.clear();
            init_default_tabs();
        }

        /**
         * Sauvegarde les paramètres dans le gestionnaire de configuration
         * @param config_manager Le gestionnaire de configuration
         */
        public void save_to_config(ConfigManager config_manager) {
            config_manager.set_string("Explorer", "documents_path", documents_path);
            config_manager.set_string("Explorer", "files_path", files_path);

            // Sauvegarder les favoris
            string favorites_str = "";
            foreach (string fav in favorites) {
                favorites_str += fav + ";";
            }
            config_manager.set_string("Explorer", "favorites", favorites_str);

            // Sauvegarder les emplacements récents
            string recents_str = "";
            foreach (string rec in recent_locations) {
                recents_str += rec + ";";
            }
            config_manager.set_string("Explorer", "recent_locations", recents_str);

            // Sauvegarder l'état du fil d'Ariane
            config_manager.set_boolean("Explorer", "breadcrumb_enabled", breadcrumb_enabled);

            // *** NOUVEAU : Sauvegarder l'état des fichiers cachés ***
            config_manager.set_boolean("Explorer", "show_hidden_files", show_hidden_files);
            // *** FIN NOUVEAU ***

            // *** NOUVEAU : Sauvegarder l'état de la barre de recherche ***
            config_manager.set_boolean("Explorer", "search_bar_enabled", search_bar_enabled);
            // *** FIN NOUVEAU ***
        }

        /**
         * Ajoute un nouvel onglet au modèle
         * @param tab Le modèle d'onglet à ajouter
         */
        public void add_tab(ExplorerTabModel tab) {
            tabs.add(tab);
            tab_added(tab);
        }

        /**
         * Supprime un onglet du modèle
         * @param tab Le modèle d'onglet à supprimer
         */
        public void remove_tab(ExplorerTabModel tab) {
            int index = tabs.index_of(tab);
            if (index >= 0) {
                tabs.remove_at(index);
                tab_removed(tab);
            }
        }

        /**
         * Ajoute un emplacement aux favoris
         * @param path Le chemin à ajouter aux favoris
         */
        public void add_to_favorites(string path) {
            if (!favorites.contains(path)) {
                favorites.add(path);
            }
        }

        /**
         * Supprime un emplacement des favoris
         * @param path Le chemin à supprimer des favoris
         */
        public void remove_from_favorites(string path) {
            favorites.remove(path);
        }

        /**
         * Vérifie si un chemin est dans les favoris
         * @param path Le chemin à vérifier
         * @return true si le chemin est dans les favoris, false sinon
         */
        public bool is_favorite(string path) {
            return favorites.contains(path);
        }

        /**
         * Vérifie si un chemin est dans les favoris et le bascule (ajoute ou supprime)
         * @param path Le chemin à basculer dans les favoris
         * @return true si le chemin a été ajouté aux favoris, false s'il a été supprimé
         */
        public bool toggle_favorite(string path) {
            if (favorites.contains(path)) {
                remove_from_favorites(path);
                return false;
            } else {
                add_to_favorites(path);
                return true;
            }
        }

        /**
         * Charge les favoris à partir d'un fichier externe
         * @param file_path Chemin du fichier contenant les favoris
         * @return true si le chargement a réussi, false sinon
         */
        public bool load_favorites_from_file(string file_path) {
            try {
                if (!FileUtils.test(file_path, FileTest.EXISTS)) {
                    return false;
                }

                string content;
                FileUtils.get_contents(file_path, out content);

                string[] lines = content.split("\n");
                favorites.clear();

                foreach (string line in lines) {
                    string trimmed = line.strip();
                    if (trimmed != "" && FileUtils.test(trimmed, FileTest.EXISTS)) {
                        favorites.add(trimmed);
                    }
                }

                return true;
            } catch (Error e) {
                warning("Erreur lors du chargement des favoris: %s", e.message);
                return false;
            }
        }

        /**
         * Sauvegarde les favoris dans un fichier externe
         * @param file_path Chemin du fichier où sauvegarder les favoris
         * @return true si la sauvegarde a réussi, false sinon
         */
        public bool save_favorites_to_file(string file_path) {
            try {
                StringBuilder builder = new StringBuilder();

                foreach (string fav in favorites) {
                    builder.append(fav);
                    builder.append("\n");
                }

                FileUtils.set_contents(file_path, builder.str);
                return true;
            } catch (Error e) {
                warning("Erreur lors de la sauvegarde des favoris: %s", e.message);
                return false;
            }
        }

        /**
         * Récupère la liste des favoris
         * @return La liste des chemins favoris
         */
        public Gee.ArrayList<string> get_favorites() {
            return favorites;
        }

        /**
         * Obtient les favoris triés par nom
         * @return Une liste des favoris triés par nom
         */
        public Gee.ArrayList<FileItemModel> get_favorites_as_file_items() {
            var items = new Gee.ArrayList<FileItemModel>();

            foreach (string path in favorites) {
                try {
                    var file_item = new FileItemModel.from_path(path);
                    items.add(file_item);
                } catch (Error e) {
                    warning("Erreur lors de la création du FileItemModel pour %s: %s", path, e.message);
                }
            }

            // Trier par nom
            items.sort((a, b) => a.name.collate(b.name));

            return items;
        }

        /**
         * Ajoute un emplacement aux emplacements récents
         * @param path Le chemin à ajouter aux emplacements récents
         */
        public void add_to_recent_locations(string path) {
            // Supprimer si déjà présent pour le mettre en haut de la liste
            recent_locations.remove(path);

            // Ajouter en première position
            recent_locations.insert(0, path);

            // Limiter à MAX_RECENT_LOCATIONS
            while (recent_locations.size > MAX_RECENT_LOCATIONS) {
                recent_locations.remove_at(recent_locations.size - 1);
            }
        }

        /**
         * Récupère la liste des emplacements récents
         * @return La liste des emplacements récents
         */
        public Gee.ArrayList<string> get_recent_locations() {
            return recent_locations;
        }

        /**
         * Obtient les emplacements récents sous forme de modèles de fichiers
         * @return Une liste des emplacements récents convertis en FileItemModel
         */
        public Gee.ArrayList<FileItemModel> get_recent_locations_as_file_items() {
            var items = new Gee.ArrayList<FileItemModel>();

            foreach (string path in recent_locations) {
                try {
                    var file_item = new FileItemModel.from_path(path);
                    items.add(file_item);
                } catch (Error e) {
                    warning("Erreur lors de la création du FileItemModel pour %s: %s", path, e.message);
                }
            }

            return items;
        }

        /**
         * Récupère le contenu d'un répertoire avec cache
         * @param path Le chemin du répertoire
         * @return La liste des éléments du répertoire
         */
        public Gee.ArrayList<FileItemModel> get_directory_content(string path) {
            // Vérifier si le contenu est déjà dans le cache
            var cached_items = directory_cache.get(path);
            if (cached_items != null) {
                // Mettre à jour les emplacements récents quand même
                add_to_recent_locations(path);
                return cached_items;
            }

            // Si pas dans le cache, charger normalement
            var items = new Gee.ArrayList<FileItemModel>();

            try {
                var directory = File.new_for_path(path);
                var enumerator = directory.enumerate_children(
                    "standard::*,time::modified,unix::mode",
                    FileQueryInfoFlags.NONE
                );

                FileInfo info;
                while ((info = enumerator.next_file()) != null) {
                    var file_path = Path.build_filename(path, info.get_name());
                    if (file_matches_filters(info.get_name())) {
                        var item = new FileItemModel.from_file_info(file_path, info);
                        items.add(item);
                    }
                }

                // Trier: d'abord les dossiers, puis les fichiers, par ordre alphabétique
                items.sort((a, b) => {
                    if (a.is_directory() && !b.is_directory())
                        return -1;
                    if (!a.is_directory() && b.is_directory())
                        return 1;
                    return a.name.collate(b.name);
                });

                // Ajouter aux emplacements récents
                add_to_recent_locations(path);

                // Mettre en cache le résultat
                add_to_cache(path, items);

            } catch (Error e) {
                warning("Erreur lors de la lecture du répertoire %s: %s", path, e.message);
            }

            return items;
        }

        /**
         * Ajoute des éléments au cache
         * @param path Chemin du répertoire
         * @param items Éléments à mettre en cache
         */
        private void add_to_cache(string path, Gee.ArrayList<FileItemModel> items) {
            // Si le cache est plein, retirer l'élément le plus ancien
            while (cache_keys.get_length() >= MAX_CACHE_ENTRIES) {
                string old_key = cache_keys.pop_head();
                directory_cache.remove(old_key);
            }

            // Faire une copie défensive pour éviter les modifications externes
            var items_copy = new Gee.ArrayList<FileItemModel>();
            foreach (var item in items) {
                items_copy.add(item);
            }

            // Ajouter au cache
            directory_cache.insert(path, items_copy);
            cache_keys.push_tail(path);
        }

        /**
         * Invalide le cache pour un répertoire spécifique
         * @param path Le chemin du répertoire à invalider
         */
        public void invalidate_cache(string path) {
            if (directory_cache.contains(path)) {
                directory_cache.remove(path);
            }
        }

        /**
         * Invalide tout le cache de répertoires
         */
        public void clear_cache() {
            directory_cache.remove_all();
            cache_keys.clear();
        }

        /**
         * Recherche des fichiers correspondant à un motif dans un répertoire
         * @param path Le chemin du répertoire de base
         * @param pattern Le motif à rechercher
         * @param recursive Si true, recherche récursivement dans les sous-dossiers
         * @return La liste des fichiers correspondants
         */
        public Gee.ArrayList<FileItemModel> search_files_by_pattern(string path, string pattern, bool recursive = true) {
            var results = new Gee.ArrayList<FileItemModel>();
            var pattern_lower = pattern.down();

            try {
                search_files_internal(path, pattern_lower, recursive, results);
            } catch (Error e) {
                warning("Erreur lors de la recherche de fichiers: %s", e.message);
            }

            return results;
        }

        /**
         * Fonction interne pour la recherche récursive de fichiers
         */
        private void search_files_internal(string path, string pattern, bool recursive, Gee.ArrayList<FileItemModel> results) throws Error {
            var directory = File.new_for_path(path);
            var enumerator = directory.enumerate_children(
                "standard::*,time::modified,unix::mode",
                FileQueryInfoFlags.NONE
            );

            FileInfo info;
            while ((info = enumerator.next_file()) != null) {
                var name = info.get_name().down();
                var file_path = Path.build_filename(path, info.get_name());

                // Ajouter si le nom correspond au motif
                if (name.contains(pattern)) {
                    var item = new FileItemModel.from_file_info(file_path, info);
                    results.add(item);
                }

                // Rechercher dans les sous-dossiers si demandé
                if (recursive && info.get_file_type() == FileType.DIRECTORY) {
                    search_files_internal(file_path, pattern, recursive, results);
                }
            }
        }

        /**
         * Effectue une recherche de texte dans le contenu des fichiers
         * @param path Le chemin du répertoire de base pour la recherche
         * @param text Le texte à rechercher dans les fichiers
         * @param max_results Nombre maximum de résultats à retourner
         * @param recursive Si true, recherche récursivement dans les sous-dossiers
         * @return La liste des fichiers dont le contenu contient le texte recherché
         */
        public Gee.ArrayList<FileItemModel> search_in_file_contents(string path, string text, int max_results = 100, bool recursive = true) {
            var results = new Gee.ArrayList<FileItemModel>();
            var text_lower = text.down();

            try {
                search_content_internal(path, text_lower, max_results, recursive, results);
            } catch (Error e) {
                warning("Erreur lors de la recherche dans le contenu des fichiers: %s", e.message);
            }

            return results;
        }

        /**
         * Fonction interne pour la recherche récursive dans le contenu des fichiers
         */
        private void search_content_internal(string path, string text, int max_results, bool recursive, Gee.ArrayList<FileItemModel> results) throws Error {
            if (results.size >= max_results) {
                return; // Limiter le nombre de résultats
            }

            var directory = File.new_for_path(path);
            var enumerator = directory.enumerate_children(
                "standard::*,time::modified,unix::mode",
                FileQueryInfoFlags.NONE
            );

            FileInfo info;
            while ((info = enumerator.next_file()) != null && results.size < max_results) {
                var file_path = Path.build_filename(path, info.get_name());

                if (info.get_file_type() == FileType.REGULAR) {
                    // Vérifier uniquement les fichiers texte
                    var content_type = info.get_content_type();
                    if (content_type != null &&
                        (content_type.contains("text/") ||
                         content_type.contains("application/json") ||
                         content_type.contains("application/xml"))) {

                        try {
                            // Lire le contenu du fichier
                            string content;
                            FileUtils.get_contents(file_path, out content);

                            // Vérifier si le contenu contient le texte recherché
                            if (content.down().contains(text)) {
                                var item = new FileItemModel.from_file_info(file_path, info);

                                // Ajouter un extrait du contenu aux métadonnées
                                int index = content.down().index_of(text);
                                if (index >= 0) {
                                    int start = int.max(0, index - 30);
                                    int end = int.min(content.length, index + text.length + 30);
                                    string context = content.substring(start, end - start);
                                    context = context.replace("\n", " ").replace("\r", "");
                                    item.set_metadata("search_match_context", "..." + context + "...");
                                }

                                results.add(item);
                            }
                        } catch (Error e) {
                            // Ignorer les erreurs de lecture de fichier
                        }
                    }
                } else if (recursive && info.get_file_type() == FileType.DIRECTORY) {
                    // Recherche récursive dans les sous-répertoires
                    search_content_internal(file_path, text, max_results, recursive, results);
                }
            }
        }

        /**
         * Recherche des fichiers récemment modifiés dans un intervalle de temps
         * @param path Le chemin du répertoire de base pour la recherche
         * @param time_span L'intervalle de temps en secondes (par rapport à maintenant)
         * @param recursive Si true, recherche récursivement dans les sous-dossiers
         * @return La liste des fichiers récemment modifiés
         */
        public Gee.ArrayList<FileItemModel> search_recent_files(string path, int64 time_span, bool recursive = true) {
            var results = new Gee.ArrayList<FileItemModel>();
            var now = new DateTime.now_local();
            var cutoff_time = now.add_seconds(-time_span);

            try {
                search_by_time_internal(path, cutoff_time, recursive, results);
            } catch (Error e) {
                warning("Erreur lors de la recherche de fichiers récents: %s", e.message);
            }

            // Trier par date de modification (plus récent d'abord)
            results.sort((a, b) => {
                return -a.modified_time.compare(b.modified_time);
            });

            return results;
        }

        /**
         * Fonction interne pour la recherche récursive par date
         */
        private void search_by_time_internal(string path, DateTime cutoff_time, bool recursive, Gee.ArrayList<FileItemModel> results) throws Error {
            var directory = File.new_for_path(path);
            var enumerator = directory.enumerate_children(
                "standard::*,time::modified,unix::mode",
                FileQueryInfoFlags.NONE
            );

            FileInfo info;
            while ((info = enumerator.next_file()) != null) {
                var file_path = Path.build_filename(path, info.get_name());
                var mod_time = info.get_modification_date_time();

                if (mod_time != null && mod_time.compare(cutoff_time) > 0) {
                    var item = new FileItemModel.from_file_info(file_path, info);
                    results.add(item);
                }

                if (recursive && info.get_file_type() == FileType.DIRECTORY) {
                    search_by_time_internal(file_path, cutoff_time, recursive, results);
                }
            }
        }

        /**
         * Obtient un aperçu du contenu d'un fichier texte
         * @param path Le chemin du fichier
         * @param max_length Longueur maximale de l'aperçu
         * @return Le contenu du fichier limité à max_length caractères
         */
        public string? get_file_preview(string path, int max_length = 1000) {
            try {
                // Vérifier si c'est un fichier texte
                var file = File.new_for_path(path);
                var info = file.query_info("standard::content-type", FileQueryInfoFlags.NONE);
                var content_type = info.get_content_type();

                if (!content_type.contains("text/") &&
                    !content_type.contains("application/json") &&
                    !content_type.contains("application/xml")) {
                    return null;
                }

                // Lire le contenu
                string content;
                FileUtils.get_contents(path, out content);

                // Limiter la taille
                if (content.length > max_length) {
                    content = content.substring(0, max_length) + "...";
                }

                return content;
            } catch (Error e) {
                warning("Erreur lors de la génération de l'aperçu pour %s: %s", path, e.message);
                return null;
            }
        }

        /**
         * Récupère le répertoire actuel de l'onglet actif
         * @return Le répertoire actuel sous forme de File, ou null si aucun onglet n'est actif
         */
        public File? get_current_directory() {
            if (active_tab == null) {
                return null;
            }

            return File.new_for_path(active_tab.current_path);
        }

        /**
         * Rafraîchit la vue de l'explorateur en rechargeant le contenu du répertoire actuel
         */
        public void refresh() {
            if (active_tab == null) {
                return;
            }

            // Vider le cache pour le répertoire actuel
            string current_path = active_tab.current_path;
            if (directory_cache.contains(current_path)) {
                directory_cache.remove(current_path);
            }

            // Re-naviguer vers le même dossier pour forcer le rechargement
            var current_file = File.new_for_path(current_path);
            if (current_file.query_exists()) {
                // Notifier les observateurs que les fichiers ont été mis à jour
                // (Utilisez un signal existant ou créez-en un nouveau)
                active_tab.notify_property("current-path");

                // Si vous avez un signal files_updated, utilisez-le ici :
                // files_updated(current_path);

                // Notifier aussi les changements de configuration qui affectent l'affichage
                show_hidden_files_changed(this.show_hidden_files);
                breadcrumb_enabled_changed(this.breadcrumb_enabled);
            }
        }

        /**
         * Navigue vers le dossier parent du répertoire courant
         * @return true si la navigation a réussi, false sinon
         */
        public bool navigate_to_parent() {
            var tab = get_active_tab_by_index();
            if (tab == null) {
                return false;
            }

            var dir = File.new_for_path(tab.current_path);
            var parent = dir.get_parent();

            if (parent != null) {
                return navigate_to(parent.get_path());
            }

            return false;
        }

        // Modifier ApplicationControllerExtension.get_explorer_model() pour utiliser cette version
        public static ExplorerModel get_explorer_model(ApplicationController controller) {
            if (_explorer_model != null) {
                return _explorer_model;
            } else {
                // Create a new model if none exists with the controller
                var model = new ExplorerModel(controller);
                _explorer_model = model;
                return model;
            }
        }

        // Liste des extensions filtrées (ex: ["txt", "md"])
        private Gee.Set<string> filtered_extensions = new Gee.HashSet<string>();

        public void set_filtered_extensions(Gee.Set<string> extensions) {
            filtered_extensions.clear();
            filtered_extensions.add_all(extensions);
            // Rafraîchir la vue ou relancer la recherche si besoin
            refresh();
        }

        // Supprime ou commente toute la méthode suivante :
        // public Gee.List<string> get_available_extensions(string directory) {
        //     var exts = new Gee.HashSet<string>();
        //     // Parcours des fichiers du dossier
        //     try {
        //         var dir = File.new_for_path(directory);
        //         var enumerator = dir.enumerate_children(FileAttribute.STANDARD_NAME, 0);
        //         FileInfo info;
        //         while ((info = enumerator.next_file()) != null) {
        //             var name = info.get_name();
        //             int dot = name.last_index_of_char('.');
        //             if (dot > 0 && dot < name.length - 1) {
        //                 exts.add(name.substring(dot + 1));
        //             }
        //         }
        //     } catch (Error e) {
        //         // Ignorer les erreurs
        //     }
        //     var list = new Gee.ArrayList<string>();
        //     list.add_all(exts);
        //     list.sort();
        //     return list;
        // }

        // Filtrage lors du chargement des fichiers
        private bool file_matches_filters(string filename) {
            if (filtered_extensions.size == 0)
                return true; // Aucun filtre = tout afficher
            int dot = filename.last_index_of_char('.');
            if (dot > 0 && dot < filename.length - 1) {
                string ext = filename.substring(dot + 1);
                return filtered_extensions.contains(ext);
            }
            return false;
        }

        public Gee.List<string> get_available_extensions_from_ini() {
            var config_dir = Environment.get_user_config_dir() + "/sambo";
            var ini_path = Path.build_filename(config_dir, "extension.ini");
            var extensions = new Gee.ArrayList<string>();

            var key_file = new KeyFile();
            try {
                key_file.load_from_file(ini_path, KeyFileFlags.KEEP_COMMENTS);
                string ext_str = key_file.get_string("Extensions", "list");
                foreach (string ext in ext_str.split(";")) {
                    if (ext.strip() != "") {
                        extensions.add(ext.strip());
                    }
                }
            } catch (Error e) {
                warning("Impossible de charger extension.ini : %s", e.message);
                // Valeurs par défaut si le fichier n'existe pas
                extensions.add("txt");
                extensions.add("md");
                extensions.add("html");
                extensions.add("vala");
            }
            extensions.sort();
            return extensions;
        }

        public class ExtensionInfo : Object {
            public string extension;
            public string label;
            public ExtensionInfo(string extension, string label) {
                this.extension = extension;
                this.label = label;
            }
        }

        public Gee.List<ExtensionInfo> get_available_extensions_with_labels() {
            var config_dir = Environment.get_user_config_dir() + "/sambo";
            var ini_path = Path.build_filename(config_dir, "extension.ini");
            var extensions = new Gee.ArrayList<ExtensionInfo>();

            var key_file = new KeyFile();
            try {
                key_file.load_from_file(ini_path, KeyFileFlags.KEEP_COMMENTS);
                string[] keys = key_file.get_keys("Extensions");
                foreach (string ext in keys) {
                    string label = key_file.get_string("Extensions", ext);
                    extensions.add(new ExtensionInfo(ext.strip(), label.strip()));
                }
            } catch (Error e) {
                warning("Impossible de charger extension.ini : %s", e.message);
                // Valeurs par défaut
                extensions.add(new ExtensionInfo("txt", "Texte brut"));
                extensions.add(new ExtensionInfo("md", "Markdown"));
            }
            return extensions;
        }
    }
}

/*
 * Implementation notes:
 *
 * Dans ApplicationController.init() après la création de explorer_view:
 * explorer_view.file_selected.connect((path) => {
 *     var model = ApplicationControllerExtension.get_explorer_model(this);
 *     var file = File.new_for_path(path);
 *
 *     try {
 *         var file_info = file.query_info(FileAttribute.STANDARD_TYPE, FileQueryInfoFlags.NONE);
 *
 *         if (file_info.get_file_type() == FileType.DIRECTORY) {
 *             // C'est un dossier, naviguer vers ce dossier
 *             model.navigate_to(path);
 *         } else {
 *             // C'est un fichier, l'ouvrir dans l'éditeur
 *             open_document(path);
 *         }
 *     } catch (Error e) {
 *         stderr.printf("Erreur lors de la gestion du fichier: %s\n", e.message);
 *     }
 * });
 *
 * Dans la méthode on_item_activated de ExplorerTabView:
 * Remplacer la ligne : file_selected(file_item.path); par:
 * if (file_item.is_directory()) {
 *     var explorer_model = ApplicationControllerExtension.get_explorer_model(controller);
 *     explorer_model.navigate_to(file_item.path);
 * } else {
 *     file_selected(file_item.path);
 * }
 */
