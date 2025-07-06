#ifndef SAMBO_LLAMA_WRAPPER_H
#define SAMBO_LLAMA_WRAPPER_H

#include <glib.h>

G_BEGIN_DECLS

/**
 * Interface C simple pour llama.cpp compatible avec Vala
 */

// Fonctions de base (déjà implémentées)
gboolean sambo_llama_backend_init();
void sambo_llama_backend_free();

gboolean sambo_llama_load_model(const gchar* model_path);
void sambo_llama_unload_model();
gboolean sambo_llama_is_model_loaded();

void sambo_llama_cleanup();

// Structure pour les paramètres de sampling
typedef struct {
    gfloat temperature;
    gfloat top_p;
    gint top_k;
    gint max_tokens;
    gfloat repetition_penalty;
    gfloat frequency_penalty;
    gfloat presence_penalty;
    gint seed;
    gint context_length;
    gboolean stream;
} SamboSamplingParams;

// Callback pour le streaming
typedef void (*sambo_stream_callback)(const gchar* token, gpointer user_data);

// Callback pour le streaming avec signature compatible Vala
typedef void (*sambo_vala_stream_callback)(const gchar* token, gpointer user_data, gpointer closure_data);

// Fonctions d'inférence
gboolean sambo_llama_generate(
    const gchar* prompt,
    SamboSamplingParams* params,
    sambo_vala_stream_callback callback,
    gpointer user_data
);

gchar* sambo_llama_generate_simple(
    const gchar* prompt,
    SamboSamplingParams* params
);

void sambo_llama_stop_generation();

G_END_DECLS

#endif // SAMBO_LLAMA_WRAPPER_H
