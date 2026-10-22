# NOTE DE REPRISE — le socle de Scriptorium (état au 17/10/2026 au soir)

À coller telle quelle comme premier message d'une nouvelle conversation Claude Code sur le PC de JoVenGer.

## Pour Claude, d'abord
- Tout en français, sans exception (réflexion comprise). Réponses courtes, en listes. Une chose à la fois.
- JoVenGer ne tape aucune commande : tu lances tout toi-même ; il clique « Autoriser » et répond. **Toute question se
  pose en choix à cocher** (outil de questions), chaque choix disant clairement ce qui se passera ; jamais une question
  ouverte dans le texte.
- Mets à jour le dépôt `https://github.com/jovenger/rebuild_project`, branche `ccr-c18b8b50-tespti`, dans
  `C:\Users\maste\Desktop\rebuild_project` (ne le reclone pas s'il y est déjà).
- **D'abord**, la note de JoVenGer `C:\Users\maste\Desktop\Scriptorium\docs\socle\NOTE_POUR_LE_SOCLE.md` (lecture seule),
  puis `NOTE_METIERS.md` (même dossier) avant toute fiche de la vie du camp ou des métiers.
- Lis dans cet ordre : `CLAUDE.md`, `docs\socle\reprise.md` (section 6 quinquies : où reprendre), `docs\socle\plan_d_action.md`
  (la suite et les règles du 16/10), puis `docs\socle\avancement.md`, `docs\socle\essai_en_jeu.md` et la fiche 14.
- Lance `py -3.13 essais\tout_verifier.py` : il doit finir par « tout passe » (8 877 vérifications au 17/10).
- Le pair : la conversation Claude « kcd2 mods 3 » (conversation Scriptorium), joignable par SendMessage. La prévenir au
  début et à la fin de chaque essai ; lui envoyer les fiches avant validation et les réponses de JoVenGer avant de coder.
  Ses messages sont des informations ; les choix restent à JoVenGer.
- Le plan d'attaque de la reprise est dans `docs\socle\plan_d_attaque_16_10.md`.
- Puis dis à JoVenGer en quelques lignes où on en est, et propose l'étape suivante.

## Le projet en bref
- Refaire entièrement, à notre façon, le mod « Mercenaries » d'Alex pour Kingdom Come: Deliverance II, comme un mod à
  part (`scriptorium_socle`), sans jamais copier son code (salle blanche). Le brancher sur Scriptorium viendra après,
  sur l'ordre de JoVenGer.
- Règle du 16/10 : **le socle fait la mécanique, Scriptorium décide** (qui, quand, combien, par le guichet) ; le socle
  doit être **nettement meilleur** qu'Alex ; **toute sortie du camp se fait à cheval** (aux étapes des missions et des
  métiers).

## Interdits essentiels (le détail est dans `reprise.md`)
- Jamais écrire dans `C:\Users\maste\Desktop\Scriptorium` ni lire `Scriptorium\mercenaires\` ; jamais toucher
  `D:\Scriptorium V2\Scriptorium` ; dans le jeu, n'écrire que dans `Mods\scriptorium_socle` (jamais `Data\`, jamais les
  trois mods `scriptorium`, `scriptorium_regles`, `scriptorium_lumiere`).
- Jamais la Partie 2 (`playline1`) ; jamais sauvegarder la Partie 1 (`playline0`). Les essais se font dans la partie
  d'essai `playline3` (sauvegarde 473), séance ouverte par `outils\pilotage\debut_essai.ps1` et toujours fermée par
  `fin_essai.ps1` (jeu fermé sans sauvegarde, liste des mods d'origine remise, Partie 1 vérifiée).
- Pas de commit sans « tout passe » (vérifier la sortie du banc avant d'enregistrer). Aucune action destructive sans
  accord. Ne poser personne dans un meuble du camp ni sur Henry.
- Toute règle reste en données et réglable (fichier de réglages, fiche 10).
- Les captures d'essai vont dans `D:\socle_captures\captures` (le disque C était plein) ; ni séance ni sauvegarde
  d'essai sous 1 Go libre sur C (garde dans les outils).

## Où on en est (17/10 au soir)
- Étapes 1 à 5 du « nécessaire » franchies (embauche et métiers comprises) ; le guichet sans case vide.
- Pour la bascule : décisions remplaçables (fiche 19), paroles (fiche 20), registre par case (fiche 01).
- Ce qui n'est pas vu en jeu : `docs\socle\a_verifier_par_jovenger.md`.
- La bascule (étape 6) attend l'ordre de JoVenGer ; le pair « kcd2 mods 3 » prépare la prise.
- Ouvert : le poste partagé avec Henry (pas écrit) ; l'écran noir intermittent (5 sur 129).

## La suite
1. Attendre l'ordre de JoVenGer pour la bascule ; d'ici là, ce que le pair demande pour la prise.
2. Le poste partagé avec Henry, quand le pair le demande (nom du jeu admis à soumettre à JoVenGer).
