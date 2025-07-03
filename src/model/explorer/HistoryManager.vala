public class HistoryManager : Object {
    private static HistoryManager? instance = null;
    private Gee.List<File> history;
    private File history_file;
    private const int MAX_HISTORY_SIZE = 50;

    public signal void history_changed();

    public static HistoryManager get_instance() {
        if (instance == null) {
            instance = new HistoryManager();
        }
        return instance;
    }

    private HistoryManager() {
        history = new Gee.ArrayList<File>();

        // Localisation du fichier d'historique
        string config_dir = Environment.get_user_config_dir();
        string app_config_dir = Path.build_filename(config_dir, "sambo");

        try {
            File dir = File.new_for_path(app_config_dir);
            if (!dir.query_exists()) {
                dir.make_directory_with_parents();
            }

            history_file = File.new_for_path(Path.build_filename(app_config_dir, "history.txt"));
            load_history();
        } catch (Error e) {
            warning(_("Erreur lors de l'initialisation de l'historique: %s"), e.message);
        }
    }

    public Gee.List<File> get_history() {
        return history;
    }

    public void add_to_history(File file) {
        // Supprimer l'entrée si elle existe déjà
        for (int i = 0; i < history.size; i++) {
            if (history[i].get_path() == file.get_path()) {
                history.remove_at(i);
                break;
            }
        }

        // Ajouter au début de la liste
        history.insert(0, file);

        // Limiter la taille de l'historique
        while (history.size > MAX_HISTORY_SIZE) {
            history.remove_at(history.size - 1);
        }

        save_history();
        history_changed();
    }

    public void clear_history() {
        history.clear();
        save_history();
        history_changed();
    }

    private void load_history() {
        history.clear();

        if (!history_file.query_exists()) {
            return;
        }

        try {
            var dis = new DataInputStream(history_file.read());
            string line;

            while ((line = dis.read_line()) != null) {
                if (line.strip() != "") {
                    var file = File.new_for_path(line);
                    history.add(file);
                }
            }
        } catch (Error e) {
            warning(_("Erreur lors du chargement de l'historique: %s"), e.message);
        }
    }

    private void save_history() {
        try {
            var dos = new DataOutputStream(
                history_file.replace(null, false, FileCreateFlags.NONE)
            );

            foreach (var entry in history) {
                dos.put_string(entry.get_path() + "\n");
            }
        } catch (Error e) {
            warning(_("Erreur lors de l'enregistrement de l'historique: %s"), e.message);
        }
    }

    public void refresh_history() {
        load_history();
        history_changed();
    }
}
