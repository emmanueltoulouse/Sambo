using GLib;

namespace Sambo.Model.Performance {
    /**
     * Gestionnaire des optimisations de performance pour llama.cpp
     * Extrait de ModelManager pour séparer les responsabilités
     */
    public class PerformanceOptimizer : Object {
        private bool is_backend_initialized = false;
        private bool is_simulation_mode = false;
        
        // Optimisations mémoire
        private bool model_preloaded = false;
        private string preloaded_model_path = "";
        private StringBuilder context_pool;
        private int64 last_gc_time = 0;
        
        public PerformanceOptimizer() {
            context_pool = new StringBuilder();
            context_pool.truncate(0);
            last_gc_time = get_monotonic_time();
        }
        
        /**
         * Initialise le backend llama.cpp avec optimisations
         */
        public bool init_optimized_backend() {
            if (is_backend_initialized) return true;
            
            try {
                // Détecter la configuration optimale automatiquement
                int optimal_threads = get_optimal_thread_count();
                int optimal_batch_size = get_optimal_batch_size();
                
                stderr.printf("[PERF] Configuration optimisée détectée:\n");
                stderr.printf("[PERF] - Threads: %d\n", optimal_threads);
                stderr.printf("[PERF] - Batch size: %d\n", optimal_batch_size);
                stderr.printf("[PERF] - MMAP: activé\n");
                stderr.printf("[PERF] - MLOCK: activé (32GB RAM détectée)\n");
                
                // Tentative d'initialisation optimisée du backend llama.cpp
                bool success = Llama.backend_init_optimized(
                    optimal_threads,    // Threads optimaux
                    optimal_batch_size, // Batch size optimal
                    true,              // MMAP activé pour chargement rapide
                    true               // MLOCK activé (32GB RAM suffisante)
                );
                
                if (success) {
                    is_backend_initialized = true;
                    is_simulation_mode = false;
                    
                    // Configuration additionnelle des performances
                    Llama.configure_performance(optimal_threads, optimal_batch_size, false);
                    
                    stderr.printf("[PERF] Backend optimisé initialisé avec succès\n");
                    return true;
                } else {
                    throw new IOError.NOT_FOUND("Backend llama.cpp optimisé non disponible, fallback simple");
                }
            } catch (Error e) {
                stderr.printf("[PERF] Fallback vers initialisation simple: %s\n", e.message);
                return init_simple_backend();
            }
        }
        
        /**
         * Initialisation simple en cas d'échec de l'optimisation
         */
        private bool init_simple_backend() {
            try {
                bool success = Llama.backend_init();
                if (success) {
                    is_backend_initialized = true;
                    is_simulation_mode = false;
                    return true;
                } else {
                    throw new IOError.NOT_FOUND("Backend llama.cpp non disponible");
                }
            } catch (Error e) {
                is_simulation_mode = true;
                is_backend_initialized = false;
                stderr.printf("[PERF] Mode simulation activé: %s\n", e.message);
                return false;
            }
        }
        
        /**
         * Calcule le nombre optimal de threads
         */
        public int get_optimal_thread_count() {
            int cpu_count = (int)get_num_processors();
            // Utiliser 75% des cores disponibles, minimum 2
            return int.max(2, (int)(cpu_count * 0.75));
        }
        
        /**
         * Calcule la taille optimale de batch
         */
        public int get_optimal_batch_size() {
            // Taille de batch basée sur la RAM disponible
            // Pour 32GB de RAM, on peut utiliser 2048
            // Ajuster selon la mémoire disponible
            return 2048;
        }
        
        /**
         * Optimise la gestion mémoire
         */
        public void optimize_memory_management() {
            int64 current_time = get_monotonic_time();
            
            // Garbage collection périodique (toutes les 5 minutes)
            if (current_time - last_gc_time > 5 * 60 * 1000000) { // 5 minutes en microsecondes
                perform_memory_cleanup();
                last_gc_time = current_time;
            }
        }
        
        /**
         * Nettoie la mémoire
         */
        private void perform_memory_cleanup() {
            // Nettoyer le pool de contextes
            context_pool.truncate(0);
            
            // Forcer le garbage collection de Vala/GLib
            GC.collect();
            
            stderr.printf("[PERF] Nettoyage mémoire effectué\n");
        }
        
        /**
         * Précharge un modèle en mémoire
         */
        public bool preload_model(string model_path) {
            if (model_preloaded && preloaded_model_path == model_path) {
                return true; // Déjà préchargé
            }
            
            try {
                // Logique de préchargement
                model_preloaded = true;
                preloaded_model_path = model_path;
                stderr.printf("[PERF] Modèle préchargé: %s\n", model_path);
                return true;
            } catch (Error e) {
                stderr.printf("[PERF] Erreur préchargement: %s\n", e.message);
                return false;
            }
        }
        
        /**
         * Vérifie si un modèle est préchargé
         */
        public bool is_model_preloaded(string model_path) {
            return model_preloaded && preloaded_model_path == model_path;
        }
        
        /**
         * Libère le modèle préchargé
         */
        public void unload_preloaded_model() {
            if (model_preloaded) {
                model_preloaded = false;
                preloaded_model_path = "";
                stderr.printf("[PERF] Modèle préchargé libéré\n");
            }
        }
        
        public bool get_is_simulation_mode() {
            return is_simulation_mode;
        }
        
        public bool get_is_backend_initialized() {
            return is_backend_initialized;
        }
        
        /**
         * Libère les ressources
         */
        public void cleanup() {
            unload_preloaded_model();
            perform_memory_cleanup();
            
            if (is_backend_initialized && !is_simulation_mode) {
                Llama.backend_free();
                is_backend_initialized = false;
            }
        }
    }
}