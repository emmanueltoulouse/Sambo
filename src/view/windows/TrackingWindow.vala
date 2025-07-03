using Gtk;
using Adw;

namespace Sambo {

public class TrackingWindow : Adw.Window {
    private ApplicationController controller;
    private Adw.ToastOverlay toast_overlay;

    public TrackingWindow(ApplicationController controller) {
        Object(
            title: "Suivi Sambo - Tableau de Bord",
            default_width: 1000,
            default_height: 700,
            resizable: true
        );
        this.controller = controller;
        setup_ui();
    }

    private void setup_ui() {
        var header_bar = new Adw.HeaderBar();
        header_bar.set_title_widget(new Adw.WindowTitle("Suivi Sambo", "Tableau de bord des fonctionnalités et tâches"));

        var refresh_btn = new Button();
        refresh_btn.set_icon_name("view-refresh-symbolic");
        refresh_btn.set_tooltip_text("Actualiser le tableau de suivi");
        refresh_btn.clicked.connect(() => {
            refresh_content();
            show_toast("Tableau de suivi actualisé");
        });
        header_bar.pack_end(refresh_btn);

        var main_box = new Box(Orientation.VERTICAL, 0);
        main_box.append(header_bar);

        // ScrolledWindow pour le contenu principal
        var scrolled = new ScrolledWindow();
        scrolled.set_policy(PolicyType.NEVER, PolicyType.AUTOMATIC);
        scrolled.set_vexpand(true);

        var content_box = new Box(Orientation.VERTICAL, 24);
        content_box.set_margin_start(24);
        content_box.set_margin_end(24);
        content_box.set_margin_top(24);
        content_box.set_margin_bottom(24);

        // En-tête avec icône et titre principal
        var header_container = new Box(Orientation.VERTICAL, 16);
        header_container.set_halign(Align.CENTER);

        // Conteneur horizontal pour l'icône et le titre
        var icon_title_box = new Box(Orientation.HORIZONTAL, 16);
        icon_title_box.set_halign(Align.CENTER);

        // Icône de l'application
        var app_icon = new Image.from_icon_name("com.cabineteto.Sambo");
        app_icon.set_pixel_size(64);
        app_icon.set_valign(Align.CENTER);

        // Titre principal
        var title_box = new Box(Orientation.VERTICAL, 8);
        var main_title = new Label("<span size='x-large' weight='bold'>🎯 Tableau de Suivi Sambo</span>");
        main_title.set_use_markup(true);
        main_title.set_halign(Align.START);

        var subtitle = new Label("<span color='#888888'>Développement et progression des fonctionnalités</span>");
        subtitle.set_use_markup(true);
        subtitle.set_halign(Align.START);

        title_box.append(main_title);
        title_box.append(subtitle);

        // Assemblage
        icon_title_box.append(app_icon);
        icon_title_box.append(title_box);
        header_container.append(icon_title_box);
        content_box.append(header_container);

        // Section Fonctionnalités
        content_box.append(create_features_section());

        // Section Tâches
        content_box.append(create_tasks_section());

        scrolled.set_child(content_box);
        main_box.append(scrolled);

        toast_overlay = new Adw.ToastOverlay();
        toast_overlay.set_child(main_box);
        set_content(toast_overlay);

        // Appliquer le style CSS
        apply_custom_styles();
    }

    private Widget create_features_section() {
        var section = new Adw.PreferencesGroup();
        section.set_title("🚀 Fonctionnalités de Sambo");
        section.set_description("Vue d'ensemble des capacités actuelles et futures");

        var features_text = create_features_content();
        var text_view = new TextView();
        text_view.set_buffer(features_text);
        text_view.set_editable(false);
        text_view.set_cursor_visible(false);
        text_view.set_wrap_mode(WrapMode.WORD);
        text_view.add_css_class("tracking-textview");

        var scrolled_features = new ScrolledWindow();
        scrolled_features.set_policy(PolicyType.NEVER, PolicyType.AUTOMATIC);
        scrolled_features.set_min_content_height(300);
        scrolled_features.set_child(text_view);
        scrolled_features.add_css_class("tracking-scroll");

        section.add(scrolled_features);
        return section;
    }

    private Widget create_tasks_section() {
        var section = new Adw.PreferencesGroup();
        section.set_title("📋 Feuille de Route");
        section.set_description("Tâches organisées par priorité avec suivi de progression");

        var tasks_text = create_tasks_content();
        var text_view = new TextView();
        text_view.set_buffer(tasks_text);
        text_view.set_editable(false);
        text_view.set_cursor_visible(false);
        text_view.set_wrap_mode(WrapMode.WORD);
        text_view.add_css_class("tracking-textview");

        var scrolled_tasks = new ScrolledWindow();
        scrolled_tasks.set_policy(PolicyType.NEVER, PolicyType.AUTOMATIC);
        scrolled_tasks.set_min_content_height(400);
        scrolled_tasks.set_child(text_view);
        scrolled_tasks.add_css_class("tracking-scroll");

        section.add(scrolled_tasks);
        return section;
    }

