using Gtk;
using Adw;
using Gee;

// Import pour la fenêtre HuggingFace
using Sambo.View.Windows;

namespace Sambo {

public enum DocumentSource {
    UNKNOWN,
    EXPLORER,
    FILE_DIALOG
}

public class MainWindow : Adw.ApplicationWindow {
    private ApplicationController controller;

    private Adw.HeaderBar header_bar;
    private Box main_box;
    private Paned main_paned;
    private Paned top_paned;
    private Paned editor_comm_paned;

    private ExplorerView? explorer_view;
    private CommunicationView communication_view;
    private ToggleButton explorer_button;
    private ToggleButton communication_button;
    private ToggleButton editor_button;

    private Notebook editor_notebook;
    private Gee.List<EditorView> editor_tabs = new Gee.ArrayList<EditorView>();
    private bool use_detached_explorer = false;
    private bool explorer_visible = true;
    private bool editor_visible = true;
    private bool communication_visible = true;
    private bool layout_updating = false; // Évite les appels récursifs
    private bool configuration_applied = false; // Flag pour éviter les applications multiples
    private bool initializing = true; // Flag pour éviter la sauvegarde pendant l'initialisation

    public signal void file_opened(string path);
    public signal void directory_changed(string path);

    public MainWindow(Gtk.Application app, ApplicationController controller, bool detached_explorer_mode = false) {
        Object(
            application: app,
            title: "Sambo",
            default_width: 1200,
            default_height: 600,
            resizable: true
        );
        this.controller = controller;
        this.use_detached_explorer = detached_explorer_mode;

        // Traces pour debug icône
        stdout.printf("[TRACE] MainWindow: set_icon_name(com.cabineteto.Sambo)\n");
        this.set_icon_name("com.cabineteto.Sambo");

        setup_ui();
        setup_actions();
        connect_signals();

        // Connexion au signal map pour appliquer la configuration quand l'interface est prête
        this.map.connect(() => {
            if (!configuration_applied) {
                stderr.printf("🎯 INIT: Interface mappée, application différée de la configuration\n");
                // Utiliser Idle.add pour reporter l'application après le rendu complet
                GLib.Idle.add(() => {
                    apply_saved_configuration();
                    return false; // Ne pas répéter
                });
            }
        });
    }

    // === UI ===
    private void setup_ui() {
        main_box = new Box(Orientation.VERTICAL, 0);

        // HeaderBar
        header_bar = new Adw.HeaderBar();

        // Boutons de toggle pour l'interface (à gauche)
        explorer_button = new ToggleButton();
        explorer_button.set_icon_name("folder-symbolic");
        explorer_button.set_tooltip_text("Afficher/Masquer l'explorateur");
        // État par défaut visible, signaux connectés après configuration
        explorer_button.set_active(true);
        header_bar.pack_start(explorer_button);

        editor_button = new ToggleButton();
        editor_button.set_icon_name("text-editor-symbolic");
        editor_button.set_tooltip_text("Afficher/Masquer la zone d'édition");
        // État par défaut visible, signaux connectés après configuration
        editor_button.set_active(true);
        header_bar.pack_start(editor_button);

        communication_button = new ToggleButton();
        communication_button.set_icon_name("mail-message-new-symbolic");
        communication_button.set_tooltip_text("Afficher/Masquer la zone de communication");
        // État par défaut visible, signaux connectés après configuration
        communication_button.set_active(true);
        header_bar.pack_start(communication_button);

        // Menu hamburger à droite
        var menu_button = new MenuButton();
        menu_button.set_icon_name("open-menu-symbolic");
        menu_button.set_tooltip_text("Menu principal");
        menu_button.set_menu_model(build_app_menu());
        header_bar.pack_end(menu_button);

        main_box.append(header_bar);

        // Paned principal
        main_paned = new Paned(Orientation.VERTICAL);
        main_paned.set_vexpand(true);
        main_paned.set_wide_handle(true);

        if (use_detached_explorer) {
            explorer_view = null;
            top_paned = null;
            editor_notebook = new Notebook();
            main_box.append(editor_notebook);
            communication_view = new CommunicationView(controller);
            main_paned.set_end_child(communication_view);
            editor_comm_paned = main_paned;
        } else {
            top_paned = new Paned(Orientation.HORIZONTAL);
            top_paned.set_wide_handle(true);
            top_paned.set_vexpand(true);

            var explorer_model = ApplicationControllerExtension.get_explorer_model(controller);
            explorer_view = new ExplorerView(explorer_model);
            top_paned.set_start_child(explorer_view);

            editor_notebook = new Notebook();
            top_paned.set_end_child(editor_notebook);            // Zone de communication
            communication_view = new CommunicationView(controller);

            main_paned.set_start_child(top_paned);
            main_paned.set_end_child(communication_view);

            main_paned.set_resize_start_child(true);
            main_paned.set_shrink_start_child(true);
            top_paned.set_resize_start_child(false);
            top_paned.set_shrink_start_child(false);

            top_paned.set_position(280);

            editor_comm_paned = main_paned;
        }

        main_box.append(main_paned);

        // Créer un ToastOverlay autour de main_box
        var toast_overlay = new Adw.ToastOverlay();
        toast_overlay.set_child(main_box);
        set_content(toast_overlay);

        // Onglet par défaut
        var default_editor = new EditorView(controller);
        default_editor.set_document_source((EditorView.DocumentSource)DocumentSource.UNKNOWN);
        default_editor.set_current_file_path("");
        editor_tabs.add(default_editor);
        var default_tab_box = create_tab_box(_("Nouveau document"), default_editor);
        editor_notebook.append_page(default_editor, default_tab_box);
        editor_notebook.set_tab_reorderable(default_editor, true);
        editor_notebook.set_current_page(0);
    }

