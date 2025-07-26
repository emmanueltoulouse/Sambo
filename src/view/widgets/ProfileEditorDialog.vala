using Gtk;
using Adw;
using Gee;

namespace Sambo {
    /**
     * Dialogue d'édition des profils d'inférence avec design moderne
     */
    public class ProfileEditorDialog : Adw.Window {
        private ApplicationController controller;
        private ConfigManager config_manager;
        private InferenceProfile? original_profile;
        private InferenceProfile editing_profile;
        private bool is_editing;

        // Interface moderne
        private Adw.HeaderBar header_bar;
        private Adw.PreferencesPage preferences_page;
        private Adw.ToastOverlay toast_overlay;
        private Button save_button;
        private Button cancel_button;

        // Widgets d'édition modernes
        private Adw.EntryRow title_entry;
        private Adw.EntryRow comment_entry;
        private TextView prompt_textview;
        private TextView template_textview;
        private DropDown model_dropdown;
        private StringList model_list;
        private HashMap<string, string> model_paths;

        // Paramètres de sampling avec design moderne
        private Adw.SpinRow temperature_row;
        private Adw.SpinRow top_p_row;
        private Adw.SpinRow top_k_row;
        private Adw.SpinRow max_tokens_row;
        private Adw.SpinRow repetition_penalty_row;
        private Adw.SpinRow frequency_penalty_row;
        private Adw.SpinRow presence_penalty_row;
        private Adw.SpinRow seed_row;
        private Adw.SpinRow context_length_row;
        private Adw.SwitchRow stream_row;

        public signal void profile_saved(InferenceProfile profile);

        public ProfileEditorDialog(Gtk.Window parent, ApplicationController controller, InferenceProfile? profile = null) {
            Object(
                title: profile == null ? "Nouveau profil" : "Éditer le profil",
                default_width: 700,
                default_height: 800,
                modal: true,
                transient_for: parent
            );

            this.controller = controller;
            this.config_manager = controller.get_config_manager();
            this.original_profile = profile;
            this.is_editing = profile != null;
            this.model_paths = new HashMap<string, string>();

            // Créer le profil d'édition
            if (is_editing) {
                editing_profile = new InferenceProfile();
                editing_profile.id = original_profile.id;
                editing_profile.copy_from(original_profile);
            } else {
                editing_profile = InferenceProfile.create_default(
                    InferenceProfile.generate_unique_id(),
                    "Nouveau profil"
                );
            }

            setup_modern_ui();
            populate_fields();
        }

        private void setup_modern_ui() {
            // Toast overlay principal
            toast_overlay = new Adw.ToastOverlay();
            set_content(toast_overlay);
            add_css_class("profile-editor-dialog");

            var main_box = new Box(Orientation.VERTICAL, 0);
            toast_overlay.set_child(main_box);

            // Header bar moderne avec actions
            setup_header_bar();
            main_box.append(header_bar);

            // Page de préférences avec scroll
            var scrolled = new ScrolledWindow();
            scrolled.set_policy(PolicyType.NEVER, PolicyType.AUTOMATIC);
            scrolled.set_vexpand(true);
            scrolled.add_css_class("profile-editor-scroll");

            preferences_page = new Adw.PreferencesPage();
            preferences_page.set_title("Configuration du profil");
            preferences_page.set_icon_name("user-info-symbolic");
            preferences_page.add_css_class("profile-editor-page");

            scrolled.set_child(preferences_page);
            main_box.append(scrolled);

            // Créer les sections avec design moderne
            create_general_section();
            create_model_section();
            create_prompt_section();
            create_template_section();
            create_sampling_section();
            create_advanced_section();
            create_preview_section();
        }

