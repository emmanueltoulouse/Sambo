#include <stdio.h>
#include <stdlib.h>

// Test simple pour vérifier la liaison
extern "C" {
#ifdef HAVE_LLAMA_CPP
#include "llama.h"
#include "ggml.h"
#endif

void test_llama_availability() {
#ifdef HAVE_LLAMA_CPP
    printf("HAVE_LLAMA_CPP is defined\n");

    // Test d'initialisation du backend
    llama_backend_init();
    printf("llama_backend_init() called successfully\n");

    // Test de chargement d'un modèle
    const char* test_model = "/home/emmanuel/Modeles/bartowski/Llama-3.2-3B-Instruct-GGUF/Llama-3.2-3B-Instruct-Q8_0.gguf";

    llama_model_params model_params = llama_model_default_params();
    model_params.n_gpu_layers = 0; // CPU seulement

    printf("Attempting to load model: %s\n", test_model);
    llama_model* model = llama_load_model_from_file(test_model, model_params);

    if (model) {
        printf("Model loaded successfully!\n");
        llama_free_model(model);
    } else {
        printf("Failed to load model\n");
    }

    llama_backend_free();
    printf("llama_backend_free() called\n");
#else
    printf("HAVE_LLAMA_CPP is NOT defined\n");
#endif
}
}

int main() {
    test_llama_availability();
    return 0;
}
