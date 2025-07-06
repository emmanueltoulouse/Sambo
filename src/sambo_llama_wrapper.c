#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <glib.h>
#include "sambo_llama_wrapper.h"

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
    context_params.n_ctx = 512;  // Contexte de 512 tokens par défaut
    struct llama_context* context = llama_init_from_model(model, context_params);

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
    // Mode simulation sans llama.cpp
    g_print("Mode simulation : chargement simulé du modèle %s\n", model_path);

    // Marquer comme chargé même en simulation
    g_llama_wrapper->model = NULL;     // Pas de modèle réel
    g_llama_wrapper->context = NULL;   // Pas de contexte réel
    g_llama_wrapper->is_loaded = TRUE; // Mais marqué comme chargé pour la simulation

    g_print("Modèle simulé chargé avec succès : %s\n", model_path);
    return TRUE;
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

// Variables globales pour le contrôle de génération
static gboolean g_generation_active = FALSE;
static gboolean g_stop_generation = FALSE;

/**
 * Arrête la génération en cours
 */
void sambo_llama_stop_generation() {
    g_stop_generation = TRUE;
}

/**
 * Callback interne pour collecter le texte en mode simple
 */
static void collect_tokens_callback(const gchar* token, gpointer user_data, gpointer closure_data) {
    (void)closure_data; // Paramètre non utilisé
    GString* str = (GString*)user_data;
    g_string_append(str, token);
}

/**
 * Génère du texte avec streaming
 * @param prompt Le prompt d'entrée
 * @param params Paramètres de sampling
 * @param callback Fonction de callback pour le streaming (peut être NULL)
 * @param user_data Données utilisateur pour le callback
 * @return TRUE si succès, FALSE sinon
 */
