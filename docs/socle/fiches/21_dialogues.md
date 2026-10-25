# Fiche 21 — Les dialogues d'Henry avec nos hommes, le colonel et le Directeur

Source : la demande du pair (18/10/2026), projet validé par JoVenGer le 18/10 (« plus courts et plus réels ; une vraie
discussion, avec les bonnes questions et les bons ordres ; pas surchargé »). Les textes sont ceux de Scriptorium
(`Scriptorium\docs\socle\DIALOGUES.md`, lecture seule) ; le socle fait la **mécanique seulement**. Aucun fichier, nom ni
code du mod d'Alex : le principe seul, transmis par le pair (décision de JoVenGer du 15/10). Formes relevées dans les
paks du jeu (lecture seule) : `Quests/Final/Barbora.xml` et ses Level, quêtes et FaderDialog ; le marchandage
(`…/open_world/shop/bribe_haggle_negotiation_vyjednavani_smlouvani_podplaceni/*.xml` et
`Scripts/Systems/KCD1/Negotiation.lua`) ; `Libs/Storm/storm.xml`, `storm.dtd`, `roles/quests/sedmStatecnych.xml` ;
`Libs/Tables/rpg/role.xml`.

## Ce que le joueur voit
- « Parler » sur un de nos hommes, le colonel ou le Directeur ouvre la page de dialogue du jeu, avec son menu.
- Henry choisit une question ; la réponse est dite dans la page (texte seul, sous-titre, sans voix), puis on revient au
  menu. On ne sort que par « Ce sera tout » (règle de JoVenGer du 2/10).
- Un homme : Discutons un peu (Parle-moi de toi / La vie au camp / Des choses à signaler), Parlons de toi (Va te faire
  soigner), J'ai un ordre pour toi, le duel, Ce sera tout.
- Le colonel : comme un homme, plus « Où en sont les hommes ? » (un rapport de trois répliques au plus) et ses quatre
  ordres, proposés seulement à lui.
- Le Directeur : « Comment va le camp ? » (trois répliques au plus), puis ses quatre décisions.

