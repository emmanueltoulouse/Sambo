using Gtk;
using Adw;

namespace Sambo {
    /**
     * Dialogue d'édition des profils d'inférence
     */
    public class ProfileEditorDialog : Adw.Window {
        private ApplicationController controller;
        private ConfigManager config_manager;
        private InferenceProfile? original_profile;
        private InferenceProfile editing_profile;
        private bool is_editing;

        // Widgets d'interface
        private Adw.EntryRow title_entry;
        private Adw.EntryRow comment_entry;
        private TextView prompt_textview;
        private DropDown model_dropdown;
        private StringList model_list;
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
        private Button save_button;
        private Button cancel_button;
        private Adw.ToastOverlay toast_overlay;

        public signal void profile_saved(InferenceProfile profile);

        public ProfileEditorDialog(Gtk.Window parent, ApplicationController controller, InferenceProfile? profile = null) {
            Object(
                title: profile == null ? "Créer un profil" : "Éditer le profil",
                default_width: 600,
                default_height: 700,
                modal: true,
                transient_for: parent
            );

            this.controller = controller;
            this.config_manager = controller.get_config_manager();
            this.original_profile = profile;
            this.is_editing = profile != null;

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

            setup_ui();
            populate_fields();
        }

        private void setup_ui() {
            // Toast overlay pour les notifications
            toast_overlay = new Adw.ToastOverlay();
            set_content(toast_overlay);

            // Boîte principale
            var main_box = new Box(Orientation.VERTICAL, 0);
            toast_overlay.set_child(main_box);

            // Header bar
            var header_bar = new Adw.HeaderBar();
            main_box.append(header_bar);

            // Boutons dans la header bar
            cancel_button = new Button.with_label("Annuler");
            cancel_button.clicked.connect(() => this.close());
            header_bar.pack_start(cancel_button);

            save_button = new Button.with_label(is_editing ? "Enregistrer" : "Créer");
            save_button.add_css_class("suggested-action");
            save_button.clicked.connect(on_save_clicked);
            header_bar.pack_end(save_button);

            // Contenu principal
            var content_box = new Box(Orientation.VERTICAL, 12);
            content_box.set_margin_top(12);
            content_box.set_margin_bottom(12);
            content_box.set_margin_start(12);
            content_box.set_margin_end(12);

            // Zone de défilement
            var scroll = new ScrolledWindow();
            scroll.set_policy(PolicyType.NEVER, PolicyType.AUTOMATIC);
            scroll.set_vexpand(true);
            scroll.set_child(content_box);
            main_box.append(scroll);

            // Créer les sections
            content_box.append(create_general_section());
            content_box.append(create_model_section());
            content_box.append(create_prompt_section());
            content_box.append(create_sampling_section());
            content_box.append(create_advanced_section());
        }

        private Widget create_general_section() {
            var group = new Adw.PreferencesGroup();
            group.set_title("Informations générales");
            group.set_description("Définissez le nom et la description du profil");

            // Titre
            var title_row = new Adw.EntryRow();
            title_row.set_title("Titre du profil");
            title_row.set_text(editing_profile.title);
            title_entry = title_row;
            group.add(title_row);

            // Commentaire
            var comment_row = new Adw.EntryRow();
            comment_row.set_title("Commentaire (optionnel)");
            comment_row.set_text(editing_profile.comment);
            comment_entry = comment_row;
            group.add(comment_row);

            return group;
        }

        private Widget create_model_section() {
            var group = new Adw.PreferencesGroup();
            group.set_title("Modèle");
            group.set_description("Sélectionnez le modèle à utiliser");

            // Dropdown pour la sélection du modèle
            model_list = new StringList(null);
            populate_model_list();

            model_dropdown = new DropDown(model_list, null);
            var model_row = new Adw.ActionRow();
            model_row.set_title("Modèle sélectionné");
            model_row.set_subtitle("Choisissez le modèle à utiliser pour ce profil");
            model_row.add_suffix(model_dropdown);
            group.add(model_row);

            return group;
        }

        private void populate_model_list() {
            // Vider la liste existante
            var n_items = model_list.get_n_items();
            if (n_items > 0) {
                model_list.splice(0, n_items, null);
            }
            
            model_list.append("Aucun modèle sélectionné");

            var models_tree = config_manager.get_models_tree();
            if (models_tree.has_error()) {
                return;
            }

            populate_model_list_recursive(models_tree, "");
            
            // Sélectionner le modèle actuel
            if (editing_profile.model_path != "") {
                for (uint i = 0; i < model_list.get_n_items(); i++) {
                    var item = model_list.get_string(i);
                    if (item.contains(Path.get_basename(editing_profile.model_path))) {
                        model_dropdown.set_selected(i);
                        break;
                    }
                }
            }
        }

