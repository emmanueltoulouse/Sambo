public class BookmarksManager : Object {
    private static BookmarksManager? instance = null;
    private Gee.List<File> bookmarks;
    private Gee.List<GnomeBookmark?> gnome_bookmarks;
    private File bookmarks_file;
    private File gnome_bookmarks_file;
    private FileMonitor? gnome_monitor = null;

    public signal void bookmarks_changed();

    public struct GnomeBookmark {
        public string uri;
        public string? name;
        public string path;
    }

    public static BookmarksManager get_instance() {
        if (instance == null) {
            instance = new BookmarksManager();
        }
        return instance;
    }

    private BookmarksManager() {
        bookmarks = new Gee.ArrayList<File>();
        gnome_bookmarks = new Gee.ArrayList<GnomeBookmark?>();

        // Localisation du fichier de favoris Sambo
        string config_dir = Environment.get_user_config_dir();
        string app_config_dir = Path.build_filename(config_dir, "sambo");

        try {
            File dir = File.new_for_path(app_config_dir);
            if (!dir.query_exists()) {
                dir.make_directory_with_parents();
            }

            bookmarks_file = File.new_for_path(Path.build_filename(app_config_dir, "bookmarks.txt"));
            
            // Localisation du fichier de signets GNOME Fichiers
            gnome_bookmarks_file = File.new_for_path(Path.build_filename(config_dir, "gtk-3.0", "bookmarks"));
            if (!gnome_bookmarks_file.query_exists()) {
                // Essayer gtk-4.0 si gtk-3.0 n'existe pas
                gnome_bookmarks_file = File.new_for_path(Path.build_filename(config_dir, "gtk-4.0", "bookmarks"));
            }
            
            load_bookmarks();
            load_gnome_bookmarks();
            setup_gnome_monitor();
            
        } catch (Error e) {
            warning(_("Erreur lors de l'initialisation des favoris: %s"), e.message);
        }
    }

    public Gee.List<File> get_bookmarks() {
        return bookmarks;
    }

    public Gee.List<GnomeBookmark?> get_gnome_bookmarks() {
        return gnome_bookmarks;
    }

    public Gee.List<File> get_all_bookmarks() {
        var all_bookmarks = new Gee.ArrayList<File>();
        
        // Ajouter les signets GNOME d'abord
        foreach (var gnome_bookmark in gnome_bookmarks) {
            try {
                var file = File.new_for_uri(gnome_bookmark.uri);
                if (file.query_exists()) {
                    all_bookmarks.add(file);
                }
            } catch (Error e) {
                // Ignorer les URIs invalides
            }
        }
        
        // Ajouter les signets Sambo (s'ils ne sont pas déjà présents)
        foreach (var bookmark in bookmarks) {
            bool already_present = false;
            foreach (var existing in all_bookmarks) {
                if (existing.get_path() == bookmark.get_path()) {
                    already_present = true;
                    break;
                }
            }
            if (!already_present) {
                all_bookmarks.add(bookmark);
            }
        }
        
        return all_bookmarks;
    }

    public bool add_bookmark(File file) {
        // Vérifier si le favori existe déjà
        foreach (var bookmark in bookmarks) {
            if (bookmark.get_path() == file.get_path()) {
                return false;
            }
        }

        bookmarks.add(file);
        save_bookmarks();
        bookmarks_changed();
        return true;
    }

    public bool remove_bookmark(File file) {
        bool removed = false;

        for (int i = 0; i < bookmarks.size; i++) {
            if (bookmarks[i].get_path() == file.get_path()) {
                bookmarks.remove_at(i);
                removed = true;
                break;
            }
        }

        if (removed) {
            save_bookmarks();
            bookmarks_changed();
        }

        return removed;
    }

    public bool is_bookmarked(File file) {
        foreach (var bookmark in bookmarks) {
            if (bookmark.get_path() == file.get_path()) {
                return true;
            }
        }
        return false;
    }

    private void load_bookmarks() {
        bookmarks.clear();

        if (!bookmarks_file.query_exists()) {
            return;
        }

        try {
            var dis = new DataInputStream(bookmarks_file.read());
            string line;

            while ((line = dis.read_line()) != null) {
                if (line.strip() != "") {
                    var file = File.new_for_path(line);
                    bookmarks.add(file);
                }
            }
        } catch (Error e) {
            warning(_("Erreur lors du chargement des favoris: %s"), e.message);
        }
    }

    private void save_bookmarks() {
        try {
            var dos = new DataOutputStream(
                bookmarks_file.replace(null, false, FileCreateFlags.NONE)
            );

            foreach (var bookmark in bookmarks) {
                dos.put_string(bookmark.get_path() + "\n");
            }
        } catch (Error e) {
            warning(_("Erreur lors de l'enregistrement des favoris: %s"), e.message);
        }
    }

    public void refresh_bookmarks() {
        load_bookmarks();
        load_gnome_bookmarks();
        bookmarks_changed();
    }

    private void load_gnome_bookmarks() {
        gnome_bookmarks.clear();

        if (!gnome_bookmarks_file.query_exists()) {
            return;
        }

        try {
            var dis = new DataInputStream(gnome_bookmarks_file.read());
            string line;

            while ((line = dis.read_line()) != null) {
                line = line.strip();
                if (line != "" && line.has_prefix("file://")) {
                    // Parser la ligne: "file:///path/to/folder Optional Name"
                    string[] parts = line.split(" ", 2);
                    string uri = parts[0];
                    string? name = parts.length > 1 ? parts[1] : null;
                    
                    try {
                        var file = File.new_for_uri(uri);
                        string path = file.get_path();
                        
                        if (path != null && file.query_exists()) {
                            GnomeBookmark bookmark = GnomeBookmark() {
                                uri = uri,
                                name = name,
                                path = path
                            };
                            gnome_bookmarks.add(bookmark);
                        }
                    } catch (Error e) {
                        // Ignorer les URIs invalides
                        warning("URI invalide dans les signets GNOME: %s", uri);
                    }
                }
            }
        } catch (Error e) {
            warning(_("Erreur lors du chargement des signets GNOME: %s"), e.message);
        }
    }

    public void setup_gnome_monitor() {
        if (!gnome_bookmarks_file.query_exists()) {
            return;
        }

        try {
            gnome_monitor = gnome_bookmarks_file.monitor_file(FileMonitorFlags.NONE);
            gnome_monitor.changed.connect(on_gnome_bookmarks_changed);
        } catch (Error e) {
            warning(_("Impossible de surveiller les signets GNOME: %s"), e.message);
        }
    }

    private void on_gnome_bookmarks_changed(File file, File? other_file, FileMonitorEvent event_type) {
        if (event_type == FileMonitorEvent.CHANGES_DONE_HINT) {
            // Recharger les signets GNOME avec un léger délai
            Timeout.add(100, () => {
                load_gnome_bookmarks();
                bookmarks_changed();
                return false;
            });
        }
    }
}
