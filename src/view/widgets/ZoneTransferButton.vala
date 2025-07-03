/*
 * ZoneTransferButton.vala
 *
 * Widget bouton moderne en style bulle pour le transfert des contenus
 * des zones ChatView et TerminalView vers l'EditorView.
 *
 * Design : Bouton flottant avec icône, tooltip informatif et animations au survol.
 */

using Gtk;
using Adw;

public class Sambo.ZoneTransferButton : Box {

    private Button transfer_button;
    private bool hover_state = false;

    // Signaux
    public signal void transfer_requested();

    public ZoneTransferButton() {
        Object(orientation: Orientation.HORIZONTAL, spacing: 0);
        setup_ui();
        setup_styling();
        connect_signals();
    }

    private void setup_ui() {
        // Configuration du conteneur principal
        set_halign(Align.CENTER);
        set_valign(Align.CENTER);

        // Bouton principal avec icône
        transfer_button = new Button();
        transfer_button.set_icon_name("document-send-symbolic");
        transfer_button.set_tooltip_markup(
            "<b>Transférer vers l'éditeur</b>\n" +
            "Fusionne les contenus du chat et du terminal\n" +
            "puis les transfère en format Markdown"
        );

        // Classes CSS pour le style bulle
        transfer_button.add_css_class("transfer-button");
        transfer_button.add_css_class("circular");
        transfer_button.add_css_class("suggested-action");

        append(transfer_button);
    }

    private void setup_styling() {
        // Ajout des classes CSS personnalisées
        add_css_class("zone-transfer-widget");

        // Style CSS intégré pour le bouton bulle moderne
        var css_provider = new CssProvider();
        try {
            css_provider.load_from_string("""
                .zone-transfer-widget {
                    margin: 8px;
                    padding: 4px;
                }

                .transfer-button {
                    min-width: 48px;
                    min-height: 48px;
                    border-radius: 24px;
                    background: linear-gradient(135deg,
                        @accent_color_light 0%,
                        @accent_color 50%,
                        @accent_color_dark 100%);
                    border: 2px solid rgba(255, 255, 255, 0.2);
                    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15),
                                0 2px 4px rgba(0, 0, 0, 0.1);
                    transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
                    color: white;
                }

                .transfer-button:hover {
                    transform: translateY(-2px) scale(1.05);
                    box-shadow: 0 8px 20px rgba(0, 0, 0, 0.2),
                                0 4px 8px rgba(0, 0, 0, 0.15);
                    border-color: rgba(255, 255, 255, 0.3);
                }

                .transfer-button:active {
                    transform: translateY(0) scale(0.98);
                    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.2);
                }

                .transfer-button image {
                    font-size: 18px;
                    opacity: 0.95;
                }

                .transfer-button:hover image {
                    opacity: 1.0;
                }

                /* Animation de pulsation pour attirer l'attention */
                @keyframes pulse {
                    0% {
                        box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15),
                                    0 2px 4px rgba(0, 0, 0, 0.1),
                                    0 0 0 0 rgba(255, 255, 255, 0.4);
                    }
                    50% {
                        box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15),
                                    0 2px 4px rgba(0, 0, 0, 0.1),
                                    0 0 0 8px rgba(255, 255, 255, 0.0);
                    }
                    100% {
                        box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15),
                                    0 2px 4px rgba(0, 0, 0, 0.1),
                                    0 0 0 0 rgba(255, 255, 255, 0.0);
                    }
                }

                .transfer-button.pulse {
                    animation: pulse 2s infinite;
                }
            """);

            StyleContext.add_provider_for_display(
                get_display(),
                css_provider,
                STYLE_PROVIDER_PRIORITY_APPLICATION
            );
        } catch (Error e) {
            warning("Erreur lors du chargement du CSS pour ZoneTransferButton: %s", e.message);
        }
    }

    private void connect_signals() {
        // Signal de clic
        transfer_button.clicked.connect(() => {
            // Animation de feedback
            animate_click();
            // Émettre le signal de transfert
            transfer_requested();
        });

        // Gestion du survol pour les effets visuels
        var motion_controller = new EventControllerMotion();
        transfer_button.add_controller(motion_controller);

        motion_controller.enter.connect((x, y) => {
            hover_state = true;
            update_hover_state();
        });

        motion_controller.leave.connect(() => {
            hover_state = false;
            update_hover_state();
        });
    }

    private void update_hover_state() {
        if (hover_state) {
            transfer_button.add_css_class("hover");
        } else {
            transfer_button.remove_css_class("hover");
        }
    }

    private void animate_click() {
        // Animation de clic avec feedback visuel
        transfer_button.add_css_class("active");

        Timeout.add(150, () => {
            transfer_button.remove_css_class("active");
            return false;
        });
    }

    /**
     * Active l'animation de pulsation pour attirer l'attention
     */
    public void start_pulse_animation() {
        transfer_button.add_css_class("pulse");
    }

    /**
     * Désactive l'animation de pulsation
     */
    public void stop_pulse_animation() {
        transfer_button.remove_css_class("pulse");
    }

    /**
     * Définit l'état actif/inactif du bouton
     */
    public void set_sensitive_state(bool sensitive) {
        transfer_button.set_sensitive(sensitive);

        if (!sensitive) {
            transfer_button.add_css_class("disabled");
            transfer_button.set_tooltip_text("Aucun contenu disponible pour le transfert");
        } else {
            transfer_button.remove_css_class("disabled");
            transfer_button.set_tooltip_markup(
                "<b>Transférer vers l'éditeur</b>\n" +
                "Fusionne les contenus du chat et du terminal\n" +
                "puis les transfère en format Markdown"
            );
        }
    }

    /**
     * Met à jour l'icône du bouton selon l'état
     */
    public void set_transfer_state(bool in_progress) {
        if (in_progress) {
            transfer_button.set_icon_name("content-loading-symbolic");
            transfer_button.add_css_class("loading");
            transfer_button.set_sensitive(false);
        } else {
            transfer_button.set_icon_name("document-send-symbolic");
            transfer_button.remove_css_class("loading");
            transfer_button.set_sensitive(true);
        }
    }
}