    private TextBuffer create_features_content() {
        var buffer = new TextBuffer(null);

        // Créer les tags pour le formatage
        var title_tag = buffer.create_tag("title");
        title_tag.weight = Pango.Weight.BOLD;
        title_tag.scale = 1.2;
        title_tag.foreground = "#2563eb";

        var completed_tag = buffer.create_tag("completed");
        completed_tag.background = "#fef08a"; // Jaune surligneur
        completed_tag.weight = Pango.Weight.BOLD;

        var category_tag = buffer.create_tag("category");
        category_tag.weight = Pango.Weight.BOLD;
        category_tag.foreground = "#059669";
        category_tag.scale = 1.1;

        var feature_tag = buffer.create_tag("feature");
        feature_tag.left_margin = 20;

        TextIter iter;
        buffer.get_end_iter(out iter);

        // Contenu des fonctionnalités
        var content = """📝 ÉDITEUR DE TEXTE AVANCÉ
══════════════════════════════

🎯 Fonctionnalités Actuelles :
• Éditeur multi-onglets avec syntax highlighting
• Support Markdown avec aperçu en temps réel
• Système de sauvegarde automatique
• Interface utilisateur moderne avec Adwaita

🔮 Fonctionnalités Prévues :

📁 GESTION DE FICHIERS
• Explorateur de fichiers intégré avec arborescence
• Recherche avancée dans les fichiers
• Système de signets et favoris
• Historique de navigation
• Prévisualisation des fichiers multimédias

🤖 INTELLIGENCE ARTIFICIELLE
• Assistant IA intégré pour l'écriture
• Génération automatique de contenu
• Correction grammaticale et stylistique
• Traduction multilingue
• Résumé automatique de documents

💬 COLLABORATION
• Chat intégré pour la communication
• Partage de documents en temps réel
• Commentaires et annotations
• Système de révisions et versions

🎨 PERSONNALISATION
• Thèmes visuels personnalisables
• Raccourcis clavier configurables
• Extensions et plugins
• Espaces de travail modulaires

🔧 OUTILS DÉVELOPPEUR
• Terminal intégré
• Debugger visuel
• Support Git avancé
• Outils de comparaison de fichiers

📊 PRODUCTIVITÉ
• Gestionnaire de tâches intégré
• Calendrier et planification
• Système de notes rapides
• Export multi-formats (PDF, HTML, DOCX)

🔒 SÉCURITÉ
• Chiffrement des documents
• Authentification multi-facteurs
• Sauvegarde cloud sécurisée
• Protection par mot de passe""";

        buffer.insert(ref iter, content, -1);

        // Appliquer le surlignage aux éléments terminés
        apply_highlighting_to_buffer(buffer, completed_tag);

        return buffer;
    }

    private TextBuffer create_tasks_content() {
        var buffer = new TextBuffer(null);

        // Tags pour les priorités
        var urgent_tag = buffer.create_tag("urgent");
        urgent_tag.background = "#fecaca"; // Rouge clair
        urgent_tag.weight = Pango.Weight.BOLD;

        var important_tag = buffer.create_tag("important");
        important_tag.background = "#fef08a"; // Jaune clair
        important_tag.weight = Pango.Weight.BOLD;

        var completed_tag = buffer.create_tag("completed");
        completed_tag.background = "#bbf7d0"; // Vert clair
        urgent_tag.strikethrough = true;

        var highlight_tag = buffer.create_tag("highlight");
        highlight_tag.background = "#fef08a"; // Surlignage jaune

        var priority_header_tag = buffer.create_tag("priority_header");
        priority_header_tag.weight = Pango.Weight.BOLD;
        priority_header_tag.scale = 1.15;

        TextIter iter;
        buffer.get_end_iter(out iter);

        var content = """🔴 PRIORITÉ URGENTE (Rouge)
═══════════════════════════

• Finaliser le système de menus hamburger
• Intégrer la fenêtre de suivi dans le menu Outils
• Corriger les bugs de sauvegarde des fichiers
• Optimiser les performances de l'éditeur
• Résoudre les problèmes d'affichage des icônes

🟡 PRIORITÉ IMPORTANTE (Jaune)
══════════════════════════════

• Développer l'assistant IA intégré
• Améliorer le système de syntax highlighting
• Créer le gestionnaire d'extensions
• Implémenter la recherche globale
• Ajouter le support des thèmes personnalisés
• Développer le terminal intégré
• Créer le système de collaboration
• Implémenter la prévisualisation des fichiers

🟢 TERMINÉ / NON BLOQUANT (Vert)
═══════════════════════════════

• ✅ Structure de base de l'application
• ✅ Interface utilisateur principale
• ✅ Système d'onglets pour l'éditeur
• ✅ Menu hamburger de base
• ✅ Intégration des préférences
• ✅ Système de communication basic
• ✅ Architecture MVC
• ✅ Configuration Meson de base

📝 SOLUTIONS DE CONTOURNEMENT
═══════════════════════════════

Pour les tâches partiellement terminées :

🔧 Menu Hamburger :
   Solution temporaire → Utiliser les actions GTK existantes

🔧 Système d'Icônes :
   Solution temporaire → Icônes par défaut du système

🔧 Sauvegarde :
   Solution temporaire → Sauvegarde manuelle uniquement

🔧 Préférences :
   Solution temporaire → Configuration basique

📊 MÉTRIQUES DE PROGRESSION
═══════════════════════════

🎯 Fonctionnalités de base : 70% ████████████████▒▒▒▒▒
🤖 Intelligence Artificielle : 15% ███▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒
💬 Collaboration : 20% ████▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒
🎨 Personnalisation : 25% █████▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒
🔧 Outils Développeur : 30% ██████▒▒▒▒▒▒▒▒▒▒▒▒▒▒
📊 Productivité : 10% ██▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒

🎖️ PROGRESSION GLOBALE : 35% ███████▒▒▒▒▒▒▒▒▒▒▒▒▒""";

        buffer.insert(ref iter, content, -1);

        // Appliquer le surlignage aux éléments terminés
        apply_task_highlighting(buffer);

        return buffer;
    }

