/* llama.vapi - Interface simplifiée pour llama.cpp via wrapper C
 *
 * API simplifiée utilisant un wrapper C pour éviter les problèmes de bindings
 */

[CCode (cheader_filename = "sambo_llama_wrapper.h")]
namespace Llama {

    // Configuration optimisée du backend
    [CCode (cname = "sambo_llama_backend_init_optimized")]
    public static bool backend_init_optimized(int n_threads, int batch_size, bool enable_mmap, bool enable_mlock);

    [CCode (cname = "sambo_llama_get_optimal_threads")]
    public static int get_optimal_threads();

    [CCode (cname = "sambo_llama_configure_performance")]
    public static void configure_performance(int n_threads, int batch_size, bool gpu_offload);

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

    // Structure pour les paramètres de sampling
    [CCode (cname = "SamboSamplingParams")]
    public struct SamplingParams {
        public float temperature;
        public float top_p;
        public int top_k;
        public int max_tokens;
        public float repetition_penalty;
        public float frequency_penalty;
        public float presence_penalty;
        public int seed;
        public int context_length;
        public bool stream;
    }

    // Callback pour le streaming
    [CCode (cname = "sambo_vala_stream_callback", has_target = false)]
    public delegate void StreamCallback(string token, void* user_data, void* closure_data);

    // Fonctions d'inférence
    [CCode (cname = "sambo_llama_generate")]
    public static bool generate(string prompt, SamplingParams* params, StreamCallback callback, void* user_data);

    [CCode (cname = "sambo_llama_generate_simple")]
    public static string? generate_simple(string prompt, SamplingParams* params);

    [CCode (cname = "sambo_llama_stop_generation")]
    public static void stop_generation();
}
