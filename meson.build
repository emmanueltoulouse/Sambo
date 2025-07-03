project('Sambo', 'vala', version: '0.1.0',
        license: 'GPL-3.0-or-later',
        default_options: [
            'warning_level=3',
            'debug=true'
        ])

gtk_dep = dependency('gtk4', version: '>=4.1', required: true)
adw_dep = dependency('libadwaita-1', version: '>=1.0', required: true)
gee_dep = dependency('gee-0.8', required: true)
json_dep = dependency('json-glib-1.0', required: true)
gio_dep = dependency('gio-2.0', required: true)
soup_dep = dependency('libsoup-3.0', required: true)

# Import des modules GNOME
gnome = import('gnome')

# Configuration de l'internationalisation
i18n = import('i18n')
gettext_package = meson.project_name().to_lower()

# Définir GETTEXT_PACKAGE pour C et Vala
add_global_arguments('-DGETTEXT_PACKAGE="@0@"'.format(gettext_package), language: 'c')
add_global_arguments('--define=GETTEXT_PACKAGE="@0@"'.format(gettext_package), language: 'vala')

# Intégration de llama.cpp comme sous-projet CMake (temporairement désactivé)
# cmake = import('cmake')
# llama_proj = cmake.subproject('llama', options: cmake.subproject_options())
# llama_dep = llama_proj.dependency('llama')

# Vérifier si l'icône existe dans le répertoire personnel de l'utilisateur
check_home_icon = run_command('sh', '-c', 'test -f ~/com.cabineteto.Sambo.png && echo yes || echo no', check: false).stdout().strip()

if check_home_icon == 'yes'
  # Copier l'icône depuis le répertoire personnel vers le dossier data
  run_command('mkdir', '-p', 'data/icons/hicolor/scalable/apps', check: false)
  run_command('cp', '~/com.cabineteto.Sambo.png', 'data/icons/hicolor/scalable/apps/', check: false)
endif

# Compilation des ressources GResource
resources = gnome.compile_resources(
  'sambo-resources',
  'data/sambo.gresource.xml',
  source_dir: 'data'
)

sources = [
    # Fichier principal de l'application
    'src/Application.vala',
    'src/HeaderBar.vala',
    'src/TextEditor.vala',

    # Modèles
    'src/model/ApplicationModel.vala',
    'src/model/ConfigManager.vala',
    'src/model/EditorModel.vala',
    'src/model/CommunicationModel.vala',
    'src/model/ChatMessage.vala',
    'src/model/ZoneTransferManager.vala',

    # Explorateur - Modèles
    'src/model/ExplorerModel.vala',
    'src/model/explorer/BreadcrumbModel.vala',
    'src/model/explorer/ExplorerTabModel.vala',
    'src/model/explorer/FileItemModel.vala',
    'src/model/explorer/ViewMode.vala',
    'src/model/explorer/IconCache.vala',
    'src/model/explorer/SearchService.vala',
    'src/model/explorer/BookmarksManager.vala',
    'src/model/explorer/HistoryManager.vala',

    # Module pivot et convertisseurs (Phase 1)
    'src/model/document/PivotDocument.vala',
    'src/model/document/DocumentConverter.vala',
    'src/model/document/DocumentConverterManager.vala',
    'src/model/document/PivotDocumentConverter.vala',
    'src/model/document/TextDocumentConverter.vala',



    # Module pivot et convertisseurs (Phase 2 enrichie)
    'src/model/document/MarkdownDocumentConverter.vala',
    'src/model/document/HtmlDocumentConverter.vala',

    # Modèles HuggingFace
    'src/model/huggingface/HuggingFaceAPI.vala',
    'src/model/huggingface/HuggingFaceModel.vala',
    'src/model/huggingface/HuggingFaceFile.vala',

    # Contrôleur
    'src/controller/ApplicationController.vala',

    # Vues principales
    'src/view/MainWindow.vala',
    'src/view/ExplorerView.vala',
    'src/view/EditorView.vala',
    'src/view/CommunicationView.vala',

    # Fenêtres pour l'explorateur
    'src/view/windows/ExplorerWindow.vala',
    'src/view/windows/PreferencesWindow.vala',
    'src/view/windows/TrackingWindow.vala',
    'src/view/windows/HuggingFaceModelsWindow.vala',
    'src/view/windows/HuggingFaceDownloadWindow.vala',

    # Boîtes de dialogue
    'src/view/dialogs/DialogFileComparer.vala',
    'src/view/dialogs/TableEditorDialog.vala',

    # Widgets
    'src/view/widgets/ChatBubbleRow.vala',
    'src/view/widgets/ChatView.vala',
    'src/view/widgets/TerminalView.vala',
    'src/view/widgets/ComparisonView.vala',
    'src/view/widgets/FilePreviewWidget.vala',
    'src/view/widgets/ErrorInfoBar.vala',
    'src/view/widgets/BreadcrumbWidget.vala',
    'src/view/widgets/ExtensionFilterChips.vala',
    'src/view/widgets/WysiwygEditor.vala',
    'src/view/widgets/ZoneTransferButton.vala',

    # Vues supplémentaires à ajouter
    'src/CommandView.vala',
    'src/Sidebar.vala',
]

add_project_arguments(['--target-glib=auto'], language: 'vala')

# Assurez-vous que le compilateur valac puisse trouver les packages
add_project_arguments(['--pkg=gtk4', '--pkg=libadwaita-1', '--pkg=gee-0.8', '--pkg=gio-2.0', '--pkg=libsoup-3.0'], language: 'vala')

# Ajouter le répertoire vapi pour les bindings llama.cpp
add_project_arguments(['--vapidir=' + meson.current_source_dir() + '/vapi'], language: 'vala')

# Dans votre fichier meson.build principal
add_project_arguments(['--disable-warnings'], language: 'vala')

# Dépendance pour la bibliothèque mathématique
math_dep = meson.get_compiler('c').find_library('m', required: false)

executable('Sambo',
  sources: sources + resources,
  dependencies: [gtk_dep, adw_dep, gee_dep, json_dep, gio_dep, soup_dep, math_dep],
  install: true,
  vala_args: ['--Xcc=-lm'] # Temporairement sans llama: '--pkg=llama'
)

# Installation de l'icône
install_data('data/icons/hicolor/scalable/apps/com.cabineteto.Sambo.png',
  install_dir: join_paths(get_option('datadir'), 'icons/hicolor/scalable/apps')
)

# Création et installation du fichier .desktop
conf = configuration_data()
conf.set('ICON', 'com.cabineteto.Sambo')
conf.set('EXEC', 'Sambo')
conf.set('NAME', 'Sambo')

configure_file(
  input: 'data/com.cabineteto.Sambo.desktop.in',
  output: 'com.cabineteto.Sambo.desktop',
  configuration: conf,
  install: true,
  install_dir: join_paths(get_option('datadir'), 'applications')
)

# Installation du schéma GSettings
install_data('data/com.cabineteto.Sambo.gschema.xml',
  install_dir: join_paths(get_option('datadir'), 'glib-2.0/schemas')
)

# Compilation du schéma GSettings (pour les tests locaux)
gnome.compile_schemas(depend_files: 'data/com.cabineteto.Sambo.gschema.xml')

# Configuration pour l'internationalisation
subdir('po')
