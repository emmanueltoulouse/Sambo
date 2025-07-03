/* llama.vapi - Interface simplifiée pour llama.cpp via wrapper C
 *
 * API simplifiée utilisant un wrapper C pour éviter les problèmes de bindings
 */

[CCode (cheader_filename = "sambo_llama_wrapper.h")]
namespace Llama {
    
    // Fonctions d'initialisation/finalisation du backend
    [CCode (cname = "sambo_llama_backend_init")]
    public static bool backend_init();

    [CCode (cname = "sambo_llama_backend_free")]
    public static void backend_free();

    // Gestion des modèles
    [CCode (cname = "sambo_llama_load_model")]
    public static bool load_model(string model_path);
    
    [CCode (cname = "sambo_llama_unload_model")]
    public static void unload_model();
    
    [CCode (cname = "sambo_llama_is_model_loaded")]
    public static bool is_model_loaded();
    
    [CCode (cname = "sambo_llama_cleanup")]
    public static void cleanup();
}
