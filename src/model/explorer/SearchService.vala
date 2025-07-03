public class SearchService : Object {
    private static SearchService? instance = null;

    // Signaux pour notifier les résultats de recherche
    public signal void search_started();
    public signal void search_results_found(Gee.List<File> results);
    public signal void search_error(string message);
    public signal void search_completed(int result_count);

    private bool is_searching = false;
    private Cancellable? current_search = null;

    public static SearchService get_instance() {
        if (instance == null) {
            instance = new SearchService();
        }
        return instance;
    }

    public bool get_is_searching() {
        return is_searching;
    }

    public void cancel_search() {
        if (current_search != null && !current_search.is_cancelled()) {
            current_search.cancel();
        }
        is_searching = false;
    }

    // Méthode principale à modifier
    public void search_in_directory(File directory, string search_term, bool recursive = true,
                                   bool case_sensitive = false, string? file_pattern = null) {
        if (is_searching) {
            cancel_search();
        }

        is_searching = true;
        current_search = new Cancellable();

        search_started();

        try {
            new Thread<void>("file-search", () => {
                perform_search(directory, search_term, recursive, case_sensitive,
                              file_pattern, current_search);
            });
        } catch (ThreadError e) {
            // Capturer les erreurs de création de thread
            search_error(_("Impossible de créer le thread de recherche: %s").printf(e.message));
            is_searching = false;
        }
    }

    // Méthode privée pour effectuer la recherche (à ajouter)
    private void perform_search(File directory, string search_term, bool recursive,
                               bool case_sensitive, string? file_pattern, Cancellable cancellable) {
        // Définir les résultats en dehors du bloc try
        var results = new Gee.ArrayList<File>();

        try {
            search_directory_internal(directory, search_term, recursive, case_sensitive,
                                     file_pattern, results, cancellable);

            Idle.add(() => {
                search_completed(results.size);
                search_results_found(results);
                is_searching = false;
                return false;
            });
        } catch (Error error) {  // Renommer pour éviter toute confusion
            // Capturer le message d'erreur dans une variable locale
            // pour éviter les problèmes de portée avec le lambda
            string error_message = error.message;

            Idle.add(() => {
                search_error(_("Erreur interne de recherche: %s").printf(error_message));
                is_searching = false;
                return false;
            });
        }
    }

    private void search_directory_internal(File directory, string search_term, bool recursive,
                                         bool case_sensitive, string? file_pattern,
                                         Gee.List<File> results, Cancellable? cancellable) {
        if (cancellable != null && cancellable.is_cancelled()) {
            return;
        }

        try {
            var enumerator = directory.enumerate_children(
                "standard::*",
                FileQueryInfoFlags.NOFOLLOW_SYMLINKS,
                cancellable
            );

            FileInfo info;
            while ((info = enumerator.next_file(cancellable)) != null) {
                var file = directory.get_child(info.get_name());

                // Vérifier si le fichier correspond au modèle de fichier
                if (file_pattern != null) {
                    if (!PatternSpec.match_simple(file_pattern, info.get_name())) {
                        continue;
                    }
                }

                // Vérifier si le nom correspond au terme de recherche
                string name = info.get_name();
                bool match = case_sensitive ?
                    name.contains(search_term) :
                    name.down().contains(search_term.down());

                if (match) {
                    results.add(file);
                }

                // Recherche récursive dans les sous-répertoires
                if (recursive && info.get_file_type() == FileType.DIRECTORY) {
                    search_directory_internal(file, search_term, recursive,
                                           case_sensitive, file_pattern,
                                           results, cancellable);
                }
            }
        } catch (Error e) {
            if (!(e is IOError.CANCELLED)) {
                warning(_("Erreur lors de la recherche dans %s: %s"),
                      directory.get_path(), e.message);
            }
        }
    }

    // Méthode avancée avec options supplémentaires
    public void advanced_search(File directory, string search_term,
                               bool recursive = true,
                               bool case_sensitive = false,
                               string? file_pattern = null,
                               DateTime? modified_after = null,
                               DateTime? modified_before = null,
                               bool search_content = false) {
        // TODO: Implémenter la recherche avancée avec toutes les options
        search_in_directory(directory, search_term, recursive, case_sensitive, file_pattern);
    }
}