    // === Actions et menus ===
    private void setup_actions() {
        var quit_action = new SimpleAction("quit", null);
        quit_action.activate.connect(() => {
            if (should_confirm_quit()) {
                var dialog = new Adw.AlertDialog(
                    _("Quitter l'application"),
                    _("Êtes-vous sûr de vouloir quitter ? Les modifications non enregistrées seront perdues.")
                );
                dialog.add_response("cancel", _("Annuler"));
                dialog.add_response("quit", _("Quitter"));
                dialog.set_response_appearance("quit", Adw.ResponseAppearance.DESTRUCTIVE);
                dialog.response.connect((response) => {
                    if (response == "quit") {
                        save_window_state();
                        application.quit();
                    }
                });
                dialog.present(this);
            } else {
                save_window_state();
                application.quit();
            }
        });

        var preferences_action = new SimpleAction("preferences", null);
        preferences_action.activate.connect(() => {
            var prefs_window = new PreferencesWindow(controller);
            prefs_window.present();
        });

        var about_action = new SimpleAction("about", null);
        about_action.activate.connect(() => {
            stdout.printf("[TRACE] MainWindow: Ouverture de la boîte À propos avec logo_icon_name=com.cabineteto.Sambo\n");
            var about = new Gtk.AboutDialog() {
                transient_for = this,
                program_name = "Sambo",
                logo_icon_name = "com.cabineteto.Sambo",
                version = "0.1.0",
                authors = { "Cabinet ETO" },
                copyright = "© 2023 Cabinet ETO",
                license_type = Gtk.License.GPL_3_0,
                website = "https://cabineteto.com",
                website_label = _("Site Web")
            };
            about.present();
        });

        add_action(quit_action);
        add_action(preferences_action);
        add_action(about_action);

        application.set_accels_for_action("win.quit", {"<Control>q"});
        application.set_accels_for_action("win.preferences", {"<Control>comma"});

        var save_action = new SimpleAction("save-file", null);
        save_action.activate.connect(() => { save_current_document(); });
        this.add_action(save_action);

        var save_as_action = new SimpleAction("save-file-as", null);
        save_as_action.activate.connect(() => { save_current_document_as(); });
        this.add_action(save_as_action);

        application.set_accels_for_action("win.save-file", {"<Control>s"});
        application.set_accels_for_action("win.save-file-as", {"<Control><Shift>s"});

        var tracking_sambo_action = new SimpleAction("tracking-sambo", null);
        tracking_sambo_action.activate.connect(() => {
            var tracking_window = new TrackingWindow(controller);
            tracking_window.present();
        });
        this.add_action(tracking_sambo_action);

        // Action pour les modèles HuggingFace
        var huggingface_models_action = new SimpleAction("huggingface-models", null);
        huggingface_models_action.activate.connect(() => {
            var hf_window = new HuggingFaceModelsWindow(controller);
            hf_window.present();
        });
        this.add_action(huggingface_models_action);

        var toggle_explorer_action = new SimpleAction("toggle-explorer", null);
        toggle_explorer_action.activate.connect(() => {
            explorer_button.set_active(!explorer_button.get_active());
            // Cela déclenche déjà la logique via le signal toggled du bouton
        });
        this.add_action(toggle_explorer_action);

        var toggle_communication_action = new SimpleAction("toggle-communication", null);
        toggle_communication_action.activate.connect(() => {
            communication_button.set_active(!communication_button.get_active());
            // Cela déclenche déjà la logique via le signal toggled du bouton
        });
        this.add_action(toggle_communication_action);

        var toggle_editor_action = new SimpleAction("toggle-editor", null);
        toggle_editor_action.activate.connect(() => {
            editor_button.set_active(!editor_button.get_active());
            // Cela déclenche déjà la logique via le signal toggled du bouton
        });
        this.add_action(toggle_editor_action);
    }

