using Gtk;
using Adw;
using Gee;

namespace Sambo {
    /**
     * Assistant moderne de création de profil avec interface guidée
     */
    public class ProfileCreationWizard : Adw.Window {
        private ApplicationController controller;
        private ConfigManager config_manager;
        
        // Interface moderne
        private Adw.HeaderBar header_bar;
        private Adw.Carousel carousel;
        private Adw.CarouselIndicatorDots indicator;
        private Adw.ToastOverlay toast_overlay;
        private Button next_button;
        private Button back_button;
        private Button finish_button;
        
        // Données du profil en cours de création
        private InferenceProfile new_profile;
        private int current_step = 0;
        private const int TOTAL_STEPS = 4;
        
        // Widgets des étapes
        private Adw.EntryRow title_entry;
        private Adw.EntryRow description_entry;
        private DropDown model_dropdown;
        private TextView prompt_textview;
        private Adw.SpinRow temperature_row;
        private Adw.SpinRow max_tokens_row;
        private Adw.SwitchRow stream_row;
        
        public signal void profile_created(InferenceProfile profile);
        
        public ProfileCreationWizard(Gtk.Window parent, ApplicationController controller) {
            Object(
                title: "Assistant de création de profil",
                default_width: 600,
                default_height: 500,
                modal: true,
                transient_for: parent
            );
            
            this.controller = controller;
            this.config_manager = controller.get_config_manager();
            
            // Créer le nouveau profil
            new_profile = InferenceProfile.create_default(
                InferenceProfile.generate_unique_id(),
                "Nouveau profil"
            );
            
            setup_ui();
            setup_steps();
            update_navigation();
        }
        
        private void setup_ui() {
            add_css_class("profile-creation-wizard");
            
            // Toast overlay principal
            toast_overlay = new Adw.ToastOverlay();
            set_content(toast_overlay);
            
            var main_box = new Box(Orientation.VERTICAL, 0);
            toast_overlay.set_child(main_box);
            
            // Header bar moderne
            header_bar = new Adw.HeaderBar();
            header_bar.add_css_class("flat");
            header_bar.add_css_class("wizard-header");
            
            var title_box = new Box(Orientation.HORIZONTAL, 8);
            var wizard_icon = new Image.from_icon_name("preferences-system-symbolic");
            wizard_icon.add_css_class("accent");
            title_box.append(wizard_icon);
            
            var title_label = new Label("Assistant de création");
            title_label.add_css_class("heading");
            title_box.append(title_label);
            
            header_bar.set_title_widget(title_box);
            
            // Boutons de navigation
            back_button = new Button.with_label("Précédent");
            back_button.add_css_class("flat");
            back_button.clicked.connect(go_back);
            header_bar.pack_start(back_button);
            
            next_button = new Button.with_label("Suivant");
            next_button.add_css_class("suggested-action");
            next_button.clicked.connect(go_next);
            header_bar.pack_end(next_button);
            
            finish_button = new Button.with_label("✨ Créer le profil");
            finish_button.add_css_class("suggested-action");
            finish_button.add_css_class("wizard-finish-button");
            finish_button.clicked.connect(finish_wizard);
            finish_button.set_visible(false);
            header_bar.pack_end(finish_button);
            
            var cancel_button = new Button.with_label("Annuler");
            cancel_button.add_css_class("flat");
            cancel_button.clicked.connect(() => this.close());
            header_bar.pack_start(cancel_button);
            
            main_box.append(header_bar);
            
            // Indicateur de progression
            indicator = new Adw.CarouselIndicatorDots();
            indicator.add_css_class("wizard-indicator");
            main_box.append(indicator);
            
            // Carousel pour les étapes
            carousel = new Adw.Carousel();
            carousel.set_allow_scroll_wheel(false);
            carousel.set_allow_mouse_drag(false);
            carousel.set_allow_long_swipes(false);
            carousel.add_css_class("wizard-carousel");
            indicator.set_carousel(carousel);
            
            main_box.append(carousel);
        }
        
        private void setup_steps() {
            // Étape 1 : Informations de base
            var step1 = create_step1();
            carousel.append(step1);
            
            // Étape 2 : Sélection du modèle
            var step2 = create_step2();
            carousel.append(step2);
            
            // Étape 3 : Prompt système
            var step3 = create_step3();
            carousel.append(step3);
            
            // Étape 4 : Paramètres de génération
            var step4 = create_step4();
            carousel.append(step4);
        }
        
        private Widget create_step1() {
            var page = new Adw.StatusPage();
            page.set_icon_name("document-edit-symbolic");
            page.set_title("Informations de base");
            page.set_description("Donnez un nom et une description à votre profil");
            
            var group = new Adw.PreferencesGroup();
            group.set_title("Identité du profil");
            
            title_entry = new Adw.EntryRow();
            title_entry.set_title("Nom du profil");
            title_entry.set_text(new_profile.title);
            title_entry.changed.connect(() => {
                new_profile.title = title_entry.get_text();
            });
            group.add(title_entry);
            
            description_entry = new Adw.EntryRow();
            description_entry.set_title("Description (optionnel)");
            description_entry.set_text(new_profile.comment);
            description_entry.changed.connect(() => {
                new_profile.comment = description_entry.get_text();
            });
            group.add(description_entry);
            
            page.set_child(group);
            return page;
        }
        
