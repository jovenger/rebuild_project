# Fiche 05 — Le combat et les batailles

- Morceau : 5. Table : `Scriptorium.bataille`. Fichier : `socle/pak/Scripts/scriptorium/bataille.lua`.
- État : écrit et passé au banc ; vu en jeu (la bande vient ; mort constatée par le jeu ; fin par le jeu et fin par la règle). Les personnages nés par script ne se battent pas encore : leur combat attend un cerveau à nous (V18). Validée par JoVenGer le 14/10/2026 : alerte, ordre de bataille, délai de deux heures, pertes, quatre sortes de bandes et partage tels quels ; **butin doublé** ; **corps ennemis laissés à fouiller**.
- Avec la fiche 11 (caractère, 15/10) : la force de chaque homme est multipliée par son aguerrissement, son courage et sa fatigue ; dans un rang, le moindre jugement tombe le premier ; les survivants se fatiguent, s'aguerrissent et se font connaître ; un blessé perd un point de forme.

## Ce que le joueur voit
- « Une bande approche du camp : » suivi du nombre, une heure avant qu'elle arrive (deux heures avec les tours de guet du morceau 7).
- Les hommes prennent leur ordre de bataille face à la menace : pavois et hommes d'armes devant, arbalétriers et archers derrière, chacun avec sa ligne de tir. Les blessés et les gens de métier restent au feu.
- La bande arrive ; le combat est celui du jeu. À la fin : « Victoire : la bande est repoussée. », « Victoire chèrement payée : … », « La bande a été repoussée, mais elle a mordu. » ou « Défaite : la bande a enfoncé le camp. », puis « Butin partagé, au coffre : » et le montant. Les ennemis encore debout s'en vont ; les corps tombent et restent sur place, à fouiller, une journée de jeu (vu en jeu le 15/10 : « Piller », « Saisir le corps »).

## Règles
- **Une seule entrée, « lever une bande » :** `lever_une_bande{ sorte, effectif, direction, delai }`. Sorte parmi `brigands`, `coumans`, `soudards`, `deserteurs` ; effectif de 1 à 60 ; direction en degrés (d'où elle vient, par rapport au camp) ; délai en heures de jeu avant l'arrivée (2 par défaut). Tous les raids passent par là. Refus sans camp fondé.
- **Marche, contact, fin.** Une bande est `en_marche`, puis `au_contact` à l'heure d'arrivée, puis `finie`. Elle arrive à soixante mètres du camp, du côté de sa direction, et marche sur le camp (ou sur la porte, si l'enceinte du morceau 7 existe).
- **Ordre de bataille d'époque.** Rang avant à dix mètres de l'ancre face à la menace : pavoisiers et hommes d'armes, à un mètre vingt l'un de l'autre. Rang arrière à sept mètres : arbalétriers et archers, placés dans les intervalles du rang avant, pour avoir une ligne de tir ; s'ils sont plus nombreux que les intervalles, ils débordent sur les ailes. Les blessés, le barbier, le cuisinier et l'armurier restent au feu. Au contact, chaque combattant reçoit l'affectation « bataille » (les hommes ne reprennent leur journée qu'à la fin).
- **Deux façons de finir.** Par le jeu : quand la bande a été appelée dans le jeu, la bataille finit quand il ne reste plus d'ennemi vivant, ou que tous nos combattants sont tombés ; les morts sont ceux que le jeu dit morts. Par la règle : quand le jeu ne peut pas faire venir la bande, ou après deux heures de contact sans fin, l'issue se calcule.
- **La règle.** Force des nôtres : somme des poids des combattants valides (homme d'armes 3, arbalétrier 2,5, pavoisier 2, archer 2), multipliée par le moral moyen (de 0,7 à 1,2) et par le bonus de l'enceinte s'il y en a une. Force de la bande : effectif × poids de la sorte (brigands 1, déserteurs 0,8, soudards 1,2, coumans 1,4). Rapport ≥ 1,5 : victoire ; ≥ 1 : victoire chèrement payée ; ≥ 0,7 : repoussée ; sinon défaite. Les pertes dépendent de l'issue (victoire : 0 mort, 15 % de blessés ; chère : 10 % de morts, 30 % de blessés ; repoussée : 20 % et 40 % ; défaite : 35 % et 40 %), le rang avant tombant le premier. Le hasard vient d'une graine gardée au registre : la même partie rejoue les mêmes coups.
- **Après la bataille.** Les morts quittent la Compagnie (`hommes.retirer(id, "mort")`), les blessés reçoivent de 2 à 5 jours de soins, le moral de tous bouge (victoire + 10, chère + 5, repoussée − 5, défaite − 15). Une défaite fait piller la moitié des groschen du coffre (ligne « pillage »).
- **Butin, partagé selon la coutume.** Victoire : effectif de la bande × butin par tête de la sorte (brigands 16, déserteurs 10, soudards 20, coumans 24 : doublé par JoVenGer) ; chère : 60 % ; repoussée : 20 % ; défaite : rien. Le tout entre au coffre (« butin »), puis en ressortent la part des hommes (la moitié, « part_hommes ») et la part du capitaine s'il y en a un (un sixième, « part_capitaine ») ; le coffre garde le reste.
- **Les corps.** À la fin d'une bataille venue dans le jeu, les ennemis encore debout sont retirés aussitôt (ils s'en vont) ; les corps restent à fouiller `duree_des_corps` heures de jeu, puis le battement les retire (choix de JoVenGer).
- **Le journal des batailles** garde les trente dernières issues.
- **Enregistrement** à chaque changement d'état d'une bande.

## Sorts rendus
`lever_une_bande` rend l'identifiant de la bande, ou `false` et une raison : `camp_absent`, `sorte_inconnue`, `effectif_invalide`, `direction_invalide`, `delai_invalide`.

## Réglages (`bataille.reglages`)
`delai_par_defaut` 2, `distance_arrivee` 60, `avertissement` 1, `duree_max_contact` 2, `ecart_entre_hommes` 1.2, `distance_rang_avant` 10, `distance_rang_arriere` 7, `effectif_max` 60, `journal_gardes` 30, `duree_des_corps` 24.

## Ce qui est sauvegardé (case `bataille`, version 1)
`{ prochaine = 1, bandes = { [id] = … }, ordre = {…}, resultats = {…}, graine }` ; une bande finie garde ses `corps` et l'heure `corps_retires_a` jusqu'à leur retrait.

## Ce que la bataille demande au jeu (liaison)
`faire_venir_ennemis(sorte, effectif, position, cap)` → liste d'identifiants ou nil ; `ennemis_vivants(liste)` → nombre ; `renvoyer_ennemis(liste)` ; `personnage_mort(identifiant)` ; `ordonner(…)` par les hommes ; `heure_du_jeu()` ; `journal(texte)`.

## À vérifier en jeu
- Comment faire venir une bande ennemie (classe `NPC`, âmes de brigands, de Coumans… du jeu de base) et compter les vivants.
- Comment savoir qu'un de nos personnages est mort (`personnage_mort`).
- Que les ordres de bataille (se tenir à une position, face à un cap) sont suivis par les personnages.

## Essais au banc (`essais/lua/essai_bataille.lua`)
Levée et refus ; avertissement puis arrivée, venue des ennemis, affectations et ordres ; ordre de bataille (rangs, intervalles, ailes, réserve) ; forces et moral ; les quatre issues de la règle ; pertes, soins, moral, pillage ; butin partagé au livre ; fin par le jeu (ennemis morts, nos morts constatés) ; fin par le délai ; journal des batailles ; graine stable ; écriture puis relecture.
