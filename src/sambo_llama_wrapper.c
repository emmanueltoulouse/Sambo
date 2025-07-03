#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <glib.h>

// Header llama.cpp optionnel - détecté à la compilation
#ifdef HAVE_LLAMA_CPP
#include <llama.h>
#endif

/**
 * Interface C simple pour llama.cpp compatible avec Vala
 */

typedef struct {
    gpointer model;      // pointeur vers llama_model
    gpointer context;    // pointeur vers llama_context
    gboolean is_loaded;
} SamboLlamaWrapper;

// Instance globale (singleton simple)
static SamboLlamaWrapper* g_llama_wrapper = NULL;

// Déclarations anticipées
void sambo_llama_unload_model();

/**
 * Initialise le backend llama.cpp
 * @return TRUE si succès, FALSE sinon
 */
gboolean sambo_llama_backend_init() {
#ifdef HAVE_LLAMA_CPP
    llama_backend_init();
    g_print("Backend llama.cpp initialisé avec succès\n");
    return TRUE;
#else
    g_warning("llama.cpp non disponible à la compilation\n");
    return FALSE;
#endif
}

/**
 * Libère le backend llama.cpp
 */
void sambo_llama_backend_free() {
#ifdef HAVE_LLAMA_CPP
    llama_backend_free();
    g_print("Backend llama.cpp libéré\n");
#endif
}

/**
 * Charge un modèle depuis un fichier
 * @param model_path Chemin vers le fichier modèle
 * @return TRUE si succès, FALSE sinon
 */
gboolean sambo_llama_load_model(const gchar* model_path) {
    if (!model_path) {
        g_warning("Chemin de modèle invalide\n");
        return FALSE;
    }
    
    // Créer le wrapper s'il n'existe pas
    if (!g_llama_wrapper) {
        g_llama_wrapper = g_malloc0(sizeof(SamboLlamaWrapper));
    }
    
    // Libérer le modèle précédent s'il existe
    sambo_llama_unload_model();
    
#ifdef HAVE_LLAMA_CPP
    // Charger le modèle avec llama.cpp
    struct llama_model_params model_params = llama_model_default_params();
    struct llama_model* model = llama_model_load_from_file(model_path, model_params);
    
    if (!model) {
        g_warning("Échec du chargement du modèle : %s\n", model_path);
        return FALSE;
    }
    
    // Créer le contexte
    struct llama_context_params context_params = llama_context_default_params();
    struct llama_context* context = llama_new_context_with_model(model, context_params);
    
    if (!context) {
        llama_model_free(model);
        g_warning("Échec de la création du contexte pour : %s\n", model_path);
        return FALSE;
    }
    
    // Stocker dans le wrapper
    g_llama_wrapper->model = model;
    g_llama_wrapper->context = context;
    g_llama_wrapper->is_loaded = TRUE;
    
    g_print("Modèle chargé avec succès : %s\n", model_path);
    return TRUE;
#else
    g_warning("llama.cpp non disponible, impossible de charger le modèle\n");
    return FALSE;
#endif
}

/**
 * Décharge le modèle actuel
 */
void sambo_llama_unload_model() {
    if (!g_llama_wrapper || !g_llama_wrapper->is_loaded) {
        return;
    }
    
#ifdef HAVE_LLAMA_CPP
    if (g_llama_wrapper->context) {
        llama_free((struct llama_context*)g_llama_wrapper->context);
        g_llama_wrapper->context = NULL;
    }
    
    if (g_llama_wrapper->model) {
        llama_model_free((struct llama_model*)g_llama_wrapper->model);
        g_llama_wrapper->model = NULL;
    }
#endif
    
    g_llama_wrapper->is_loaded = FALSE;
    g_print("Modèle déchargé\n");
}

/**
 * Vérifie si un modèle est chargé
 * @return TRUE si un modèle est chargé
 */
gboolean sambo_llama_is_model_loaded() {
    return g_llama_wrapper && g_llama_wrapper->is_loaded;
}

/**
 * Nettoie toutes les ressources
 */
void sambo_llama_cleanup() {
    sambo_llama_unload_model();
    
    if (g_llama_wrapper) {
        g_free(g_llama_wrapper);
        g_llama_wrapper = NULL;
    }
}
