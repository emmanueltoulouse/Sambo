using Sambo.Document;
using GLib;

namespace Sambo.Document {
    /**
     * Gestionnaire central des convertisseurs de documents (phase 1).
     */
    public class DocumentConverterManager : Object {
    private static DocumentConverterManager? instance = null;
    private DocumentConverter txt_converter;
    private DocumentConverter md_converter;
    private DocumentConverter html_converter;
    private DocumentConverter pivot_converter;

    private DocumentConverterManager() {
        txt_converter = new TextDocumentConverter();
        md_converter = new MarkdownDocumentConverter();
        html_converter = new HtmlDocumentConverter();
        pivot_converter = new PivotDocumentConverter();
    }

    public static DocumentConverterManager get_instance() {
        if (instance == null) {
            instance = new DocumentConverterManager();
        }
        return instance;
    }

    /**
     * Crée un document pivot à partir d'un contenu brut, sans passer par un fichier
     * @param content Le contenu brut à convertir
     * @param path Le chemin fictif ou réel (pour déterminer le format)
     * @param format_hint Format suggéré ("md", "html", "txt", "pivot"), utilisé si path est vide
     * @return Un nouveau document pivot représentant le contenu
     */
    public PivotDocument create_document_from_content(string content, string path, string format_hint = "txt") throws Error {
        PivotDocument doc;

        // Déterminer le format à partir du chemin ou de l'indice format_hint
        if (path != "") {
            if (path.has_suffix(".pivot")) {
                doc = pivot_converter.to_pivot(content, path);
            } else if (path.has_suffix(".md")) {
                doc = md_converter.to_pivot(content, path);
            } else if (path.has_suffix(".html") || path.has_suffix(".htm")) {
                doc = html_converter.to_pivot(content, path);
            } else {
                doc = txt_converter.to_pivot(content, path);
            }
        } else {
            // Utiliser l'indice de format
            if (format_hint == "md") {
                doc = md_converter.to_pivot(content, "");
            } else if (format_hint == "html") {
                doc = html_converter.to_pivot(content, "");
            } else if (format_hint == "pivot") {
                doc = pivot_converter.to_pivot(content, "");
            } else {
                doc = txt_converter.to_pivot(content, "");
            }
        }

        // Vérification supplémentaire pour garantir un document valide
        if (doc == null) {
            doc = new PivotDocument();
            doc.source_path = path;
            doc.content = content;
        }

        return doc;
    }

    /**
     * Ouvre un fichier et le convertit en document pivot
     * @param path Le chemin vers le fichier à ouvrir
     * @return Un nouveau document pivot représentant le contenu du fichier
     */
    public PivotDocument? open_file_as_pivot(string path) throws Error {
        if (!FileUtils.test(path, FileTest.EXISTS)) {
            throw new FileError.NOENT("Le fichier %s n'existe pas".printf(path));
        }

        string content;
        FileUtils.get_contents(path, out content);

        return create_document_from_content(content, path);
    }

    public string save_pivot_to_file(PivotDocument pivot, string path) throws Error {
        if (path.has_suffix(".pivot")) {
            FileUtils.set_contents(path, pivot_converter.from_pivot(pivot));
            return path;
        } else if (path.has_suffix(".md")) {
            FileUtils.set_contents(path, md_converter.from_pivot(pivot));
            return path;
        } else if (path.has_suffix(".html") || path.has_suffix(".htm")) {
            FileUtils.set_contents(path, html_converter.from_pivot(pivot));
            return path;
        } else {
            FileUtils.set_contents(path, txt_converter.from_pivot(pivot));
            return path;
        }
    }
    }
}
