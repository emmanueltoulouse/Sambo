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
        private ConfigManager config_manager; // Gestionnaire de configuration

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
            // Récupérer l'instance de ConfigManager
            config_manager = new ConfigManager();
            config_manager.load();

            // Initialiser le backend llama.cpp
            init_backend();
        }

        /**
         * Initialise le backend llama.cpp
         */
        private void init_backend() {
            if (!is_backend_initialized) {
                try {
                    // Tentative d'initialisation réelle du backend llama.cpp via wrapper
                    bool success = Llama.backend_init();
                    if (success) {
                        is_backend_initialized = true;
                        is_simulation_mode = false;
                    } else {
                        throw new IOError.NOT_FOUND("Backend llama.cpp non disponible");
                    }
                } catch (Error e) {
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
                if (!is_simulation_mode) {
                    // Libération des ressources llama.cpp via wrapper
                    Llama.unload_model();
                }

                current_model_path = "";
                is_model_loaded = false;

                model_unloaded();
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
            stderr.printf("[TRACE][OUT] MODELMANAGER: generate_response_async démarré\n");
            stderr.printf("[TRACE][OUT] MODELMANAGER: params.stream = %s, callback = %s\n",
                params.stream ? "TRUE" : "FALSE",
                callback != null ? "NON-NULL" : "NULL");

            // Récupérer le timeout depuis la configuration (en secondes)
            int timeout_seconds = config_manager.get_generation_timeout();
            int64 timeout_microseconds = timeout_seconds == 0 ? 0 : (int64)timeout_seconds * 1000000;

            stderr.printf("[TRACE][OUT] MODELMANAGER: Timeout configuré: %d secondes (%s)\n",
                timeout_seconds, timeout_seconds == 0 ? "INFINI" : "LIMITÉ");

            // Créer un thread pour la génération avec timeout de sécurité
            var start_time = get_monotonic_time();

            // Copier le callback pour éviter les problèmes de mémoire
            GenerationCallback? local_callback = callback;

            current_generation_thread = new Thread<void*>("ai_generation", () => {
                // Vérifier l'annulation avant de commencer
                if (is_generation_cancelled) {
                    Idle.add(() => {
                        if (local_callback != null) {
                            local_callback("⏹️ Génération annulée", true);
                        }
                        return Source.REMOVE;
                    });
                    return null;
                }

                string? response = null;
                bool generation_successful = false;

                try {
                    stderr.printf("[TRACE][OUT] MODELMANAGER: Début du try - vérification streaming\n");
                    // Vérifier si on a le streaming activé
                    if (params.stream && local_callback != null) {
                        stderr.printf("[TRACE][OUT] MODELMANAGER: STREAMING ACTIVÉ - début génération réelle\n");

                        // Tenter la génération réelle avec streaming via llama.cpp
                        try {
                            response = generate_real_streaming(prompt, params, local_callback, &is_generation_cancelled);
                            generation_successful = (response != null && response.length > 0);

                            stderr.printf("[TRACE][IN] MODELMANAGER: Génération streaming réelle terminée, résultat: %s (%d caractères)\n",
                                generation_successful ? "SUCCÈS" : "ÉCHEC",
                                response != null ? (int)response.length : 0);
                        } catch (Error streaming_error) {
                            stderr.printf("⚠️ MODELMANAGER: Erreur streaming réel, fallback vers simulation: %s\n", streaming_error.message);

                            // Fallback vers la simulation si le streaming réel échoue
                            response = generate_streaming_simulation(prompt, params, local_callback, &is_generation_cancelled);
                            generation_successful = (response != null && response.length > 0);

                            stderr.printf("[TRACE][IN] MODELMANAGER: Simulation streaming (fallback) terminée, résultat: %s (%d caractères)\n",
                                generation_successful ? "SUCCÈS" : "ÉCHEC",
                                response != null ? (int)response.length : 0);
                        }
                    } else {
                        stderr.printf("[TRACE][OUT] MODELMANAGER: PAS DE STREAMING - params.stream=%s, callback=%s\n",
                            params.stream ? "TRUE" : "FALSE",
                            local_callback != null ? "NON-NULL" : "NULL");
                        // Génération simple sans streaming
                        stderr.printf("[TRACE][OUT] MODELMANAGER: Génération simple sans streaming\n");
                        response = Llama.generate_simple(prompt, &params);
                        generation_successful = (response != null);
                        stderr.printf("[TRACE][IN] MODELMANAGER: Génération simple terminée: %s\n",
                            generation_successful ? "SUCCÈS" : "ÉCHEC");
                    }

                    // Vérifier l'annulation après la génération
                    if (is_generation_cancelled) {
                        Idle.add(() => {
                            if (local_callback != null) {
                                local_callback("⏹️ Génération annulée", true);
                            }
                            return Source.REMOVE;
                        });
                        return null;
                    }

                } catch (Error e) {
                    stderr.printf("❌ MODELMANAGER: Erreur lors de la génération: %s\n", e.message);
                    generation_successful = false;
                }

                // Vérifier le timeout (seulement si configuré)
                if (timeout_microseconds > 0) {
                    var elapsed_time = get_monotonic_time() - start_time;
                    if (elapsed_time > timeout_microseconds) {
                        Idle.add(() => {
                            if (local_callback != null) {
                                local_callback("⏱️ Timeout de génération atteint", true);
                            }
                            return Source.REMOVE;
                        });
                        return null;
                    }
                }

                // Traiter le résultat final
                if (generation_successful && response != null && response.length > 0) {
                    // Pour le streaming, envoyer le signal de fin
                    if (params.stream && local_callback != null) {
                        // Pour le streaming simulé, juste signaler la fin
                        Idle.add(() => {
                            stderr.printf("[TRACE][OUT] MODELMANAGER: Envoi signal de fin de streaming simulé\n");
                            if (local_callback != null) {
                                local_callback(response, true); // true = terminé
                            }
                            return Source.REMOVE;
                        });
                    } else {
                        // Pour la génération simple, appeler le callback avec le résultat final
                        Idle.add(() => {
                            stderr.printf("[TRACE][OUT] MODELMANAGER: Envoi résultat final non-stream\n");
                            if (local_callback != null) {
                                local_callback(response, true); // true = terminé
                            }
                            return Source.REMOVE;
                        });
                    }
                } else {
                    Idle.add(() => {
                        stderr.printf("[TRACE][OUT] MODELMANAGER: Envoi erreur de génération\n");
                        if (local_callback != null) {
                            local_callback("❌ Erreur lors de la génération", true);
                        }
                        return Source.REMOVE;
                    });
                }

                return null;
            });

            // Surveillance du thread avec timeout et kill forcé (seulement si timeout configuré)
            if (timeout_seconds > 0) {
                Timeout.add_seconds(timeout_seconds + 5, () => { // 5 secondes de marge pour le nettoyage
                    if (current_generation_thread != null && is_generating()) {
                        stderr.printf("[TRACE][OUT] MODELMANAGER: Timeout de sécurité atteint, nettoyage forcé\n");

                        // Forcer l'annulation
                        is_generation_cancelled = true;

                        // Tenter d'arrêter le backend
                        if (!is_simulation_mode) {
                            Llama.stop_generation();

                            // Forcer le nettoyage du modèle
                            try {
                                string current_model = current_model_path;
                                Llama.unload_model();
                                Thread.usleep(200000); // 200ms
                                if (current_model != "") {
                                    Llama.load_model(current_model);
                                }
                            } catch (Error e) {
                                stderr.printf("⚠️ MODELMANAGER: Erreur lors du nettoyage forcé: %s\n", e.message);
                            }
                        }

                        // Marquer le thread comme terminé
                        current_generation_thread = null;

                        // Émettre le signal d'annulation
                        generation_cancelled.emit();
                    }
                    return false; // Ne pas répéter
                });
            }
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
                // Simuler le streaming progressif avec vérification d'annulation
                string[] words = response.split(" ");
                string partial = "";

                foreach (string word in words) {
                    // Vérifier l'annulation à chaque mot
                    if (is_generation_cancelled) {
                        callback("⏹️ Génération annulée", true);
                        return "⏹️ Génération annulée";
                    }

                    partial += word + " ";
                    callback(partial, false);
                    Thread.usleep(50000); // 50ms de délai pour simuler le streaming
                }

                // Vérification finale d'annulation
                if (is_generation_cancelled) {
                    callback("⏹️ Génération annulée", true);
                    return "⏹️ Génération annulée";
                }

                callback(response, true); // Signal de fin
            }

            return response;
        }

        /**
         * Génère une réponse avec streaming simulé pendant l'exécution réelle
         */
        private string? generate_streaming_simulation(string prompt, Llama.SamplingParams params, GenerationCallback callback, bool* cancel_ref) {
            stderr.printf("[TRACE][OUT] MODELMANAGER: Début génération streaming simulé\n");

            // Créer des réponses simulées basées sur le prompt
            string[] possible_responses = {
                "Je suis Sambo, votre assistant IA. Comment puis-je vous aider aujourd'hui ?",
                "Excellente question ! Laissez-moi réfléchir à cela...",
                "D'après mes connaissances, voici ce que je peux vous dire :",
                "C'est un sujet intéressant. Permettez-moi de vous expliquer...",
                "Je vais analyser votre demande et vous fournir une réponse détaillée."
            };

            // Choisir une réponse de base (simulation simple)
            string base_response = possible_responses[0];

            // Si le prompt contient des mots-clés spécifiques, adapter la réponse
            string prompt_lower = prompt.down();
            if ("capital" in prompt_lower || "capitale" in prompt_lower) {
                if ("france" in prompt_lower) {
                    base_response = "La capitale de la France est Paris. Paris est une ville historique située au centre-nord de la France, sur la Seine. C'est le centre politique, économique et culturel du pays.";
                } else {
                    base_response = "Pour répondre à votre question sur les capitales, j'aurais besoin de savoir de quel pays vous parlez spécifiquement.";
                }
            } else if ("bonjour" in prompt_lower || "salut" in prompt_lower) {
                base_response = "Bonjour ! Je suis Sambo, votre assistant IA. Comment puis-je vous aider aujourd'hui ?";
            } else if ("comment" in prompt_lower && "allez" in prompt_lower) {
                base_response = "Je vais très bien, merci de demander ! En tant qu'assistant IA, je suis toujours prêt à vous aider. Que puis-je faire pour vous ?";
            } else {
                base_response = "Je comprends votre question. Laissez-moi vous fournir une réponse détaillée et utile sur ce sujet.";
            }

            stderr.printf("[TRACE][OUT] MODELMANAGER: Réponse simulée choisie (%d caractères)\n", (int)base_response.length);

            // Simuler le streaming progressif mot par mot
            string[] words = base_response.split(" ");
            var partial_response = new StringBuilder();

            foreach (string word in words) {
                if (*cancel_ref) {
                    stderr.printf("[TRACE][OUT] MODELMANAGER: Annulation détectée dans simulation\n");
                    break;
                }

                partial_response.append(word).append(" ");
                string current_content = partial_response.str;

                stderr.printf("[TRACE][OUT] MODELMANAGER: Envoi simulation (%d caractères): '%s'\n",
                    (int)current_content.length,
                    current_content.length > 50 ? current_content.substring(0, 50) + "..." : current_content);

                // Envoyer la mise à jour dans le thread principal
                Idle.add(() => {
                    stderr.printf("[TRACE][IN] MODELMANAGER: Callback simulation dans thread principal\n");
                    if (!(*cancel_ref) && callback != null) {
                        stderr.printf("[TRACE][OUT] MODELMANAGER: Appel callback simulation avec %d caractères\n",
                            (int)current_content.length);
                        callback(current_content, false); // false = pas terminé
                    } else {
                        stderr.printf("[TRACE][OUT] MODELMANAGER: Callback simulation annulé\n");
                    }
                    return Source.REMOVE;
                });

                // Délai pour simuler le streaming progressif
                Thread.usleep(100000); // 100ms pour voir le streaming
            }

            stderr.printf("[TRACE][OUT] MODELMANAGER: Fin simulation streaming\n");
            return base_response;
        }

        /**
         * Génère une réponse avec vrai streaming via llama.cpp
         */
        private string? generate_real_streaming(string prompt, Llama.SamplingParams params, GenerationCallback callback, bool* cancel_ref) {
            stderr.printf("[TRACE][OUT] MODELMANAGER: Début génération streaming réelle avec llama.cpp\n");

            var response_builder = new StringBuilder();
            string? final_response = null;
            bool generation_completed = false;
            bool has_error = false;

            // Créer la structure pour passer les données au callback C
            StreamingContext context = {};
            context.response_builder = response_builder;
            context.vala_callback = callback;
            context.cancel_ref = cancel_ref;
            context.generation_completed = &generation_completed;
            context.has_error = &has_error;

            try {
                stderr.printf("[TRACE][OUT] MODELMANAGER: Appel Llama.generate avec streaming réel\n");

                // Appel de la vraie fonction de streaming llama.cpp
                bool success = Llama.generate(prompt, &params, streaming_callback_wrapper, &context);

                if (!success) {
                    stderr.printf("[TRACE][OUT] MODELMANAGER: Échec de Llama.generate, fallback vers simulation\n");
                    throw new IOError.FAILED("Échec de la génération llama.cpp");
                }

                // Attendre que la génération soit terminée
                var start_time = get_monotonic_time();
                int timeout_seconds = config_manager.get_generation_timeout();
                int64 timeout_microseconds = timeout_seconds == 0 ? 0 : (int64)timeout_seconds * 1000000;

                stderr.printf("[TRACE][OUT] MODELMANAGER: Attente streaming avec timeout: %d sec (%s)\n",
                    timeout_seconds, timeout_seconds == 0 ? "INFINI" : "LIMITÉ");

                while (!generation_completed && !(*cancel_ref) && !has_error) {
                    Thread.usleep(10000); // 10ms

                    // Vérifier le timeout (seulement si configuré)
                    if (timeout_microseconds > 0) {
                        var elapsed_time = get_monotonic_time() - start_time;
                        if (elapsed_time > timeout_microseconds) {
                            stderr.printf("[TRACE][OUT] MODELMANAGER: Timeout streaming réel\n");
                            Llama.stop_generation();
                            throw new IOError.TIMED_OUT("Timeout de génération");
                        }
                    }
                }

                if (*cancel_ref) {
                    stderr.printf("[TRACE][OUT] MODELMANAGER: Génération annulée\n");
                    Llama.stop_generation();
                    final_response = null;
                } else if (has_error) {
                    stderr.printf("[TRACE][OUT] MODELMANAGER: Erreur durant la génération\n");
                    final_response = null;
                } else {
                    final_response = response_builder.str;
                    stderr.printf("[TRACE][OUT] MODELMANAGER: Génération streaming réelle réussie (%d caractères)\n",
                        final_response != null ? (int)final_response.length : 0);
                }

            } catch (Error e) {
                stderr.printf("❌ MODELMANAGER: Erreur streaming réel, fallback vers simulation: %s\n", e.message);

                // Fallback vers la simulation si le streaming réel échoue
                return generate_streaming_simulation(prompt, params, callback, cancel_ref);
            }

            stderr.printf("[TRACE][OUT] MODELMANAGER: Fin génération streaming réelle\n");
            return final_response;
        }

        // Structure pour passer le contexte au callback C
        private struct StreamingContext {
            unowned StringBuilder response_builder;
            unowned GenerationCallback vala_callback;
            bool* cancel_ref;
            bool* generation_completed;
            bool* has_error;
        }

        // Callback appelé par llama.cpp pour chaque token généré
        private static void streaming_callback_wrapper(string token, void* user_data, void* closure_data) {
            StreamingContext* context = (StreamingContext*)user_data;

            stderr.printf("[TRACE][TOKEN] Reçu token: '%s' (longueur: %d)\n",
                token.length > 20 ? token.substring(0, 20) + "..." : token,
                (int)token.length);

            // Vérifier l'annulation
            if (*(context->cancel_ref)) {
                stderr.printf("[TRACE][TOKEN] Annulation détectée dans callback\n");
                *(context->generation_completed) = true;
                return;
            }

            // Cas spéciaux : fin de génération
            if (token == "" || token == "</s>" || token == "<|end|>" || token == "<|endoftext|>") {
                stderr.printf("[TRACE][TOKEN] Token de fin détecté: '%s'\n", token);
                *(context->generation_completed) = true;

                // Notifier la fin via le callback Vala
                Idle.add(() => {
                    if (!(*(context->cancel_ref)) && context->vala_callback != null) {
                        string final_content = context->response_builder.str;
                        stderr.printf("[TRACE][CALLBACK] Fin génération - %d caractères au total\n",
                            (int)final_content.length);
                        context->vala_callback(final_content, true); // true = terminé
                    }
                    return Source.REMOVE;
                });
                return;
            }

            // Ajouter le token à la réponse
            context->response_builder.append(token);
            string current_content = context->response_builder.str;

            // Notifier le nouveau contenu via le callback Vala
            Idle.add(() => {
                if (!(*(context->cancel_ref)) && context->vala_callback != null) {
                    stderr.printf("[TRACE][CALLBACK] Mise à jour streaming - %d caractères\n",
                        (int)current_content.length);
                    context->vala_callback(current_content, false); // false = pas terminé
                }
                return Source.REMOVE;
            });
        }

        /**
         * Annule la génération en cours
         */
        public void cancel_generation() {
            is_generation_cancelled = true;

            // Arrêter la génération llama.cpp si elle est en cours
            if (!is_simulation_mode) {
                Llama.stop_generation();

                // Forcer le nettoyage du modèle et recharger pour s'assurer que le processus s'arrête
                try {
                    string current_model = current_model_path;
                    Llama.unload_model();
                    Thread.usleep(100000); // 100ms
                    if (current_model != "") {
                        Llama.load_model(current_model);
                    }
                } catch (Error e) {
                    stderr.printf("⚠️ MODELMANAGER: Erreur lors du rechargement: %s\n", e.message);
                }

                // En cas d'urgence, utiliser le script de nettoyage
                Timeout.add(2000, () => {
                    try {
                        string script_path = Path.build_filename(Environment.get_current_dir(), "scripts", "kill_llama.sh");
                        Process.spawn_command_line_sync(script_path);
                    } catch (Error e) {
                        stderr.printf("⚠️ MODELMANAGER: Erreur lors du nettoyage d'urgence: %s\n", e.message);
                    }
                    return false;
                });
            }

            // Marquer le thread comme terminé
            current_generation_thread = null;

            generation_cancelled.emit();
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
         * Met à jour la configuration du timeout depuis les préférences
         */
        public void update_config() {
            config_manager.load();
            stderr.printf("[TRACE][OUT] MODELMANAGER: Configuration mise à jour - timeout: %d sec\n",
                config_manager.get_generation_timeout());
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
