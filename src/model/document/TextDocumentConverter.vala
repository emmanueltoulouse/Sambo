namespace Sambo.Document {
    /**
     * Convertisseur minimal pour les fichiers texte (phase 1).
     */
    public class TextDocumentConverter : Object, DocumentConverter {
        public PivotDocument to_pivot(string content, string path) {
            var pivot = new PivotDocument();
            pivot.source_path = path;
            pivot.source_format = "txt";
            if (content != null) {
                pivot.content = content;  // Utilise notre accesseur qui convertit en PivotParagraph
            }
            return pivot;
        }

        public string from_pivot(PivotDocument pivot) {
            return pivot.content;  // Utilise notre accesseur qui convertit l'AST en texte
        }
    }
}