    // === Gestion de la visibilité de la zone d'édition ===
    private void toggle_editor_visibility(bool show) {
        editor_visible = show;

        if (editor_notebook == null) return;

        editor_notebook.set_visible(show);

        // Sauvegarder l'état
        var config = controller.get_config_manager();
        config.set_boolean("Window", "editor_visible", show);
        config.save();

        // Mettre à jour le layout adaptatif
        update_adaptive_layout();
    }

    // === Gestion de la visibilité de la zone de communication ===
    private void toggle_communication_visibility(bool show) {
        communication_visible = show;

        if (communication_view == null) return;

        communication_view.set_visible(show);

        // Sauvegarder l'état
        var config = controller.get_config_manager();
        config.set_boolean("Window", "communication_visible", show);
        config.save();

        // Mettre à jour le layout adaptatif
        update_adaptive_layout();
    }

    /**
     * Met à jour le layout en fonction de la visibilité des zones
     * Si l'explorateur et l'éditeur sont masqués, la zone de chat prend toute la largeur
     */
    private void update_adaptive_layout() {
        if (use_detached_explorer || main_paned == null || top_paned == null) return;

        // Éviter les appels récursifs
        if (layout_updating) return;
        layout_updating = true;

        // Vérifier l'état actuel des zones
        bool explorer_shown = explorer_visible && explorer_view != null;
        bool editor_shown = editor_visible && editor_notebook != null;
        bool communication_shown = communication_visible && communication_view != null;

        // Debug
        stderr.printf("🔧 LAYOUT: explorer=%s, editor=%s, communication=%s\n",
            explorer_shown ? "VISIBLE" : "MASQUÉ",
            editor_shown ? "VISIBLE" : "MASQUÉ",
            communication_shown ? "VISIBLE" : "MASQUÉ");

        // NOUVELLE APPROCHE : Configuration directe avec force de recalcul

        if (!explorer_shown && !editor_shown && communication_shown) {
            // Chat seul - configuration directe
            stderr.printf("🔧 LAYOUT: Mode CHAT SEUL\n");
            if (top_paned.get_parent() == main_paned) main_paned.set_start_child(null);
            main_paned.set_end_child(communication_view);
            if (communication_view != null) communication_view.set_visible(true);
            if (top_paned != null) top_paned.set_visible(false);

        } else if (!explorer_shown && editor_shown && communication_shown) {
            // Éditeur + Chat - configuration directe
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

        } else if (explorer_shown && !editor_shown && communication_shown) {
            // Explorateur + Chat
            stderr.printf("🔧 LAYOUT: Mode EXPLORATEUR + CHAT\n");
            main_paned.set_start_child(explorer_view);
            main_paned.set_end_child(communication_view);
            if (explorer_view != null) explorer_view.set_visible(true);
            if (communication_view != null) communication_view.set_visible(true);
            if (top_paned != null) top_paned.set_visible(false);

        } else if (explorer_shown || editor_shown) {
            // Layout normal avec top_paned
            stderr.printf("🔧 LAYOUT: Mode NORMAL avec top_paned\n");
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
            if (top_paned != null) top_paned.set_visible(true);
            if (explorer_view != null) explorer_view.set_visible(explorer_shown);
            if (editor_notebook != null) editor_notebook.set_visible(editor_shown);
            if (communication_view != null) communication_view.set_visible(communication_shown);

        } else {
            // Fallback - au moins l'éditeur
            stderr.printf("🔧 LAYOUT: Mode FALLBACK\n");
            main_paned.set_start_child(editor_notebook);
            main_paned.set_end_child(null);
            if (editor_notebook != null) editor_notebook.set_visible(true);
            editor_visible = true;
            if (editor_button != null) editor_button.set_active(true);
        }

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
        if (editor_notebook != null && editor_shown) {
            editor_notebook.queue_resize();
            editor_notebook.queue_allocate();
            // Forcer le rafraîchissement de tous les onglets d'éditeur
            for (int i = 0; i < editor_tabs.size; i++) {
                var editor = editor_tabs[i];
                if (editor != null) {
                    editor.queue_resize();
                    editor.queue_allocate();
                }
            }
        }

        this.queue_resize();

        // Libérer le verrou
        layout_updating = false;

        // Forcer un rafraîchissement différé pour s'assurer que le layout est correct
        Idle.add(() => {
            if (editor_notebook != null && editor_shown) {
                editor_notebook.queue_draw();
                for (int i = 0; i < editor_tabs.size; i++) {
                    var editor = editor_tabs[i];
                    if (editor != null) {
                        editor.queue_draw();
                    }
                }
            }
            return false; // Ne pas répéter
        });
    }