        private void setup_header_bar() {
            header_bar = new Adw.HeaderBar();
            header_bar.add_css_class("flat");
            header_bar.add_css_class("profile-editor-header");

            // Bouton annuler avec style moderne
            cancel_button = new Button.with_label("Annuler");
            cancel_button.add_css_class("profile-cancel-button");
            cancel_button.clicked.connect(() => this.close());
            header_bar.pack_start(cancel_button);

            // Bouton sauvegarder avec style moderne
            save_button = new Button.with_label(is_editing ? "💾 Enregistrer" : "✨ Créer");
            save_button.add_css_class("suggested-action");
            save_button.add_css_class("profile-save-button");
            save_button.clicked.connect(on_save_clicked);
            header_bar.pack_end(save_button);

            // Bouton de test rapide
            var test_button = new Button.with_label("🧪 Tester");
            test_button.add_css_class("flat");
            test_button.add_css_class("profile-test-button");
            test_button.set_tooltip_text("Tester les paramètres actuels");
            header_bar.pack_end(test_button);

            // Titre avec icône animée
            var title_box = new Box(Orientation.HORIZONTAL, 8);
            var icon = new Image.from_icon_name(is_editing ? "document-edit-symbolic" : "document-new-symbolic");
            icon.add_css_class("profile-header-icon");
            title_box.append(icon);

            var title_label = new Label(is_editing ? "Éditer le profil" : "Nouveau profil");
            title_label.add_css_class("heading");
            title_label.add_css_class("profile-header-title");
            title_box.append(title_label);

            header_bar.set_title_widget(title_box);
        }

        private void create_general_section() {
            var group = new Adw.PreferencesGroup();
            group.set_title("✨ Informations générales");
            group.set_description("Nom et description de votre profil d'inférence");
            group.add_css_class("profile-general-section");

            // Titre avec validation en temps réel et suggestions
            title_entry = new Adw.EntryRow();
            title_entry.set_title("Nom du profil");
            title_entry.set_text(editing_profile.title);
            var title_icon = new Image.from_icon_name("text-x-generic-symbolic");
            title_icon.add_css_class("accent");
            title_entry.add_prefix(title_icon);

            // Bouton de suggestion de nom
            var suggest_button = new Button.from_icon_name("view-refresh-symbolic");
            suggest_button.add_css_class("flat");
            suggest_button.set_tooltip_text("Suggérer un nom automatiquement");
            suggest_button.clicked.connect(() => {
                var suggestions = new string[] {
                    "Profil Créatif", "Assistant Personnel", "Rédacteur Pro",
                    "Analyste Expert", "Codeur IA", "Tuteur Intelligent"
                };
                var random_index = Random.int_range(0, suggestions.length);
                title_entry.set_text(suggestions[random_index]);
                validate_form();
            });
            title_entry.add_suffix(suggest_button);

            title_entry.changed.connect(() => {
                validate_form();
            });
            group.add(title_entry);

            // Commentaire optionnel avec compteur de caractères
            comment_entry = new Adw.EntryRow();
            comment_entry.set_title("Description (optionnel)");
            comment_entry.set_text(editing_profile.comment);
            var comment_icon = new Image.from_icon_name("text-x-script-symbolic");
            comment_icon.add_css_class("dim-label");
            comment_entry.add_prefix(comment_icon);

            var char_count = new Gtk.Label("0/100");
            char_count.add_css_class("caption");
            char_count.add_css_class("dim-label");
            comment_entry.add_suffix(char_count);

            comment_entry.changed.connect(() => {
                var text = comment_entry.get_text();
                char_count.set_text(text.length.to_string() + "/100");
                if (text.length > 100) {
                    char_count.add_css_class("error");
                } else {
                    char_count.remove_css_class("error");
                }
            });

            group.add(comment_entry);

            preferences_page.add(group);
        }