gboolean sambo_llama_generate(
    const gchar* prompt,
    SamboSamplingParams* params,
    sambo_vala_stream_callback callback,
    gpointer user_data
) {
    if (!prompt || !sambo_llama_is_model_loaded()) {
        g_warning("Modèle non chargé ou prompt invalide\n");
        return FALSE;
    }

    if (g_generation_active) {
        g_warning("Une génération est déjà en cours\n");
        return FALSE;
    }

    g_generation_active = TRUE;
    g_stop_generation = FALSE;

#ifdef HAVE_LLAMA_CPP
    // Implémentation réelle avec llama.cpp
    g_print("Démarrage de la génération avec llama.cpp...\n");

    struct llama_model* model = (struct llama_model*)g_llama_wrapper->model;
    struct llama_context* context = (struct llama_context*)g_llama_wrapper->context;

    if (!model || !context) {
        g_warning("Modèle ou contexte non valide\n");
        g_generation_active = FALSE;
        return FALSE;
    }

    // Obtenir le vocabulaire depuis le modèle
    const struct llama_vocab* vocab = llama_model_get_vocab(model);

    // Allouer un buffer pour les tokens
    int max_tokens_prompt = strlen(prompt) + 256; // estimation large
    llama_token* tokens = g_malloc(sizeof(llama_token) * max_tokens_prompt);

    // Tokeniser le prompt
    int n_tokens = llama_tokenize(vocab, prompt, strlen(prompt), tokens, max_tokens_prompt, true, true);
    if (n_tokens < 0) {
        g_warning("Erreur lors de la tokenisation du prompt\n");
        g_free(tokens);
        g_generation_active = FALSE;
        return FALSE;
    }

    g_print("Prompt tokenisé : %d tokens\n", n_tokens);

    // Créer un batch pour traiter le prompt
    struct llama_batch batch = llama_batch_init(512, 0, 1);

    // Ajouter tous les tokens du prompt au batch
    for (int i = 0; i < n_tokens; i++) {
        batch.token[i] = tokens[i];
        batch.pos[i] = i;
        batch.n_seq_id[i] = 1;
        batch.seq_id[i][0] = 0;
        batch.logits[i] = false;
    }
    batch.n_tokens = n_tokens;

    // Le dernier token peut générer la sortie
    if (batch.n_tokens > 0) {
        batch.logits[batch.n_tokens - 1] = true;
    }

    // Traiter le prompt
    if (llama_decode(context, batch) != 0) {
        g_warning("Erreur lors du décodage du prompt\n");
        llama_batch_free(batch);
        g_free(tokens);
        g_generation_active = FALSE;
        return FALSE;
    }

    // Générer la réponse token par token
    int n_generated = 0;
    int n_ctx = llama_n_ctx(context);

    while (n_generated < params->max_tokens && !g_stop_generation) {
        // Obtenir les logits du dernier token
        float* logits = llama_get_logits_ith(context, batch.n_tokens - 1);
        if (!logits) {
            g_warning("Erreur : impossible d'obtenir les logits\n");
            break;
        }

        // Sampling simple : prendre le token avec la plus haute probabilité
        int n_vocab = llama_vocab_n_tokens(vocab);
        llama_token new_token = 0;
        float max_logit = logits[0];

        for (int i = 1; i < n_vocab; i++) {
            if (logits[i] > max_logit) {
                max_logit = logits[i];
                new_token = i;
            }
        }

        // Vérifier si c'est un token de fin de génération
        if (llama_vocab_is_eog(vocab, new_token)) {
            g_print("Token EOS rencontré, fin de génération\n");
            break;
        }

        // Convertir le token en texte
        char token_str[256];
        int token_len = llama_token_to_piece(vocab, new_token, token_str, sizeof(token_str), 0, true);
        if (token_len > 0) {
            token_str[token_len] = '\0';

            // Appeler le callback si fourni
            if (callback) {
                callback(token_str, user_data, NULL);
            }

            g_print("%s", token_str); // Debug : afficher le token généré
        }

        // Préparer le batch pour le prochain token
        batch.n_tokens = 0;
        batch.token[0] = new_token;
        batch.pos[0] = n_tokens + n_generated;
        batch.n_seq_id[0] = 1;
        batch.seq_id[0][0] = 0;
        batch.logits[0] = true;
        batch.n_tokens = 1;

        // Vérifier si on dépasse la limite du contexte
        if (n_tokens + n_generated >= n_ctx - 1) {
            g_warning("Limite de contexte atteinte\n");
            break;
        }

        // Décoder le nouveau token
        if (llama_decode(context, batch) != 0) {
            g_warning("Erreur lors du décodage du token %d\n", new_token);
            break;
        }

        n_generated++;
    }

    g_print("\n"); // Nouvelle ligne après la génération

    // Nettoyage
    llama_batch_free(batch);
    g_free(tokens);
    g_generation_active = FALSE;

    g_print("Génération terminée : %d tokens générés\n", n_generated);
    return TRUE;

#else
    // Mode simulation sans llama.cpp
    g_print("Mode simulation : génération pour prompt '%s'\n", prompt);

    const char* simulation_tokens[] = {
        "Voici", " une", " réponse", " simulée", " pour", " votre", " prompt", ".",
        " Cette", " réponse", " est", " générée", " sans", " llama.cpp", " pour",
        " tester", " l'interface", " utilisateur", ".", " Les", " paramètres",
        " utilisés", " sont", ":", " température=", NULL
    };

    gchar* temp_str = g_strdup_printf("%.1f", params->temperature);

    for (int i = 0; simulation_tokens[i] != NULL && !g_stop_generation; i++) {
        if (callback) {
            callback(simulation_tokens[i], user_data, NULL);
        }

        if (params->stream) {
            g_usleep(50000); // 50ms entre tokens pour simulation réaliste
        }
    }

    if (callback && !g_stop_generation) {
        callback(temp_str, user_data, NULL);
        callback(".", user_data, NULL);
    }

    g_free(temp_str);
    g_generation_active = FALSE;
    return TRUE;
#endif
}

/**
 * Génère du texte de manière synchrone (sans streaming)
 * @param prompt Le prompt d'entrée
 * @param params Paramètres de sampling
 * @return Le texte généré (à libérer avec g_free) ou NULL en cas d'erreur
 */
gchar* sambo_llama_generate_simple(
    const gchar* prompt,
    SamboSamplingParams* params
) {
    if (!prompt || !sambo_llama_is_model_loaded()) {
        return NULL;
    }

    GString* result = g_string_new("");

    // Désactiver le streaming pour la génération simple
    SamboSamplingParams simple_params = *params;
    simple_params.stream = FALSE;

    gboolean success = sambo_llama_generate(prompt, &simple_params, collect_tokens_callback, result);

    if (success) {
        return g_string_free(result, FALSE); // Retourner le contenu
    } else {
        g_string_free(result, TRUE); // Libérer et retourner NULL
        return NULL;
    }
}
