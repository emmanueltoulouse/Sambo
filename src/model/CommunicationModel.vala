using GLib;

namespace Sambo {
    public class CommunicationModel {
        // Onglet actif (0=IA, 1=Terminal, 2=Macros)
        public int active_tab { get; set; default = 0; }

        // Liste de messages du chat
        private List<ChatMessage> chat_messages;

        // Signal émis lorsqu'un nouveau message est ajouté
        public signal void message_added(ChatMessage message);

        // Signal pour les commandes terminal
        public signal void terminal_command_executed(string command, string output);

        public CommunicationModel() {
            chat_messages = new List<ChatMessage>();
        }

        /**
         * Configure le contrôleur pour écouter les signaux
         */
        public void setup_controller(ApplicationController controller) {
            terminal_command_executed.connect((command, output) => {
                controller.terminal_command_signal(command, output);
            });
        }

        /**
         * Ajoute un message à l'historique du chat
         */
        public void add_message(ChatMessage message) {
            chat_messages.append(message);
            message_added(message);
        }

        /**
         * Récupère tous les messages du chat
         */
        public unowned List<ChatMessage> get_messages() {
            return chat_messages;
        }

        /**
         * Exécute une commande dans le terminal
         * @param command La commande à exécuter
         */
        public void execute_terminal_command(string command) {
            // Simulation d'exécution de commande
            string output = "";

            // Commandes simples pour démonstration
            if (command == "hello" || command == "bonjour") {
                output = "Bonjour à vous ! Comment puis-je vous aider ?";
            } else if (command == "help" || command == "aide") {
                output = "Commandes disponibles :\n" +
                         "- hello, bonjour : Affiche un message de salutation\n" +
                         "- date : Affiche la date et l'heure actuelles\n" +
                         "- version : Affiche la version de l'application\n" +
                         "- help, aide : Affiche ce message d'aide";
            } else if (command == "date") {
                var datetime = new DateTime.now_local();
                output = "Date et heure actuelles : " + datetime.format("%x %X");
            } else if (command == "version") {
                output = "Sambo version 0.1.0";
            } else if (command == "clear" || command == "cls") {
                // Commande spéciale traitée directement dans la vue
                output = "CLEAR_TERMINAL";
            } else if (command.strip() == "") {
                // Commande vide
                output = "";
            } else {
                output = "Commande inconnue : " + command + "\nTapez 'help' pour voir les commandes disponibles.";
            }

            // Émettre le signal avec la sortie
            terminal_command_executed(command, output);
        }
    }
}