        private void create_model_section() {
            var group = new Adw.PreferencesGroup();
            group.set_title("🤖 Modèle d'IA");
            group.set_description("Sélectionnez le modèle à utiliser pour ce profil");
            group.add_css_class("profile-model-section");

            // Libellé au-dessus du dropdown
            var model_label_row = new Adw.ActionRow();
            model_label_row.set_title("Modèle sélectionné");
            model_label_row.set_subtitle("Choisissez parmi les modèles disponibles");
            var model_icon = new Image.from_icon_name("applications-science-symbolic");
            model_icon.add_css_class("accent");
            model_label_row.add_prefix(model_icon);
            group.add(model_label_row);

            // Dropdown moderne pour les modèles avec aperçu
            model_list = new StringList(null);
            populate_model_list();

            model_dropdown = new DropDown(model_list, null);
            model_dropdown.set_size_request(-1, -1);
            model_dropdown.add_css_class("profile-model-dropdown");

            // Container pour centrer le dropdown
            var model_container = new Box(Orientation.HORIZONTAL, 12);
            model_container.set_halign(Align.FILL);
            model_container.set_margin_start(12);
            model_container.set_margin_end(12);
            model_container.set_margin_top(6);
            model_container.set_margin_bottom(6);
            model_container.append(model_dropdown);

            var model_widget_row = new Adw.ActionRow();
            model_widget_row.set_child(model_container);
            group.add(model_widget_row);

            // Indicateur de statut du modèle avec détails
            var status_row = new Adw.ActionRow();
            status_row.set_title("Statut du modèle");
            var status_icon = new Image.from_icon_name("emblem-default-symbolic");
            status_icon.add_css_class("success");
            status_row.add_prefix(status_icon);
            status_row.set_subtitle("✅ Modèle prêt à utiliser");
            group.add(status_row);

            // Informations sur le modèle
            var info_row = new Adw.ActionRow();
            info_row.set_title("Informations");
            info_row.set_subtitle("📊 Taille, type et performances du modèle");
            var info_icon = new Image.from_icon_name("dialog-information-symbolic");
            info_icon.add_css_class("dim-label");
            info_row.add_prefix(info_icon);
            info_row.set_activatable(true);
            info_row.activated.connect(() => {
                show_toast("🔍 Informations détaillées du modèle (à venir)");
            });
            group.add(info_row);

            preferences_page.add(group);
        }

        private void create_prompt_section() {
            var group = new Adw.PreferencesGroup();
            group.set_title("💬 Prompt système");
            group.set_description("Instructions qui seront données à l'IA");

            // Libellé au-dessus de la zone de texte
            var prompt_label_row = new Adw.ActionRow();
            prompt_label_row.set_title("Contenu du prompt");
            prompt_label_row.set_subtitle("Rédigez les instructions pour l'IA");
            var prompt_icon = new Image.from_icon_name("text-x-script-symbolic");
            prompt_icon.add_css_class("accent");
            prompt_label_row.add_prefix(prompt_icon);
            group.add(prompt_label_row);

            // Zone de texte moderne pour le prompt dans une ActionRow
            var prompt_frame = new Frame(null);
            prompt_frame.add_css_class("card");
            prompt_frame.set_size_request(-1, 180);
            prompt_frame.set_margin_start(12);
            prompt_frame.set_margin_end(12);
            prompt_frame.set_margin_top(6);
            prompt_frame.set_margin_bottom(6);

            var prompt_scroll = new ScrolledWindow();
            prompt_scroll.set_policy(PolicyType.AUTOMATIC, PolicyType.AUTOMATIC);
            prompt_frame.set_child(prompt_scroll);

            prompt_textview = new TextView();
            prompt_textview.set_wrap_mode(WrapMode.WORD);
            prompt_textview.add_css_class("monospace");
            prompt_textview.get_buffer().set_text(editing_profile.prompt);

            // Validation en temps réel
            prompt_textview.get_buffer().changed.connect(() => {
                validate_form();
            });

            prompt_scroll.set_child(prompt_textview);

            var prompt_widget_row = new Adw.ActionRow();
            prompt_widget_row.set_child(prompt_frame);
            group.add(prompt_widget_row);

            // Boutons d'aide pour le prompt
            var actions_row = new Adw.ActionRow();
            actions_row.set_title("Actions rapides");

            var examples_button = new Button.with_label("Exemples");
            examples_button.add_css_class("pill");
            examples_button.clicked.connect(show_prompt_examples);
            actions_row.add_suffix(examples_button);

            var clear_button = new Button.with_label("Effacer");
            clear_button.add_css_class("pill");
            clear_button.add_css_class("destructive-action");
            clear_button.clicked.connect(() => {
                prompt_textview.get_buffer().set_text("");
            });
            actions_row.add_suffix(clear_button);

            group.add(actions_row);
            preferences_page.add(group);
        }

