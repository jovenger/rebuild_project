# NOTE DE REPRISE — le socle de Scriptorium (état au 15/10/2026)

À coller telle quelle comme premier message d'une nouvelle conversation Claude Code sur le PC de JoVenGer.

## Pour Claude, d'abord
- Tout en français, sans exception (réflexion comprise). Réponses courtes, en listes. Une chose à la fois.
- JoVenGer ne tape aucune commande : tu lances tout toi-même ; il clique « Autoriser » et répond. Fais-lui valider les
  choix par **questions à cocher**.
- Mets à jour le dépôt `https://github.com/jovenger/rebuild_project`, branche `ccr-c18b8b50-tespti`, dans
  `C:\Users\maste\Desktop\rebuild_project` (ne le reclone pas s'il y est déjà).
- Lis dans cet ordre : `CLAUDE.md`, `docs\socle\reprise.md` (l'état exact, les interdits, comment mener un essai en jeu),
  `docs\socle\plan_d_action.md` (la suite), puis `docs\socle\avancement.md` et `docs\socle\essai_en_jeu.md`.
- Lance `py -3.13 essais\tout_verifier.py` : il doit finir par « tout passe ».
- Puis dis à JoVenGer en quelques lignes où on en est, et propose l'étape 1 du plan d'action.

## Le projet en bref
- Refaire entièrement, à notre façon, le mod « Mercenaries » d'Alex pour Kingdom Come: Deliverance II, comme un mod à
  part (`scriptorium_socle`), sans jamais copier son code (salle blanche). Le brancher sur Scriptorium viendra après,
  sur l'ordre de JoVenGer.

## Interdits essentiels (le détail est dans `reprise.md`)
- Jamais écrire dans `C:\Users\maste\Desktop\Scriptorium` ni lire `Scriptorium\mercenaires\` ; jamais toucher
  `D:\Scriptorium V2\Scriptorium` ; dans le jeu, n'écrire que dans `Mods\scriptorium_socle` (jamais `Data\`, jamais les
  trois mods `scriptorium`, `scriptorium_regles`, `scriptorium_lumiere`).
- Jamais la Partie 2 (`playline1`) ; les essais se font dans la Partie 1 (`playline0`, sauvegarde 473), **jamais
  sauvegardée**. Changer la liste des mods seulement avec l'accord de JoVenGer juste avant, et la remettre à la fin
  (`outils\pilotage\fin_essai.ps1`).
- Pas de commit sans « tout passe ». Aucune action destructive sans accord. Rien de jaune à l'écran : le bandeau en bas.
- Toute règle reste en données et réglable (fichier de réglages, fiche 10) : le programme Scriptorium doit pouvoir la
  changer plus tard.

## Où on en est
- Fait, validé par JoVenGer et vérifié (1 699 vérifications) : bandeau, registre, coffre, camp, hommes, batailles,
  Directeur (menu en données), enceinte et atelier, patrouilles, discipline, réglages par fichier, caractère de chaque homme ;
  fiches 00 à 11.
- Vu en jeu : camp et enceinte de 20 m debout, feu, bancs et paillasses, coffre et bourse d'Henry, sauvegarde du camp,
  bande qui vient, morts, fins de bataille, butin, corps à piller, réglages changés en pleine partie.
- **Manque** : nos personnages ne bougent pas et ne se battent pas (un personnage né par script n'a pas de
  comportement) ; pas de dialogue du Directeur ni d'écran de la Gestion du camp ; pas d'âmes ni d'apparences à nous ;
  pas de quête de fond ; voix et icônes ; quelques essais en jeu (aube, semaine, patrouille, porte la nuit, V6).

## La suite (`plan_d_action.md`)
1. Le comportement des personnages (priorité) : marcher, s'asseoir, dormir, garder, se battre.
2. Nos âmes et personnages (tables du jeu), faction de la Compagnie.
3. Le dialogue du Directeur et la Gestion du camp à l'écran.
4. La quête de fond « La Compagnie ».
5. Voix et icônes.
6. Les essais en jeu restants.
7. Fin du chantier : contrôle strict, morceaux scellés, langues, bascule sur ordre de JoVenGer.
