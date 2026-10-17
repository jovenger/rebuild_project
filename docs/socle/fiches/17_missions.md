# Fiche 17 — Les missions (étape 4 du nécessaire)

Sources : la note de JoVenGer (`Scriptorium/docs/socle/NOTE_POUR_LE_SOCLE.md`, partie 6, lecture seule), la liste du
pair du 17/10 (ce que Scriptorium attend), la règle scellée « ennemis_au_contact » (les ennemis viennent attaquer,
personne ne reste figé). Deux recherches (mods KCD2 qui posent un camp de bandits ; naissance de groupes de PNJ) : rien
d'utilisable, seulement des demandes de mods et des guides du premier jeu. Le socle s'appuie sur ce qu'il sait déjà
faire : ses bandes (fiche 05, âmes de la fiche 13) et les meubles du camp (fiche 03, modèles déjà vus en jeu).

Découpage, une tranche à la fois, chacune vue en jeu avant la suivante :
1. le camp de bandits à un lieu (ci-dessous) ;
2. la mission et sa colonne (prendre, lieu, niveau selon la force, carte, à cheval aller et retour, issue calculée
   au-delà de 300 m, rapport) ; l'accroche « une mission peut-elle partir ? » (le jour de repos de Scriptorium) ;
3. plusieurs missions à la fois (réservation des lieux), puis les convois ;
4. la fouille des corps (relecture du pair, 17/10) : après une bataille de mission **et après une bataille au camp** ;
   un fouilleur va au point de chute, seuls certains hommes peuvent y aller (accroche, les bains l'enveloppent), et
   « vider la fouille » (portage des corps, sentinelles).

## Tranche 1 — Le camp de bandits à un lieu

Réponses prises d'office (consigne du 17/10 : l'option recommandée, notée ici) :
- **Un morceau `missions`** tient les lieux, les camps de bandits et (tranche 2) les missions. **Le combat reste à la
  bataille** : les hommes d'un camp de bandits sont une bande « postée » (pas de deuxième machine à combat).
- **Les lieux sont fournis par Scriptorium** (`missions.ajouter_un_lieu(nom, carte, position, cap)`), jamais devinés :
  le socle n'en connaît aucun ; le poste d'essai en pose un devant Henry.
- **Le coffre du camp est une somme** (selon la taille) ; vaincu, sa part entre au coffre de la compagnie par le partage
  du butin de la bataille (règle de Scriptorium, enveloppable). Pas de pillage de notre camp si on perd là-bas.
- **Rien ne naît ailleurs ni sous les yeux d'Henry** : meubles et hommes du camp naissent quand Henry est sur la carte
  du lieu et que le lieu n'est pas dans son regard (`henry_voit`, le même seuil que le secours) à moins de
  `naissance_vue_m` (300 m).
- **L'alerte** : Henry ou un de nos hommes à moins de `alerte_m` (35 m) du lieu : la bande passe au contact et
  attaque (ordre 8, relance des figés : tout ce que la bataille fait déjà). Combattants : nos hommes à moins de
  `engagement_m` (80 m) du lieu.
