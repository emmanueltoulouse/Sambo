using GLib;

namespace Sambo {
    public class ConfigManager {
        private string config_path;
        private KeyFile key_file;
        private string app_home_dir;

        public signal void config_changed();
        public signal void config_error(string message);

        public ConfigManager() {
            // Répertoire de configuration standard
            config_path = Path.build_filename(Environment.get_user_config_dir(), "sambo", "config.ini");

            // Répertoire personnel pour l'application
            app_home_dir = Path.build_filename(Environment.get_home_dir(), "com.cabineteto.Sambo");

            // Si le répertoire personnel pour l'app existe, l'utiliser plutôt
            if (FileUtils.test(app_home_dir, FileTest.IS_DIR)) {
                config_path = Path.build_filename(app_home_dir, "config.ini");
            }

            key_file = new KeyFile();

            // Crée le dossier de configuration si nécessaire
            var config_dir = Path.get_dirname(config_path);
            try {
                if (!FileUtils.test(config_dir, FileTest.IS_DIR)) {
                    if (DirUtils.create_with_parents(config_dir, 0755) == -1) {
                        throw new FileError.FAILED("Impossible de créer le dossier de configuration");
                    }
                }

                // Vérifier si le fichier de config existe, sinon créer un fichier vide
                if (!FileUtils.test(config_path, FileTest.EXISTS)) {
                    FileUtils.set_contents(config_path, "");
                }
            } catch (Error e) {
                warning("Erreur lors de l'initialisation de la configuration: %s", e.message);
                config_error.emit(e.message);
            }
        }

        public void load() {
            // Méthode pour charger la configuration depuis le fichier INI
            try {
                key_file.load_from_file(config_path, KeyFileFlags.KEEP_COMMENTS);
                print("Configuration chargée depuis %s\n", config_path);
            } catch (Error e) {
                warning("Erreur lors du chargement de la configuration: %s", e.message);
                config_error.emit(e.message);
            }
        }

        public void save() {
            // Méthode pour sauvegarder la configuration dans le fichier INI
            try {
                string data = key_file.to_data();
                FileUtils.set_contents(config_path, data);
                print("Configuration sauvegardée dans %s\n", config_path);
                config_changed.emit();
            } catch (Error e) {
                warning("Erreur lors de la sauvegarde de la configuration: %s", e.message);
                config_error.emit(e.message);
            }
        }

        // Méthodes utilitaires pour manipuler la configuration
        public string get_string(string group, string key, string default_value = "") {
            try {
                return key_file.get_string(group, key);
            } catch (Error e) {
                return default_value;
            }
        }

        public void set_string(string group, string key, string value) {
            key_file.set_string(group, key, value);
        }

        public int get_integer(string group, string key, int default_value = 0) {
            try {
                return key_file.get_integer(group, key);
            } catch (Error e) {
                return default_value;
            }
        }

        public void set_integer(string group, string key, int value) {
            key_file.set_integer(group, key, value);
        }

        public bool get_boolean(string group, string key, bool default_value = false) {
            try {
                return key_file.get_boolean(group, key);
            } catch (Error e) {
                return default_value;
            }
        }

        public void set_boolean(string group, string key, bool value) {
            key_file.set_boolean(group, key, value);
        }

        /**
         * Obtient une valeur double de la configuration
         * @param section La section
         * @param key La clé
         * @param default_value La valeur par défaut si la clé n'existe pas
         * @return La valeur ou la valeur par défaut
         */
        public double get_double(string section, string key, double default_value = 0.0) {
            try {
                return key_file.get_double(section, key);
            } catch (Error e) {
                // Si la clé n'existe pas, renvoyer la valeur par défaut
                return default_value;
            }
        }

        /**
         * Définit une valeur double dans la configuration
         * @param section La section
         * @param key La clé
         * @param value La valeur
         */
        public void set_double(string section, string key, double value) {
            key_file.set_double(section, key, value);
        }

        /**
         * Structure pour représenter un nœud dans l'arborescence des modèles
         */
        public class ModelNode : Object {
            public string name { get; set; }
            public string full_path { get; set; }
            public string size_str { get; set; }
            public bool is_file { get; set; }
            public string error_message { get; set; default = ""; }
            public string error_details { get; set; default = ""; }
            public Gee.List<ModelNode> children { get; set; }

            public ModelNode(string name, string full_path, bool is_file = false, string size_str = "") {
                this.name = name;
                this.full_path = full_path;
                this.is_file = is_file;
                this.size_str = size_str;
                this.children = new Gee.ArrayList<ModelNode>();
            }

            public bool has_error() {
                return error_message != "";
            }
        }

