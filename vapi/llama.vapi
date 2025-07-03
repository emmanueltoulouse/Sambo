/* llama.vapi - Bindings Vala pour llama.cpp
 *
 * Ce fichier sera progressivement rempli avec les bindings
 * pour l'API de llama.cpp
 */

[CCode (cheader_filename = "llama.h")]
namespace Llama {
    // TODO: Ajouter les bindings progressivement

    // Placeholder pour la compilation - fonctions de base
    [CCode (cname = "llama_backend_init")]
    public static void backend_init ();

    [CCode (cname = "llama_backend_free")]
    public static void backend_free ();

    // Chargement et libération du modèle
    [CCode (cname = "llama_model_load_from_file")]
    public static unowned Model model_load_from_file (string path_model, void* params);
    [CCode (cname = "llama_model_free")]
    public static void model_free (Model model);

    // Création et libération du contexte
    [CCode (cname = "llama_init_from_model")]
    public static unowned Context init_from_model (Model model, void* params);
    [CCode (cname = "llama_free")]
    public static void free (Context ctx);

    // Accès au vocabulaire
    [CCode (cname = "llama_model_get_vocab")]
    public static void* model_get_vocab (Model model);
    [CCode (cname = "llama_vocab_n_tokens")]
    public static int vocab_n_tokens (void* vocab);
    [CCode (cname = "llama_tokenize")]
    public static int tokenize (void* vocab, string text, int text_len, int[] tokens, int n_tokens_max, bool add_special, bool parse_special);
    [CCode (cname = "llama_detokenize")]
    public static int detokenize (void* vocab, int[] tokens, int n_tokens, string text, int text_len_max, bool remove_special, bool unparse_special);

    // Fonctions LoRA
    [CCode (cname = "llama_adapter_lora_init")]
    public static void* adapter_lora_init (Model model, string path_lora);
    [CCode (cname = "llama_adapter_lora_free")]
    public static void adapter_lora_free (void* adapter);
    [CCode (cname = "llama_set_adapter_lora")]
    public static int set_adapter_lora (Context ctx, void* adapter, float scale);
    [CCode (cname = "llama_rm_adapter_lora")]
    public static int rm_adapter_lora (Context ctx, void* adapter);
    [CCode (cname = "llama_clear_adapter_lora")]
    public static void clear_adapter_lora (Context ctx);
    [CCode (cname = "llama_apply_adapter_cvec")]
    public static int apply_adapter_cvec (Context ctx, float[] data, size_t len, int n_embd, int il_start, int il_end);

    // Structure opaque pour le contexte
    [CCode (cname = "llama_model", free_function = "llama_free_model", has_type_id = false)]
    public class Model {
    }

    [CCode (cname = "llama_context", free_function = "llama_free", has_type_id = false)]
    public class Context {
    }
}