- **Henry seul** : la bataille ne finit que quand la bande est tombée ; Henry à plus de `fuite_m` (300 m) sans aucun de
  nos combattants debout : la bande retourne à son poste avec ses survivants (rien n'est tranché).
- **Au chargement** : meubles et hommes du camp de bandits sont retirés et refaits depuis le registre (les survivants
  comptés au dernier battement), comme le camp (fiche 03).
- **Après la victoire** : les corps et les meubles restent `duree_des_corps` (24 h), puis le camp est levé et le lieu
  redevient libre.

Accroches (fonctions publiques du morceau, que Scriptorium remplace en appelant l'ancienne) :
- `missions.taille_du_camp(lieu, niveau)` rend `{ sorte, effectif, coffre }` ;
- `missions.camp_vaincu(camp)` est appelée une fois, à la victoire (par défaut : une ligne au journal et l'annonce).

Services : `ajouter_un_lieu`, `lieux_de(carte)`, `dresser_un_camp(lieu, niveau)`, `camp(id)`, `camps()`,
`lever_un_camp(id)`, `lieu_sur_ma_carte(lieu)`.

Réglages au catalogue : `missions.reglages` (section `missions`), `missions.niveaux` (section `niveaux_des_camps`),
`missions.plan` (section `plan_des_camps`).

**Vu en jeu (17/10, 1a5d03f)** : rien né sous les yeux d'Henry (à 120 m, devant lui) ; dos tourné, quatre brigands
et les meubles nés au battement suivant ; Henry à moins de 35 m : alerte, les quatre reçoivent l'ordre 8 contre lui et
viennent l'attaquer (atout « Envers et contre tous » à l'écran) ; abattus par l'ordre d'essai : « victoire, butin 120 »,
« camp vaincu » une fois, l'annonce au bandeau ; puis levé. **Non vus en jeu** : la fuite d'Henry (retour au poste), un
de nos hommes qui donne l'alerte, la réfection au chargement, la levée 24 h après (vus au banc).

## Tranche 2 — La mission et sa colonne (en cours)

Déroulé (le pair, 17/10) : la troupe monte à cheval au camp et sort en colonne ; **avec Henry**, elle va jusqu'au camp de
bandits et s'y bat (tranche 1) ; **sans Henry**, hors de sa vue, elle passe « dehors » (retirée du monde, gardée au
registre), l'issue se calcule (force de la colonne contre celle du camp), puis elle renaît hors de la vue d'Henry sur
le chemin du retour, entre à cheval et descend.

- **La colonne va à un point** : `hommes.tenir(id, regle, { activite = "suivre", vers = { x, y, z }, a_cheval = true,
  formation })` ; sa tête mène vers le point (ordre 20 : la branche 18 vers `scriptorium_essai_point`), les autres se
  rangent (ordre 19). Une colonne vers un point ne fait pas le grand saut derrière Henry, n'est pas refaite près de lui,
  et le Directeur ne la prend pas.
- **Sonde du 17/10 (b56d855)** : l'ordre 18 avec pour chef un objet du monde (le feu du camp de bandits) : la monte et la
  formation se font (« Formation de Jan : followNPC », allure « course » à 142 m), mais **Jan n'a pas bougé** en deux
  minutes (même position à deux relevés) : le `Move` vers une entité qui n'est pas un personnage échoue en silence.
  D'où l'ordre 20 vers un point (le jalon invisible n'aurait pas mieux marché).
- **Vu en jeu (17/10, 198384c)** : l'ordre 20 marche : Jan monte et mène vers le point (40 m entre deux relevés), les
  deux autres rangés derrière lui ; arrêté à 6,7 m du point ; l'alerte engage les trois. **Deux défauts vus, corrigés** :
  le secours jugeait « bloqué » un homme qui se battait et le reposait au point (la bataille en est exclue, comme pour le
  gardien) ; la tenue « bataille » portait le point du camp : un ordre de marche redonné après le retrait du cheval
  écrasait l'attaque, et le combat s'enlisait (4 brigands sur 4 debout après plusieurs minutes, trois « figé malgré 2
  relances »). Contre une bande postée, la tenue ne porte plus de point. **Non vérifié en jeu** : le combat corrigé.
- **La mission** (réponses prises d'office, consigne du 17/10) :
  - `missions.prendre_une_mission({ lieu, hommes, chef, niveau })` : refus si l'accroche `missions.peut_partir(ordre)`
    dit non (le jour de repos de Scriptorium), lieu inconnu, homme indisponible (blessé, dehors, tenu plus fort), chef
    hors de la colonne. Le niveau, sinon donné : `missions.niveau_pour(force, lieu)` (accroche ; le plus grand niveau
    dont la force, × `marge_de_force` 1,5, ne dépasse pas celle de la colonne, `bataille.force_de(ids)`). Le camp de
    bandits est dressé au lieu (un lieu déjà pris : refus, la réservation viendra en tranche 3).
  - La colonne : règle « mission » (rang 2, sous la bataille), à cheval, le chef en tête (`tete`), vers le lieu.
  - **Loin d'Henry** (chacun à plus de `henry_loin_m` 300 m et hors de son regard) : « dehors » (`hommes.mettre_dehors` :
    personnage et cheval retirés, ni refait, ni garde, ni défense du camp) ; au lieu à l'heure calculée (distance /
    `vitesse_m_par_h`, 12 km/h) : `bataille.trancher_la_bande_postee` (force contre force, pertes, butin, partage) ; de
    retour à l'heure calculée : renaissance à `retour_naissance_m` (150 m) du camp sur le chemin du lieu, hors du
    regard d'Henry (sinon on attend), puis à cheval vers le camp.
  - **Avec Henry** : le combat sur place (tranche 1), puis le retour à cheval.
  - Rentrée (un homme à moins de `arrivee_m` du centre) : lâchée, chevaux retirés, l'accroche
    `missions.rapport_de_mission(r)` une fois (issue, morts, blessés, butin). Camp levé pendant la mission : rentrés près
    d'Henry, mission finie. Le registre garde les `gardes` (20) derniers camps levés et missions finies (trois erreurs
    injectées attrapées).
  - Relecture avant la séance : « sous les yeux » borné (regard et moins de `dehors_vue_m` 500 m) ; Henry illisible :
    personne n'est retiré du monde ; le retour vise le bord du camp (`retour_m` 15 m du centre, côté du lieu ;
    `arrivee_m` 6 m), jamais le feu au milieu des meubles. La tenue « mission » tombe par sûreté après `tenue_max_h`
    (24 h de jeu) : bien au-delà d'une mission ordinaire. La mission n'ouvre aucune fonction locale de plus au guichet.
  - **Non vérifié en jeu** : la mission entière (le prochain essai, regroupé avec le combat corrigé).
  - À reprendre plus tard : l'attente de renaissance n'a pas de borne (un joueur qui fixe la route bloque le retour) ;
    l'heure d'arrivée est comptée depuis le centre du camp, pas depuis le point où la colonne a disparu ; Henry qui
    rejoint le lieu pendant « dehors » y trouve les brigands sans nos hommes.
