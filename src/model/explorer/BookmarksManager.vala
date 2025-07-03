public class BookmarksManager : Object {
    private static BookmarksManager? instance = null;
    private Gee.List<File> bookmarks;
    private File bookmarks_file;

    public signal void bookmarks_changed();

    public static BookmarksManager get_instance() {
        if (instance == null) {
            instance = new BookmarksManager();
        }
        return instance;
    }

    private BookmarksManager() {
        bookmarks = new Gee.ArrayList<File>();

        // Localisation du fichier de favoris
        string config_dir = Environment.get_user_config_dir();
        string app_config_dir = Path.build_filename(config_dir, "sambo");

        try {
            File dir = File.new_for_path(app_config_dir);
            if (!dir.query_exists()) {
                dir.make_directory_with_parents();
            }

            bookmarks_file = File.new_for_path(Path.build_filename(app_config_dir, "bookmarks.txt"));
            load_bookmarks();
        } catch (Error e) {
            warning(_("Erreur lors de l'initialisation des favoris: %s"), e.message);
        }
    }

    public Gee.List<File> get_bookmarks() {
        return bookmarks;
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
        bookmarks_changed();
    }
}
