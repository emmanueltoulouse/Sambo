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
    }
}
