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

## Meubles utilisables (validé par JoVenGer le 15/10/2026, questions à cocher)
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
  3. Sièges et lits du camp gardés aux hommes de la Compagnie et à Henry ; le lit d'Henry dans sa tente à lui seul.

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
