using GLib;

namespace Sambo {
    /**
     * Gestionnaire de modèles llama.cpp
     * Gère le chargement, l'initialisation et la libération des modèles
     */
    public class ModelManager : Object {
        private static ModelManager? instance = null;
        private string current_model_path = "";
        private bool is_model_loaded = false;
        private bool is_backend_initialized = false;
        private bool is_simulation_mode = false; // Mode réel par défaut

        // Signaux pour informer l'interface
        public signal void model_loaded(string model_path, string model_name);
        public signal void model_load_failed(string model_path, string error_message);
        public signal void model_unloaded();

        /**
         * Singleton - obtenir l'instance unique
         */
        public static ModelManager get_instance() {
            if (instance == null) {
                instance = new ModelManager();
            }
            return instance;
        }

        /**
         * Constructeur privé (pattern singleton)
         */
        private ModelManager() {
            // Initialiser le backend llama.cpp
            init_backend();
        }

        /**
         * Initialise le backend llama.cpp
         */
        private void init_backend() {
            if (!is_backend_initialized) {
                stderr.printf("🔧 MODELMANAGER: Initialisation du backend llama.cpp...\n");
                try {
                    // Tentative d'initialisation réelle du backend llama.cpp via wrapper
                    bool success = Llama.backend_init();
                    if (success) {
                        is_backend_initialized = true;
                        is_simulation_mode = false;
                        stderr.printf("✅ MODELMANAGER: Backend llama.cpp initialisé avec succès\n");
                    } else {
                        throw new IOError.NOT_FOUND("Backend llama.cpp non disponible");
                    }
                } catch (Error e) {
                    stderr.printf("⚠️ MODELMANAGER: llama.cpp non disponible, mode simulation activé: %s\n", e.message);
                    is_simulation_mode = true;
                    is_backend_initialized = false;
                }
            }
        }

        /**
         * Charge un modèle depuis un fichier
         * @param model_path Chemin vers le fichier du modèle
         * @return true si le chargement a réussi, false sinon
         */
        public bool load_model(string model_path) {
            // Vérifier que le fichier existe
            if (!FileUtils.test(model_path, FileTest.EXISTS)) {
                string error_msg = @"Le fichier modèle n'existe pas : $model_path";
                warning(error_msg);
                model_load_failed(model_path, error_msg);
                return false;
            }

            // Libérer le modèle précédent s'il existe
            unload_current_model();

            stderr.printf("📂 MODELMANAGER: Chargement du modèle : %s\n", model_path);

            // Mode simulation si llama.cpp n'est pas disponible
            if (is_simulation_mode) {
                return load_model_simulation(model_path);
            }

            try {
                // Tentative de chargement réel du modèle via wrapper
                bool success = Llama.load_model(model_path);
                
                if (!success) {
                    throw new IOError.FAILED("Échec du chargement du modèle");
                }
                
                // Succès du chargement réel
                current_model_path = model_path;
                is_model_loaded = true;
                
                string model_name = Path.get_basename(model_path);
                print("Modèle chargé avec succès : %s\n", model_name);
                
                model_loaded(model_path, model_name);
                return true;
                
            } catch (Error e) {
                // En cas d'erreur, basculer en mode simulation si possible
                warning("Erreur lors du chargement réel, tentative en mode simulation : %s", e.message);
                return load_model_simulation(model_path);
            }
        }

        /**
         * Charge un modèle en mode simulation (pour les tests sans llama.cpp)
         */
        private bool load_model_simulation(string model_path) {
            print("Mode simulation : chargement simulé du modèle %s\n", model_path);
            
            // Simuler un délai de chargement
            Thread.usleep(500000); // 0.5 seconde
            
            // Vérifier la taille du fichier (simulation de validation)
            try {
                var file = File.new_for_path(model_path);
                var file_info = file.query_info(FileAttribute.STANDARD_SIZE, FileQueryInfoFlags.NONE);
                int64 file_size = file_info.get_size();
                
                if (file_size < 1024) { // Fichier trop petit
                    string error_msg = "Le fichier modèle semble trop petit ou corrompu";
                    model_load_failed(model_path, error_msg);
                    return false;
                }
                
                // Succès de la simulation
                current_model_path = model_path;
                is_model_loaded = true;
                
                string model_name = Path.get_basename(model_path);
                print("Modèle simulé chargé avec succès : %s\n", model_name);
                
                model_loaded(model_path, model_name);
                return true;
                
            } catch (Error e) {
                string error_msg = @"Erreur lors de la validation du modèle : $(e.message)";
                model_load_failed(model_path, error_msg);
                return false;
            }
        }

        /**
         * Décharge le modèle actuel
         */
        public void unload_current_model() {
            if (is_model_loaded) {
                print("Déchargement du modèle actuel...\n");
                
                if (!is_simulation_mode) {
                    // Libération des ressources llama.cpp via wrapper
                    Llama.unload_model();
                }
                
                current_model_path = "";
                is_model_loaded = false;
                
                model_unloaded();
                print("Modèle déchargé\n");
            }
        }

        /**
         * Vérifie si un modèle est actuellement chargé
         */
        public bool is_model_ready() {
            if (is_simulation_mode) {
                return is_model_loaded;
            }
            return is_model_loaded && Llama.is_model_loaded();
        }

        /**
         * Indique si le gestionnaire fonctionne en mode simulation
         */
        public bool is_in_simulation_mode() {
            return is_simulation_mode;
        }

        /**
         * Obtient le chemin du modèle actuellement chargé
         */
        public string get_current_model_path() {
            return current_model_path;
        }

        /**
         * Obtient le nom du modèle actuellement chargé
         */
        public string get_current_model_name() {
            if (current_model_path == "") {
                return "";
            }
            return Path.get_basename(current_model_path);
        }

        /**
         * Destructeur - libère les ressources
         */
        ~ModelManager() {
            unload_current_model();
            
            if (is_backend_initialized && !is_simulation_mode) {
                Llama.backend_free();
                is_backend_initialized = false;
            }
        }
    }
}
