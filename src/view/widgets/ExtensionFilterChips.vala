using Gtk;
using Gee;

namespace Sambo {
    /**
     * Widget de sélection multiple d'extensions sous forme de bulles (chips)
     */
    public class ExtensionFilterChips : Box {
        public signal void selection_changed(Set<string> selected_extensions);
        // Signal emitted when an extension is selected or deselected
        public signal void extension_selected(string ext, bool selected);

        private Entry search_entry;
        private FlowBox chips_box;
        private Button select_all_btn;
        private Button clear_btn;

        private Gee.List<string> all_extensions;
        private Set<string> selected_extensions;
        private Gee.List<ExtensionInfo> extensions;

        public ExtensionFilterChips(Gee.List<ExtensionInfo> extensions) {
            Object(orientation: Orientation.VERTICAL, spacing: 6);

            this.extensions = extensions;
            all_extensions = new Gee.ArrayList<string>();
            foreach (var extinfo in extensions) {
                all_extensions.add(extinfo.extension);
            }
            all_extensions.sort(); // Tri alphabétique

            selected_extensions = new HashSet<string>();

            // Barre de recherche
            search_entry = new Entry();
            search_entry.set_placeholder_text(_("Rechercher une extension..."));
            search_entry.changed.connect(() => update_chips());

            // Boutons "Tout sélectionner" et "Aucune"
            var btn_box = new Box(Orientation.HORIZONTAL, 6);
            select_all_btn = new Button.with_label(_("Tout sélectionner"));
            clear_btn = new Button.with_label(_("Aucune"));
            select_all_btn.clicked.connect(() => {
                selected_extensions.clear();
                foreach (var ext in all_extensions) selected_extensions.add(ext);
                update_chips();
                selection_changed(selected_extensions);
            });
            clear_btn.clicked.connect(() => {
                selected_extensions.clear();
                update_chips();
                selection_changed(selected_extensions);
            });
            btn_box.append(select_all_btn);
            btn_box.append(clear_btn);

            // FlowBox pour les bulles
            chips_box = new FlowBox();
            chips_box.set_selection_mode(SelectionMode.NONE);

            append(search_entry);
            append(btn_box);
            append(chips_box);

            update_chips();
        }

        private void update_chips() {
            chips_box.remove_all();
            string filter = search_entry.text.down().strip();
            foreach (var extinfo in extensions) {
                if (filter != "" && !extinfo.extension.down().contains(filter)) continue;
                var chip = new ToggleButton.with_label(extinfo.extension);
                chip.set_tooltip_text(extinfo.label); // Affiche le label au survol
                chip.set_active(selected_extensions.contains(extinfo.extension));
                chip.toggled.connect(() => {
                    if (chip.active)
                        selected_extensions.add(extinfo.extension);
                    else
                        selected_extensions.remove(extinfo.extension);
                    selection_changed(selected_extensions);
                    extension_selected(extinfo.extension, chip.active);
                });
                chips_box.append(chip);
            }
        }

        public Set<string> get_selected_extensions() {
            return selected_extensions;
        }

        public void set_selected_extensions(Set<string> exts) {
            selected_extensions.clear();
            selected_extensions.add_all(exts);
            update_chips();
        }
    }
}
