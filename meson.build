project('Sambo', 'vala', 'c', 'cpp',
        version: '0.1.0',
        license: 'GPL-3.0-or-later',
        default_options: [
            'warning_level=3',
            'debug=true'
        ])

# Import des modules requis au début
gnome = import('gnome')
i18n = import('i18n')
cmake = import('cmake')
fs = import('fs')

# Configuration de l'internationalisation
gettext_package = meson.project_name().to_lower()

# Définir GETTEXT_PACKAGE pour C et Vala AVANT toute cible
add_global_arguments('-DGETTEXT_PACKAGE="@0@"'.format(gettext_package), language: 'c')
add_global_arguments('--define=GETTEXT_PACKAGE="@0@"'.format(gettext_package), language: 'vala')

# Dépendances de base
gtk_dep = dependency('gtk4', version: '>=4.1', required: true)
adw_dep = dependency('libadwaita-1', version: '>=1.0', required: true)
gee_dep = dependency('gee-0.8', required: true)
json_dep = dependency('json-glib-1.0', required: true)
gio_dep = dependency('gio-2.0', required: true)
soup_dep = dependency('libsoup-3.0', required: true)

# Détection précoce de llama.cpp et définition des flags globaux
have_llama_cpp = false

# Vérifier si le sous-projet llama existe
if fs.is_dir('subprojects/llama')
  message('Tentative de chargement de llama.cpp depuis subprojects/')
  have_llama_cpp = true
else
  # Essayer de trouver llama.cpp installé dans le système
  if meson.get_compiler('c').find_library('llama',
     dirs: ['/usr/local/lib', '/usr/lib'],
     required: false).found()
    have_llama_cpp = true
  elif meson.get_compiler('c').has_header('llama.h',
       args: ['-I/usr/local/include'])
    have_llama_cpp = true
  endif
endif

# Définir HAVE_LLAMA_CPP maintenant, avant toute autre cible
if have_llama_cpp
  add_global_arguments('-DHAVE_LLAMA_CPP=1', language: 'c')
  add_global_arguments('-DHAVE_LLAMA_CPP=1', language: 'cpp')
  message('HAVE_LLAMA_CPP défini - mode llama.cpp réel activé')
else
  message('Mode simulation activé - llama.cpp non disponible')
endif

# Maintenant charger les dépendances llama.cpp
llama_dep = dependency('', required: false)  # Initialisation
ggml_dep = dependency('', required: false)   # Initialisation

# Vérifier si le sous-projet llama existe et le charger
if fs.is_dir('subprojects/llama')
  # Charger le sous-projet cmake
  llama_subproject = cmake.subproject('llama')

  # Essayer de récupérer les dépendances du sous-projet
  if llama_subproject.found()
    llama_dep = llama_subproject.dependency('llama')
    ggml_dep = llama_subproject.dependency('ggml')

    # Si les dépendances du sous-projet ne sont pas trouvées, les créer manuellement
    if not llama_dep.found()
      llama_dep = declare_dependency(
        link_args: ['-L' + meson.current_build_dir() + '/subprojects/llama', '-lllama'],
        compile_args: ['-I' + meson.current_source_dir() + '/subprojects/llama/include']
      )
      message('llama.cpp configuré manuellement depuis subprojects/')
    endif

    if not ggml_dep.found()
      ggml_dep = declare_dependency(
        link_args: ['-L' + meson.current_build_dir() + '/subprojects/llama', '-lggml'],
        compile_args: ['-I' + meson.current_source_dir() + '/subprojects/llama/ggml/include']
      )
      message('ggml configuré manuellement depuis subprojects/')
    endif

    message('llama.cpp et ggml chargés avec succès depuis subprojects/')
  endif
endif

# Si le sous-projet a échoué, essayer find_library
if not llama_dep.found()
  llama_dep = meson.get_compiler('c').find_library('llama',
    dirs: ['/usr/local/lib', '/usr/lib'],
    required: false
  )
  if llama_dep.found()
    ggml_dep = meson.get_compiler('c').find_library('ggml',
      dirs: ['/usr/local/lib', '/usr/lib'],
      required: false
    )
  endif
endif

# Si llama.cpp n'est pas trouvé via find_library, essayer de déclarer manuellement
if not llama_dep.found()
  warning('llama.cpp non trouvé via find_library, tentative manuelle...')
  # Déclaration manuelle si installé dans /usr/local
  if meson.get_compiler('c').has_header('llama.h',
     args: ['-I/usr/local/include'])
    llama_dep = declare_dependency(
      link_args: ['-L/usr/local/lib', '-lllama'],
      compile_args: ['-I/usr/local/include']
    )
    ggml_dep = declare_dependency(
      link_args: ['-L/usr/local/lib', '-lggml'],
      compile_args: ['-I/usr/local/include']
    )
    message('llama.cpp et ggml trouvés dans /usr/local')
  else
    warning('llama.cpp non trouvé, mode simulation activé')
    llama_dep = dependency('', required: false)  # Dépendance vide
    ggml_dep = dependency('', required: false)   # Dépendance vide
  endif