        private void create_template_section() {
            var group = new Adw.PreferencesGroup();
            group.set_title("🔧 Template de chat");
            group.set_description("Format de conversation pour le modèle (optionnel)");

            // Libellé au-dessus de la zone de texte
            var template_label_row = new Adw.ActionRow();
            template_label_row.set_title("Template personnalisé");
            template_label_row.set_subtitle("Utilisez {system}, {user}, {assistant} comme placeholders");
            var template_icon = new Image.from_icon_name("code-symbolic");
            template_icon.add_css_class("accent");
            template_label_row.add_prefix(template_icon);
            group.add(template_label_row);

            // Zone de texte moderne pour le template dans une ActionRow
            var template_frame = new Frame(null);
            template_frame.add_css_class("card");
            template_frame.set_size_request(-1, 120);
            template_frame.set_margin_start(12);
            template_frame.set_margin_end(12);
            template_frame.set_margin_top(6);
            template_frame.set_margin_bottom(6);

            var template_scroll = new ScrolledWindow();
            template_scroll.set_policy(PolicyType.AUTOMATIC, PolicyType.AUTOMATIC);
            template_frame.set_child(template_scroll);

            template_textview = new TextView();
            template_textview.set_wrap_mode(WrapMode.WORD);
            template_textview.add_css_class("monospace");
            template_textview.get_buffer().set_text(editing_profile.template ?? "");

            template_scroll.set_child(template_textview);

            var template_widget_row = new Adw.ActionRow();
            template_widget_row.set_child(template_frame);
            group.add(template_widget_row);

            // Boutons d'aide pour le template
            var template_actions_row = new Adw.ActionRow();
            template_actions_row.set_title("Modèles prédéfinis");

            var mistral_button = new Button.with_label("Mistral");
            mistral_button.add_css_class("pill");
            mistral_button.clicked.connect(() => {
                var mistral_template = "<s>[INST] {system}\n\n{user} [/INST] {assistant}</s>";
                template_textview.get_buffer().set_text(mistral_template);
            });
            template_actions_row.add_suffix(mistral_button);

            var llama_button = new Button.with_label("Llama");
            llama_button.add_css_class("pill");
            llama_button.clicked.connect(() => {
                var llama_template = "<|begin_of_text|><|start_header_id|>system<|end_header_id|>\n\n{system}<|eot_id|><|start_header_id|>user<|end_header_id|>\n\n{user}<|eot_id|><|start_header_id|>assistant<|end_header_id|>\n\n{assistant}";
                template_textview.get_buffer().set_text(llama_template);
            });
            template_actions_row.add_suffix(llama_button);

            var clear_template_button = new Button.with_label("Effacer");
            clear_template_button.add_css_class("pill");
            clear_template_button.add_css_class("destructive-action");
            clear_template_button.clicked.connect(() => {
                template_textview.get_buffer().set_text("");
            });
            template_actions_row.add_suffix(clear_template_button);

            group.add(template_actions_row);
            preferences_page.add(group);
        }

