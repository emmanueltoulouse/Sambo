using Soup;
using Json;

namespace Sambo.HuggingFace {
    /**
     * Callback pour le suivi de progression du téléchargement
     *
     * @param progress Progression de 0.0 à 1.0
     * @param downloaded_bytes Nombre d'octets téléchargés
     * @param total_bytes Taille totale du fichier
     * @param speed Vitesse en octets/seconde
     * @param eta_seconds Temps estimé restant en secondes
     */
    public delegate void ProgressCallback(double progress, int64 downloaded_bytes, int64 total_bytes, double speed, double eta_seconds);

    /**
     * Client API pour interagir avec HuggingFace
     */
    public class HuggingFaceAPI : GLib.Object {
        private Session session;
        private string? api_token;
        private const string BASE_URL = "https://huggingface.co/api";

        public HuggingFaceAPI(string? token = null) {
            session = new Session();
            this.api_token = token;
        }

        /**
         * Configure le token d'API
         */
        public void set_token(string? token) {
            this.api_token = token;
        }

        /**
         * Configure la clé API (alias pour set_token)
         */
        public void set_api_key(string? key) {
            set_token(key);
        }

        /**
         * Teste la validité du token
         */
        public async bool validate_token(string token) throws Error {
            var message = new Message("GET", BASE_URL + "/whoami");
            message.request_headers.append("Authorization", "Bearer " + token);

            var response = yield session.send_async(message, Priority.DEFAULT, null);
            return message.status_code == 200;
        }

        /**
         * Recherche de modèles avec filtres (version asynchrone)
         */
        public async Gee.List<HuggingFaceModel> search_models_async(string? query = null) throws Error {
            return yield search_models_with_filters_async(query, 50, "downloads", "-1", null, null, null);
        }

        /**
         * Recherche de modèles avec filtres avancés (version asynchrone)
         */
        public async Gee.List<HuggingFaceModel> search_models_with_filters_async(
            string? query = null,
            int limit = 50,
            string sort = "downloads",
            string direction = "-1",
            string? library = null,
            string? pipeline_tag = null,
            string? tags = null
        ) throws Error {
            var url = BASE_URL + @"/models?limit=$(limit)";

            // Ajouter les filtres en premier
            if (query != null && query.strip().length > 0) {
                url += "&search=" + Uri.escape_string(query);
            }

            bool has_filters = false;

            if (library != null && library.strip().length > 0) {
                // Utiliser le paramètre filter pour les formats (GGUF, PyTorch, etc.)
                url += "&filter=" + Uri.escape_string(library);
                has_filters = true;
            }

            if (pipeline_tag != null && pipeline_tag.strip().length > 0) {
                url += "&pipeline_tag=" + Uri.escape_string(pipeline_tag);
                has_filters = true;
            }

            if (tags != null && tags.strip().length > 0) {
                url += "&tags=" + Uri.escape_string(tags);
                has_filters = true;
            }

            // Problème: L'API HuggingFace ignore les filtres tags quand on trie par downloads
            // Solution: Ne pas trier quand des filtres sont appliqués, l'API retourne les modèles par pertinence
            if (!has_filters) {
                // Ajouter le tri seulement s'il n'y a pas de filtres
                url += @"&sort=$(sort)&direction=$(direction)";
            }

            // Debug: afficher l'URL générée
            stdout.printf("[DEBUG] URL API générée: %s\n", url);

            var message = new Message("GET", url);
            if (api_token != null) {
                message.request_headers.append("Authorization", "Bearer " + api_token);
            }

            var bytes = yield session.send_and_read_async(message, Priority.DEFAULT, null);

            if (message.status_code != 200) {
                var error_message = get_error_message_for_status(message.status_code);
                throw new IOError.FAILED(error_message);
            }

            var json_data = (string) bytes.get_data();
            return parse_models_response(json_data);
        }

        /**
         * Récupère les fichiers d'un modèle de manière asynchrone
         */
        public async Gee.List<HuggingFaceFile> get_model_files_async(string model_id) throws Error {
            var url = BASE_URL + @"/models/$(model_id)/tree/main";

            var message = new Message("GET", url);
            if (api_token != null) {
                message.request_headers.append("Authorization", "Bearer " + api_token);
            }

            var bytes = yield session.send_and_read_async(message, Priority.DEFAULT, null);

            if (message.status_code != 200) {
                var error_message = get_error_message_for_status(message.status_code);
                throw new IOError.FAILED(error_message);
            }

            var json_data = (string) bytes.get_data();
            return parse_files_list(json_data);
        }