    private void apply_highlighting_to_buffer(TextBuffer buffer, TextTag completed_tag) {
        // Surligner les fonctionnalités déjà implémentées
        string[] completed_features = {
            "• Éditeur multi-onglets avec syntax highlighting",
            "• Support Markdown avec aperçu en temps réel",
            "• Système de sauvegarde automatique",
            "• Interface utilisateur moderne avec Adwaita"
        };

        foreach (string feature in completed_features) {
            highlight_text_in_buffer(buffer, feature, completed_tag);
        }
    }

    private void apply_task_highlighting(TextBuffer buffer) {
        var completed_tag = buffer.get_tag_table().lookup("completed");

        // Tâches terminées à surligner
        string[] completed_tasks = {
            "• ✅ Structure de base de l'application",
            "• ✅ Interface utilisateur principale",
            "• ✅ Système d'onglets pour l'éditeur",
            "• ✅ Menu hamburger de base",
            "• ✅ Intégration des préférences",
            "• ✅ Système de communication basic",
            "• ✅ Architecture MVC",
            "• ✅ Configuration Meson de base"
        };

        foreach (string task in completed_tasks) {
            highlight_text_in_buffer(buffer, task, completed_tag);
        }
    }

    private void highlight_text_in_buffer(TextBuffer buffer, string text, TextTag tag) {
        TextIter start_iter, end_iter, match_start, match_end;
        buffer.get_start_iter(out start_iter);
        buffer.get_end_iter(out end_iter);

        if (start_iter.forward_search(text, TextSearchFlags.TEXT_ONLY, out match_start, out match_end, null)) {
            buffer.apply_tag(tag, match_start, match_end);
        }
    }

    private void apply_custom_styles() {
        // Récupérer les préférences de police de l'application
        var config = controller.get_config_manager();
        string font_family = config.get_string("Editor", "font_family", "Sans");
        int font_size = config.get_integer("Editor", "font_size", 12);

        var css_provider = new CssProvider();
        var css_data = """
        .tracking-textview {
            background: linear-gradient(135deg, #f8fafc 0%, #f1f5f9 100%);
            border-radius: 12px;
            padding: 16px;
            font-family: '%s';
            font-size: %dpx;
            line-height: 1.6;
            border: 1px solid #e2e8f0;
            box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1);
        }

        .tracking-scroll {
            border-radius: 12px;
            border: 1px solid #e2e8f0;
            background: white;
            box-shadow: inset 0 2px 4px rgba(0, 0, 0, 0.05);
        }

        .tracking-textview text {
            background: transparent;
        }

        /* Style pour les bulles modernes */
        .tracking-section {
            background: linear-gradient(135deg, #ffffff 0%, #f8fafc 100%);
            border-radius: 16px;
            border: 1px solid #e2e8f0;
            box-shadow: 0 10px 15px -3px rgba(0, 0, 0, 0.1), 0 4px 6px -2px rgba(0, 0, 0, 0.05);
            margin: 8px 0;
        }

        /* Effet hover pour les sections */
        .tracking-section:hover {
            box-shadow: 0 20px 25px -5px rgba(0, 0, 0, 0.1), 0 10px 10px -5px rgba(0, 0, 0, 0.04);
            transform: translateY(-2px);
            transition: all 0.3s ease;
        }
        """.printf(font_family, font_size);

        try {
            css_provider.load_from_data(css_data.data);
            Gtk.StyleContext.add_provider_for_display(
                Gdk.Display.get_default(),
                css_provider,
                Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
            );
        } catch (Error e) {
            warning("Erreur lors du chargement du CSS : %s", e.message);
        }
    }

    private void refresh_content() {
        // Logique pour actualiser le contenu du tableau de suivi
        // Cela pourrait inclure la lecture de fichiers de configuration,
        // la vérification de l'état des tâches, etc.
    }

    private void show_toast(string message) {
        var toast = new Adw.Toast(message);
        toast.set_timeout(3);
        toast_overlay.add_toast(toast);
    }
}

}
