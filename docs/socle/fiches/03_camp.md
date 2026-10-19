# Fiche 03 — Le camp : tentes, lits, feux, sièges

- Morceau : 3. Table : `Scriptorium.camp`. Fichier : `socle/pak/Scripts/scriptorium/camp.lua`.
- État : écrit et passé au banc ; vu en jeu (camp debout et orienté comme Henry, feu qui brûle, bancs `Chair`, paillasses `Bed`, reposé à chaque chargement). Validée par JoVenGer le 14/10/2026 : fondé là où se tient Henry ; 4, puis 8, puis 12 hommes ; agrandi sur ordre au Directeur ; bancs et paillasses pour Henry et les hommes, le lit du Directeur à lui seul.

## Ce que le joueur voit
- Un camp dressé autour d'un feu : des sièges, des tentes avec leurs paillasses, la tente du Directeur avec son lit et le coffre du camp.
- Après un chargement, le camp est là, complet, qu'il y ait des hommes ou non.
- « Le camp est dressé. » à la fondation, « Le camp est levé. » quand on le démonte. Le redressement après chargement se fait en silence (journal seulement).

## Règles
- **Le plan est en données, pas dans le code.** `camp.plan` liste les emplacements : nom, sorte (`feu`, `siege`, `tente`, `lit`, `coffre`), position par rapport à l'ancre du camp (mètres : x à droite, y devant), cap (degrés, 0 = devant), niveau (1 à 3).
- **L'ancre.** `fonder(position, cap)` fixe l'ancre du camp (là où se tient Henry, dans le poste d'essai). Chaque emplacement est tourné du cap de l'ancre puis décalé de sa position. Fonder deux fois est refusé : il faut lever le camp d'abord.
- **Niveaux.** Le camp commence au niveau 1 (un feu, quatre sièges, la tente du Directeur, deux tentes, cinq lits, le coffre). `agrandir()` passe au niveau suivant et dresse les emplacements du nouveau niveau : plus de tentes, de lits et de sièges, pour une compagnie qui grossit. Le niveau 3 est le dernier.
- **Objets du jeu de base.** Chaque sorte renvoie à un modèle du jeu (`camp.modeles`), appelé par son chemin, jamais copié. Chemins relevés dans les paks et vérifiés par `outils/verifier_modeles.py`.
- **Dresser.** Pour chaque emplacement du niveau courant qui n'est pas posé, le camp demande au jeu de poser l'objet et garde l'identifiant rendu. Un objet que le jeu refuse de poser est noté au journal ; le camp continue avec les autres.
- **Redresser.** Après un chargement, `redresser()` demande au jeu, pour chaque objet gardé, s'il existe encore ; les manquants sont reposés. Rien d'autre n'est touché. Cela marche sans aucun homme.
- **Lever.** `lever()` retire tous les objets du jeu et oublie l'ancre. Les tentes appartiennent à JoVenGer : le camp garde le propriétaire dans le registre.
- **Places.** Les lits et les sièges sont des places : `reserver(nom, qui)` et `liberer(nom)` ; `places_libres(sorte, pour)` les rend, en écartant celles réservées à quelqu'un d'autre (le lit du Directeur est réservé au Directeur). Les hommes (morceau 4) s'en servent. Une place déjà prise est refusée.
- **Positions.** `position_de(nom)` rend la position et le cap dans le monde d'un emplacement ; `point(x, y, cap)` fait de même pour un point quelconque du plan (postes de garde, lieux d'exercice).
- **Enregistrement.** Après fondation, agrandissement, redressement et levée.

## Le camp devant Henry, pas sous ses pieds (réponse de JoVenGer du 16/10/2026, après V72 c)
- Vu en V72 c : le camp était fondé là où se tient Henry, et Henry restait debout dans le feu central (0,0 m) ; deux
  écrans noirs intermittents, cause non prouvée (fiche 14). Désormais, le centre du camp est posé
  `camp.reglages.fonder_devant` mètres devant Henry (4 par défaut, réglable) : `camp.ancre_devant(position, cap)` le
  calcule, et c'est ce point qu'on donne à `camp.fonder`. `camp.fonder` garde son sens : le centre du camp est le point
  donné. Le guichet de Scriptorium (étape 3) fondera le camp de la même façon.

## Le camp ne suit jamais Henry (JoVenGer, 16/10/2026, transmis par le pair)
- **Ce que JoVenGer a vu** (V73 b 2) : il avait déplacé Henry avant la pose, et le camp est apparu à partir de la
  nouvelle place d'Henry. Ce n'est pas ce qu'il veut. Chez Scriptorium (`camp_selon_le_terrain`, scellé), le camp est
  fondé **une fois**, à un point choisi selon le terrain, puis son ancre (origine et cap) est fixée, gardée, et stable
  aux rechargements. **Le choix du lieu est la règle de Scriptorium : le socle ne s'en mêle pas** (JoVenGer).
