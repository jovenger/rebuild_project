-- Les hommes au camp : fiches, contrats, solde, vivres, moral, journée, garde, départs.
-- Fiche de comportement : docs/socle/fiches/04_hommes.md

local Scriptorium = Scriptorium

local hommes = {}
Scriptorium.hommes = hommes

hommes.reglages = {
  moral_depart = 60,
  ecart_entre_hommes = 1.2,   -- autour d'un point d'activité, mètres entre deux places (JoVenGer, 16/10, après V72 c)
  -- Le secours de l'homme bloqué (fiche 15, réponse 1 de JoVenGer du 16/10) : s'il ne s'est pas rapproché d'au moins
  -- « secours_progres_m » pendant « secours_delai_s », il est posé près de son but ; au plus « secours_max » fois par
  -- ordre ; « secours_arrivee_m » : arrivé.
  -- V73 a : le jeu arrête une marche entre 1,5 et 2,5 m du but ; « arrivé » doit le dépasser. « secours_assis_m » : un
  -- homme encore à moins de tant de mètres de sa place d'avant (assis, couché) n'est jamais posé d'un coup (poser un
  -- homme assis le fait se lever à son banc, sans le déplacer).
  secours_delai_s = 30,
  secours_progres_m = 1,
  secours_arrivee_m = 3,
  secours_max = 2,
  secours_assis_m = 1.5,
  -- Règle de JoVenGer (20/10, vu sur une copie : un porteur passant par la porte du camp, donc s'éloignant d'abord de son
  -- but, était posé d'office) : un homme qui marche n'est jamais bloqué ; il l'est seulement s'il ne s'est ni rapproché
  -- ni déplacé de « secours_progres_m » ; et celui qui marche sans jamais s'approcher mieux de son but pendant
  -- « secours_detour_max_s » (il tourne en rond) l'est aussi.
  secours_detour_max_s = 180,
  -- Fiche 15, V73 e (réponse 1 a de JoVenGer du 16/10, revue avec le pair le 17/10) : un homme à plus de « secours_loin_m »
  -- d'un but qui est au camp (à moins de « secours_loin_camp_m » de son centre) est secouru sans attendre le délai ; une
  -- sortie n'y est jamais soumise. Aucun secours ne pose un homme sous les yeux d'Henry : le cosinus entre son regard et
  -- la direction de l'endroit au-dessus de « secours_vue_cos » (0,5 : à moins de 60°), le secours attend.
  secours_loin_m = 150,
  secours_loin_camp_m = 50,
  secours_vue_cos = 0.5,
  -- Vu en J34 (25/10, la nuit : des hommes figés vers leurs lits, dans les grandes tentes de l'Aménagement, attendaient
  -- le secours sans fin, Henry restant au camp et regardant de leur côté) : la nuit, un endroit à plus de
  -- « secours_vue_nuit_m » d'Henry ne se voit plus (0 : la nuit ne change rien).
  secours_vue_nuit_m = 15,
  -- Vu sur une copie de la partie de JoVenGer le 20/10 : trois gens du personnel envoyés dormir sur des objets à plus de
  -- 2 km, puis posés là-bas par le secours. Un lit nommé à plus de « lit_nomme_max_m » du centre du camp (camp fondé)
  -- est refusé.
  lit_nomme_max_m = 100,
  -- Vu sur une copie de la partie de JoVenGer le 20/10 (sondes du pair : un homme envoyé à 64 m s'arrêtait à 31 m et
  -- jouait son geste sur place) : la marche était abandonnée au bout de « marche_delai_ms », quelle que soit la
  -- distance. Le temps de la marche qui reste, à « marche_approche_m_par_s » (prudent : 1,4 m/s mesuré), borné à
  -- « marche_approche_max_ms », s'ajoute désormais à ce délai (écrit par la liaison, ajouté par l'arbre).
  marche_approche_m_par_s = 1,
  marche_approche_max_ms = 600000,
  -- Demande du pair (20/10, sa condition de réalisme) : à moins de « marche_sur_place_m » de son but (assis à sa place,
  -- ordre reposé, relance, rechargement), pas de marche : temps 0, et l'arbre ne le fait pas se relever.
  marche_sur_place_m = 1.5,
  ration = 2,                 -- vivres par homme et par jour (choix de JoVenGer, 14/10)
  heure_lever = 5,            -- aube : contrats finis, désertions
  heure_repas = 7,            -- repas du matin : rations et soins
  -- Le jour d'entretien (relecture du pair, 17/10) : un numéro de jour qui commence à cette heure du soir.
  heure_d_entretien = 20,
  heure_paie = 8,             -- heure de la solde, le jour de paie
  semaines_impayees_max = 2,  -- au-delà, l'homme s'en va
  moral_desertion = 10,       -- en dessous, à l'aube, il déserte
  postes_garde_jour = 1,      -- au plus, le jour : un poste pour quatre hommes valides
  postes_garde_nuit = 2,      -- au plus, la nuit : un poste pour deux hommes valides
  hommes_par_poste_jour = 4,
  hommes_par_poste_nuit = 2,
  duree_tour_de_garde = 3,    -- heures
  -- Le factionnaire (fiche 15, V73 d 1) : il se tient face à un point de regard, à tant de mètres devant son poste.
  regard_m = 10,
  -- La ronde (fiche 15, V73 d 2, réponses a, a, b et a de JoVenGer du 17/10) : un chemin de 2 à « ronde_points_max »
  -- points ; à chaque point, une pause courte (« ronde_pause_ms », plus ou moins « ronde_pause_ecart_ms »), longue une
  -- fois sur « ronde_longue_sur » (« ronde_longue_ms », plus ou moins « ronde_longue_ecart_ms »), tirée au hasard du
  -- socle, jamais sous « ronde_pause_min_ms » ; pendant la pause, l'homme se tourne vers le dehors (à « regard_m »).
  ronde_points_max = 32,
  ronde_pause_ms = 6000,
  ronde_pause_ecart_ms = 4000,
  ronde_longue_ms = 20000,
  ronde_longue_ecart_ms = 8000,
  ronde_longue_sur = 5,
  ronde_pause_min_ms = 500,
  -- Le rassemblement (fiche 15, V73 e, réponses recommandées prises d'office le 17/10) : sans autre indication de la
  -- tenue, un arc de « rassemblement_ouverture » degrés à « rassemblement_rayon_m » du centre (le briefing de
  -- Scriptorium : un demi-cercle à 3 m, de −60° à +60°).
  rassemblement_rayon_m = 3,
  rassemblement_ouverture = 120,
  -- Suivre (fiche 15, V73 f 1, la règle de Scriptorium « LOIN 60, ARRIERE 4 ») : un suiveur à plus de « suivi_loin_m » de
  -- son chef est posé « suivi_derriere_m » derrière Henry, hors de sa vue ; à 0, jamais.
  suivi_loin_m = 60,
  suivi_derriere_m = 4,
  -- À cheval (fiche 15, V73 f 2 b, principes transmis par le pair) : une sortie à cheval donne à chaque homme un cheval
  -- passager, né à « cheval_distance_m » de lui sous un angle tiré au hasard ; une monte manquée (le délai du cerveau
  -- passé sans être en selle) retire le cheval et en fait naître un autre, au plus « monte_essais_max » essais, puis
  -- l'homme suit à pied jusqu'à la fin de sa sortie. La sortie finie, le cheval est retiré quand l'homme s'en est éloigné
  -- de plus de « cheval_retrait_m », ou au plus tard au « cheval_retrait_battements »-ième battement (jamais pendant la
  -- descente).
  cheval_distance_m = 5,
  cheval_retrait_m = 6,
  cheval_retrait_battements = 2,
  monte_essais_max = 3,
  -- La place du cheval (V73 f 2 c, conseils du pair : jamais dans un meuble, l'hypothèse de l'écran noir) : un homme dans
  -- le cercle de l'enceinte (celui du plan, bâtie ou non) va chercher sa monture hors du camp, « cheval_hors_camp_m »
  -- au-delà du cercle, du côté de la porte ; jusqu'à « cheval_places_essayees » angles tirés au hasard ; une place est
  -- bonne à « cheval_ecart_meuble_m » de tout objet du plan du camp et de l'enceinte (tous niveaux, par prudence), hors
  -- du cercle d'autant quand un camp est fondé, à « cheval_ecart_cheval_m » des chevaux des autres hommes, sur un terrain
  -- de pente au plus « cheval_pente_max » (mesurée à « cheval_sol_pas_m » de part et d'autre) et que rien n'encombre ;
  -- hors de la vue d'Henry si possible. L'homme marche jusqu'à son cheval : le délai de la monte s'allonge de la marche,
  -- à « monte_approche_m_par_s », au plus « monte_approche_max_ms ».
  cheval_hors_camp_m = 6,
  cheval_places_essayees = 8,
  -- Vu sur une copie de la partie de JoVenGer le 21/10 (J4 : le cheval de Jan né dans un cul-de-sac entre une tente et
  -- une clôture du camp réel, la colonne arrêtée 1,2 h ; accord du pair, règle de JoVenGer du 16/10 : on part et rentre
  -- à cheval depuis le bord du camp) : un chef de colonne à cheval qui n'a pas bougé de « fige_bouge_m » pendant
  -- « colonne_arret_battements » battements, à plus de « colonne_arrivee_m » de son but, est remis à pied (une monte
  -- manquée).
  colonne_arret_battements = 6,
  colonne_arrivee_m = 15,
  -- Demande de JoVenGer par le pair (21/10, J5 : deux blessés renés à 100 de santé, pris pour gardes des bains par
  -- Scriptorium qui juge un blessé à sa santé) : la santé d'un blessé suit sa blessure (les jours restent la vérité) ;
  -- son plafond selon ses jours de soins, 1 jour, 2, 3, 4, puis 5 et plus.
  sante_blesse_1 = 70,
  sante_blesse_2 = 60,
  sante_blesse_3 = 45,
  sante_blesse_4 = 38,
  sante_blesse_5 = 30,
  cheval_ecart_meuble_m = 3,
  cheval_ecart_cheval_m = 3,
  cheval_pente_max = 0.5,
  cheval_sol_pas_m = 1.5,
  monte_approche_m_par_s = 1,
  monte_approche_max_ms = 60000,
  -- Henry à cheval (V73 f 2 d, principe transmis par le pair) : l'escorte « comme Henry » monte quand il monte, tout de
  -- suite, et descend quand il descend, après « henry_descente_lectures » lectures « à pied » de suite (l'anti-rebond),
  -- une lecture toutes les « henry_veille_ms » ; Henry est lu monté quand un cheval monté (n'importe lequel, sauf les
  -- nôtres) se tient à moins de « henry_cheval_pres_m » de lui.
  henry_veille_ms = 1000,
  henry_descente_lectures = 4,
  henry_cheval_pres_m = 1.5,
  -- Le Directeur reprend la tête (V73 f 2 e, la règle de Scriptorium transmise par le pair) : quand il suit Henry en
  -- formation, une escorte d'Henry en formation se range dans sa formation ; à faux, son premier homme mène.
  directeur_mene_l_escorte = true,
  -- L'allure du chef monté (V73 f 2 f, principe d'Alex transmis par le pair) : la vitesse mesurée de celui qu'il suit la
  -- donne : sous « allure_arret_m_s », arrêté ; sous « allure_pas_m_s », le pas ; sous « allure_course_m_s », la course ;
  -- sous « allure_galop_m_s », le trot rapide ; au-delà, le galop ; « allure_marge » (relecture du pair) : on ne monte
  -- d'allure qu'au-dessus du seuil plus la marge, on ne descend qu'en dessous du seuil moins la marge. La distance
  -- corrige : le chef vise une place à « allure_place_m » ; au-delà de la place plus « allure_plus_m », une allure de
  -- plus ; en deçà de la place moins « allure_moins_m », une de moins ; arrêté et à sa place, il tient.
  allure_arret_m_s = 0.3,
  allure_pas_m_s = 2.2,
  allure_course_m_s = 4.5,
  allure_galop_m_s = 8,
  allure_marge = 0.1,
  allure_place_m = 7,
  allure_plus_m = 4,
  allure_moins_m = 3,
  -- V73 f 2 f bis (relecture du pair) : arrêté, il s'arrête à sa place et ne repart qu'au-delà de la place plus
  -- « allure_plus_m » ; « une de plus » est gardée jusqu'à la place plus « allure_freinage_m » (à cheval, il faut de
  -- la distance pour freiner) ; « une de moins », jusqu'à la place.
  allure_freinage_m = 1,
  -- V73 f 2 g (relecture du pair) : un relevé au-delà de « allure_saut_m_s » est un saut, pas une course (la vitesse
  -- d'avant reste) ; un suiveur est perdu au-delà de « allure_perdu_m » de son chef, et rentre dans le rang en deçà de
  -- « allure_rang_m ».
  allure_saut_m_s = 20,
  -- V73 f 3 b : sur une autre carte que celle du camp, l'escorte d'Henry est refaite à « escorte_derriere_m » derrière
  -- lui, hors de sa vue ; un cavalier à plus de « cheval_saut_m » de son chef (un grand saut, le voyage rapide) descend,
  -- son cheval est retiré, il est rattrapé à pied, puis un nouveau cheval naît près de lui.
  escorte_derriere_m = 6,
  cheval_saut_m = 150,
  -- Le saut rapide (relecture du pair : l'escorte voyage avec Henry) : un bond d'Henry de plus de « henry_bond_m » entre
  -- deux veilles (une seconde) lance le saut tout de suite ; « saut_descente_ms » après l'ordre à pied, le cheval est
  -- retiré et le cavalier posé derrière Henry.
  henry_bond_m = 50,
  saut_descente_ms = 3000,
  -- (relecture du pair) Jamais un cheval retiré sous son cavalier : encore en selle (lu), on attend « saut_attente_ms »,
  -- « saut_attentes_max » fois au plus, puis le saut est abandonné (il rejoint à cheval). Ni saut ni retrait sous les
  -- yeux d'Henry : dans son regard et à moins de « saut_vue_m ».
  saut_attente_ms = 2000,
  saut_attentes_max = 3,
  saut_vue_m = 300,
  -- (vu en jeu le 17/10 : une pose juste après la descente est parfois ignorée par le jeu) La pose est relue
  -- « saut_verif_ms » après : à plus de « saut_pose_ecart_m » de sa place, il est reposé, « saut_poses_max » fois au plus.
  saut_verif_ms = 1500,
  saut_pose_ecart_m = 15,
  saut_poses_max = 3,
  -- V73 g, le gardien des hommes (version simple ; les leçons de Scriptorium transmises par le pair) : une veille de
  -- « gardien_cadence_ms ». Sous le sol : plus de « gardien_sous_sol_m » sous le terrain, « gardien_sous_sol_regards »
  -- regards de suite : repêché, immortel « gardien_immortel_ms », « gardien_repeches_max » fois au plus par partie.
  -- Figé : à plus de « fige_but_m » de son but, moins de « fige_bouge_m » depuis le regard précédent, son ordre vieux
  -- d'au moins « fige_ordre_regards » regards : relancé (réveil, ordre redonné), « fige_relances_max » fois par ordre,
  -- jamais deux en « fige_regards_entre » regards, « fige_par_regard » au plus par regard ; utile au-delà de
  -- « fige_utile_m » au regard suivant.
  gardien_cadence_ms = 4000,
  gardien_sous_sol_m = 5,
  gardien_sous_sol_regards = 2,
  gardien_immortel_ms = 15000,
  gardien_repeches_max = 3,
  -- Mesuré sur une copie de la partie de JoVenGer le 20/10 (sondes du pair) : la marche du jeu s'arrête à 2,2-2,5 m de
  -- son point ; à 2,5, un homme arrivé était encore jugé figé et relancé. Aligné sur « secours_arrivee_m » (3).
  fige_but_m = 3,
  fige_bouge_m = 0.5,
  fige_utile_m = 1.5,
  fige_relances_max = 2,
  fige_regards_entre = 2,
  fige_par_regard = 6,
  -- Vu en J32 (24/10) : 35 marches lancées d'un coup au changement de la journée, des hommes pas encore partis jugés
  -- figés au bout de 8 s : la grâce depuis l'ordre de l'homme passe à 5 regards (20 s).
  fige_ordre_regards = 5,
  -- Même vue : au-delà de tant de mètres d'Henry (là où l'agent du personnage dort), un homme n'est pas jugé figé.
  gardien_rayon_m = 300,
  allure_perdu_m = 13,
  allure_rang_m = 6,
  anciens_gardes = 50,
  semaines_min = 1,
  semaines_max = 52,
  -- Fiche 20 : une demande de parole qui attend plus de tant d'heures du jeu (en combat, au lit) est oubliée.
  parole_attente_max_h = 2,
  -- Vu sur une copie de la partie de JoVenGer le 21/10 (J3 : une parole coupait neuf fois la colonne d'une mission) :
  -- une parole non urgente attend tant que l'homme est tenu par une règle plus forte (rang plus petit) que celle-ci ;
  -- 3, le rang de la règle de Scriptorium (décision de JoVenGer par le pair) : ses conversations du camp restent.
  parole_rang_min = 3,
  -- Fiche 18, 5 c, tranche 4 : le poste partagé avec Henry : la station rendue après « partage_delai_s » secondes au
  -- moins (Henry peut de nouveau lancer un mini-jeu), ou quand Henry s'en éloigne de plus de « partage_loin_m » ; l'homme
  -- attend à « partage_attente_m » de la station.
  partage_delai_s = 3,
  partage_loin_m = 6,
  partage_attente_m = 2.5,
  palier_par_defaut = 1,      -- palier d'embauche quand le contrat n'en donne pas : 1 recrue, 2 confirmé, 3 vétéran
  plafond = 80,               -- fiche 18, 5 a : la compagnie au plus (le chiffre de JoVenGer du 28/09)
  -- Vu sur une copie de la partie de JoVenGer le 21/10 (J26 : 30 embauches d'un coup, 13 jamais venus, « aucune place
  -- libre à côté » du feu) : au battement, au plus tant d'hommes sans personnage sont refaits (0 : jamais, comme avant).
  venues_par_battement = 3,
  -- Décision de JoVenGer (21/10, « Dormir au sol au feu ») : faute de lit libre, la posture couchée jouée à terre près du
  -- feu (une posture du jeu par son nom ; « » : pas de repli), l'écart entre deux dormeurs et le recul du premier rang
  -- (mètres) ; le blessé sans lit aussi. Vu en jeu le 21/10 (J27, image du pair) : « lyingInjured » exige un objet (les
  -- hommes restaient debout) ; « QuestHunterInjuryIdleLie », que le jeu joue sans objet (AI/quests/zranenylovci), les
  -- couche dans l'herbe.
  sommeil_sol_geste = "QuestHunterInjuryIdleLie",
  sommeil_sol_ecart_m = 2,
  sommeil_sol_recul_m = 3,
  sommeil_sol_blesses = true,
  -- L'arbitre (fiche 15, V73 b 3) : une tenue « jusqu'à libération » (bataille, patrouille) tombe par sûreté au bout de
  -- tant d'heures du jeu, notée au journal (réponse 2 a de JoVenGer) ; la journée du socle tient l'homme qu'aucune règle
  -- ne tient (réponse 3 a) : à faux, il attend où il est (Scriptorium la coupera à la bascule).
  tenue_max_h = 24,
  journee_du_socle = true,
  -- La garde de la tenue (fiche 13, après V73 b, réponses a et a de JoVenGer du 16/10) : tant d'hommes par battement, en
  -- tournant, remettent leurs propres pièces (le moteur leur ôte parfois leur tenue en pleine partie).
  tenue_garde_par_battement = 1,
  -- Vu dans la partie de JoVenGer le 22/10 (des hommes torse nu plusieurs minutes chaque matin : un seul homme habillé par
  -- battement, deux battements par homme) : tant d'hommes habillés par battement (1 : comme avant), et leur second
  -- passage tant de millisecondes après (0 : au battement suivant, comme avant).
  habillage_par_battement = 100,
  -- Demande de JoVenGer (22/10 : « beaucoup de monde debout » à l'aube) : la durée du lever (heures) avant le LEVER de
  -- Scriptorium.
  lever_duree_h = 0.5,
  -- Vu en J32 (24/10) : au changement de la journée, toute la compagnie recevait son ordre dans le même battement ; au
  -- plus tant de nouveaux ordres de la journée par seconde, les autres dans les secondes suivantes (0 : tous d'un coup).
  ordres_par_seconde = 4,
  habillage_second_passage_ms = 2000,
  -- Vu à l'image le 25/10 (socle 9fbb391 : Václav Vlk nu après le retrait de ses doublons, malgré la remise du battement
  -- suivant ; une remise quelques minutes plus tard le vêtait) : après un retrait de doublons, ses pièces refaites
  -- porter encore à ces délais (secondes réelles ; 0 : pas de remise).
  doublons_remise_1_s = 30,
  doublons_remise_2_s = 120,
  doublons_remise_3_s = 300,
  -- Vu en J38 bis (25/10, le pair : des hommes rentrés par hommes.faire_rentrer ne prenaient pas leur premier ordre ; la
  -- relance du gardien, réveil puis ordre redonné, les faisait partir) : un personnage qui vient d'être fait venir est
  -- réveillé et reçoit de nouveau son ordre « venue_ordre_redonne_ms » après sa venue, une fois (0 : jamais).
  venue_ordre_redonne_ms = 4000,
}

-- L'arbitre des ordres (fiche 15, V73 b 3) : le rang de chaque règle, du plus fort (1) au plus faible. Ordre validé par
-- JoVenGer le 16/10 (bataille, rassemblement, soins et bains, garde et ronde, travail, repas et sommeil, loisir) ; la
-- patrouille au rang de la garde, la corvée de punition au rang du travail (réponse 1 a du V73 b). La journée du socle
-- vient après toutes. Une règle absente de cette table ne tient personne.
hommes.priorites = {
  bataille = 1,
  rassemblement = 2,
  escorte = 2,
  mission = 2,
  soins = 3,
  bains = 3,
  garde = 4,
  garde_de_nuit = 4,
  ronde = 4,
  fouille = 4,
  patrouille = 4,
  travail = 5,
  punition = 5,
  repas = 6,
  sommeil = 6,
  loisir = 7,
}

-- Fiche 12 (les valeurs de l'arbre en données, règle de JoVenGer du 14/10) : les valeurs du comportement long et du
-- switch, en entiers, écrites dans le cerveau de chaque homme et du Directeur (variables scriptorium_cerveau_<nom>) au
-- premier battement après le réveil, à la naissance et à chaque changement. Tant que rien n'est écrit (zéro), l'arbre
-- prend ces mêmes valeurs par défaut, recopiées dans l'arbre et comparées au banc ; zéro vaut donc « par défaut ».
hommes.cerveau = {
  garde_ms = 500,             -- la garde relit l'ordre et fait battre le pouls
  tour_ms = 2000,             -- un tour du switch
  sortie_ms = 2000,           -- après une posture, le temps laissé au jeu pour jouer la sortie
  relance_tours = 3,          -- pouls figé tant de tours, le comportement en marche : relancé
  file_tours = 30,            -- lancé, jamais commencé depuis tant de tours : relancé
  marche_delai_ms = 30000,    -- une marche abandonnée au-delà
  marche_arret_cm = 200,      -- une marche s'arrête à tant du but, plus ou moins l'écart
  marche_ecart_cm = 50,
  siege_arret_cm = 10,        -- l'approche d'un siège (posture « sitting »)
  siege_ecart_cm = 5,
  lit_arret_cm = 50,          -- l'approche d'un lit (posture « lying »)
  lit_ecart_cm = 5,
  -- Vu sur une copie de la partie de JoVenGer le 20/10 (debout sur leur lit) : vers un objet, le Move ne réussit pas ;
  -- l'arrivée se LIT (la liaison mesure l'écart à l'objet visé) : à moins de « place_arrivee_cm » de l'objet (son centre,
  -- que l'homme ne peut pas toujours approcher à « siege_arret_cm »), la posture vient aussitôt.
  place_arrivee_cm = 150,
  -- Demande du pair (20/10, sonde : depuis un geste à genoux, le premier pas attendait la fin normale du geste) : la
  -- sortie de posture avant une marche se fait sous une urgence (la voie du jeu : UrgencyDecorator autour du WaitAction,
  -- AI/npc/basic/switch/interrupt_attack.xml) : 1 lente (slow), 2 rapide (fast), 3 instantanée (instant). Mesuré sur
  -- une copie de la partie de JoVenGer le 21/10 (J3 en rapide : des hommes retenus par l'action de leur geste ; J4 en
  -- instantanée, même copie, même heure : aucun figé) : 3 par défaut (décision de JoVenGer par le pair).
  urgence_relever = 3,
  -- Le factionnaire (fiche 15, V73 d 1, réponses a et a de JoVenGer du 16/10) : l'arrêt au poste, court comme celui du
  -- siège ; le jour, un geste « regarder autour » toutes les « poste_geste_ms », plus ou moins « poste_geste_ecart_ms »
  -- tirés au hasard par le jeu (les gardes ne bougent pas tous ensemble).
  poste_arret_cm = 50,
  poste_ecart_cm = 10,
  poste_geste_ms = 60000,
  poste_geste_ecart_ms = 30000,
  -- La ronde (fiche 15, V73 d 2) : l'arrêt à chaque point (principe d'Alex, transmis par le pair : 1 m, plus ou moins
  -- 0,5).
  ronde_arret_cm = 100,
  ronde_ecart_cm = 50,
  -- Suivre (fiche 15, V73 f 1) : les distances de la fonction de suivi du jeu (followNpc, ses valeurs par défaut) : il se
  -- met en marche au-delà de « suivi_depart_cm » de son chef, s'arrête à « suivi_arret_cm » ; l'allure change d'après la
  -- distance qui reste (de la marche à la course au-delà de « suivi_marche_course_cm », etc.).
  suivi_depart_cm = 500,
  suivi_arret_cm = 250,
  suivi_marche_course_cm = 2000,
  suivi_marche_sprint_cm = 3000,
  suivi_course_marche_cm = 1000,
  suivi_course_sprint_cm = 3000,
  suivi_sprint_course_cm = 2000,
  suivi_sprint_marche_cm = 1000,
  -- L'escorte en formation du moteur (fiche 15, V73 f 1 bis) : comment les suiveurs se rangent (1 « MoveHistory » : ils
  -- marchent où le chef a marché ; 2 « KeepShape » ; 3 « KeepDistance » ; 4 « Relaxed »).
  formation_mode = 1,
  -- Le suiveur dont la formation n'est pas ouverte suit son chef normalement et réessaie toutes les
  -- « formation_reessai_ms » (pas plus souvent : chaque essai refait le suiveur du moteur, chemin compris).
  formation_reessai_ms = 4000,
  -- À cheval (fiche 15, V73 f 2 a, relecture du pair) : la monte est bornée ; pas en selle au bout de « monte_delai_ms »,
  -- l'homme suit à pied (jamais figé à côté de son cheval).
  monte_delai_ms = 10000,
  -- L'allure du chef monté (V73 f 2 f) : un relevé toutes les « allure_cadence_ms » ; son Move s'arrête à
  -- « allure_arret_cm » de son chef, à plus ou moins « allure_ecart_cm ».
  allure_cadence_ms = 300,
  allure_arret_cm = 300,
  allure_ecart_cm = 100,
  -- La formation montée (V73 f 2 b, relecture du pair : tous les suiveurs montés du jeu sont en « MoveHistory » ou
  -- « Relaxed », aucun en « KeepShape ») : 1 « MoveHistory » ; 4 « Relaxed ».
  formation_mode_monte = 1,
  -- Le plafond de relances (fiche 15, V73 b 2, proposition du pair) : au plus « relances_max » lancements de la vie du
  -- camp par fenêtre de « relances_fenetre_ms » ; au-delà, plus aucun pendant une fenêtre entière, et une ligne au journal.
  relances_max = 3,
  relances_fenetre_ms = 60000,
}

-- Rôles, solde hebdomadaire de base en groschen, et réserve d'âmes où l'homme prend la sienne (fiche 13 : combattants
-- par palier, gens de métier).
hommes.roles = {
  homme_d_armes = { solde = 12, reserve = "combattant" },
  arbaletrier   = { solde = 14, reserve = "combattant" },
  archer        = { solde = 12, reserve = "combattant" },
  pavoisier     = { solde = 10, reserve = "combattant" },
  barbier       = { solde = 15, reserve = "metier" },
  cuisinier     = { solde = 8, reserve = "metier" },
  armurier      = { solde = 16, reserve = "metier" },
  -- Fiche 18, 5 c : le forgeron du camp (souvent le personnage de Scriptorium, admis par « hommes.admettre »).
  forgeron      = { solde = 16, reserve = "metier" },
}

-- Fiche 18, 5 c (la liste du pair : le forgeron exclu de la garde et des rondes) : les règles dont les gens de métier
-- sont exemptés (1 exempté, 0 non), en données.
hommes.exemptions_des_metiers = { garde = 1, garde_de_nuit = 1, ronde = 1, patrouille = 1 }

-- Rangs et multiplicateur de solde.
hommes.rangs = { soudoyer = 1, dizainier = 1.5, capitaine = 2 }

-- L'équipement des combattants (fiche 13, V71 b ; règles validées par JoVenGer le 15/10/2026) : la tenue selon le grade,
-- la famille d'armes de l'homme d'armes tirée à l'embauche (ou donnée par le contrat) et gardée à vie, la qualité selon
-- le grade ; le pavoisier, un préréglage à pavois peint ; archers et arbalétriers, nos assemblages de tir et leurs
-- munitions. Niveaux de préréglage « de » à « a » compris, la variante tirée ; les pièces de chaque préréglage sont dans
-- la liaison (outils/equipement.py). Chaque pièce est créée une à une : le jeu la garde avec son usure (V71 a3).
hommes.equipement = {
  etat_neuf = 1,     -- état des pièces neuves (1 : neuves)
  tenue = { sorte = "soldier_generic", palier_1 = { de = 1, a = 2 }, palier_2 = { de = 3, a = 4 }, palier_3 = { de = 5, a = 6 },
            -- Hors du tirage (réponse de JoVenGer du 15/10/2026, après V71 e) : les six tenues du palier 3 qui superposent
            -- une cotte, une brigandine ou une cuirasse et une cotte de mailles ; la cotte de dessus n'y est pas portée.
            exclues = { "soldier_generic_5_02", "soldier_generic_5_05", "soldier_generic_5_12", "soldier_generic_6_01",
                        "soldier_generic_6_03", "soldier_generic_6_04" } },
  familles = {
    epee_bouclier  = { sorte = "sword_shield", palier_1 = { de = 3, a = 3 }, palier_2 = { de = 4, a = 4 }, palier_3 = { de = 5, a = 5 } },
    hache_bouclier = { sorte = "axe_shield", palier_1 = { de = 3, a = 3 }, palier_2 = { de = 4, a = 4 }, palier_3 = { de = 5, a = 6 } },
    epee_longue    = { sorte = "longsword", palier_1 = { de = 3, a = 3 }, palier_2 = { de = 4, a = 4 }, palier_3 = { de = 5, a = 6 } },
    masse_bouclier = { sorte = "mace_shield", palier_1 = { de = 2, a = 3 }, palier_2 = { de = 4, a = 4 }, palier_3 = { de = 5, a = 6 } },
    hache          = { sorte = "axe", palier_1 = { de = 2, a = 2 }, palier_2 = { de = 3, a = 3 }, palier_3 = { de = 5, a = 5 } },
    arme_d_hast    = { sorte = "polearm", palier_1 = { de = 2, a = 2 }, palier_2 = { de = 3, a = 3 }, palier_3 = { de = 4, a = 6 } },
    -- Les compagnons nommés (18/10, liste validée par JoVenGer) : cinq familles de plus, données par contrat seulement
    -- (tirage = 0 : jamais tirées pour un homme ordinaire ; les six familles d'origine restent les seules tirées).
    masse          = { sorte = "mace", palier_1 = { de = 1, a = 1 }, palier_2 = { de = 2, a = 2 }, palier_3 = { de = 3, a = 3 }, tirage = 0 },
    marteau        = { sorte = "hammer", palier_1 = { de = 2, a = 2 }, palier_2 = { de = 3, a = 3 }, palier_3 = { de = 4, a = 4 }, tirage = 0 },
    sabre          = { sorte = "sabre", palier_1 = { de = 1, a = 1 }, palier_2 = { de = 1, a = 1 }, palier_3 = { de = 3, a = 3 }, tirage = 0 },
    epee           = { sorte = "sword", palier_1 = { de = 2, a = 2 }, palier_2 = { de = 3, a = 3 }, palier_3 = { de = 4, a = 4 }, tirage = 0 },
    epee_courte    = { sorte = "huntingsword", palier_1 = { de = 1, a = 2 }, palier_2 = { de = 3, a = 3 }, palier_3 = { de = 4, a = 5 }, tirage = 0 },
  },
  pavois = {
    palier_1 = { "mace_shield_2_02", "mace_shield_2_03" },
    palier_2 = { "mace_shield_3_04", "axe_shield_3_02", "axe_shield_3_03", "huntingsword_shield_3_01", "huntingsword_shield_3_02" },
    palier_3 = { "mace_shield_4_02", "axe_shield_4_02", "huntingsword_shield_4_01" },
  },
  tir = {
    archer = {
      palier_1 = { prereglages = { "scriptorium_archer_1" }, munitions = 25 },
      palier_2 = { prereglages = { "scriptorium_archer_2" }, munitions = 30 },
      palier_3 = { prereglages = { "scriptorium_archer_3" }, munitions = 30 },
    },
    arbaletrier = {
      palier_1 = { prereglages = { "scriptorium_arbaletrier_1_a", "scriptorium_arbaletrier_1_b" }, munitions = 20 },
      palier_2 = { prereglages = { "scriptorium_arbaletrier_2_a", "scriptorium_arbaletrier_2_b" }, munitions = 20 },
      palier_3 = { prereglages = { "scriptorium_arbaletrier_3_a", "scriptorium_arbaletrier_3_b" }, munitions = 20 },
    },
  },
}

-- Les 31 compagnons nommés (demande du pair ; liste validée par JoVenGer le 18/10, Scriptorium docs/socle/COMPAGNONS.md) :
-- chacun son âme (réserve « compagnon », outils/ames.py : numéro = rang dans cette liste, un visage fixe hors des
-- palettes), son rôle et sa famille d'armes. Familles les plus proches, faute de préréglage du jeu : la hache à deux
-- mains -> « hache » ; l'arbalète et la dague -> « arbaletrier » (son assemblage porte une épée courte) ; l'épée et la
-- dague -> « epee » (l'épée seule) ; l'arc long -> « archer ». La prise embauche ainsi :
-- hommes.embaucher({ nom = c.nom, ame = c.ame, role = c.role, famille = c.famille, palier = c.palier, prime = 0 }) ;
-- le prix est payé au coffre par Scriptorium. Liste à nom : réglable par le fichier (section « compagnons »).
hommes.compagnons = {
  { nom = "Vítek Lísek", surnom = "le Renard", ame = "5c7a5c7a-0007-4001-8000-000000000001", role = "archer", palier = 3 },
  { nom = "Matouš Kos", surnom = "le Merle", ame = "5c7a5c7a-0007-4001-8000-000000000002", role = "homme_d_armes", famille = "epee_courte", palier = 3 },
  { nom = "Ondra z Mýta", ame = "5c7a5c7a-0007-4001-8000-000000000003", role = "homme_d_armes", famille = "arme_d_hast", palier = 3 },
  { nom = "Kuneš Bradatý", surnom = "le Barbu", ame = "5c7a5c7a-0007-4001-8000-000000000004", role = "homme_d_armes", famille = "hache", palier = 3 },
  { nom = "Petr Šeptal", surnom = "le Chuchoteur", ame = "5c7a5c7a-0007-4001-8000-000000000005", role = "arbaletrier", palier = 3 },
  { nom = "Hroznata", ame = "5c7a5c7a-0007-4001-8000-000000000006", role = "homme_d_armes", famille = "masse", palier = 3 },
  { nom = "Jakub Vrba", ame = "5c7a5c7a-0007-4001-8000-000000000007", role = "arbaletrier", palier = 3 },
  { nom = "Radim Tichý", surnom = "le Silencieux", ame = "5c7a5c7a-0007-4001-8000-000000000008", role = "homme_d_armes", famille = "epee_bouclier", palier = 3 },
  { nom = "Ulrich der Rote", surnom = "le Rouge", ame = "5c7a5c7a-0007-4001-8000-000000000009", role = "homme_d_armes", famille = "epee_longue", palier = 3 },
  { nom = "Bartoš Kulhavý", surnom = "le Boiteux", ame = "5c7a5c7a-0007-4001-8000-00000000000a", role = "arbaletrier", palier = 3 },
  { nom = "Zdeněk Medvěd", surnom = "l'Ours", ame = "5c7a5c7a-0007-4001-8000-00000000000b", role = "homme_d_armes", famille = "hache", palier = 3 },
  { nom = "Mikeš Šídlo", surnom = "l'Alêne", ame = "5c7a5c7a-0007-4001-8000-00000000000c", role = "archer", palier = 3 },
  { nom = "Václav Hrbek", surnom = "le Bossu", ame = "5c7a5c7a-0007-4001-8000-00000000000d", role = "homme_d_armes", famille = "masse_bouclier", palier = 3 },
  { nom = "Ctibor z Hlinska", ame = "5c7a5c7a-0007-4001-8000-00000000000e", role = "homme_d_armes", famille = "epee_longue", palier = 3 },
  { nom = "Lukáš Čáp", surnom = "la Cigogne", ame = "5c7a5c7a-0007-4001-8000-00000000000f", role = "homme_d_armes", famille = "arme_d_hast", palier = 3 },
  { nom = "Gerhard Schwab", surnom = "le Souabe", ame = "5c7a5c7a-0007-4001-8000-000000000010", role = "homme_d_armes", famille = "epee_bouclier", palier = 3 },
  { nom = "Dobeš Kamenný", surnom = "le Roc", ame = "5c7a5c7a-0007-4001-8000-000000000011", role = "homme_d_armes", famille = "masse", palier = 3 },
  { nom = "Ješek Sokol", surnom = "le Faucon", ame = "5c7a5c7a-0007-4001-8000-000000000012", role = "archer", palier = 3 },
  { nom = "Mařík z Kutné Hory", ame = "5c7a5c7a-0007-4001-8000-000000000013", role = "arbaletrier", palier = 3 },
  { nom = "Sigmund Eisenhart", surnom = "Cœur de fer", ame = "5c7a5c7a-0007-4001-8000-000000000014", role = "homme_d_armes", famille = "epee_longue", palier = 3 },
  { nom = "Prokop Holý", surnom = "le Chauve", ame = "5c7a5c7a-0007-4001-8000-000000000015", role = "homme_d_armes", famille = "hache", palier = 3 },
  { nom = "Hanuš Šťastný", surnom = "le Chanceux", ame = "5c7a5c7a-0007-4001-8000-000000000016", role = "homme_d_armes", famille = "epee_bouclier", palier = 3 },
  { nom = "István Kovács", surnom = "le Hongrois", ame = "5c7a5c7a-0007-4001-8000-000000000017", role = "homme_d_armes", famille = "sabre", palier = 3 },
  { nom = "Bořek Hromovec", surnom = "le Tonnerre", ame = "5c7a5c7a-0007-4001-8000-000000000018", role = "homme_d_armes", famille = "marteau", palier = 3 },
  { nom = "Heřman z Lipé", ame = "5c7a5c7a-0007-4001-8000-000000000019", role = "homme_d_armes", famille = "epee_longue", palier = 3 },
  { nom = "Tobiáš Rychlý", surnom = "le Rapide", ame = "5c7a5c7a-0007-4001-8000-00000000001a", role = "homme_d_armes", famille = "epee", palier = 3 },
  { nom = "Mstidruh", ame = "5c7a5c7a-0007-4001-8000-00000000001b", role = "homme_d_armes", famille = "hache", palier = 3 },
  { nom = "Wojciech z Krakova", surnom = "le Polonais", ame = "5c7a5c7a-0007-4001-8000-00000000001c", role = "homme_d_armes", famille = "arme_d_hast", palier = 3 },
  { nom = "Smil Železný", surnom = "de Fer", ame = "5c7a5c7a-0007-4001-8000-00000000001d", role = "homme_d_armes", famille = "masse_bouclier", palier = 3 },
  { nom = "Konrád", surnom = "le Chevalier déchu", ame = "5c7a5c7a-0007-4001-8000-00000000001e", role = "homme_d_armes", famille = "epee_longue", palier = 3 },
  { nom = "Vok Starý", surnom = "le Vieux, maître d'armes", ame = "5c7a5c7a-0007-4001-8000-00000000001f", role = "homme_d_armes", famille = "epee_longue", palier = 3 },
}

-- Le service lisible pour la prise : nom -> la fiche du compagnon (les mêmes tables que hommes.compagnons).
hommes.compagnons_nommes = {}
for _, c in ipairs(hommes.compagnons) do
  hommes.compagnons_nommes[c.nom] = c
end

-- Les niveaux de moral.
hommes.niveaux_de_moral = {
  { seuil = 75, nom = "ardent" },
  { seuil = 50, nom = "content" },
  { seuil = 25, nom = "morose" },
  { seuil = 0, nom = "abattu" },
}

-- La journée, par tranches d'heures (de inclus, a exclu ; la dernière passe minuit). Réglable par le fichier (section
-- « journee », fiche 16, 3 b : l'horloge de Scriptorium) ; chaque tranche a un nom pour son chemin ; la nuit est la
-- tranche du sommeil.
hommes.journee = {
  { nom = "lever", de = 5, a = 7, activite = "lever" },
  { nom = "repas_du_matin", de = 7, a = 8, activite = "repas" },
  { nom = "exercice", de = 8, a = 12, activite = "exercice" },
  { nom = "repas_de_midi", de = 12, a = 13, activite = "repas" },
  { nom = "corvee", de = 13, a = 18, activite = "corvee" },
  { nom = "repas_du_soir", de = 18, a = 19, activite = "repas" },
  { nom = "veillee", de = 19, a = 22, activite = "veillee" },
  { nom = "sommeil", de = 22, a = 5, activite = "sommeil" },
}

-- Points du camp où se font les activités, par rapport à l'ancre.
hommes.points = {
  exercice = { x = 5, y = -1, cap = 90 },
  corvee = { x = -4, y = 6, cap = 0 },
  feu = { x = 0, y = 2.2, cap = 180 },
  des = { x = -2.5, y = -1.5, cap = 45 },   -- un coin près du feu, pour les dés de la veillée (fiche 11)
  -- Le centre du briefing d'essai (fiche 15, V73 e), à l'ouest du camp, l'arc tourné vers le camp : ses places, pour un à
  -- neuf hommes, sont à l'écart des meubles (vérifié au banc).
  briefing = { x = -15, y = 0, cap = 90 },
}

-- Postes de garde, autour du camp.
hommes.postes_de_garde = {
  { x = 0, y = 12, cap = 0 },
  { x = 12, y = 0, cap = 90 },
  { x = 0, y = -12, cap = 180 },
  { x = -12, y = 0, cap = 270 },
}

-- Les formations du moteur permises pour une escorte (fiche 15, V73 f 1 bis) : le nom d'un modèle du jeu
-- (AI/FormationDefinitions.xml, relu au banc) et son nombre de places ; au-delà, les surnuméraires suivent en chaîne.
hommes.formations = {
  followNPC = 8,
  infantryMen20 = 19,
  battleFormation_basic25 = 24,
}

-- Les rondes du socle (fiche 15, V73 d 2), autour de l'ancre : pour la commande d'essai seulement ; celles de
-- Scriptorium viennent par la tenue « ronde ». « pourtour » : un cercle de « nombre_de_points » à « rayon_m » du centre
-- (à 12 m, deux segments passeraient à moins de 2,4 m d'une tente et d'un banc du niveau 3 ; à 16 m, la palissade est
-- à 4 m).
hommes.rondes = {
  pourtour = { rayon_m = 16, nombre_de_points = 12 },
}

-- Noms d'époque (Bohême vers 1400). Prénoms et surnoms se combinent sans se répéter.
hommes.prenoms = {
  "Jan", "Mikuláš", "Ondřej", "Václav", "Jakub", "Petr", "Matěj", "Vít", "Havel", "Beneš",
  "Jindřich", "Oldřich", "Zdeněk", "Bohuslav", "Hanuš", "Kunrát", "Albrecht", "Ulrich",
  "Heinz", "Wenzel", "Prokop", "Beneda", "Martin", "Diviš",
}
hommes.surnoms = {
  "Kladivo", "le Rouge", "de Sázava", "Vlk", "le Long", "Sekera", "de Talmberk", "Hrom",
  "le Borgne", "Kozel", "de Rataje", "Medvěd", "le Taciturne", "Šíp", "de Skalice", "Holub",
}
-- Les femmes (réserve « femme ») : leurs prénoms et surnoms, combinés de même.
hommes.prenoms_de_femmes = {
  "Anna", "Markéta", "Dorota", "Kateřina", "Alžběta", "Ludmila", "Johana", "Barbora", "Mandalena", "Eliška",
}
hommes.surnoms_de_femmes = { "la Rousse", "de Ledeč", "Vlková", "la Douce", "de Sázava", "Holubová" }
-- Décision de JoVenGer (18/10, transmise par le pair) : l'intitulé de repli, partout où un nom manquerait.
hommes.nom_de_repli = "Homme de la Compagnie"
-- Le nom affiché au-dessus du Directeur (demande du pair, 19/10, d'après la décision de JoVenGer du 18/10 : chaque homme
-- son nom ; vu en jeu à la répétition 4 : il affichait « Soldat », le nom du personnage du jeu).
hommes.nom_du_directeur = "Le Directeur"

local function jeu()
  return Scriptorium.jeu
end

local function annoncer(cle, options)
  if Scriptorium.bandeau then
    Scriptorium.bandeau.annoncer(cle, options)
  end
end

local function coffre()
  return Scriptorium.coffre
end

local function camp()
  return Scriptorium.camp
end

-- ---------------------------------------------------------------- données

local function donnees_neuves()
  return {
    prochain = 1,
    prochain_nom = 1,
    liste = {},
    ordre = {},
    anciens = {},
    prochaine_paie = nil,
    dernier_jour_repas = nil,
    derniere_aube = nil,
    derniere_heure = nil,
    capitaine = nil,
  }
end

-- Montées de version de la case « hommes ».
-- 1 -> 2 (14/10) : le lieu d'une affectation change de nom de champ. Les affectations sont passagères
-- (elles ont une fin) : on les oublie, et chacun reprend sa journée.
-- 2 -> 3 (16/10, fiche 15, V73 b 3) : l'affectation unique devient une tenue par règle (« tenues ») ; l'ancienne,
-- passagère elle aussi, est oubliée de même.
local function oublier_les_affectations(d)
  for _, f in pairs(d.liste or {}) do
    if type(f) == "table" then
      f.affectation = nil
    end
  end
  return d
end

local migrations = {
  [1] = oublier_les_affectations,
  [2] = oublier_les_affectations,
}

local function donnees()
  local registre = Scriptorium.registre
  if not registre.etat_de("hommes") then
    registre.declarer_case("hommes", 3, donnees_neuves, migrations)
  end
  return registre.lire("hommes")
end

local function enregistrer()
  Scriptorium.registre.enregistrer("hommes")
end

-- Le personnel mené (demande du pair, 18/10 : les gens de Scriptorium à notre cerveau, hors de la Compagnie) : des
-- fiches minimales dans « d.menes », jamais dans « d.ordre » ; ni effectif, ni solde, ni moral, ni garde, ni bataille.
-- Les quatre fonctions qui mènent (activite_de, l'ordre, tenir, lâcher) trouvent la fiche ici ou là.
local function fiche_de(d, id)
  return d.liste[id] or (d.menes and d.menes[id]) or nil
end

-- Ceux avec qui l'on se range (colonne, arc) : la Compagnie pour un homme, lui seul pour un mené.
local function ordre_de(d, f)
  return (f and f.mene) and { f.id } or d.ordre
end

local function refuser(raison, detail)
  jeu().journal("Hommes : refus (" .. raison .. ")" .. (detail and (" : " .. detail) or ""))
  return false, raison
end

local function borner(valeur, mini, maxi)
  if valeur < mini then return mini end
  if valeur > maxi then return maxi end
  return valeur
end

local function jour_de(heure)
  return math.floor(heure / 24)
end

-- Service : le numéro du jour d'entretien à cette heure du jeu (l'heure du jeu en cours sans argument) ; il change à
-- « heure_d_entretien ».
function hommes.jour_d_entretien(heure)
  heure = heure or jeu().heure_du_jeu()
  return jour_de(heure - hommes.reglages.heure_d_entretien)
end

local function heure_dans_le_jour(heure)
  return heure - jour_de(heure) * 24
end

-- ---------------------------------------------------------------- noms

local function pgcd(a, b)
  while b ~= 0 do
    a, b = b, a % b
  end
  return a
end

-- Le nom du i-ième homme engagé. Prénom et surnom changent tous deux d'un homme à l'autre (« aucun pareil », souhait
-- de JoVenGer transmis le 15/10/2026 : en V70, les trois premiers s'appelaient tous Kladivo), et toutes les
-- combinaisons passent avant qu'un nom revienne : par tranches du plus petit commun multiple des deux listes, le surnom
-- décalé d'un cran à chaque tranche.
function hommes.nom_d_epoque(i)
  local np, ns = #hommes.prenoms, #hommes.surnoms
  local tranche = np * ns / pgcd(np, ns)
  local k = (i - 1) % (np * ns)
  local decalage, r = math.floor(k / tranche), k % tranche
  return hommes.prenoms[r % np + 1] .. " " .. hommes.surnoms[(r + decalage) % ns + 1]
end

-- La même combinaison pour les femmes.
function hommes.nom_de_femme(i)
  local np, ns = #hommes.prenoms_de_femmes, #hommes.surnoms_de_femmes
  local tranche = np * ns / pgcd(np, ns)
  local k = (i - 1) % (np * ns)
  local decalage, r = math.floor(k / tranche), k % tranche
  return hommes.prenoms_de_femmes[r % np + 1] .. " " .. hommes.surnoms_de_femmes[(r + decalage) % ns + 1]
end

-- Décision de JoVenGer (18/10, transmise par le pair) : chaque homme son nom, fixé par son âme (le jeu l'affiche
-- au-dessus de sa tête par le personnage de l'âme, outils/ames.py) : les combattants puis les gens de métier suivent les
-- noms d'époque, les femmes les leurs, les compagnons nommés leur liste, le Directeur le sien. Le nom d'une âme de nos
-- réserves, ou nil.
-- essais/tout_verifier.py vérifie que ce nom est celui que la table des textes donne au personnage de l'âme.
function hommes.nom_de_l_ame(ame)
  local reserve, rang = nil, nil
  if jeu().rang_de_l_ame then
    reserve, rang = jeu().rang_de_l_ame(ame)
  end
  if reserve == "combattant" then
    return hommes.nom_d_epoque(rang + 1)
  elseif reserve == "metier" then
    local combattants = 0
    for _, n in ipairs(jeu().paliers_de("combattant")) do
      combattants = combattants + n
    end
    return hommes.nom_d_epoque(combattants + rang + 1)
  elseif reserve == "femme" then
    return hommes.nom_de_femme(rang + 1)
  elseif reserve == "compagnon" then
    local c = hommes.compagnons[rang + 1]
    return c and c.nom or nil
  elseif reserve == "reprise" then
    local h = (jeu().reprise_des_hommes or {})[rang + 1]
    return h and h.nom or nil
  elseif reserve == "directeur" then
    return hommes.nom_du_directeur
  end
  return nil
end

-- L'empreinte d'une clé du relevé (un nombre ; outils/ames.py calcule la même) : la clé, nom d'entité de l'ancien mod,
-- n'est jamais écrite dans le socle.
function hommes.empreinte_de_cle(cle)
  local h = 5381
  for i = 1, #cle do
    h = (h * 33 + string.byte(cle, i)) % 2147483647
  end
  return h
end

-- La reprise des hommes de JoVenGer (demande du pair, 18/10) : hommes.ames_de_la_reprise[cle du relevé] -> son âme,
-- lisible par la prise (contrat « ame ») ; nil pour une clé inconnue, ou tant qu'aucun relevé n'a été écrit
-- (outils/ames.py --releve).
hommes.ames_de_la_reprise = setmetatable({}, { __index = function(_, cle)
  if type(cle) ~= "string" or not jeu() then
    return nil
  end
  local empreinte = hommes.empreinte_de_cle(cle)
  for i, h in ipairs(jeu().reprise_des_hommes or {}) do
    if h.empreinte == empreinte then
      return jeu().ame_de("reprise", 1, i)
    end
  end
  return nil
end })

-- ---------------------------------------------------------------- lecture

function hommes.liste()
  local copie = {}
  for i, id in ipairs(donnees().ordre) do
    copie[i] = id
  end
  return copie
end

function hommes.fiche(id)
  local f = donnees().liste[id]
  if not f then
    return nil
  end
  local copie = {}
  for cle, valeur in pairs(f) do
    if type(valeur) == "table" then
      local sous = {}
      for k, v in pairs(valeur) do sous[k] = v end
      copie[cle] = sous
    else
      copie[cle] = valeur
    end
  end
  return copie
end

function hommes.niveau_de_moral(moral)
  for _, niveau in ipairs(hommes.niveaux_de_moral) do
    if moral >= niveau.seuil then
      return niveau.nom
    end
  end
  return "abattu"
end

function hommes.effectif()
  local d = donnees()
  local bilan = { nombre = 0, valides = 0, blesses = 0, presents = 0, par_role = {}, par_rang = {} }
  for _, id in ipairs(d.ordre) do
    local f = d.liste[id]
    bilan.nombre = bilan.nombre + 1
    if f.blessure > 0 then bilan.blesses = bilan.blesses + 1 else bilan.valides = bilan.valides + 1 end
    if f.personnage then bilan.presents = bilan.presents + 1 end
    bilan.par_role[f.role] = (bilan.par_role[f.role] or 0) + 1
    bilan.par_rang[f.rang] = (bilan.par_rang[f.rang] or 0) + 1
  end
  return bilan
end

function hommes.anciens()
  local copie = {}
  for i, a in ipairs(donnees().anciens) do
    copie[i] = { id = a.id, nom = a.nom, role = a.role, cause = a.cause, moment = a.moment }
  end
  return copie
end

-- ---------------------------------------------------------------- solde d'un homme

local function solde_hebdomadaire(f)
  return math.floor(f.contrat.solde * hommes.rangs[f.rang] + 0.5)
end

function hommes.solde_de(id)
  local f = donnees().liste[id]
  return f and solde_hebdomadaire(f) or nil
end

-- ---------------------------------------------------------------- dialogues

-- Décision remplaçable (fiche 21, fiche 19) : la réponse d'un interlocuteur (un de nos hommes, ou « directeur ») au choix
-- d'Henry « choix » de l'arbre « arbre » : { codes = { c1, c2, c3 }, colonel = vrai|faux }. Les règles et les mots sont
-- à Scriptorium ; par défaut le socle ne dit rien (la réplique de repli), et seul le chef de la Compagnie (le capitaine
-- du socle ; le colonel de Scriptorium par sa remplaçante) est dit colonel.
function hommes.reponse_du_dialogue(arbre, choix, id)
  local d = donnees()
  return { codes = {}, colonel = (id ~= nil and id == d.capitaine) }
end
Scriptorium.remplacable(hommes, "reponse_du_dialogue", function(rendu)
  if type(rendu) ~= "table" or (rendu.codes ~= nil and type(rendu.codes) ~= "table") then
    return false
  end
  for i, code in ipairs(rendu.codes or {}) do
    if i > 3 or type(code) ~= "number" or code ~= math.floor(code) or code < 0 then
      return false
    end
  end
  return true
end)

-- Le personnage qui parle (le nom de son entité) devient l'homme, ou « directeur » ; la décision rend la réponse.
-- Décision remplaçable (fiche 21 ; décisions de JoVenGer du 25/10, contrat du pair) : les conditions des catégories et
-- des choix de l'arbre « arbre » pour cet interlocuteur, { nom = vrai|faux }, demandées à l'ouverture et à chaque choix
-- comme « colonel ». Les noms sont ceux de hommes.conditions_du_dialogue_noms (outils/dialogues.py les écrit dans les
-- arbres) ; un nom absent vaut faux. Par défaut, le socle ne sait que le chef et le camp : ni troupe, ni alerte, ni mesure.
hommes.conditions_du_dialogue_noms = { "colonel", "camp_monte", "camp_leve", "troupe_chez_elle", "troupe_appelee",
                                       "alerte", "sans_alerte", "mesure" }
function hommes.conditions_du_dialogue(arbre, id)
  local d = donnees()
  local monte = (camp() and camp().est_fonde()) == true
  return { colonel = (id ~= nil and id == d.capitaine), camp_monte = monte, camp_leve = not monte,
           troupe_chez_elle = false, troupe_appelee = false, alerte = false, sans_alerte = true, mesure = false }
end
Scriptorium.remplacable(hommes, "conditions_du_dialogue", function(rendu)
  if type(rendu) ~= "table" then
    return false
  end
  for nom, valeur in pairs(rendu) do
    if type(nom) ~= "string" or type(valeur) ~= "boolean" then
      return false
    end
  end
  return true
end)

function hommes.repondre_au_dialogue(arbre, choix, personnage)
  local id = personnage and hommes.homme_du_personnage(personnage) or nil
  if not id and personnage and Scriptorium.directeur and Scriptorium.directeur.personnage() == personnage then
    id = "directeur"
  end
  local reponse = Scriptorium.avis(hommes, "reponse_du_dialogue", arbre, choix, id) or { codes = {} }
  local conditions = {}
  for _, nom in ipairs(hommes.conditions_du_dialogue_noms) do
    conditions[nom] = false
  end
  for nom, valeur in pairs(Scriptorium.avis(hommes, "conditions_du_dialogue", arbre, id) or {}) do
    if conditions[nom] ~= nil then
      conditions[nom] = valeur
    end
  end
  -- « colonel » dit par la réponse (la forme d'avant le 25/10) compte toujours.
  conditions.colonel = conditions.colonel or reponse.colonel == true
  reponse.colonel = conditions.colonel
  reponse.conditions = conditions
  return reponse
end

-- ---------------------------------------------------------------- rangs

local function verifier_rangs(d, rapport)
  -- Fiche 16 : le chef est le colonel de Scriptorium ; le capitaine et les dizainiers d'office, éteints.
  if not Scriptorium.actif("rangs_du_socle") then
    return
  end
  local total = #d.ordre
  -- Capitaine d'office à dix hommes, s'il n'y en a pas : le plus ancien.
  if d.capitaine == nil and total >= 10 then
    local id = d.ordre[1]
    d.liste[id].rang = "capitaine"
    d.capitaine = id
    annoncer("ui_scriptorium_hommes_capitaine", { complement = d.liste[id].nom })
    rapport.capitaine = id
  end
  -- Un dizainier pour dix hommes, parmi ceux qui ne sont pas capitaine.
  local voulus = math.floor(total / 10)
  local dizainiers = {}
  local soudoyers = {}
  for _, id in ipairs(d.ordre) do
    local f = d.liste[id]
    if f.rang == "dizainier" then table.insert(dizainiers, id) end
    if f.rang == "soudoyer" then table.insert(soudoyers, id) end
  end
  -- Promotions, parmi les plus anciens.
  while #dizainiers < voulus and #soudoyers > 0 do
    local id = table.remove(soudoyers, 1)
    d.liste[id].rang = "dizainier"
    table.insert(dizainiers, id)
    annoncer("ui_scriptorium_hommes_promu_dizainier", { complement = d.liste[id].nom })
    rapport.promotions = (rapport.promotions or 0) + 1
  end
  -- Rétrogradations, les plus récents d'abord.
  while #dizainiers > voulus do
    local id = table.remove(dizainiers)
    d.liste[id].rang = "soudoyer"
    rapport.retrogradations = (rapport.retrogradations or 0) + 1
  end
end

function hommes.nommer_capitaine(id)
  local d = donnees()
  local f = d.liste[id]
  if not f then
    return refuser("homme_inconnu", tostring(id))
  end
  if d.capitaine and d.capitaine ~= id and d.liste[d.capitaine] then
    d.liste[d.capitaine].rang = "soudoyer"
  end
  f.rang = "capitaine"
  d.capitaine = id
  verifier_rangs(d, {})
  enregistrer()
  annoncer("ui_scriptorium_hommes_capitaine", { complement = f.nom })
  return true
end

-- ---------------------------------------------------------------- venue et départ des personnages

-- Une âme libre pour l'homme (fiche 13, validée par JoVenGer le 15/10/2026) : une âme par homme vivant, jamais partagée,
-- prise dans la réserve de son rôle, à son palier ; palier plein, au palier le plus proche (ses compétences corrigent
-- ensuite son niveau). Pas de jumeaux (demande du pair, 18/10) : d'abord une âme dont le visage n'est porté par personne
-- de la Compagnie (liaison.visage_de), puis, s'il n'en reste plus, une âme libre quelconque. Rend l'identifiant de
-- l'âme, ou nil quand toute la réserve est prise.
local function choisir_ame(d, f)
  local role = hommes.roles[f.role]
  local reserve = role and role.reserve
  local paliers = reserve and jeu().paliers_de(reserve) or {}
  local prises, visages_pris = {}, {}
  for _, id in ipairs(d.ordre) do
    local autre = d.liste[id]
    if autre and autre ~= f and autre.ame then
      prises[autre.ame] = true
      local v = jeu().visage_de and jeu().visage_de(autre.ame)
      if v then
        visages_pris[v] = true
      end
    end
  end
  local voulu = f.palier or 1
  local ordre_des_paliers = { voulu }
  for ecart = 1, #paliers do
    table.insert(ordre_des_paliers, voulu - ecart)
    table.insert(ordre_des_paliers, voulu + ecart)
  end
  for _, sans_jumeau in ipairs({ true, false }) do
    for _, palier in ipairs(ordre_des_paliers) do
      for numero = 1, paliers[palier] or 0 do
        local ame = jeu().ame_de(reserve, palier, numero)
        local v = ame and jeu().visage_de and jeu().visage_de(ame)
        if ame and not prises[ame] and not (sans_jumeau and v and visages_pris[v]) then
          return ame
        end
      end
    end
  end
  return nil
end

-- L'âme est tirée une fois, à la première venue, et gardée sur le registre : même visage et même voix au retour, et
-- l'homme la garde quand il monte en grade. Un homme né avant la fiche 13 sur une âme empruntée au jeu (cerveau du jeu)
-- renaît sur une âme à nous.
-- Une place derrière Henry (V73 f 3 b) : à « escorte_derriere_m », hors de sa vue, sur un sol que rien n'encombre ni ne
-- penche trop (les règles des chevaux) ; en éventail derrière lui, sinon juste derrière.
function hommes.point_pres_d_henry()
  local henry, cap = jeu().position_du_joueur(), jeu().cap_du_joueur() or 0
  if not henry then
    return nil
  end
  local r = hommes.reglages
  local repli = nil
  for _, ecart in ipairs({ 0, 40, -40, 80, -80 }) do
    local a = math.rad(cap + 180 + ecart)
    local p = { x = henry.x + r.escorte_derriere_m * math.sin(a), y = henry.y + r.escorte_derriere_m * math.cos(a),
                z = henry.z }
    repli = repli or p
    local sol = jeu().sol_de and Scriptorium.avis(jeu(), "sol_de", p, r.cheval_sol_pas_m) or nil
    local mauvais_sol = sol and (sol.encombre == true or (type(sol.pente) == "number" and sol.pente > r.cheval_pente_max))
    if not mauvais_sol and jeu().henry_voit(p, r.secours_vue_cos) ~= true then
      return p
    end
  end
  return repli
end

local function faire_venir(d, f, pres_d_henry, ici)
  local present = f.personnage and jeu().personnage_existe(f.personnage)
  -- Fiche 18, 5 c : un personnage admis (né ailleurs, celui de Scriptorium) n'est jamais refait par le socle.
  if f.admis then
    return present and true or false
  end
  if present and f.ame then
    return true
  end
  if not f.ame then
    f.ame = choisir_ame(d, f)
    if not f.ame then
      jeu().journal("Hommes : plus d'âme libre pour « " .. f.nom .. " » (" .. tostring(f.role) .. ") ; il reste sur le registre")
      if not present then
        f.personnage = nil
      end
      return present and true or false
    end
    -- Resté sans nom faute d'âme à l'embauche : il prend celui de l'âme qu'il reçoit enfin.
    if f.nom == hommes.nom_de_repli then
      f.nom = hommes.nom_de_l_ame(f.ame) or hommes.nom_de_repli
    end
    if present then
      jeu().journal("Hommes : « " .. f.nom .. " » renaît sur une âme à nous")
      jeu().renvoyer_homme(f.personnage)
      f.personnage = nil
    end
  end
  local position = ici
  if position then
    -- Fiche 17 : un homme qui rentre de mission renaît au point donné.
  elseif pres_d_henry then
    position = hommes.point_pres_d_henry()
  elseif camp().est_fonde() then
    position = camp().point(hommes.points.feu.x, hommes.points.feu.y, hommes.points.feu.cap)
  end
  local personnage = jeu().faire_venir_homme(f.ame, f.nom, position)
  if personnage == nil then
    jeu().journal("Hommes : le jeu n'a pas fait venir « " .. f.nom .. " » ; il reste sur le registre")
    f.personnage = nil
    return false
  end
  f.personnage = personnage
  f.derniere_activite = nil
  local ms = tonumber(hommes.reglages.venue_ordre_redonne_ms) or 0
  if ms > 0 and jeu().minuterie then
    local generation, id = Scriptorium.generation, f.id
    jeu().minuterie(ms, function()
      local g = generation == Scriptorium.generation and donnees().liste[id]
      if g and g.personnage == personnage and jeu().personnage_existe(personnage) then
        jeu().eveiller(personnage, g.nom)
        g.derniere_activite = nil
        jeu().journal("Hommes : « " .. g.nom .. " » venu : réveillé, son ordre redonné")
      end
    end)
  end
  -- Fiche 15, V73 d 2 bis : un personnage refait a un cerveau neuf ; s'il était de ronde, il la reprend comme après un
  -- rechargement.
  hommes.raisons_de_reprise[f.id] = hommes.raisons_de_reprise[f.id] or "rechargement"
  -- Fiche 13, V71 b : un personnage refait naît avec une tenue de naissance et sans les pièces de l'ancien, parties avec
  -- lui : il est rééquipé (tenue de naissance retirée de nouveau) ; les pièces données ensuite sont perdues.
  local e = f.equipement
  if e and e.etat ~= "impossible" and (e.naissance_retiree or e.etat == "pret" or e.etat == "a_rhabiller"
                                       or e.etat == "a_completer") then
    if #(e.en_plus or {}) > 0 then
      jeu().journal("Hommes : « " .. f.nom .. " » refait : " .. #e.en_plus .. " pièce(s) donnée(s) recréée(s) avec leur dernier état")
      e.recreer_en_plus = true
    end
    e.naissance_retiree, e.etat, e.otees, e.anciennes = false, "a_equiper", {}, nil
  end
  return true
end

local function liberer_place(f)
  if f.lit and camp().occupant_de(f.lit) == f.id then
    camp().liberer(f.lit)
  end
  f.lit = nil
end

-- Interrupteur « un_lit_par_homme » éteint (décision de JoVenGer, 20/10 : tous en relève) : un lit encore réservé à un
-- homme (embauché avant) est rendu, une fois, avec une ligne au journal. Rend le nombre de lits rendus.
local function rendre_les_lits_reserves(d)
  if Scriptorium.actif("un_lit_par_homme") then
    return 0
  end
  local rendus = 0
  for _, id in ipairs(d.ordre) do
    local f = d.liste[id]
    if f and f.lit then
      local nom = f.lit
      liberer_place(f)
      f.derniere_activite = nil
      rendus = rendus + 1
      jeu().journal("Hommes : « " .. f.nom .. " » rend son lit réservé « " .. nom .. " » : tous en relève")
    end
  end
  if rendus > 0 then
    enregistrer()
  end
  return rendus
end

-- Une place déclarée par Scriptorium a été retirée (camp.declarer_les_places l'a omise : l'objet n'est plus là) :
-- l'homme qui l'avait pour lit n'en a plus ; il dormira à une place libre (place_pour). Rend son identifiant, ou nil.
function hommes.lit_retire(nom)
  local d = donnees()
  for _, id in ipairs(d.ordre) do
    local f = d.liste[id]
    if f and f.lit == nom then
      f.lit = nil
      f.derniere_activite = nil
      enregistrer()
      jeu().journal("Hommes : « " .. f.nom .. " » perd son lit « " .. nom .. " » (retiré par Scriptorium)")
      return id
    end
  end
  return nil
end

local function faire_partir(d, f, cause, cle, garder_le_corps)
  local corps = nil
  if f.personnage and f.admis then
    -- Fiche 18, 5 c : un personnage admis reste dans le monde (il est à Scriptorium), mort ou vif : le socle ne rend pas
    -- son corps (personne ne le retire) et cesse seulement de le mener.
    f.personnage = nil
  elseif f.personnage and garder_le_corps then
    -- Fiche 17 (relecture du pair) : un mort reste à terre, rien ne disparaît sous les yeux d'Henry ; qui l'a tué retire
    -- le corps plus tard, hors de sa vue.
    corps = f.personnage
    f.personnage = nil
  elseif f.personnage then
    jeu().renvoyer_homme(f.personnage)
    f.personnage = nil
  end
  liberer_place(f)
  if Scriptorium.caractere then
    Scriptorium.caractere.oublier(f.id)
  end
  d.liste[f.id] = nil
  for i, id in ipairs(d.ordre) do
    if id == f.id then
      table.remove(d.ordre, i)
      break
    end
  end
  if d.capitaine == f.id then
    d.capitaine = nil
  end
  table.insert(d.anciens, { id = f.id, nom = f.nom, role = f.role, cause = cause, moment = jeu().heure_du_jeu() })
  while #d.anciens > hommes.reglages.anciens_gardes do
    table.remove(d.anciens, 1)
  end
  jeu().journal("Hommes : « " .. f.nom .. " » parti (" .. cause .. ")")
  if cle then
    annoncer(cle, { complement = f.nom })
  end
  return corps
end

-- ---------------------------------------------------------------- équipement (fiche 13, V71 b)

-- Les accroches : le programme Scriptorium y branche ses fonctions. « apres_le_rhabillage » (identifiant de l'homme) :
-- après qu'un homme a été équipé ou a remis ses affaires ; « piece_otee » (identifiant, objet) : une pièce de son ancien
-- grade, rendue au camp (réponse a de JoVenGer, 15/10) : la fonction rend vrai si elle la prend, et la pièce sort alors
-- du sac de l'homme ; si personne ne la prend, elle y reste, rien n'est détruit.
-- « ronde_reprise » (fiche 15, V73 d 2 bis, choix de JoVenGer du 17/10, proposée par le pair) : un rondier reprend sa
-- ronde ; l'accroche rend le numéro du point d'où il repart, ou rien (le point le plus proche).
-- « apres_l_equipement » (la bascule, demande du pair, 18/10) : (identifiant, donne) chaque fois que le socle donne à un
-- homme sa tenue, ses armes ou ses munitions : donne = { raison = "equipement" | "munitions", tenue, armes, objets =
-- { identifiants créés }, munitions = { objet, nombre } } ; Scriptorium y fait payer l'homme (sa bourse, sinon une
-- dette).
hommes.accroches = { apres_le_rhabillage = {}, piece_otee = {}, ronde_reprise = {}, apres_l_equipement = {} }

function hommes.accrocher(nom, fonction)
  local liste = hommes.accroches[nom]
  if not liste or type(fonction) ~= "function" then
    return refuser("accroche_inconnue", tostring(nom))
  end
  table.insert(liste, fonction)
  return true
end

local function appeler(nom, ...)
  local pris = false
  for _, fonction in ipairs(hommes.accroches[nom] or {}) do
    local ok, rendu = pcall(fonction, ...)
    if not ok then
      jeu().journal("Hommes : accroche « " .. nom .. " » en panne : " .. tostring(rendu))
    elseif rendu then
      pris = true
    end
  end
  return pris
end

-- Une accroche qui répond (fiche 15, V73 d 2 bis) : la première réponse que « valable » accepte, dans l'ordre où les
-- accroches ont été posées ; une réponse refusée ou une accroche en panne est dite au journal. Rend la réponse, ou nil.
local function demander(nom, valable, ...)
  for _, fonction in ipairs(hommes.accroches[nom] or {}) do
    local ok, rendu = pcall(fonction, ...)
    if not ok then
      jeu().journal("Hommes : accroche « " .. nom .. " » en panne : " .. tostring(rendu))
    elseif rendu ~= nil then
      if valable(rendu) then
        return rendu
      end
      jeu().journal("Hommes : accroche « " .. nom .. " » : réponse refusée (" .. tostring(rendu) .. ")")
    end
  end
  return nil
end

local function est_combattant(f)
  local role = hommes.roles[f.role]
  return role ~= nil and role.reserve == "combattant"
end

-- Le hasard de l'équipement, propre aux hommes et gardé sur le registre.
local function tirer(d)
  if not Scriptorium.hasard_en_ordre(d.graine_equipement) then
    d.graine_equipement = Scriptorium.hasard_depuis(7171)
  end
  return Scriptorium.tirer(d.graine_equipement)
end

local function choisir(d, liste)
  if #liste == 0 then
    return nil
  end
  return liste[math.floor(tirer(d) * #liste) + 1]
end

local function est_un_pavois(nom)
  for _, liste in pairs(hommes.equipement.pavois) do
    for _, p in ipairs(liste) do
      if p == nom then
        return true
      end
    end
  end
  return false
end

-- Les préréglages connus d'une sorte entre deux niveaux, sans ceux à pavois (réservés au pavoisier) ni ceux de la liste
-- « exclues ».
local function prereglages_de(sorte, bornes, exclues)
  local liste, hors = {}, {}
  for _, nom in ipairs(exclues or {}) do
    hors[nom] = true
  end
  if type(bornes) ~= "table" or type(bornes.de) ~= "number" or type(bornes.a) ~= "number" then
    return liste
  end
  for _, nom in ipairs(jeu().noms_des_prereglages()) do
    local s, niveau = string.match(nom, "^(.-)_(%d+)_%d+$")
    niveau = tonumber(niveau)
    if s == sorte and niveau and niveau >= bornes.de and niveau <= bornes.a and not est_un_pavois(nom) and not hors[nom] then
      table.insert(liste, nom)
    end
  end
  return liste
end

local function noms_des_familles()
  local noms = {}
  for nom, famille in pairs(hommes.equipement.familles) do
    if famille.tirage ~= 0 then
      table.insert(noms, nom)
    end
  end
  table.sort(noms)
  return noms
end

-- Fiche 19 (A5, A22, A23 ; décision remplaçable) : la tenue, les armes et les munitions d'un combattant pour son palier
-- (sa famille tirée une fois, s'il n'en a pas) : { tenue, armes, munitions } (des noms de préréglages du jeu), ou faux
-- s'il n'y en a pas.
function hommes.choix_de_l_equipement(id)
  local d = donnees()
  local f = d.liste[id]
  if not f then
    return false
  end
  local regles = hommes.equipement
  local cle = "palier_" .. tostring(f.palier or 1)
  local tenue = choisir(d, prereglages_de(regles.tenue.sorte, regles.tenue[cle], regles.tenue.exclues))
  local armes, munitions = nil, 0
  if f.role == "homme_d_armes" then
    if not (f.famille and regles.familles[f.famille]) then
      f.famille = choisir(d, noms_des_familles())
    end
    local famille = regles.familles[f.famille]
    armes = choisir(d, prereglages_de(famille.sorte, famille[cle]))
  elseif f.role == "pavoisier" then
    armes = choisir(d, regles.pavois[cle] or {})
  elseif regles.tir[f.role] then
    local tir = regles.tir[f.role][cle] or {}
    armes = choisir(d, tir.prereglages or {})
    munitions = tir.munitions or 0
  end
  if not tenue or not armes then
    return false
  end
  return { tenue = tenue, armes = armes, munitions = munitions }
end
Scriptorium.remplacable(hommes, "choix_de_l_equipement", function(rendu)
  return rendu == false or (type(rendu) == "table" and type(rendu.tenue) == "string" and type(rendu.armes) == "string"
    and #(jeu().pieces_de(rendu.tenue) or {}) > 0 and #(jeu().pieces_de(rendu.armes) or {}) > 0
    and type(rendu.munitions) == "number" and rendu.munitions >= 0 and math.floor(rendu.munitions) == rendu.munitions)
end)

-- Choisit l'équipement d'un combattant (la décision remplaçable ci-dessus), à équiper au prochain battement. Rend vrai
-- s'il en a.
local function choisir_l_equipement(d, f)
  local e = f.equipement or {}
  e.en_plus, e.otees = e.en_plus or {}, e.otees or {}
  e.naissance_retiree = e.naissance_retiree or false
  f.equipement = e
  local choix = Scriptorium.avis(hommes, "choix_de_l_equipement", f.id)
  if type(choix) ~= "table" then
    e.etat = "impossible"
    jeu().journal("Hommes : pas de préréglage pour « " .. f.nom .. " » (" .. tostring(f.role) .. ", palier_"
                  .. tostring(f.palier or 1) .. ")")
    return false
  end
  e.tenue, e.armes, e.munitions, e.etat = choix.tenue, choix.armes, choix.munitions, "a_equiper"
  return true
end

-- Une pièce donnée (en_plus) : { objet, etat }, son dernier état connu (V71 c) ; une fiche d'avant n'a que l'objet.
local function objet_de(piece)
  return type(piece) == "table" and piece.objet or piece
end

-- Ce qu'il porte, dans l'ordre : pièces de sa tenue, de ses armes, ses munitions, puis les pièces données ensuite, moins
-- celles qu'il ne porte plus. La dernière pièce d'une même place l'emporte : toujours la même (pair, 15/10).
local function liste_portee(f)
  local e = f.equipement or {}
  local liste = {}
  for _, nom in ipairs({ e.tenue or false, e.armes or false }) do
    for _, objet in ipairs(nom and jeu().pieces_de(nom) or {}) do
      table.insert(liste, objet)
    end
  end
  local munition = e.armes and jeu().munition_de(e.armes)
  if munition then
    table.insert(liste, munition)
  end
  for _, piece in ipairs(e.en_plus or {}) do
    table.insert(liste, objet_de(piece))
  end
  for _, objet in ipairs(e.otees or {}) do
    for i = #liste, 1, -1 do
      if liste[i] == objet then
        table.remove(liste, i)
        break
      end
    end
  end
  -- Demande du pair (18/10) : les pièces au sac (hommes.pieces_au_sac) restent dans le sac, jamais remises par la garde.
  for _, objet in ipairs(e.au_sac or {}) do
    for i = #liste, 1, -1 do
      if liste[i] == objet then
        table.remove(liste, i)
        break
      end
    end
  end
  return liste
end

function hommes.ce_qu_il_porte(id)
  local f = donnees().liste[id]
  return f and liste_portee(f) or {}
end

-- Le nombre voulu de chaque pièce de ces objets (sa tenue, ses armes) : une par mention, plus ses pièces données de la
-- même classe.
local function pieces_voulues(f, objets)
  local voulues = {}
  for _, objet in ipairs(objets) do
    voulues[objet] = (voulues[objet] or 0) + 1
  end
  for _, piece in ipairs(f.equipement.en_plus or {}) do
    local objet = objet_de(piece)
    if voulues[objet] then
      voulues[objet] = voulues[objet] + 1
    end
  end
  return voulues
end

-- Vu en jeu le 25/10 (le colonel nu, 23 pièces de sa tenue au lieu de 10) : deux pièces de la même classe trompent le
-- jeu (FindItem prend l'une ou l'autre : la forge détruisait la copie portée). Les copies au-delà du nombre voulu sont
-- retirées, avant de faire porter. Rend le nombre de pièces retirées.
-- Vu ensuite (25/10, socle 961689d : le colonel nu après le retrait, ses pièces au sac ; refaites porter plus tard, il
-- était vêtu) : la copie que le jeu trouve est gardée, les autres détruites par leur identifiant (liaison) ; et l'homme
-- remet encore ses pièces au battement suivant (« a_rhabiller »).
local remettre_apres_doublons
local function retirer_les_doublons(f, voulues)
  local retirees = 0
  for objet, n in pairs(voulues) do
    local a = jeu().compter_objet(f.personnage, objet)
    if a > n then
      retirees = retirees + jeu().retirer_les_copies(f.personnage, objet, a - n)
    end
  end
  if retirees > 0 then
    jeu().journal("Hommes : « " .. f.nom .. " », " .. retirees .. " pièce(s) en double retirée(s) ; il remettra ses pièces au battement suivant")
    remettre_apres_doublons(f)
  end
  return retirees
end

-- Équipe l'homme : sa tenue de naissance retirée d'abord, une fois (V71 a6), puis chaque pièce créée une à une, puis
-- portée dans l'ordre ; les pièces de l'ancien grade offertes à l'accroche « piece_otee ».
local function equiper(d, f)
  local e = f.equipement
  local a_creer = {}
  for _, nom in ipairs({ e.tenue, e.armes }) do
    for _, objet in ipairs(jeu().pieces_de(nom) or {}) do
      table.insert(a_creer, objet)
    end
  end
  local munition = jeu().munition_de(e.armes)
  local doublons = 0
  -- Un personnage refait retrouve les pièces qu'on lui avait données, avec leur dernier état connu (V71 c ; « ce qu'il
  -- a acheté est à lui », règle de JoVenGer dans Scriptorium).
  local a_recreer = {}
  if e.recreer_en_plus then
    for i, piece in ipairs(e.en_plus) do
      local etat = type(piece) == "table" and piece.etat or nil
      if type(etat) ~= "number" then
        etat = 1
        jeu().journal("Hommes : « " .. f.nom .. " », état inconnu pour " .. tostring(objet_de(piece)) .. " : recréée neuve")
      end
      e.en_plus[i] = { objet = objet_de(piece), etat = etat }
      table.insert(a_recreer, e.en_plus[i])
    end
    e.recreer_en_plus = nil
  end
  local munitions_donnees = (munition and (e.munitions or 0) > 0) and { objet = munition, nombre = e.munitions } or nil
  -- Vu en jeu le 25/10 (le colonel nu, 23 pièces de sa tenue au lieu de 10) : un rééquipement au même choix recréait
  -- toutes ses pièces à côté des siennes. Deux pièces de la même classe trompent le jeu (FindItem prend l'une ou
  -- l'autre : la forge détruisait la copie portée). Sa tenue de naissance déjà retirée, il garde ses pièces (et leur
  -- usure) : seules celles qui manquent sont créées, les copies en trop retirées avant de porter.
  if e.naissance_retiree then
    local voulues = pieces_voulues(f, a_creer)
    doublons = retirer_les_doublons(f, voulues)
    local manque, manquantes = {}, {}
    for _, objet in ipairs(a_creer) do
      if manque[objet] == nil then
        manque[objet] = voulues[objet] - jeu().compter_objet(f.personnage, objet)
      end
      if manque[objet] > 0 then
        table.insert(manquantes, objet)
        manque[objet] = manque[objet] - 1
      end
    end
    a_creer = manquantes
    if munitions_donnees then
      munitions_donnees.nombre = math.max(0, e.munitions - jeu().compter_objet(f.personnage, munition))
      if munitions_donnees.nombre == 0 then
        munitions_donnees = nil
      end
    end
  end
  local compte = jeu().equiper_homme(f.personnage, {
    retirer_naissance = not e.naissance_retiree,
    creer = a_creer,
    etat = hommes.equipement.etat_neuf,
    munition = munitions_donnees,
    recreer = a_recreer,
    porter = liste_portee(f),
  })
  appeler("apres_l_equipement", f.id, { raison = "equipement", tenue = e.tenue, armes = e.armes, objets = a_creer,
                                        munitions = munitions_donnees })
  e.naissance_retiree = true
  e.etat = "a_completer"
  if e.anciennes then
    local portees = {}
    for _, objet in ipairs(liste_portee(f)) do
      portees[objet] = true
    end
    local rendues = 0
    for _, objet in ipairs(e.anciennes) do
      if not portees[objet] and appeler("piece_otee", f.id, objet) and jeu().retirer_un_objet(f.personnage, objet) then
        rendues = rendues + 1
      end
    end
    jeu().journal("Hommes : « " .. f.nom .. " », " .. rendues .. " pièce(s) de l'ancien grade rendue(s) au camp")
    e.anciennes = nil
  end
  jeu().journal("Hommes : « " .. f.nom .. " » équipé (" .. tostring(e.tenue) .. ", " .. tostring(e.armes) .. ") : " .. tostring(compte))
  if doublons > 0 then
    e.etat = "a_rhabiller"
  end
end

-- À chaque entrée en partie, l'homme remet ses propres pièces, dans l'ordre (réponse a de JoVenGer, 15/10) : le jeu ne
-- lui laisse portée qu'une partie de ses pièces et lui ôte ses armes (V71 a6). Une pièce introuvable est notée, jamais
-- recréée au hasard. Filet (règle du 5/10) : plus aucune pièce de sa tenue, ou plus son arme principale : ses
-- préréglages sont recréés au battement suivant. Ses munitions sont complétées jusqu'au nombre de son préréglage.
-- Le filet de la tenue de corps (fiche 13, règle du 5/10 : « l'homme n'a plus son arme principale ou plus sa tenue de
-- corps ») : la partie qui manque (« torse » ou « jambes » : sa tenue en a, il n'en porte plus aucune), « arme », ou nil.
-- Vu en jeu le 18/10 : un homme ne gardait que coiffe, tour de cou et bottes ; l'ancien filet (plus aucune pièce) le
-- laissait ainsi.
local function ce_qui_manque(f)
  local e = f.equipement
  if not (e and e.tenue and e.armes) then
    return nil
  end
  local voulues, portees = {}, {}
  for _, objet in ipairs(jeu().pieces_de(e.tenue) or {}) do
    local partie = jeu().partie_du_corps and jeu().partie_du_corps(objet) or nil
    if partie then
      voulues[partie] = true
      if jeu().compter_objet(f.personnage, objet) > 0 then
        portees[partie] = true
      end
    end
  end
  for _, partie in ipairs({ "torse", "jambes" }) do
    if voulues[partie] and not portees[partie] then
      return partie
    end
  end
  local armes = jeu().pieces_de(e.armes) or {}
  if not armes[1] or jeu().compter_objet(f.personnage, armes[1]) == 0 then
    return "arme"
  end
  return nil
end

local function rhabiller(d, f)
  local e = f.equipement
  -- Demande de JoVenGer (25/10) : les doublons d'avant la correction (sa vraie partie en a) retirés au rhabillage,
  -- sans attendre un rééquipement.
  local doublons = 0
  if e.tenue and e.armes and e.naissance_retiree then
    local objets = jeu().pieces_de(e.tenue) or {}
    for _, objet in ipairs(jeu().pieces_de(e.armes) or {}) do
      table.insert(objets, objet)
    end
    doublons = retirer_les_doublons(f, pieces_voulues(f, objets))
  end
  local portes, introuvables = jeu().faire_porter(f.personnage, liste_portee(f))
  e.etat = "a_completer"
  -- Le dernier état connu de chaque pièce donnée, pour la recréer telle quelle si le personnage est refait (V71 c).
  for i, piece in ipairs(e.en_plus or {}) do
    local etat = jeu().etat_objet(f.personnage, objet_de(piece))
    e.en_plus[i] = { objet = objet_de(piece), etat = etat or (type(piece) == "table" and piece.etat or nil) }
  end
  if e.tenue and e.armes then
    local reste = 0
    for _, objet in ipairs(jeu().pieces_de(e.tenue) or {}) do
      if jeu().compter_objet(f.personnage, objet) > 0 then
        reste = reste + 1
      end
    end
    local manque = ce_qui_manque(f)
    if reste == 0 or manque then
      jeu().journal("Hommes : « " .. f.nom .. " » sans sa tenue ou sans son arme (" .. tostring(manque or "tenue")
                    .. ") : ses préréglages seront recréés")
      e.etat = "a_equiper"
      return
    end
    local munition = jeu().munition_de(e.armes)
    if munition then
      local n = jeu().compter_objet(f.personnage, munition)
      if n < (e.munitions or 0) then
        jeu().creer_objet(f.personnage, munition, 1, e.munitions - n)
        jeu().journal("Hommes : « " .. f.nom .. " », munitions complétées (" .. n .. " -> " .. e.munitions .. ")")
        appeler("apres_l_equipement", f.id, { raison = "munitions", objets = {},
                                              munitions = { objet = munition, nombre = e.munitions - n } })
      end
    end
  end
  jeu().journal("Hommes : « " .. f.nom .. " » a remis ses affaires (" .. tostring(portes) .. " pièce(s)"
    .. (#introuvables > 0 and (", " .. #introuvables .. " introuvable(s) ou refusée(s)") or "") .. ")")
  if doublons > 0 then
    e.etat = "a_rhabiller"
  end
end

-- La garde de la tenue (fiche 13) : marque un homme équipé « à rhabiller » ; le battement lui fera remettre ses pièces,
-- par le chemin du chargement (journal, second passage, accroche). Rend vrai s'il est marqué.
local function marquer_a_rhabiller(f)
  local e = f.equipement
  if e and (e.etat == "pret" or e.etat == "a_completer") then
    e.etat = "a_rhabiller"
    return true
  end
  return false
end

-- Second passage, au battement suivant (V71 c : un seul passage juste après la création ou la remise ne fait pas tout
-- porter ; un second complète la tenue, un troisième ne change rien). Puis l'accroche « après le rhabillage ».
local function completer(d, f)
  local portes, introuvables = jeu().faire_porter(f.personnage, liste_portee(f))
  f.equipement.etat = "pret"
  jeu().journal("Hommes : « " .. f.nom .. " », second passage (" .. tostring(portes) .. " pièce(s)"
    .. (#introuvables > 0 and (", " .. #introuvables .. " introuvable(s) ou refusée(s)") or "") .. ")")
  appeler("apres_le_rhabillage", f.id)
end

local function en_bataille()
  return Scriptorium.bataille ~= nil and #Scriptorium.bataille.bandes() > 0
end

-- La garde de la tenue ne touche pas un homme (fiche 13, réponse 2 a de JoVenGer) : au lit (sa place est un lit ; la
-- sortie du lit le rhabillera), sous une tenue qui le veut dévêtu (le bain : « ne_pas_rhabiller »), en combat ou en
-- conversation. Rend la raison, ou nil.
local function garde_suspendue(id, f)
  local a = Scriptorium.avis(hommes, "activite_de", id, jeu().heure_du_jeu())
  if a and a.lieu and camp().sorte_de(a.lieu) == "lit" then
    return "au lit"
  end
  if a and a.ne_pas_rhabiller then
    return "tenu dévêtu (" .. tostring(a.regle) .. ")"
  end
  local occupe = f.personnage and jeu().occupation_de(f.personnage)
  if occupe then
    return "en " .. occupe
  end
  return nil
end

-- Un homme par battement, jamais en bataille ; un homme que la garde ne doit pas toucher attend son tour (fiche 13).
-- Vu sur une copie de la partie de JoVenGer le 19/10 : la file repartait toujours du premier de la liste ; les premiers,
-- remis « à rhabiller » sans cesse (vie du camp relancée, fin de combat), passaient toujours devant, et le colonel,
-- neuvième, restait à équiper, presque nu, pendant des heures de jeu. Désormais, par ordre : l'homme commencé (son
-- second passage), puis un homme à équiper (sans sa tenue), puis un homme à rhabiller ; et dans chaque cas en tournant
-- (la file reprend après le dernier servi).
-- Rend l'identifiant de l'homme équipé ou rhabillé, ou faux.
hommes.habillage_rang = 0

-- Même vue (22/10) : le second passage d'un homme, « habillage_second_passage_ms » après son rhabillage ou son équipement,
-- par une minuterie ; jamais en bataille ni pour une autre partie ; la file du battement reste le filet.
local function second_passage_differe(f)
  local ms = tonumber(hommes.reglages.habillage_second_passage_ms) or 0
  if ms <= 0 or not jeu().minuterie then
    return
  end
  local generation, id = Scriptorium.generation, f.id
  jeu().minuterie(ms, function()
    if generation ~= Scriptorium.generation or en_bataille() then
      return
    end
    local d = donnees()
    local g = d.liste[id]
    if g and g.equipement and g.equipement.etat == "a_completer" and g.personnage and jeu().personnage_existe(g.personnage) then
      completer(d, g)
      enregistrer()
    end
  end)
end

-- Les remises après un retrait de doublons (« doublons_remise_N_s ») : ses propres pièces refaites porter, sans rien
-- créer ni rien ôter (remettre une pièce portée ne l'ôte pas, V71 c) ; jamais en bataille, ni s'il est tenu dévêtu.
remettre_apres_doublons = function(f)
  if not jeu().minuterie then
    return
  end
  local generation, id = Scriptorium.generation, f.id
  for i = 1, 3 do
    local s = tonumber(hommes.reglages["doublons_remise_" .. i .. "_s"]) or 0
    if s > 0 then
      jeu().minuterie(s * 1000, function()
        if generation ~= Scriptorium.generation or en_bataille() then
          return
        end
        local g = donnees().liste[id]
        if g and g.equipement and g.personnage and jeu().personnage_existe(g.personnage) and not garde_suspendue(id, g) then
          local portes, introuvables = jeu().faire_porter(g.personnage, liste_portee(g))
          jeu().journal("Hommes : « " .. g.nom .. " », remise après ses doublons (+" .. s .. " s) : " .. tostring(portes)
                        .. " pièce(s) portée(s), " .. #introuvables .. " introuvable(s)")
        end
      end)
    end
  end
end

-- Les hommes habillés au moment de leur ordre depuis le début du battement (la file ne les reprend pas aussitôt).
hommes.habilles_hors_file = hommes.habilles_hors_file or {}

local function equiper_un_homme(d, faits)
  faits = faits or {}
  if en_bataille() or #d.ordre == 0 then
    return false
  end
  for _, id in ipairs(d.ordre) do
    local f = d.liste[id]
    if f.personnage and jeu().personnage_existe(f.personnage) and not f.equipement and est_combattant(f)
        and not f.admis then
      choisir_l_equipement(d, f)
    end
  end
  for _, voulu in ipairs({ "a_completer", "a_equiper", "a_rhabiller" }) do
    for pas = 1, #d.ordre do
      local rang = (hommes.habillage_rang + pas - 1) % #d.ordre + 1
      local id = d.ordre[rang]
      local f = d.liste[id]
      local etat = f.equipement and f.equipement.etat
      -- La garde n'est lue que pour un homme qui a quelque chose à faire (elle interroge l'arbitre).
      if etat == voulu and not faits[id] and f.personnage and jeu().personnage_existe(f.personnage)
          and not garde_suspendue(id, f) then
        if etat == "a_equiper" then
          equiper(d, f)
        elseif etat == "a_rhabiller" then
          rhabiller(d, f)
        else
          completer(d, f)
        end
        if f.equipement and f.equipement.etat == "a_completer" then
          second_passage_differe(f)
        end
        hommes.habillage_rang = rang
        return id
      end
    end
  end
  return false
end

-- La garde de la tenue, en tournant (fiche 13, réponse 2 a de JoVenGer) : « tenue_garde_par_battement » hommes prêts,
-- chacun à son tour, remettent leurs propres pièces, sans rien créer ni rien ôter (remettre une pièce portée ne l'ôte pas,
-- V71 c), en silence : compté au rapport, pas au journal. Jamais en bataille ; un homme que la garde ne doit pas toucher
-- est sauté, comme celui que le rhabillage vient de traiter dans ce battement (« deja »). Rend le nombre d'hommes repassés.
hommes.garde_de_la_tenue_rang = 0

local function garder_les_tenues(d, deja)
  if en_bataille() or #d.ordre == 0 then
    return 0
  end
  local repasses, vus = 0, 0
  local voulus = math.max(0, math.floor(tonumber(hommes.reglages.tenue_garde_par_battement) or 0))
  while repasses < voulus and vus < #d.ordre do
    hommes.garde_de_la_tenue_rang = hommes.garde_de_la_tenue_rang % #d.ordre + 1
    vus = vus + 1
    local id = d.ordre[hommes.garde_de_la_tenue_rang]
    local f = d.liste[id]
    if not (deja and deja[id]) and f.personnage and f.equipement and f.equipement.etat == "pret" and jeu().personnage_existe(f.personnage)
        and not garde_suspendue(id, f) then
      jeu().faire_porter(f.personnage, liste_portee(f))
      repasses = repasses + 1
      -- Le filet de la tenue de corps, aussi en pleine journée (vu en jeu le 18/10 : déshabillé hors de nos rhabillages,
      -- un homme prêt n'était plus jamais revu) : marqué à rhabiller, le rhabillage recrée ses préréglages.
      local manque = ce_qui_manque(f)
      if manque then
        f.equipement.etat = "a_rhabiller"
        jeu().journal("Hommes : « " .. f.nom .. " » à rhabiller (plus de " .. manque .. ")")
      end
    end
  end
  return repasses
end

-- ---------------------------------------------------------------- embauche

-- Accroches de l'embauche (fiche 18, 5 a) : avant (Scriptorium refuse, ou modifie le contrat ; rend vrai, ou faux et la
-- raison) et après (l'homme engagé).
function hommes.avant_l_embauche(contrat)
  return true
end

function hommes.apres_l_embauche(id, contrat)
end

-- Le plafond de la compagnie, lisible : { plafond, effectif, lits_libres }.
function hommes.plafond_de_la_compagnie()
  local d = donnees()
  return { plafond = hommes.reglages.plafond, effectif = #d.ordre,
           lits_libres = camp().est_fonde() and #Scriptorium.avis(camp(), "places_libres", "lit", "hommes") or 0 }
end

-- Le contrat d'embauche : role, semaines, solde, prime, palier, famille ; et (fiche 18, 5 a) « nom » (un compagnon
-- nommé), « ame » (son âme, un identifiant du jeu donné par Scriptorium), « position » (où il naît). Une prime de 0 :
-- rien à payer, aucun appel au coffre (Scriptorium paie lui-même l'embauche ; le 10/10, un retrait de 0 avait vidé la
-- bourse d'Henry). Les contrats à durée éteints, « semaines » est facultatif (le plus long contrat).
function hommes.embaucher(contrat)
  contrat = contrat or {}
  local d = donnees()
  if not camp().est_fonde() then
    return refuser("camp_absent")
  end
  local lu, permis, pourquoi = pcall(hommes.avant_l_embauche, contrat)
  if not lu then
    return refuser("accroche_en_erreur", tostring(permis))
  end
  if permis ~= true then
    return refuser("refus_de_scriptorium", tostring(pourquoi))
  end
  if #d.ordre >= hommes.reglages.plafond then
    return refuser("plafond_atteint", #d.ordre .. " / " .. hommes.reglages.plafond)
  end
  if contrat.nom ~= nil and (type(contrat.nom) ~= "string" or contrat.nom == "") then
    return refuser("nom_invalide", tostring(contrat.nom))
  end
  if contrat.ame ~= nil and (type(contrat.ame) ~= "string" or not string.match(contrat.ame, "^%x+%-%x+%-%x+%-%x+%-%x+$")) then
    return refuser("ame_invalide", tostring(contrat.ame))
  end
  -- Règle du pair (18/10) : jamais deux hommes sur une même âme (un compagnon nommé ne s'embauche qu'une fois).
  if contrat.ame ~= nil then
    for _, autre in ipairs(d.ordre) do
      local sienne = d.liste[autre].ame
      if sienne and string.lower(sienne) == string.lower(contrat.ame) then
        return refuser("ame_deja_portee", autre)
      end
    end
  end
  local p = contrat.position
  if p ~= nil and (type(p) ~= "table" or type(p.x) ~= "number" or type(p.y) ~= "number" or type(p.z) ~= "number") then
    return refuser("position_invalide")
  end
  -- Fiche 18, 5 c : « personnage » (hommes.admettre) : un personnage déjà né, pas encore de la Compagnie.
  local deja_ne = contrat.personnage
  if deja_ne ~= nil then
    if type(deja_ne) ~= "string" or not jeu().personnage_existe(deja_ne) then
      return refuser("personnage_introuvable", tostring(deja_ne))
    end
    for _, autre in ipairs(d.ordre) do
      if d.liste[autre].personnage == deja_ne then
        return refuser("deja_de_la_compagnie", autre)
      end
    end
    if contrat.ame ~= nil or p ~= nil then
      return refuser("personnage_avec_ame_ou_point")
    end
  end
  local role = hommes.roles[contrat.role]
  if not role then
    return refuser("role_inconnu", tostring(contrat.role))
  end
  local semaines = contrat.semaines
  if semaines == nil and not Scriptorium.actif("contrats_a_duree") then
    semaines = hommes.reglages.semaines_max
  end
  if type(semaines) ~= "number" or math.floor(semaines) ~= semaines
     or semaines < hommes.reglages.semaines_min or semaines > hommes.reglages.semaines_max then
    return refuser("duree_invalide", tostring(semaines))
  end
  local function somme_juste(n)
    return type(n) == "number" and n == n and n >= 0 and n < math.huge and math.floor(n) == n
  end
  local solde = contrat.solde or role.solde
  if not somme_juste(solde) then
    return refuser("solde_invalide", tostring(solde))
  end
  -- Fiche 18, 5 c : un personnage admis est à Scriptorium : sans prime donnée, rien à payer.
  local prime = contrat.prime or (contrat.personnage ~= nil and 0) or solde * 2
  if not somme_juste(prime) then
    return refuser("prime_invalide", tostring(prime))
  end
  local palier = contrat.palier or hommes.reglages.palier_par_defaut
  local nb_paliers = #jeu().paliers_de(role.reserve)
  if type(palier) ~= "number" or math.floor(palier) ~= palier or palier < 1 or palier > math.max(nb_paliers, 1) then
    return refuser("palier_invalide", tostring(palier))
  end
  if contrat.famille ~= nil and not hommes.equipement.familles[contrat.famille] then
    return refuser("famille_inconnue", tostring(contrat.famille))
  end
  -- Fiche 18, 5 a bis (la reprise de la partie de JoVenGer, le pair, 17/10) : « objets », l'équipement donné au lieu du
  -- préréglage : une liste de { objet (identifiant du jeu), etat (0 à 1) } ou d'identifiants, recréés à la naissance avec
  -- leur état (la voie des pièces données, V71 c), puis portés.
  local objets = nil
  if contrat.objets ~= nil then
    if type(contrat.objets) ~= "table" or #contrat.objets == 0 then
      return refuser("objets_invalides")
    end
    objets = {}
    for i, piece in ipairs(contrat.objets) do
      local objet = type(piece) == "table" and piece.objet or piece
      local etat = type(piece) == "table" and piece.etat or hommes.equipement.etat_neuf
      if type(objet) ~= "string" or not string.match(objet, "^%x+%-%x+%-%x+%-%x+%-%x+$")
          or type(etat) ~= "number" or etat <= 0 or etat > 1 then
        return refuser("objet_invalide", tostring(i))
      end
      objets[i] = { objet = string.lower(objet), etat = etat }
    end
    if contrat.personnage ~= nil then
      return refuser("personnage_avec_objets")
    end
  end
  local lits = Scriptorium.avis(camp(), "places_libres", "lit", "hommes")
  if #lits == 0 and Scriptorium.actif("un_lit_par_homme") then
    annoncer("ui_scriptorium_hommes_pas_de_lit")
    return refuser("pas_de_lit")
  end
  if prime > 0 and coffre().solde() < prime then
    annoncer("ui_scriptorium_coffre_manque", { groupe = "coffre_manque" })
    return refuser("coffre_insuffisant", "prime " .. prime .. " > " .. coffre().solde())
  end
  local heure = jeu().heure_du_jeu()
  local id = "homme_" .. d.prochain
  d.prochain = d.prochain + 1
  local f = {
    id = id,
    nom = contrat.nom,
    role = contrat.role,
    rang = "soudoyer",
    palier = palier,
    ame = contrat.ame,
    contrat = { semaines = semaines, solde = solde, prime = prime, debut = heure, fin = heure + semaines * 7 * 24 },
    moral = hommes.reglages.moral_depart,
    blessure = 0,
    impayes = 0,
    personnage = nil,
    -- Décision de JoVenGer (20/10, transmise par le pair, choix recommandé) : interrupteur éteint, tous en relève, aucun
    -- lit réservé à l'embauche (il dort à une place libre, comme les autres).
    lit = Scriptorium.actif("un_lit_par_homme") and lits[1] or nil,
    derniere_activite = nil,
    engage = heure,
    retenue = 0,
    famille = contrat.famille,
  }
  -- Chaque homme son nom, celui de son âme (décision de JoVenGer, 18/10) : l'âme est tirée dès l'embauche ; un nom donné
  -- par le contrat (compagnon nommé, reprise) passe devant ; sans âme libre ni nom donné, l'intitulé de repli.
  if not f.ame and not deja_ne then
    f.ame = choisir_ame(d, f)
  end
  f.nom = f.nom or (f.ame and hommes.nom_de_l_ame(f.ame)) or hommes.nom_de_repli
  if prime > 0 then
    local ok = coffre().payer(prime, "prime")
    if not ok then
      return refuser("coffre_insuffisant", "prime")
    end
  end
  d.liste[id] = f
  table.insert(d.ordre, id)
  if f.lit then
    camp().reserver(f.lit, id)
  else
    jeu().journal("Hommes : « " .. f.nom .. " » engagé sans lit (interrupteur un_lit_par_homme éteint)")
  end
  if Scriptorium.caractere then
    Scriptorium.caractere.naitre(id)
  end
  if d.prochaine_paie == nil then
    d.prochaine_paie = (jour_de(heure) + 7) * 24 + hommes.reglages.heure_paie
    d.derniere_heure = heure
    d.derniere_aube = jour_de(heure - hommes.reglages.heure_lever)
    d.dernier_jour_repas = jour_de(heure - hommes.reglages.heure_repas)
  end
  -- V73 f 3 b : embauché quand Henry est sur une autre carte que celle du camp, il rejoint le registre (sans personnage)
  -- et paraît au camp au retour d'Henry.
  if deja_ne then
    f.personnage, f.admis = deja_ne, true
    jeu().journal("Hommes : « " .. f.nom .. " » admis (personnage « " .. deja_ne .. " », déjà né)")
  elseif camp().sur_sa_carte == nil or camp().sur_sa_carte() then
    faire_venir(d, f, false, p and { x = p.x, y = p.y, z = p.z } or nil)
  else
    jeu().journal("Hommes : « " .. f.nom .. " » embauché loin du camp (autre carte) : il paraîtra au camp")
  end
  if objets then
    f.equipement = { en_plus = objets, otees = {}, naissance_retiree = false, munitions = 0, etat = "a_equiper",
                     recreer_en_plus = true }
  elseif est_combattant(f) and not f.admis then
    choisir_l_equipement(d, f)
  end
  verifier_rangs(d, {})
  enregistrer()
  annoncer("ui_scriptorium_hommes_rejoint", { complement = f.nom })
  local apres_lu, erreur = pcall(hommes.apres_l_embauche, id, contrat)
  if not apres_lu then
    jeu().journal("Hommes : accroche « après l'embauche » en erreur : " .. tostring(erreur))
  end
  return id
end

-- Fiche 18, 5 c : admettre dans la Compagnie un personnage déjà né (le forgeron de Scriptorium, connu par son
-- personnage) : le contrat de l'embauche, sans âme ni point ; il n'est jamais refait ni renvoyé par le socle, ni équipé ;
-- absent (une autre carte, pas encore chargé), il attend au registre. Rend son identifiant, ou faux et la raison.
function hommes.admettre(personnage, contrat)
  local c = {}
  for cle, valeur in pairs(contrat or {}) do c[cle] = valeur end
  c.personnage = personnage
  if c.personnage == nil then
    return refuser("personnage_introuvable", "nil")
  end
  return hommes.embaucher(c)
end

-- L'homme dont le personnage est celui-ci, ou nil (le forgeron connu par son personnage).
function hommes.homme_du_personnage(personnage)
  local d = donnees()
  for _, id in ipairs(d.ordre) do
    if d.liste[id].personnage == personnage then
      return id
    end
  end
  return nil
end

-- Fiche 18, 5 b : rendre un homme parlable (Henry peut lui parler ; le dialogue de Scriptorium s'y greffe par l'accroche
-- « quand_on_lui_parle »). Rend vrai, ou faux et la raison.
function hommes.rendre_parlable(id, oui)
  local f = donnees().liste[id]
  if not f then
    return refuser("homme_inconnu", tostring(id))
  end
  f.parlable = oui and true or nil
  if f.personnage and jeu().rendre_parlable then
    jeu().rendre_parlable(f.personnage, oui and true or false)
  end
  enregistrer()
  return true
end

-- Accroche (fiche 18, 5 b ; le dialogue de Scriptorium la remplace) : Henry parle à un homme parlable. Par défaut, une
-- ligne au journal et une annonce.
function hommes.quand_on_lui_parle(id)
  local f = donnees().liste[id]
  if not f then
    return
  end
  jeu().journal("Hommes : Henry parle à « " .. f.nom .. " »")
  annoncer("ui_scriptorium_hommes_vous_ecoute", { complement = f.nom })
end

-- Fiche 18, 5 a : faire venir plusieurs hommes du même contrat (N soldats d'un rang, N archers) ; s'arrête au premier
-- refus. Rend la liste des engagés, et la raison d'un refus.
function hommes.faire_venir_des_hommes(ordre)
  ordre = ordre or {}
  local n = ordre.nombre
  if type(n) ~= "number" or math.floor(n) ~= n or n < 1 or n > hommes.reglages.plafond then
    return {}, "nombre_invalide"
  end
  local engages = {}
  for _ = 1, n do
    local contrat = {}
    for cle, valeur in pairs(ordre) do
      if cle ~= "nombre" then contrat[cle] = valeur end
    end
    local id, raison = hommes.embaucher(contrat)
    if not id then
      return engages, raison
    end
    table.insert(engages, id)
  end
  return engages, nil
end

function hommes.renouveler(id, semaines)
  local d = donnees()
  local f = d.liste[id]
  if not f then
    return refuser("homme_inconnu", tostring(id))
  end
  if type(semaines) ~= "number" or math.floor(semaines) ~= semaines
     or semaines < hommes.reglages.semaines_min or semaines > hommes.reglages.semaines_max then
    return refuser("duree_invalide", tostring(semaines))
  end
  local base = math.max(f.contrat.fin, jeu().heure_du_jeu())
  f.contrat.fin = base + semaines * 7 * 24
  f.contrat.semaines = f.contrat.semaines + semaines
  f.moral = borner(f.moral + 5, 0, 100)
  enregistrer()
  return true
end

function hommes.renvoyer(id)
  local d = donnees()
  local f = d.liste[id]
  if not f then
    return refuser("homme_inconnu", tostring(id))
  end
  faire_partir(d, f, "renvoye", "ui_scriptorium_hommes_parti_renvoye")
  verifier_rangs(d, {})
  enregistrer()
  return true
end

-- Départ pour une cause venue d'ailleurs (« mort » par le morceau 5).
function hommes.retirer(id, cause)
  local d = donnees()
  local f = d.liste[id]
  if not f then
    return refuser("homme_inconnu", tostring(id))
  end
  local cle = (cause == "mort") and "ui_scriptorium_hommes_mort" or nil
  -- Un mort laisse son corps (fiche 17) : rendu en second, pour qui le retirera hors de la vue d'Henry.
  local corps = faire_partir(d, f, cause or "retire", cle, cause == "mort")
  verifier_rangs(d, {})
  enregistrer()
  return true, corps
end

-- ---------------------------------------------------------------- moral et blessures

function hommes.changer_moral(id, delta)
  local f = donnees().liste[id]
  if not f then
    return refuser("homme_inconnu", tostring(id))
  end
  f.moral = borner(f.moral + delta, 0, 100)
  enregistrer()
  return true
end

-- Le même événement pour tous ; une perte de moral pèse selon le sang-froid de chacun (fiche 11).
function hommes.moral_pour_tous(delta)
  local d = donnees()
  for _, id in ipairs(d.ordre) do
    local f = d.liste[id]
    local sa_part = Scriptorium.caractere and Scriptorium.caractere.moral_ajuste(id, delta) or delta
    f.moral = borner(f.moral + sa_part, 0, 100)
  end
  enregistrer()
  return #d.ordre
end

function hommes.blesser(id, jours)
  local f = donnees().liste[id]
  if not f then
    return refuser("homme_inconnu", tostring(id))
  end
  if type(jours) ~= "number" or jours < 1 or math.floor(jours) ~= jours then
    return refuser("jours_invalides", tostring(jours))
  end
  f.blessure = f.blessure + jours
  enregistrer()
  return true
end

-- Ôte des jours de soins (un remède, un barbier).
function hommes.guerir(id, jours)
  local f = donnees().liste[id]
  if not f then
    return refuser("homme_inconnu", tostring(id))
  end
  if type(jours) ~= "number" or jours < 1 or math.floor(jours) ~= jours then
    return refuser("jours_invalides", tostring(jours))
  end
  f.blessure = math.max(0, f.blessure - jours)
  enregistrer()
  return true
end

local function barbier_valide(d)
  for _, id in ipairs(d.ordre) do
    local f = d.liste[id]
    if f.role == "barbier" and f.blessure == 0 then
      return true
    end
  end
  return false
end

-- ---------------------------------------------------------------- garde et activités

local function tranche_de(heure_du_jour)
  for _, t in ipairs(hommes.journee) do
    if t.de < t.a then
      if heure_du_jour >= t.de and heure_du_jour < t.a then return t end
    else
      if heure_du_jour >= t.de or heure_du_jour < t.a then return t end
    end
  end
  return hommes.journee[#hommes.journee]
end

local function dans_la_tranche(t, heure_du_jour)
  if t.de < t.a then
    return heure_du_jour >= t.de and heure_du_jour < t.a
  end
  return heure_du_jour >= t.de or heure_du_jour < t.a
end

-- La nuit : la tranche du sommeil de la journée (22 h - 5 h par défaut ; fiche 16, 3 b). Fiche 19 (A18) : décision
-- remplaçable.
function hommes.est_nuit(heure_du_jour)
  for _, t in ipairs(hommes.journee) do
    if t.activite == "sommeil" and dans_la_tranche(t, heure_du_jour) then
      return true
    end
  end
  return false
end
Scriptorium.remplacable(hommes, "est_nuit", function(rendu) return type(rendu) == "boolean" end)

local function est_nuit(heure_du_jour)
  return Scriptorium.avis(hommes, "est_nuit", heure_du_jour)
end

function hommes.verifier_journee()
  return Scriptorium.journee_valable(hommes.journee)
end

-- Demande de JoVenGer (22/10, transmise par le pair : à 5 h 58, 33 hommes debout au feu ; Scriptorium dit au lit jusqu'à
-- 7 h) : l'horaire est celui de Scriptorium quand il le donne (scriptorium.journee.COUCHER et LEVER) : sommeil de COUCHER
-- à LEVER moins « lever_duree_h », lever jusqu'à LEVER ; la veillée finit au coucher, le repas du matin commence au lever.
-- Sinon, nos tranches (réglables). Une journée qui ne tiendrait plus (Scriptorium.journee_valable) n'est pas posée, une
-- ligne au journal. Rend vrai si la journée a changé.
local horaire_refuse = nil
function hommes.suivre_l_horaire_de_scriptorium()
  local programme = rawget(_G, "scriptorium")
  local j = type(programme) == "table" and type(programme.journee) == "table" and programme.journee or nil
  local h_coucher, h_lever = j and tonumber(j["COUCHER"]), j and tonumber(j["LEVER"])
  if not h_coucher or not h_lever then
    return false
  end
  local duree = tonumber(hommes.reglages.lever_duree_h) or 0
  -- L'aube du socle (contrats, désertions) suit le lever de Scriptorium (accord de JoVenGer, 22/10).
  if hommes.reglages.heure_lever ~= h_lever and h_lever > 0 and h_lever < 24 then
    hommes.reglages.heure_lever = h_lever
    jeu().journal("Hommes : l'aube suit le lever de Scriptorium : " .. h_lever .. " h")
  end
  local voulu = { sommeil = { de = h_coucher, a = h_lever - duree }, lever = { de = h_lever - duree, a = h_lever },
                  veillee = { a = h_coucher }, repas_du_matin = { de = h_lever } }
  local par_nom, avant, change = {}, {}, false
  for _, t in ipairs(hommes.journee) do
    par_nom[t.nom] = t
  end
  for nom, bornes in pairs(voulu) do
    local t = par_nom[nom]
    if not t then
      return false
    end
    avant[nom] = { de = t.de, a = t.a }
    for cle, valeur in pairs(bornes) do
      if t[cle] ~= valeur then
        change = true
      end
    end
  end
  if not change then
    return false
  end
  for nom, bornes in pairs(voulu) do
    for cle, valeur in pairs(bornes) do
      par_nom[nom][cle] = valeur
    end
  end
  local ok, raison = hommes.verifier_journee()
  if not ok then
    for nom, b in pairs(avant) do
      par_nom[nom].de, par_nom[nom].a = b.de, b.a
    end
    local cle = h_coucher .. "/" .. h_lever
    if horaire_refuse ~= cle then
      horaire_refuse = cle
      jeu().journal("Hommes : l'horaire de Scriptorium (coucher " .. h_coucher .. " h, lever " .. h_lever .. " h) ne tient pas dans "
                    .. "la journée (" .. tostring(raison) .. ") : la nôtre reste")
    end
    return false
  end
  horaire_refuse = nil
  jeu().journal("Hommes : horaire de Scriptorium : sommeil de " .. h_coucher .. " h à " .. (h_lever - duree) .. " h, lever jusqu'à "
                .. h_lever .. " h")
  return true
end

-- ---------------------------------------------------------------- l'arbitre des ordres (fiche 15, V73 b 3)

-- Le rang d'une règle au catalogue (1 le plus fort), ou nil : une règle inconnue ne tient personne.
local function rang_de(regle)
  return hommes.priorites[regle]
end

-- Le prochain changement de tranche de la journée après « heure » (heure du jeu, absolue) : la borne d'une tenue posée
-- sans fin (réponse 4 a de JoVenGer, 16/10). La tranche de la nuit passe minuit (22 h → 5 h).
local function prochain_changement_de_tranche(heure)
  local h = heure_dans_le_jour(heure)
  local debut_du_jour = heure - h
  local t = tranche_de(h)
  if t.de < t.a or h < t.a then
    return debut_du_jour + t.a
  end
  return debut_du_jour + 24 + t.a
end

-- La tenue posée la plus forte d'un homme : (règle, tenue, rang). À rang égal, la plus ancienne garde l'homme, puis le nom
-- de la règle (l'ordre de « pairs » n'est pas sûr).
local function tenue_la_plus_forte_du_socle(f)
  local regle_choisie, tenue_choisie, rang_choisi = nil, nil, nil
  for regle, t in pairs(f.tenues or {}) do
    local rang = rang_de(regle)
    if rang then
      local depuis, depuis_choisi = t.depuis or 0, tenue_choisie and (tenue_choisie.depuis or 0)
      if rang_choisi == nil or rang < rang_choisi
          or (rang == rang_choisi and (depuis < depuis_choisi or (depuis == depuis_choisi and regle < regle_choisie))) then
        regle_choisie, tenue_choisie, rang_choisi = regle, t, rang
      end
    end
  end
  return regle_choisie, tenue_choisie, rang_choisi
end

-- Fiche 19 (A7, l'arbitre ; décision remplaçable) : la règle dont la tenue l'emporte sur l'homme, ou faux (aucune).
-- Scriptorium peut en rendre une autre parmi les tenues posées sur l'homme ; une règle qu'il ne porte pas, ou inconnue
-- du catalogue des priorités, laisse la décision du socle.
function hommes.regle_la_plus_forte(id)
  local f = fiche_de(donnees(), id)
  return (f and tenue_la_plus_forte_du_socle(f)) or false
end
Scriptorium.remplacable(hommes, "regle_la_plus_forte", function(rendu) return rendu == false or type(rendu) == "string" end)

local function tenue_la_plus_forte(f)
  local regle = Scriptorium.avis(hommes, "regle_la_plus_forte", f.id)
  local tenue = regle and f.tenues and f.tenues[regle]
  if not regle then
    return nil, nil, nil
  end
  if not tenue or not rang_de(regle) then
    return tenue_la_plus_forte_du_socle(f)
  end
  return regle, tenue, rang_de(regle)
end

-- Exempté de cette règle : par sa fiche (hommes.exempter), ou parce qu'il est de métier (fiche 18, 5 c).
local function exempte(f, regle)
  if f.exemptions and f.exemptions[regle] then
    return true
  end
  local role = hommes.roles[f.role]
  return role ~= nil and role.reserve == "metier" and hommes.exemptions_des_metiers[regle] == 1
end

-- Service pour le guichet et pour les morceaux du socle : l'homme est-il libre pour cette règle ? Il n'en est pas exempté,
-- et aucune règle aussi forte ne le tient (une tenue posée, ou ses blessures : les soins). Une tenue de la même règle ne
-- compte pas : la reposer la met à jour.
function hommes.libre_pour(id, regle)
  local f = donnees().liste[id]
  local rang = rang_de(regle)
  if not f or not rang or exempte(f, regle) then
    return false
  end
  local soins = rang_de("soins")
  if f.blessure > 0 and soins and soins <= rang and regle ~= "bains" then
    return false
  end
  for autre in pairs(f.tenues or {}) do
    local r = rang_de(autre)
    if autre ~= regle and r and r <= rang then
      return false
    end
  end
  return true
end
Scriptorium.remplacable(hommes, "libre_pour", function(rendu) return type(rendu) == "boolean" end)

-- Les hommes de garde à cette heure, en rotation par tour de veille, jamais plus que d'hommes valides. Valide : libre
-- pour la garde de cette heure (« garde_de_nuit » la nuit, dont Scriptorium exempte les compagnons, réponse 3 a du V73 b).
function hommes.gardes(heure)
  local d = donnees()
  local h = heure_dans_le_jour(heure)
  local regle = est_nuit(h) and "garde_de_nuit" or "garde"
  local valides = {}
  for _, id in ipairs(d.ordre) do
    if Scriptorium.avis(hommes, "libre_pour", id, regle) then
      table.insert(valides, id)
    end
  end
  local postes
  if est_nuit(h) then
    postes = math.min(hommes.reglages.postes_garde_nuit, math.floor(#valides / hommes.reglages.hommes_par_poste_nuit))
  else
    postes = math.min(hommes.reglages.postes_garde_jour, math.floor(#valides / hommes.reglages.hommes_par_poste_jour))
  end
  postes = math.min(postes, #valides, #hommes.postes_de_garde)
  local resultat = {}
  if postes == 0 then
    return resultat
  end
  local tour = math.floor(heure / hommes.reglages.duree_tour_de_garde)
  local depart = (tour * postes) % #valides
  for i = 1, postes do
    local id = valides[(depart + i - 1) % #valides + 1]
    table.insert(resultat, { id = id, poste = i })
  end
  return resultat
end
Scriptorium.remplacable(hommes, "gardes", function(rendu) return type(rendu) == "table" end)

-- La bascule (demande du pair, 18/10) : le rang de l'homme pour une place (camp.place_pour) : son rang dans la
-- compagnie pour un siège ; parmi les hommes sans lit à eux pour un lit. Rend nil s'il n'en a pas.
-- Les lits gardés pour la nuit (vu sur une copie de la partie de JoVenGer le 20/10 : deux hommes sur le même lit ; la
-- liste des lits libres ne savait pas qui dormait déjà où, et une déclaration raccourcie entre deux ordres faisait glisser
-- les rangs) : un lit donné au sommeil reste à cet homme jusqu'à son lever ; les autres ne le reçoivent pas. Le choix
-- reste à camp.place_pour (Scriptorium) ; la réservation est ici. En mémoire seulement : refait au rechargement.
hommes.lits_de_nuit = hommes.lits_de_nuit or {}

-- Le lit gardé pour la nuit de cet homme, s'il est encore un lit du camp ; sinon il est rendu.
local function lit_de_nuit(id)
  local lit = hommes.lits_de_nuit[id]
  if lit and camp().sorte_de(lit) ~= "lit" then
    hommes.lits_de_nuit[id] = nil
    lit = nil
  end
  return lit
end

-- Décision de JoVenGer (21/10, transmise par le pair : « Dormir au sol au feu », fiche 15) : faute de lit libre, l'homme
-- dort à terre près du feu. Sa place au sol est gardée toute la nuit (la même à chaque ordre ; il ne la quitte pas pour
-- un lit libéré) : id -> { rang, point }. En mémoire seulement.
hommes.sols_de_nuit = hommes.sols_de_nuit or {}

-- La place au sol de cet homme : la sienne s'il en a une ; sinon la première libre, en rangs de quatre derrière le feu,
-- à l'opposé de son regard. Rend (point, rang), ou nil (sans camp, ou le repli éteint).
local function place_au_sol(d, id)
  local geste = hommes.reglages.sommeil_sol_geste
  if type(geste) ~= "string" or geste == "" then
    return nil
  end
  local garde = hommes.sols_de_nuit[id]
  if garde then
    return garde.point, garde.rang
  end
  local pris = {}
  for autre, s in pairs(hommes.sols_de_nuit) do
    if autre ~= id and d.liste[autre] then
      pris[s.rang] = true
    end
  end
  local rang = 1
  while pris[rang] do
    rang = rang + 1
  end
  local p = hommes.points.feu
  local ecart = tonumber(hommes.reglages.sommeil_sol_ecart_m) or 2
  local colonne, rangee = (rang - 1) % 4, math.floor((rang - 1) / 4)
  local r = math.rad(p.cap or 0)
  local cote, recul = (colonne - 1.5) * ecart, (tonumber(hommes.reglages.sommeil_sol_recul_m) or 3) + rangee * ecart
  local point = camp().point(p.x + cote * math.cos(r) - recul * math.sin(r), p.y - cote * math.sin(r) - recul * math.cos(r),
                             p.cap)
  if not point then
    return nil
  end
  return point, rang
end

-- Le repli au sol dans le résultat de activite_de (l'activité reste la sienne : sommeil, ou repos du blessé). Rend vrai
-- s'il est posé.
local function dormir_au_sol(d, id, resultat)
  local point, rang = place_au_sol(d, id)
  if not point then
    return false
  end
  local geste = hommes.reglages.sommeil_sol_geste
  resultat.lieu, resultat.position, resultat.au_sol, resultat.sol_rang, resultat.geste = "sol_feu", point, true, rang, geste
  resultat.signature = string.format("%s:%d:%d", geste, math.floor(point.x + 0.5), math.floor(point.y + 0.5))
  return true
end

-- Le plus grand nombre de dormeurs au sol de la nuit en cours, gardé au registre.
local function compter_les_dormeurs_au_sol(d)
  local n = 0
  for autre in pairs(hommes.sols_de_nuit) do
    if d.liste[autre] then
      n = n + 1
    end
  end
  if n > (d.sol_max_nuit or 0) then
    d.sol_max_nuit = n
    enregistrer()
  end
end

-- Pour le colonel de Scriptorium (il dit chaque matin combien de lits manquent) : le plus grand nombre d'hommes couchés au
-- sol la nuit passée (arrêté à l'aube), puis celui de la nuit en cours.
function hommes.lits_manquants()
  local d = donnees()
  return d.lits_manquants or 0, d.sol_max_nuit or 0
end

function hommes.rang_pour_une_place(id, sorte)
  local d = donnees()
  local rang = 0
  for _, autre in ipairs(d.ordre) do
    local f = d.liste[autre]
    if sorte ~= "lit" or (f and not f.lit and (autre == id or not hommes.lits_de_nuit[autre])) then
      rang = rang + 1
    end
    if autre == id then
      return rang
    end
  end
  return nil
end

-- La place de l'homme (décision remplaçable camp.place_pour), parmi les places libres de la sorte, sans celles réservées
-- à un autre (vu en jeu le 19/10 : sur un camp sans Directeur, un homme dormait dans le lit du Directeur).
-- Demande du pair (21/10, J15 : quatre dames des bains tenues « assise » sur des rondins déclarés, une debout à côté du
-- sien pendant que les hommes déjeunaient sur les rondins voisins) : les sièges que tient le personnel mené (le lieu de
-- sa tenue la plus forte, une place déclarée de sorte « siege »), sauf pour lui-même.
local function sieges_du_personnel(d, sauf)
  local tenus = {}
  for cle, f in pairs(d.menes or {}) do
    if cle ~= sauf and f.tenues then
      local _, t = tenue_la_plus_forte(f)
      if t and t.lieu and camp().sorte_de(t.lieu) == "siege" then
        tenus[t.lieu] = cle
      end
    end
  end
  return tenus
end

-- Vu sur une copie de la partie de JoVenGer le 21/10 (J28 : 829 refus « place_prise » en dix minutes ; la règle par
-- défaut prend libres[rang], un siège pris ou rendu par une dame faisait glisser les sièges des hommes) : comme les lits
-- de la nuit, le siège donné à un homme pour le repas ou la veillée lui reste tant que dure l'activité ; les autres ne
-- le reçoivent pas. En mémoire seulement : id -> nom du siège.
hommes.sieges_du_moment = hommes.sieges_du_moment or {}

-- Le siège gardé de cet homme, s'il est encore un siège du camp et qu'aucun mené ne le tient ; sinon il est rendu.
local function siege_du_moment(d, id)
  local siege = hommes.sieges_du_moment[id]
  if siege and (camp().sorte_de(siege) ~= "siege" or sieges_du_personnel(d, id)[siege]) then
    hommes.sieges_du_moment[id] = nil
    siege = nil
  end
  return siege
end

local function place_pour(id, sorte)
  local libres = Scriptorium.avis(camp(), "places_libres", sorte, "hommes")
  if sorte == "siege" then
    local d = donnees()
    local tenus, restants = sieges_du_personnel(d, id), {}
    local gardes = {}
    for autre, siege in pairs(hommes.sieges_du_moment) do
      if autre ~= id and d.liste[autre] then
        gardes[siege] = true
      end
    end
    for _, place in ipairs(libres) do
      if not tenus[place] and not gardes[place] then
        table.insert(restants, place)
      end
    end
    libres = restants
  end
  if sorte == "lit" then
    local d, gardes = donnees(), {}
    for autre, lit in pairs(hommes.lits_de_nuit) do
      if autre ~= id and (d.liste[autre] or (d.menes and d.menes[autre])) then
        gardes[lit] = true
      end
    end
    local restants = {}
    for _, lit in ipairs(libres) do
      if not gardes[lit] then
        table.insert(restants, lit)
      end
    end
    libres = restants
  end
  if #libres == 0 then
    return nil
  end
  return Scriptorium.avis(camp(), "place_pour", id, sorte, libres)
end

-- Le factionnaire (fiche 15, V73 d 1) : le point qu'il regarde, à « regard_m » devant son poste. « cap » : cap de
-- boussole en degrés (0 au nord, 90 à l'est, comme tout le socle) ; sans cap, du centre du camp vers le poste, donc vers
-- le dehors. Rend nil sans position, sans cap ni camp, ou pour un poste au centre même du camp : l'ordre est alors une
-- marche simple.
local function regard_du_poste(position, cap)
  local distance = tonumber(hommes.reglages.regard_m) or 0
  if type(position) ~= "table" or distance <= 0 then
    return nil
  end
  local dx, dy
  if type(cap) == "number" then
    dx, dy = math.sin(math.rad(cap)), math.cos(math.rad(cap))
  else
    local centre = camp().point(0, 0, 0)
    if not centre then
      return nil
    end
    local ex, ey = position.x - centre.x, position.y - centre.y
    local longueur = math.sqrt(ex * ex + ey * ey)
    if longueur < 0.1 then
      return nil
    end
    dx, dy = ex / longueur, ey / longueur
  end
  return { x = position.x + distance * dx, y = position.y + distance * dy, z = position.z }
end

-- La ronde (fiche 15, V73 d 2) : un chemin est une liste de 2 à « ronde_points_max » points du monde, chacun avec x et y
-- (z facultatif). Rend une copie, ou (nil, raison).
local function copie_du_chemin(chemin)
  local maxi = tonumber(hommes.reglages.ronde_points_max) or 0
  if type(chemin) ~= "table" or #chemin < 2 or #chemin > maxi then
    return nil, "de 2 à " .. maxi .. " points"
  end
  local copie = {}
  for i = 1, #chemin do
    local p = chemin[i]
    if type(p) ~= "table" or type(p.x) ~= "number" or type(p.y) ~= "number" or (p.z ~= nil and type(p.z) ~= "number") then
      return nil, "point " .. i .. " sans x ou sans y"
    end
    copie[i] = { x = p.x, y = p.y, z = p.z }
  end
  return copie
end

-- Le rassemblement (fiche 15, V73 e) : la place « i » de « n » hommes sur l'arc d'une tenue, et le point qu'elle regarde
-- (le centre, ou le dehors à « regard_m »). Les places s'écartent d'au moins « ecart_entre_hommes » (corde) ; ce qui ne
-- tient pas sur l'arc passe sur un second arc, « ecart_entre_hommes » plus loin, et ainsi de suite.
local function place_sur_l_arc(tenue, i, n)
  local r = hommes.reglages
  local rayon = tonumber(tenue.rayon) or r.rassemblement_rayon_m
  local ouverture = tonumber(tenue.ouverture) or r.rassemblement_ouverture
  local ecart = math.max(0.5, tonumber(r.ecart_entre_hommes) or 1.2)
  local cap = tonumber(tenue.cap) or 0
  local c = tenue.centre
  local rang, restants, arc = i, n, rayon
  local sur_cet_arc
  while true do
    local pas = 2 * math.asin(math.min(1, ecart / (2 * arc)))
    local capacite
    if ouverture >= 360 then
      capacite = math.max(1, math.floor(2 * math.pi / pas + 1e-9))
    else
      capacite = math.floor(math.rad(ouverture) / pas + 1e-9) + 1
    end
    sur_cet_arc = math.min(capacite, restants)
    if rang <= sur_cet_arc then
      break
    end
    rang, restants, arc = rang - sur_cet_arc, restants - sur_cet_arc, arc + ecart
  end
  local angle
  if ouverture >= 360 then
    angle = cap + (rang - 1) * 360 / sur_cet_arc
  elseif sur_cet_arc == 1 then
    angle = cap
  else
    angle = cap - ouverture / 2 + (rang - 1) * ouverture / (sur_cet_arc - 1)
  end
  local dx, dy = math.sin(math.rad(angle)), math.cos(math.rad(angle))
  local position = { x = c.x + arc * dx, y = c.y + arc * dy, z = c.z }
  if tenue.face == "dehors" then
    local d = tonumber(r.regard_m) or 0
    return position, { x = position.x + d * dx, y = position.y + d * dy, z = c.z }
  end
  return position, { x = c.x, y = c.y, z = c.z }
end

-- Retient une somme sur les prochaines soldes (amende).
function hommes.retenir(id, montant)
  local f = donnees().liste[id]
  if not f then
    return refuser("homme_inconnu", tostring(id))
  end
  if type(montant) ~= "number" or montant < 0 then
    return refuser("montant_invalide", tostring(montant))
  end
  f.retenue = (f.retenue or 0) + math.floor(montant)
  enregistrer()
  return true
end

-- L'activité d'un homme à une heure : { regle, activite, lieu, position, cap, fin, regard }. L'arbitre (fiche 15, V73 b 3) : la
-- tenue posée la plus forte, contre les règles que le socle calcule lui-même (les soins d'un blessé, son tour de garde) ;
-- à rang égal, la tenue posée l'emporte (un ordre exprès) ; sinon la journée du socle, ou l'attente si elle est coupée.
-- Le « suivi » à cheval d'un porteur qui a son cheval passager (V73 f 2 b, c ; un homme, ou le Directeur, V73 f 2 e) :
-- son rôle (« mener » et sa formation, « formation », ou rien) et l'approche jusqu'à son cheval (le délai de la monte
-- s'allonge de cette marche) ; nil sans cheval (pas encore né, ou l'abandon après les montes manquées).
local function suivi_a_cheval(cle, personnage, role, formation)
  local m = hommes.montures[cle]
  if not (m and m.cheval and not m.abandon and not m.saut) then
    return nil
  end
  local ici, la = jeu().position_du_personnage(personnage), jeu().position_du_personnage(m.cheval)
  local approche = 0
  if ici and la then
    approche = math.floor(math.min(hommes.reglages.monte_approche_max_ms, 1000
      * math.sqrt((ici.x - la.x) ^ 2 + (ici.y - la.y) ^ 2) / hommes.reglages.monte_approche_m_par_s))
  end
  return { mode = "cheval", cheval = m.cheval, role = role, formation = formation, approche_ms = approche }
end

function hommes.activite_de(id, heure)
  local d = donnees()
  local f = fiche_de(d, id)
  if not f then
    return nil
  end
  local resultat = { activite = nil, lieu = nil, position = nil }
  local regle, tenue, rang = tenue_la_plus_forte(f)
  local soins = rang_de("soins")
  -- Vu sur une copie de la partie de JoVenGer le 21/10 (J3 : un blessé tenu toute la soirée par Scriptorium, jamais au
  -- repos) : les soins passent devant une tenue de même rang, comme dans hommes.libre_pour ; seules les règles plus
  -- fortes (bataille, mission, escorte, rassemblement) passent devant. Sans lit à lui (tous en relève), il se couche à
  -- son lit de la nuit ou à une place libre, gardée comme celle du sommeil. Décision de JoVenGer du 26/09 (« hors
  -- bataille, les blessés vont aux bains ») : la tenue « bains », un ordre exprès, passe devant les soins.
  if f.blessure > 0 and soins and (not rang or soins < rang or (soins == rang and regle ~= "bains")) then
    resultat.regle, resultat.activite = "soins", "repos"
    local lit = f.lit or lit_de_nuit(id) or (not hommes.sols_de_nuit[id] and place_pour(id, "lit")) or nil
    resultat.lieu = lit
    resultat.position = lit and camp().position_de(lit) or nil
    if not lit and hommes.reglages.sommeil_sol_blesses == true then
      dormir_au_sol(d, id, resultat)
    end
    return resultat
  end
  -- Le tour de garde ne prend que des hommes libres pour la garde (aucune tenue aussi forte) : il passe donc devant
  -- leurs tenues, toutes plus faibles.
  for _, g in ipairs(Scriptorium.avis(hommes, "gardes", heure)) do
    if g.id == id then
      local poste = hommes.postes_de_garde[g.poste]
      resultat.regle = est_nuit(heure_dans_le_jour(heure)) and "garde_de_nuit" or "garde"
      resultat.activite = "garde"
      resultat.lieu = "poste_" .. g.poste
      -- V73 d 1 : le cap du poste n'est plus jeté ; le garde se tient face au dehors.
      resultat.position, resultat.cap = camp().point(poste.x, poste.y, poste.cap)
      resultat.regard = regard_du_poste(resultat.position, resultat.cap)
      return resultat
    end
  end
  if tenue then
    resultat.regle, resultat.activite, resultat.lieu = regle, tenue.activite, tenue.lieu
    resultat.position, resultat.cap, resultat.fin = tenue.position, tenue.cap, tenue.fin
    -- Vu sur une copie de la partie de JoVenGer le 20/10 (sonde du pair) : le même geste au même lieu, son point déplacé
    -- de 54 m, gardait la même signature : aucun ordre redonné, l'homme restait à genoux. Le point d'une tenue entre
    -- dans la signature de l'ordre (au mètre) ; les signatures propres (rassemblement, suivre) la remplacent plus bas.
    if type(tenue.position) == "table" and tonumber(tenue.position.x) and tonumber(tenue.position.y) then
      resultat.signature = string.format("%.0f,%.0f", tenue.position.x, tenue.position.y)
    end
    resultat.ne_pas_rhabiller = tenue.ne_pas_rhabiller
    -- V73 d 2 : une ronde suit son chemin, en boucle ou en aller-retour, depuis son point de départ s'il est donné.
    resultat.chemin, resultat.aller_retour, resultat.depart = tenue.chemin, tenue.aller_retour, tenue.depart
    resultat.pauses = tenue.pauses
    -- Demande du pair (20/10) : le sommeil sur un lit nommé ; le lieu (la signature de l'ordre) est ce lit.
    if tenue.lit then
      resultat.lieu, resultat.lit = tenue.lit, tenue.lit
      resultat.position = tenue.position or jeu().position_d_un_objet(tenue.lit)
    end
    -- Fiche 18, 5 c : le geste tenu : son nom (dans le lieu, donc dans la signature de l'ordre) et le point regardé,
    -- à 5 m devant lui selon le cap.
    if tenue.geste then
      hommes.forme_du_geste(tenue, resultat)
    end
    -- La bascule (l'affrontement, 18/10) : la cible, l'arme, la fin ; le lieu nomme la cible (la signature de l'ordre).
    if tenue.activite == "affronter" then
      resultat.cible, resultat.arme, resultat.jusqu_a = tenue.cible, not tenue.mains_nues, tenue.jusqu_a
      resultat.amical = tenue.amical
      resultat.lieu = "affronter/" .. tenue.cible
      resultat.position = (tenue.cible == "henry") and jeu().position_du_joueur() or jeu().position_du_personnage(tenue.cible)
      return resultat
    end
    -- Le tir à la cible (demande du pair, 20/10) : la cible nommée dans le lieu (la signature de l'ordre), le regard sur elle.
    if tenue.activite == "tir" then
      resultat.cible = tenue.cible
      resultat.lieu = (tenue.lieu or "tir") .. "/" .. tostring(tenue.cible)
      resultat.regard = jeu().position_d_un_objet(tenue.cible)
    end
    -- Fiche 18, 5 c, tranche 4 : la station prise par Henry : l'homme cède la place et attend à côté.
    local station = tenue.partage and hommes.stations[tenue.partage]
    if station and station.prise then
      resultat.activite, resultat.lieu = "cede", "cede_" .. tenue.partage
      resultat.position = Scriptorium.avis(hommes, "ou_attendre", id, tenue.partage)
      resultat.geste, resultat.regard, resultat.chemin = nil, nil, nil
      return resultat
    end
    -- Fiche 18, 5 c : au poste de travail, le poste et sa position.
    if tenue.poste then
      resultat.poste = tenue.poste
      -- Le lieu, dans la signature de l'ordre : un autre poste redonne l'ordre (vu en jeu le 17/10 : sans lui, l'homme
      -- passait d'un poste à l'autre sans nouvel ordre).
      resultat.lieu = resultat.lieu or tenue.poste
      local p = camp().poste(tenue.poste)
      resultat.position = resultat.position or (p and p.position)
    end
    -- V73 d 1 : une garde se tient face au dehors (le cap de la tenue, sinon du centre du camp vers le poste).
    if tenue.activite == "garde" then
      resultat.regard = regard_du_poste(tenue.position, tenue.cap)
    end
    -- V73 e : un rassemblement avec un centre donne à chacun sa place sur l'arc, parmi les hommes que tient le même
    -- rassemblement (même lieu), dans l'ordre du camp ; la place entre dans la signature de l'ordre.
    -- V73 f 1 : suivre ; les hommes que tient la même escorte (même lieu), dans l'ordre du camp, forment une colonne :
    -- le premier suit le chef de la tenue (Henry, le Directeur ou un homme), chacun suit le précédent ; le rang entre dans
    -- la signature de l'ordre.
    if tenue.activite == "suivre" then
      -- Fiche 17 : « tete » (le chef d'une mission, le colonel de Scriptorium) passe en tête de sa colonne.
      local membres = {}
      for _, autre in ipairs(ordre_de(d, f)) do
        local _, t2 = tenue_la_plus_forte(fiche_de(d, autre))
        if t2 and t2.activite == "suivre" and t2.lieu == tenue.lieu then
          table.insert(membres, (autre == tenue.tete) and 1 or #membres + 1, autre)
        end
      end
      local rang, nombre, precedent = 0, #membres, nil
      for i, autre in ipairs(membres) do
        if autre == id then
          rang = i
          precedent = membres[i - 1]
        end
      end
      if rang > 0 then
        local chef = nil
        -- V73 f 1 bis : en formation, le chef de formation est le Directeur (chef « directeur ») ou le premier homme ;
        -- les suivants, dans la limite des places du modèle, s'y rangent ; les surnuméraires suivent en chaîne.
        local places = tenue.formation and tonumber(hommes.formations[tenue.formation]) or nil
        -- V73 f 2 e : le Directeur reprend la tête (réglable) : quand il suit Henry en formation, une escorte d'Henry en
        -- formation (chef « henry » ou rien) se range dans sa formation.
        local dir = Scriptorium.directeur
        local du_directeur = tenue.chef == "directeur"
          or (hommes.reglages.directeur_mene_l_escorte == true and tenue.formation ~= nil and tenue.vers == nil
              and (tenue.chef == nil or tenue.chef == "henry") and dir ~= nil and dir.mene_une_formation() == true)
        local premier = du_directeur and 0 or 1
        if places and rang > premier and rang - premier <= places then
          if du_directeur then
            chef = Scriptorium.directeur and Scriptorium.directeur.personnage()
          else
            local tete = membres[1]
            chef = tete and fiche_de(d, tete).personnage
          end
          resultat.suivi = { mode = "formation" }
        elseif places and rang == 1 and not du_directeur then
          resultat.suivi = { mode = "mener", formation = tenue.formation }
        end
        if chef == nil then
          if rang > 1 then
            chef = fiche_de(d, precedent).personnage
          elseif du_directeur then
            chef = Scriptorium.directeur and Scriptorium.directeur.personnage()
          elseif tenue.chef ~= nil and tenue.chef ~= "henry" then
            chef = fiche_de(d, tenue.chef) and fiche_de(d, tenue.chef).personnage
          end
        end
        resultat.chef = chef or "henry"
        -- Fiche 17, 4 b : une colonne qui va à un point ; sa tête mène vers le point, sans chef ; tous en sont marqués
        -- (ni grand saut derrière Henry, ni refaits près de lui).
        if tenue.vers then
          resultat.vers = true
          if chef == nil then
            resultat.chef = nil
            resultat.suivi = resultat.suivi or { mode = "mener", formation = tenue.formation }
          end
        end
        -- V73 f 2 a : à cheval (la sonde) ; l'homme qui a un cheval le monte et suit son chef en selle.
        if tenue.cheval then
          resultat.suivi = { mode = "cheval", cheval = tenue.cheval }
        elseif tenue.a_cheval == true or (tenue.a_cheval == "comme_henry" and hommes.henry_monte == true) then
          -- V73 f 2 b : la sortie à cheval (V73 f 2 d : « comme Henry », tant qu'Henry est retenu monté) ; l'homme qui a son cheval passager le monte, dans son rôle (mener, se ranger,
          -- suivre) ; sans cheval (pas encore né, ou l'abandon après les montes manquées), à pied dans ce rôle.
          local role = resultat.suivi
          resultat.suivi = suivi_a_cheval(id, f.personnage, role and role.mode or nil, role and role.formation or nil)
            or resultat.suivi
        end
        -- Le rôle à cheval et le nom du cheval entrent dans la signature : un cheval né de nouveau redonne l'ordre.
        resultat.signature = rang .. "/" .. nombre .. (resultat.suivi and ("/" .. resultat.suivi.mode) or "")
          .. (resultat.suivi and resultat.suivi.role and ("/" .. resultat.suivi.role) or "")
          .. (resultat.suivi and resultat.suivi.cheval and ("/" .. resultat.suivi.cheval) or "")
        if resultat.suivi then
          resultat.suivi.vers = (resultat.vers and resultat.chef == nil) or nil
        end
        if resultat.vers and resultat.chef == nil then
          resultat.position = { x = tenue.vers.x, y = tenue.vers.y, z = tenue.vers.z }
          -- Vu en jeu le 17/10 : le point changé (l'aller, puis le retour) doit redonner l'ordre à la tête.
          resultat.signature = resultat.signature .. string.format("@%.1f,%.1f", tenue.vers.x, tenue.vers.y)
        else
          resultat.position = (resultat.chef == "henry") and jeu().position_du_joueur()
            or jeu().position_du_personnage(resultat.chef)
        end
      end
    end
    if tenue.activite == "rassemblement" and tenue.centre then
      local rang, nombre = 0, 0
      for _, autre in ipairs(ordre_de(d, f)) do
        local _, t2 = tenue_la_plus_forte(fiche_de(d, autre))
        if t2 and t2.activite == "rassemblement" and t2.centre and t2.lieu == tenue.lieu then
          nombre = nombre + 1
          if autre == id then
            rang = nombre
          end
        end
      end
      if rang > 0 then
        resultat.position, resultat.regard = place_sur_l_arc(tenue, rang, nombre)
        resultat.allure = tenue.allure or "course"
        resultat.signature = rang .. "/" .. nombre
      end
    end
    return resultat
  end
  -- Un mené sans tenue attend : sa journée est celle de Scriptorium, jamais la nôtre.
  if f.mene or hommes.reglages.journee_du_socle == false then
    resultat.regle, resultat.activite = "aucune", "attendre"
    return resultat
  end
  resultat.regle = "journee"
  local tranche = tranche_de(heure_dans_le_jour(heure))
  local activite = tranche.activite
  -- Une place à soi autour d'un point d'activité (fiche 04 ; V72 c : trois hommes au même point) : en rangs de quatre,
  -- à « ecart_entre_hommes » mètres, selon le rang de l'homme au camp.
  local function place_autour(p)
    local rang = 1
    for i, autre in ipairs(d.ordre) do
      if autre == id then rang = i end
    end
    local ecart = tonumber(hommes.reglages.ecart_entre_hommes) or 0
    local colonne, rangee = (rang - 1) % 4, math.floor((rang - 1) / 4)
    -- Vu sur une copie de la partie de JoVenGer le 20/10 (au lever, 17 hommes autour du feu) : les rangs avançaient vers
    -- -y, donc à travers le feu (au point « feu », face au sud) : places inatteignables, hommes téléportés. Les rangs se
    -- placent désormais derrière le premier, à l'opposé du regard (« cap »), les colonnes de côté.
    local r = math.rad(p.cap or 0)
    local cote, recul = (colonne - 1.5) * ecart, rangee * ecart
    return camp().point(p.x + cote * math.cos(r) - recul * math.sin(r), p.y - cote * math.sin(r) - recul * math.cos(r), p.cap)
  end
  -- La veillée est le temps libre : chacun y fait ce que lui dictent sa fatigue et ses envies (fiche 11) ; « le feu »
  -- garde la veillée ordinaire.
  if activite == "veillee" and Scriptorium.caractere then
    local choix = Scriptorium.caractere.choix_du_soir(id, heure)
    if choix == "sommeil" or choix == "entrainement" or choix == "des" then
      activite = choix
    end
  end
  resultat.activite = activite
  if activite == "sommeil" then
    -- La bascule (18/10) : un homme sans lit à lui (sommeil en relève, « un_lit_par_homme » éteint) dort à une place libre ;
    -- faute de place libre, au sol près du feu (décision de JoVenGer du 21/10), gardé jusqu'au lever.
    local lit = f.lit or lit_de_nuit(id) or (not hommes.sols_de_nuit[id] and place_pour(id, "lit")) or nil
    resultat.lieu = lit
    resultat.position = lit and camp().position_de(lit) or nil
    if not lit then
      dormir_au_sol(d, id, resultat)
    end
  elseif activite == "entrainement" or activite == "des" then
    local p = hommes.points[(activite == "des") and "des" or "exercice"]
    resultat.lieu = (activite == "des") and "des" or "exercice"
    resultat.position = place_autour(p)
  elseif activite == "repas" or activite == "veillee" then
    local siege = siege_du_moment(d, id) or place_pour(id, "siege")
    if siege then
      resultat.lieu = siege
      resultat.position = camp().position_de(siege)
    else
      resultat.lieu = "feu_central"
      resultat.position = place_autour(hommes.points.feu)
    end
  elseif activite == "exercice" or activite == "corvee" then
    local p = hommes.points[activite]
    resultat.lieu = activite
    resultat.position = place_autour(p)
  else
    resultat.lieu = "feu_central"
    resultat.position = place_autour(hommes.points.feu)
  end
  return resultat
end
Scriptorium.remplacable(hommes, "activite_de", function(rendu) return type(rendu) == "table" end)

-- ---------------------------------------------------------------- solde, repas, aube

function hommes.payer_la_solde()
  local d = donnees()
  local rapport = { payes = 0, impayes = 0, somme = 0, partis = 0 }
  -- Fiche 16 : la paie est à Scriptorium (la part des missions) ; la solde du socle et le départ pour impayé, éteints.
  if not Scriptorium.actif("solde_de_la_semaine") then
    return rapport
  end
  local partants = {}
  for _, id in ipairs(d.ordre) do
    local f = d.liste[id]
    local montant = solde_hebdomadaire(f)
    -- Une amende retient sur la solde ; ce qui dépasse reste dû.
    if f.retenue and f.retenue > 0 then
      local retenu = math.min(f.retenue, montant)
      montant = montant - retenu
      f.retenue = f.retenue - retenu
    end
    if montant == 0 or coffre().payer(montant, "solde") then
      f.impayes = 0
      f.moral = borner(f.moral + 5, 0, 100)
      rapport.payes = rapport.payes + 1
      rapport.somme = rapport.somme + montant
    else
      f.impayes = f.impayes + 1
      f.moral = borner(f.moral - 20, 0, 100)
      rapport.impayes = rapport.impayes + 1
      if f.impayes >= hommes.reglages.semaines_impayees_max then
        table.insert(partants, f)
      end
    end
  end
  for _, f in ipairs(partants) do
    faire_partir(d, f, "solde_impayee", "ui_scriptorium_hommes_parti_solde")
    rapport.partis = rapport.partis + 1
  end
  if rapport.payes > 0 then
    annoncer("ui_scriptorium_hommes_solde_payee", { complement = rapport.somme .. " groschen" })
  end
  if rapport.impayes > 0 then
    annoncer("ui_scriptorium_hommes_solde_impayee", { importance = "alerte" })
  end
  verifier_rangs(d, rapport)
  enregistrer()
  return rapport
end

-- Le repas du matin d'un jour (« moment » : son heure) : rations selon l'appétit de chacun, soins selon sa forme,
-- puis le compte de la journée passée (fatigue, aguerrissement, fiche 11).
local function repas_du_jour(d, rapport, moment)
  local caractere = Scriptorium.caractere
  local affames, affame = 0, {}
  for _, id in ipairs(d.ordre) do
    local f = d.liste[id]
    local ration = caractere and caractere.ration_de(id, hommes.reglages.ration) or hommes.reglages.ration
    -- Repas du socle coupés (l'entretien est à Scriptorium) : rien n'est pris aux vivres, personne n'a faim ici.
    if Scriptorium.actif("repas_du_socle") then
      if coffre().prelever_reserve("vivres", ration, "repas") then
        f.moral = borner(f.moral + 2, 0, 100)
      else
        f.moral = borner(f.moral - 10, 0, 100)
        affames = affames + 1
        affame[id] = true
      end
    end
  end
  if affames > 0 then
    annoncer("ui_scriptorium_hommes_faim")
  end
  rapport.affames = affames
  -- Soins : un jour de moins, deux avec un barbier valide, selon la forme de chacun.
  local soin = barbier_valide(d) and 2 or 1
  for _, id in ipairs(d.ordre) do
    local f = d.liste[id]
    if f.blessure > 0 then
      local jours = caractere and caractere.jours_de_soin(id, soin) or soin
      f.blessure = math.max(0, f.blessure - jours)
      if f.blessure == 0 then
        rapport.gueris = (rapport.gueris or 0) + 1
      end
    end
  end
  if caractere then
    for _, id in ipairs(d.ordre) do
      local f = d.liste[id]
      local variation = caractere.passer_la_journee(id, moment, affame[id] == true)
      if variation ~= 0 then
        f.moral = borner(f.moral + variation, 0, 100)
      end
    end
  end
end

local function aube_du_jour(d, heure, rapport)
  -- Le compte de la nuit au sol, arrêté pour le colonel (décision de JoVenGer du 21/10) ; les places au sol rendues.
  d.lits_manquants, d.sol_max_nuit = d.sol_max_nuit or 0, 0
  hommes.sols_de_nuit = {}
  enregistrer()
  local partants = {}
  for _, id in ipairs(d.ordre) do
    local f = d.liste[id]
    if Scriptorium.actif("contrats_a_duree") and heure >= f.contrat.fin then
      table.insert(partants, { f = f, cause = "fin_de_contrat", cle = "ui_scriptorium_hommes_parti_fin_contrat" })
    elseif f.moral < hommes.reglages.moral_desertion then
      table.insert(partants, { f = f, cause = "desertion", cle = "ui_scriptorium_hommes_parti_moral" })
    end
  end
  for _, p in ipairs(partants) do
    faire_partir(d, p.f, p.cause, p.cle)
    rapport.partis = (rapport.partis or 0) + 1
  end
end

-- ---------------------------------------------------------------- battement

-- Fait avancer les hommes jusqu'à l'heure du jeu : aubes, repas, paies, puis les ordres.
-- Le suivi des marches, en mémoire seulement (fiche 15 : une position perdue au rechargement ne coûte rien, et le
-- registre reste sous 65 535 octets) : id -> { reste, bloque_s, secours, signale, resume }.
hommes.suivi = {}

-- La ronde de chaque homme (fiche 15, V73 d 2), en mémoire seulement : le cerveau repart de zéro au chargement, et
-- l'ordre redonné repart du point le plus proche. { resume, vise, quitte, sens, pas, arrivees } ; et le hasard des
-- pauses (aucune règle ne dépend de sa suite).
hommes.en_ronde = {}
hommes.hasard_de_la_ronde = nil
-- Les chevaux des sorties (fiche 15, V73 f 2 b), passagers, en mémoire seulement (un rechargement les perd : ils ne sont
-- pas gardés par le jeu, et il en renaît un à l'ordre suivant) : id -> { cheval, essais, abandon, manquees, hors_sortie } ;
-- et le hasard de leurs angles.
hommes.montures = {}
hommes.hasard_des_chevaux = nil
-- Henry à cheval (V73 f 2 d), en mémoire seulement : retenu monté ou non, les lectures « à pied » de suite, la lecture
-- forcée par le poste d'essai (nil : la vraie), la dernière lecture, et la génération de la veille posée.
hommes.henry_monte = false
hommes.henry_pied_lectures = 0
hommes.henry_force = nil
hommes.henry_lu = nil
hommes.veille_d_henry_generation = nil
-- Fiche 15, V73 d 2 bis : pourquoi l'ordre d'un homme est redonné (« rechargement », « secours »), pour l'accroche
-- « ronde_reprise » ; sans raison notée, une règle plus forte l'a tenu puis lâché. En mémoire, effacée à chaque ordre.
hommes.raisons_de_reprise = {}

local function tirer_la_pause()
  if not Scriptorium.hasard_en_ordre(hommes.hasard_de_la_ronde) then
    hommes.hasard_de_la_ronde = Scriptorium.hasard_depuis(7373)
  end
  return Scriptorium.tirer(hommes.hasard_de_la_ronde)
end

-- Le point du chemin le plus proche du personnage (le premier, si rien n'est lisible).
local function point_le_plus_proche(personnage, chemin)
  local choisi, meilleur = 1, nil
  for i, p in ipairs(chemin) do
    local d = jeu().ecart_au_but(personnage, p)
    if d and (meilleur == nil or d < meilleur) then
      choisi, meilleur = i, d
    end
  end
  return choisi
end

-- Service pour la liaison (fiche 15, V73 d 2) : le personnage est arrivé à un point de sa ronde (l'arbre appelle le Lua
-- à chaque point). Rend { point, regard, pause_ms, longue, ici, suivant, pas, ecart } : le point suivant ; le point
-- regardé pendant la pause (vers le dehors, réponse 3 b de JoVenGer ; sans camp, le point suivant) ; la pause ; le point
-- atteint et l'écart de l'homme à ce point. Sinon (nil, raison) : l'arbre garde sa pause par défaut et finit au
-- changement d'ordre.
function hommes.pas_de_ronde(personnage)
  local d = donnees()
  local id = nil
  for _, autre in ipairs(d.ordre) do
    if d.liste[autre].personnage == personnage then
      id = autre
    end
  end
  if not id then
    return nil, "homme inconnu"
  end
  local r = hommes.en_ronde[id]
  local a = Scriptorium.avis(hommes, "activite_de", id, jeu().heure_du_jeu())
  if not r or not a or a.activite ~= "ronde" or type(a.chemin) ~= "table" then
    return nil, "pas de ronde"
  end
  local chemin, n = a.chemin, #a.chemin
  local ici = math.min(r.vise, n)
  local suivant
  if a.aller_retour then
    local sens = r.sens or 1
    if ici + sens > n or ici + sens < 1 then
      sens = -sens
    end
    suivant, r.sens = ici + sens, sens
  else
    suivant = ici % n + 1
  end
  -- Une arrivée vraie (le secours en tient compte) : à moins de « secours_arrivee_m » du point ; une marche abandonnée
  -- passe au point suivant sans compter d'arrivée.
  local ecart = jeu().ecart_au_but(personnage, chemin[ici])
  if ecart and ecart <= hommes.reglages.secours_arrivee_m then
    r.arrivees = (r.arrivees or 0) + 1
  end
  r.quitte, r.vise, r.pas = ici, suivant, (r.pas or 0) + 1
  -- La ronde sans pause (fiche 15, V73 d 2 bis, relecture du pair : la ronde de nuit de Scriptorium, six gardes à
  -- égale distance) : aucun arrêt, aucun demi-tour vers le dehors, le regard vers le point suivant.
  if a.pauses == false then
    return { point = chemin[suivant], regard = chemin[suivant], pause_ms = 0, longue = false, ici = ici,
             suivant = suivant, pas = r.pas, ecart = ecart }
  end
  local reglages = hommes.reglages
  local sur = tonumber(reglages.ronde_longue_sur) or 0
  local longue = sur >= 1 and tirer_la_pause() * sur < 1
  local base = longue and reglages.ronde_longue_ms or reglages.ronde_pause_ms
  local ecart_de_pause = longue and reglages.ronde_longue_ecart_ms or reglages.ronde_pause_ecart_ms
  local pause = math.floor(base + (2 * tirer_la_pause() - 1) * ecart_de_pause + 0.5)
  pause = math.max(tonumber(reglages.ronde_pause_min_ms) or 0, pause)
  return { point = chemin[suivant], regard = regard_du_poste(chemin[ici], nil) or chemin[suivant], pause_ms = pause,
           longue = longue, ici = ici, suivant = suivant, pas = r.pas, ecart = ecart }
end
Scriptorium.remplacable(hommes, "pas_de_ronde")

-- Service pour le guichet (fiche 15, V73 d 2 bis, demandé par le pair : Scriptorium place un garde à égale distance des
-- autres) : où en est la ronde de cet homme, { lieu, vise, quitte, pas, points } ; rien s'il n'est pas de ronde. En
-- mémoire seulement, comme l'état de la ronde.
function hommes.ronde_point(id)
  local r = hommes.en_ronde[id]
  local a = r and Scriptorium.avis(hommes, "activite_de", id, jeu().heure_du_jeu())
  if not a or a.activite ~= "ronde" or type(a.chemin) ~= "table" or r.resume ~= "ronde@" .. tostring(a.lieu) then
    return nil
  end
  return { lieu = a.lieu, vise = r.vise, quitte = r.quitte, pas = r.pas, points = #a.chemin }
end

-- Ce que l'ordre vise (fiche 15, V73 a) : une place du camp (siège, lit) se prend par son objet du jeu ; tout le reste est
-- un point où marcher. Rend (position, objet de la place, sorte de la place).
local function but_de(a)
  -- Fiche 18, 5 c : un poste de travail (ordre 21) : son objet du jeu.
  if a.poste then
    local objet = camp().objet_du_poste(a.poste)
    if objet then
      return a.position, objet, "poste"
    end
    return a.position, nil, nil
  end
  -- Demande du pair (20/10) : un lit nommé, déclaré ou non : l'objet du jeu de ce nom (ordre 11).
  if a.lit then
    return a.position, a.lit, "lit"
  end
  local sorte = a.lieu and camp().sorte_de(a.lieu)
  if sorte and camp().sortes_places[sorte] then
    local objet = camp().objet_du_jeu_de(a.lieu)
    if objet then
      return a.position, objet, sorte
    end
  end
  return a.position, nil, nil
end

-- Le temps de marche jusqu'au but (millisecondes, entier), pour le délai de la marche dans l'arbre ; 0 sans but ou sans
-- position lisible.
function hommes.temps_de_marche_ms(personnage, but)
  local vitesse = tonumber(hommes.reglages.marche_approche_m_par_s) or 0
  local ecart = but and personnage and jeu().ecart_au_but(personnage, but)
  if not ecart or vitesse <= 0 or ecart <= (tonumber(hommes.reglages.marche_sur_place_m) or 0) then
    return 0
  end
  return math.floor(math.min(tonumber(hommes.reglages.marche_approche_max_ms) or 0, 1000 * ecart / vitesse))
end

-- Suivre (fiche 15, V73 f 1) : le rattrapage d'un suiveur, pour les hommes et pour le Directeur (la règle de Scriptorium,
-- « LOIN 60, ARRIERE 4 »). À plus de « suivi_loin_m » de son chef (« henry » ou un personnage), il est posé
-- « suivi_derriere_m » derrière Henry, jamais sous ses yeux, jamais en combat ni en conversation ; il ne compte pas dans
-- « secours_max » (un long trajet en demande plusieurs). Rend vrai s'il est posé.
hommes.rattrapages_en_attente = {}
function hommes.rattraper(personnage, chef, nom)
  local loin = tonumber(hommes.reglages.suivi_loin_m) or 0
  if loin <= 0 or not personnage or not chef then
    return false
  end
  local la = (chef == "henry") and jeu().position_du_joueur() or jeu().position_du_personnage(chef)
  local ecart = la and jeu().ecart_au_but(personnage, la)
  if not ecart or ecart <= loin or jeu().occupation_de(personnage) then
    return false
  end
  return hommes.poser_derriere_henry(personnage, nom, "à " .. string.format("%.0f", ecart) .. " m de son chef")
end
Scriptorium.remplacable(hommes, "rattraper", function(rendu) return type(rendu) == "boolean" end)

-- Posé « suivi_derriere_m » derrière Henry, jamais sous ses yeux (dit une fois qu'il attend). Rend vrai s'il est posé.
function hommes.point_derriere_henry()
  local henry, cap = jeu().position_du_joueur(), jeu().cap_du_joueur()
  if not henry then
    return nil
  end
  local recul = tonumber(hommes.reglages.suivi_derriere_m) or 0
  return { x = henry.x - recul * math.sin(math.rad(cap)), y = henry.y - recul * math.cos(math.rad(cap)), z = henry.z }
end

function hommes.poser_derriere_henry(personnage, nom, motif)
  local ou = hommes.point_derriere_henry()
  if not ou then
    return false
  end
  local recul = tonumber(hommes.reglages.suivi_derriere_m) or 0
  if jeu().henry_voit(ou, hommes.reglages.secours_vue_cos) == true then
    if not hommes.rattrapages_en_attente[personnage] then
      hommes.rattrapages_en_attente[personnage] = true
      jeu().journal("Hommes : « " .. tostring(nom) .. " » à rattraper, mais Henry regarde l'endroit : il attend")
    end
    return false
  end
  hommes.rattrapages_en_attente[personnage] = nil
  jeu().journal("Hommes : « " .. tostring(nom) .. " » " .. motif .. ", rattrapé "
                .. string.format("%g", recul) .. " m derrière Henry : " .. tostring(jeu().poser_en_secours(personnage, ou)))
  return true, ou
end

-- Le secours de l'homme bloqué (réponse 1 de JoVenGer du 16/10) : posé près de son but, jamais dans un meuble (une
-- place s'aborde à l'écart, camp.abord_de), sur une place libre (la liaison), puis son ordre est redonné.
local function secourir(id, f, a, rapport)
  -- La bataille (fiche 17, vu en jeu le 17/10 : Jan, en plein combat au camp de bandits, jugé « bloqué » et reposé au
  -- centre du camp) : un homme qui se bat ne s'approche pas de son point ; jamais secouru, comme pour le gardien ; la
  -- bataille relance elle-même ses figés. De même la fouille, qui laisse un corps pas atteint à temps.
  if a.activite == "bataille" or a.activite == "fouille" then
    return
  end
  -- Suivre (V73 f 1) : pas de secours ordinaire (un suiveur garde un écart constant, il ne « se rapproche » jamais) ;
  -- seulement le rattrapage au-delà de « suivi_loin_m ».
  if a.activite == "suivre" then
    -- V73 f 2 b : un homme à cheval n'est jamais posé seul (il serait séparé de son cheval) ; son cheval le ramène.
    -- V73 f 3 b : sauf le grand saut : il descend d'abord, son ordre redonné à pied.
    if a.suivi and a.suivi.mode == "cheval" then
      if hommes.saut_du_cavalier(id, f.personnage, a.chef, f.nom) then
        f.derniere_activite = nil
      end
      return
    end
    -- En saut, son cheval pas encore retiré : il descend peut-être encore ; jamais posé (la fin du saut s'en charge).
    if hommes.montures[id] and hommes.montures[id].saut and hommes.montures[id].cheval then
      return
    end
    -- En saut et à pied : revenu près de son chef, un nouveau cheval (son ordre redonné).
    if hommes.montures[id] and hommes.montures[id].saut and hommes.saut_du_cavalier(id, f.personnage, a.chef, f.nom) then
      f.derniere_activite = nil
      return
    end
    if a.chef and Scriptorium.avis(hommes, "rattraper", f.personnage, a.chef, f.nom) then
      f.derniere_activite = nil
      if rapport then
        rapport.rattrapages = (rapport.rattrapages or 0) + 1
      end
    end
    return
  end
  -- « Rapproché » : l'écart restant jusqu'au but a baissé (règle de JoVenGer : au moins 1 m en 30 s).
  local but = a.position
  -- La ronde (fiche 15, V73 d 2) : le but est le point visé.
  local r = hommes.en_ronde[id]
  local de_ronde = a.activite == "ronde" and r ~= nil and type(a.chemin) == "table"
  if de_ronde then
    but = a.chemin[math.min(r.vise, #a.chemin)]
  end
  local reste = but and jeu().ecart_au_but(f.personnage, but)
  local s = hommes.suivi[id]
  if not reste or not s then
    return
  end
  -- Un rondier avance tant qu'il arrive à ses points (une arrivée depuis le dernier battement), ou qu'il fait sa pause
  -- au point quitté : son compte repart de zéro.
  if de_ronde then
    local quitte = r.quitte and a.chemin[math.min(r.quitte, #a.chemin)]
    local au_quitte = quitte and jeu().ecart_au_but(f.personnage, quitte)
    if (r.arrivees or 0) ~= (s.arrivees_vues or 0) or (au_quitte and au_quitte <= hommes.reglages.secours_arrivee_m) then
      s.arrivees_vues = r.arrivees or 0
      s.reste, s.bloque_s = reste, 0
      return
    end
  end
  if reste <= hommes.reglages.secours_arrivee_m then
    s.reste, s.bloque_s = reste, 0
    return
  end
  -- Encore à sa place d'avant (assis ou couché) : on attend qu'il se lève, jamais de pose d'un coup.
  local pres = s.assis_a and jeu().ecart_au_but(f.personnage, s.assis_a)
  if pres and pres <= hommes.reglages.secours_assis_m then
    s.reste, s.bloque_s = reste, 0
    return
  end
  -- En combat ou en conversation, il ne se rapproche pas de son but sans être bloqué (fiche 15, V73 b 1) : jamais posé
  -- d'un coup hors de son combat ; son compte repart de zéro quand le jeu le rend.
  if jeu().occupation_de(f.personnage) then
    s.reste, s.bloque_s = nil, 0
    return
  end
  -- Vu sur une copie de la partie de JoVenGer le 21/10 (J26 : Wenzel Vlk assommé à l'exercice, son geste suivant à
  -- 28 m, « figé », relancé deux fois puis téléporté) : un homme assommé ne marche pas ; il n'est jamais jugé bloqué, son
  -- compte repart de zéro quand il se relève.
  if jeu().personnage_inconscient and jeu().personnage_inconscient(f.personnage) == true then
    s.reste, s.bloque_s = nil, 0
    return
  end
  local pas_s = Scriptorium.cadence_du_battement_ms / 1000
  local progres = hommes.reglages.secours_progres_m
  local ici = jeu().position_du_personnage(f.personnage)
  local bouge = ici and s.ici and math.sqrt((ici.x - s.ici.x) ^ 2 + (ici.y - s.ici.y) ^ 2) or nil
  if not s.reste or s.reste - reste >= progres then
    s.bloque_s = 0
  elseif bouge and bouge >= progres then
    -- Il marche sans se rapprocher (un détour, la porte du camp) : pas bloqué ; le temps du détour est compté.
    s.bloque_s = 0
    s.detour_s = (s.detour_s or 0) + pas_s
  else
    s.bloque_s = s.bloque_s + pas_s
  end
  if s.meilleur == nil or reste < s.meilleur - progres then
    s.meilleur, s.detour_s = reste, 0
  end
  if (s.detour_s or 0) >= (tonumber(hommes.reglages.secours_detour_max_s) or math.huge) then
    s.bloque_s = math.max(s.bloque_s, hommes.reglages.secours_delai_s)
  end
  s.reste, s.ici = reste, ici
  -- Trop loin d'un but au camp (V73 e, réponse 1 a du 16/10 revue avec le pair) : le secours n'attend pas le délai ; une
  -- sortie (un but à plus de « secours_loin_camp_m » du centre du camp) n'y est jamais soumise.
  local loin = tonumber(hommes.reglages.secours_loin_m) or 0
  if loin > 0 and reste > loin then
    local centre = camp().point(0, 0, 0)
    local au_camp = centre and math.sqrt((but.x - centre.x) ^ 2 + (but.y - centre.y) ^ 2) <= hommes.reglages.secours_loin_camp_m
    if au_camp then
      s.bloque_s = math.max(s.bloque_s, hommes.reglages.secours_delai_s)
    end
  end
  if s.bloque_s < hommes.reglages.secours_delai_s then
    return
  end
  if s.secours >= hommes.reglages.secours_max then
    if not s.signale then
      s.signale = true
      jeu().journal("Hommes : « " .. f.nom .. " » ne rejoint pas « " .. tostring(a.lieu) .. " » malgré " .. s.secours
                    .. " secours ; laissé où il est")
    end
    return
  end
  local _, objet = but_de(a)
  local ou = (not de_ronde and objet) and camp().abord_de(a.lieu) or but
  -- Jamais sous les yeux d'Henry (V73 e, relecture du pair : la règle de Scriptorium) : il regarde à moins de 60° de
  -- l'endroit, le secours attend le battement suivant ; sans lecture, il pose. Ni là où il réapparaît, ni là où il
  -- disparaît (règle de JoVenGer, 20/10).
  -- (au-delà de « saut_vue_m », un homme ne se voit plus, comme pour le grand saut).
  local henry = jeu().position_du_joueur()
  local vue_m = hommes.reglages.saut_vue_m
  local nuit_m = tonumber(hommes.reglages.secours_vue_nuit_m) or 0
  if nuit_m > 0 and est_nuit(heure_dans_le_jour(jeu().heure_du_jeu())) then
    vue_m = math.min(vue_m, nuit_m)
  end
  local function vu(point)
    if not point then
      return false
    end
    if henry and math.sqrt((point.x - henry.x) ^ 2 + (point.y - henry.y) ^ 2) > vue_m then
      return false
    end
    return jeu().henry_voit(point, hommes.reglages.secours_vue_cos) == true
  end
  local ici_vu = ici and henry and vu(ici)
  if vu(ou) or ici_vu then
    if not s.vu_par_henry then
      s.vu_par_henry = true
      jeu().journal("Hommes : « " .. f.nom .. " » à secourir, mais Henry regarde l'endroit : le secours attend")
    end
    return
  end
  s.vu_par_henry = nil
  s.secours, s.bloque_s = s.secours + 1, 0
  jeu().journal("Hommes : « " .. f.nom .. " » bloqué vers « " .. tostring(a.lieu) .. " » à "
                .. string.format("%.0f", reste) .. " m, secours " .. s.secours .. " : "
                .. tostring(jeu().poser_en_secours(f.personnage, ou)))
  f.derniere_activite = nil
  hommes.raisons_de_reprise[id] = "secours"
  rapport.secours = (rapport.secours or 0) + 1
end

-- Les cerveaux réglés depuis le dernier réveil : { [personnage] = signature des valeurs écrites, ou « refus: » suivi de
-- la signature si l'écriture a échoué (dit une fois au journal, retentée au prochain réveil ou au prochain changement).
hommes.cerveaux_regles = {}

local function signature_du_cerveau()
  local cles = {}
  for cle in pairs(hommes.cerveau) do
    table.insert(cles, cle)
  end
  table.sort(cles)
  local morceaux = {}
  for _, cle in ipairs(cles) do
    table.insert(morceaux, cle .. "=" .. tostring(hommes.cerveau[cle]))
  end
  return table.concat(morceaux, ";")
end

-- Fiche 12 : écrit les valeurs du cerveau chez chaque homme et chez le Directeur dont le personnage est nouveau, ou dont
-- les valeurs ont changé (réglage par fichier). Rend le nombre de cerveaux écrits.
local function regler_les_cerveaux(d)
  local signature = signature_du_cerveau()
  local personnages = {}
  for _, id in ipairs(d.ordre) do
    local f = d.liste[id]
    if f.personnage then
      table.insert(personnages, f.personnage)
    end
  end
  local du_directeur = Scriptorium.directeur and Scriptorium.directeur.personnage()
  if du_directeur then
    table.insert(personnages, du_directeur)
  end
  local ecrits = 0
  for _, qui in ipairs(personnages) do
    local deja = hommes.cerveaux_regles[qui]
    if deja ~= signature and deja ~= "refus:" .. signature then
      local ok, ligne = jeu().regler_le_cerveau(qui, hommes.cerveau)
      jeu().journal("Hommes : cerveau de « " .. tostring(qui) .. " » : " .. tostring(ligne))
      hommes.cerveaux_regles[qui] = ok and signature or ("refus:" .. signature)
      if ok then
        ecrits = ecrits + 1
      end
    end
  end
  return ecrits
end

-- Les compteurs du switch vus au dernier battement, par personnage (en mémoire seulement, remis à zéro au réveil comme
-- le cerveau) : les arrêts du plafond de relances (fiche 15, V73 b 2) ; les fins de combat et les lancements de la vie
-- du camp (la garde de la tenue, fiche 13).
hommes.arrets_vus = {}
hommes.fins_de_combat_vues = {}
hommes.lancements_vus = {}

local COMPTEURS_DU_SWITCH = { "scriptorium_vie_arrets", "scriptorium_fins_de_combat", "scriptorium_essai_rejoint" }

-- Une ligne au journal par hausse du compteur des arrêts, chez chaque homme et chez le Directeur ; un homme équipé dont
-- un combat vient de finir (le signal direct du switch), ou dont la vie du camp a été relancée (le filet), est marqué
-- « à rhabiller » (la garde de la tenue). Le premier relevé après le réveil ne marque personne : le réveil rhabille déjà.
-- Rend (arrêts nouveaux, hommes marqués).
local function surveiller_les_cerveaux(d)
  local suivis = {}
  for _, id in ipairs(d.ordre) do
    local f = d.liste[id]
    if f.personnage then
      table.insert(suivis, { qui = f.personnage, nom = f.nom, fiche = f })
    end
  end
  local du_directeur = Scriptorium.directeur and Scriptorium.directeur.personnage()
  if du_directeur then
    table.insert(suivis, { qui = du_directeur, nom = "Directeur" })
  end
  local nouveaux, marques = 0, 0
  for _, s in ipairs(suivis) do
    local lus = jeu().lire_le_cerveau(s.qui, COMPTEURS_DU_SWITCH)
    local arrets = tonumber(lus.scriptorium_vie_arrets)
    if arrets then
      local vus = hommes.arrets_vus[s.qui] or 0
      if arrets > vus then
        nouveaux = nouveaux + (arrets - vus)
        jeu().journal("Hommes : pouls : relances arrêtées pour « " .. s.nom .. " » (" .. arrets .. " fois depuis le chargement)")
      end
      hommes.arrets_vus[s.qui] = arrets
    end
    local fins, lancements = tonumber(lus.scriptorium_fins_de_combat), tonumber(lus.scriptorium_essai_rejoint)
    local raison = nil
    if fins then
      local vues = hommes.fins_de_combat_vues[s.qui]
      if vues and fins > vues then
        raison = "fin de combat"
      end
      hommes.fins_de_combat_vues[s.qui] = fins
    end
    if lancements then
      local vus = hommes.lancements_vus[s.qui]
      if vus and lancements > vus then
        raison = raison or "vie du camp relancée"
      end
      hommes.lancements_vus[s.qui] = lancements
    end
    if raison and s.fiche and marquer_a_rhabiller(s.fiche) then
      marques = marques + 1
      jeu().journal("Hommes : « " .. s.nom .. " » à rhabiller (" .. raison .. ")")
    end
  end
  return nouveaux, marques
end

-- La sortie à cheval (fiche 15, V73 f 2 b) : la tenue la plus forte de l'homme suit quelqu'un, à cheval.
local function en_sortie_a_cheval(f)
  local _, t = tenue_la_plus_forte(f)
  return t ~= nil and t.activite == "suivre"
    and (t.a_cheval == true or (t.a_cheval == "comme_henry" and hommes.henry_monte == true))
end

local function compter_un_essai(f, m)
  m.essais = m.essais + 1
  if m.essais >= hommes.reglages.monte_essais_max then
    m.abandon = true
    jeu().journal("Hommes : « " .. f.nom .. " » suit à pied jusqu'à la fin de sa sortie (" .. m.essais
                  .. " essai(s) de monte manqué(s))")
  end
end

-- L'étendue du camp réel (même séance, J4) : le cercle de l'enceinte du plan (20 m) ne dit pas le camp de Scriptorium
-- (tentes, clôtures, lits : plus de 50 m) ; c'est le plus loin du centre parmi ce cercle, les meubles du plan, les
-- places déclarées par Scriptorium et ses décors. Rend (centre, rayon, points des objets connus), ou nil sans camp.
local function etendue_du_camp()
  if not (camp().est_fonde and camp().est_fonde()) then
    return nil
  end
  local centre = camp().point(0, 0, 0)
  local enceinte = Scriptorium.enceinte
  local loin = enceinte and enceinte.reglages and tonumber(enceinte.reglages.rayon) or 0
  local objets = {}
  local function compter(p)
    if p and tonumber(p.x) and tonumber(p.y) then
      table.insert(objets, p)
      loin = math.max(loin, math.sqrt((p.x - centre.x) ^ 2 + (p.y - centre.y) ^ 2))
    end
  end
  for _, e in ipairs(camp().plan or {}) do
    compter((camp().point(e.x, e.y, 0)))
  end
  for _, e in ipairs(enceinte and enceinte.plan or {}) do
    compter((camp().point(e.x, e.y, 0)))
  end
  for _, p in ipairs(camp().liste_des_places_declarees and camp().liste_des_places_declarees() or {}) do
    compter(jeu().position_d_un_objet(p.nom))
  end
  for _, decor in pairs(camp().decors and camp().decors() or {}) do
    compter(decor)
  end
  -- Vu sur une copie de la partie de JoVenGer le 21/10 (J5 : une mission lancée avant que Scriptorium redéclare ses
  -- places, au chargement ; le premier cheval de Jan né dans le vrai camp) : la plus grande étendue déjà vue est gardée au
  -- registre, pour ce centre ; elle vaut dès le chargement.
  local d = donnees()
  local connue = d.etendue_du_camp
  if connue and math.sqrt((connue.x - centre.x) ^ 2 + (connue.y - centre.y) ^ 2) > 5 then
    connue = nil
  end
  if connue and connue.rayon > loin then
    loin = connue.rayon
  elseif not connue or loin > connue.rayon + 0.5 then
    d.etendue_du_camp = { x = centre.x, y = centre.y, rayon = loin }
    enregistrer()
    jeu().journal(string.format("Hommes : étendue du camp réel : %.0f m (gardée)", loin))
  end
  return centre, loin, objets
end

hommes.etendue_du_camp = etendue_du_camp

-- Dans le camp réel (à moins de son étendue et « cheval_hors_camp_m ») : jamais de cheval né là, jamais à cheval là.
local function dans_le_camp_reel(point)
  local centre, loin = etendue_du_camp()
  return centre ~= nil and point ~= nil
    and math.sqrt((point.x - centre.x) ^ 2 + (point.y - centre.y) ^ 2) < loin + hommes.reglages.cheval_hors_camp_m
end

-- La place du cheval (V73 f 2 c) : voir les réglages « cheval_* ». Rend (place, refus par raison), ou (nil, refus par
-- raison, vrai si des places bonnes étaient toutes vues d'Henry). Vu sur une copie de la partie de JoVenGer le 20/10
-- (séance J, 7 chevaux nés sur 21 sous ses yeux : toutes les places bonnes vues, la première vue était prise) : jamais
-- de naissance vue ; une place à plus de « saut_vue_m » d'Henry n'est pas vue (comme pour le secours et le grand saut).
local function place_du_cheval(id, ici)
  local r = hommes.reglages
  local function ecart(a, b)
    return ((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2) ^ 0.5
  end
  -- Même séance (J4) : un homme dans le camp réel n'a pas de cheval ; il en sort à pied, son cheval naît près de lui
  -- une fois dehors (quatrième valeur rendue : vrai).
  local centre, loin, objets = etendue_du_camp()
  objets = objets or {}
  if dans_le_camp_reel(ici) then
    return nil, {}, false, true
  end
  local base = ici
  local chevaux = {}
  for autre, m in pairs(hommes.montures) do
    if autre ~= id and m.cheval then
      local la = jeu().position_du_personnage(m.cheval)
      if la then
        table.insert(chevaux, la)
      end
    end
  end
  local henry = jeu().position_du_joueur()
  local refus, vue = {}, false
  for _ = 1, r.cheval_places_essayees do
    local angle = Scriptorium.tirer(hommes.hasard_des_chevaux) * 2 * math.pi
    local p = { x = base.x + r.cheval_distance_m * math.cos(angle), y = base.y + r.cheval_distance_m * math.sin(angle),
                z = base.z }
    local raison = nil
    if centre and ecart(p, centre) < loin + r.cheval_hors_camp_m then
      raison = "camp"
    end
    for _, o in ipairs(objets) do
      if not raison and ecart(p, o) < r.cheval_ecart_meuble_m then
        raison = "meuble"
      end
    end
    for _, c in ipairs(chevaux) do
      if not raison and ecart(p, c) < r.cheval_ecart_cheval_m then
        raison = "cheval"
      end
    end
    if not raison then
      local sol = Scriptorium.avis(jeu(), "sol_de", p, r.cheval_sol_pas_m)
      if sol and type(sol.pente) == "number" and sol.pente > r.cheval_pente_max then
        raison = "pente"
      elseif sol and sol.encombre == true then
        raison = "encombre"
      end
    end
    if raison then
      refus[raison] = (refus[raison] or 0) + 1
    elseif jeu().henry_voit(p, r.secours_vue_cos) ~= true
        or (henry and ecart(p, henry) > r.saut_vue_m) then
      return p, refus
    else
      vue = true
    end
  end
  return nil, refus, vue
end

local function dire_les_refus(refus)
  local morceaux = {}
  for _, raison in ipairs({ "camp", "meuble", "cheval", "pente", "encombre" }) do
    if refus[raison] then
      table.insert(morceaux, refus[raison] .. " " .. raison)
    end
  end
  return #morceaux > 0 and table.concat(morceaux, ", ") or "aucune"
end

-- Le cheval passager de l'homme en sortie à cheval qui n'en a pas de vivant (V73 f 2 b) : sa place (V73 f 2 c) ; une naissance refusée compte comme un essai manqué, une seule fois à la même heure
-- du jeu (la pose d'une tenue ordonne l'homme deux fois). Une ligne au journal.
local function preparer_la_monture(id, f, heure, en_sortie)
  -- Fiche 18, 5 a : les chevaux de la compagnie éteints, chacun sort à pied.
  if not en_sortie or not Scriptorium.actif("chevaux_de_la_compagnie") then
    return
  end
  local m = hommes.montures[id]
  if not m then
    m = { essais = 0 }
    hommes.montures[id] = m
  end
  m.hors_sortie = 0
  m.personnage, m.nom = f.personnage, f.nom
  if m.abandon or m.saut or (m.cheval and jeu().objet_existe(m.cheval)) or m.refus_a == heure then
    return
  end
  m.cheval = nil
  local ici = jeu().position_du_personnage(f.personnage)
  if not ici then
    return
  end
  if not Scriptorium.hasard_en_ordre(hommes.hasard_des_chevaux) then
    hommes.hasard_des_chevaux = Scriptorium.hasard_depuis(5171)
  end
  -- Un cheval laissé (colonne arrêtée, bord du camp) encore monté : le suivant attend qu'il en soit descendu.
  for _, laisse in pairs(hommes.chevaux_laisses) do
    if laisse.cavalier == f.personnage and jeu().cheval_monte(laisse.cheval) == true then
      return
    end
  end
  local place, refus, vu, dans_le_camp = place_du_cheval(id, ici)
  if dans_le_camp then
    if not m.attend_dehors then
      m.attend_dehors = true
      jeu().journal("Hommes : cheval de « " .. f.nom .. " » attendu : hors du camp (il part à pied)")
    end
    return
  end
  m.attend_dehors = nil
  -- Toutes les places bonnes vues d'Henry : pas de cheval à ce battement ; l'homme part à pied vers son but (la sortie
  -- sans cheval) ; le cheval naît au premier battement où une place n'est plus vue. Ni essai manqué, ni refus compté.
  if not place and vu then
    if not m.attend_la_vue then
      m.attend_la_vue = true
      jeu().journal("Hommes : cheval de « " .. f.nom .. " » attendu : Henry regarde (il part à pied)")
    end
    return
  end
  m.attend_la_vue = nil
  -- Un nom par essai : le cheval né de nouveau change la signature de l'ordre ; et par grand saut (V73 f 3 b).
  local cheval = place and jeu().faire_venir_cheval(id .. "_" .. (m.essais + 1) .. (m.sauts and ("_saut" .. m.sauts) or ""),
                                                    place)
  if cheval then
    m.cheval = cheval
    m.manquees = jeu().montes_manquees(f.personnage)
    jeu().journal("Hommes : « " .. f.nom .. " » part à cheval sur « " .. cheval .. " » (essai " .. (m.essais + 1)
                  .. " ; places refusées : " .. dire_les_refus(refus) .. " ; hors de la vue d'Henry)")
  else
    jeu().journal("Hommes : pas de cheval pour « " .. f.nom .. " » (naissance refusée, essai " .. (m.essais + 1)
                  .. " ; places refusées : " .. dire_les_refus(refus or {}) .. ")")
    m.refus_a = heure
    compter_un_essai(f, m)
  end
end

-- Au battement (V73 f 2 b) : la monte manquée d'un homme en sortie (le compte de son cerveau a bougé depuis la naissance
-- du cheval) retire ce cheval ; l'ordre suivant en fait naître un autre, sous le plafond d'essais. Un cheval dont l'homme
-- n'est plus en sortie à cheval est retiré quand l'homme s'en est éloigné, ou au plus tard au
-- « cheval_retrait_battements »-ième battement ; tout de suite si l'homme n'est plus au camp.
-- Le porteur d'une monture (V73 f 2 e) : un homme (sa tenue) ou le Directeur (clé « directeur », son registre). Rend
-- (porteur { personnage, nom }, en sortie à cheval), ou nil.
local function porteur(cle, d)
  if cle == "directeur" then
    local dir = Scriptorium.directeur
    local personnage = dir and dir.personnage()
    if not personnage then
      return nil, false
    end
    return { personnage = personnage, nom = "Directeur" }, dir.en_sortie_a_cheval() == true
  end
  -- Un mené aussi (demande du pair, 20/10 : les sorties de métier à cheval) : sans sa fiche, son cheval était retiré à
  -- chaque battement et refait à l'ordre suivant.
  local f = fiche_de(d, cle)
  return f, f ~= nil and en_sortie_a_cheval(f)
end

-- Services pour le Directeur (V73 f 2 e) : son cheval passager, préparé s'il est en sortie à cheval ; et son « suivi »
-- à cheval dans son rôle, ou nil.
function hommes.preparer_la_monture_du_directeur(heure)
  local p, en_sortie = porteur("directeur", donnees())
  if p then
    preparer_la_monture("directeur", p, heure, en_sortie)
  end
end

function hommes.suivi_du_directeur(role, formation)
  local p, en_sortie = porteur("directeur", donnees())
  if not p or not en_sortie then
    return nil
  end
  return suivi_a_cheval("directeur", p.personnage, role, formation)
end

-- Henry voit-il ce point, pour le saut (V73 f 3 b, relecture du pair) ? Dans son regard (« secours_vue_cos ») et à moins
-- de « saut_vue_m » (au-delà, un cavalier ne se voit plus).
local function sous_les_yeux_d_henry(point)
  local henry = jeu().position_du_joueur()
  if not (point and henry) then
    return false
  end
  if math.sqrt((point.x - henry.x) ^ 2 + (point.y - henry.y) ^ 2) > hommes.reglages.saut_vue_m then
    return false
  end
  return jeu().henry_voit(point, hommes.reglages.secours_vue_cos) == true
end

-- Le grand saut d'un cavalier (V73 f 3 b), vu au battement (le filet ; le bond d'Henry le voit en une seconde) : à plus
-- de « cheval_saut_m » de son chef, le saut rapide est lancé (hommes.lancer_les_sauts) ; un cavalier encore en saut (la
-- pose attendait qu'Henry détourne les yeux), revenu près de son chef (moins de « suivi_loin_m »), finit son saut : un
-- nouveau cheval naît près de lui. Rend vrai si son ordre est à redonner.
function hommes.saut_du_cavalier(cle, personnage, chef, nom)
  local m = hommes.montures[cle]
  if not (m and personnage and chef) then
    return false
  end
  local la = (chef == "henry") and jeu().position_du_joueur() or jeu().position_du_personnage(chef)
  local ecart = la and jeu().ecart_au_but(personnage, la)
  if not ecart then
    return false
  end
  if not m.saut and m.cheval and ecart > hommes.reglages.cheval_saut_m then
    return hommes.lancer_les_sauts() > 0
  end
  if m.saut and ecart < hommes.reglages.suivi_loin_m then
    m.saut, m.saut_ordonne, m.saut_vu, m.sauts = nil, nil, nil, (m.sauts or 0) + 1
    jeu().journal("Hommes : « " .. tostring(nom) .. " » revenu près de son chef : un nouveau cheval")
    return true
  end
  return false
end

-- L'ordre à pied d'un cavalier en saut est donné (son cheval sera retiré après sa descente).
function hommes.ordre_donne_en_saut(cle)
  local m = hommes.montures[cle]
  if m and m.saut then
    m.saut_ordonne = true
  end
end

-- Les chevaux laissés (même séance, J4 : colonne arrêtée à cheval, ou cavalier revenu au bord du camp), en mémoire :
-- cheval -> { cheval, cavalier, nom } ; chacun retiré quand son cavalier en est descendu et s'en est éloigné de plus de
-- « cheval_retrait_m », jamais sous les yeux d'Henry (ou son cavalier disparu).
hommes.chevaux_laisses = hommes.chevaux_laisses or {}

local function laisser_le_cheval(f, m, motif)
  hommes.chevaux_laisses[m.cheval] = { cheval = m.cheval, cavalier = f.personnage, nom = f.nom }
  jeu().journal("Hommes : « " .. f.nom .. " » laisse « " .. m.cheval .. " » (" .. motif .. ") : à pied")
  m.cheval, m.arret = nil, nil
  f.derniere_activite = nil
end

local function retirer_les_chevaux_laisses()
  for cheval, laisse in pairs(hommes.chevaux_laisses) do
    local ici = laisse.cavalier and jeu().position_du_personnage(laisse.cavalier)
    local la = jeu().position_du_personnage(cheval)
    local retirer = not ici or not la
    if not retirer and jeu().cheval_monte(cheval) ~= true then
      retirer = math.sqrt((ici.x - la.x) ^ 2 + (ici.y - la.y) ^ 2) > hommes.reglages.cheval_retrait_m
        and not sous_les_yeux_d_henry(la)
    end
    if retirer then
      if la then
        jeu().retirer_cheval(cheval)
      end
      hommes.chevaux_laisses[cheval] = nil
      jeu().journal("Hommes : cheval laissé « " .. cheval .. " » retiré (« " .. tostring(laisse.nom) .. " » à pied)")
    end
  end
end

-- La garde de la colonne à cheval et le bord du camp (même séance, J4) : un cavalier en sortie dans le camp réel laisse
-- son cheval (il rentre à pied ; aucun essai) ; un cavalier d'une colonne vers un point, arrêté depuis
-- « colonne_arret_battements » battements loin de son but, le laisse aussi (une monte manquée) : un autre cheval naît
-- dehors (ou, au-delà des essais, il finit à pied).
local function garder_le_cavalier(f, m)
  if not (m.cheval and f.personnage) or jeu().cheval_monte(m.cheval) ~= true then
    m.arret = nil
    return
  end
  local ici = jeu().position_du_personnage(f.personnage)
  if not ici then
    return
  end
  local t = nil
  if f.tenues then
    local _
    _, t = tenue_la_plus_forte(f)
  end
  local vers = t and t.vers
  -- Vu sur une copie de la partie de JoVenGer le 21/10 (J7 : Jan, posé au bord du camp, son but à 1,9 km, descendait) :
  -- seul un cavalier dont le but est DANS le camp réel (un retour ; l'escorte d'Henry dans le camp) y laisse son cheval.
  local but = vers
  if not but and t and t.activite == "suivre" and (t.chef == nil or t.chef == "henry") then
    but = jeu().position_du_joueur()
  end
  if dans_le_camp_reel(ici) and but and dans_le_camp_reel(but) then
    laisser_le_cheval(f, m, "au bord du camp")
    return
  end
  if not vers then
    m.arret = nil
    return
  end
  local a = m.arret
  if not (a and math.sqrt((ici.x - a.x) ^ 2 + (ici.y - a.y) ^ 2) < hommes.reglages.fige_bouge_m) then
    m.arret = { x = ici.x, y = ici.y, compte = 0 }
    return
  end
  a.compte = a.compte + 1
  local reste = math.sqrt((ici.x - vers.x) ^ 2 + (ici.y - vers.y) ^ 2)
  if a.compte >= hommes.reglages.colonne_arret_battements and reste > hommes.reglages.colonne_arrivee_m then
    jeu().journal(string.format("Gardien : colonne de « %s » arrêtée à cheval à %.0f m de son but", f.nom, reste))
    laisser_le_cheval(f, m, "colonne arrêtée")
    compter_un_essai(f, m)
  end
end

local function veiller_aux_montures(d)
  retirer_les_chevaux_laisses()
  for id, m in pairs(hommes.montures) do
    local f, en_sortie = porteur(id, d)
    -- V73 f 3 b : le filet, si la minuterie du saut n'a pas tiré : un cavalier en saut a eu un battement entier pour
    -- descendre depuis son ordre à pied (vu deux fois ici) : son cheval est retiré.
    if m.saut and m.saut_ordonne and m.cheval then
      m.saut_vu = (m.saut_vu or 0) + 1
    end
    if m.saut and m.saut_ordonne and m.cheval and m.saut_vu >= 2 then
      local monte = jeu().cheval_monte(m.cheval)
      if monte == true then
        m.saut, m.saut_ordonne, m.saut_vu = nil, nil, nil
        jeu().journal("Hommes : « " .. tostring(f and f.nom or id) .. " » toujours en selle : saut abandonné, il rejoint à cheval")
        if f then
          f.derniere_activite = nil
        end
      elseif monte == false and not sous_les_yeux_d_henry(jeu().position_du_personnage(m.cheval)) then
        jeu().retirer_cheval(m.cheval)
        jeu().journal("Hommes : cheval « " .. m.cheval .. " » retiré (grand saut de « " .. tostring(f and f.nom or id) .. " »)")
        m.cheval = nil
      end
    end
    if f and f.personnage and en_sortie then
      garder_le_cavalier(f, m)
      local n = jeu().montes_manquees(f.personnage)
      if m.cheval and n and m.manquees and n > m.manquees then
        jeu().retirer_cheval(m.cheval)
        jeu().journal("Hommes : « " .. f.nom .. " » n'a pas pu monter « " .. m.cheval .. " » (essai " .. (m.essais + 1)
                      .. " sur " .. hommes.reglages.monte_essais_max .. ") : cheval retiré")
        m.cheval = nil
        compter_un_essai(f, m)
      end
      if n then
        m.manquees = n
      end
    else
      m.hors_sortie = (m.hors_sortie or 0) + 1
      -- Demande du pair (20/10) : un mené lâché (sa fiche oubliée) en pleine sortie garde son cheval jusqu'à ce qu'il en
      -- soit descendu, comme nos hommes : son personnage et son nom sont gardés avec sa monture.
      local cavalier = (f and f.personnage) or m.personnage
      local nom = (f and f.nom) or m.nom or tostring(id)
      local retirer = not cavalier or not m.cheval
        or m.hors_sortie >= hommes.reglages.cheval_retrait_battements
      if not retirer then
        local ici = jeu().position_du_personnage(cavalier)
        local la = jeu().position_du_personnage(m.cheval)
        retirer = not ici or not la
          or math.sqrt((ici.x - la.x) ^ 2 + (ici.y - la.y) ^ 2) > hommes.reglages.cheval_retrait_m
      end
      -- V73 f 3 b (vu en séance ; la règle du pair : jamais un cheval retiré sous son cavalier) : encore en selle (lu),
      -- le cheval attend le battement suivant.
      if retirer and m.cheval and cavalier and jeu().cheval_monte(m.cheval) == true then
        retirer = false
        jeu().journal("Hommes : cheval « " .. m.cheval .. " » encore monté par « " .. nom .. " » : retiré plus tard")
      end
      if retirer then
        if m.cheval then
          jeu().retirer_cheval(m.cheval)
          jeu().journal("Hommes : cheval « " .. m.cheval .. " » retiré, la sortie de « " .. nom .. " » finie")
        end
        hommes.montures[id] = nil
      end
    end
  end
end

-- L'ordre d'un homme, seulement quand son activité change : un geste (fiche 15, V73 a), plus de téléportation ; sinon,
-- au battement, le secours de l'homme bloqué. « sans_secours » : l'ordre redonné sur-le-champ par l'arbitre, hors
-- battement (V73 b 3), ne compte pas le temps du secours (il avance d'un battement à chaque appel). « a_la_pose » :
-- l'ordre donné quand la tenue est posée (la ronde part alors de son point de départ, fiche 15, V73 d 2).
-- La signature d'un ordre : l'activité, le lieu, la signature propre (la place d'un rassemblement, le point d'une tenue).
-- Prouvé en jeu le 22/10 par le pair (le lit 54 retiré et reposé neuf sous le même nom pendant que l'armurier y dormait :
-- debout à côté, aucun ordre redonné ; de même les dames, leurs lits déplacés pendant la nuit) : la signature porte aussi
-- l'identité réelle de l'objet du lieu (lit, siège, poste) et de l'ancre d'un geste ; une place refaite redonne l'ordre.
local function identite_de_l_objet(nom)
  if type(nom) ~= "string" or not jeu().identite_d_un_objet then
    return nil
  end
  return jeu().identite_d_un_objet(nom)
end

-- L'objet du monde d'une place : celui du camp pour une place du plan ou déclarée ; sinon (vu en jeu le 22/10 : les lits
-- posés par l'éditeur de Scriptorium ne sont pas des places du camp, camp.sorte_de rend nil) l'objet de ce nom, s'il
-- existe dans le monde.
local function objet_de_la_place(nom)
  if type(nom) ~= "string" then
    return nil
  end
  local objet = camp().sorte_de(nom) and camp().objet_du_jeu_de(nom) or nil
  if not objet and jeu().objet_existe and jeu().objet_existe(nom) then
    objet = nom
  end
  return objet
end

local function resume_de(a)
  local resume = a.activite .. "@" .. tostring(a.lieu) .. (a.signature and ("#" .. a.signature) or "")
  local place = identite_de_l_objet(objet_de_la_place(a.lieu))
  local ancre = a.siege and identite_de_l_objet(hommes.objet_d_ancrage(a.siege) or objet_de_la_place(a.siege)) or nil
  if place then
    resume = resume .. "#o" .. place
  end
  if ancre then
    resume = resume .. "#a" .. ancre
  end
  return resume
end

-- Vu en J32 (24/10, mesuré par le pair : 38 « figés » à la fin du repas, des hommes pas encore partis) : les nouveaux
-- ordres de la journée sont échelonnés, « ordres_par_seconde » par seconde ; rend le délai (secondes) du prochain
-- créneau, 0 tout de suite. En mémoire : le prochain créneau libre, et les hommes dont l'ordre attend (id -> heure réelle
-- prévue).
hommes.prochain_creneau = nil
hommes.ordres_differes = hommes.ordres_differes or {}

local function creneau_d_ordre()
  local par_seconde = tonumber(hommes.reglages.ordres_par_seconde) or 0
  local t = jeu().maintenant and jeu().maintenant()
  if par_seconde <= 0 or type(t) ~= "number" then
    return 0
  end
  local prochain = math.max(hommes.prochain_creneau or t, t)
  hommes.prochain_creneau = prochain + 1 / par_seconde
  return prochain - t
end

local function ordonner_un_homme(d, id, heure, rapport, sans_secours, a_la_pose, echelonne)
  local f = fiche_de(d, id)
  if not f or not f.personnage then
    return
  end
  -- Fiche 18, 5 b : reposé à chaque battement (une entité refaite au chargement perd « Parler »).
  if f.parlable and jeu().rendre_parlable then
    jeu().rendre_parlable(f.personnage, true)
  end
  preparer_la_monture(id, f, heure, en_sortie_a_cheval(f))
  local a = Scriptorium.avis(hommes, "activite_de", id, heure)
  if a and (a.activite == "sommeil" or a.activite == "repos") and a.lieu and camp().sorte_de(a.lieu) == "lit" and not f.lit then
    hommes.lits_de_nuit[id] = a.lieu
  elseif a and a.activite ~= "sommeil" and a.activite ~= "repos" then
    hommes.lits_de_nuit[id] = nil
  end
  -- Le siège du repas ou de la veillée (vu le 21/10, J28) : gardé tant que dure l'activité.
  if a and (a.activite == "repas" or a.activite == "veillee") and a.lieu and camp().sorte_de(a.lieu) == "siege" then
    hommes.sieges_du_moment[id] = a.lieu
  elseif a and a.activite ~= "repas" and a.activite ~= "veillee" then
    -- Vu en J33 (25/10, demande de JoVenGer) : un ordre de Scriptorium en plein repas (usage, ordre de mission) lui
    -- faisait perdre son siège ; revenu au repas, il en recevait un autre, à travers le camp. Le siège lui reste tant
    -- que dure le repas ou la veillée de la journée, sauf s'il va dormir.
    local tranche = tranche_de(heure_dans_le_jour(heure)).activite
    if a.activite == "sommeil" or a.activite == "repos" or (tranche ~= "repas" and tranche ~= "veillee") then
      hommes.sieges_du_moment[id] = nil
    end
  end
  -- Le sommeil au sol (décision de JoVenGer du 21/10) : sa place gardée pour la nuit, et comptée pour le colonel.
  if a and a.au_sol then
    hommes.sols_de_nuit[id] = { rang = a.sol_rang, point = a.position }
    compter_les_dormeurs_au_sol(d)
  elseif a and a.activite ~= "sommeil" and a.activite ~= "repos" then
    hommes.sols_de_nuit[id] = nil
  end
  -- Fiche 20 : une parole demandée : jouée (au plus une fois), puis oubliée ; elle attend en combat, en bataille, au lit.
  local parole = hommes.paroles[id]
  if parole then
    local lus = jeu().lire_le_cerveau(f.personnage, { "scriptorium_parole_jouee" })
    local jouees = tonumber(lus.scriptorium_parole_jouee) or 0
    if parole.ordonnee and jouees > parole.jouees_avant then
      jeu().journal("Hommes : « " .. f.nom .. " » a dit « " .. tostring(parole.alias or parole.metarole) .. " »")
      hommes.paroles[id] = nil
      parole = nil
    elseif heure > parole.depuis + (tonumber(hommes.reglages.parole_attente_max_h) or 0) then
      jeu().journal("Hommes : « " .. f.nom .. " » n'a pas pu dire « " .. tostring(parole.alias or parole.metarole) .. " » : oubliée")
      hommes.paroles[id] = nil
      parole = nil
    elseif Scriptorium.avis(hommes, "peut_parler", id, hommes.parole_de(id), a) then
      local partenaire = parole.partenaire and fiche_de(d, parole.partenaire)
      a = { activite = "parole", lieu = "parole_" .. parole.numero, regle = "parole", parole = parole,
            partenaire = partenaire and partenaire.personnage or nil }
      parole.ordonnee = true
    end
  end
  -- Fiche 18, 5 c : le geste tenu, donné avant l'ordre.
  if a and a.parole and jeu().donner_la_parole then
    jeu().donner_la_parole(f.personnage, hommes.sortes_de_paroles[a.parole.sorte], a.parole.alias, a.parole.metarole,
                           a.partenaire)
  end
  if a and a.geste and jeu().donner_le_geste then
    local ancre = a.siege and hommes.objet_d_ancrage(a.siege) or nil
    local assis = a.assis
    if assis == nil and a.siege then
      assis = camp().sorte_de(a.siege) == "siege"
    end
    jeu().donner_le_geste(f.personnage, a.geste, { ancre = ancre, assis = assis == true, arme = a.arme_tiree == true })
  end
  -- Le tir à la cible (demande du pair, 20/10) : la cible donnée avant l'ordre.
  if a and a.activite == "tir" and jeu().donner_la_cible_du_tir then
    jeu().donner_la_cible_du_tir(f.personnage, a.cible)
  end
  -- La place d'un rassemblement (V73 e) entre dans la signature : une place qui change redonne l'ordre.
  local resume = resume_de(a)
  -- Vu en J32 (24/10) : un nouvel ordre de la journée attend son créneau (une seule attente par homme ; une attente
  -- perdue, au-delà de cinq secondes de retard, est reprise).
  if f.derniere_activite ~= resume and a.regle == "journee" and not sans_secours and not a_la_pose and not echelonne then
    local t = jeu().maintenant and jeu().maintenant()
    local attend = hommes.ordres_differes[id]
    if attend and type(t) == "number" and t <= attend + 5 then
      return
    end
    local delai = creneau_d_ordre()
    if delai > 0 and jeu().minuterie then
      hommes.ordres_differes[id] = (type(t) == "number" and t or 0) + delai
      local generation = Scriptorium.generation
      jeu().minuterie(math.floor(delai * 1000 + 0.5), function()
        hommes.ordres_differes[id] = nil
        if generation ~= Scriptorium.generation then
          return
        end
        ordonner_un_homme(donnees(), id, jeu().heure_du_jeu(), nil, false, false, true)
      end)
      return
    end
  end
  hommes.ordres_differes[id] = nil
  if f.derniere_activite ~= resume then
    -- Vu en jeu le 19/10 : l'attaque d'un affrontement ne finit qu'à la chute de la cible ; à la fin de la tenue (ou
    -- pour toute autre activité), elle est levée avant le nouvel ordre, sinon Henry reste en combat.
    if a.activite ~= "affronter" and f.derniere_activite and string.find(f.derniere_activite, "^affronter@")
        and jeu().cesser_l_attaque then
      jeu().journal("Hommes : « " .. f.nom .. " » cesse d'affronter : " .. tostring(jeu().cesser_l_attaque(f.personnage)))
      -- Vu sur une copie de la partie de JoVenGer le 19/10 : levée ainsi, l'attaque ne compte plus de « fin de combat »
      -- au cerveau, et l'homme, déshabillé par le combat, n'était plus remis à rhabiller (torse nu).
      if marquer_a_rhabiller(f) then
        jeu().journal("Hommes : « " .. f.nom .. " » à rhabiller (fin d'affrontement)")
      end
    end
    local position, objet, sorte = but_de(a)
    -- La ronde (fiche 15, V73 d 2) : à la pose de la tenue, le point de départ (Scriptorium espace ses gardes, réponse
    -- 2 a de JoVenGer) ; sinon, et ensuite (rechargement, secours, reprise après une règle plus forte), le point le plus
    -- proche de l'homme : les gardes restent espacés, aucun ne retraverse le camp.
    -- La reprise (V73 d 2 bis, réponse 1 a de JoVenGer) : tout ordre de ronde qui n'est pas donné à la pose de sa tenue
    -- demande le point à l'accroche « ronde_reprise », avec le point le plus proche (le défaut), le point visé avant la
    -- reprise (rien après un rechargement) et la raison ; une ligne au journal.
    if a.activite == "ronde" and type(a.chemin) == "table" then
      local avant = hommes.en_ronde[id]
      local premier
      if a_la_pose and a.depart then
        premier = a.depart
      else
        premier = point_le_plus_proche(f.personnage, a.chemin)
        if not a_la_pose then
          local n = #a.chemin
          local raison = hommes.raisons_de_reprise[id] or "regle_plus_forte"
          local precedent = (avant and avant.resume == resume) and avant.vise or nil
          local donne = demander("ronde_reprise", function(k)
            return type(k) == "number" and k == math.floor(k) and k >= 1 and k <= n
          end, id, { lieu = a.lieu, plus_proche = premier, points = n, precedent = precedent, raison = raison })
          jeu().journal("Hommes : « " .. f.nom .. " » reprend la ronde « " .. tostring(a.lieu) .. " » au point "
                        .. (donne or premier) .. " (" .. (donne and "donné par l'accroche" or "le plus proche") .. ", "
                        .. raison .. ")")
          premier = donne or premier
        end
      end
      hommes.en_ronde[id] = { resume = resume, vise = premier, sens = 1, pas = 0, arrivees = 0 }
      position = a.chemin[premier]
    end
    hommes.raisons_de_reprise[id] = nil
    if a.activite == "affronter" then
      -- L'attaque imposée à ce personnage (l'interruption d'attaque, comme la bataille), jamais une bataille.
      jeu().journal("Hommes : « " .. f.nom .. " » affronte « " .. tostring(a.cible) .. " » (" .. (a.arme and "à l'arme" or "à mains nues")
                    .. ", " .. (a.amical and "assaut amical" or ("jusqu'à " .. tostring(a.jusqu_a))) .. ") : "
                    .. tostring(jeu().ordonner_l_attaque(a.cible, f.personnage, { arme = a.arme, amical = a.amical == true })))
    else
      -- Vu en J34 (25/10 ; prouvé par le pair) : après un combat, un homme encore en arme refusait son lit. À chaque ordre
      -- de la vie du camp (et donc à la relance du gardien, et après la fin d'un affrontement), son arme est rangée s'il
      -- l'a tirée hors de tout combat ; jamais pour le tir ni le geste armé.
      if a.activite ~= "tir" and not a.arme_tiree and jeu().ranger_l_arme_au_repos
          and jeu().ranger_l_arme_au_repos(f.personnage) then
        jeu().journal("Hommes : « " .. f.nom .. " » range son arme (" .. tostring(a.activite) .. ")")
      end
      -- Le sommeil au sol se joue comme un geste tenu à son point (ordre 22) ; l'activité reste « sommeil ».
      jeu().ordonner(f.personnage, a.au_sol and "geste" or a.activite, position, a.lieu, objet, sorte, a.regard, a.allure,
                     a.chef, a.suivi, hommes.temps_de_marche_ms(f.personnage, position))
    end
    hommes.ordre_donne_en_saut(id)
    -- La garde de la tenue (fiche 13, proposé par le pair) : à la sortie du lit, l'homme est marqué « à rhabiller ».
    local ancien_lieu = f.derniere_activite and string.match(f.derniere_activite, "@([^#]+)")
    if ancien_lieu and camp().sorte_de(ancien_lieu) == "lit" and not (a.lieu and camp().sorte_de(a.lieu) == "lit") then
      marquer_a_rhabiller(f)
    end
    -- Demande de JoVenGer (22/10 : « plus aucun soldat sans équipement » ; Beneš le Rouge suivait Henry sans son
    -- équipement) : un homme qui reçoit un nouvel ordre hors du lit (lever, escorte, ronde, chargement) et reste à
    -- rhabiller ou à équiper est habillé tout de suite, son second passage deux secondes après, sans attendre le
    -- battement ; jamais en bataille, ni tenu dévêtu (le bain), ni en combat ou en conversation (la file le reprendra).
    local e = f.equipement
    if e and (e.etat == "a_rhabiller" or e.etat == "a_equiper") and not en_bataille()
        and not (a.lieu and camp().sorte_de(a.lieu) == "lit") and not a.ne_pas_rhabiller
        and not jeu().occupation_de(f.personnage) then
      if e.etat == "a_equiper" then
        equiper(d, f)
      else
        rhabiller(d, f)
      end
      if f.equipement and f.equipement.etat == "a_completer" then
        second_passage_differe(f)
      end
      -- La file du battement ne le reprend pas dans ce battement (son second passage vient après).
      hommes.habilles_hors_file[id] = true
    end
    f.derniere_activite = resume
    local garde = hommes.suivi[id]
    hommes.suivi[id] = { reste = nil, bloque_s = 0, secours = (garde and garde.resume == resume) and garde.secours or 0,
                         signale = garde and garde.resume == resume and garde.signale or nil, resume = resume,
                         place_position = objet and position or nil,
                         assis_a = garde and (garde.place_position or garde.assis_a) or nil }
    if rapport then
      rapport.ordres = rapport.ordres + 1
    end
  elseif not sans_secours then
    secourir(id, f, a, rapport)
  end
end

-- Henry à cheval (fiche 15, V73 f 2 d, principe transmis par le pair) : monté, tout de suite ; à pied, après
-- « henry_descente_lectures » lectures de suite (l'anti-rebond : une lecture « monté » remet le compte à zéro) ; une
-- lecture illisible ne change rien. À chaque changement, une ligne au journal et l'ordre redonné aux hommes dont
-- l'escorte suit Henry « comme Henry » ; à la descente, l'abandon des montes manquées est oublié. Rend la lecture.
-- Le saut rapide (V73 f 3 b, relecture du pair). Les cavaliers en sortie à plus de « cheval_saut_m » de leur chef, et
-- ceux qui suivent l'un d'eux (la colonne saute ensemble), sont mis en saut : leur ordre est redonné à pied tout de suite
-- (ils descendent) ; « saut_descente_ms » plus tard, hommes.finir_les_sauts. Les chefs sont lus avant tout saut. Rend le
-- nombre de cavaliers mis en saut.
local function redonner_l_ordre(d, cle, heure)
  if cle == "directeur" then
    if Scriptorium.directeur then
      Scriptorium.directeur.redonner_l_ordre()
    end
  elseif d.liste[cle] then
    d.liste[cle].derniere_activite = nil
    ordonner_un_homme(d, cle, heure, nil, true)
  end
end

-- La relecture des poses, après « ms » ; seulement dans la même partie.
local function programmer_la_relecture(ms)
  local generation = Scriptorium.generation
  jeu().minuterie(ms, function()
    if generation == Scriptorium.generation and Scriptorium.en_partie then
      local ok, erreur = pcall(hommes.relire_les_poses)
      if not ok then
        jeu().journal("Hommes : relecture des poses en erreur : " .. tostring(erreur))
      end
    end
  end)
end

-- La fin des sauts, « essai » (1 au premier passage), après « ms » ; seulement dans la même partie.
local function programmer_la_fin(essai, ms)
  local generation = Scriptorium.generation
  jeu().minuterie(ms, function()
    if generation == Scriptorium.generation and Scriptorium.en_partie then
      local ok, erreur = pcall(hommes.finir_les_sauts, essai)
      if not ok then
        jeu().journal("Hommes : fin des sauts en erreur : " .. tostring(erreur))
      end
    end
  end)
end

function hommes.lancer_les_sauts()
  local d = donnees()
  local heure = jeu().heure_du_jeu()
  local candidats, par_personnage = {}, {}
  for cle, m in pairs(hommes.montures) do
    local f, en_sortie = porteur(cle, d)
    if f and f.personnage and en_sortie and m.cheval and not m.saut and not m.abandon then
      local a
      if cle == "directeur" then
        a = Scriptorium.avis(Scriptorium.directeur, "activite", heure)
      else
        a = Scriptorium.avis(hommes, "activite_de", cle, heure)
      end
      if a and a.activite == "suivre" and a.chef and not a.vers and a.suivi and a.suivi.mode == "cheval" then
        if sous_les_yeux_d_henry(jeu().position_du_personnage(f.personnage)) then
          jeu().journal("Hommes : « " .. tostring(f.nom) .. " » sous les yeux d'Henry : pas de saut, il rejoint à cheval")
        else
          candidats[cle] = { f = f, chef = a.chef }
          par_personnage[f.personnage] = cle
        end
      end
    end
  end
  local sautent = {}
  for cle, c in pairs(candidats) do
    local la = (c.chef == "henry") and jeu().position_du_joueur() or jeu().position_du_personnage(c.chef)
    local ecart = la and jeu().ecart_au_but(c.f.personnage, la)
    if ecart and ecart > hommes.reglages.cheval_saut_m then
      sautent[cle] = "à " .. string.format("%.0f", ecart) .. " m de son chef"
    end
  end
  local change = true
  while change do
    change = false
    for cle, c in pairs(candidats) do
      local devant = par_personnage[c.chef]
      if not sautent[cle] and devant and sautent[devant] then
        sautent[cle], change = "suit « " .. tostring(candidats[devant].f.nom) .. " »", true
      end
    end
  end
  local n = 0
  for cle, motif in pairs(sautent) do
    local m = hommes.montures[cle]
    m.saut, m.saut_ordonne, m.saut_vu = true, nil, nil
    n = n + 1
    jeu().journal("Hommes : « " .. tostring(candidats[cle].f.nom) .. " » " .. motif .. " : il descend (grand saut)")
    redonner_l_ordre(d, cle, heure)
  end
  if n > 0 then
    programmer_la_fin(1, hommes.reglages.saut_descente_ms)
  end
  return n
end

-- La fin du saut rapide, passage « essai » : pour chaque cavalier en saut qui a eu son ordre à pied, rien ne se fait
-- tant qu'il est encore en selle (lu), que lui ou son cheval est sous les yeux d'Henry, ou que la place derrière Henry
-- l'est : on attend « saut_attente_ms », « saut_attentes_max » fois au plus ; ensuite le saut est abandonné, il rejoint à
-- cheval. Sinon son cheval est retiré (la durée de la descente au journal), il est posé derrière Henry, son saut finit et
-- son ordre est redonné (un nouveau cheval naît près de lui). Rend le nombre de cavaliers posés.
function hommes.finir_les_sauts(essai)
  essai = essai or 1
  local d = donnees()
  local heure = jeu().heure_du_jeu()
  local r = hommes.reglages
  local ecoule_s = (r.saut_descente_ms + (essai - 1) * r.saut_attente_ms) / 1000
  local poses, attendent = 0, 0
  for cle, m in pairs(hommes.montures) do
    if m.saut and m.saut_ordonne and not m.pose then
      local f = porteur(cle, d)
      local nom = tostring(f and f.nom or cle)
      local attente = nil
      local monte = m.cheval and jeu().cheval_monte(m.cheval)
      if m.cheval and monte ~= false then
        attente = (monte == true) and "encore en selle" or "selle illisible"
      elseif m.cheval and sous_les_yeux_d_henry(jeu().position_du_personnage(m.cheval)) then
        attente = "son cheval sous les yeux d'Henry"
      elseif f and f.personnage and sous_les_yeux_d_henry(jeu().position_du_personnage(f.personnage)) then
        attente = "sous les yeux d'Henry"
      else
        local ou = hommes.point_derriere_henry()
        if not ou or jeu().henry_voit(ou, r.secours_vue_cos) == true then
          attente = "la place derrière Henry sous ses yeux"
        end
      end
      if attente and essai <= r.saut_attentes_max then
        attendent = attendent + 1
        jeu().journal("Hommes : « " .. nom .. " » " .. attente .. " à " .. string.format("%g", ecoule_s) .. " s : il attend")
      elseif attente and m.cheval then
        m.saut, m.saut_ordonne, m.saut_vu = nil, nil, nil
        jeu().journal("Hommes : « " .. nom .. " » " .. attente .. " à " .. string.format("%g", ecoule_s)
                      .. " s : saut abandonné, il rejoint à cheval")
        redonner_l_ordre(d, cle, heure)
      elseif not attente then
        if m.cheval then
          jeu().retirer_cheval(m.cheval)
          jeu().journal("Hommes : « " .. nom .. " » à pied, lu à " .. string.format("%g", ecoule_s) .. " s : cheval « "
                        .. m.cheval .. " » retiré (grand saut)")
          m.cheval = nil
        end
        local pose, ou = false, nil
        if f and f.personnage then
          pose, ou = hommes.poser_derriere_henry(f.personnage, f.nom, "en grand saut")
        end
        if pose then
          m.pose, m.poses = ou, 1
          poses = poses + 1
        end
      end
    end
  end
  if poses > 0 then
    programmer_la_relecture(r.saut_verif_ms)
  end
  if attendent > 0 then
    programmer_la_fin(essai + 1, r.saut_attente_ms)
  end
  return poses
end

-- La relecture des poses (vu en jeu le 17/10) : un cavalier posé et resté près de sa place finit son saut, son ordre est
-- redonné (un nouveau cheval naît près de lui) ; sinon il est reposé derrière Henry, « saut_poses_max » fois au plus,
-- puis le battement le rattrape. Rend le nombre de sauts finis.
function hommes.relire_les_poses()
  local d = donnees()
  local heure = jeu().heure_du_jeu()
  local r = hommes.reglages
  local finis, reposes = 0, 0
  for cle, m in pairs(hommes.montures) do
    if m.saut and m.pose then
      local f = porteur(cle, d)
      local ici = f and f.personnage and jeu().position_du_personnage(f.personnage)
      local ecart = ici and math.sqrt((ici.x - m.pose.x) ^ 2 + (ici.y - m.pose.y) ^ 2)
      if ecart and ecart <= r.saut_pose_ecart_m then
        m.pose, m.poses = nil, nil
        m.saut, m.saut_ordonne, m.saut_vu, m.sauts = nil, nil, nil, (m.sauts or 0) + 1
        finis = finis + 1
        redonner_l_ordre(d, cle, heure)
      elseif f and f.personnage and m.poses < r.saut_poses_max then
        jeu().journal("Hommes : « " .. tostring(f.nom) .. " » pas resté posé (à "
                      .. (ecart and string.format("%.0f", ecart) or "?") .. " m de sa place) : reposé")
        local pose, ou = hommes.poser_derriere_henry(f.personnage, f.nom, "en grand saut")
        m.poses = m.poses + 1
        if pose then
          m.pose = ou
          reposes = reposes + 1
        end
      else
        jeu().journal("Hommes : « " .. tostring(f and f.nom or cle) .. " » pas resté posé après " .. tostring(m.poses)
                      .. " pose(s) : le battement le rattrapera")
        m.pose, m.poses = nil, nil
      end
    end
  end
  if reposes > 0 then
    programmer_la_relecture(r.saut_verif_ms)
  end
  return finis
end

-- Le bond d'Henry (V73 f 3 b) : sa position a bougé de plus de « henry_bond_m » depuis la veille précédente (le voyage
-- rapide, un téléport) : le saut rapide est lancé. Rend vrai s'il y a eu un bond.
function hommes.guetter_le_bond()
  local ici = jeu().position_du_joueur()
  local avant = hommes.henry_derniere_position
  hommes.henry_derniere_position = ici and { x = ici.x, y = ici.y, z = ici.z } or nil
  if not (ici and avant) then
    return false
  end
  local bond = math.sqrt((ici.x - avant.x) ^ 2 + (ici.y - avant.y) ^ 2)
  if bond <= hommes.reglages.henry_bond_m then
    return false
  end
  jeu().journal("Hommes : bond d'Henry de " .. string.format("%.0f", bond) .. " m : "
                .. hommes.lancer_les_sauts() .. " cavalier(s) en grand saut")
  return true
end

function hommes.veiller_henry()
  local lu
  if hommes.henry_force ~= nil then
    lu = hommes.henry_force
  else
    lu = jeu().henry_a_cheval(hommes.reglages.henry_cheval_pres_m)
  end
  hommes.henry_lu = lu
  local change = false
  if lu == true then
    hommes.henry_pied_lectures = 0
    if not hommes.henry_monte then
      hommes.henry_monte, change = true, true
      jeu().journal("Hommes : Henry à cheval : l'escorte monte")
    end
  elseif lu == false and hommes.henry_monte then
    hommes.henry_pied_lectures = hommes.henry_pied_lectures + 1
    if hommes.henry_pied_lectures >= hommes.reglages.henry_descente_lectures then
      hommes.henry_monte, change, hommes.henry_pied_lectures = false, true, 0
      jeu().journal("Hommes : Henry à pied (" .. hommes.reglages.henry_descente_lectures
                    .. " lectures de suite) : l'escorte descend")
    end
  end
  if change then
    local d = donnees()
    local heure = jeu().heure_du_jeu()
    for _, id in ipairs(d.ordre) do
      local _, t = tenue_la_plus_forte(d.liste[id])
      if t and t.activite == "suivre" and t.a_cheval == "comme_henry" then
        local m = hommes.montures[id]
        if m and not hommes.henry_monte then
          m.abandon, m.essais = nil, 0
        end
        ordonner_un_homme(d, id, heure, nil, true)
      end
    end
    -- V73 f 2 e : le Directeur aussi, s'il suit Henry (son ordre n'est redonné que si sa monture change).
    if Scriptorium.directeur and Scriptorium.directeur.est_installe() then
      Scriptorium.directeur.battre()
    end
  end
  hommes.guetter_le_bond()
  return lu
end

-- La veille d'Henry à cheval, une par partie (comme le guet du noyau, elle s'éteint au changement de génération) ; une
-- erreur est dite au journal, trois fois au plus. Rend vrai si elle est posée.
function hommes.lancer_la_veille_d_henry()
  local generation = Scriptorium.generation
  if hommes.veille_d_henry_generation == generation then
    return false
  end
  hommes.veille_d_henry_generation = generation
  local erreurs = 0
  local function veille()
    if generation ~= Scriptorium.generation or not Scriptorium.en_partie then
      return
    end
    local ok, erreur = pcall(hommes.veiller_henry)
    if not ok and erreurs < 3 then
      erreurs = erreurs + 1
      jeu().journal("Hommes : veille d'Henry à cheval en erreur : " .. tostring(erreur))
    end
    jeu().minuterie(hommes.reglages.henry_veille_ms, veille)
  end
  jeu().minuterie(hommes.reglages.henry_veille_ms, veille)
  return true
end

-- Le gardien des hommes (fiche 15, V73 g, version simple). En mémoire seulement : par homme, ce qu'a vu le regard
-- précédent ; et les comptes de la partie (relances, utiles, repêchages).
hommes.gardien = { vus = {}, relances = 0, utiles = 0, repeches = 0 }

local function repecher(f, v, ici)
  local r = hommes.reglages
  if (v.repeches or 0) >= r.gardien_repeches_max then
    if not v.repeche_laisse then
      v.repeche_laisse = true
      jeu().journal("Gardien : « " .. f.nom .. " » sous le sol, déjà repêché " .. v.repeches .. " fois : laissé")
    end
    return false
  end
  local effet, refus = jeu().rendre_immortel(f.personnage)
  local resultat = jeu().poser_en_secours(f.personnage, { x = ici.x, y = ici.y, z = ici.z })
  v.repeches = (v.repeches or 0) + 1
  hommes.gardien.repeches = hommes.gardien.repeches + 1
  jeu().journal("Gardien : « " .. f.nom .. " » sous le sol (à " .. string.format("%.1f", ici.z) .. ") : repêché, "
                .. tostring(resultat) .. " ; immortel : " .. (effet ~= nil and "oui" or ("non (" .. tostring(refus) .. ")")))
  if effet ~= nil then
    local personnage = f.personnage
    jeu().minuterie(r.gardien_immortel_ms, function()
      jeu().retirer_l_effet(personnage, effet)
    end)
  end
  f.derniere_activite = nil
  return true
end

-- Un regard du gardien sur chaque homme présent. Rend (repêchés, relancés).
function hommes.garder()
  local d = donnees()
  local r = hommes.reglages
  local g = hommes.gardien
  local heure = jeu().heure_du_jeu()
  local henry = jeu().position_du_joueur()
  local terrain_d_henry = henry and jeu().altitude_du_terrain(henry.x, henry.y)
  local henry_sous_le_sol = terrain_d_henry ~= nil and henry.z < terrain_d_henry - r.gardien_sous_sol_m
  local repeches, relances = 0, 0
  for _, id in ipairs(d.ordre) do
    local f = d.liste[id]
    local ici = f and f.personnage and jeu().position_du_personnage(f.personnage)
    if ici then
      local v = g.vus[id] or {}
      g.vus[id] = v
      local a = Scriptorium.avis(hommes, "activite_de", id, heure)
      -- Sous le sol (jamais s'il suit Henry et qu'Henry est lui-même sous le sol : une grotte).
      local terrain = jeu().altitude_du_terrain(ici.x, ici.y)
      if terrain and ici.z < terrain - r.gardien_sous_sol_m then
        v.sous_le_sol = (v.sous_le_sol or 0) + 1
        if v.sous_le_sol >= r.gardien_sous_sol_regards and not (a and a.activite == "suivre" and henry_sous_le_sol) then
          if repecher(f, v, ici) then
            repeches = repeches + 1
          end
          v.sous_le_sol = 0
        end
      else
        v.sous_le_sol = 0
      end
      -- Figé.
      if v.regards == nil or v.ordre ~= f.derniere_activite then
        v.ordre, v.regards, v.relances, v.depuis_relance, v.laisse = f.derniere_activite, 0, 0, nil, nil
      end
      v.regards = v.regards + 1
      local bouge = v.avant and math.sqrt((ici.x - v.avant.x) ^ 2 + (ici.y - v.avant.y) ^ 2) or nil
      if v.attend_utile and bouge then
        v.attend_utile = nil
        if bouge > r.fige_utile_m then
          g.utiles = g.utiles + 1
          jeu().journal("Gardien : « " .. f.nom .. " » repart (" .. string.format("%.1f", bouge) .. " m) : relance utile")
        end
      end
      if v.depuis_relance then
        v.depuis_relance = v.depuis_relance + 1
      end
      local but = a and a.position
      -- La fouille (fiche 17, vu en jeu le 17/10 : un fouilleur arrivé au corps pris pour figé) a sa propre borne.
      -- Vu sur une copie de la partie de JoVenGer le 20/10 (au chargement et au lever, 10 hommes « figés », relancés deux
      -- fois puis laissés au secours) : un homme dont l'activité a changé sans qu'il ait encore reçu l'ordre (aucun ordre
      -- depuis le rechargement, lever d'un homme couché) attend le battement ; il est jugé sur l'ordre reçu.
      local exclu = not but or a.activite == "suivre" or a.activite == "bataille" or a.activite == "ronde"
        or a.activite == "fouille" or f.derniere_activite ~= resume_de(a)
        or jeu().occupation_de(f.personnage) ~= nil
        -- Vu en J32 (24/10) : loin d'Henry, l'agent du personnage dort ; il n'est pas jugé figé.
        or (henry ~= nil and math.sqrt((ici.x - henry.x) ^ 2 + (ici.y - henry.y) ^ 2) > (tonumber(r.gardien_rayon_m) or math.huge))
        -- Même vue (J26) : un homme assommé n'est pas figé.
        or (jeu().personnage_inconscient and jeu().personnage_inconscient(f.personnage) == true)
      if not exclu and bouge and bouge < r.fige_bouge_m and v.regards > r.fige_ordre_regards then
        local ecart = jeu().ecart_au_but(f.personnage, but)
        if ecart and ecart > r.fige_but_m then
          if v.relances >= r.fige_relances_max then
            if not v.laisse then
              v.laisse = true
              jeu().journal("Gardien : « " .. f.nom .. " » toujours figé après " .. v.relances
                            .. " relance(s) : laissé au secours")
            end
          elseif (v.depuis_relance == nil or v.depuis_relance >= r.fige_regards_entre)
              and relances < r.fige_par_regard then
            jeu().eveiller(f.personnage, f.nom)
            f.derniere_activite = nil
            ordonner_un_homme(d, id, heure, nil, true)
            v.ordre = f.derniere_activite
            v.relances, v.depuis_relance, v.attend_utile = v.relances + 1, 0, true
            relances = relances + 1
            g.relances = g.relances + 1
            jeu().journal("Gardien : « " .. f.nom .. " » figé à " .. string.format("%.1f", ecart) .. " m de son but ("
                          .. tostring(a.activite) .. ") : relancé (" .. v.relances .. " sur " .. r.fige_relances_max .. ")")
          end
        end
      end
      v.avant = { x = ici.x, y = ici.y, z = ici.z }
    end
  end
  return repeches, relances
end

-- La veille du gardien, une par partie (comme la veille d'Henry) ; une erreur est dite au journal, trois fois au plus.
function hommes.lancer_le_gardien()
  local generation = Scriptorium.generation
  if hommes.gardien_generation == generation then
    return false
  end
  hommes.gardien_generation = generation
  local erreurs = 0
  local function regard()
    if generation ~= Scriptorium.generation or not Scriptorium.en_partie then
      return
    end
    local ok, erreur = pcall(hommes.garder)
    if not ok and erreurs < 3 then
      erreurs = erreurs + 1
      jeu().journal("Gardien : regard en erreur : " .. tostring(erreur))
    end
    jeu().minuterie(hommes.reglages.gardien_cadence_ms, regard)
  end
  jeu().minuterie(hommes.reglages.gardien_cadence_ms, regard)
  return true
end

-- Vu sur une copie de la partie de JoVenGer le 21/10 (J26) : un homme dont la venue a été refusée (« place prise … et
-- aucune place libre à côté » : trente embauches nées au feu dans le même instant) restait sans personnage jusqu'au
-- chargement suivant (hommes.redresser). Au battement, sur la carte du camp, au plus « venues_par_battement » d'entre
-- eux sont refaits, dans l'ordre du camp ; ni un homme dehors (sa mission le fait rentrer), ni un admis.
local function refaire_les_absents(d)
  local limite = tonumber(hommes.reglages.venues_par_battement) or 0
  if limite <= 0 or not camp().est_fonde() or (camp().sur_sa_carte ~= nil and not camp().sur_sa_carte()) then
    return 0
  end
  local refaits = 0
  for _, id in ipairs(d.ordre) do
    local f = d.liste[id]
    if refaits >= limite then
      break
    end
    if f and f.personnage == nil and not f.dehors and not f.admis then
      refaits = refaits + 1
      if faire_venir(d, f, false) then
        jeu().journal("Hommes : « " .. f.nom .. " » vient enfin (sa venue avait été refusée)")
        enregistrer()
      end
    end
  end
  return refaits
end

function hommes.battre()
  local d = donnees()
  hommes.habilles_hors_file = {}
  hommes.suivre_l_horaire_de_scriptorium()
  local heure = jeu().heure_du_jeu()
  local rapport = { aubes = 0, repas = 0, paies = 0, ordres = 0, equipes = 0, changements = 0, cerveaux = 0, arrets = 0,
                    a_rhabiller = 0, tenues = 0 }
  rapport.cerveaux = regler_les_cerveaux(d)
  rapport.arrets, rapport.a_rhabiller = surveiller_les_cerveaux(d)
  veiller_aux_montures(d)
  -- Fiche 18, 5 c, tranche 4 : les stations partagées avec Henry (définies plus bas, appelées par la table).
  hommes.veiller_les_stations(d, heure)
  -- La bascule (l'affrontement, 18/10) : la cible à terre, la tenue se lâche ; sinon l'attaque est redonnée à qui ne se
  -- bat plus.
  hommes.veiller_les_affrontements(d)
  -- Sans aucun homme, le personnel mené l'est encore (vu au banc le 20/10 : il ne recevait plus ni ordre ni secours).
  if #d.ordre == 0 and #d.anciens == 0 then
    if d.menes and next(d.menes) then
      hommes.mener_le_personnel(d, heure, rapport)
    end
    return rapport
  end
  if d.derniere_heure == nil then
    d.derniere_heure = heure
  end
  if heure < d.derniere_heure then
    -- L'horloge a reculé (autre partie chargée) : on repart d'ici.
    d.derniere_heure = heure
    d.derniere_aube = jour_de(heure - hommes.reglages.heure_lever)
    d.dernier_jour_repas = jour_de(heure - hommes.reglages.heure_repas)
    rapport.changements = rapport.changements + 1
  end
  -- Aubes passées.
  local aube = jour_de(heure - hommes.reglages.heure_lever)
  if d.derniere_aube == nil then d.derniere_aube = aube end
  while d.derniere_aube < aube do
    d.derniere_aube = d.derniere_aube + 1
    aube_du_jour(d, heure, rapport)
    rapport.aubes = rapport.aubes + 1
    rapport.changements = rapport.changements + 1
  end
  -- Repas passés.
  local repas = jour_de(heure - hommes.reglages.heure_repas)
  if d.dernier_jour_repas == nil then d.dernier_jour_repas = repas end
  while d.dernier_jour_repas < repas do
    d.dernier_jour_repas = d.dernier_jour_repas + 1
    repas_du_jour(d, rapport, d.dernier_jour_repas * 24 + hommes.reglages.heure_repas)
    rapport.repas = rapport.repas + 1
    rapport.changements = rapport.changements + 1
  end
  -- Paies passées.
  while d.prochaine_paie and heure >= d.prochaine_paie do
    d.prochaine_paie = d.prochaine_paie + 7 * 24
    hommes.payer_la_solde()
    rapport.paies = rapport.paies + 1
    rapport.changements = rapport.changements + 1
  end
  if rapport.changements > 0 then
    verifier_rangs(d, rapport)
  end
  -- Même vue (J26) : les hommes restés sans personnage (la venue refusée) sont refaits ici, pas seulement au chargement.
  refaire_les_absents(d)
  -- Les tenues tombent à leur fin ; une tenue « jusqu'à libération » tombe par sûreté au bout de « tenue_max_h »
  -- (réponse 2 a de JoVenGer, V73 b), notée au journal : sa règle l'avait oubliée (fiche 15, V73 b 3).
  for _, id in ipairs(d.ordre) do
    local f = d.liste[id]
    for regle, t in pairs(f.tenues or {}) do
      local tombee = false
      if type(t.fin) == "number" then
        tombee = heure >= t.fin
      elseif heure >= (t.depuis or heure) + hommes.reglages.tenue_max_h then
        tombee = true
        jeu().journal("Hommes : tenue « " .. regle .. " » de « " .. f.nom .. " » tombée au bout de "
                      .. string.format("%g", hommes.reglages.tenue_max_h) .. " h, jamais lâchée")
      end
      if tombee then
        f.tenues[regle] = nil
        rapport.changements = rapport.changements + 1
      end
    end
  end
  rendre_les_lits_reserves(d)
  for _, id in ipairs(d.ordre) do
    ordonner_un_homme(d, id, heure, rapport, false)
  end
  hommes.mener_le_personnel(d, heure, rapport)
  hommes.appliquer_les_pieces_au_sac(d)
  -- Vu dans la partie de JoVenGer le 22/10 : « habillage_par_battement » hommes, jamais deux fois le même, ni celui
  -- habillé au moment de son ordre dans ce battement.
  local habilles = hommes.habilles_hors_file
  for _ = 1, math.max(1, math.floor(tonumber(hommes.reglages.habillage_par_battement) or 1)) do
    local equipe = equiper_un_homme(d, habilles)
    if not equipe then
      break
    end
    habilles[equipe] = true
    rapport.equipes = rapport.equipes + 1
    rapport.changements = rapport.changements + 1
  end
  rapport.tenues = garder_les_tenues(d, habilles)
  hommes.tenir_la_sante_des_blesses(d)
  d.derniere_heure = heure
  if rapport.changements > 0 or rapport.a_rhabiller > 0 then
    enregistrer()
  end
  return rapport
end

-- La santé d'un blessé suit sa blessure (demande de JoVenGer par le pair, 21/10, J5) : au-dessus de son plafond (selon
-- ses jours de soins), elle y est ramenée, sans coup (renaissance, rentrée de mission, régénération du jeu, chargement) ;
-- une ligne au journal à chaque nouveau plafond, en mémoire. Guéri, plus de plafond : la santé remonte d'elle-même.
hommes.plafonds_poses = hommes.plafonds_poses or {}

function hommes.plafond_de_sante(jours)
  if type(jours) ~= "number" or jours <= 0 then
    return nil
  end
  local r = hommes.reglages
  local plafonds = { r.sante_blesse_1, r.sante_blesse_2, r.sante_blesse_3, r.sante_blesse_4, r.sante_blesse_5 }
  return tonumber(plafonds[math.min(5, math.max(1, math.floor(jours)))])
end

function hommes.tenir_la_sante_des_blesses(d)
  for _, id in ipairs(d.ordre) do
    local f = d.liste[id]
    local plafond = f and f.personnage and hommes.plafond_de_sante(f.blessure)
    if not plafond then
      hommes.plafonds_poses[id] = nil
    else
      local sante = jeu().sante_de and jeu().sante_de(f.personnage)
      if type(sante) == "number" and sante > plafond + 1 and jeu().regler_la_sante then
        local ok = jeu().regler_la_sante(f.personnage, plafond)
        if hommes.plafonds_poses[id] ~= plafond then
          hommes.plafonds_poses[id] = plafond
          jeu().journal(string.format("Hommes : « %s » blessé (%d jour(s)) : santé %.0f ramenée à %d%s", f.nom,
            f.blessure, sante, plafond, ok and "" or " (refusé)"))
        end
      end
    end
  end
end

-- ---------------------------------------------------------------- l'arbitre : services (fiche 15, V73 b 3)

local function memes_points(a, b)
  if a == nil or b == nil then
    return a == b
  end
  return a.x == b.x and a.y == b.y and a.z == b.z
end

-- Le rassemblement (V73 e) : poser ou lâcher une tenue peut déplacer les places de l'arc ; chacun des hommes d'un
-- rassemblement dont la place a changé reçoit son ordre sur-le-champ (les autres n'en reçoivent pas : même signature).
local function redonner_au_rassemblement(d, heure)
  for _, autre in ipairs(d.ordre) do
    local f = d.liste[autre]
    local _, t = tenue_la_plus_forte(f)
    if t and ((t.activite == "rassemblement" and t.centre) or t.activite == "suivre") then
      ordonner_un_homme(d, autre, heure, nil, true)
    end
  end
end

local function memes_chemins(a, b)
  if a == nil or b == nil then
    return a == b
  end
  if #a ~= #b then
    return false
  end
  for i = 1, #a do
    if not memes_points(a[i], b[i]) then
      return false
    end
  end
  return true
end

local function memes_tenues(a, b)
  return a.activite == b.activite and a.lieu == b.lieu and a.cap == b.cap and a.fin == b.fin
    and a.ne_pas_rhabiller == b.ne_pas_rhabiller and memes_points(a.position, b.position)
    and a.aller_retour == b.aller_retour and a.depart == b.depart and a.pauses == b.pauses
    and memes_chemins(a.chemin, b.chemin) and memes_points(a.centre, b.centre) and a.rayon == b.rayon
    and a.ouverture == b.ouverture and a.face == b.face and a.allure == b.allure and a.chef == b.chef
    and a.formation == b.formation and a.cheval == b.cheval and a.a_cheval == b.a_cheval
    and (a.vers == nil) == (b.vers == nil) and (a.vers == nil or (a.vers.x == b.vers.x and a.vers.y == b.vers.y))
    and a.tete == b.tete and a.poste == b.poste and a.geste == b.geste and a.partage == b.partage
    and a.siege == b.siege and a.assis == b.assis and a.arme_tiree == b.arme_tiree and a.lit == b.lit
    and a.cible == b.cible and a.mains_nues == b.mains_nues and a.jusqu_a == b.jusqu_a and a.amical == b.amical
end

-- L'objet du jeu d'un « siege » de geste (demande du pair, 18/10) : une place du camp (son objet où s'asseoir), un poste
-- de travail, un objet du camp, sinon le nom tel quel (une entité du jeu).
function hommes.objet_d_ancrage(siege)
  return camp().objet_du_jeu_de(siege) or camp().objet_du_poste(siege) or camp().objet_de(siege) or siege
end

-- Fiche 18, 5 c : la forme d'un geste tenu (d'un homme, ou du Directeur, demande du pair du 20/10) : son nom (dans le
-- lieu, donc dans la signature de l'ordre) et le point regardé, à 5 m devant lui selon le cap. Demande du pair (18/10) :
-- le geste ancré sur un objet (« siege »), assis s'il est assis ; l'arme à la main. Rend « resultat ».
function hommes.forme_du_geste(source, resultat)
  resultat.geste = source.geste
  resultat.lieu = (source.lieu or "geste") .. "/" .. source.geste .. (source.siege and ("@" .. source.siege) or "")
    .. (source.arme_tiree and "/arme" or "")
  resultat.siege, resultat.assis, resultat.arme_tiree = source.siege, source.assis, source.arme_tiree
  if source.siege and not source.position then
    resultat.position = jeu().position_d_un_objet(hommes.objet_d_ancrage(source.siege))
  end
  if source.cap and source.position then
    local r = math.rad(source.cap)
    resultat.regard = { x = source.position.x + 5 * math.sin(r), y = source.position.y + 5 * math.cos(r), z = source.position.z }
  end
  return resultat
end

-- Service pour le guichet et pour les morceaux du socle : tenir un homme par une règle (au catalogue, hommes.priorites).
-- « quoi » : activite, lieu, position, cap, et sa fin : une heure du jeu ; « liberation » (jusqu'à ce que la règle le
-- lâche, borné par sûreté à « tenue_max_h ») ; rien (jusqu'au prochain changement de tranche, réponse 4 a). Une règle
-- plus faible ne reprend pas un homme qu'une plus forte tient : sa tenue reste posée, et prend effet quand la plus forte
-- le lâche. Reposer la même règle la met à jour sans la rajeunir. L'ordre est redonné sur-le-champ si l'activité de
-- l'homme change. L'activité « ronde » (fiche 15, V73 d 2) veut aussi « chemin » (2 à « ronde_points_max » points du
-- monde ; Scriptorium, qui garde ses rondes dans le repère du camp, les redonne à chaque fondation), et accepte
-- « aller_retour » (sinon en boucle), « depart » (le numéro du premier point, à la pose) et « pauses » (à faux : sans
-- pause, V73 d 2 bis). Le rassemblement (V73 e) accepte « centre » (un point du monde), et alors « cap » (le milieu de
-- l'arc vu du centre), « rayon », « ouverture » (degrés, 360 : un cercle), « face » (« centre » ou « dehors ») et
-- « allure » (« course » ou « marche ») ; sans centre, il reste une marche au point. Suivre (V73 f 2 b) accepte
-- « a_cheval » (un booléen) : une sortie à cheval, un cheval passager par homme ; ou « comme_henry » (V73 f 2 d) : à
-- cheval tant qu'Henry l'est. Rend vrai, ou (faux, raison).
-- Demande du pair (21/10, J27 : les dames des bains tiraient des sièges qu'un homme occupait, refusés « place_prise »
-- en boucle) : les sièges déclarés où un homme de la Compagnie est assis ou va s'asseoir maintenant (le lieu de son
-- activité du moment) : { [nom de la place] = nom de l'homme }. C'est le test même du refus « place_prise » de
-- hommes.tenir. Une activite_de par homme : à appeler une fois par tour, pas une fois par siège.
function hommes.sieges_occupes(heure)
  local d = donnees()
  heure = heure or jeu().heure_du_jeu()
  local occupes = {}
  for _, autre in ipairs(d.ordre) do
    local a = Scriptorium.avis(hommes, "activite_de", autre, heure)
    if a and type(a.lieu) == "string" and not occupes[a.lieu] and camp().sorte_de(a.lieu) == "siege" then
      occupes[a.lieu] = d.liste[autre].nom
    end
  end
  return occupes
end

function hommes.tenir(id, regle, quoi)
  local d = donnees()
  local f = fiche_de(d, id)
  if not f then
    return refuser("homme_inconnu", tostring(id))
  end
  if not rang_de(regle) then
    return refuser("regle_inconnue", tostring(regle))
  end
  if exempte(f, regle) then
    return refuser("homme_exempte", f.nom .. " : " .. regle)
  end
  quoi = quoi or {}
  local heure = jeu().heure_du_jeu()
  local fin = quoi.fin
  if fin == nil then
    fin = prochain_changement_de_tranche(heure)
  elseif fin ~= "liberation" and type(fin) ~= "number" then
    return refuser("fin_invalide", tostring(fin))
  end
  local chemin, depart = nil, nil
  if quoi.activite == "ronde" then
    local raison
    chemin, raison = copie_du_chemin(quoi.chemin)
    if not chemin then
      return refuser("chemin_invalide", raison)
    end
    depart = quoi.depart
    if depart ~= nil and (type(depart) ~= "number" or depart ~= math.floor(depart) or depart < 1 or depart > #chemin) then
      return refuser("chemin_invalide", "départ " .. tostring(depart))
    end
    if quoi.pauses ~= nil and type(quoi.pauses) ~= "boolean" then
      return refuser("chemin_invalide", "pauses " .. tostring(quoi.pauses))
    end
  end
  -- Le rassemblement avec un centre (V73 e) : un arc autour du centre ; sans centre, une marche au point, comme avant.
  local arc = nil
  if quoi.activite == "rassemblement" and quoi.centre ~= nil then
    local c = quoi.centre
    if type(c) ~= "table" or type(c.x) ~= "number" or type(c.y) ~= "number" or (c.z ~= nil and type(c.z) ~= "number") then
      return refuser("rassemblement_invalide", "centre")
    end
    if quoi.rayon ~= nil and (type(quoi.rayon) ~= "number" or quoi.rayon <= 0) then
      return refuser("rassemblement_invalide", "rayon " .. tostring(quoi.rayon))
    end
    if quoi.ouverture ~= nil and (type(quoi.ouverture) ~= "number" or quoi.ouverture <= 0 or quoi.ouverture > 360) then
      return refuser("rassemblement_invalide", "ouverture " .. tostring(quoi.ouverture))
    end
    if quoi.cap ~= nil and type(quoi.cap) ~= "number" then
      return refuser("rassemblement_invalide", "cap " .. tostring(quoi.cap))
    end
    if quoi.face ~= nil and quoi.face ~= "centre" and quoi.face ~= "dehors" then
      return refuser("rassemblement_invalide", "face " .. tostring(quoi.face))
    end
    if quoi.allure ~= nil and quoi.allure ~= "course" and quoi.allure ~= "marche" then
      return refuser("rassemblement_invalide", "allure " .. tostring(quoi.allure))
    end
    arc = { centre = { x = c.x, y = c.y, z = c.z }, rayon = quoi.rayon, ouverture = quoi.ouverture, face = quoi.face,
            allure = quoi.allure }
  end
  -- Suivre (V73 f 1) : le chef de la colonne, « henry » (défaut), « directeur », ou un autre homme du camp. Fiche 17,
  -- 4 b : « vers » (un point du monde) : la colonne va à ce point, menée par son premier homme, sans chef.
  if quoi.activite == "suivre" and quoi.chef ~= nil and quoi.chef ~= "henry" and quoi.chef ~= "directeur"
      and (not d.liste[quoi.chef] or quoi.chef == id) then
    return refuser("escorte_invalide", "chef " .. tostring(quoi.chef))
  end
  if quoi.activite == "suivre" and quoi.formation ~= nil and not hommes.formations[quoi.formation] then
    return refuser("escorte_invalide", "formation " .. tostring(quoi.formation))
  end
  if quoi.tete ~= nil and (quoi.activite ~= "suivre" or not d.liste[quoi.tete]) then
    return refuser("colonne_invalide", "tête " .. tostring(quoi.tete))
  end
  local vers = nil
  if quoi.vers ~= nil then
    local v = quoi.vers
    if quoi.activite ~= "suivre" or quoi.chef ~= nil or type(v) ~= "table" or type(v.x) ~= "number" or type(v.y) ~= "number"
        or (v.z ~= nil and type(v.z) ~= "number") then
      return refuser("colonne_invalide", "vers")
    end
    vers = { x = v.x, y = v.y, z = v.z or 0 }
  end
  if quoi.activite == "suivre" and quoi.a_cheval ~= nil and type(quoi.a_cheval) ~= "boolean" and quoi.a_cheval ~= "comme_henry" then
    return refuser("escorte_invalide", "a_cheval " .. tostring(quoi.a_cheval))
  end
  -- Fiche 18, 5 c : le geste tenu à un point (la forge de Scriptorium) : un nom de geste et un point ; ou ancré sur un
  -- objet du jeu (« siege » : une place, un poste ou un objet du camp, ou le nom d'une entité ; demande du pair, 18/10),
  -- le point étant alors celui de l'objet ; « assis » et « arme_tiree » : vrai ou faux.
  if quoi.activite == "geste" then
    local p = quoi.position
    local sans_point = quoi.siege ~= nil and p == nil
    if type(quoi.geste) ~= "string" or quoi.geste == "" or not string.match(quoi.geste, "^[%w_]+$")
        or (not sans_point and (type(p) ~= "table" or type(p.x) ~= "number" or type(p.y) ~= "number" or type(p.z) ~= "number"))
        or (quoi.cap ~= nil and type(quoi.cap) ~= "number")
        or (quoi.siege ~= nil and (type(quoi.siege) ~= "string" or quoi.siege == ""))
        or (quoi.assis ~= nil and type(quoi.assis) ~= "boolean")
        or (quoi.arme_tiree ~= nil and type(quoi.arme_tiree) ~= "boolean") then
      return refuser("geste_invalide", tostring(quoi.geste))
    end
    if sans_point and not jeu().position_d_un_objet(hommes.objet_d_ancrage(quoi.siege)) then
      return refuser("geste_invalide", "objet introuvable : " .. quoi.siege)
    end
  end
  -- Demande du pair (20/10 : le personnel de Scriptorium restait debout la nuit, son lit réservé chez Scriptorium) : le
  -- sommeil sur un lit donné par son nom d'entité (« lit »), déclaré ou non ; l'homme s'y couche par son WUID (ordre 11).
  if quoi.lit ~= nil then
    if quoi.activite ~= "sommeil" or type(quoi.lit) ~= "string" or quoi.lit == "" then
      return refuser("lit_invalide", tostring(quoi.lit))
    end
    if not jeu().objet_existe(quoi.lit) then
      return refuser("lit_invalide", "objet introuvable : " .. quoi.lit)
    end
    local centre, la = camp().point(0, 0, 0), jeu().position_d_un_objet(quoi.lit)
    local max = tonumber(hommes.reglages.lit_nomme_max_m) or 0
    if centre and la and max > 0 and math.sqrt((la.x - centre.x) ^ 2 + (la.y - centre.y) ^ 2) > max then
      return refuser("lit_invalide", string.format("%s à %.0f m du camp", quoi.lit,
        math.sqrt((la.x - centre.x) ^ 2 + (la.y - centre.y) ^ 2)))
    end
  end
  -- La bascule (demande du pair, 18/10 : duels, pugilat, conspiration de Scriptorium) : affronter un personnage précis
  -- (« henry » compris), à l'arme ou à mains nues, jusqu'à ce qu'il soit assommé ou mort ; jamais une bataille.
  if quoi.activite == "affronter" then
    if type(quoi.cible) ~= "string" or quoi.cible == "" or (quoi.arme ~= nil and type(quoi.arme) ~= "boolean")
        or (quoi.jusqu_a ~= nil and quoi.jusqu_a ~= "assomme" and quoi.jusqu_a ~= "mort")
        or (quoi.amical ~= nil and type(quoi.amical) ~= "boolean") then
      return refuser("affrontement_invalide", tostring(quoi.cible))
    end
    if quoi.cible ~= "henry" and jeu().personnage_mort(quoi.cible) then
      return refuser("affrontement_invalide", "cible absente ou morte : " .. quoi.cible)
    end
  end
  -- Demande du pair (20/10, séance J : le tir à la cible de Scriptorium) : au poste de tir (« position »), l'arc en main,
  -- tirant sur le point de visée (« cible » : le nom de son entité, que Scriptorium pose au cœur de la cible).
  if quoi.activite == "tir" then
    local p = quoi.position
    if type(p) ~= "table" or type(p.x) ~= "number" or type(p.y) ~= "number" or type(p.z) ~= "number"
        or type(quoi.cible) ~= "string" or quoi.cible == "" then
      return refuser("tir_invalide", tostring(quoi.cible))
    end
    if not jeu().objet_existe(quoi.cible) then
      return refuser("tir_invalide", "cible introuvable : " .. quoi.cible)
    end
  end
  -- Même demande (J15) : un mené tenu sur un siège déclaré qu'un homme de la Compagnie occupe déjà : refusé.
  if f.mene and type(quoi.lieu) == "string" and camp().sorte_de(quoi.lieu) == "siege" then
    local qui = hommes.sieges_occupes(heure)[quoi.lieu]
    if qui then
      return refuser("place_prise", quoi.lieu .. " : " .. tostring(qui))
    end
  end
  -- Fiche 18, 5 c, tranche 4 : la station partagée avec Henry, une station surveillée.
  if quoi.partage ~= nil and not (type(quoi.partage) == "string" and hommes.stations[quoi.partage]) then
    return refuser("station_inconnue", tostring(quoi.partage))
  end
  -- Fiche 18, 5 c : le poste de travail, un poste connu du camp.
  if quoi.activite == "poste" and not camp().poste(quoi.poste) then
    return refuser("poste_inconnu", tostring(quoi.poste))
  end
  -- « pauses » n'est écrit que s'il vaut faux (le défaut, avec pauses, n'écrit rien).
  local pauses = nil
  if chemin and quoi.pauses == false then
    pauses = false
  end
  f.tenues = f.tenues or {}
  local avant = f.tenues[regle]
  -- « ne_pas_rhabiller » : une règle qui veut l'homme dévêtu (le bain) ; la garde de la tenue le saute (fiche 13).
  local tenue = { activite = quoi.activite, lieu = quoi.lieu, position = quoi.position, cap = quoi.cap, fin = fin,
                  depuis = avant and avant.depuis or heure, ne_pas_rhabiller = (quoi.ne_pas_rhabiller == true) or nil,
                  chemin = chemin, aller_retour = (chemin and quoi.aller_retour == true) or nil, depart = depart,
                  pauses = pauses, centre = arc and arc.centre, rayon = arc and arc.rayon,
                  ouverture = arc and arc.ouverture, face = arc and arc.face, allure = arc and arc.allure,
                  chef = (quoi.activite == "suivre") and quoi.chef or nil, vers = vers,
                  tete = (quoi.activite == "suivre") and quoi.tete or nil,
                  poste = (quoi.activite == "poste") and quoi.poste or nil,
                  geste = (quoi.activite == "geste") and quoi.geste or nil,
                  siege = (quoi.activite == "geste") and quoi.siege or nil,
                  assis = (quoi.activite == "geste") and quoi.assis or nil,
                  arme_tiree = (quoi.activite == "geste" and quoi.arme_tiree == true) or nil,
                  lit = (quoi.activite == "sommeil") and quoi.lit or nil,
                  cible = (quoi.activite == "affronter" or quoi.activite == "tir") and quoi.cible or nil,
                  mains_nues = (quoi.activite == "affronter" and quoi.arme == false) or nil,
                  jusqu_a = (quoi.activite == "affronter" and quoi.amical ~= true) and (quoi.jusqu_a or "assomme") or nil,
                  -- Demande du pair (25/10) : l'assaut amical, le combat d'entraînement du jeu (personne ne tombe).
                  amical = (quoi.activite == "affronter" and quoi.amical == true) or nil,
                  partage = quoi.partage,
                  formation = (quoi.activite == "suivre") and quoi.formation or nil,
                  cheval = (quoi.activite == "suivre" and type(quoi.cheval) == "string") and quoi.cheval or nil,
                  a_cheval = (quoi.activite == "suivre" and (quoi.a_cheval == true or quoi.a_cheval == "comme_henry"))
                    and quoi.a_cheval or nil }
  f.tenues[regle] = tenue
  if not avant or not memes_tenues(avant, tenue) then
    enregistrer()
  end
  ordonner_un_homme(d, id, heure, nil, true, true)
  redonner_au_rassemblement(d, heure)
  return true
end

-- Service : lâcher la tenue d'une règle ; l'homme prend aussitôt ce que dit la règle d'en dessous. Une tenue déjà tombée
-- (fin, sûreté, montée de version) n'a rien à lâcher : rien n'est dit.
function hommes.lacher(id, regle)
  local d = donnees()
  local f = fiche_de(d, id)
  if not f then
    return refuser("homme_inconnu", tostring(id))
  end
  if not (f.tenues and f.tenues[regle]) then
    return true
  end
  f.tenues[regle] = nil
  enregistrer()
  ordonner_un_homme(d, id, jeu().heure_du_jeu(), nil, true)
  redonner_au_rassemblement(d, jeu().heure_du_jeu())
  return true
end

-- ---------------------------------------------------------------- le personnel mené (hors de la Compagnie)

-- Demande du pair (18/10) : les gens de Scriptorium (métiers du camp, clients, prisonniers…) ont notre cerveau et sont
-- menés par les mêmes ordres que nos hommes (geste ancré, poste, marche, suivre, à cheval), sans être de la Compagnie.
-- hommes.tenir_un_personnage(personnage, regle, quoi) : « quoi » comme pour hommes.tenir ; rend vrai, ou faux et la
-- raison. Le mené naît à sa première tenue ; un personnage de la Compagnie est refusé (deja_de_la_compagnie).
function hommes.tenir_un_personnage(personnage, regle, quoi)
  local d = donnees()
  if type(personnage) ~= "string" or personnage == "" or not jeu().personnage_existe(personnage) then
    return refuser("personnage_introuvable", tostring(personnage))
  end
  for _, id in ipairs(d.ordre) do
    if d.liste[id].personnage == personnage then
      return refuser("deja_de_la_compagnie", id)
    end
  end
  d.menes = d.menes or {}
  local id = "mene_" .. personnage
  if not d.menes[id] then
    d.menes[id] = { id = id, nom = personnage, personnage = personnage, mene = true, blessure = 0, tenues = {} }
    jeu().journal("Hommes : « " .. personnage .. " » est mené (hors de la Compagnie)")
  end
  local ok, raison = hommes.tenir(id, regle, quoi)
  if not ok and next(d.menes[id].tenues) == nil then
    d.menes[id] = nil
  end
  return ok, raison
end

-- Lâche la tenue d'une règle ; sans plus aucune tenue, le personnage n'est plus mené (il attend, rendu à Scriptorium).
function hommes.lacher_un_personnage(personnage, regle)
  local d = donnees()
  local id = "mene_" .. tostring(personnage)
  local f = d.menes and d.menes[id]
  if not f then
    return true
  end
  -- Vu sur une copie de la partie de JoVenGer le 19/10 : la dernière tenue lâchée, hommes.lacher donnait encore un ordre
  -- « attendre » à un personnage que Scriptorium venait de faire disparaître (« introuvable ») : sans plus aucune tenue,
  -- il n'est plus mené, sans ordre.
  if f.tenues and f.tenues[regle] and next(f.tenues, nil) == regle and next(f.tenues, regle) == nil then
    d.menes[id] = nil
    hommes.suivi[id] = nil
    enregistrer()
    jeu().journal("Hommes : « " .. tostring(personnage) .. " » n'est plus mené")
    return true
  end
  local ok, raison = hommes.lacher(id, regle)
  if next(f.tenues or {}) == nil then
    d.menes[id] = nil
    hommes.suivi[id] = nil
    enregistrer()
    jeu().journal("Hommes : « " .. tostring(personnage) .. " » n'est plus mené")
  end
  return ok, raison
end

-- Les personnages menés, lisibles : { identifiant de personnage, ... }.
function hommes.personnel_mene()
  local liste = {}
  for _, f in pairs(donnees().menes or {}) do
    table.insert(liste, f.personnage)
  end
  table.sort(liste)
  return liste
end

-- Au battement : les tenues échues tombent (comme pour nos hommes), un personnage disparu n'est plus mené, et chacun
-- reçoit son ordre. Vu sur une copie de la partie de JoVenGer le 20/10 : des chasseurs et un jardinier menés, bloqués
-- contre le mur de la cabane pendant des heures, sans jamais être secourus ; ils ont désormais le même secours que nos
-- hommes (la téléportation du jeu, jamais sous les yeux d'Henry).
function hommes.mener_le_personnel(d, heure, rapport)
  local menes = {}
  for cle_du_mene in pairs(d.menes or {}) do
    table.insert(menes, cle_du_mene)
  end
  table.sort(menes)
  for _, id in ipairs(menes) do
    local f = d.menes[id]
    if not jeu().personnage_existe(f.personnage) then
      jeu().journal("Hommes : « " .. f.personnage .. " » n'existe plus : il n'est plus mené")
      d.menes[id] = nil
      hommes.suivi[id] = nil
    else
      for regle, t in pairs(f.tenues) do
        if (type(t.fin) == "number" and heure >= t.fin)
            or (type(t.fin) ~= "number" and heure >= (t.depuis or heure) + hommes.reglages.tenue_max_h) then
          f.tenues[regle] = nil
          if rapport then rapport.changements = rapport.changements + 1 end
        end
      end
      -- Sans plus aucune tenue (toutes échues), il n'est plus mené, sans ordre.
      if next(f.tenues) == nil then
        jeu().journal("Hommes : « " .. f.personnage .. " » n'est plus mené (tenues échues)")
        d.menes[id] = nil
        hommes.suivi[id] = nil
      else
        ordonner_un_homme(d, id, heure, rapport, false)
      end
    end
  end
end

-- ---------------------------------------------------------------- les paroles (fiche 20)

-- Les demandes de parole en cours, en mémoire (une parole n'a de sens que sur le moment) : id -> { sorte, alias,
-- metarole, partenaire, numero, depuis, jouees_avant }.
hommes.paroles = hommes.paroles or {}
hommes.prochaine_parole = hommes.prochaine_parole or 1
hommes.sortes_de_paroles = { replique = 1, conversation = 2, dialogue = 3, replique_vers_henry = 4 }

-- Décision remplaçable (fiche 19) : cet homme peut-il dire sa parole maintenant ? Par défaut : ni occupé en combat, ni
-- tenu par la bataille, ni au sommeil. Une parole « urgente » (l'alerte du guetteur ; vu en jeu le 18/10 : sinon elle
-- attendait la fin du combat) se dit même tenu par la bataille, jamais en plein combat ni au sommeil.
function hommes.peut_parler(id, parole, activite)
  local f = fiche_de(donnees(), id)
  if not f or not f.personnage or jeu().occupation_de(f.personnage) == "combat" then
    return false
  end
  if parole and parole.urgente then
    return not (activite and activite.activite == "sommeil")
  end
  local rang = activite and activite.regle and hommes.priorites[activite.regle]
  if rang and rang < (tonumber(hommes.reglages.parole_rang_min) or 0) then
    return false
  end
  if activite and (activite.regle == "bataille" or activite.activite == "sommeil") then
    return false
  end
  -- Choix du pair (20/10, vu sur une copie : deux porteurs tenaient une conversation au lieu de porter leur corps) : on
  -- ne s'arrête pas pour causer en route ; une parole non urgente attend que l'homme soit arrivé à son but (à moins de
  -- « secours_arrivee_m »). La ronde et la suite, qui n'arrivent jamais, n'attendent pas.
  if activite and activite.position and activite.activite ~= "ronde" and activite.activite ~= "suivre" then
    local reste = jeu().ecart_au_but(f.personnage, activite.position)
    if reste and reste > hommes.reglages.secours_arrivee_m then
      return false
    end
  end
  return true
end
Scriptorium.remplacable(hommes, "peut_parler", function(rendu) return type(rendu) == "boolean" end)

local function demander_la_parole(id, parole)
  local d = donnees()
  local f = fiche_de(d, id)
  if not f then
    return refuser("homme_inconnu", tostring(id))
  end
  local function nom_valable(n)
    return n == nil or (type(n) == "string" and n ~= "" and string.match(n, "^[%w_]+$") ~= nil)
  end
  if not nom_valable(parole.alias) or not nom_valable(parole.metarole) or (parole.alias == nil and parole.metarole == nil) then
    return refuser("parole_invalide", tostring(parole.alias or parole.metarole))
  end
  local lus = f.personnage and jeu().lire_le_cerveau(f.personnage, { "scriptorium_parole_jouee" }) or {}
  parole.jouees_avant = tonumber(lus.scriptorium_parole_jouee) or 0
  parole.numero = hommes.prochaine_parole
  hommes.prochaine_parole = hommes.prochaine_parole + 1
  parole.depuis = jeu().heure_du_jeu()
  hommes.paroles[id] = parole
  jeu().journal("Hommes : « " .. f.nom .. " » doit dire « " .. tostring(parole.alias or parole.metarole) .. " » (" .. parole.sorte .. ")")
  ordonner_un_homme(d, id, parole.depuis, nil, true)
  return true
end

-- Fiche 20 : une réplique de Scriptorium (un alias, sinon un metarole) ; « regard_henry » : en regardant Henry.
function hommes.dire_une_replique(id, quoi)
  quoi = quoi or {}
  return demander_la_parole(id, { sorte = quoi.regard_henry and "replique_vers_henry" or "replique", alias = quoi.alias,
                                  metarole = quoi.metarole, urgente = quoi.urgente == true or nil })
end

-- Fiche 20 : une conversation à deux, depuis l'initiateur, avec son partenaire (un autre homme de la Compagnie).
function hommes.conversation(id, partenaire, quoi)
  quoi = quoi or {}
  local p = fiche_de(donnees(), partenaire)
  if not p or partenaire == id then
    return refuser("partenaire_invalide", tostring(partenaire))
  end
  return demander_la_parole(id, { sorte = "conversation", alias = quoi.alias, metarole = quoi.metarole, partenaire = partenaire })
end

-- Fiche 20 : un dialogue du jeu vers Henry, par son alias (ou { alias | metarole }).
function hommes.dialogue_force(id, alias)
  if type(alias) == "table" then
    return demander_la_parole(id, { sorte = "dialogue", alias = alias.alias, metarole = alias.metarole })
  end
  return demander_la_parole(id, { sorte = "dialogue", alias = alias })
end

-- Demande du pair (20/10, la séance J : « réplique pour un inconnu », le forgeron qui crie sa marchandise, les dames du
-- camp en conversation) : les paroles du personnel mené, par le nom de son entité. Un homme de la Compagnie est trouvé
-- par son personnage ; un personnage ni mené ni de la Compagnie est refusé (pas_mene : sans notre cerveau, il ne peut
-- rien dire par nous).
local function id_du_personnage(d, personnage)
  if type(personnage) ~= "string" then
    return nil
  end
  if d.menes and d.menes["mene_" .. personnage] then
    return "mene_" .. personnage
  end
  for _, id in ipairs(d.ordre) do
    if d.liste[id].personnage == personnage then
      return id
    end
  end
  return nil
end

function hommes.dire_une_replique_du_personnage(personnage, quoi)
  -- Un ennemi d'une bataille en cours (demande du pair, 21/10, J14 : les provocations des pillards).
  local bat = Scriptorium.bataille
  if bat and bat.dire_une_replique and type(personnage) == "string" and not id_du_personnage(donnees(), personnage) then
    local dir_ = Scriptorium.directeur
    if not (dir_ and dir_.personnage and dir_.personnage() == personnage) then
      local ok, raison = bat.dire_une_replique(personnage, quoi)
      if ok or raison ~= "hors_bataille" then
        return ok, raison
      end
    end
  end
  -- Le Directeur (vu sur une copie le 21/10, J11 : « réplique refusée pour Scriptorium_Directeur : pas_mene »).
  local dir = Scriptorium.directeur
  if dir and personnage ~= nil and dir.personnage and dir.personnage() == personnage then
    return dir.dire_une_replique(quoi)
  end
  local id = id_du_personnage(donnees(), personnage)
  if not id then
    return refuser("pas_mene", tostring(personnage))
  end
  return hommes.dire_une_replique(id, quoi)
end

function hommes.conversation_du_personnage(personnage, partenaire, quoi)
  local dir = Scriptorium.directeur
  if dir and personnage ~= nil and dir.personnage and dir.personnage() == personnage then
    return dir.conversation(partenaire, quoi)
  end
  local d = donnees()
  local id = id_du_personnage(d, personnage)
  if not id then
    return refuser("pas_mene", tostring(personnage))
  end
  local autre = id_du_personnage(d, partenaire)
  if not autre then
    return refuser("partenaire_invalide", tostring(partenaire))
  end
  return hommes.conversation(id, autre, quoi)
end

-- Demande du pair (21/10, J6 : l'expédition de Scriptorium avançait ses hommes hors de vue par SetWorldPos ; un homme en
-- selle ne bougeait pas) : poser un homme à un point, hors de la vue d'Henry ; son cheval de sortie avec lui (en selle,
-- le cavalier suit sa monture ; à pied, le cheval posé près du point, l'homme par la téléportation du jeu, l'ordre 10 du
-- secours) ; son ordre est redonné au battement suivant. « qui » : l'identifiant d'un homme, ou le nom d'entité d'un
-- homme ou d'un mené. Rend vrai, ou faux et la raison.
function hommes.poser(qui, point)
  local d = donnees()
  local id = (d.liste[qui] and qui) or (d.menes and d.menes[qui] and qui) or id_du_personnage(d, qui)
  local f = id and fiche_de(d, id)
  if not f then
    return refuser("homme_inconnu", tostring(qui))
  end
  if type(point) ~= "table" or type(point.x) ~= "number" or type(point.y) ~= "number" or type(point.z) ~= "number" then
    return refuser("point_invalide", tostring(qui))
  end
  local ici = f.personnage and jeu().position_du_personnage(f.personnage)
  if not ici then
    return refuser("personnage_introuvable", f.nom)
  end
  if sous_les_yeux_d_henry(ici) or sous_les_yeux_d_henry(point) then
    return refuser("vu_d_henry", f.nom)
  end
  local m = hommes.montures[id]
  local cheval = m and m.cheval
  local en_selle = cheval ~= nil and jeu().cheval_monte(cheval) == true
  local ligne
  if cheval and en_selle then
    local ok, dit = jeu().poser_le_cheval(cheval, point)
    if not ok then
      return refuser("pose_refusee", f.nom .. " : " .. tostring(dit))
    end
    ligne = "en selle, avec « " .. cheval .. " » : " .. tostring(dit)
  else
    if cheval then
      local la = { x = point.x + hommes.reglages.cheval_distance_m, y = point.y, z = point.z }
      jeu().poser_le_cheval(cheval, la)
    end
    ligne = tostring(jeu().poser_en_secours(f.personnage, point)) .. (cheval and (" ; « " .. cheval .. " » près de lui") or "")
  end
  f.derniere_activite = nil
  hommes.suivi[id] = nil
  jeu().journal(string.format("Hommes : « %s » posé en (%.1f, %.1f) : %s", f.nom, point.x, point.y, ligne))
  return true
end

-- La parole qui se joue (ou attend) pour cet homme : une copie, ou nil.
function hommes.parole_de(id)
  local p = hommes.paroles[id]
  if not p then
    return nil
  end
  return { sorte = p.sorte, alias = p.alias, metarole = p.metarole, partenaire = p.partenaire, numero = p.numero,
           urgente = p.urgente }
end

-- ---------------------------------------------------------------- le poste partagé avec Henry (fiche 18, 5 c, tranche 4)

-- Les stations surveillées, en mémoire (reposées à chaque battement) : nom de l'entité -> { prise, depuis }.
hommes.stations = hommes.stations or {}

-- Surveiller une station du jeu qu'Henry emploie aussi (son nom d'entité). « oui » à faux : plus surveillée.
function hommes.partager_avec_henry(station, oui)
  if type(station) ~= "string" or station == "" then
    return refuser("station_inconnue", tostring(station))
  end
  if oui == false then
    hommes.stations[station] = nil
    if jeu().partager_avec_henry then jeu().partager_avec_henry(station, false) end
    return true
  end
  hommes.stations[station] = hommes.stations[station] or { prise = false }
  if jeu().partager_avec_henry and not jeu().partager_avec_henry(station, true) then
    jeu().journal("Hommes : station « " .. station .. " » introuvable pour l'instant (reposée au battement)")
  end
  return true
end

-- La station est-elle prise par Henry ? (vrai, faux, ou nil si elle n'est pas surveillée)
function hommes.station_prise(station)
  local s = hommes.stations[station]
  if not s then
    return nil
  end
  return s.prise == true
end

-- Décision remplaçable (fiche 19) : où l'homme attend que la station se libère. Par défaut, à « partage_attente_m » de la
-- station, de son côté (sans position lisible : près de la station).
function hommes.ou_attendre(id, station)
  local f = donnees().liste[id]
  local la = jeu().position_d_un_objet and jeu().position_d_un_objet(station) or nil
  if not la then
    return nil
  end
  local ici = f and f.personnage and jeu().position_du_personnage(f.personnage)
  local dx, dy = 1, 0
  if ici then
    dx, dy = ici.x - la.x, ici.y - la.y
  end
  local longueur = math.sqrt(dx * dx + dy * dy)
  if longueur < 0.1 then
    dx, dy, longueur = 1, 0, 1
  end
  local m = (tonumber(hommes.reglages.partage_attente_m) or 2.5) / longueur
  return { x = la.x + dx * m, y = la.y + dy * m, z = la.z }
end
Scriptorium.remplacable(hommes, "ou_attendre", function(rendu)
  return type(rendu) == "table" and type(rendu.x) == "number" and type(rendu.y) == "number" and type(rendu.z) == "number"
end)

local function redonner_aux_partageurs(d, station, heure)
  for _, id in ipairs(d.ordre) do
    local f = d.liste[id]
    for _, t in pairs(f.tenues or {}) do
      if t.partage == station then
        f.derniere_activite = nil
        ordonner_un_homme(d, id, heure, nil, true)
        break
      end
    end
  end
end

-- Henry vient de prendre la station (appelé par la liaison, l'action « use » de la station).
function hommes.henry_prend_la_station(station)
  local s = hommes.stations[station]
  if not s or s.prise then
    return
  end
  s.prise, s.depuis = true, jeu().maintenant()
  jeu().journal("Hommes : Henry prend la station « " .. station .. " » : ses hommes lui cèdent la place")
  redonner_aux_partageurs(donnees(), station, jeu().heure_du_jeu())
end

-- Au battement : les enveloppes reposées ; une station prise, rendue quand Henry a fini.
local function veiller_les_stations(d, heure)
  for station, s in pairs(hommes.stations) do
    if jeu().partager_avec_henry then
      jeu().partager_avec_henry(station, true)
    end
    if s.prise and jeu().henry_a_fini and jeu().henry_a_fini(station, s.depuis, tonumber(hommes.reglages.partage_delai_s) or 0,
        tonumber(hommes.reglages.partage_loin_m) or 6) then
      s.prise, s.depuis = false, nil
      jeu().journal("Hommes : Henry rend la station « " .. station .. " » : ses hommes reprennent")
      redonner_aux_partageurs(d, station, heure)
    end
  end
end
hommes.veiller_les_stations = veiller_les_stations

-- La bascule (l'affrontement, 18/10) : pour chaque homme tenu à affronter : la cible à terre (assommée ou morte selon
-- « jusqu_a » ; morte suffit toujours), la tenue est lâchée, une ligne au journal ; sinon, s'il ne se bat pas, son ordre
-- est redonné au battement (comme la bataille relance qui ne se bat pas).
function hommes.veiller_les_affrontements(d)
  for _, id in ipairs(d.ordre) do
    local f = d.liste[id]
    for regle, t in pairs(f and f.tenues or {}) do
      if t.activite == "affronter" and t.cible then
        local morte = jeu().personnage_mort(t.cible)
        local a_terre = morte or (t.jusqu_a == "assomme" and jeu().personnage_inconscient(t.cible) == true)
        if a_terre then
          jeu().journal("Hommes : « " .. f.nom .. " » a mis « " .. t.cible .. " » à terre (" .. (morte and "mort" or "assommé")
                        .. ") : l'affrontement est fini")
          hommes.lacher(id, regle)
        elseif f.personnage and jeu().occupation_de(f.personnage) ~= "combat" then
          f.derniere_activite = nil
        end
      end
    end
  end
end

-- Service (réponse 3 a de JoVenGer, V73 b) : exempter un homme d'une règle, par exemple un compagnon de la garde de nuit
-- (« garde_de_nuit ») ; l'arbitre et la garde du socle ne la lui donnent plus, et sa tenue de cette règle tombe. « oui »
-- à faux lève l'exemption. Qui est compagnon, c'est Scriptorium qui le décide.
function hommes.exempter(id, regle, oui)
  local d = donnees()
  local f = d.liste[id]
  if not f then
    return refuser("homme_inconnu", tostring(id))
  end
  if not rang_de(regle) then
    return refuser("regle_inconnue", tostring(regle))
  end
  f.exemptions = f.exemptions or {}
  if oui == false then
    f.exemptions[regle] = nil
  else
    f.exemptions[regle] = true
    if f.tenues then
      f.tenues[regle] = nil
    end
  end
  enregistrer()
  ordonner_un_homme(d, id, jeu().heure_du_jeu(), nil, true)
  return true
end

-- Service pour le guichet (fiche 13, proposé par le pair) : rhabiller cet homme maintenant (sortie du bain, achat à la
-- forge, changement de grade) : il remet ses propres pièces aussitôt (le second passage et l'accroche suivent au
-- battement) ; au lit, au bain ou en combat, il est seulement marqué, pour quand la garde pourra le toucher.
function hommes.rhabiller(id)
  local d = donnees()
  local f = d.liste[id]
  if not f then
    return refuser("homme_inconnu", tostring(id))
  end
  if not (f.equipement and f.personnage) then
    return refuser("sans_equipement", f.nom)
  end
  local raison = garde_suspendue(id, f)
  if raison then
    f.equipement.etat = "a_rhabiller"
    jeu().journal("Hommes : « " .. f.nom .. " » sera rhabillé plus tard (" .. raison .. ")")
  else
    rhabiller(d, f)
  end
  enregistrer()
  return true
end

-- Service : la règle qui tient l'homme à cette heure (une règle du catalogue, « journee », ou « aucune » quand la
-- journée du socle est coupée), et son activité ({ regle, activite, lieu, position, cap, fin }). Rend nil si l'homme est
-- inconnu.
function hommes.qui_tient(id, heure)
  local a = Scriptorium.avis(hommes, "activite_de", id, heure or jeu().heure_du_jeu())
  if not a then
    return nil
  end
  return a.regle, a
end

-- Après un chargement : fait revenir les personnages manquants. Rend (revenus, manquants).
-- L'escorte d'Henry (V73 f 3 b) : la tenue la plus forte de l'homme le fait suivre (Henry, le Directeur, ou un homme qui
-- suit) ; elle passe d'une carte à l'autre avec lui.
local function en_escorte(f)
  local _, t = tenue_la_plus_forte(f)
  return t ~= nil and t.activite == "suivre" and t.vers == nil
end

function hommes.redresser()
  local d = donnees()
  local revenus, manquants, laisses = 0, 0, 0
  -- V73 f 3 b : sur une autre carte que celle du camp, seule l'escorte d'Henry est refaite, près de lui ; les autres
  -- restent au registre (sans personnage) et reviennent quand Henry revient sur la carte du camp.
  local sur_place = camp().sur_sa_carte == nil or camp().sur_sa_carte()
  for _, id in ipairs(d.ordre) do
    local f = d.liste[id]
    local present = f.personnage and jeu().personnage_existe(f.personnage)
    if f.dehors then
      -- Fiche 17 : en mission, hors du monde ; il rentre par sa mission.
      laisses = laisses + 1
    elseif f.admis then
      -- Fiche 18, 5 c : un personnage admis n'est jamais refait ; absent, il attend.
      if not present then
        laisses = laisses + 1
      end
    elseif not present or not f.ame then
      if sur_place or en_escorte(f) then
        if faire_venir(d, f, not sur_place) then revenus = revenus + 1 else manquants = manquants + 1 end
      else
        if not present then
          f.personnage = nil
        end
        laisses = laisses + 1
      end
    end
  end
  if revenus > 0 or laisses > 0 then
    enregistrer()
  end
  jeu().journal("Hommes : redressés, " .. revenus .. " revenu(s), " .. manquants .. " manquant(s)"
                .. (laisses > 0 and (", " .. laisses .. " laissé(s) au camp (autre carte)") or ""))
  return revenus, manquants
end

-- Fiche 17, 4 b : un homme « dehors » (une mission loin d'Henry) : son personnage et son cheval retirés du monde, sa
-- fiche gardée au registre ; il n'est ni refait, ni de garde, ni à défendre le camp. Rend vrai, ou faux et la raison.
function hommes.mettre_dehors(id, motif)
  local d = donnees()
  local f = d.liste[id]
  if not f then
    return refuser("homme_inconnu", tostring(id))
  end
  if f.admis then
    return refuser("personnage_admis", f.nom)
  end
  local m = hommes.montures[id]
  if m and m.cheval then
    jeu().retirer_cheval(m.cheval)
  end
  hommes.montures[id] = nil
  if f.personnage then
    jeu().renvoyer_homme(f.personnage)
    f.personnage = nil
  end
  f.dehors = tostring(motif or "dehors")
  f.derniere_activite = nil
  enregistrer()
  jeu().journal("Hommes : « " .. f.nom .. " » dehors (" .. f.dehors .. ")")
  return true
end

-- Il rentre : il renaît au point donné (hors de la vue d'Henry : à qui l'appelle d'y veiller) ; sans point, près
-- d'Henry. Rend vrai, ou faux.
function hommes.faire_rentrer(id, position)
  local d = donnees()
  local f = d.liste[id]
  if not f or not f.dehors then
    return refuser("pas_dehors", tostring(id))
  end
  f.dehors = nil
  local venu = faire_venir(d, f, position == nil, position)
  enregistrer()
  jeu().journal("Hommes : « " .. f.nom .. " » rentre" .. (venu and "" or " (le jeu ne l'a pas fait venir : au registre)"))
  return venu
end

function hommes.est_dehors(id)
  local f = donnees().liste[id]
  return f ~= nil and f.dehors ~= nil
end

-- Entrée en partie (nouvelle ou chargée). Vu en jeu le 15/10 (V56) : après « Sauvegarder et quitter » puis
-- rechargement, nos personnages sont encore dans le monde et leur cerveau tourne sans réveil, mais ses variables
-- reviennent à zéro : l'ordre en cours est perdu. Chaque homme présent reçoit donc de nouveau son ordre au battement
-- suivant, et les personnages manquants reviennent. Rend (revenus, manquants).
function hommes.relancer()
  local d = donnees()
  hommes.ordres_differes, hommes.prochain_creneau = {}, nil
  hommes.suivi = {}
  hommes.en_ronde = {}
  hommes.montures = {}
  hommes.chevaux_laisses = {}
  hommes.henry_monte, hommes.henry_pied_lectures = false, 0
  hommes.henry_derniere_position = nil
  hommes.lancer_la_veille_d_henry()
  hommes.gardien = { vus = {}, relances = 0, utiles = 0, repeches = 0 }
  hommes.lancer_le_gardien()
  hommes.raisons_de_reprise = {}
  hommes.cerveaux_regles = {}
  hommes.arrets_vus = {}
  hommes.fins_de_combat_vues = {}
  hommes.lancements_vus = {}
  for _, id in ipairs(d.ordre) do
    local f = d.liste[id]
    f.derniere_activite = nil
    hommes.raisons_de_reprise[id] = "rechargement"
    -- Fiche 13, V71 b : chacun remettra ses propres affaires, un par battement.
    if f.equipement and (f.equipement.etat == "pret" or f.equipement.etat == "a_completer") then
      f.equipement.etat = "a_rhabiller"
    elseif f.equipement and f.equipement.etat == "impossible" then
      f.equipement = nil
    end
  end
  return hommes.redresser()
end

-- Service pour le programme Scriptorium (fiche 13, V71 b) : le grade d'un homme change ; sa famille et son âme
-- restent ; il reçoit au battement suivant la tenue et les armes du nouveau grade ; les pièces de l'ancien grade sont
-- rendues au camp par l'accroche « piece_otee » (réponse a de JoVenGer, 15/10).
function hommes.changer_de_palier(id, palier)
  local d = donnees()
  local f = d.liste[id]
  if not f then
    return refuser("homme_inconnu", tostring(id))
  end
  local nb_paliers = #jeu().paliers_de(hommes.roles[f.role].reserve)
  if type(palier) ~= "number" or math.floor(palier) ~= palier or palier < 1 or palier > math.max(nb_paliers, 1) then
    return refuser("palier_invalide", tostring(palier))
  end
  if palier == f.palier then
    return true
  end
  f.palier = palier
  hommes.reequiper_la_fiche(d, f)
  jeu().journal("Hommes : « " .. f.nom .. " » passe au palier " .. palier)
  return true
end

-- Le choix d'équipement refait (décision remplaçable « choix_de_l_equipement »), à son palier : les pièces de l'ancien
-- choix sont offertes à l'accroche « piece_otee » une fois le nouveau porté (comme un changement de palier).
function hommes.reequiper_la_fiche(d, f)
  local e = f.equipement
  local anciennes = {}
  if e and (e.etat == "pret" or e.etat == "a_rhabiller" or e.etat == "a_completer") then
    for _, nom in ipairs({ e.tenue, e.armes }) do
      for _, objet in ipairs(jeu().pieces_de(nom) or {}) do
        table.insert(anciennes, objet)
      end
    end
  end
  local refait = false
  if est_combattant(f) and not f.admis and choisir_l_equipement(d, f) then
    f.equipement.otees = {}
    f.equipement.anciennes = #anciennes > 0 and anciennes or nil
    refait = true
  end
  enregistrer()
  return refait
end

-- Service pour Scriptorium (demande du pair, 18/10 : la tenue propre du colonel) : rééquiper un homme sans changer son
-- palier. Rend vrai (équipé au battement), ou faux et la raison.
function hommes.reequiper(id)
  local d = donnees()
  local f = d.liste[id]
  if not f then
    return refuser("homme_inconnu", tostring(id))
  end
  if not est_combattant(f) or f.admis then
    return refuser("pas_d_equipement_du_socle", f.nom)
  end
  if not hommes.reequiper_la_fiche(d, f) then
    return refuser("choix_impossible", f.nom)
  end
  jeu().journal("Hommes : « " .. f.nom .. " » sera rééquipé (palier " .. tostring(f.palier) .. ")")
  return true
end

-- Service pour le guichet (fiche 13, V71 b) : une pièce donnée à un homme (forge, butin) est créée une à une dans son
-- sac, avec son état ; portée, elle s'ajoute à ce qu'il porte, après sa tenue de grade.
function hommes.donner_une_piece(id, objet, etat, porter)
  local d = donnees()
  local f = d.liste[id]
  if not f then
    return refuser("homme_inconnu", tostring(id))
  end
  if type(objet) ~= "string" or not string.match(objet, "^%x+%-%x+%-%x+%-%x+%-%x+$") then
    return refuser("objet_invalide", tostring(objet))
  end
  etat = etat or hommes.equipement.etat_neuf
  if type(etat) ~= "number" or etat <= 0 or etat > 1 then
    return refuser("etat_invalide", tostring(etat))
  end
  if not (f.personnage and jeu().personnage_existe(f.personnage)) then
    return refuser("homme_absent", f.nom)
  end
  objet = string.lower(objet)
  if not jeu().creer_objet(f.personnage, objet, etat, 1) then
    return refuser("objet_refuse", objet)
  end
  if porter then
    if not f.equipement and est_combattant(f) and not f.admis then
      choisir_l_equipement(d, f)
    end
    f.equipement = f.equipement or { en_plus = {}, otees = {}, naissance_retiree = false, etat = "pret" }
    table.insert(f.equipement.en_plus, { objet = objet, etat = etat })
    jeu().faire_porter(f.personnage, { objet })
  end
  enregistrer()
  jeu().journal("Hommes : une pièce donnée à « " .. f.nom .. " » (" .. objet .. ", état " .. etat .. ")")
  return true
end

-- Service pour Scriptorium (demande du pair, 18/10 : la forge, règles de JoVenGer du 22/09 et du 6/10) : une pièce que
-- l'homme porte est changée pour une neuve de la même classe, à « etat » (0 à 1), portée ; l'ancienne est détruite. Ce
-- qu'il porte ne change pas dans les livres du socle (même classe) ; une pièce donnée garde son nouvel état. Rend vrai,
-- ou faux et la raison.
function hommes.remplacer_une_piece(id, objet, etat)
  local d = donnees()
  local f = d.liste[id]
  if not f then
    return refuser("homme_inconnu", tostring(id))
  end
  if not (f.personnage and jeu().personnage_existe(f.personnage)) then
    return refuser("homme_absent", f.nom)
  end
  -- Seule une pièce qu'il porte est acceptée (plus bas) : la forme de l'objet n'a pas à être éprouvée à part.
  if type(objet) ~= "string" or objet == "" then
    return refuser("objet_invalide", tostring(objet))
  end
  if type(etat) ~= "number" or etat <= 0 or etat > 1 then
    return refuser("etat_invalide", tostring(etat))
  end
  objet = string.lower(objet)
  local porte = false
  for _, o in ipairs(liste_portee(f)) do
    if o == objet then
      porte = true
    end
  end
  if not porte then
    return refuser("piece_non_portee", f.nom .. " : " .. objet)
  end
  if not jeu().remplacer_un_objet(f.personnage, objet, etat) then
    return refuser("remplacement_refuse", f.nom .. " : " .. objet)
  end
  for _, piece in ipairs((f.equipement and f.equipement.en_plus) or {}) do
    if type(piece) == "table" and piece.objet == objet then
      piece.etat = etat
    end
  end
  enregistrer()
  jeu().journal("Hommes : « " .. f.nom .. " » : une pièce remplacée par une neuve (" .. objet .. ", état " .. etat .. ")")
  return true
end

-- Décision remplaçable (demande du pair, 18/10 : au camp, le colonel ôte son bassinet ; dehors, en alerte, au combat,
-- il le remet) : les pièces de cet homme qui restent au sac maintenant, une liste d'objets, ou nil (aucune). Par défaut :
-- aucune. Seules les pièces qu'il porte dans les livres du socle comptent ; les autres sont ignorées.
function hommes.pieces_au_sac(id)
  return nil
end
Scriptorium.remplacable(hommes, "pieces_au_sac", function(rendu)
  if type(rendu) ~= "table" then
    return false
  end
  for _, objet in ipairs(rendu) do
    if type(objet) ~= "string" or objet == "" then
      return false
    end
  end
  return true
end)

-- Au battement : pour chaque homme équipé, la décision lue ; une pièce nouvellement au sac y est rangée, une pièce qui
-- n'y est plus est remise. Jamais pour un homme absent ou pas encore équipé. Rend le nombre de pièces déplacées.
function hommes.appliquer_les_pieces_au_sac(d)
  local deplacees = 0
  for _, id in ipairs(d.ordre) do
    local f = d.liste[id]
    local e = f.equipement
    if e and (e.etat == "pret" or e.etat == "a_completer") and f.personnage and jeu().personnage_existe(f.personnage) then
      local portees = {}
      local avant_le_sac = e.au_sac
      e.au_sac = nil
      for _, o in ipairs(liste_portee(f)) do
        portees[o] = true
      end
      e.au_sac = avant_le_sac
      local voulues = {}
      for _, objet in ipairs(Scriptorium.avis(hommes, "pieces_au_sac", id) or {}) do
        objet = string.lower(objet)
        if portees[objet] then
          voulues[objet] = true
        end
      end
      local deja = {}
      for _, objet in ipairs(e.au_sac or {}) do
        deja[objet] = true
      end
      local neuves = {}
      for objet in pairs(voulues) do
        if deja[objet] then
          table.insert(neuves, objet)
        elseif jeu().ranger_au_sac(f.personnage, objet) then
          table.insert(neuves, objet)
          deplacees = deplacees + 1
          jeu().journal("Hommes : « " .. f.nom .. " » range au sac " .. objet)
        end
      end
      for objet in pairs(deja) do
        if not voulues[objet] then
          jeu().faire_porter(f.personnage, { objet })
          deplacees = deplacees + 1
          jeu().journal("Hommes : « " .. f.nom .. " » remet " .. objet)
        end
      end
      table.sort(neuves)
      e.au_sac = #neuves > 0 and neuves or nil
    end
  end
  if deplacees > 0 then
    enregistrer()
  end
  return deplacees
end

-- Accroche du guichet (fiche 13, V71 b) : une pièce qu'il ne porte plus (vendue, cassée, perdue) sort de ce qu'il porte.
function hommes.piece_otee(id, objet)
  local d = donnees()
  local f = d.liste[id]
  if not f then
    return refuser("homme_inconnu", tostring(id))
  end
  if type(objet) ~= "string" then
    return refuser("objet_invalide", tostring(objet))
  end
  objet = string.lower(objet)
  local e = f.equipement
  if not e then
    return refuser("sans_equipement", f.nom)
  end
  for i = #e.en_plus, 1, -1 do
    if objet_de(e.en_plus[i]) == objet then
      table.remove(e.en_plus, i)
      enregistrer()
      return true
    end
  end
  table.insert(e.otees, objet)
  enregistrer()
  return true
end

-- L'allure du chef monté (fiche 15, V73 f 2 f) : la règle, en données (voir « allure_* »). « vitesse » : celle de celui
-- qu'il suit (m/s) ; « ecart » : la distance qui les sépare (m) ; « fond_avant », « correction_avant », « code_avant » :
-- l'allure de fond, la correction et le code du relevé précédent (les tenues) ; « perdu_avant » : le cavalier était
-- perdu (V73 f 2 g). Rend (le code : 3 galop, 2 trot rapide, 1 course, 0 pas, -1 tenir ; l'allure de fond, sans
-- correction ; la correction par la distance : 1, 0 ou -1 ; perdu : loin de son chef, avec sa tenue).
function hommes.allure_du_chef(vitesse, ecart, fond_avant, correction_avant, code_avant, perdu_avant)
  local r = hommes.reglages
  local fond = 0
  for k, seuil in ipairs({ r.allure_pas_m_s, r.allure_course_m_s, r.allure_galop_m_s }) do
    local s = seuil
    if fond_avant ~= nil then
      s = (fond_avant >= k) and seuil * (1 - r.allure_marge) or seuil * (1 + r.allure_marge)
    end
    if vitesse >= s then
      fond = k
    end
  end
  local place = r.allure_place_m
  -- La correction tenue (V73 f 2 f bis) : « une de plus » au-delà de la place + plus, gardée jusqu'à la place + freinage ;
  -- « une de moins » en deçà de la place − moins, gardée jusqu'à la place.
  local correction = 0
  if ecart > place + r.allure_plus_m or (correction_avant == 1 and ecart > place + r.allure_freinage_m) then
    correction = 1
  elseif ecart < place - r.allure_moins_m or (correction_avant == -1 and ecart < place) then
    correction = -1
  end
  local perdu = ecart > r.allure_perdu_m or (perdu_avant == true and ecart > r.allure_rang_m)
  local code = fond
  if vitesse < r.allure_arret_m_s then
    -- Arrêté : il s'arrête à sa place, et ne repart qu'au-delà de la place + plus (la tenue de l'arrêt).
    if ecart <= place or (code_avant == -1 and ecart <= place + r.allure_plus_m) then
      return -1, fond, 0, perdu
    end
    code = 0
  end
  code = math.max(-1, math.min(3, code + correction))
  return code, fond, correction, perdu
end

-- Le filtre des sauts (V73 f 2 g, relecture du pair) : un relevé au-delà de « allure_saut_m_s » (un saut d'Henry, une
-- pose) garde la vitesse d'avant. Rend la vitesse retenue.
function hommes.vitesse_retenue(mesuree, avant)
  if mesuree > hommes.reglages.allure_saut_m_s then
    return avant or 0
  end
  return mesuree
end

Scriptorium.declarer_morceau("hommes", function()
  -- Le battement est lancé par le poste d'essai ou par le socle une fois la partie chargée.
  -- La ronde (fiche 15, V73 d 2) : la liaison, appelée par l'arbre à chaque point, demande le pas suivant aux hommes.
  if jeu() and jeu().accrocher_la_ronde then
    jeu().accrocher_la_ronde(function(personnage) return Scriptorium.avis(hommes, "pas_de_ronde", personnage) end)
  end
  -- Fiche 18, 5 c, tranche 4 : la station prise par Henry, dite par la liaison.
  if jeu() and jeu().accrocher_la_station then
    jeu().accrocher_la_station(function(station) return hommes.henry_prend_la_station(station) end)
  end
  -- Fiche 18, 5 b : « Parler » à un homme parlable ; la liaison donne le personnage, l'accroche reçoit l'homme.
  if jeu() and jeu().accrocher_la_parole then
    jeu().accrocher_la_parole(function(personnage)
      local d = donnees()
      for _, id in ipairs(d.ordre) do
        if d.liste[id].personnage == personnage then
          return hommes.quand_on_lui_parle(id)
        end
      end
    end)
  end
  -- Fiche 21 : les dialogues ; la liaison, appelée par l'ExitScript d'un choix d'Henry, demande la réponse aux hommes.
  if jeu() and jeu().accrocher_le_dialogue then
    jeu().accrocher_le_dialogue(function(arbre, choix, personnage)
      return hommes.repondre_au_dialogue(arbre, choix, personnage)
    end)
  end
  -- L'allure du chef monté (V73 f 2 f) : la liaison, appelée par l'arbre toutes les 300 ms, demande l'allure aux hommes.
  if jeu() and jeu().accrocher_l_allure then
    jeu().accrocher_l_allure(hommes.allure_du_chef, hommes.vitesse_retenue)
  end
end)
