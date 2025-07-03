namespace Sambo.HuggingFace {
    /**
     * Représente un fichier dans un modèle HuggingFace
     */
    public class HuggingFaceFile : Object {
        public string filename { get; set; }
        public string oid { get; set; }
        public int64 size { get; set; }
        public string? lfs_oid { get; set; }
        public bool is_lfs { get; set; }
        public bool selected { get; set; default = false; }
        public DownloadStatus status { get; set; default = DownloadStatus.NOT_DOWNLOADED; }

        public enum DownloadStatus {
            NOT_DOWNLOADED,
            DOWNLOADING,
            DOWNLOADED,
            ERROR
        }

        public HuggingFaceFile(string filename, string oid, int64 size, string? lfs_oid = null) {
            this.filename = filename;
            this.oid = oid;
            this.size = size;
            this.lfs_oid = lfs_oid;
            this.is_lfs = (lfs_oid != null);
        }

        /**
         * Retourne la taille formatée pour l'affichage
         */
        public string get_formatted_size() {
            if (size < 1024) {
                return "%lld B".printf(size);
            } else if (size < 1024 * 1024) {
                return "%.1f KB".printf(size / 1024.0);
            } else if (size < 1024 * 1024 * 1024) {
                return "%.1f MB".printf(size / (1024.0 * 1024.0));
            } else {
                return "%.1f GB".printf(size / (1024.0 * 1024.0 * 1024.0));
            }
        }

        /**
         * Retourne l'icône appropriée selon le type de fichier
         */
        public string get_icon_name() {
            var parts = filename.split(".");
            var extension = parts.length > 1 ? parts[parts.length - 1].down() : "";

            switch (extension) {
                case ".json":
                    return "text-x-generic-symbolic";
                case ".bin":
                case ".safetensors":
                    return "application-x-executable-symbolic";
                case ".md":
                    return "text-markdown-symbolic";
                case ".txt":
                    return "text-x-generic-symbolic";
                case ".py":
                    return "text-x-python-symbolic";
                default:
                    return "text-x-generic-symbolic";
            }
        }
    }
}