        /**
         * Obtient l'arborescence des modèles disponibles
         * @return Racine de l'arborescence des modèles
         */
        public ModelNode get_models_tree() {
            string models_dir = get_string("AI", "models_directory", "");
            var root = new ModelNode("Models", models_dir);

            // Définir l'état d'erreur dans le nœud racine
            root.error_message = "";

            print("Répertoire des modèles configuré : %s\n", models_dir);

            // Vérifier si un répertoire est configuré
            if (models_dir == "") {
                root.error_message = "AUCUN_REPERTOIRE_CONFIGURE";
                root.error_details = "Aucun répertoire de modèles n'est configuré dans les paramètres.";
                return root;
            }

            // Vérifier si le répertoire existe
            if (!FileUtils.test(models_dir, FileTest.EXISTS)) {
                root.error_message = "REPERTOIRE_INEXISTANT";
                root.error_details = @"Le répertoire configuré n'existe pas :\n$(models_dir)";
                return root;
            }

            // Vérifier si c'est bien un dossier
            if (!FileUtils.test(models_dir, FileTest.IS_DIR)) {
                root.error_message = "PAS_UN_DOSSIER";
                root.error_details = @"Le chemin configuré n'est pas un dossier :\n$(models_dir)";
                return root;
            }

            // Scanner l'arborescence
            try {
                build_models_tree(models_dir, root, models_dir);
            } catch (Error e) {
                warning("Erreur lors du scan des modèles: %s", e.message);
                root.error_message = "ERREUR_SCAN";
                root.error_details = @"Erreur lors du scan du répertoire :\n$(e.message)";
                return root;
            }

            // Vérifier si des modèles ont été trouvés
            if (root.children.size == 0) {
                root.error_message = "AUCUN_MODELE_TROUVE";
                root.error_details = @"Aucun modèle trouvé dans le répertoire :\n$(models_dir)\n\nFormats supportés : .gguf, .bin, .safetensors";
                return root;
            }

            print("Arborescence des modèles construite avec %d éléments\n", root.children.size);
            return root;
        }

        /**
         * Construit récursivement l'arborescence des modèles
         */
        private void build_models_tree(string dir_path, ModelNode parent_node, string base_path) throws Error {
            var dir = Dir.open(dir_path);
            string? name;

            while ((name = dir.read_name()) != null) {
                string full_path = Path.build_filename(dir_path, name);

                if (FileUtils.test(full_path, FileTest.IS_DIR)) {
                    // Créer un nœud dossier
                    var folder_node = new ModelNode(name, full_path, false);
                    parent_node.children.add(folder_node);

                    // Scanner récursivement le dossier
                    build_models_tree(full_path, folder_node, base_path);
                } else if (name.has_suffix(".gguf") ||
                          name.has_suffix(".bin") ||
                          name.has_suffix(".safetensors")) {

                    // Obtenir la taille du fichier
                    string size_str = "";
                    try {
                        var file = File.new_for_path(full_path);
                        var file_info = file.query_info(FileAttribute.STANDARD_SIZE, FileQueryInfoFlags.NONE);
                        int64 file_size = file_info.get_size();
                        size_str = format_file_size(file_size);
                    } catch (Error e) {
                        size_str = "?";
                    }

                    // Nettoyer le nom du fichier
                    string clean_name = name;
                    if (name.has_suffix(".gguf")) {
                        clean_name = name.substring(0, name.length - 5);
                    } else if (name.has_suffix(".bin")) {
                        clean_name = name.substring(0, name.length - 4);
                    } else if (name.has_suffix(".safetensors")) {
                        clean_name = name.substring(0, name.length - 12);
                    }

                    // Créer un nœud fichier
                    var file_node = new ModelNode(clean_name, full_path, true, size_str);
                    parent_node.children.add(file_node);

                    print("Modèle trouvé : %s (taille: %s, chemin: %s)\n", clean_name, size_str, full_path);
                }
            }
        }

        /**
         * Obtient la liste des modèles disponibles (compatibilité avec l'ancien code)
         * @return Liste des noms de modèles
         */
        public string[] get_available_models() {
            var models = new Gee.ArrayList<string>();
            var tree = get_models_tree();

            flatten_tree_to_list(tree, "", models);

            return models.to_array();
        }

        /**
         * Aplatit l'arborescence en liste pour compatibilité
         */
        private void flatten_tree_to_list(ModelNode node, string path_prefix, Gee.ArrayList<string> models) {
            if (node.is_file) {
                string full_name = path_prefix.length > 0 ? @"$(path_prefix)/$(node.size_str) - $(node.name)" : @"$(node.size_str) - $(node.name)";
                models.add(full_name);
            } else {
                string new_prefix = path_prefix.length > 0 ? @"$(path_prefix)/$(node.name)" : node.name;
                if (node.name != "Models") { // Skip root
                    foreach (var child in node.children) {
                        flatten_tree_to_list(child, new_prefix, models);
                    }
                } else {
                    foreach (var child in node.children) {
                        flatten_tree_to_list(child, "", models);
                    }
                }
            }
        }

        /**
         * Formate la taille d'un fichier en unités lisibles
         */
        private string format_file_size(int64 size_bytes) {
            if (size_bytes < 1024) {
                return @"$(size_bytes) B";
            } else if (size_bytes < 1024 * 1024) {
                int64 size_kb = size_bytes / 1024;
                return @"$(size_kb) KB";
            } else if (size_bytes < 1024 * 1024 * 1024) {
                double size_mb = (double)size_bytes / (1024 * 1024);
                int mb_rounded = (int)(size_mb * 10) / 10; // Arrondi à 1 décimale
                if (size_mb - mb_rounded >= 0.05) {
                    mb_rounded++;
                }
                return @"$(mb_rounded).$(((int)(size_mb * 10)) % 10) MB";
            } else {
                double size_gb = (double)size_bytes / (1024 * 1024 * 1024);
                int gb_rounded = (int)(size_gb * 10) / 10; // Arrondi à 1 décimale
                if (size_gb - gb_rounded >= 0.05) {
                    gb_rounded++;
                }
                return @"$(gb_rounded).$(((int)(size_gb * 10)) % 10) GB";
            }
        }

    }
}
