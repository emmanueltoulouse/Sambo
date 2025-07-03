using Soup;
using Json;

namespace Sambo.HuggingFace {
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
            var url = BASE_URL + "/models?limit=50&sort=downloads&direction=-1";

            if (query != null && query.strip().length > 0) {
                url += "&search=" + Uri.escape_string(query);
            }

            var message = new Message("GET", url);
            if (api_token != null) {
                message.request_headers.append("Authorization", "Bearer " + api_token);
            }

            var response = yield session.send_async(message, Priority.DEFAULT, null);

            if (message.status_code != 200) {
                throw new IOError.FAILED(@"API returned status $(message.status_code)");
            }

            var bytes = yield session.send_and_read_async(message, Priority.DEFAULT, null);
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

            var response = yield session.send_async(message, Priority.DEFAULT, null);

            if (message.status_code != 200) {
                throw new IOError.FAILED(@"API returned status $(message.status_code)");
            }

            var bytes = yield session.send_and_read_async(message, Priority.DEFAULT, null);
            var json_data = (string) bytes.get_data();
            return parse_files_list(json_data);
        }

        /**
         * Télécharge un fichier d'un modèle
         */
        public async void download_file_async(string model_id, string filename, string local_path) throws Error {
            var url = @"https://huggingface.co/$(model_id)/resolve/main/$(filename)";

            var message = new Message("GET", url);
            if (api_token != null) {
                message.request_headers.append("Authorization", "Bearer " + api_token);
            }

            var response = yield session.send_async(message, Priority.DEFAULT, null);

            if (message.status_code != 200) {
                throw new IOError.FAILED(@"Download failed with status $(message.status_code)");
            }

            // Sauvegarder le fichier
            var bytes = yield session.send_and_read_async(message, Priority.DEFAULT, null);
            yield save_file_async(local_path, bytes.get_data());
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
                warning("Erreur lors du parsing des dates: %s", e.message);
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
    }
}