    private GLib.MenuModel build_app_menu() {
        var menu = new GLib.Menu();
        var file_menu = new GLib.Menu();
        file_menu.append(_("Nouveau"), "win.new-file");
        file_menu.append(_("Ouvrir..."), "win.open-file");
        file_menu.append(_("Enregistrer"), "win.save-file");
        file_menu.append(_("Enregistrer sous..."), "win.save-file-as");
        file_menu.append(_("Fermer"), "win.close-file");
        file_menu.append(_("Quitter"), "win.quit");

        var edit_menu = new GLib.Menu();
        edit_menu.append(_("Annuler"), "win.undo");
        edit_menu.append(_("Rétablir"), "win.redo");
        edit_menu.append(_("Couper"), "win.cut");
        edit_menu.append(_("Copier"), "win.copy");
        edit_menu.append(_("Coller"), "win.paste");

        var view_menu = new GLib.Menu();
        view_menu.append(_("Plein écran"), "win.fullscreen");
        view_menu.append(_("Mode sombre"), "win.dark-mode");
        // AJOUT ICI :
        view_menu.append(_("Afficher/Masquer l'explorateur"), "win.toggle-explorer");
        view_menu.append(_("Afficher/Masquer l'éditeur"), "win.toggle-editor");
        view_menu.append(_("Afficher/Masquer la communication"), "win.toggle-communication");

        var tools_menu = new GLib.Menu();
        tools_menu.append(_("Préférences"), "win.preferences");
        tools_menu.append(_("Comparer des fichiers..."), "win.compare-files");
        tools_menu.append(_("Extensions..."), "win.extensions");
        // AJOUT ICI :
        tools_menu.append(_("Modèle HuggingFace"), "win.huggingface-models");
        tools_menu.append(_("Suivi Sambo"), "win.tracking-sambo");

        var help_menu = new GLib.Menu();
        help_menu.append(_("Documentation"), "win.documentation");
        help_menu.append(_("À propos"), "win.about");

        menu.append_submenu(_("Fichier"), file_menu);
        menu.append_submenu(_("Affichage"), view_menu);
        menu.append_submenu(_("Outils"), tools_menu);
        menu.append_submenu(_("Aide"), help_menu);

        return menu;
    }

    // === Signaux et gestion d'état ===
    private void connect_signals() {
        explorer_button.toggled.connect((button) => {
            explorer_visible = button.get_active();
            controller.toggle_explorer_visibility(button.get_active());
            // Sauvegarder l'état de l'explorateur
            var config = controller.get_config_manager();
            config.set_boolean("Window", "explorer_visible", button.get_active());
            config.save();
            // Mettre à jour le layout adaptatif
            update_adaptive_layout();
        });

        this.close_request.connect(on_close_request);

        editor_comm_paned.notify["position"].connect(() => {
            int width, height;
            this.get_default_size(out width, out height);
            int min_comm_height = 150;
            int max_editor_height = height - min_comm_height;
            if (editor_comm_paned.get_position() > max_editor_height) {
                editor_comm_paned.set_position(max_editor_height);
            }
            // Sauvegarder automatiquement la position
            save_paned_positions();
        });

        main_paned.notify["position"].connect(() => {
            int width, height;
            this.get_default_size(out width, out height);
            int min_comm_height = 150;
            int max_top_height = height - min_comm_height;
            if (main_paned.get_position() > max_top_height) {
                main_paned.set_position(max_top_height);
            }
            // Sauvegarder automatiquement la position
            save_paned_positions();
        });
    }

    public void set_integrated_explorer_visible(bool show) {
        if (use_detached_explorer || explorer_view == null) return;
        explorer_visible = show;
        explorer_view.set_visible(show);
        // Mettre à jour le layout adaptatif
        update_adaptive_layout();
    }

    public void update_explorer_button_state(bool active) {
        if (explorer_button != null) {
            explorer_button.set_active(active);
        }
    }

    // === Gestion des onglets ===
    public void open_document_in_tab(Sambo.Document.PivotDocument doc, string file_path) {
        int current_page = editor_notebook.get_current_page();
        bool is_empty_first_tab = false;
        if (current_page >= 0 && current_page < editor_tabs.size) {
            var current_editor = editor_tabs[current_page];
            is_empty_first_tab = (current_editor.current_document == null);
        }

        EditorView editor;
        if (is_empty_first_tab) {
            editor = editor_tabs[current_page];
            editor.load_document(doc);
            var tab_box = create_tab_box(Path.get_basename(file_path), editor);
            editor_notebook.set_tab_label(editor_notebook.get_nth_page(current_page), tab_box);
            editor_notebook.set_tab_reorderable(editor, true);
        } else {
            editor = new EditorView(controller);
            editor.load_document(doc);
            var tab_box = create_tab_box(Path.get_basename(file_path), editor);
            editor_tabs.add(editor);
            int page_num = editor_notebook.append_page(editor, tab_box);
            editor_notebook.set_current_page(page_num);
            editor_notebook.set_tab_reorderable(editor, true);
        }

        // Définir la provenance et le chemin du fichier pour la barre d'état
        editor.set_document_source((EditorView.DocumentSource)DocumentSource.EXPLORER);
        editor.set_current_file_path(file_path);

        var page_num = editor_notebook.page_num(editor);
        var tab_label = editor_notebook.get_tab_label(editor);
        update_tab_appearance(editor, tab_label);
    }

