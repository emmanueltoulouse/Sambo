namespace Sambo.HuggingFace {
    /**
     * Représente un modèle HuggingFace
     */
    public class HuggingFaceModel : Object {
        public string id { get; set; default = ""; }
        public string author { get; set; default = ""; }
        public string sha { get; set; default = ""; }
        public DateTime? created_at { get; set; }
        public DateTime? last_modified { get; set; }
        public bool private_model { get; set; default = false; }
        public bool gated { get; set; default = false; }
        public bool disabled { get; set; default = false; }
        public int downloads { get; set; default = 0; }
        public int likes { get; set; default = 0; }
        public string[] tags { get; set; }
        public string pipeline_tag { get; set; default = ""; }
        public string library_name { get; set; default = ""; }
        public string? description { get; set; }
        public string? license { get; set; }
        public Gee.List<HuggingFaceFile> files { get; set; }
        public int64 total_size { get; private set; }

        // Permissions de l'utilisateur
        public bool can_read { get; set; default = true; }
        public bool can_write { get; set; default = false; }
        public bool can_download { get; set; default = true; }

        public HuggingFaceModel() {
            files = new Gee.ArrayList<HuggingFaceFile>();
            tags = {};
        }

        /**
         * Calcule la taille totale du modèle
         */
        public void calculate_total_size() {
            total_size = 0;
            foreach (var file in files) {
                total_size += file.size;
            }
        }

        /**
         * Retourne la taille totale formatée
         */
        public string get_formatted_total_size() {
            if (total_size < 1024) {
                return "%lld B".printf(total_size);
            } else if (total_size < 1024 * 1024) {
                return "%.1f KB".printf(total_size / 1024.0);
            } else if (total_size < 1024 * 1024 * 1024) {
                return "%.1f MB".printf(total_size / (1024.0 * 1024.0));
            } else {
                return "%.1f GB".printf(total_size / (1024.0 * 1024.0 * 1024.0));
            }
        }

        /**
         * Retourne une description courte du modèle
         */
        public string get_short_description() {
            if (description != null && description.length > 0) {
                var lines = description.split("\n");
                if (lines.length > 0) {
                    var first_line = lines[0].strip();
                    if (first_line.length > 150) {
                        return first_line.substring(0, 150) + "...";
                    }
                    return first_line;
                }
            }
            return _("Aucune description disponible");
        }

        /**
         * Retourne l'icône appropriée selon le type de modèle
         */
        public string get_icon_name() {
            switch (pipeline_tag.down()) {
                case "text-generation":
                    return "text-editor-symbolic";
                case "text-classification":
                case "token-classification":
                    return "text-x-generic-symbolic";
                case "image-classification":
                case "image-to-text":
                case "text-to-image":
                    return "image-x-generic-symbolic";
                case "automatic-speech-recognition":
                case "text-to-speech":
                    return "audio-x-generic-symbolic";
                case "translation":
                    return "preferences-desktop-locale-symbolic";
                case "conversational":
                    return "user-available-symbolic";
                default:
                    return "applications-science-symbolic";
            }
        }

        /**
         * Retourne le nombre de fichiers sélectionnés
         */
        public int get_selected_files_count() {
            int count = 0;
            foreach (var file in files) {
                if (file.selected) {
                    count++;
                }
            }
            return count;
        }

        /**
         * Retourne la taille totale des fichiers sélectionnés
         */
        public int64 get_selected_files_size() {
            int64 size = 0;
            foreach (var file in files) {
                if (file.selected) {
                    size += file.size;
                }
            }
            return size;
        }

        /**
         * Sélectionne ou désélectionne tous les fichiers
         */
        public void select_all_files(bool selected) {
            foreach (var file in files) {
                file.selected = selected;
            }
        }

        /**
         * Détermine si le modèle est téléchargeable
         * Un modèle est considéré comme téléchargeable s'il :
         * - N'est pas privé ou gated (sauf si l'utilisateur a les permissions)
         * - N'est pas désactivé
         * - A des fichiers téléchargeables
         * - A les permissions de téléchargement
         */
        public bool is_downloadable() {
            // Vérifier si le modèle est désactivé
            if (disabled) {
                return false;
            }

            // Vérifier les permissions de base
            if (!can_download || !can_read) {
                return false;
            }

            // Vérifier si le modèle est privé ou gated sans permissions appropriées
            if (private_model || gated) {
                // Si le modèle est privé/gated mais qu'on peut le lire, c'est OK
                if (!can_read) {
                    return false;
                }
            }

            // Vérifier s'il y a des fichiers téléchargeables
            return has_downloadable_files();
        }

        /**
         * Vérifie si le modèle a des fichiers téléchargeables
         */
        public bool has_downloadable_files() {
            // Si on n'a pas encore chargé les fichiers, on considère qu'il pourrait être téléchargeable
            if (files.size == 0) {
                return true;
            }

            // Extensions de fichiers considérées comme téléchargeables
            string[] downloadable_extensions = {
                ".bin", ".safetensors", ".gguf", ".pt", ".pth", ".onnx",
                ".pkl", ".h5", ".tflite", ".pb", ".ckpt", ".model"
            };

            foreach (var file in files) {
                string filename = file.filename.down();

                // Ignorer les fichiers système/metadata
                if (filename.has_prefix(".") ||
                    filename == "readme.md" ||
                    filename == "config.json" ||
                    filename == "tokenizer.json" ||
                    filename == "tokenizer_config.json" ||
                    filename.has_suffix(".txt") ||
                    filename.has_suffix(".md")) {
                    continue;
                }

                // Vérifier les extensions téléchargeables
                foreach (string ext in downloadable_extensions) {
                    if (filename.has_suffix(ext)) {
                        return true;
                    }
                }
            }

            return false;
        }
    }
}