- **Vérifié dans le code du socle** (16/10, sans changement) : `camp.fonder` garde l'ancre au registre une seule fois
  (une seconde fondation est refusée) ; au chargement, `camp.redresser` et `camp.relancer` reposent chaque objet depuis
  cette ancre gardée (`camp.dans_le_monde(d.ancre, …)`), jamais depuis Henry. Seule la commande d'essai `essai_camp`
  fonde le camp devant Henry : chaque séance repart de la sauvegarde 473, sans camp, et le fonde là où se tient Henry.
  Ce que JoVenGer a vu vient donc de la façon d'essayer, pas de la repose.
- **Au banc** (`essai_camp.lua`) : fondé, Henry éloigné de 50 m et tourné, la partie relue : chaque objet du niveau 1
  est reposé exactement à sa place d'avant, dans les deux façons de reposer (ce qui manque, ou tout), et le camp n'est
  jamais refondé.
- **Vu en jeu** (16/10, sans changement de code) : camp fondé, Henry éloigné au clavier à 44 m et tourné, sauvegardé
  puis repris : « Camp : redressé, 14 objet(s) reposé(s) », le feu, un siège, une tente et deux lits exactement à leur
  place d'avant, au dixième de mètre ; le camp vu de loin, là où il avait été fondé. **Acquis.**