    private Box create_tab_box(string title, EditorView editor) {
        var tab_box = new Box(Orientation.HORIZONTAL, 6);
        var label = new Label(title);
        label.add_css_class("tab-label-black");
        var close_button = new Button.from_icon_name("window-close-symbolic");
        close_button.add_css_class("flat");
        close_button.add_css_class("circular");
        close_button.set_tooltip_text(_("Fermer"));
        close_button.set_valign(Align.CENTER);
        tab_box.append(label);
        tab_box.append(close_button);
        tab_box.show();

        close_button.clicked.connect(() => {
            close_tab(editor);
        });

        // Connexion du signal de changement d'état de sauvegarde
        // Connect to document changes using a public method/property instead
        if (editor != null && editor is GLib.Object) {
            try {
                editor.notify["has-unsaved-changes"].connect(() => {
                    update_tab_appearance(editor, tab_box);
                });
            } catch (Error e) {
                warning("MainWindow: Erreur lors de la connexion du signal: %s", e.message);
            }
        } else {
            warning("MainWindow: Editor est NULL ou n'est pas un GObject lors de la connexion du signal");
        }

        return tab_box;
    }

    private void update_tab_appearance(EditorView editor, Gtk.Widget tab_label) {
        if (tab_label is Box) {
            var box = (Box)tab_label;
            var label = box.get_first_child();
            while (label != null && !(label is Label)) {
                label = label.get_next_sibling();
            }
            // Correction ici : appel de la propriété ou méthode selon la déclaration dans EditorView
            bool has_changes = false;
            #if HAS_UNSAVED_CHANGES_IS_PROPERTY
            has_changes = editor.has_unsaved_changes;
            #else
            has_changes = editor.has_unsaved_changes;
            #endif
            if (label is Label) {
                var text_label = (Label)label;
                if (editor_tabs.size == 1 && editor == editor_tabs[0] &&
                    editor.current_document == null && !has_changes) {
                    text_label.add_css_class("tab-label-black");
                    text_label.remove_css_class("tab-label-green");
                    text_label.remove_css_class("tab-label-yellow");
                } else if (!has_changes) {
                    text_label.add_css_class("tab-label-green");
                    text_label.remove_css_class("tab-label-yellow");
                    text_label.remove_css_class("tab-label-black");
                } else {
                    text_label.add_css_class("tab-label-yellow");
                    text_label.remove_css_class("tab-label-green");
                    text_label.remove_css_class("tab-label-black");
                }
            }
        }
    }

    public void close_tab(EditorView editor_to_close) {
        int editor_index = -1;
        for (int i = 0; i < editor_tabs.size; i++) {
            if (editor_tabs[i] == editor_to_close) {
                editor_index = i;
                break;
            }
        }
        if (editor_index >= 0) {
            // Correction ici : appel de la propriété ou méthode selon la déclaration dans EditorView
            bool has_changes = false;
            #if HAS_UNSAVED_CHANGES_IS_PROPERTY
            has_changes = editor_to_close.has_unsaved_changes;
            #else
            has_changes = editor_to_close.has_unsaved_changes;
            #endif
            if (has_changes) {
                var dialog = new Gtk.MessageDialog(
                    this,
                    DialogFlags.MODAL,
                    MessageType.QUESTION,
                    ButtonsType.NONE,
                    _("Ce document contient des modifications non sauvegardées. Souhaitez-vous l'enregistrer avant de fermer?")
                );
                dialog.add_button(_("Abandonner les modifications"), 0);
                dialog.add_button(_("Annuler"), 1);
                dialog.add_button(_("Enregistrer"), 2);
                var captured_editor = editor_to_close;
                var captured_index = editor_index;
                dialog.response.connect((id) => {
                    dialog.destroy();
                    if (id == 0) {
                        remove_tab(captured_index);
                    } else if (id == 2) {
                        if (captured_editor.save_document()) {
                            remove_tab(captured_index);
                        }
                    }
                });
                dialog.show();
            } else {
                remove_tab(editor_index);
            }
        }
    }

    private void remove_tab(int index) {
        if (index >= 0 && index < editor_tabs.size) {
            var editor = editor_tabs[index];
            editor_tabs.remove_at(index);
            editor_notebook.remove_page(index);
            if (editor_tabs.size == 0) {
                var new_editor = new EditorView(controller);
                editor_tabs.add(new_editor);
                editor_notebook.append_page(new_editor, new Label(_("Nouveau document")));
            }
        }
    }

