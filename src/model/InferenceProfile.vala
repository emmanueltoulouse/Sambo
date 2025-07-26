using GLib;
using Gee;

namespace Sambo {
    /**
     * Représente un profil d'inférence complet
     */
    public class InferenceProfile : Object {
        public string id { get; set; }
        public string title { get; set; }
        public string comment { get; set; }
        public string prompt { get; set; }
        public string model_path { get; set; }
        public string template { get; set; default = ""; }

        // Paramètres de sampling
        public float temperature { get; set; default = 0.7f; }
        public float top_p { get; set; default = 0.9f; }
        public int top_k { get; set; default = 40; }
        public int max_tokens { get; set; default = 512; }
        public float repetition_penalty { get; set; default = 1.1f; }
        public float frequency_penalty { get; set; default = 0.0f; }
        public float presence_penalty { get; set; default = 0.0f; }
        public int seed { get; set; default = -1; }
        public int context_length { get; set; default = 2048; }
        public bool stream { get; set; default = true; }

        public InferenceProfile(string id = "", string title = "", string comment = "", string prompt = "", string model_path = "") {
            this.id = id;
            this.title = title;
            this.comment = comment;
            this.prompt = prompt;
            this.model_path = model_path;
        }

        /**
         * Crée un profil avec des valeurs par défaut
         */
        public static InferenceProfile create_default(string id, string title) {
            var profile = new InferenceProfile(id, title, "", "", "");
            profile.prompt = "Tu es un assistant IA utile et bienveillant. Réponds de manière claire et concise.";
            return profile;
        }

        /**
         * Valide le profil
         * @return true si le profil est valide, false sinon
         */
        public bool is_valid() {
            return id != "" && title != "" && prompt != "" && model_path != "";
        }

        /**
         * Retourne les erreurs de validation
         * @return Liste des erreurs, vide si le profil est valide
         */
        public string[] get_validation_errors() {
            var errors = new ArrayList<string>();

            if (id == "") {
                errors.add("ID du profil requis");
            }

            if (title == "") {
                errors.add("Titre du profil requis");
            }

            if (prompt == "") {
                errors.add("Prompt système requis");
            }

            if (model_path == "") {
                errors.add("Modèle requis");
            }

            return errors.to_array();
        }

        /**
         * Copie les valeurs d'un autre profil
         */
        public void copy_from(InferenceProfile other) {
            this.title = other.title;
            this.comment = other.comment;
            this.prompt = other.prompt;
            this.model_path = other.model_path;
            this.template = other.template;
            this.temperature = other.temperature;
            this.top_p = other.top_p;
            this.top_k = other.top_k;
            this.max_tokens = other.max_tokens;
            this.repetition_penalty = other.repetition_penalty;
            this.frequency_penalty = other.frequency_penalty;
            this.presence_penalty = other.presence_penalty;
            this.seed = other.seed;
            this.context_length = other.context_length;
            this.stream = other.stream;
        }

        /**
         * Génère un ID unique basé sur le timestamp
         */
        public static string generate_unique_id() {
            return "profile_%s".printf(new DateTime.now_utc().to_unix().to_string());
        }
    }
}
