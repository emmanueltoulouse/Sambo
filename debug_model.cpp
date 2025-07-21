#include <iostream>
#include <cstdio>
#include "src/sambo_llama_wrapper.h"

int main() {
    std::cout << "=== Test de chargement du modèle ===" << std::endl;
    
    // Initialiser le backend
    gboolean init_result = sambo_llama_backend_init();
    std::cout << "Initialisation du backend: " << (init_result ? "SUCCESS" : "FAILED") << std::endl;
    
    // Chemin du modèle 
    const char* model_path = "/home/emmanuel/Modeles/bartowski/Llama-3.2-3B-Instruct-GGUF/Llama-3.2-3B-Instruct-Q8_0.gguf";
    std::cout << "Tentative de chargement: " << model_path << std::endl;
    
    // Tenter le chargement
    gboolean load_result = sambo_llama_load_model(model_path);
    std::cout << "Chargement du modèle: " << (load_result ? "SUCCESS" : "FAILED") << std::endl;
    
    // Vérifier si vraiment chargé
    gboolean is_loaded = sambo_llama_is_model_loaded();
    std::cout << "Modèle vraiment chargé: " << (is_loaded ? "YES" : "NO") << std::endl;
    
    // Nettoyer
    sambo_llama_cleanup();
    
    return 0;
}