    // === Fermeture et sauvegarde ===
    private bool should_confirm_quit() {
        foreach (var editor in editor_tabs) {
            // Correction ici : appel de la propriété ou méthode selon la déclaration dans EditorView
            bool has_changes = false;
            #if HAS_UNSAVED_CHANGES_IS_PROPERTY
            has_changes = editor.has_unsaved_changes;
            #else
            has_changes = editor.has_unsaved_changes;
            #endif
            if (has_changes) {
                var dialog = new Adw.MessageDialog(this,
                    _("Modifications non sauvegardées"),
                    _("Certains documents ont des modifications non sauvegardées. Voulez-vous vraiment quitter?")
                );
                dialog.add_response("cancel", _("Annuler"));
                dialog.add_response("save_quit", _("Sauvegarder et quitter"));
                dialog.add_response("quit", _("Quitter sans sauvegarder"));
                dialog.set_response_appearance("quit", Adw.ResponseAppearance.DESTRUCTIVE);
                dialog.set_response_appearance("save_quit", Adw.ResponseAppearance.SUGGESTED);
                dialog.set_default_response("cancel");
                dialog.response.connect((response) => {
                    if (response == "save_quit") {
                        save_all_documents();
                        this.application.quit();
                    } else if (response == "quit") {
                        this.application.quit();
                    }
                });
                dialog.present();
                return true;
            }
        }
        return false;
    }

    private void save_all_documents() {
        foreach (var editor in editor_tabs) {
            // Correction ici : appel de la propriété ou méthode selon la déclaration dans EditorView
            bool has_changes = false;
            #if HAS_UNSAVED_CHANGES_IS_PROPERTY
            has_changes = editor.has_unsaved_changes;
            #else
            has_changes = editor.has_unsaved_changes;
            #endif
            if (has_changes) {
                editor.save_document();
            }
        }
    }

    private bool on_close_request() {
        save_window_state();
        if (should_confirm_quit()) {
            return true;
        }
        application.quit();
        return true;
    }

    private void restore_paned_positions() {
        var config = controller.get_config_manager();

        if (!use_detached_explorer) {
            int top_position = config.get_integer("Window", "top_paned_position", 280);
            int main_position = config.get_integer("Window", "main_paned_position", 500);

            if (top_paned != null && top_paned.get_visible()) {
                // Attendre que le layout soit stable avant de restaurer
                GLib.Timeout.add(50, () => {
                    if (top_paned.get_visible()) {
                        top_paned.set_position(top_position);
                        stderr.printf("🔧 RESTORE: top_paned position restaurée: %d\n", top_position);
                    }
                    return false;
                });
            }

            if (main_paned != null) {
                // Restaurer la position du main_paned avec plusieurs tentatives
                GLib.Timeout.add(100, () => {
                    // Vérifier que les deux zones sont visibles
                    bool editor_ready = editor_visible && editor_notebook != null && editor_notebook.get_visible();
                    bool comm_ready = communication_visible && communication_view != null && communication_view.get_visible();

                    if (editor_ready && comm_ready) {
                        main_paned.set_position(main_position);
                        stderr.printf("🔧 RESTORE: main_paned position restaurée: %d (editor:%s, comm:%s)\n",
                            main_position, editor_ready ? "OK" : "NON", comm_ready ? "OK" : "NON");
                    } else {
                        stderr.printf("🔧 RESTORE: Attente des widgets (editor:%s, comm:%s)\n",
                            editor_ready ? "OK" : "NON", comm_ready ? "OK" : "NON");
                    }
                    return false;
                });
            }
        } else {
            int main_position = config.get_integer("Window", "main_paned_position", 500);
            if (main_paned != null) {
                GLib.Timeout.add(100, () => {
                    main_paned.set_position(main_position);
                    stderr.printf("🔧 RESTORE: main_paned position restaurée (mode détaché): %d\n", main_position);
                    return false;
                });
            }
        }
    }

    private void save_paned_positions() {
        // Ne pas sauvegarder pendant l'initialisation
        if (initializing) {
            stderr.printf("⏸️  SAVE: Sauvegarde ignorée (initialisation en cours)\n");
            return;
        }

        var config = controller.get_config_manager();

        // Sauvegarder position du top_paned (entre explorateur et éditeur)
        if (top_paned != null && top_paned.get_visible()) {
            int top_position = top_paned.get_position();
            if (top_position > 50 && top_position < 800) { // Position raisonnable
                config.set_integer("Window", "top_paned_position", top_position);
                stderr.printf("💾 SAVE: top_paned position sauvée: %d\n", top_position);
            }
        }

        // Sauvegarder position du main_paned (entre éditeur et chat)
        if (main_paned != null) {
            int main_position = main_paned.get_position();
            if (main_position > 100 && main_position < 1000) { // Position raisonnable
                config.set_integer("Window", "main_paned_position", main_position);
                stderr.printf("💾 SAVE: main_paned position sauvée: %d\n", main_position);
            }
        }

        config.save();
    }

    private void save_window_state() {
        int width, height;
        this.get_default_size(out width, out height);
        var config = controller.get_config_manager();
        config.set_integer("Window", "width", width);
        config.set_integer("Window", "height", height);

        // Sauvegarder les positions des paneds
        save_paned_positions();
    }