## La mécanique (le principe, prouvé en jeu par Scriptorium aujourd'hui)
1. La question d'Henry appelle notre Lua par l'`ExitScript` de son choix.
2. Le Lua range le **code** de la réponse dans une **variable globale du jeu** (`Variables.SetGlobal`), trois au plus
   (une par place de réplique, la plus importante d'abord) ; 0 : rien à dire à cette place.
3. La décision suivante (`Autoselect`) choisit la réplique par `EntryCondition gvar('…') == code` ; aucune ne convient :
   « Pardon, chef… j'avais la tête ailleurs. » ; puis retour au menu (`EndType="GoTo"`, forme du jeu).
4. Une catégorie peut poser ses variables avant de proposer ses choix : les ordres du colonel n'apparaissent qu'au
   colonel (`gvar('scriptorium_dialogue_colonel') == 1`).
5. Variable globale plutôt que variable de quête (piège mesuré par Scriptorium le 2/10 : des nœuds ajoutés à une quête
   déjà commencée n'y tournent pas).

## Où ça vit
- Notre propre **projet de quêtes** (`Quests/scriptorium_socle.xml`), un fichier par carte (kutnohorsko, trosecko),
  une quête de fond par carte éveillée avec la carte (arête `OnWake` vers son port d'entrée), les FaderDialog
  (`AllowGreeting` et `AllowFarewell` à faux, une `Decision` de priorité « General ») dans la quête.
- Les dialogues tiennent aux personnes **par un rôle** : une table de rôles suffixée et des règles Storm à nous
  (`hasFaction` la Compagnie → le rôle des hommes ; `hasName` l'âme du Directeur → son rôle). C'est alors le jeu qui
  propose « Parler » ; l'enveloppe du socle (fiche 18, 5 b) ne l'ajoute que s'il manque.
- Les arbres sont **écrits par un outil** (`outils/dialogues.py`) depuis une description en données
  (`socle/dialogues/arbres.json` : menus, choix, répliques et leurs codes, textes français) : Scriptorium change les
  mots et les codes sans toucher à la mécanique.
- Le Lua : `liaison.dialogue_choix(arbre, choix, qui)` (appelée par l'`ExitScript`) demande la réponse à la décision
  remplaçable `hommes.reponse_du_dialogue(arbre, choix, id)` (fiche 19 ; par défaut rien : la réplique de repli),
  puis pose les variables.

## Réponses prises d'office (consigne de JoVenGer du 17/10)
- Les répliques sans voix : texte seul (le principe transmis).
- Le texte des répliques dans un fichier de textes à nous (`text_ui_dialog__scriptorium_socle.xml`).
- Une première preuve en jeu sur un arbre réduit (un choix, sa réponse, le retour au menu), puis les arbres entiers.

## Vu en jeu (18/10, premier essai, partie d'essai 473)
- La table des rôles patchée par le jeu (« lines added: 2 ») ; le fichier de textes des dialogues chargé.
- **Le jeu n'offre pas encore son « Parler »** à un homme devant Henry : c'est le secours du socle qui répond.
  Le journal du jeu ne dit rien de Storm ni des quêtes ; aucune fonction Lua ne dit si le rôle a pris. Questions de
  principe posées au pair (le fichier Storm, le sélecteur, le projet, le démarrage sur une partie existante).
- Écarts relevés entre le principe transmis et les fichiers du jeu : le retour au menu s'écrit `EndType="GoTo"`
  (le jeu n'a aucun `EndType="Decision"` sans décision fille) ; `VoiceNamespace` n'existe pas sur un Level (mis
  sur la quête) ; le port d'entrée de la quête est le nôtre (« eveil »).
- Le contrôle d'absence admet à part les lignes de nos quêtes et de Storm identiques mot pour mot aux fichiers du
  jeu de la même famille (13 : en-têtes, `ObjectiveValueTypes`, la tâche « roles », l'en-tête d'un Dialogue,
  `Response Role="HENRY"`) : **validé par JoVenGer le 18/10** (questions à cocher).

## Décisions de JoVenGer (18/10, questions à cocher)
- Les 13 lignes identiques au jeu : admises.
- Le « Parler » du jeu absent : attendre le principe d'Alex par le pair, et essayer sur une partie neuve d'essai.
- L'annonce « une bande approche » sans guetteur : silencieuse (seul un garde qui a vu donne l'alerte à l'écran).
- La bascule : après les dialogues vus en jeu.

## Le dialogue du Directeur vu en jeu (troisième répétition de la bascule, 19/10/2026)
- Sur une copie de la partie de JoVenGer, monde du socle, le Directeur tenu par `directeur.parler` : le dialogue s'ouvre
  (« Oui, chef ? », menu complet), la caméra le filme à ses répliques ; « Comment va le camp ? », « Trouve-nous une
  mission » (sans hommes : « pas en état de partir »), « Donne-moi de l'argent du coffre » et « Mets ça au coffre »
  (la caisse juste au groschen près, aller et retour, relue par le pair), « Que me conseilles-tu ? » puis « On continue
  comme ça », « Des fautes aujourd'hui ? ». Aucune erreur.
- Corrigé ensuite (demande du pair) : sans fautif (réponse « Rien, chef », code 4), le sous-menu « Je pardonne /
  Sanctionne-le » n'est plus proposé : la branche revient au menu (`sans_sous_menu` dans socle/dialogues/arbres.json ;
  contrôlé au banc). Non revu en jeu.

## L'interlocuteur du dialogue (vu sur une copie de la partie de JoVenGer le 21/10, J11)
- Vu : Henry devant Ondřej (l'invite « Ondřej de Sazava : Parler »), mais l'interlocuteur lié par le jeu (`dc[rôle]`)
  était Mikuláš, collé à lui : tous nos hommes portent le même rôle Storm (SCRIPTORIUM_SOCLE_HOMME), et le jeu en lie un
  autre que celui visé. Toute réponse serait partie au mauvais homme.
- Désormais l'interlocuteur est l'homme VISÉ : la liaison note l'homme dont le jeu lit les actions pour l'invite
  (`liaison.noter_le_vise`, dans notre GetActions) ; à l'ouverture du dialogue, s'il a été visé depuis moins de
  `liaison.vise_recent_s` (15 s), c'est lui, gardé pour les choix suivants ; sinon le rôle du jeu. Au journal, quand
  ils diffèrent : « interlocuteur lié = … (visé ; rôle du jeu : …) ».
- Épreuve Lua de la liaison au banc (vérifiée en échec sans) ; non vu en jeu.

## Les lignes du cadre de visée (demande du pair, 21/10, J12 ; règle de JoVenGer du 7/10 et du 8/10)
- En visant un homme parlable, le cadre montre, après « Parler », les lignes du programme Scriptorium : son grade (le
  colonel en premier), puis le moral, la fatigue et la santé en barres. Le socle appelle, après ses actions, la fonction
  de Scriptorium `scriptorium.progression.ligne_du_grade(entité, actions)` si elle existe (`liaison.cadre_de_scriptorium`),
  jamais pour la première action seule, ni pour un homme mort, assommé ou en combat ; Scriptorium décide du contenu. Une
  erreur : au journal, une fois. Vaut pour tout personnage rendu parlable (hommes et personnel mené).
- La note de l'homme visé ne peut plus jeter d'erreur (elle ôtait « Parler » de l'invite, vu au banc sans horloge).
- Épreuve Lua de la liaison au banc (vérifiée en échec sans) ; non vu en jeu.

## « Rentrez tous au camp » (demande du pair, 21/10 ; demande de JoVenGer du 24/09)
- Dans l'arbre « homme », sous « J'ai un ordre pour toi », le choix `rentrez_tous` : Henry « Rentrez tous au camp. »
  (« Tout le monde rentre au camp. ») ; une place de réponse : code 44 « À vos ordres, chef. On rentre tous. », code 45
  « Personne d'autre ne vous suit, chef. » ; puis retour au menu, comme « Rentre au camp ».
- Le choix arrive à `hommes.reponse_du_dialogue("homme", "rentrez_tous", id)`, que Scriptorium remplace : il lâche
  l'escorte de chaque homme qui la tient et rend 44, ou 45 s'il n'y en avait aucun. Sans Scriptorium : aucune réplique.
- Données seulement (`socle/dialogues/arbres.json`, fichiers écrits par `outils/dialogues.py`, à jour au banc) ; non vu
  en jeu.

## Les conditions par nom, les grandes mesures, le camp et la troupe, le renvoi du colonel (25/10, décisions de JoVenGer, contrat du pair)
- **Conditions** : `condition` d'une catégorie ou d'un choix est un nom ou une liste de noms, tous exigés. Les noms :
  colonel, camp_monte, camp_leve, troupe_chez_elle, troupe_appelee, alerte, sans_alerte, mesure
  (`hommes.conditions_du_dialogue_noms`, la même liste que `CONDITIONS` de l'outil, vérifié au banc). Tranchés par la
  décision remplaçable `hommes.conditions_du_dialogue(arbre, id)` → { nom = vrai|faux }, demandée à l'ouverture et à
  chaque choix ; Scriptorium la remplace. Par défaut : colonel (le chef du socle), camp_monte (camp fondé), camp_leve
  (l'inverse), sans_alerte ; le reste faux. Un nom absent vaut faux, un nom inconnu n'est pas posé ; « colonel » rendu
  par la réponse (la forme d'avant) compte encore. La liaison pose une variable globale par nom
  (`scriptorium_dialogue_si_<nom>`, « colonel » garde `scriptorium_dialogue_colonel`), et les noms vrais au journal.
- **Forme** : plusieurs noms joints par « AND », la forme des conditions des quêtes du jeu (Data/Scripts.pak, Quests/ :
  5 256 emplois, par exemple `Port('…') AND !Port('…')` dans dialog_s_benem.xml) ; aucune n'y combine `gvar` : non vu en
  jeu.
- **Directeur** : toutes les catégories d'avant exigent camp_monte (règle de JoVenGer du 9/10 : camp levé, il ne
  propose que « Le camp et la troupe » et « Ce sera tout »). Nouvelles catégories : « les_grandes_mesures »
  [camp_monte] (ce qui est en vigueur aux places 1 et 2, codes 1 à 9 ; alerte, sept mesures, retour à l'ordinaire,
  codes 10 à 13 et 20 à 24) ; « le_camp_et_la_troupe » (lever, monter, appeler tous ou la moitié, renvoyer ; chaque
  réplique ferme la conversation, l'ordre part ensuite).
- **Homme** : « ton_commandement » [colonel] : « Tu es renvoyé » (codes 50 à 52, la conversation fermée) ou « Rien.
  Continue ton service » (53, retour au menu) ; deux pas avant le renvoi. Les effets (départ, rébellion, duel à mort,
  succession) sont à Scriptorium.
- **Taille** : deux places de réponse avant un sous-menu de dix choix donnaient 80 copies du sous-menu (le fichier du
  Directeur passait de 0,5 à 4,6 Mo). Pour une catégorie à plusieurs places, le sous-menu est écrit une fois, sous la
  première branche, et les autres branches y sautent (`GoTo` vers une décision d'une branche voisine, la forme du jeu :
  16 806 emplois dans Data/Scripts.pak Quests/, par exemple albik_o_leku.xml, seq6 vers dec6 écrite sous seq5) : 0,63
  Mo. Les catégories à une place (le conseil, les fautes) ne changent pas.
- Essai Lua (vérifié en échec sans) ; fichiers écrits par l'outil, XML bien formé ; **non vu en jeu**.
