public class IconCache : Object {
    private static IconCache? instance = null;
    private Gee.HashMap<string, Icon> icon_cache;
    
    public static IconCache get_instance() {
        if (instance == null) {
            instance = new IconCache();
        }
        return instance;
    }
    
    private IconCache() {
        icon_cache = new Gee.HashMap<string, Icon>();
    }
    
    public Icon get_icon_for_file(File file) {
        string path = file.get_path();
        
        if (icon_cache.has_key(path)) {
            return icon_cache[path];
        }
        
        try {
            FileInfo info = file.query_info("standard::*", FileQueryInfoFlags.NONE);
            Icon icon = info.get_icon();
            icon_cache[path] = icon;
            return icon;
        } catch (Error e) {
            warning(_("Erreur lors du chargement de l'icône: %s"), e.message);
            // Retourner une icône par défaut
            return new ThemedIcon("text-x-generic");
        }
    }
    
    public Icon get_icon_for_mime_type(string mime_type) {
        if (icon_cache.has_key(mime_type)) {
            return icon_cache[mime_type];
        }
        
        var icon = ContentType.get_icon(mime_type);
        icon_cache[mime_type] = icon;
        return icon;
    }
    
    public void clear_cache() {
        icon_cache.clear();
    }
}