    private void apply_saved_configuration() {
        if (configuration_applied) {
            stderr.printf("⚠️  INIT: Configuration déjà appliquée, ignorer\n");
            return;
        }

        stderr.printf("🎯 INIT: Application de la configuration sauvegardée\n");

        var config = controller.get_config_manager();
        int width = config.get_integer("Window", "width", 800);
        int height = config.get_integer("Window", "height", 600);
        width = int.max(width, 600);
        height = int.max(height, 450);
        this.set_default_size(width, height);

        // Restaurer les états des zones
        bool show_explorer = config.get_boolean("Window", "explorer_visible", true);
        bool show_editor = config.get_boolean("Window", "editor_visible", true);
        bool show_communication = config.get_boolean("Window", "communication_visible", true);

        // Mettre à jour les variables d'état
        explorer_visible = show_explorer;
        editor_visible = show_editor;
        communication_visible = show_communication;

        // Debug
        stderr.printf("🔧 CONFIG: explorer=%s, editor=%s, communication=%s\n",
            show_explorer ? "VISIBLE" : "MASQUÉ",
            show_editor ? "VISIBLE" : "MASQUÉ",
            show_communication ? "VISIBLE" : "MASQUÉ");

        // Mettre à jour l'état des boutons SANS déclencher les signaux
        explorer_button.set_active(show_explorer);
        editor_button.set_active(show_editor);
        communication_button.set_active(show_communication);

        // Appliquer la visibilité initiale des widgets
        if (explorer_view != null) {
            explorer_view.set_visible(show_explorer);
        }
        if (editor_notebook != null) {
            editor_notebook.set_visible(show_editor);
        }
        if (communication_view != null) {
            communication_view.set_visible(show_communication);
        }

        // Configurer l'explorateur avec le controller
        controller.toggle_explorer_visibility(show_explorer);

        // Appliquer le layout adaptatif UNE SEULE FOIS
        update_adaptive_layout();

        // Restaurer les positions des panneaux après le layout (différé)
        Idle.add(() => {
            restore_paned_positions();
            return false; // Ne pas répéter
        });

        // Restauration supplémentaire avec plus de délai pour s'assurer que tout est prêt
        GLib.Timeout.add(500, () => {
            restore_paned_positions();
            // Marquer la fin de l'initialisation après la dernière restauration
            GLib.Timeout.add(100, () => {
                initializing = false;
                stderr.printf("🏁 INIT: Initialisation terminée - sauvegarde automatique activée\n");
                return false;
            });
            return false;
        });

        // Debug des tailles après layout
        GLib.Timeout.add(100, () => {
            debug_widget_sizes();
            return false;
        });

        // MAINTENANT connecter les signaux des boutons
        connect_toggle_signals();

        // Marquer la configuration comme appliquée
        configuration_applied = true;
        stderr.printf("✅ INIT: Configuration appliquée avec succès\n");
    }

    private void debug_widget_sizes() {
        stderr.printf("🔍 DEBUG TAILLES:\n");

        if (main_paned != null) {
            var alloc = Gtk.Allocation();
            main_paned.get_allocation(out alloc);
            stderr.printf("  main_paned: %dx%d à (%d,%d), position=%d\n",
                alloc.width, alloc.height, alloc.x, alloc.y, main_paned.get_position());
        }

        if (top_paned != null) {
            var alloc = Gtk.Allocation();
            top_paned.get_allocation(out alloc);
            stderr.printf("  top_paned: %dx%d à (%d,%d), position=%d\n",
                alloc.width, alloc.height, alloc.x, alloc.y, top_paned.get_position());
        }

        if (explorer_view != null) {
            var alloc = Gtk.Allocation();
            explorer_view.get_allocation(out alloc);
            stderr.printf("  explorer: %dx%d à (%d,%d), visible=%s, parent=%s\n",
                alloc.width, alloc.height, alloc.x, alloc.y,
                explorer_view.get_visible() ? "OUI" : "NON",
                explorer_view.get_parent() != null ? "OUI" : "NON");
        }

        if (editor_notebook != null) {
            var alloc = Gtk.Allocation();
            editor_notebook.get_allocation(out alloc);
            stderr.printf("  editor: %dx%d à (%d,%d), visible=%s, parent=%s\n",
                alloc.width, alloc.height, alloc.x, alloc.y,
                editor_notebook.get_visible() ? "OUI" : "NON",
                editor_notebook.get_parent() != null ? "OUI" : "NON");
        }

        if (communication_view != null) {
            var alloc = Gtk.Allocation();
            communication_view.get_allocation(out alloc);
            stderr.printf("  communication: %dx%d à (%d,%d), visible=%s, parent=%s\n",
                alloc.width, alloc.height, alloc.x, alloc.y,
                communication_view.get_visible() ? "OUI" : "NON",
                communication_view.get_parent() != null ? "OUI" : "NON");
        }
    }