        private Widget create_step2() {
            var page = new Adw.StatusPage();
            page.set_icon_name("applications-science-symbolic");
            page.set_title("Sélection du modèle");
            page.set_description("Choisissez le modèle d'IA à utiliser");
            
            var group = new Adw.PreferencesGroup();
            group.set_title("Modèle d'IA");
            
            // Dropdown pour les modèles
            var model_list = new StringList(null);
            var models = config_manager.get_available_models();
            foreach (string model in models) {
                model_list.append(model);
            }
            
            model_dropdown = new DropDown(model_list, null);
            
            var model_row = new Adw.ActionRow();
            model_row.set_title("Modèle sélectionné");
            model_row.set_subtitle("Choisissez parmi les modèles disponibles");
            model_row.add_suffix(model_dropdown);
            group.add(model_row);
            
            page.set_child(group);
            return page;
        }
        
        private Widget create_step3() {
            var page = new Adw.StatusPage();
            page.set_icon_name("text-x-script-symbolic");
            page.set_title("Prompt système");
            page.set_description("Définissez les instructions pour l'IA");
            
            var group = new Adw.PreferencesGroup();
            group.set_title("Instructions système");
            
            var prompt_frame = new Frame(null);
            prompt_frame.add_css_class("card");
            prompt_frame.set_size_request(-1, 200);
            
            var prompt_scroll = new ScrolledWindow();
            prompt_scroll.set_policy(PolicyType.AUTOMATIC, PolicyType.AUTOMATIC);
            prompt_frame.set_child(prompt_scroll);
            
            prompt_textview = new TextView();
            prompt_textview.set_wrap_mode(WrapMode.WORD);
            prompt_textview.add_css_class("monospace");
            prompt_textview.get_buffer().set_text(new_profile.prompt);
            prompt_textview.get_buffer().changed.connect(() => {
                TextIter start, end;
                prompt_textview.get_buffer().get_bounds(out start, out end);
                new_profile.prompt = prompt_textview.get_buffer().get_text(start, end, false);
            });
            
            prompt_scroll.set_child(prompt_textview);
            group.set_header_suffix(prompt_frame);
            
            page.set_child(group);
            return page;
        }
        
        private Widget create_step4() {
            var page = new Adw.StatusPage();
            page.set_icon_name("preferences-system-symbolic");
            page.set_title("Paramètres de génération");
            page.set_description("Configurez les paramètres de génération");
            
            var group = new Adw.PreferencesGroup();
            group.set_title("Configuration");
            
            // Température
            temperature_row = new Adw.SpinRow.with_range(0.0, 2.0, 0.1);
            temperature_row.set_title("Température");
            temperature_row.set_subtitle("Contrôle la créativité (0.0 = déterministe, 2.0 = très créatif)");
            temperature_row.set_value(new_profile.temperature);
            temperature_row.changed.connect(() => {
                new_profile.temperature = (float)temperature_row.get_value();
            });
            group.add(temperature_row);
            
            // Tokens maximum
            max_tokens_row = new Adw.SpinRow.with_range(50, 4096, 50);
            max_tokens_row.set_title("Tokens maximum");
            max_tokens_row.set_subtitle("Longueur maximale de la réponse");
            max_tokens_row.set_value(new_profile.max_tokens);
            max_tokens_row.changed.connect(() => {
                new_profile.max_tokens = (int)max_tokens_row.get_value();
            });
            group.add(max_tokens_row);
            
            // Mode streaming
            stream_row = new Adw.SwitchRow();
            stream_row.set_title("Mode streaming");
            stream_row.set_subtitle("Affiche la réponse en temps réel");
            stream_row.set_active(new_profile.stream);
            stream_row.notify["active"].connect(() => {
                new_profile.stream = stream_row.get_active();
            });
            group.add(stream_row);
            
            page.set_child(group);
            return page;
        }
        
        private void go_back() {
            if (current_step > 0) {
                current_step--;
                carousel.scroll_to(carousel.get_nth_page(current_step), true);
                update_navigation();
            }
        }
        
        private void go_next() {
            if (current_step < TOTAL_STEPS - 1) {
                current_step++;
                carousel.scroll_to(carousel.get_nth_page(current_step), true);
                update_navigation();
            }
        }
        
        private void update_navigation() {
            back_button.set_visible(current_step > 0);
            next_button.set_visible(current_step < TOTAL_STEPS - 1);
            finish_button.set_visible(current_step == TOTAL_STEPS - 1);
        }
        
        private void finish_wizard() {
            if (validate_profile()) {
                profile_created.emit(new_profile);
                show_toast("✨ Profil créé avec succès!");
                this.close();
            } else {
                show_toast("❌ Veuillez corriger les erreurs avant de continuer");
            }
        }
        
        private bool validate_profile() {
            if (new_profile.title.strip() == "") {
                show_toast("❌ Le nom du profil est requis");
                return false;
            }
            
            if (new_profile.prompt.strip() == "") {
                show_toast("❌ Le prompt système est requis");
                return false;
            }
            
            return true;
        }
        
        private void show_toast(string message) {
            var toast = new Adw.Toast(message);
            toast.set_timeout(3);
            toast_overlay.add_toast(toast);
        }
    }
}