- À la bascule, le point de fondation viendra de Scriptorium (la fondation, le terrain, l'éditeur) ; « devant Henry »
  ne vaut que pour la commande d'essai.

## Meubles utilisables (validé par JoVenGer le 15/10/2026, questions à cocher)
- **À revoir** (vu en V70) : dans le plan, une paillasse sur deux est à côté de la petite tente, hors de la toile
  (`lit_1a`/`lit_1b` autour de `tente_1`, et de même pour les autres tentes) ; l'homme y dort à découvert.
- **Acquis en jeu** (V66, V68, V69) : un homme s'assoit sur un banc du camp, face au feu, et se couche sur une
  paillasse du camp, à la bonne hauteur. Données : `camp.objets_du_jeu` (propriétés relevées en V65, décalages réglables).
- **Ce que le joueur voit** : au repas et à la veillée, les hommes s'assoient sur les bancs du camp ; la nuit, chacun se
  couche sur SA paillasse, dans SA tente ; le Directeur dans son lit.
- **Comment (acquis en jeu, V62)** : un meuble visible (le modèle du jeu, comme aujourd'hui) et, posé dessus, un objet du
  jeu (`StanceSmartObject`) de la sorte qui convient, un par place. C'est la façon du jeu : sa classe `Chair` relie son
  meuble à un objet « so_chair » à part (`Scripts/Entities/WH/Chair/chair.lua`) ; les meubles du monde sont des modèles,
  et les places des objets à part (V60). L'homme y va et s'y assoit ou s'y couche par le comportement « use » de l'objet.
- **Le socle offre, il ne dispose pas** (règle de Scriptorium) : « rendre ce meuble utilisable » pose les objets du jeu
  sur un meuble et les suit là où il est. La disposition du camp est l'affaire de l'éditeur du camp de Scriptorium ;
  pendant le chantier, `camp.plan` reste la disposition d'essai.
- **Règles en données** (catalogue de `reglages.lua`) : pour chaque modèle de meuble, la sorte de l'objet du jeu (siège
  bas « Chair / Sit_1Place_Bench_Low » pour le banc de rondins ; paillasse « GroundBed », voir question 1), le nombre de
  places et le décalage de chacune (droite, devant, hauteur, cap), réglés à l'essai.
- **Les ordres des hommes** (fiche 04) : « repas » et « veillée » → s'asseoir sur le siège qu'il a réservé, ou debout au
  feu s'il n'y en a plus (règle déjà validée de la fiche 04 ; jamais assis dans le vide) ; « sommeil » et « repos » → se
  coucher sur sa paillasse, à lui seul, libérée à sa mort ou à son départ ; « garde », « exercice », « corvée » → aller au
  point.
- **Places gardées** : les gens du jeu (villageois de passage, brigands d'un raid) cherchent parfois un banc proche
  (`AI/crime/mournOnBench.xml`) ; les sièges et les lits du camp sont aux hommes de la Compagnie et à Henry, dont le lit
  dans sa tente reste à lui seul. Comment l'obtenir du jeu : à chercher et à vérifier en jeu (non vérifié).
- **Choix de JoVenGer (15/10)** :
  1. Paillasse des tentes : la sorte du jeu « Bed_1Place_Tent » (lit de tente), une par homme ; hauteur vérifiée à
     l'image.
  2. Au rechargement : seulement les manquants, après une séance qui vérifie si les meubles reviennent encore blancs.
     Un objet qui a un état (le coffre et son contenu, la porte, le feu allumé) n'est jamais reposé à l'aveugle ; une
     tente que JoVenGer a retirée, ou une tente détruite, n'est jamais remise.
     Vu en jeu (V63, V64) : un objet gardé par la sauvegarde revenait avec le modèle par défaut de sa classe (tentes
     blanches) ; chaque objet du socle est donc posé avec `bSaved_by_game` à false : rien du camp n'est gardé par la
     sauvegarde, et tout est reposé depuis le registre à l'entrée en partie, à l'identique. Conséquence : les WUID des
     sièges et des lits changent à chaque chargement ; la place d'un homme se garde par son nom (lit_1a…), et le WUID
     se relit après chaque repose.
  3. Sièges et lits du camp gardés aux hommes de la Compagnie et à Henry ; le lit d'Henry dans sa tente à lui seul.

## Les lits dans leur tente (16/10/2026, V73 c 12)
- Mesuré en jeu (boîte englobante, repère de chaque modèle) : la tente `tent_small_b` va de (-1,20 ; -1,47) à
  (1,19 ; 1,67) ; le lit `bed_makeshift_a` de (-0,44 ; -1,32) à (0,58 ; 0,98).
- Avant, les 13 lits du plan dépassaient de leur tente : le premier de chaque tente de 0,7 m par l'arrière, le second de
  0,5 m par le côté (un homme couché hors de sa tente en V73 c 6), celui du Directeur de 0,85 m par l'arrière.
- Désormais : deux lits côte à côte dans chaque tente, à -0,60 et 0,46 m de son axe, 0,27 m vers l'avant, même cap
  que la tente (1,06 m entre leurs places, au-dessus de l'écart d'un mètre entre deux personnages) ; le lit du
  Directeur au milieu de la sienne.
- Vu en jeu (V73 c 13) : dans chaque tente, un homme couché dedans, l'autre le long du côté, à moitié dehors.
- **Le quart de tour** (principe transmis par le pair, V73 c 14) : l'objet de posture d'un lit prend son orientation à
  la naissance avec un quart de tour de décalage sur le meuble ; à cap 0, l'homme se couchait en travers. Place du lit
  à cap 90 (`camp.objets_du_jeu.lit`, réglable : `meubles.lit.places.couche.cap`) : vu en jeu, **les trois hommes
  couchés dedans, le long du lit** (les deux de la tente 1, le troisième dans la tente 2). Le lit du Directeur, replacé
  et tourné de même, n'a pas encore été vu occupé.

## Sorts rendus
`fonder`, `agrandir`, `lever`, `reserver`, `liberer` rendent `true`, ou `false` et une raison : `deja_fonde`, `pas_fonde`, `niveau_maximal`, `place_inconnue`, `place_prise`, `place_libre`, `position_invalide`.

## Ce qui est sauvegardé (case `camp`, version 1)
`{ fonde, ancre = { x, y, z, cap }, niveau, proprietaire, objets = { [nom] = { identifiant } }, places = { [nom] = qui } }`.

## Ce que le camp demande au jeu (liaison)
`poser_objet(sorte, modele, position, cap, nom)` → identifiant ou nil ; `retirer_objet(identifiant)` ; `objet_existe(identifiant)` ; `position_du_joueur()` et `cap_du_joueur()` (pour le poste d'essai) ; `journal(texte)`.

## À vérifier en jeu
- L'appel qui pose un objet avec un modèle (`System.SpawnEntity` avec la classe `BasicEntity` et `object_Model`) et celui qui le retire (`System.RemoveEntity`).
- Les chemins des modèles du jeu de base pour la tente, la paillasse, le feu, le banc et le coffre (`camp.modeles`), à relever dans les paks du jeu.
- Que les objets posés sont bien gardés par la sauvegarde du jeu, ou qu'il faut les reposer à chaque chargement (`redresser` couvre les deux cas).
- Que le feu posé brûle, et que les hommes du jeu reconnaissent un lit et un siège posés ainsi (sinon, chercher les objets « intelligents » du jeu).

## Essais au banc (`essais/lua/essai_camp.lua`)
Géométrie (rotation et décalage) ; fondation et positions des objets ; double fondation refusée ; objet refusé par le jeu noté sans bloquer ; agrandissement par niveau et niveau maximal ; redressement ne reposant que les manquants ; levée ; places réservées et libérées ; écriture puis relecture ; plan cohérent (noms uniques, sortes connues, niveaux valides).

## Le camp adopté (la bascule, demande du pair, 19/10/2026)
- `camp.adopter(position, cap, carte)` : la reprise du camp de la partie de JoVenGer. Le camp est fondé à son ancre et
  dans son sens, sur sa carte (sinon celle lue), SANS aucun objet posé : ses tentes, son feu, sa cabane et ses postes
  sont à JoVenGer. `camp.est_adopte()` le dit.
- Un camp adopté ne pose ni ne repose jamais rien du plan (fondation, agrandissement, redressement, entrée en partie) ;
  ses places du plan sont vides (`places_libres` rend une liste vide : aucun banc ni lit du socle) ; l'enceinte ne s'y
  bâtit pas (`camp_adopte`). Les postes de travail rendus fonctionnels par Scriptorium restent posés et reposés. Levé, il
  redevient un camp ordinaire.
- Pour la prise : elle relit l'ancre de l'ancien camp (entités cachées qui survivent au retrait de l'ancien mod) et
  appelle `camp.adopter` si le socle n'a pas de camp. Les lits et sièges viennent de Scriptorium : `camp.place_pour`
  n'accepte qu'une place du plan du socle, donc Scriptorium mène ses hommes à ses propres meubles par ses tâches
  (`hommes.tenir`), et l'interrupteur `un_lit_par_homme` est éteint.
- Non vérifié en jeu (à voir à la répétition de la bascule, sur une copie de sa partie).

## Les décors du camp (la bascule, demande du pair, 19/10/2026)
- `camp.poser_un_decor(nom, modele, position, cap, classe)` : un objet du jeu posé par son modèle à un point du monde,
  gardé au registre du camp, reposé à neuf à l'entrée en partie (un objet posé par script revient sans modèle au
  chargement, V63), retiré par `camp.retirer_un_decor(nom)` ou à la levée du camp. `camp.decors()` les liste.
- « classe » : BasicEntity (un décor) par défaut ; Bed et Chair restent utilisables (les classes des lits et bancs du
  camp, vues en jeu). Toute autre classe est refusée (`classe_invalide`).
- Le coffre d'Henry (classe du jeu AnimStash, Scripts/Entities/WH/Stash) n'y est PAS admis : son contenu tient à
  l'entité ; reposé à neuf à chaque chargement, il serait vidé. Une voie à part, après un essai en jeu.
- Pour la prise : la cabane d'Henry, sa tente et les pièces de l'Aménagement (lit, sièges ; pas le coffre).
- Non vérifié en jeu.

## Les places déclarées par Scriptorium (contrat avec le pair, 19/10/2026, sur demande de JoVenGer)
- Vu sur la sauvegarde de JoVenGer (vérification du 19/10) : sur son camp adopté, aucun homme n'avait de lit la nuit ;
  les 11 lits hauts et les 4 tentes achetés à l'Aménagement de Scriptorium ne servaient à personne (le plan n'a aucun
  meuble sur un camp adopté, et une place ne pouvait être qu'un nom du plan).
- `camp.declarer_les_places(liste)`, liste = `{ { nom = "<nom d'entité du jeu>", sorte = "lit" }, ... }` : toute la
  liste à la fois (Scriptorium ne déclare jamais une liste partielle), refusée au premier élément boiteux (nom vide, nom
  du plan, en double, sorte hors de `camp.sortes_places`). Une liste vide est acceptée. Registre en mémoire seulement
  (`camp.places_declarees`, ordre dans `camp.ordre_des_places_declarees`) ; lecture : `camp.liste_des_places_declarees()`.
- Une place déclarée se lit par son objet du jeu, par son nom (stable ; l'identifiant change à chaque chargement) :
  `objet_du_jeu_de` rend le nom s'il existe, sinon nil ; `position_de` sa position ; `abord_de` à `ecart_d_abord` de
  l'objet, du côté opposé au centre du camp. `sorte_de`, `reserver`, `liberer`, `occupant_de`, `place_pour` marchent
  sans changement. `places_libres` les ajoute après le plan (sur un camp adopté, elles seules) ; `capacite` les compte.
- Règle : une réservation que le registre ignore reste réservée (après un chargement, l'objet revient avec
  l'Aménagement) ; une déclaration qui OMET un nom réservé hors du plan le libère, et l'homme qui l'avait le perd
  (`hommes.lit_retire`, une ligne au journal).
- Limite connue : la règle par défaut `camp.place_pour` range aussi les hommes de garde ; un lit peut rester vide
  pendant leur quart. Sur le camp de JoVenGer, la chaîne des règles de Scriptorium la remplace.
- Essais : `essai_camp.lua` (le contrat), `essai_hommes.lua` (la nuit sur un camp adopté). Non vérifié en jeu (le « use »
  des StanceSmartObject de l'Aménagement, catégorie Bed, devrait marcher comme pour nos lits).
