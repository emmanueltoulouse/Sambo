namespace Sambo {
    public class ApplicationModel {
        // Structure pour stocker la configuration
        public ConfigManager config_manager;

        // Structures pour stocker les données des trois zones
        public ExplorerModel explorer;
        public EditorModel editor;
        public CommunicationModel communication;

        public ApplicationModel(ApplicationController controller) {
            config_manager = new ConfigManager();
            explorer = new ExplorerModel(controller);
            editor = new EditorModel();
            communication = new CommunicationModel();
        }
    }
}
