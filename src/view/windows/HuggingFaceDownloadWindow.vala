/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2025 Your Name <your.email@example.com>
 */

using Gtk;
using Adw;
using Sambo.HuggingFace;

namespace Sambo.View.Windows {

    public class HuggingFaceDownloadWindow : Adw.Window {
        private HuggingFaceModelsWindow parent_window;
        private HuggingFaceModel model;
        private Gee.ArrayList<HuggingFaceFile> files;
        private ApplicationController controller;
        private HuggingFaceAPI api;

        // Interface utilisateur
        private Adw.ToastOverlay toast_overlay;
        private Gtk.Box main_box;
        private Gtk.Label title_label;
        private Gtk.Label info_label;
        private Gtk.ProgressBar overall_progress;
        private Gtk.Label overall_progress_label;
        private Gtk.ListBox files_list;
        private Gtk.Button cancel_button;
        private Gtk.Button close_button;

        // Etat du telechargement
        private bool is_downloading = false;
        private bool is_cancelled = false;
        private int completed_files = 0;
        private int64 downloaded_bytes = 0;
        private int64 total_bytes = 0;
        private Gee.HashMap<string, FileDownloadRow> file_rows;
        
        // Configuration pour le téléchargement parallèle
        private int max_concurrent_downloads = 3; // Limite pour éviter de surcharger le serveur

        public HuggingFaceDownloadWindow(HuggingFaceModelsWindow parent, HuggingFaceModel model,
                                       Gee.ArrayList<HuggingFaceFile> files, ApplicationController controller) {
            this.parent_window = parent;
            this.model = model;
            this.files = files;
            this.controller = controller;
            this.api = new HuggingFaceAPI();
            this.file_rows = new Gee.HashMap<string, FileDownloadRow>();

            // Configuration pour le téléchargement parallèle
            var config = controller.get_config_manager();
            max_concurrent_downloads = config.get_integer("AI", "max_concurrent_downloads", 3);
            
            // S'assurer que la valeur est dans une plage raisonnable
            if (max_concurrent_downloads < 1) max_concurrent_downloads = 1;
            if (max_concurrent_downloads > 6) max_concurrent_downloads = 6;

            // Configurer l'API
            var api_key = config.get_string("AI", "huggingface_token", "");
            if (api_key != null && api_key.length > 0) {
                api.set_api_key(api_key);
            }

            setup_ui();
            calculate_total_size();
            start_download();
        }

        private void setup_ui() {
            this.title = "Telechargement en cours";
            this.default_width = 600;
            this.default_height = 500;
            this.modal = true;
            this.transient_for = parent_window;

            // Toast overlay
            toast_overlay = new Adw.ToastOverlay();
            this.content = toast_overlay;

            // Contenu principal
            main_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
            toast_overlay.child = main_box;

            // Header bar
            var header_bar = new Adw.HeaderBar();
            header_bar.title_widget = new Adw.WindowTitle("Telechargement", model.id);
            main_box.append(header_bar);

            // Contenu
            var content_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 24);
            content_box.margin_top = 24;
            content_box.margin_bottom = 24;
            content_box.margin_start = 24;
            content_box.margin_end = 24;

            // Titre et info
            title_label = new Gtk.Label(@"Telechargement du modele $(model.id)");
            title_label.add_css_class("title-2");
            title_label.halign = Gtk.Align.START;
            content_box.append(title_label);

            info_label = new Gtk.Label(@"Preparation du telechargement de $(files.size) fichiers...");
            info_label.add_css_class("dim-label");
            info_label.halign = Gtk.Align.START;
            content_box.append(info_label);

            // Barre de progression globale
            var progress_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 6);

            overall_progress = new Gtk.ProgressBar();
            overall_progress.show_text = true;
            overall_progress.text = "0%";

            overall_progress_label = new Gtk.Label("0 / 0 octets");
            overall_progress_label.add_css_class("caption");
            overall_progress_label.halign = Gtk.Align.CENTER;

            progress_box.append(overall_progress);
            progress_box.append(overall_progress_label);
            content_box.append(progress_box);

            // Liste des fichiers avec leur progression
            var files_label = new Gtk.Label("Progression des fichiers");
            files_label.add_css_class("title-4");
            files_label.halign = Gtk.Align.START;
            content_box.append(files_label);