        /**
         * Télécharge un fichier d'un modèle avec callback de progression précis
         */
        public async void download_file_async(string model_id, string filename, string local_path,
                                             owned ProgressCallback? progress_callback = null) throws Error {
            var url = @"https://huggingface.co/$(model_id)/resolve/main/$(filename)";

            var message = new Message("GET", url);
            if (api_token != null) {
                message.request_headers.append("Authorization", "Bearer " + api_token);
            }

            // Variables pour le suivi de progression
            int64 total_bytes = 0;
            int64 downloaded_bytes = 0;
            var start_time = get_monotonic_time();
            var last_progress_update = start_time;
            const int64 PROGRESS_UPDATE_INTERVAL = 50000; // 50ms en microsecondes

            // Effectuer la requête
            var input_stream = yield session.send_async(message, Priority.DEFAULT, null);

            // Récupérer la taille totale depuis les en-têtes
            var content_length = message.response_headers.get_one("content-length");
            if (content_length != null) {
                total_bytes = int64.parse(content_length);
            }

            if (message.status_code != 200) {
                var error_message = "Échec du téléchargement : " + get_error_message_for_status(message.status_code);
                throw new IOError.FAILED(error_message);
            }

            // Créer le fichier de destination et ses répertoires parents
            var file = File.new_for_path(local_path);
            var parent = file.get_parent();
            if (parent != null && !parent.query_exists()) {
                parent.make_directory_with_parents();
            }

            var output_stream = yield file.replace_async(null, false, FileCreateFlags.REPLACE_DESTINATION, Priority.DEFAULT, null);

            try {
                // Télécharger par chunks pour permettre la progression précise
                const int CHUNK_SIZE = 4096; // 4KB par chunk pour plus de granularité
                var buffer = new uint8[CHUNK_SIZE];

                while (true) {
                    var bytes_read = yield input_stream.read_async(buffer, Priority.DEFAULT, null);
                    if (bytes_read == 0) break; // Fin du fichier

                    downloaded_bytes += bytes_read;
                    yield output_stream.write_all_async(buffer[0:bytes_read], Priority.DEFAULT, null, null);

                    // Mettre à jour la progression avec throttling pour éviter trop d'appels
                    var current_time = get_monotonic_time();
                    if (progress_callback != null && total_bytes > 0 &&
                        (current_time - last_progress_update >= PROGRESS_UPDATE_INTERVAL || downloaded_bytes == total_bytes)) {

                        double progress = (double)downloaded_bytes / (double)total_bytes;
                        var elapsed_seconds = (current_time - start_time) / 1000000.0;

                        // Calculer la vitesse (octets/seconde)
                        double speed = elapsed_seconds > 0 ? downloaded_bytes / elapsed_seconds : 0.0;

                        // Estimer le temps restant
                        var remaining_bytes = total_bytes - downloaded_bytes;
                        double eta_seconds = (speed > 0 && remaining_bytes > 0) ? remaining_bytes / speed : 0.0;

                        progress_callback(progress, downloaded_bytes, total_bytes, speed, eta_seconds);
                        last_progress_update = current_time;
                    }
                }

                yield output_stream.close_async(Priority.DEFAULT, null);
                
                // Fermer le stream d'entrée
                try {
                    yield input_stream.close_async(Priority.DEFAULT, null);
                } catch (Error close_error) {
                    warning("Erreur lors de la fermeture du stream d'entrée: %s", close_error.message);
                }
            } catch (Error e) {
                // Nettoyer le fichier partiellement téléchargé en cas d'erreur
                try {
                    yield output_stream.close_async(Priority.DEFAULT, null);
                    if (file.query_exists()) {
                        file.delete();
                    }
                } catch (Error cleanup_error) {
                    warning("Impossible de nettoyer le fichier partiellement téléchargé: %s", cleanup_error.message);
                }
                
                // Fermer le stream d'entrée même en cas d'erreur
                try {
                    yield input_stream.close_async(Priority.DEFAULT, null);
                } catch (Error close_error) {
                    warning("Erreur lors de la fermeture du stream d'entrée: %s", close_error.message);
                }
                
                throw e;
            }
        }

        /**
         * Sauvegarde asynchrone d'un fichier
         */
        private async void save_file_async(string path, uint8[] data) throws Error {
            var file = File.new_for_path(path);
            var stream = yield file.replace_async(null, false, FileCreateFlags.NONE, Priority.DEFAULT, null);
            size_t bytes_written;
            yield stream.write_all_async(data, Priority.DEFAULT, null, out bytes_written);
            yield stream.close_async(Priority.DEFAULT, null);
        }

        /**
         * Extrait le contenu de la réponse
         */
        private async string get_response_body(InputStream response) throws Error {
            var data_stream = new DataInputStream(response);
            var content = new StringBuilder();
            string line;

            while ((line = yield data_stream.read_line_async()) != null) {
                content.append(line);
                content.append("\n");
            }

            return content.str;
        }

        /**
         * Parse la réponse de recherche de modèles
         */
        private Gee.List<HuggingFaceModel> parse_models_response(string json_data) {
            var models = new Gee.ArrayList<HuggingFaceModel>();

            try {
                var parser = new Parser();
                parser.load_from_data(json_data);
                var root = parser.get_root();

                if (root.get_node_type() == NodeType.ARRAY) {
                    var array = root.get_array();

                    foreach (var element in array.get_elements()) {
                        var model_obj = element.get_object();
                        var model = parse_model_object(model_obj);
                        models.add(model);
                    }
                }
            } catch (Error e) {
                warning("Erreur lors du parsing des modèles: %s", e.message);
            }

            return models;
        }

