namespace Sambo {
    public class ErrorInfoBar : Gtk.Box {
        private Gtk.Label message_label;
        private Gtk.InfoBar info_bar;

        public ErrorInfoBar() {
            Object(orientation: Gtk.Orientation.VERTICAL, spacing: 0);

            info_bar = new Gtk.InfoBar();
            info_bar.set_message_type(Gtk.MessageType.ERROR);
            info_bar.set_revealed(false);
            info_bar.add_button("Fermer", Gtk.ResponseType.CLOSE);

            message_label = new Gtk.Label("");
            message_label.wrap = true;
            message_label.xalign = 0;

            info_bar.add_child(message_label);

            this.append(info_bar);

            info_bar.response.connect((id) => {
                if (id == Gtk.ResponseType.CLOSE) {
                    info_bar.set_revealed(false);
                }
            });
        }

        public void show_error(string message, string? details = null) {
            string display_message = message;

            if (details != null && details.strip() != "") {
                display_message += "\n\n" + details;
            }

            message_label.set_text(display_message);
            info_bar.set_revealed(true);

            // Masquer automatiquement après un délai
            Timeout.add_seconds(10, () => {
                info_bar.set_revealed(false);
                return false;
            });
        }
    }
}