        private void create_sampling_section() {
            var group = new Adw.PreferencesGroup();
            group.set_title("⚙️ Paramètres de génération");
            group.set_description("Contrôlez la créativité et le style de génération");

            // Température avec indicateur visuel
            temperature_row = new Adw.SpinRow.with_range(0.0, 2.0, 0.1);
            temperature_row.set_title("Température");
            temperature_row.set_subtitle("Contrôle la créativité (0.1 = logique, 2.0 = créatif)");
            temperature_row.set_value(editing_profile.temperature);
            var temp_icon = new Image.from_icon_name("temperature-symbolic");
            temp_icon.add_css_class(get_temperature_color(editing_profile.temperature));
            temperature_row.add_prefix(temp_icon);

            // Mise à jour de l'icône en temps réel
            temperature_row.changed.connect(() => {
                temp_icon.remove_css_class("success");
                temp_icon.remove_css_class("accent");
                temp_icon.remove_css_class("warning");
                temp_icon.remove_css_class("error");
                temp_icon.add_css_class(get_temperature_color((float)temperature_row.get_value()));
            });
            group.add(temperature_row);

            // Top-P
            top_p_row = new Adw.SpinRow.with_range(0.0, 1.0, 0.05);
            top_p_row.set_title("Top-P (Nucleus Sampling)");
            top_p_row.set_subtitle("Limite les tokens selon leur probabilité cumulative");
            top_p_row.set_value(editing_profile.top_p);
            var top_p_icon = new Image.from_icon_name("view-filter-symbolic");
            top_p_icon.add_css_class("accent");
            top_p_row.add_prefix(top_p_icon);
            group.add(top_p_row);

            // Top-K
            top_k_row = new Adw.SpinRow.with_range(1, 100, 1);
            top_k_row.set_title("Top-K");
            top_k_row.set_subtitle("Nombre de tokens les plus probables à considérer");
            top_k_row.set_value(editing_profile.top_k);
            var top_k_icon = new Image.from_icon_name("view-list-symbolic");
            top_k_icon.add_css_class("accent");
            top_k_row.add_prefix(top_k_icon);
            group.add(top_k_row);

            // Max tokens
            max_tokens_row = new Adw.SpinRow.with_range(1, 4096, 1);
            max_tokens_row.set_title("Tokens maximum");
            max_tokens_row.set_subtitle("Longueur maximale de la réponse");
            max_tokens_row.set_value(editing_profile.max_tokens);
            var max_tokens_icon = new Image.from_icon_name("text-x-generic-symbolic");
            max_tokens_icon.add_css_class("accent");
            max_tokens_row.add_prefix(max_tokens_icon);
            group.add(max_tokens_row);

            preferences_page.add(group);
        }

        private void create_advanced_section() {
            var group = new Adw.PreferencesGroup();
            group.set_title("🔧 Paramètres avancés");
            group.set_description("Contrôles fins pour utilisateurs expérimentés");

            // Repetition penalty
            repetition_penalty_row = new Adw.SpinRow.with_range(0.0, 2.0, 0.1);
            repetition_penalty_row.set_title("Pénalité de répétition");
            repetition_penalty_row.set_subtitle("Réduit la répétition de phrases");
            repetition_penalty_row.set_value(editing_profile.repetition_penalty);
            var rep_icon = new Image.from_icon_name("media-playlist-repeat-symbolic");
            rep_icon.add_css_class("warning");
            repetition_penalty_row.add_prefix(rep_icon);
            group.add(repetition_penalty_row);

            // Frequency penalty
            frequency_penalty_row = new Adw.SpinRow.with_range(0.0, 2.0, 0.1);
            frequency_penalty_row.set_title("Pénalité de fréquence");
            frequency_penalty_row.set_subtitle("Réduit la fréquence des mots répétés");
            frequency_penalty_row.set_value(editing_profile.frequency_penalty);
            var freq_icon = new Image.from_icon_name("preferences-system-symbolic");
            freq_icon.add_css_class("warning");
            frequency_penalty_row.add_prefix(freq_icon);
            group.add(frequency_penalty_row);

            // Presence penalty
            presence_penalty_row = new Adw.SpinRow.with_range(0.0, 2.0, 0.1);
            presence_penalty_row.set_title("Pénalité de présence");
            presence_penalty_row.set_subtitle("Encourage l'utilisation de nouveaux mots");
            presence_penalty_row.set_value(editing_profile.presence_penalty);
            var pres_icon = new Image.from_icon_name("insert-text-symbolic");
            pres_icon.add_css_class("warning");
            presence_penalty_row.add_prefix(pres_icon);
            group.add(presence_penalty_row);

            // Seed
            seed_row = new Adw.SpinRow.with_range(-1, 999999, 1);
            seed_row.set_title("Seed (Graine)");
            seed_row.set_subtitle("Pour des résultats reproductibles (-1 = aléatoire)");
            seed_row.set_value(editing_profile.seed);
            var seed_icon = new Image.from_icon_name("dice-1-symbolic");
            seed_icon.add_css_class("accent");
            seed_row.add_prefix(seed_icon);
            group.add(seed_row);

            // Context length
            context_length_row = new Adw.SpinRow.with_range(512, 8192, 256);
            context_length_row.set_title("Longueur du contexte");
            context_length_row.set_subtitle("Mémoire de l'IA en tokens");
            context_length_row.set_value(editing_profile.context_length);
            var context_icon = new Image.from_icon_name("view-paged-symbolic");
            context_icon.add_css_class("accent");
            context_length_row.add_prefix(context_icon);
            group.add(context_length_row);

            // Stream avec icône animée
            stream_row = new Adw.SwitchRow();
            stream_row.set_title("Mode streaming");
            stream_row.set_subtitle("Affiche la réponse en temps réel");
            stream_row.set_active(editing_profile.stream);
            var stream_icon = new Image.from_icon_name("media-playback-start-symbolic");
            stream_icon.add_css_class("success");
            stream_row.add_prefix(stream_icon);
            group.add(stream_row);

            preferences_page.add(group);
        }