        private void populate_model_list_recursive(ConfigManager.ModelNode node, string prefix) {
            if (node.is_file) {
                string display_name = prefix != "" ? "%s/%s (%s)".printf(prefix, node.name, node.size_str) : "%s (%s)".printf(node.name, node.size_str);
                model_list.append(display_name);
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

        private Widget create_prompt_section() {
            var group = new Adw.PreferencesGroup();
            group.set_title("Prompt système");
            group.set_description("Définissez le prompt qui sera utilisé pour initialiser l'IA");

            // Zone de texte pour le prompt
            var prompt_frame = new Frame(null);
            prompt_frame.set_size_request(-1, 200);
            
            var prompt_scroll = new ScrolledWindow();
            prompt_scroll.set_policy(PolicyType.AUTOMATIC, PolicyType.AUTOMATIC);
            prompt_frame.set_child(prompt_scroll);

            prompt_textview = new TextView();
            prompt_textview.set_wrap_mode(WrapMode.WORD);
            prompt_textview.get_buffer().set_text(editing_profile.prompt);
            prompt_scroll.set_child(prompt_textview);

            group.set_header_suffix(prompt_frame);

            // Bouton pour les exemples
            var examples_button = new Button.with_label("Exemples de prompts");
            examples_button.clicked.connect(show_prompt_examples);
            group.add(examples_button);

            return group;
        }

        private Widget create_sampling_section() {
            var group = new Adw.PreferencesGroup();
            group.set_title("Paramètres de sampling");
            group.set_description("Contrôlez la créativité et la génération de texte");

            // Température
            temperature_row = new Adw.SpinRow.with_range(0.0, 2.0, 0.1);
            temperature_row.set_title("Température");
            temperature_row.set_subtitle("Contrôle la créativité (0.1 = déterministe, 2.0 = très créatif)");
            temperature_row.set_value(editing_profile.temperature);
            group.add(temperature_row);

            // Top-P
            top_p_row = new Adw.SpinRow.with_range(0.0, 1.0, 0.05);
            top_p_row.set_title("Top-P");
            top_p_row.set_subtitle("Limite les tokens selon leur probabilité cumulative");
            top_p_row.set_value(editing_profile.top_p);
            group.add(top_p_row);

            // Top-K
            top_k_row = new Adw.SpinRow.with_range(1, 100, 1);
            top_k_row.set_title("Top-K");
            top_k_row.set_subtitle("Nombre de tokens les plus probables à considérer");
            top_k_row.set_value(editing_profile.top_k);
            group.add(top_k_row);

            // Max tokens
            max_tokens_row = new Adw.SpinRow.with_range(1, 4096, 1);
            max_tokens_row.set_title("Tokens maximum");
            max_tokens_row.set_subtitle("Nombre maximum de tokens à générer");
            max_tokens_row.set_value(editing_profile.max_tokens);
            group.add(max_tokens_row);

            return group;
        }

        private Widget create_advanced_section() {
            var group = new Adw.PreferencesGroup();
            group.set_title("Paramètres avancés");
            group.set_description("Paramètres de contrôle avancés");

            // Repetition penalty
            repetition_penalty_row = new Adw.SpinRow.with_range(0.0, 2.0, 0.1);
            repetition_penalty_row.set_title("Pénalité de répétition");
            repetition_penalty_row.set_subtitle("Réduit la répétition de mots");
            repetition_penalty_row.set_value(editing_profile.repetition_penalty);
            group.add(repetition_penalty_row);

            // Frequency penalty
            frequency_penalty_row = new Adw.SpinRow.with_range(0.0, 2.0, 0.1);
            frequency_penalty_row.set_title("Pénalité de fréquence");
            frequency_penalty_row.set_subtitle("Réduit la fréquence des mots répétés");
            frequency_penalty_row.set_value(editing_profile.frequency_penalty);
            group.add(frequency_penalty_row);

            // Presence penalty
            presence_penalty_row = new Adw.SpinRow.with_range(0.0, 2.0, 0.1);
            presence_penalty_row.set_title("Pénalité de présence");
            presence_penalty_row.set_subtitle("Encourage l'utilisation de nouveaux mots");
            presence_penalty_row.set_value(editing_profile.presence_penalty);
            group.add(presence_penalty_row);

            // Seed
            seed_row = new Adw.SpinRow.with_range(-1, 999999, 1);
            seed_row.set_title("Seed");
            seed_row.set_subtitle("Graine pour la génération (-1 = aléatoire)");
            seed_row.set_value(editing_profile.seed);
            group.add(seed_row);

            // Context length
            context_length_row = new Adw.SpinRow.with_range(512, 8192, 256);
            context_length_row.set_title("Longueur du contexte");
            context_length_row.set_subtitle("Taille du contexte en tokens");
            context_length_row.set_value(editing_profile.context_length);
            group.add(context_length_row);

            // Stream
            stream_row = new Adw.SwitchRow();
            stream_row.set_title("Mode streaming");
            stream_row.set_subtitle("Affiche la réponse en temps réel");
            stream_row.set_active(editing_profile.stream);
            group.add(stream_row);

            return group;
        }

        private void show_prompt_examples() {
            var dialog = new Adw.MessageDialog(this, "Exemples de prompts", null);
            
            var examples = """Voici quelques exemples de prompts système efficaces :

**Assistant général :**
Tu es un assistant IA utile et bienveillant. Réponds de manière claire et concise.

**Assistant technique :**
Tu es un expert en programmation et technologie. Fournis des réponses précises et techniques avec des exemples de code quand c'est approprié.

**Assistant créatif :**
Tu es un assistant créatif spécialisé dans l'écriture et la génération d'idées. Sois imaginatif et propose des solutions originales.

**Assistant éducatif :**
Tu es un professeur patient et pédagogue. Explique les concepts de manière simple et progressive avec des exemples concrets.

**Assistant de recherche :**
Tu es un assistant de recherche rigoureux. Fournis des informations factuelles et sourcées, et indique clairement les limites de tes connaissances.""";

            dialog.set_body(examples);
            dialog.add_response("close", "Fermer");
            dialog.set_default_response("close");
            dialog.present();
        }

        private void populate_fields() {
            title_entry.set_text(editing_profile.title);
            comment_entry.set_text(editing_profile.comment);
            prompt_textview.get_buffer().set_text(editing_profile.prompt);
            
            // Les autres champs sont déjà populés dans create_*_section()
        }

        private void on_save_clicked() {
            // Récupérer les valeurs des champs
            editing_profile.title = title_entry.get_text().strip();
            editing_profile.comment = comment_entry.get_text().strip();
            
            TextIter start, end;
            prompt_textview.get_buffer().get_bounds(out start, out end);
            editing_profile.prompt = prompt_textview.get_buffer().get_text(start, end, false).strip();

            // Récupérer le modèle sélectionné
            var selected_model = model_dropdown.get_selected();
            if (selected_model > 0) {
                var selected_text = model_list.get_string(selected_model);
                editing_profile.model_path = extract_model_path_from_selection(selected_text);
            } else {
                editing_profile.model_path = "";
            }

            // Récupérer les paramètres de sampling
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

            // Valider le profil
            var errors = editing_profile.get_validation_errors();
            if (errors.length > 0) {
                var error_message = "Erreurs de validation :\n" + string.joinv("\n", errors);
                show_toast(error_message);
                return;
            }

            // Émettre le signal de sauvegarde
            profile_saved.emit(editing_profile);
            this.close();
        }

        private string extract_model_path_from_selection(string selection) {
            // Cette fonction doit extraire le chemin du modèle depuis la sélection
            // Pour l'instant, on va utiliser une méthode simple
            var models_tree = config_manager.get_models_tree();
            return find_model_path_in_tree(models_tree, selection, "");
        }

        private string find_model_path_in_tree(ConfigManager.ModelNode node, string selection, string prefix) {
            if (node.is_file) {
                string display_name = prefix != "" ? "%s/%s (%s)".printf(prefix, node.name, node.size_str) : "%s (%s)".printf(node.name, node.size_str);
                if (display_name == selection) {
                    return node.full_path;
                }
            } else if (node.name != "Models") {
                string new_prefix = prefix != "" ? "%s/%s".printf(prefix, node.name) : node.name;
                foreach (var child in node.children) {
                    string result = find_model_path_in_tree(child, selection, new_prefix);
                    if (result != "") {
                        return result;
                    }
                }
            } else {
                foreach (var child in node.children) {
                    string result = find_model_path_in_tree(child, selection, "");
                    if (result != "") {
                        return result;
                    }
                }
            }
            return "";
        }

        private void show_toast(string message) {
            var toast = new Adw.Toast(message);
            toast.set_timeout(5);
            toast_overlay.add_toast(toast);
        }
    }
}
