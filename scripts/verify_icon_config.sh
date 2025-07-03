#!/bin/bash

# Script de vérification de la configuration de l'icône Sambo
echo "=== Vérification de la configuration de l'icône Sambo ==="
echo

# 1. Vérifier la présence du fichier Sambo.png dans le répertoire racine
echo "1. Fichier Sambo.png dans le répertoire racine :"
if [ -f "Sambo.png" ]; then
    echo "   ✅ Présent ($(du -h Sambo.png | cut -f1))"
else
    echo "   ❌ Absent"
fi

# 2. Vérifier la présence de l'icône dans le dossier d'installation
echo "2. Icône dans data/icons/hicolor/scalable/apps/ :"
if [ -f "data/icons/hicolor/scalable/apps/com.cabineteto.Sambo.png" ]; then
    echo "   ✅ Présent ($(du -h data/icons/hicolor/scalable/apps/com.cabineteto.Sambo.png | cut -f1))"
else
    echo "   ❌ Absent"
fi

# 3. Vérifier la configuration dans le fichier .desktop
echo "3. Configuration dans le fichier .desktop :"
if grep -q "Icon=@ICON@" data/com.cabineteto.Sambo.desktop.in; then
    echo "   ✅ Configuration trouvée dans le template"
else
    echo "   ❌ Configuration manquante"
fi

# 4. Vérifier la configuration dans meson.build
echo "4. Configuration dans meson.build :"
if grep -q "conf.set('ICON', 'com.cabineteto.Sambo')" meson.build; then
    echo "   ✅ ICON configuré dans meson.build"
else
    echo "   ❌ ICON non configuré"
fi

if grep -q "install_data('data/icons/hicolor/scalable/apps/com.cabineteto.Sambo.png'" meson.build; then
    echo "   ✅ Installation de l'icône configurée"
else
    echo "   ❌ Installation de l'icône non configurée"
fi

# 5. Vérifier la configuration dans MainWindow.vala
echo "5. Configuration dans la boîte À propos :"
if grep -q 'logo_icon_name = "com.cabineteto.Sambo"' src/view/MainWindow.vala; then
    echo "   ✅ logo_icon_name configuré dans MainWindow.vala"
else
    echo "   ❌ logo_icon_name non configuré"
fi

# 6. Vérifier la présence du README avec l'icône
echo "6. README avec icône :"
if [ -f "README.md" ] && grep -q "![Icône Sambo](Sambo.png)" README.md; then
    echo "   ✅ README créé avec référence à l'icône Sambo.png"
else
    echo "   ❌ README manquant ou sans référence à l'icône"
fi

echo
echo "=== Résumé ==="
echo "L'icône Sambo.png est maintenant configurée pour apparaître :"
echo "• Comme icône d'application (via le fichier .desktop)"
echo "• Dans la boîte À propos (via MainWindow.vala)"
echo "• Dans le README (avec affichage de l'image)"
echo
echo "Pour voir l'icône dans la boîte À propos, lancez l'application et"
echo "allez dans le menu Aide > À propos."