endif

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

    # Wrapper C++ pour llama.cpp
    'src/sambo_llama_wrapper.cpp',

    # Modèles
    'src/model/ApplicationModel.vala',
    'src/model/ConfigManager.vala',
    'src/model/InferenceProfile.vala',
    'src/model/ModelManager.vala',
    'src/model/EditorModel.vala',
    'src/model/CommunicationModel.vala',
    'src/model/ChatMessage.vala',
    'src/model/ZoneTransferManager.vala',
    'src/model/ExplorerModel.vala',
    'src/model/explorer/BreadcrumbModel.vala',
    'src/model/explorer/ExplorerTabModel.vala',
    'src/model/explorer/FileItemModel.vala',
    'src/model/explorer/ViewMode.vala',
    'src/model/explorer/IconCache.vala',
    'src/model/explorer/SearchService.vala',
    'src/model/explorer/BookmarksManager.vala',
    'src/model/explorer/HistoryManager.vala',
    'src/model/document/PivotDocument.vala',
    'src/model/document/DocumentConverter.vala',
    'src/model/document/DocumentConverterManager.vala',
    'src/model/document/PivotDocumentConverter.vala',
    'src/model/document/TextDocumentConverter.vala',
    'src/model/document/MarkdownDocumentConverter.vala',
    'src/model/document/HtmlDocumentConverter.vala',
    'src/model/huggingface/HuggingFaceAPI.vala',
    'src/model/huggingface/HuggingFaceModel.vala',
    'src/model/huggingface/HuggingFaceFile.vala',

    # Contrôleurs
    'src/controller/ApplicationController.vala',

    # Vues principales
    'src/view/MainWindow.vala',
    'src/view/ExplorerView.vala',
    'src/view/EditorView.vala',
    'src/view/CommunicationView.vala',

    # Fenêtres
    'src/view/windows/ExplorerWindow.vala',
    'src/view/windows/PreferencesWindow.vala',
    'src/view/windows/TrackingWindow.vala',
    'src/view/windows/HuggingFaceModelsWindow.vala',
    'src/view/windows/HuggingFaceDownloadWindow.vala',

    # Dialogues
    'src/view/dialogs/DialogFileComparer.vala',
    'src/view/dialogs/TableEditorDialog.vala',

    # Widgets
    'src/view/widgets/ChatBubbleRow.vala',
    'src/view/widgets/ChatView.vala',
    'src/view/widgets/ProfileManager.vala',
    'src/view/widgets/ProfileEditorDialog.vala',
    'src/view/widgets/ProfileCreationWizard.vala',
    'src/view/widgets/TerminalView.vala',
    'src/view/widgets/ComparisonView.vala',
    'src/view/widgets/FilePreviewWidget.vala',
    'src/view/widgets/ErrorInfoBar.vala',
    'src/view/widgets/BreadcrumbWidget.vala',
    'src/view/widgets/ExtensionFilterChips.vala',
    'src/view/widgets/WysiwygEditor.vala',
    'src/view/widgets/ZoneTransferButton.vala',

    # CommandView et Sidebar
    'src/CommandView.vala',
    'src/Sidebar.vala',
]

dependencies = [
    gtk_dep,
    adw_dep,
    gee_dep,
    json_dep,
    gio_dep,
    soup_dep,
    llama_dep,
    ggml_dep,
]

# Configuration des schemas GSettings
# Créer le répertoire de destination s'il n'existe pas
schema_output_dir = join_paths(get_option('datadir'), 'glib-2.0', 'schemas')
install_data('data/com.cabineteto.Sambo.gschema.xml',
             install_dir: schema_output_dir)

# Application exécutable principal
executable('Sambo',
    sources, resources,
    dependencies: dependencies,
    vala_args: [
        '--pkg=libsoup-3.0',
        '--pkg=gio-2.0',
        '--pkg=json-glib-1.0',
        '--pkg=gee-0.8',
        '--pkg=libadwaita-1',
        '--pkg=gtk4',
        '--vapidir=' + meson.current_source_dir() + '/vapi',
        '--pkg=llama',
        '--color=always'
    ],
    c_args: ['-lm'],
    include_directories: include_directories('src'),
    install: true
)

# Fichier de bureau (.desktop)
configure_file(
    input: 'data/com.cabineteto.Sambo.desktop.in',
    output: 'com.cabineteto.Sambo.desktop',
    configuration: {
        'NAME': 'Sambo',
        'EXEC': join_paths(get_option('prefix'), get_option('bindir'), 'Sambo'),
        'ICON': 'com.cabineteto.Sambo',
    },
    install: true,
    install_dir: join_paths(get_option('datadir'), 'applications')
)

# Installation de l'icône
install_data(join_paths('data', 'icons', 'hicolor', 'scalable', 'apps', 'com.cabineteto.Sambo.png'),
             install_dir: join_paths(get_option('datadir'), 'icons', 'hicolor', 'scalable', 'apps'))

# Scripts utiles
install_data('scripts/install_icon_and_desktop.sh',
             install_dir: join_paths(get_option('datadir'), 'sambo', 'scripts'),
             install_mode: 'rwxr-xr-x')

# Tests et validation
run_target('post-install',
           command: ['scripts/install_icon_and_desktop.sh'])

# Cible pour installer l'icône système (nécessite sudo)
run_target('install-system-icon',
           command: ['sudo', 'scripts/install_icon_and_desktop.sh'])

# Cible personnalisée pour traiter les icons
run_target('update-icon-cache',
           command: [find_program('gtk4-update-icon-cache'), '-f', '-t',
                     join_paths(get_option('prefix'), get_option('datadir'), 'icons', 'hicolor')])

# Internationalisation (optionnel)
# subdir('po')

# Documentation (optionnel)
# subdir('docs')