        /**
         * Parse un objet modèle JSON
         */
        private HuggingFaceModel parse_model_object(Json.Object obj) {
            var model = new HuggingFaceModel();

            model.id = obj.get_string_member_with_default("id", "");
            model.author = obj.get_string_member_with_default("author", "");
            model.sha = obj.get_string_member_with_default("sha", "");
            model.private_model = obj.get_boolean_member_with_default("private", false);
            model.gated = obj.get_boolean_member_with_default("gated", false);
            model.disabled = obj.get_boolean_member_with_default("disabled", false);
            model.downloads = (int)obj.get_int_member_with_default("downloads", 0);
            model.likes = (int)obj.get_int_member_with_default("likes", 0);
            model.pipeline_tag = obj.get_string_member_with_default("pipeline_tag", "");
            model.library_name = obj.get_string_member_with_default("library_name", "");
            model.description = obj.get_string_member_with_default("description", null);
            model.license = obj.get_string_member_with_default("license", null);

            // Parse tags
            if (obj.has_member("tags")) {
                var tags_array = obj.get_array_member("tags");
                var tags_list = new Gee.ArrayList<string>();
                foreach (var tag_element in tags_array.get_elements()) {
                    tags_list.add(tag_element.get_string());
                }
                model.tags = tags_list.to_array();
            }

            // Parse dates
            var created_str = obj.get_string_member_with_default("createdAt", "");
            var modified_str = obj.get_string_member_with_default("lastModified", "");

            try {
                if (created_str.length > 0) {
                    model.created_at = new DateTime.from_iso8601(created_str, null);
                }
                if (modified_str.length > 0) {
                    model.last_modified = new DateTime.from_iso8601(modified_str, null);
                }
            } catch (Error e) {
                warning("Erreur lors du parsing des dates pour %s: %s", model.id, e.message);
            }

            return model;
        }

        /**
         * Parse une liste de fichiers depuis JSON
         */
        private Gee.List<HuggingFaceFile> parse_files_list(string json_data) {
            var files = new Gee.ArrayList<HuggingFaceFile>();

            try {
                var parser = new Parser();
                parser.load_from_data(json_data);
                var root = parser.get_root();
                var array = root.get_array();

                foreach (var element in array.get_elements()) {
                    var file_obj = element.get_object();

                    if (file_obj.get_string_member_with_default("type", "") == "file") {
                        var filename = file_obj.get_string_member_with_default("path", "");
                        var oid = file_obj.get_string_member_with_default("oid", "");
                        var size = file_obj.get_int_member_with_default("size", 0);
                        var lfs_oid = file_obj.get_string_member_with_default("lfs", null);

                        var file = new HuggingFaceFile(filename, oid, size, lfs_oid);
                        files.add(file);
                    }
                }
            } catch (Error e) {
                warning("Erreur lors du parsing des fichiers: %s", e.message);
            }

            return files;
        }

        /**
         * Génère un message d'erreur approprié en fonction du code de statut HTTP
         */
        private string get_error_message_for_status(uint status_code) {
            switch (status_code) {
                case 400:
                    return "Requête invalide (erreur 400)";
                case 401:
                    return "Clé API invalide ou manquante (erreur 401)";
                case 403:
                    return "Accès interdit - vérifiez votre clé API (erreur 403)";
                case 404:
                    return "Modèle non trouvé (erreur 404)";
                case 429:
                    if (api_token == null) {
                        return "Limite de taux dépassée (erreur 429). Ajoutez une clé API HuggingFace dans les préférences pour un accès illimité, ou attendez quelques minutes.";
                    } else {
                        return "Limite de taux dépassée (erreur 429). Attendez quelques minutes avant de réessayer.";
                    }
                case 500:
                    return "Erreur interne du serveur HuggingFace (erreur 500)";
                case 502:
                    return "Serveur HuggingFace temporairement indisponible (erreur 502)";
                case 503:
                    return "Service HuggingFace temporairement indisponible (erreur 503)";
                default:
                    return @"Erreur de l'API HuggingFace (code $(status_code))";
            }
        }

        /**
         * Génère un message d'erreur court pour les toasts
         */
        private string get_short_error_message_for_status(uint status_code) {
            switch (status_code) {
                case 400:
                    return "Requête invalide";
                case 401:
                    return "Clé API invalide - Vérifiez vos préférences";
                case 403:
                    return "Accès interdit - Vérifiez vos préférences";
                case 404:
                    return "Modèle non trouvé";
                case 429:
                    if (api_token == null) {
                        return "Limite dépassée - Ajoutez une clé API ou patientez";
                    } else {
                        return "Limite dépassée - Patientez quelques minutes";
                    }
                case 500:
                case 502:
                case 503:
                    return "Serveur HuggingFace indisponible - Réessayez plus tard";
                default:
                    return @"Erreur API HuggingFace ($(status_code))";
            }
        }
    }
}