            var files_scroll = new Gtk.ScrolledWindow();
            files_scroll.max_content_height = 200;
            files_scroll.propagate_natural_height = true;
            files_scroll.vexpand = true;

            files_list = new Gtk.ListBox();
            files_list.add_css_class("boxed-list");
            files_list.set_selection_mode(Gtk.SelectionMode.NONE);
            files_scroll.child = files_list;

            content_box.append(files_scroll);

            main_box.append(content_box);

            // Barre de boutons
            var button_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 12);
            button_box.halign = Gtk.Align.CENTER;
            button_box.margin_bottom = 24;

            cancel_button = new Gtk.Button.with_label("Annuler");
            cancel_button.add_css_class("destructive-action");
            cancel_button.clicked.connect(cancel_download);

            close_button = new Gtk.Button.with_label("Fermer");
            close_button.add_css_class("suggested-action");
            close_button.clicked.connect(on_close_button_clicked);
            close_button.visible = false;

            button_box.append(cancel_button);
            button_box.append(close_button);
            main_box.append(button_box);

            // Créer les lignes de fichiers
            create_file_rows();
        }

        private void calculate_total_size() {
            total_bytes = 0;
            foreach (var file in files) {
                total_bytes += file.size;
            }
        }

        private void create_file_rows() {
            foreach (var file in files) {
                var row = new FileDownloadRow(file);
                file_rows.set(file.filename, row);
                files_list.append(row);
            }
        }

        private void start_download() {
            is_downloading = true;
            is_cancelled = false;

            download_files_async.begin((obj, res) => {
                bool success = download_files_async.end(res);

                is_downloading = false;

                if (is_cancelled) {
                    show_toast("Telechargement annule");
                    this.close();
                } else if (success) {
                    show_completion_success();
                } else {
                    show_completion_error();
                }
            });
        }

        private async bool download_files_async() {
            var settings = controller.get_config_manager();
            var models_dir = settings.get_string("AI", "models_directory", "");

            if (models_dir == null || models_dir.length == 0) {
                // Pas de répertoire configuré, utiliser le répertoire par défaut mais l'informer
                models_dir = Path.build_filename(Environment.get_home_dir(), ".local", "share", "sambo", "models");
                stdout.printf("[INFO] Utilisation du répertoire par défaut: %s\n", models_dir);
            }

            var model_dir = Path.build_filename(models_dir, model.id);

            // Créer le répertoire du modèle
            try {
                var dir_file = File.new_for_path(model_dir);
                if (!dir_file.query_exists()) {
                    dir_file.make_directory_with_parents();
                }
            } catch (Error e) {
                warning("Erreur lors de la création du répertoire: %s", e.message);
                return false;
            }

            completed_files = 0;
            downloaded_bytes = 0;

            // Téléchargement parallèle avec limitation de concurrence
            return yield download_files_parallel(model_dir);
        }

        /**
         * Télécharge les fichiers en parallèle avec une limite de concurrence
         */
        private async bool download_files_parallel(string model_dir) {
            var active_downloads = new Gee.ArrayList<DownloadTask>();
            var pending_files = new Gee.ArrayList<HuggingFaceFile>();
            bool has_error = false;

            // Initialiser la liste des fichiers en attente
            foreach (var file in files) {
                pending_files.add(file);
            }

            stdout.printf("[INFO] Démarrage du téléchargement parallèle: %d fichiers, max %d simultanés\n", 
                         files.size, max_concurrent_downloads);

            // Boucle principale de téléchargement
            while ((pending_files.size > 0 || active_downloads.size > 0) && !has_error && !is_cancelled) {
                
                // Démarrer de nouveaux téléchargements si possible
                while (pending_files.size > 0 && active_downloads.size < max_concurrent_downloads && !has_error) {
                    var file = pending_files.remove_at(0);
                    var task = new DownloadTask(file, model_dir, this);
                    active_downloads.add(task);

                    // Démarrer le téléchargement
                    task.start_download.begin();

                    // Mettre à jour l'UI
                    Idle.add(() => {
                        update_file_status(file.filename, "Telechargement...", 0.0);
                        return false;
                    });
                }

                // Vérifier les téléchargements terminés
                var completed_tasks = new Gee.ArrayList<DownloadTask>();
                foreach (var task in active_downloads) {
                    if (task.is_completed) {
                        completed_tasks.add(task);
                        
                        if (task.is_successful) {
                            completed_files++;
                            downloaded_bytes += task.file.size;
                            
                            Idle.add(() => {
                                update_file_status(task.file.filename, "Terminé", 1.0);
                                update_overall_progress();
                                return false;
                            });
                        } else {
                            has_error = true;
                            Idle.add(() => {
                                update_file_status(task.file.filename, "Erreur de téléchargement", 0.0);
                                return false;
                            });
                        }
                    }
                }

                // Retirer les tâches terminées
                foreach (var task in completed_tasks) {
                    active_downloads.remove(task);
                }

                // Attendre un peu avant de vérifier à nouveau
                yield wait_async(50); // 50ms pour une réactivité élevée
            }

            return !has_error && completed_files == files.size;
        }

        /**
         * Fonction utilitaire pour attendre de manière asynchrone
         */
        private async void wait_async(int milliseconds) {
            Timeout.add(milliseconds, () => {
                wait_async.callback();
                return false;
            });
            yield;
        }

        /**
         * Télécharge un fichier individuel avec suivi de progression
         */
        public async bool download_single_file(HuggingFaceFile file, string model_dir) throws Error {
            var file_path = Path.build_filename(model_dir, file.filename);

            // Créer les répertoires parents si nécessaire
            var parent_dir = Path.get_dirname(file_path);
            var parent_file = File.new_for_path(parent_dir);
            if (!parent_file.query_exists()) {
                parent_file.make_directory_with_parents();
            }

            // Variables pour le suivi de progression
            var start_time = get_monotonic_time();
            var last_update_time = start_time;

            // Callback de progression
            HuggingFace.ProgressCallback progress_callback = (progress, downloaded_bytes, total_bytes, speed, eta_seconds) => {
                var current_time = get_monotonic_time();

                // Fréquence de mise à jour adaptative selon la taille du fichier
                int64 update_interval;
                if (file.size > 1024 * 1024 * 1024) { // > 1GB - 10 fois par seconde pour plus de fluidité
                    update_interval = 100000; // 100ms
                } else if (file.size > 100 * 1024 * 1024) { // > 100MB - 20 fois par seconde
                    update_interval = 50000; // 50ms
                } else { // Petits fichiers - 10 fois par seconde pour éviter le spam
                    update_interval = 100000; // 100ms
                }

                if (current_time - last_update_time > update_interval) {
                    last_update_time = current_time;

                    Idle.add(() => {
                        var row = file_rows.get(file.filename);
                        if (row != null) {
                            row.update_progress_details(progress, downloaded_bytes, total_bytes, speed, eta_seconds);
                        }

                        // Mettre à jour aussi la progression globale
                        update_overall_progress_with_bytes(downloaded_bytes, total_bytes);
                        return false;
                    });
                }
            };

            // Telecharger le fichier avec callback de progression
            yield api.download_file_async(model.id, file.filename, file_path, progress_callback);

            return true;
        }

        private void update_file_status(string filename, string status, double progress) {
            var row = file_rows.get(filename);
            if (row != null) {
                row.update_status(status, progress);
            }
        }

        private void update_overall_progress() {
            double progress = completed_files > 0 ? (double)completed_files / (double)files.size : 0.0;
            overall_progress.fraction = progress;

            // Formatage du pourcentage avec précision adaptative
            if (total_bytes > 1024 * 1024 * 1024) { // > 1GB
                overall_progress.text = @"$(progress * 100.0)%".printf("%.2f", progress * 100.0);
            } else if (total_bytes > 100 * 1024 * 1024) { // > 100MB
                overall_progress.text = @"$(progress * 100.0)%".printf("%.1f", progress * 100.0);
            } else {
                overall_progress.text = @"$(Math.round(progress * 100.0))%";
            }

            var downloaded_str = format_size(downloaded_bytes);
            var total_str = format_size(total_bytes);
            overall_progress_label.label = @"$(downloaded_str) / $(total_str)";

            info_label.label = @"$(completed_files) / $(files.size) fichiers telecharges";
        }

        private void update_overall_progress_with_bytes(int64 current_file_downloaded, int64 current_file_total) {
            // Calculer les octets téléchargés en incluant le fichier actuel
            int64 total_downloaded = downloaded_bytes + current_file_downloaded;

            double progress = total_bytes > 0 ? (double)total_downloaded / (double)total_bytes : 0.0;
            overall_progress.fraction = progress;

            // Formatage du pourcentage avec précision adaptative selon la taille totale
            string progress_text;
            if (total_bytes > 5 * 1024 * 1024 * 1024) { // > 5GB - précision au centième
                progress_text = "%.2f%%".printf(progress * 100.0);
            } else if (total_bytes > 1024 * 1024 * 1024) { // > 1GB - précision au dixième
                progress_text = "%.1f%%".printf(progress * 100.0);
            } else if (total_bytes > 100 * 1024 * 1024) { // > 100MB - précision au dixième
                progress_text = "%.1f%%".printf(progress * 100.0);
            } else { // Petits téléchargements - pourcentage entier
                progress_text = "%d%%".printf((int)Math.round(progress * 100.0));
            }
            overall_progress.text = progress_text;

            var downloaded_str = format_size(total_downloaded);
            var total_str = format_size(total_bytes);
            overall_progress_label.label = @"$(downloaded_str) / $(total_str)";
        }

        private string format_size(int64 size) {
            if (size < 1024) return @"$(size) B";
            if (size < 1024 * 1024) return @"$((size / 1024)) KB";
            if (size < 1024 * 1024 * 1024) return @"$((size / (1024 * 1024))) MB";
            return @"$((size / (1024 * 1024 * 1024))) GB";
        }

        private void cancel_download() {
            is_cancelled = true;
            cancel_button.sensitive = false;
            info_label.label = "Annulation en cours...";
        }

        private void show_completion_success() {
            title_label.label = "Telechargement termine";
            info_label.label = @"$(files.size) fichiers telecharges avec succes";

            cancel_button.visible = false;
            close_button.visible = true;

            // Afficher un toast de succes
            parent_window.show_success(@"Modele $(model.id) telecharge avec succes");
        }

        private void show_completion_error() {
            title_label.label = "Erreur de telechargement";
            info_label.label = "Une erreur est survenue pendant le telechargement";

            cancel_button.visible = false;
            close_button.visible = true;
        }

        private void show_toast(string message) {
            stdout.printf("[TRACE] HuggingFaceDownloadWindow TOAST: %s\n", message);
            var toast = new Adw.Toast(message);
            toast.timeout = 3;
            toast_overlay.add_toast(toast);
        }

        /**
         * Callback pour fermer la fenêtre (remplace lambda close_button.clicked)
         */
        private void on_close_button_clicked() {
            this.close();
        }
    }

    /**
     * Classe pour gérer une tâche de téléchargement individuelle
     */
    private class DownloadTask : Object {
        public HuggingFaceFile file { get; private set; }
        public string model_dir { get; private set; }
        public bool is_completed { get; private set; default = false; }
        public bool is_successful { get; private set; default = false; }
        
        private weak HuggingFaceDownloadWindow window;

        public DownloadTask(HuggingFaceFile file, string model_dir, HuggingFaceDownloadWindow window) {
            this.file = file;
            this.model_dir = model_dir;
            this.window = window;
        }

        public async void start_download() {
            try {
                is_successful = yield window.download_single_file(file, model_dir);
            } catch (Error e) {
                warning("Erreur lors du téléchargement de %s: %s", file.filename, e.message);
                is_successful = false;
            }
            is_completed = true;
        }
    }

    private class FileDownloadRow : Gtk.ListBoxRow {
        private HuggingFaceFile file;
        private Gtk.Label name_label;
        private Gtk.Label status_label;
        private Gtk.Label details_label;
        private Gtk.ProgressBar progress_bar;

        public FileDownloadRow(HuggingFaceFile file) {
            this.file = file;
            this.selectable = false;
            setup_ui();
        }

        private void setup_ui() {
            var box = new Gtk.Box(Gtk.Orientation.VERTICAL, 6);
            box.margin_top = 6;
            box.margin_bottom = 6;
            box.margin_start = 12;
            box.margin_end = 12;

            var header_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 12);

            name_label = new Gtk.Label(file.filename);
            name_label.halign = Gtk.Align.START;
            name_label.hexpand = true;
            name_label.ellipsize = Pango.EllipsizeMode.MIDDLE;

            status_label = new Gtk.Label("En attente");
            status_label.add_css_class("dim-label");
            status_label.add_css_class("caption");

            header_box.append(name_label);
            header_box.append(status_label);

            progress_bar = new Gtk.ProgressBar();
            progress_bar.fraction = 0.0;
            progress_bar.show_text = true;
            progress_bar.text = "0.00%";

            // Label pour les détails (vitesse, ETA, taille)
            details_label = new Gtk.Label("");
            details_label.add_css_class("dim-label");
            details_label.add_css_class("caption");
            details_label.halign = Gtk.Align.START;

            box.append(header_box);
            box.append(progress_bar);
            box.append(details_label);

            this.child = box;
        }

        public void update_status(string status, double progress) {
            status_label.label = status;
            progress_bar.fraction = progress;

            // Formatage du pourcentage avec précision adaptative selon la taille du fichier
            string progress_text;
            if (file.size > 1024 * 1024 * 1024) { // Fichiers > 1GB - précision au centième
                progress_text = "%.2f%%".printf(progress * 100.0);
            } else if (file.size > 100 * 1024 * 1024) { // Fichiers > 100MB - précision au dixième
                progress_text = "%.1f%%".printf(progress * 100.0);
            } else if (file.size > 10 * 1024 * 1024) { // Fichiers > 10MB - précision au dixième
                progress_text = "%.1f%%".printf(progress * 100.0);
            } else { // Petits fichiers - pourcentage entier
                progress_text = "%d%%".printf((int)Math.round(progress * 100.0));
            }
            progress_bar.text = progress_text;
        }

        public void update_progress_details(double progress, int64 downloaded_bytes, int64 total_bytes,
                                          double speed, double eta_seconds) {
            status_label.label = "Téléchargement...";
            progress_bar.fraction = progress;

            // Formatage du pourcentage avec précision adaptative selon la taille du fichier
            string progress_text;
            if (file.size > 1024 * 1024 * 1024) { // Fichiers > 1GB - précision au centième
                progress_text = "%.2f%%".printf(progress * 100.0);
            } else if (file.size > 100 * 1024 * 1024) { // Fichiers > 100MB - précision au dixième
                progress_text = "%.1f%%".printf(progress * 100.0);
            } else if (file.size > 10 * 1024 * 1024) { // Fichiers > 10MB - précision au dixième
                progress_text = "%.1f%%".printf(progress * 100.0);
            } else { // Petits fichiers - pourcentage entier
                progress_text = "%d%%".printf((int)Math.round(progress * 100.0));
            }
            progress_bar.text = progress_text;

            // Formatage des détails avec vitesse et ETA
            var downloaded_str = format_size(downloaded_bytes);
            var total_str = format_size(total_bytes);
            var speed_str = format_speed(speed);
            var eta_str = format_time(eta_seconds);

            details_label.label = @"$(downloaded_str) / $(total_str) • $(speed_str) • ETA: $(eta_str)";
        }

        private string format_size(int64 size) {
            if (size < 1024) return @"$(size) B";
            if (size < 1024 * 1024) return @"$((size / 1024)) KB";
            if (size < 1024 * 1024 * 1024) return @"$((size / (1024 * 1024))) MB";
            return @"$((size / (1024 * 1024 * 1024))) GB";
        }

        private string format_speed(double bytes_per_second) {
            if (bytes_per_second < 1024) return @"$((int)bytes_per_second) B/s";
            if (bytes_per_second < 1024 * 1024) return @"$((int)(bytes_per_second / 1024)) KB/s";
            if (bytes_per_second < 1024 * 1024 * 1024) return @"$((int)(bytes_per_second / (1024 * 1024))) MB/s";
            return @"%.1f GB/s".printf(bytes_per_second / (1024 * 1024 * 1024));
        }

        private string format_time(double seconds) {
            if (seconds < 60) return @"$((int)seconds)s";
            if (seconds < 3600) return @"$((int)(seconds / 60))m $((int)(seconds % 60))s";
            return @"$((int)(seconds / 3600))h $((int)((seconds % 3600) / 60))m";
        }
    }
}
