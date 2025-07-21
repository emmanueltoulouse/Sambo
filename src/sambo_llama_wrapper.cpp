#include "sambo_llama_wrapper.h"
#include <thread>
#include <cstdlib>
#include <glib.h>
#include <string>
#include <vector>
#include <memory>

// Inclure les headers de llama.cpp
#ifdef HAVE_LLAMA_CPP
#include "llama.h"
#include "ggml.h"
#endif

// Variables globales pour gérer l'état de llama.cpp
#ifdef HAVE_LLAMA_CPP
static llama_model* g_model = nullptr;
static llama_context* g_context = nullptr;
static bool g_backend_initialized = false;
static volatile bool g_generation_stopped = false;
#endif

extern "C" {

// Fonctions de base
gboolean sambo_llama_backend_init() {
#ifdef HAVE_LLAMA_CPP
    g_debug("HAVE_LLAMA_CPP is defined during compilation");
    if (g_backend_initialized) {
        return TRUE;
    }
    
    llama_backend_init();
    g_backend_initialized = true;
    g_debug("llama.cpp backend initialized");
    return TRUE;
#else
    g_debug("HAVE_LLAMA_CPP is NOT defined during compilation - using simulation mode");
    g_debug("llama.cpp not available - using simulation mode");
    return TRUE;
#endif
}

void sambo_llama_backend_free() {
#ifdef HAVE_LLAMA_CPP
    if (g_context) {
        llama_free(g_context);
        g_context = nullptr;
    }
    if (g_model) {
        llama_model_free(g_model);
        g_model = nullptr;
    }
    if (g_backend_initialized) {
        llama_backend_free();
        g_backend_initialized = false;
    }
    g_debug("llama.cpp backend freed");
#else
    g_debug("llama.cpp not available - simulation mode cleanup");
#endif
}

// Fonctions d'optimisation
gboolean sambo_llama_backend_init_optimized(gint n_threads, gint batch_size, gboolean enable_mmap, gboolean enable_mlock) {
#ifdef HAVE_LLAMA_CPP
    g_debug("HAVE_LLAMA_CPP is defined during compilation - optimized init");
    g_debug("Backend init optimized: threads=%d, batch_size=%d, mmap=%s, mlock=%s", 
            n_threads, batch_size, enable_mmap ? "true" : "false", enable_mlock ? "true" : "false");
    
    // Initialiser le backend avec les paramètres optimisés
    llama_backend_init();
    g_backend_initialized = true;
    
    return TRUE;
#else
    g_debug("HAVE_LLAMA_CPP is NOT defined during compilation - optimized init simulation mode");
    g_debug("llama.cpp not available - using simulation mode");
    return sambo_llama_backend_init();
#endif
}

gint sambo_llama_get_optimal_threads() {
#ifdef HAVE_LLAMA_CPP
    // Retourne le nombre de threads CPU disponibles
    int cpu_threads = (int)std::thread::hardware_concurrency();
    // Limiter à un nombre raisonnable pour l'inférence
    return std::min(cpu_threads, 8);
#else
    return (gint)std::thread::hardware_concurrency();
#endif
}

void sambo_llama_configure_performance(gint n_threads, gint batch_size, gboolean gpu_offload) {
    g_debug("Configure performance: threads=%d, batch_size=%d, gpu_offload=%s", 
            n_threads, batch_size, gpu_offload ? "true" : "false");
#ifdef HAVE_LLAMA_CPP
    // Ces paramètres seront utilisés lors du chargement du modèle
    // Pas d'action immédiate ici
#endif
}

// Gestion des modèles
gboolean sambo_llama_load_model(const gchar* model_path) {
#ifdef HAVE_LLAMA_CPP
    if (!g_backend_initialized) {
        sambo_llama_backend_init();
    }
    
    if (g_model) {
        llama_model_free(g_model);
        g_model = nullptr;
    }
    if (g_context) {
        llama_free(g_context);
        g_context = nullptr;
    }
    
    // Paramètres par défaut pour le modèle
    llama_model_params model_params = llama_model_default_params();
    model_params.n_gpu_layers = 0; // CPU seulement pour l'instant
    
    g_debug("Loading model: %s", model_path);
    g_model = llama_model_load_from_file(model_path, model_params);
    
    if (!g_model) {
        g_warning("Failed to load model: %s", model_path);
        return FALSE;
    }
    g_debug("Model loaded successfully into g_model: %p", (void*)g_model);
    
    // Créer le contexte
    llama_context_params ctx_params = llama_context_default_params();
    ctx_params.n_ctx = 2048; // Contexte par défaut
    ctx_params.n_threads = sambo_llama_get_optimal_threads();
    ctx_params.n_threads_batch = ctx_params.n_threads;
    
    g_context = llama_init_from_model(g_model, ctx_params);
    
    if (!g_context) {
        g_warning("Failed to create context for model: %s", model_path);
        llama_model_free(g_model);
        g_model = nullptr;
        return FALSE;
    }
    g_debug("Context created successfully: %p", (void*)g_context);
    
    g_debug("Model loaded successfully: %s", model_path);
    return TRUE;
#else
    g_debug("Simulation: Loading model: %s", model_path);
    return TRUE;
#endif
}

void sambo_llama_unload_model() {
#ifdef HAVE_LLAMA_CPP
    if (g_context) {
        llama_free(g_context);
        g_context = nullptr;
    }
    if (g_model) {
        llama_model_free(g_model);
        g_model = nullptr;
    }
    g_debug("Model unloaded");
#else
    g_debug("Simulation: Unloading model");
#endif
}

gboolean sambo_llama_is_model_loaded() {
#ifdef HAVE_LLAMA_CPP
    // Retourner le vrai état : modèle ET contexte doivent être chargés
    bool real_state = (g_model != nullptr && g_context != nullptr);
    g_debug("Real model state check: model=%s, context=%s, result=%s",
            g_model ? "loaded" : "null",
            g_context ? "loaded" : "null", 
            real_state ? "true" : "false");
    return real_state;
#else
    g_debug("Simulation mode: model always reports as not loaded");
    return FALSE;  // En mode simulation, le modèle n'est jamais vraiment "chargé"
#endif
}

void sambo_llama_cleanup() {
#ifdef HAVE_LLAMA_CPP
    sambo_llama_unload_model();
    sambo_llama_backend_free();
    g_debug("llama.cpp cleanup completed");
#else
    g_debug("Simulation: llama cleanup");
#endif
}

// Fonctions d'inférence
gboolean sambo_llama_generate(
    const gchar* prompt,
    SamboSamplingParams* params,
    sambo_vala_stream_callback callback,
    gpointer user_data
) {
#ifdef HAVE_LLAMA_CPP
    if (!g_model || !g_context) {
        g_warning("Model not loaded - cannot perform real inference");
        // Fallback vers simulation
        if (callback) {
            callback("Erreur: modèle non chargé. ", user_data, nullptr);
            callback("Utilisation de la simulation...", user_data, nullptr);
            callback("", user_data, nullptr);  // Signal de fin
        }
        return FALSE;
    }
    
    g_debug("Performing real inference with llama.cpp for prompt: %s", prompt);
    
    try {
        // Tokeniser le prompt avec la nouvelle API
        std::vector<llama_token> tokens;
        
        // Obtenir le vocabulaire du modèle
        const llama_vocab* vocab = llama_model_get_vocab(g_model);
        
        // Première passe pour obtenir le nombre de tokens
        const int n_prompt = -llama_tokenize(vocab, prompt, strlen(prompt), nullptr, 0, true, true);
        if (n_prompt < 0) {
            g_warning("Failed to get token count for prompt");
            return FALSE;
        }
        
        tokens.resize(n_prompt);
        const int actual_tokens = llama_tokenize(vocab, prompt, strlen(prompt), tokens.data(), tokens.size(), true, true);
        if (actual_tokens < 0) {
            g_warning("Failed to tokenize prompt");
            return FALSE;
        }
        
        g_debug("Tokenized prompt: %d tokens", actual_tokens);
        
        // Créer et remplir le batch
        llama_batch batch = llama_batch_init(tokens.size(), 0, 1);
        for (size_t i = 0; i < tokens.size(); i++) {
            batch.token[batch.n_tokens] = tokens[i];
            batch.pos[batch.n_tokens] = i;
            batch.n_seq_id[batch.n_tokens] = 1;
            batch.seq_id[batch.n_tokens][0] = 0;
            batch.logits[batch.n_tokens] = false;
            batch.n_tokens++;
        }
        
        // Marquer le dernier token pour la génération
        if (batch.n_tokens > 0) {
            batch.logits[batch.n_tokens - 1] = true;
        }
        
        // Traiter le prompt
        if (llama_decode(g_context, batch) != 0) {
            g_warning("Failed to decode prompt");
            llama_batch_free(batch);
            return FALSE;
        }
        
        g_debug("Prompt processed, starting generation...");
        
        // Paramètres de génération
        const int max_tokens = params ? params->max_tokens : 512;
        const float temperature = params ? params->temperature : 0.7f;
        const float top_p = params ? params->top_p : 0.9f;
        const int top_k = params ? params->top_k : 40;
        
        g_debug("Generation parameters: max_tokens=%d, temp=%.2f, top_p=%.2f, top_k=%d", 
                max_tokens, temperature, top_p, top_k);
        
        // Créer un sampler avec les nouveaux paramètres
        llama_sampler* sampler = llama_sampler_chain_init({});
        llama_sampler_chain_add(sampler, llama_sampler_init_top_k(top_k));
        llama_sampler_chain_add(sampler, llama_sampler_init_top_p(top_p, 1));
        llama_sampler_chain_add(sampler, llama_sampler_init_temp(temperature));
        llama_sampler_chain_add(sampler, llama_sampler_init_dist(1337));
        
        // Générer des tokens
        int n_generated = 0;
        std::string response_text;
        g_generation_stopped = false;  // Réinitialiser le flag
        
        while (n_generated < max_tokens && !g_generation_stopped) {
            // Obtenir les logits
            const float* logits = llama_get_logits_ith(g_context, batch.n_tokens - 1);
            if (!logits) {
                g_warning("Failed to get logits");
                break;
            }
            
            // Échantillonner le token avec le nouveau sampler
            llama_token new_token = llama_sampler_sample(sampler, g_context, batch.n_tokens - 1);
            
            // Vérifier si c'est un token de fin avec la nouvelle API
            if (llama_vocab_is_eog(vocab, new_token)) {
                g_debug("End of generation token reached");
                break;
            }
            
            // Vérifier si l'arrêt a été demandé
            if (g_generation_stopped) {
                g_debug("Generation stopped by user request");
                break;
            }
            
            // Convertir le token en texte
            char token_str[256];
            const int n_chars = llama_token_to_piece(vocab, new_token, token_str, sizeof(token_str), 0, false);
            if (n_chars > 0) {
                token_str[n_chars] = '\0';
                response_text += token_str;
                
                g_debug("Generated token: '%s'", token_str);
                
                // Envoyer le token via callback
                if (callback) {
                    callback(token_str, user_data, nullptr);
                }
            }
            
            // Préparer le prochain batch avec le nouveau token
            batch.n_tokens = 0;
            batch.token[batch.n_tokens] = new_token;
            batch.pos[batch.n_tokens] = tokens.size() + n_generated;
            batch.n_seq_id[batch.n_tokens] = 1;
            batch.seq_id[batch.n_tokens][0] = 0;
            batch.logits[batch.n_tokens] = true;
            batch.n_tokens++;
            
            // Décoder le nouveau token
            if (llama_decode(g_context, batch) != 0) {
                g_warning("Failed to decode generated token");
                break;
            }
            
            n_generated++;
        }
        
        llama_sampler_free(sampler);
        llama_batch_free(batch);
        
        g_debug("Generation completed: %d tokens generated, total response: %d chars", 
                n_generated, (int)response_text.length());
        
        // Envoyer le signal de fin
        if (callback) {
            callback("", user_data, nullptr);  // Signal de fin
        }
        
        return TRUE;
        
    } catch (const std::exception& e) {
        g_warning("Exception during real inference: %s", e.what());
        if (callback) {
            callback("Erreur lors de l'inférence réelle", user_data, nullptr);
            callback("", user_data, nullptr);  // Signal de fin
        }
        return FALSE;
    }
#else
    g_debug("Simulation: Generate with prompt: %s", prompt);
    
    // Simulation pour test avec signal de fin
    if (callback) {
        callback("Réponse simulée de llama.cpp", user_data, nullptr);
        callback(" en mode simulation", user_data, nullptr);
        // IMPORTANT: Envoyer le signal de fin
        callback("", user_data, nullptr);  // Token vide = fin de génération
    }
    
    return TRUE;
#endif
}

// Variables pour la génération simple (en dehors du bloc extern "C")
static std::string* g_simple_response = nullptr;
static bool g_simple_finished = false;

// Callback pour la génération simple
static void simple_generation_callback(const gchar* token, gpointer user_data, gpointer closure_data) {
    (void)user_data;    // Supprimer warning unused parameter
    (void)closure_data; // Supprimer warning unused parameter
    
    if (strlen(token) == 0) {
        // Signal de fin
        g_simple_finished = true;
    } else if (g_simple_response) {
        g_simple_response->append(token);
    }
}

gchar* sambo_llama_generate_simple(
    const gchar* prompt,
    SamboSamplingParams* params
) {
    (void)params; // Supprimer warning unused parameter
    
#ifdef HAVE_LLAMA_CPP
    if (!g_model || !g_context) {
        g_warning("Model not loaded for simple generation");
        return g_strdup("Erreur: modèle non chargé");
    }
    
    g_debug("Performing simple generation with llama.cpp");
    
    // Initialiser les variables globales
    std::string response;
    g_simple_response = &response;
    g_simple_finished = false;
    
    // Utiliser la fonction de génération avec streaming
    gboolean success = sambo_llama_generate(prompt, params, simple_generation_callback, nullptr);
    
    if (!success) {
        g_simple_response = nullptr;
        return g_strdup("Erreur lors de la génération");
    }
    
    // Attendre que la génération soit terminée (avec timeout)
    int timeout_ms = 30000;  // 30 secondes
    int elapsed_ms = 0;
    const int sleep_ms = 10;
    
    while (!g_simple_finished && elapsed_ms < timeout_ms) {
        g_usleep(sleep_ms * 1000);  // Convertir ms en µs
        elapsed_ms += sleep_ms;
    }
    
    g_simple_response = nullptr;
    
    if (!g_simple_finished) {
        g_warning("Timeout lors de la génération simple");
        return g_strdup("Timeout lors de la génération");
    }
    
    g_debug("Simple generation completed: %d characters", (int)response.length());
    return g_strdup(response.c_str());
#else
    g_debug("Simulation: Generate simple with prompt: %s", prompt);
    return g_strdup("Réponse simulée de llama.cpp (mode simulation)");
#endif
}

void sambo_llama_stop_generation() {
#ifdef HAVE_LLAMA_CPP
    g_debug("Stopping llama.cpp generation");
    g_generation_stopped = true;
    g_simple_finished = true;  // Arrêter aussi la génération simple
#else
    g_debug("Simulation: Stop generation");
#endif
}

} // extern "C"