        private void populate_model_list() {
            model_list.splice(0, model_list.get_n_items(), null);
            model_paths.clear();

            model_list.append("🚫 Aucun modèle sélectionné");
            model_paths.set("🚫 Aucun modèle sélectionné", "");

            var models_tree = config_manager.get_models_tree();
            if (!models_tree.has_error()) {
                populate_model_list_recursive(models_tree, "");
            }

            // Sélectionner le modèle actuel
            if (editing_profile.model_path != "") {
                var model_name = Path.get_basename(editing_profile.model_path);
                for (uint i = 0; i < model_list.get_n_items(); i++) {
                    var item = model_list.get_string(i);
                    if (item.contains(model_name)) {
                        model_dropdown.set_selected(i);
                        break;
                    }
                }
            }
        }

        private void populate_model_list_recursive(ConfigManager.ModelNode node, string prefix) {
            if (node.is_file) {
                string emoji = "🤖";
                if (node.name.contains("instruct") || node.name.contains("chat")) {
                    emoji = "💬";
                } else if (node.name.contains("code")) {
                    emoji = "💻";
                }

                string display_name = "%s %s (%s)".printf(emoji, node.name, node.size_str);
                if (prefix != "") {
                    display_name = "%s %s/%s (%s)".printf(emoji, prefix, node.name, node.size_str);
                }
                model_list.append(display_name);
                model_paths.set(display_name, node.full_path);
            } else if (node.name != "Models") {
                string new_prefix = prefix != "" ? "%s/%s".printf(prefix, node.name) : node.name;
                foreach (var child in node.children) {
                    populate_model_list_recursive(child, new_prefix);
                }
            } else {
                foreach (var child in node.children) {
                    populate_model_list_recursive(child, "");
                }
            }
        }

        private void populate_fields() {
            title_entry.set_text(editing_profile.title);
            comment_entry.set_text(editing_profile.comment);
            prompt_textview.get_buffer().set_text(editing_profile.prompt);
            validate_form();
        }

        private void validate_form() {
            bool title_valid = title_entry.get_text().strip() != "";
            bool prompt_valid = false;

            TextIter start, end;
            prompt_textview.get_buffer().get_bounds(out start, out end);
            string prompt_text = prompt_textview.get_buffer().get_text(start, end, false).strip();
            prompt_valid = prompt_text != "";

            save_button.set_sensitive(title_valid && prompt_valid);

            // Mise à jour visuelle des champs
            if (title_valid) {
                title_entry.remove_css_class("error");
            } else {
                title_entry.add_css_class("error");
            }
        }

