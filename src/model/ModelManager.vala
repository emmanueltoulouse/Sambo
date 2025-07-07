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
        private bool is_generation_cancelled = false; // Pour annuler la génération
        private Thread<void*>? current_generation_thread = null; // Thread actuel

        // Signaux pour informer l'interface
        public signal void model_loaded(string model_path, string model_name);
        public signal void model_load_failed(string model_path, string error_message);
        public signal void model_unloaded();
        public signal void generation_cancelled(); // Signal d'annulation

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
         * Constructeur public
         */
        public ModelManager() {
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

            // Toujours tenter de charger via le wrapper C (qui gère le mode simulation)
            try {
                // Tentative de chargement du modèle via wrapper
                bool success = Llama.load_model(model_path);

                if (!success) {
                    throw new IOError.FAILED("Échec du chargement du modèle");
                }

                // Succès du chargement
                current_model_path = model_path;
                is_model_loaded = true;

                string model_name = Path.get_basename(model_path);
                if (is_simulation_mode) {
                    print("Modèle chargé avec succès en simulation : %s\n", model_name);
                } else {
                    print("Modèle chargé avec succès : %s\n", model_name);
                }

                model_loaded(model_path, model_name);
                return true;

            } catch (Error e) {
                // En cas d'erreur, essayer le mode simulation legacy
                warning("Erreur lors du chargement via wrapper, tentative simulation legacy : %s", e.message);
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
         * Génère une réponse IA en utilisant les paramètres fournis
         * @param prompt Le prompt complet avec contexte
         * @param params Les paramètres de sampling
         * @param callback Fonction appelée pour chaque token généré (pour le streaming)
         * @return La réponse complète ou null en cas d'erreur
         */
        public string? generate_response(string prompt, Llama.SamplingParams params, owned GenerationCallback? callback = null) {
            if (!is_model_loaded) {
                stderr.printf("❌ MODELMANAGER: Aucun modèle chargé pour la génération\n");
                return null;
            }

            // Annuler toute génération en cours
            if (is_generating()) {
                cancel_generation();
                // Attendre un peu que le thread précédent se termine
                Thread.usleep(100000); // 100ms
            }

            // Réinitialiser le flag d'annulation
            is_generation_cancelled = false;

            if (is_simulation_mode) {
                return generate_simulated_response(prompt, params, (owned) callback);
            }

            // Génération asynchrone pour éviter de bloquer l'UI
            generate_response_async.begin(prompt, params, (owned) callback, (obj, res) => {
                // Nettoyer la référence du thread une fois terminé
                current_generation_thread = null;
            });
            
            return null; // La réponse sera fournie via le callback
        }

        /**
         * Génération asynchrone pour éviter de bloquer l'interface utilisateur
         */
        private async void generate_response_async(string prompt, Llama.SamplingParams params, owned GenerationCallback? callback) {
            // Créer un thread pour la génération
            current_generation_thread = new Thread<void*>("ai_generation", () => {
                stderr.printf("Démarrage de la génération avec llama.cpp...\n");
                
                // Vérifier l'annulation avant de commencer
                if (is_generation_cancelled) {
                    Idle.add(() => {
                        if (callback != null) {
                            callback("⏹️ Génération annulée", true);
                        }
                        return false;
                    });
                    return null;
                }
                
                // Estimation approximative du nombre de tokens (1 token ≈ 4 caractères)
                var estimated_tokens = prompt.length / 4;
                stderr.printf("Prompt estimé : %d tokens\n", estimated_tokens);
                
                // Vérifier l'annulation avant la génération
                if (is_generation_cancelled) {
                    Idle.add(() => {
                        if (callback != null) {
                            callback("⏹️ Génération annulée", true);
                        }
                        return false;
                    });
                    return null;
                }
                
                // Génération réelle via llama.cpp
                string? response = Llama.generate_simple(prompt, &params);
                
                // Vérifier l'annulation après la génération
                if (is_generation_cancelled) {
                    Idle.add(() => {
                        if (callback != null) {
                            callback("⏹️ Génération annulée", true);
                        }
                        return false;
                    });
                    return null;
                }
                
                if (response != null && response.length > 0) {
                    stderr.printf("Génération terminée avec succès\n");
                    // Appeler le callback dans le thread principal
                    Idle.add(() => {
                        if (callback != null) {
                            callback(response, true); // true = terminé
                        }
                        return false;
                    });
                } else {
                    stderr.printf("❌ MODELMANAGER: Génération échouée ou réponse vide\n");
                    Idle.add(() => {
                        if (callback != null) {
                            callback("❌ Erreur lors de la génération", true);
                        }
                        return false;
                    });
                }
                
                return null;
            });
            
            // Attendre la fin du thread de manière asynchrone
            yield;
        }

        /**
         * Génère une réponse simulée pour les tests
         */
        private string generate_simulated_response(string prompt, Llama.SamplingParams params, owned GenerationCallback? callback) {
            string response = """Réponse simulée du modèle IA.

🤖 **Modèle** : %s
🌡️ **Température** : %.2f
🎯 **Top-P** : %.2f
🔢 **Top-K** : %d
📝 **Max tokens** : %d

Votre message : "%s"

Cette réponse est générée en mode simulation car llama.cpp n'est pas disponible ou aucun modèle n'est chargé.
""".printf(
                get_current_model_name(), 
                params.temperature, 
                params.top_p, 
                params.top_k, 
                params.max_tokens,
                prompt.length > 100 ? prompt[0:100] + "..." : prompt
            );

            if (callback != null) {
                // Simuler le streaming progressif
                string[] words = response.split(" ");
                string partial = "";
                
                foreach (string word in words) {
                    partial += word + " ";
                    callback(partial, false);
                    Thread.usleep(50000); // 50ms de délai pour simuler le streaming
                }
                
                callback(response, true); // Signal de fin
            }

            return response;
        }

        /**
         * Annule la génération en cours
         */
        public void cancel_generation() {
            is_generation_cancelled = true;
            generation_cancelled.emit();
            stderr.printf("🛑 MODELMANAGER: Génération annulée par l'utilisateur\n");
        }

        /**
         * Vérifie si une génération est en cours
         */
        public bool is_generating() {
            return current_generation_thread != null;
        }

        /**
         * Type de délégué pour les callbacks de génération (streaming)
         * @param partial_response Réponse partielle courante
         * @param is_finished true si la génération est terminée
         */
        public delegate void GenerationCallback(string partial_response, bool is_finished);

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
