public void show_toast(string message, int timeout = 2) {
    // À adapter selon l'intégration réelle de l'UI
    var toast = new Adw.Toast(message);
    toast.set_timeout(timeout);
    // Ici, il faudrait ajouter le toast à l'overlay de la fenêtre principale
}

public void on_new_document() {
    // Méthode vide pour remplacer la logique
}

public void on_open_document() {
    try {
        // ...logique d'ouverture...
        show_toast("Chargement réussi");
    } catch (Error e) {
        show_toast("Erreur lors du chargement : " + e.message, 4);
    }
}

public void on_save_document() {
    try {
        // ...logique de sauvegarde...
        show_toast("Document sauvegardé");
    } catch (Error e) {
        show_toast("Erreur lors de la sauvegarde : " + e.message, 4);
    }
}