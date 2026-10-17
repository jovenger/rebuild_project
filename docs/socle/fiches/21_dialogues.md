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

## Non vérifié en jeu
Tout, à ce jour (fiche écrite le 18/10).
