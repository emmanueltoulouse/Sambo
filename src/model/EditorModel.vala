namespace Sambo {
    public class EditorModel {
        // Propriétés de base pour l'éditeur de texte
        public string current_file { get; set; default = ""; }

        // TODO: Intégrer PivotDocument et DocumentConverterManager pour la gestion du document pivot (phase 1)

        public EditorModel() {
            // Constructeur vide pour le moment
        }
    }
}