        private string get_temperature_color(float temperature) {
            if (temperature < 0.3) return "success";  // Vert pour déterministe
            if (temperature < 0.7) return "accent";   // Bleu pour équilibré
            if (temperature < 1.2) return "warning";  // Orange pour créatif
            return "error";  // Rouge pour très créatif
        }

        private void show_prompt_examples() {
            var dialog = new Adw.MessageDialog(this, "💡 Exemples de prompts", null);

            var examples = """**🤖 Assistant général :**
Tu es un assistant IA utile et bienveillant. Réponds de manière claire et concise.

**💻 Assistant technique :**
Tu es un expert en programmation. Fournis des réponses techniques précises avec des exemples de code.

**✍️ Assistant créatif :**
Tu es un assistant créatif spécialisé dans l'écriture. Sois imaginatif et propose des solutions originales.

**🎓 Assistant éducatif :**
Tu es un professeur patient. Explique les concepts de manière simple avec des exemples concrets.

**🔬 Assistant de recherche :**
Tu es un assistant de recherche rigoureux. Fournis des informations factuelles et sourcées.""";

            dialog.set_body(examples);
            dialog.add_response("close", "Fermer");
            dialog.set_default_response("close");
            dialog.present();
        }

        private void on_save_clicked() {
            // Récupérer les valeurs
            editing_profile.title = title_entry.get_text().strip();
            editing_profile.comment = comment_entry.get_text().strip();

            TextIter start, end;
            prompt_textview.get_buffer().get_bounds(out start, out end);
            editing_profile.prompt = prompt_textview.get_buffer().get_text(start, end, false).strip();

            // Récupérer le template
            template_textview.get_buffer().get_bounds(out start, out end);
            editing_profile.template = template_textview.get_buffer().get_text(start, end, false).strip();

            // Récupérer le modèle sélectionné
            var selected_model = model_dropdown.get_selected();
            if (selected_model > 0) {
                var selected_text = model_list.get_string(selected_model);
                editing_profile.model_path = model_paths.get(selected_text) ?? "";
            } else {
                editing_profile.model_path = "";
            }

            // Paramètres de sampling
            editing_profile.temperature = (float)temperature_row.get_value();
            editing_profile.top_p = (float)top_p_row.get_value();
            editing_profile.top_k = (int)top_k_row.get_value();
            editing_profile.max_tokens = (int)max_tokens_row.get_value();
            editing_profile.repetition_penalty = (float)repetition_penalty_row.get_value();
            editing_profile.frequency_penalty = (float)frequency_penalty_row.get_value();
            editing_profile.presence_penalty = (float)presence_penalty_row.get_value();
            editing_profile.seed = (int)seed_row.get_value();
            editing_profile.context_length = (int)context_length_row.get_value();
            editing_profile.stream = stream_row.get_active();

            // Validation finale
            var errors = editing_profile.get_validation_errors();
            if (errors.length > 0) {
                show_toast("❌ " + string.joinv(", ", errors));
                return;
            }

            // Émettre le signal et fermer
            profile_saved.emit(editing_profile);
            this.close();
        }