- **L'issue tranchée par passes** (règle scellée de JoVenGer « bataille_au_loin », 24/09, transmise par le pair le
  17/10 : « laisser le jeu en décider selon la puissance de chacun », « rien n'est écrit d'avance ») : au loin, pour la
  bataille du camp quand la règle tranche et pour l'embuscade d'une patrouille. Accroche `bataille.issue_au_loin(nous,
  sorte, effectif, bonus)` : à chaque passe un camp perd un homme, tiré au sort avec une chance de tomber qui suit le
  rapport des forces encore debout ; nos hommes tombent dans l'ordre de chute (rang avant, moindre jugement) ; fin quand
  un camp n'a plus personne. Chaque tombé : mort avec `part_des_morts` (0,5), blessé sinon. Le butin : tout si la bande
  tombe, rien sinon. L'issue dit ce qui s'est passé (victoire sans perte, avec pertes, repoussée si la moitié des leurs
  est tombée, défaite). La force d'un homme (accroche `bataille.force_d_un_homme`, où Scriptorium mettra l'expérience) :
  le poids du rôle, le palier (`bataille.paliers` : 1 ; 1,25 ; 1,5), l'usure, le caractère (aguerrissement, courage,
  fatigue) et le moral ; le sang-froid y entre par le moral (réponse prise d'office : pas de second facteur). Au banc,
  400 batailles par effectif (3 archers) : contre 2 brigands 371 victoires, 3 : 308, 4 : 233, 6 : 81, 9 : 7.
  Henry sur place : le vrai combat du jeu, rien de calculé (les blessés y restent encore une part fixe : à reprendre).
- **Séance du 17/10 (e22d7ca)** : la mission proche part (chef en tête, ordres 20 et 19), arrive, l'alerte engage les
  trois ; plus d'ordre de marche ni de « bloqué » (corrections vues). Mais le combat, à 117 m d'Henry, **se fige** : Jan
  assommé (inconscient, 4,7 de vie), les brigands intacts, plus personne en combat, positions et santés identiques à
  plusieurs minutes d'écart, les relances bornées épuisées. **Corrigé** : une bande postée au contact sans aucun tombé
  depuis `poste_stagnation_h` (0,5 h du jeu) et Henry à plus de `poste_sur_place_m` (80 m) est tranchée par passes.
  Vu aussi, cause non trouvée : après la pose d'Henry à 50 m du camp de bandits (commande d'essai), l'image retournée
  et l'interface disparue (Henry à terre ?). Séance fermée là ; **non vérifiés** : la fin de la mission proche, la
  mission lointaine.
