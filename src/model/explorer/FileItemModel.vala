// filepath: /home/emmanuel/Bureau/Projects/Sambo/src/model/explorer/FileItemModel.vala
namespace Sambo {
    /**
     * Modèle représentant un élément de fichier ou dossier dans l'explorateur
     * Stocke les métadonnées du fichier (nom, taille, date de modification, etc.)
     */
    public class FileItemModel : Object {
        // Propriétés du fichier/dossier
        public string name { get; set; }                // Nom du fichier/dossier
        public string path { get; set; }                // Chemin complet
        public string mime_type { get; set; }           // Type MIME
        public int64 size { get; set; default = 0; }    // Taille en octets
        public DateTime modified_time { get; set; }     // Date de dernière modification
        public bool is_hidden { get; set; default = false; }  // Si le fichier est caché
        public FileType file_type { get; set; }         // Type (fichier ou dossier)
        public uint file_mode { get; set; default = 0;} // Mode (permissions)
        public Icon? icon { get; set; default = null; } // Icône associée

        // Métadonnées supplémentaires pour les fichiers
        private HashTable<string, string> metadata;

        /**
         * Crée un nouveau modèle de fichier vide
         */
        public FileItemModel() {
            metadata = new HashTable<string, string>(str_hash, str_equal);
            modified_time = new DateTime.now_local();
        }

        /**
         * Crée un modèle de fichier à partir d'un chemin
         *
         * @param path Le chemin du fichier/dossier
         */
        public FileItemModel.from_path(string path) {
            this();

            try {
                var file = File.new_for_path(path);
                var info = file.query_info(
                    "standard::*,time::modified,unix::mode",
                    FileQueryInfoFlags.NONE
                );

                init_from_file_info(path, info);
            } catch (Error e) {
                warning("Erreur lors de la création du modèle de fichier: %s", e.message);
            }
        }

        /**
         * Crée un modèle de fichier à partir d'un FileInfo
         *
         * @param path Le chemin du fichier/dossier
         * @param info L'objet FileInfo
         */
        public FileItemModel.from_file_info(string path, FileInfo info) {
            this();
            init_from_file_info(path, info);
        }

        /**
         * Initialise les propriétés à partir d'un FileInfo
         */
        private void init_from_file_info(string path, FileInfo info) {
            this.path = path;
            this.name = info.get_name();
            this.file_type = info.get_file_type();
            this.mime_type = info.get_content_type() ?? "";
            this.size = info.get_size();
            this.is_hidden = info.get_is_hidden();
            this.icon = info.get_icon();

            // Récupérer les permissions si disponibles
            try {
                this.file_mode = info.get_attribute_uint32(FileAttribute.UNIX_MODE);
            } catch (Error e) {
                this.file_mode = 0;
            }

            // Récupérer la date de modification
            var mod_time = info.get_modification_date_time();
            if (mod_time != null) {
                this.modified_time = mod_time;
            }
        }

        /**
         * Vérifie si l'élément est un dossier
         *
         * @return true si c'est un dossier, false sinon
         */
        public bool is_directory() {
            return file_type == FileType.DIRECTORY;
        }

        /**
         * Vérifie si l'élément est un fichier régulier
         *
         * @return true si c'est un fichier, false sinon
         */
        public bool is_regular() {
            return file_type == FileType.REGULAR;
        }

        /**
         * Obtient la taille formatée pour l'affichage
         *
         * @return La taille formatée (ex: "1.2 MB")
         */
        public string get_formatted_size() {
            // Si c'est un dossier, ne pas afficher de taille
            if (is_directory()) {
                return "";
            }

            if (size < 1024) {
                return "%lld o".printf(size);
            } else if (size < 1024 * 1024) {
                return "%.1f Ko".printf(size / 1024.0);
            } else if (size < 1024 * 1024 * 1024) {
                return "%.1f Mo".printf(size / (1024.0 * 1024));
            } else {
                return "%.1f Go".printf(size / (1024.0 * 1024 * 1024));
            }
        }

        /**
         * Obtient la date de modification formatée pour l'affichage
         *
         * @return La date formatée
         */
        public string get_formatted_modified_time() {
            return modified_time.format("%d/%m/%Y %H:%M");
        }

        /**
         * Obtient l'extension du fichier
         *
         * @return L'extension du fichier ou une chaîne vide si pas d'extension ou dossier
         */
        public string get_extension() {
            if (is_directory() || name.last_index_of(".") == -1) {
                return "";
            }

            return name.substring(name.last_index_of(".") + 1).down();
        }

        /**
         * Ajoute ou met à jour une métadonnée associée au fichier
         *
         * @param key Clé de la métadonnée
         * @param value Valeur de la métadonnée
         */
        public void set_metadata(string key, string value) {
            metadata.insert(key, value);
        }

        /**
         * Récupère une métadonnée associée au fichier
         *
         * @param key Clé de la métadonnée
         * @return La valeur de la métadonnée ou null si inexistante
         */
        public string? get_metadata(string key) {
            return metadata.lookup(key);
        }

        /**
         * Vérifie si le fichier peut être lu
         *
         * @return true si le fichier est lisible, false sinon
         */
        public bool is_readable() {
            // Vérifie si le fichier existe et si l'utilisateur a les droits de lecture
            return FileUtils.test(path, FileTest.EXISTS) &&
                  ((file_mode & 0400) != 0); // 0400 est Posix.S_IRUSR (droits de lecture pour l'utilisateur)
        }

        /**
         * Vérifie si le fichier peut être écrit
         *
         * @return true si le fichier est modifiable, false sinon
         */
        public bool is_writable() {
            // Vérifie si le fichier existe et si l'utilisateur a les droits d'écriture
            return FileUtils.test(path, FileTest.EXISTS) &&
                  ((file_mode & 0200) != 0); // 0200 est Posix.S_IWUSR (droits d'écriture pour l'utilisateur)
        }

        /**
         * Obtient le nom du fichier sans son extension
         *
         * @return Le nom sans extension
         */
        public string get_name_without_extension() {
            if (is_directory() || name.last_index_of(".") == -1) {
                return name;
            }

            return name.substring(0, name.last_index_of("."));
        }
    }
}
