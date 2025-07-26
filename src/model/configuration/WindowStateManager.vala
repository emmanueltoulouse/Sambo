namespace Sambo.Model.Configuration {
    /**
     * Gestionnaire centralisé des états de fenêtre
     * Consolide la logique de sauvegarde/restauration des préférences UI
     */
    public class WindowStateManager : Object {
        private ConfigManager config_manager;
        
        public WindowStateManager(ConfigManager config_manager) {
            this.config_manager = config_manager;
        }
        
        /**
         * Sauvegarde l'état de la fenêtre principale
         */
        public void save_window_state(int width, int height, bool explorer_visible, bool editor_visible, bool communication_visible) {
            config_manager.set_integer("Window", "width", width);
            config_manager.set_integer("Window", "height", height);
            config_manager.set_boolean("Window", "explorer_visible", explorer_visible);
            config_manager.set_boolean("Window", "editor_visible", editor_visible);
            config_manager.set_boolean("Window", "communication_visible", communication_visible);
            config_manager.save();
        }
        
        /**
         * Sauvegarde les positions des panneaux
         */
        public void save_paned_positions(int? top_paned_position, int? main_paned_position) {
            if (top_paned_position != null && top_paned_position > 50 && top_paned_position < 800) {
                config_manager.set_integer("Window", "top_paned_position", top_paned_position);
            }
            
            if (main_paned_position != null && main_paned_position > 100 && main_paned_position < 1000) {
                config_manager.set_integer("Window", "main_paned_position", main_paned_position);
            }
            
            config_manager.save();
        }
        
        /**
         * Restaure les dimensions de la fenêtre
         */
        public void restore_window_dimensions(out int width, out int height) {
            width = config_manager.get_integer("Window", "width", 800);
            height = config_manager.get_integer("Window", "height", 600);
            width = int.max(width, 600);
            height = int.max(height, 450);
        }
        
        /**
         * Restaure les états de visibilité des zones
         */
        public void restore_visibility_states(out bool explorer_visible, out bool editor_visible, out bool communication_visible) {
            explorer_visible = config_manager.get_boolean("Window", "explorer_visible", true);
            editor_visible = config_manager.get_boolean("Window", "editor_visible", true);
            communication_visible = config_manager.get_boolean("Window", "communication_visible", true);
        }
        
        /**
         * Restaure les positions des panneaux
         */
        public void restore_paned_positions(out int top_paned_position, out int main_paned_position) {
            top_paned_position = config_manager.get_integer("Window", "top_paned_position", 280);
            main_paned_position = config_manager.get_integer("Window", "main_paned_position", 500);
        }
        
        /**
         * Sauvegarde l'état d'une zone spécifique
         */
        public void save_zone_visibility(string zone_name, bool visible) {
            config_manager.set_boolean("Window", zone_name + "_visible", visible);
            config_manager.save();
        }
        
        /**
         * Vérifie si les positions sont dans des limites raisonnables
         */
        public bool is_position_valid(int position, int min_value, int max_value) {
            return position >= min_value && position <= max_value;
        }
    }
}