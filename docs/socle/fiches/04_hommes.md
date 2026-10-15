# Fiche 04 — Les hommes au camp

- Morceau : 4. Table : `Scriptorium.hommes`. Fichier : `socle/pak/Scripts/scriptorium/hommes.lua`.
- État : écrit et passé au banc ; vu en jeu (trois hommes venus au camp, solde et prime au coffre). Validée par JoVenGer le 14/10/2026 : soldes, prime de deux semaines, départ après deux semaines impayées, **deux rations par homme et par jour**, rangs, journée, garde et départs tels quels. Leurs gestes (marcher, s'asseoir, dormir, se battre) attendent un cerveau à nous (V17, V18).
- Avec la fiche 11 (caractère, 15/10) : la ration de chacun suit son appétit, les soins sa forme ; la veillée est son temps libre (le feu, l'entraînement, les dés ou le lit, selon sa fatigue et ses envies) ; une perte de moral commune pèse selon le sang-froid de chacun.

## Ce que le joueur voit
- Des hommes engagés par contrat, qui vivent au camp : le jour ils mangent, s'exercent et font les corvées ; le soir ils veillent au feu ; la nuit ils dorment sous les tentes ou montent la garde, par tours de veille.
- Chacun a un nom d'époque (Jan Kladivo, Ondřej le Rouge…), un rôle, un rang.
- Messages : « Un homme a rejoint la Compagnie : Jan Kladivo », « La solde a été payée : 84 groschen », « La solde n'a pas pu être payée : le coffre manque de groschen. », « Les hommes ont eu faim : les vivres manquent. », « A déserté : … », « A été fait dizainier : … ».

## Règles
- **Fiche par homme :** identifiant, nom, rôle, rang, contrat (semaines, solde hebdomadaire, prime, début, fin), moral (0 à 100), blessure (jours de soin restants), semaines impayées, présence dans le jeu (identifiant du personnage).
- **Rôles** et solde hebdomadaire de base en groschen : homme d'armes 12, arbalétrier 14, archer 12, pavoisier 10, barbier 15, cuisinier 8, armurier 16.
- **Rangs :** soudoyer (solde × 1), dizainier (× 1,5), capitaine (× 2). Un dizainier pour dix hommes, promu d'office parmi les plus anciens ; rétrogradé si la compagnie rétrécit. Le capitaine (hejtman) est nommé par le joueur ; à dix hommes sans capitaine, le dizainier le plus ancien le devient.
- **Embauche par contrat :** `embaucher{ role, semaines, solde?, prime? }`. Durée de 1 à 52 semaines. Prime par défaut : deux semaines de solde, payée au coffre ; refus si le coffre ne peut pas. Il faut une paillasse libre (le lit du Directeur ne compte pas) : sinon « Pas de paillasse libre : agrandissez le camp. » L'homme existe d'abord sur le registre ; le jeu est ensuite prié de faire venir le personnage ; s'il ne peut pas, l'homme reste sur le registre et `redresser()` réessaiera.
- **Solde hebdomadaire :** payée au coffre, chaque semaine à 8 h, en commençant par les plus anciens. Payé : moral + 5. Impayé : moral − 20 ; deux semaines impayées de suite : l'homme s'en va.
- **Vivres :** deux rations par homme et par jour (choix de JoVenGer), prises au repas de 7 h sur la réserve `vivres` du coffre. Nourri : moral + 2. Affamé : moral − 10, et le joueur est prévenu une fois par jour.
- **Moral :** quatre niveaux, abattu (< 25), morose (< 50), content (< 75), ardent. À l'aube (5 h), un homme au moral sous 10 déserte. Les batailles (morceau 5) feront varier le moral par `moral_pour_tous`.
- **Journée réglée sur les heures :** lever 5 h, repas 7 h, exercice 8 h à 12 h, repas 12 h, corvée 13 h à 18 h, repas 18 h, veillée 19 h à 22 h, sommeil 22 h à 5 h. Les places : sommeil sur sa paillasse, repas et veillée sur un siège (ou debout au feu s'il n'y en a plus), exercice et corvée à des points du camp.
- **Garde :** un poste pour quatre hommes valides le jour (un au plus), un poste pour deux hommes valides la nuit (deux au plus) : **jamais plus de postes que d'hommes** (règle de JoVenGer), et un homme seul dort au lieu de veiller. Tours de veille de trois heures, en rotation ; les blessés ne gardent pas. Quatre postes autour du camp, à douze mètres.
- **Blessés :** `blesser(id, jours)`. Un blessé se repose sur sa paillasse, ne s'exerce pas et ne garde pas. Chaque jour, un jour de soin en moins ; deux avec un barbier valide au camp.
- **Départs :** fin de contrat (à l'aube, sauf renouvellement par `renouveler(id, semaines)`), solde impayée, désertion, renvoi par le joueur (`renvoyer`), mort (`retirer(id, "mort")`, par le morceau 5). La paillasse est libérée, le personnage renvoyé, la fiche gardée dans les anciens (cinquante au plus) avec la cause.
- **Ordres :** à chaque battement, l'activité de chaque homme présent est calculée ; si elle change, le jeu reçoit l'ordre (activité, place, position). Jamais deux fois le même ordre. À l'entrée en partie (nouvelle ou chargée), chacun reçoit de nouveau son ordre en cours et les personnages manquants reviennent : le cerveau d'un homme ne garde pas ses variables à la sauvegarde (V56, fiche 12).
- **Enregistrement :** après chaque événement (embauche, départ, paie, repas, promotion, blessure).

## Sorts rendus
`embaucher` rend l'identifiant, ou `false` et une raison : `camp_absent`, `role_inconnu`, `duree_invalide`, `pas_de_lit`, `coffre_insuffisant`. Les autres : `homme_inconnu`, `rang_invalide`, `jours_invalides`.

## Réglages (`hommes.reglages`)
`moral_depart` 60, `ration` 2, `heure_lever` 5, `heure_repas` 7, `heure_paie` 8, `semaines_impayees_max` 2, `moral_desertion` 10, `postes_garde_jour` 1, `postes_garde_nuit` 2, `hommes_par_poste_jour` 4, `hommes_par_poste_nuit` 2, `duree_tour_de_garde` 3, `anciens_gardes` 50.

## Ce qui est sauvegardé (case `hommes`, version 1)
`{ prochain = 1, prochain_nom = 1, liste = { [id] = fiche }, ordre = {…}, anciens = {…}, prochaine_paie, dernier_jour_repas, derniere_aube, derniere_heure, capitaine }`.

## Ce que les hommes demandent au jeu (liaison)
`faire_venir_homme(ame, nom, position)` → identifiant de personnage ou nil (l'âme de l'homme, tirée à l'embauche dans la réserve de son rôle et gardée sur sa fiche : fiche 13 ; `ame_de(reserve, palier, numero)`, `paliers_de(reserve)`) ; `personnage_existe(identifiant)` ; `renvoyer_homme(identifiant)` ; `ordonner(identifiant, activite, position, place)` ; `heure_du_jeu()` ; `journal(texte)`. Et, par les autres morceaux : le coffre (prime, solde, vivres), le camp (paillasses, points).

## À vérifier en jeu
- Comment faire venir un personnage de la Compagnie (`System.SpawnEntity` classe `NPC` avec une âme à nous : tables du morceau 2.9) et comment lui donner un ordre simple (dormir ici, s'asseoir là, se tenir là). En attendant, la liaison note l'ordre au journal.
- Comment afficher un message avec un complément (le nom de l'homme, le montant) : la liaison compose `@clé` puis le complément.
- Les heures du jeu (`Calendar.GetWorldTime`) et leur unité.

## Essais au banc (`essais/lua/essai_hommes.lua`)
Embauche (prime, paillasse, nom d'époque, message) et ses refus ; solde hebdomadaire avec rangs, impayés, départ après deux semaines ; rations et faim ; journée et places ; garde bornée au nombre d'hommes, rotation, blessés exclus ; ordres donnés seulement au changement ; dizainiers et capitaine ; fin de contrat et renouvellement ; soins et barbier ; désertion ; renvoi et mort dans les anciens ; écriture puis relecture ; redressement des personnages manquants.
