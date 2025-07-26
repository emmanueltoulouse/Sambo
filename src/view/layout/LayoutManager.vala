using Gtk;
using Adw;

namespace Sambo.View.Layout {
    /**
     * Gestionnaire de disposition pour la fenêtre principale
     * Extrait la logique complexe de layout de MainWindow
     */
    public class LayoutManager : Object {
        private Paned main_paned;
        private Paned? top_paned;
        private ExplorerView? explorer_view;
        private Notebook editor_notebook;
        private CommunicationView communication_view;
        
        private bool use_detached_explorer;
        private bool layout_updating = false;
        
        // États de visibilité
        public bool explorer_visible { get; set; default = true; }
        public bool editor_visible { get; set; default = true; }
        public bool communication_visible { get; set; default = true; }
        
        public LayoutManager(
            Paned main_paned,
            Paned? top_paned,
            ExplorerView? explorer_view,
            Notebook editor_notebook,
            CommunicationView communication_view,
            bool use_detached_explorer
        ) {
            this.main_paned = main_paned;
            this.top_paned = top_paned;
            this.explorer_view = explorer_view;
            this.editor_notebook = editor_notebook;
            this.communication_view = communication_view;
            this.use_detached_explorer = use_detached_explorer;
        }
        
        /**
         * Met à jour le layout en fonction de la visibilité des zones
         */
        public void update_adaptive_layout() {
            if (use_detached_explorer || main_paned == null) return;
            
            // Éviter les appels récursifs
            if (layout_updating) return;
            layout_updating = true;
            
            try {
                // Vérifier l'état actuel des zones
                bool explorer_shown = explorer_visible && explorer_view != null;
                bool editor_shown = editor_visible && editor_notebook != null;
                bool communication_shown = communication_visible && communication_view != null;
                
                // Debug
                stderr.printf("🔧 LAYOUT: explorer=%s, editor=%s, communication=%s\n",
                    explorer_shown ? "VISIBLE" : "MASQUÉ",
                    editor_shown ? "VISIBLE" : "MASQUÉ",
                    communication_shown ? "VISIBLE" : "MASQUÉ");
                
                if (!explorer_shown && !editor_shown && communication_shown) {
                    configure_chat_only_layout();
                } else if (!explorer_shown && editor_shown && communication_shown) {
                    configure_editor_chat_layout();
                } else if (explorer_shown && !editor_shown && communication_shown) {
                    configure_explorer_chat_layout();
                } else if (explorer_shown || editor_shown) {
                    configure_normal_layout(explorer_shown, editor_shown, communication_shown);
                } else {
                    configure_fallback_layout();
                }
                
                force_layout_refresh();
            } finally {
                layout_updating = false;
            }
        }
        
        private void configure_chat_only_layout() {
            stderr.printf("🔧 LAYOUT: Mode CHAT SEUL\n");
            if (top_paned != null && top_paned.get_parent() == main_paned) {
                main_paned.set_start_child(null);
            }
            main_paned.set_end_child(communication_view);
            if (communication_view != null) communication_view.set_visible(true);
            if (top_paned != null) top_paned.set_visible(false);
        }
        
        private void configure_editor_chat_layout() {
            stderr.printf("🔧 LAYOUT: Mode EDITEUR + CHAT\n");
            
            // Détacher editor_notebook seulement si nécessaire
            if (editor_notebook.get_parent() != main_paned) {
                if (editor_notebook.get_parent() != null) {
                    editor_notebook.unparent();
                }
                main_paned.set_start_child(editor_notebook);
            }
            
            // Détacher communication_view seulement si nécessaire
            if (communication_view.get_parent() != main_paned) {
                if (communication_view.get_parent() != null) {
                    communication_view.unparent();
                }
                main_paned.set_end_child(communication_view);
            }
            
            if (editor_notebook != null) editor_notebook.set_visible(true);
            if (communication_view != null) communication_view.set_visible(true);
            if (top_paned != null) top_paned.set_visible(false);
        }
        
        private void configure_explorer_chat_layout() {
            stderr.printf("🔧 LAYOUT: Mode EXPLORATEUR + CHAT\n");
            main_paned.set_start_child(explorer_view);
            main_paned.set_end_child(communication_view);
            if (explorer_view != null) explorer_view.set_visible(true);
            if (communication_view != null) communication_view.set_visible(true);
            if (top_paned != null) top_paned.set_visible(false);
        }
        
        private void configure_normal_layout(bool explorer_shown, bool editor_shown, bool communication_shown) {
            stderr.printf("🔧 LAYOUT: Mode NORMAL avec top_paned\n");
            
            if (top_paned == null) return;
            
            main_paned.set_start_child(top_paned);
            if (communication_shown) {
                main_paned.set_end_child(communication_view);
            } else {
                main_paned.set_end_child(null);
            }
            
            // Configuration du top_paned
            if (explorer_shown && editor_shown) {
                top_paned.set_start_child(explorer_view);
                top_paned.set_end_child(editor_notebook);
            } else if (explorer_shown) {
                top_paned.set_start_child(explorer_view);
                top_paned.set_end_child(null);
            } else if (editor_shown) {
                top_paned.set_start_child(null);
                top_paned.set_end_child(editor_notebook);
            }
            
            // Visibilité
            top_paned.set_visible(true);
            if (explorer_view != null) explorer_view.set_visible(explorer_shown);
            if (editor_notebook != null) editor_notebook.set_visible(editor_shown);
            if (communication_view != null) communication_view.set_visible(communication_shown);
        }
        
        private void configure_fallback_layout() {
            stderr.printf("🔧 LAYOUT: Mode FALLBACK\n");
            main_paned.set_start_child(editor_notebook);
            main_paned.set_end_child(null);
            if (editor_notebook != null) editor_notebook.set_visible(true);
            
            // Mise à jour des états
            editor_visible = true;
        }
        
        private void force_layout_refresh() {
            // FORCER le recalcul GTK4
            if (main_paned != null) {
                main_paned.queue_resize();
                main_paned.queue_allocate();
            }
            if (top_paned != null && top_paned.get_visible()) {
                top_paned.queue_resize();
                top_paned.queue_allocate();
            }
            
            // Forcer le rafraîchissement de l'éditeur
            if (editor_notebook != null && editor_visible) {
                editor_notebook.queue_resize();
                editor_notebook.queue_allocate();
            }
        }
        
        /**
         * Force un rafraîchissement différé pour s'assurer que le layout est correct
         */
        public void schedule_delayed_refresh() {
            GLib.Idle.add(() => {
                if (editor_notebook != null && editor_visible) {
                    editor_notebook.queue_draw();
                }
                return false; // Ne pas répéter
            });
        }
    }
}