        /**
         * Crée une section de prévisualisation moderne du profil
         */
        private void create_preview_section() {
            var group = new Adw.PreferencesGroup();
            group.set_title("🔍 Aperçu du profil");
            group.set_description("Visualisation en temps réel de votre profil");
            group.add_css_class("profile-preview-section");

            // Carte de prévisualisation
            var preview_card = new Adw.ActionRow();
            preview_card.set_title("Aperçu en temps réel");
            preview_card.set_subtitle("Vos modifications apparaîtront ici");
            preview_card.add_css_class("profile-preview-card");

            var preview_icon = new Image.from_icon_name("view-reveal-symbolic");
            preview_icon.add_css_class("accent");
            preview_card.add_prefix(preview_icon);

            var refresh_button = new Button.from_icon_name("view-refresh-symbolic");
            refresh_button.add_css_class("flat");
            refresh_button.set_tooltip_text("Actualiser l'aperçu");
            refresh_button.clicked.connect(update_preview);
            preview_card.add_suffix(refresh_button);

            group.add(preview_card);

            // Statistiques du profil
            var stats_expander = new Adw.ExpanderRow();
            stats_expander.set_title("📊 Statistiques");
            stats_expander.set_subtitle("Informations détaillées sur le profil");
            stats_expander.add_css_class("profile-stats-expander");

            var stats_content = new Box(Orientation.VERTICAL, 8);
            stats_content.set_margin_start(12);
            stats_content.set_margin_end(12);
            stats_content.set_margin_top(8);
            stats_content.set_margin_bottom(8);

            var prompt_length_label = new Label("Longueur du prompt : 0 caractères");
            prompt_length_label.add_css_class("caption");
            prompt_length_label.set_xalign(0);
            stats_content.append(prompt_length_label);

            var complexity_label = new Label("Complexité : Équilibrée");
            complexity_label.add_css_class("caption");
            complexity_label.set_xalign(0);
            stats_content.append(complexity_label);

            var estimated_tokens_label = new Label("Tokens estimés : ~150");
            estimated_tokens_label.add_css_class("caption");
            estimated_tokens_label.set_xalign(0);
            stats_content.append(estimated_tokens_label);

            stats_expander.add_row(stats_content);
            group.add(stats_expander);

            // Conseils d'optimisation
            var tips_expander = new Adw.ExpanderRow();
            tips_expander.set_title("💡 Conseils d'optimisation");
            tips_expander.set_subtitle("Améliorez les performances de votre profil");
            tips_expander.add_css_class("profile-tips-expander");

            var tips_content = new Box(Orientation.VERTICAL, 8);
            tips_content.set_margin_start(12);
            tips_content.set_margin_end(12);
            tips_content.set_margin_top(8);
            tips_content.set_margin_bottom(8);

            var tip1 = new Label("• Une température entre 0.3 et 0.8 donne de bons résultats");
            tip1.add_css_class("caption");
            tip1.set_xalign(0);
            tips_content.append(tip1);

            var tip2 = new Label("• Un prompt concis et précis améliore la qualité des réponses");
            tip2.add_css_class("caption");
            tip2.set_xalign(0);
            tips_content.append(tip2);

            var tip3 = new Label("• Activez le streaming pour une meilleure expérience utilisateur");
            tip3.add_css_class("caption");
            tip3.set_xalign(0);
            tips_content.append(tip3);

            tips_expander.add_row(tips_content);
            group.add(tips_expander);

            preferences_page.add(group);
        }

        /**
         * Met à jour l'aperçu du profil en temps réel
         */
        private void update_preview() {
            // Mise à jour des statistiques basées sur les valeurs actuelles
            var prompt_text = "";
            TextIter start, end;
            prompt_textview.get_buffer().get_bounds(out start, out end);
            prompt_text = prompt_textview.get_buffer().get_text(start, end, false);

            // Calcul de la complexité basée sur la température
            var temp = (float)temperature_row.get_value();
            string complexity;
            if (temp < 0.3) {
                complexity = "🟢 Déterministe";
            } else if (temp < 0.7) {
                complexity = "🟡 Équilibrée";
            } else if (temp < 1.2) {
                complexity = "🟠 Créative";
            } else {
                complexity = "🔴 Très créative";
            }

            // Estimation des tokens (approximation simple)
            var estimated_tokens = (int)(prompt_text.length / 4.0 + 50);

            show_toast("🔄 Aperçu mis à jour");
        }

        private void show_toast(string message) {
            var toast = new Adw.Toast(message);
            toast.set_timeout(5);
            toast_overlay.add_toast(toast);
        }
    }
}
