using Sambo.Document;

/**
 * Interface pour les convertisseurs de documents (phase 1).
 */
public interface DocumentConverter : Object {
    public abstract PivotDocument to_pivot(string content, string path);
    public abstract string from_pivot(PivotDocument pivot);
}