    private void connect_toggle_signals() {
        stderr.printf("🔗 INIT: Connexion des signaux utilisateur\n");

        explorer_button.toggled.connect((button) => {
            if (configuration_applied) { // Ignorer les signaux pendant l'initialisation
                controller.toggle_explorer_visibility(button.get_active());
            }
        });

        editor_button.toggled.connect((button) => {
            if (configuration_applied) { // Ignorer les signaux pendant l'initialisation
                toggle_editor_visibility(button.get_active());
            }
        });

        communication_button.toggled.connect((button) => {
            if (configuration_applied) { // Ignorer les signaux pendant l'initialisation
                toggle_communication_visibility(button.get_active());
            }
        });
    }

    private void restore_window_state() {
        var config = controller.get_config_manager();
        int width = config.get_integer("Window", "width", 800);
        int height = config.get_integer("Window", "height", 600);
        width = int.max(width, 600);
        height = int.max(height, 450);
        this.set_default_size(width, height);

        // Restaurer les états des zones SANS déclencher les signaux
        bool show_explorer = config.get_boolean("Window", "explorer_visible", true);
        bool show_editor = config.get_boolean("Window", "editor_visible", true);
        bool show_communication = config.get_boolean("Window", "communication_visible", true);

        // Mettre à jour les variables d'état
        explorer_visible = show_explorer;
        editor_visible = show_editor;
        communication_visible = show_communication;

        // Debug
        stderr.printf("🔧 RESTORE: explorer=%s, editor=%s, communication=%s\n",
            show_explorer ? "VISIBLE" : "MASQUÉ",
            show_editor ? "VISIBLE" : "MASQUÉ",
            show_communication ? "VISIBLE" : "MASQUÉ");

        // Mettre à jour l'état des boutons SANS déclencher les signaux
        explorer_button.set_active(show_explorer);
        editor_button.set_active(show_editor);
        communication_button.set_active(show_communication);

        // Appliquer la visibilité initiale des widgets
        if (explorer_view != null) {
            explorer_view.set_visible(show_explorer);
        }
        if (editor_notebook != null) {
            editor_notebook.set_visible(show_editor);
        }
        if (communication_view != null) {
            communication_view.set_visible(show_communication);
        }

        // Configurer l'explorateur avec le controller
        Timeout.add(50, () => {
            controller.toggle_explorer_visibility(show_explorer);
            return false;
        });

        // Restaurer les positions des panneaux
        if (!use_detached_explorer) {
            int main_position = config.get_integer("Window", "main_paned_position", 280);
            int editor_comm_position = config.get_integer("Window", "editor_comm_paned_position", 500);
            Timeout.add(100, () => {
                if (main_paned != null) main_paned.set_position(editor_comm_position);
                if (top_paned != null) top_paned.set_position(main_position);
                // Appliquer le layout adaptatif après la restauration complète
                update_adaptive_layout();
                return false;
            });
        } else {
            int editor_comm_position = config.get_integer("Window", "editor_comm_paned_position", 500);
            Timeout.add(100, () => {
                if (main_paned != null) main_paned.set_position(editor_comm_position);
                // Appliquer le layout adaptatif après la restauration complète
                update_adaptive_layout();
                return false;
            });
        }
    }

    // === Utilitaires ===
    public Adw.HeaderBar? get_header_bar() { return header_bar; }
    public ExplorerView? get_explorer_view() { return explorer_view; }

    private void save_current_document() {
        int current_page = editor_notebook.get_current_page();
        if (current_page >= 0 && current_page < editor_tabs.size) {
            var editor = editor_tabs[current_page];
            editor.save_document();
        }
    }

    private void save_current_document_as() {
        int current_page = editor_notebook.get_current_page();
        if (current_page >= 0 && current_page < editor_tabs.size) {
            var editor = editor_tabs[current_page];
            editor.save_document_as();
        }
    }

    public void apply_editor_style_to_all_tabs(int size, string family, string color) {
        foreach (var editor in editor_tabs) {
            editor.set_editor_style(size, family, color);
        }
    }

    public void add_toast(Adw.Toast toast) {
        unowned Adw.ToastOverlay? overlay = find_descendant_of_type<Adw.ToastOverlay>();
        if (overlay != null) {
            overlay.add_toast(toast);
        }
    }

    public unowned T? find_descendant_of_type<T>() {
        return find_widget_recursive<T>(this);
    }

    private unowned T? find_widget_recursive<T>(Gtk.Widget widget) {
        if (widget is T) return (T)widget;
        var child = widget.get_first_child();
        while (child != null) {
            unowned T? result = find_widget_recursive<T>(child);
            if (result != null) return result;
            child = child.get_next_sibling();
        }
        return null;
    }

    /**
     * Rafraîchit la sélection de profil après l'initialisation complète
     */
    public void refresh_profile_selection() {
        // Demander au CommunicationView de recharger le profil
        if (communication_view != null) {
            communication_view.refresh_profile_selection();
        }
    }
}

}