- **Tranchée, l'issue s'applique aux vrais personnages** (relecture du pair, 17/10 ; « rien ne disparaît » sous les
  yeux d'Henry) : leurs tombés tués dans le jeu (le corps reste, à fouiller) ; nos morts tués, couchés, leur corps
  gardé puis retiré avec ceux de la bande ; nos blessés mis à terre (`liaison.mettre_a_terre`, santé portée à
  `blesse_sante` 5 : non vérifié que le jeu les couche) ; les survivants d'une bande postée restent debout et ne sont
  retirés que hors de la vue d'Henry ; le camp de bandits n'est levé que hors de sa vue. Un mort, partout (même au combat
  vu dans le jeu), laisse son corps (`hommes.retirer` rend le corps). Une bande venue au camp : ses survivants s'en
  vont aussitôt, comme avant (choix de JoVenGer du 14/10).
- **Séance suivante (7b66ead, puis rechargée avec 67fdb96)** : le combat figé tranché par passes (« défaite, 0 mort, 3
  blessés ») ; « défaite au lieu, retour au camp ». Deux défauts vus, corrigés : au retour, aucun ordre (le point changé
  n'entrait pas dans la signature de la tête ; corrigé, rechargé dans le jeu ouvert : l'ordre vers le bord du camp est
  donné) ; puis la tête, Jan, assommé au combat, ne remonte pas : la colonne l'attend. **Corrigé** : un homme hors
  d'état (`liaison.personnage_inconscient`) est porté (mis dehors hors de la vue d'Henry, il rentre avec la colonne) ; la
  tête passe au premier homme debout ; personne debout : la colonne entière rentre au loin. Non vérifié en jeu.
- **Vu en jeu (17/10, a182f1d)** : les deux missions jusqu'au rapport. Proche : combat figé tranché par passes
  (défaite, 3 blessés mis à terre), les trois portés, retour au loin, renaissance dès qu'Henry se détourne, rentrée à
  cheval, rapport une fois, les blessés à leur lit. Lointaine : dehors (les brigands à 451 m d'Henry ont l'agent IA
  inactif : à cette distance le jeu ne les fait plus vivre), tranchée au loin, renaissance, rentrée, rapport. La tête
  s'arrêtait à 6,4 m de son point : `arrivee_m` porté à 10 m (68d9c96). **Non vus en jeu** : une victoire (le combat
  vivant a chaque fois figé), la fuite des survivants d'une bande venue au camp, l'immortalité des blessés (c5ae51f).
- À surveiller (bataille du camp) : la tenue « bataille » y porte la place du rang ; un ordre de rang redonné en plein
  combat peut de même écraser l'attaque (à relire en séance).

À reprendre plus tard : le lieu d'essai pris devant Henry peut tomber dans une ferme (vu : derrière un mur) ; un vrai coffre du jeu à fouiller au milieu du camp ; les bandits assis au feu ou couchés.
