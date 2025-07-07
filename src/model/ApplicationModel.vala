namespace Sambo {
    public class ApplicationModel {
        // Structure pour stocker la configuration
        public ConfigManager config_manager;

        // Gestionnaire de modèles IA
        public ModelManager model_manager;

        // Structures pour stocker les données des trois zones
        public ExplorerModel explorer;
        public EditorModel editor;
        public CommunicationModel communication;

        public ApplicationModel(ApplicationController controller) {
            config_manager = new ConfigManager();
            model_manager = new ModelManager();
            explorer = new ExplorerModel(controller);
            editor = new EditorModel();
            communication = new CommunicationModel();
        }
    }
}
