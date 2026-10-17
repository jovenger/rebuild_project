# NOTE DE REPRISE — le socle de Scriptorium (état au 16/10/2026, après l'essai V73 c 4)

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
- Lis dans cet ordre : `CLAUDE.md`, `docs\socle\reprise.md` (section 6 ter : où reprendre), `docs\socle\plan_d_action.md`
  (la suite et les règles du 16/10), puis `docs\socle\avancement.md`, `docs\socle\essai_en_jeu.md` et la fiche 14.
- Lance `py -3.13 essais\tout_verifier.py` : il doit finir par « tout passe » (2 330 vérifications au 16/10).
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

## Où on en est (17/10)
- Fait et vérifié : bandeau, registre, coffre, camp, hommes, batailles, Directeur, enceinte, atelier, patrouilles,
  discipline, réglages par fichier, caractère ; fiches 00 à 14.
- Vu en jeu : nos hommes naissent sur nos âmes et notre cerveau, marchent, s'assoient, se couchent, se battent sur
  ordre ; équipement pièce par pièce gardé au rechargement, munitions complétées ; faction « la Compagnie » (amie
  d'Henry, ne réagit pas à ses délits) ; camp fondé devant Henry, une place par homme ; réveil différé de 30 s et
  guetteur du chargement.
- Vu en jeu (16/10, fiches 12 et 15) : un seul comportement long, la « vie du camp » ; les hommes marchent,
  s'assoient face au feu et se couchent par notre propre posture, se lèvent à l'ordre et ne sont plus rassis ; repas à
  midi, corvée à 13 h ; le comportement revient après un rechargement.
- Vu en jeu (16 et 17/10, fiche 15) : l'arbitre des ordres par tenues (V73 b) ; la garde de la tenue ; l'ancre du camp ;
  le factionnaire, face au dehors (V73 d 1) ; la ronde, l'arbre appelant le Lua à chaque point, pauses tirées par le
  socle, tourné vers le dehors à chaque pause (V73 d 2) ; la ronde reprise (accroche « ronde reprise ») et la ronde
  sans pause (V73 d 2 bis) ; le rassemblement en arc, en courant, face au centre, et les 150 m du secours (V73 e).
- Les valeurs de l'arbre (attentes, distances d'arrêt, délais) suivent le catalogue (section « cerveau »), réglables
  en pleine partie.
- Ouvert : l'écran noir intermittent (3 sur 47 chargements, 1 sur 37 depuis les correctifs ; décompte dans la fiche 14,
  à poursuivre à chaque séance).

## La suite (`plan_d_action.md`)
1. L'arbitre (V73 b), la garde de la tenue, l'ancre du camp, le factionnaire (V73 d 1), la ronde (V73 d 2 et 2 bis) et le
   rassemblement (V73 e) sont faits et vus en jeu. Suite : V73 f, suivre Henry (à cheval), puis le gardien des hommes ;
   toujours après relecture de `CARTE_DES_REGLES.md` et de `NOTE_METIERS.md`.
2. Puis les étapes 2 à 8 de la note de JoVenGer ; la bascule seulement sur son ordre.
