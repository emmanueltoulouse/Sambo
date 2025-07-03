
=========================================================================================================

il faut que la chaine de traitement du texte, prenne en compte l'arrivé d'un nouveau texte. il sera loadé
avec ses tag originaux  puis afficher dans main_text_view avec les enrichissemnt gtk, tous en gardant les teg initiaux. durant l'edition, il pourra etre mofifier et les modification seront affiché en gtk et conservé avec les tah originaus. a la sauvegarde, on sauver le document, avec les tag initiau plus toutes les modification en tag originaux.
pour resumer, tous au long du process( chargement, edition,sauvegarde), je garde les tag au format edition, et a l'affichage, je n'aurais quel les enrichissement Gtk. aucun tag initiaux doive etre vu a l'affichage.
ce process devra applique sur tous les fichies, quelques sois le chemin emprunté pour arrivé au chargement bouton ouvrir, lisste, IA, commande ...
le process devra etre factoriser pour que quelques soit l'origine, il passera pas les meme methode.
le process doit etre assez ouvert pour prendre en compte un coup du markdown ou du HTML, ou bien du CSS.les methode ou bloc devont etre tres proprement et clairement  commenter.
tu va respecter le model MVC.
Tous les codes proposé devront etre précédé du nom du fichier dans lequel on trouvera ce code

========================================================================================================

a la fin de la barre d'icones de main_texte_view, je voudrais que tu mette un separateur, puis les icones pour code,citation et tableau.
au debut de la barre d'icones denat bold, je vodrais que tu mett des icones pour font, couleur de texte et couleur de font. tu mettre la logique pour que ces 3 icones ouvre leurs widget Adw respectif, puis mettre a jours main_text_view.
les valeurs des ses trois icone devront etre sauvegarder dans le .ini avec les dimention de la fenetre. et loader au demmarage de l'application.
les methode ou bloc devont etre tres proprement et clairement  commenter.
tu va respecter le model MVC.
Tous les codes proposé devront etre précédé du nom du fichier dans lequel on trouvera ce code

========================================================================================================

