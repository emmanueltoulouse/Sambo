#ifndef SAMBO_LLAMA_WRAPPER_H
#define SAMBO_LLAMA_WRAPPER_H

#include <glib.h>

G_BEGIN_DECLS

/**
 * Interface C simple pour llama.cpp compatible avec Vala
 */

gboolean sambo_llama_backend_init();
void sambo_llama_backend_free();

gboolean sambo_llama_load_model(const gchar* model_path);
void sambo_llama_unload_model();
gboolean sambo_llama_is_model_loaded();

void sambo_llama_cleanup();

G_END_DECLS

#endif // SAMBO_LLAMA_WRAPPER_H
