/**
 * CommandView - Classe de gestion des commandes de l'application
 *
 * Cette classe est responsable de :
 * - Traiter les commandes entrées par l'utilisateur
 * - Servir d'interface entre l'UI et le modèle de communication
 * - Gérer les actions spécifiques aux macros, chat IA et terminal
 */

using Sambo; // Ajouter le namespace Sambo pour accéder à ApplicationController

public class CommandView {
    // Contrôleur de l'application
    private Sambo.ApplicationController? controller;

    /**
     * Crée une nouvelle instance de CommandView
     *
     * @param controller Contrôleur principal de l'application
     */
    public CommandView(Sambo.ApplicationController controller) {
        this.controller = controller;
    }

    /**
     * Traite un message de chat envoyé par l'utilisateur
     *
     * @param message Le message à traiter
     */
    public void process_chat_message(string message) {
        // Implémenter le traitement des messages chat
        // Cette méthode sera appelée depuis l'UI du chat
    }

    /**
     * Exécute une commande de terminal
     *
     * @param command La commande à exécuter
     */
    public void execute_terminal_command(string command) {
        // Vérifier que le contrôleur n'est pas null avant d'appeler la méthode
        if (controller != null) {
            controller.execute_terminal_command(command);
        }
    }

    /**
     * Exécute une macro spécifiée
     *
     * @param macro_name Nom de la macro à exécuter
     * @param params Paramètres optionnels pour la macro
     */
    public void execute_macro(string macro_name, string[]? params = null) {
        // Implémenter l'exécution des macros
        // Cette fonctionnalité sera développée ultérieurement
    }
}
