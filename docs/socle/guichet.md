# Le guichet — chaque entrée du contrat de Scriptorium face au service du socle

Contrat lu : `CONTRAT_DU_SOCLE.md`, empreinte sha256 5db5c6bda121dc16.

| n° | entrée du contrat | ce qu'elle fait | notre service |
|---|---|---|---|
| A1 | `GetCampFurniture` | enveloppée par : duels_judiciaires, en_garde_du_camp, lit_par_son_cote, prisonniers_des_raids | `Scriptorium.camp.places_libres(sorte, pour)` |
| A2 | `PickCombatTarget` | enveloppée par : conspiration_du_camp, duels_judiciaires, ordres_de_combat, prisonniers_des_raids | à ouvrir : `bataille.lua`, `lancer_l_attaque` (et `lancer_l_attaque_de_la_bande`) |
| A3 | `ApplyCampRole` | enveloppée par : pilori_du_directeur, pugilat_du_camp, roles_du_mod | `Scriptorium.hommes.tenir(id, regle, quoi)` |
| A4 | `ClaimSpot` | enveloppée par : amis_cote_a_cote, dialogue_des_mercenaires, nuit_du_camp | `Scriptorium.camp.reserver(nom, qui)` |
| A5 | `GiveArcherAmmo` | enveloppée par : arbaletriers_du_camp, banque_du_camp, stocks_des_metiers | à ouvrir : `hommes.lua`, `equiper` (les munitions de `hommes.equipement.tir`) |
| A6 | `BanditCampComplete` | enveloppée par : assaut_des_convois, intendant_missions | `Scriptorium.missions.camp_vaincu(c)` (accroche, fiche 17) |
| A7 | `CampActorYield` | enveloppée par : duels_judiciaires, en_garde_du_camp | à ouvrir : `hommes.lua`, `tenue_la_plus_forte` (l'arbitre des priorités) |
| A8 | `EquipMercenary` | enveloppée par : armures_de_la_forge, tenue_selon_le_grade | `Scriptorium.hommes.accrocher("apres_le_rhabillage", fonction)` |
| A9 | `FindQuartermasterTarget` | enveloppée par : directeur_en_retrait, prisonniers_des_raids | `Scriptorium.directeur.activite(heure)` |
| A10 | `GetCampActivity` | enveloppée par : duels_judiciaires, en_garde_du_camp | `Scriptorium.hommes.activite_de(id, heure)` |
| A11 | `LootSweepClear` | enveloppée par : portage_des_corps, sentinelles_du_camp | étape 4 (la fouille des corps, le butin) |
| A12 | `SpawnMercCamp` | enveloppée par : montage_du_camp, troupe_chez_elle | `Scriptorium.camp.fonder(position, cap)` |
| A13 | `UpdateMeleeCombatData` | enveloppée par : conspiration_du_camp, duels_judiciaires | à ouvrir : `bataille.lua`, `a_relancer` (le suivi au contact) |
| A14 | `AdvancePatrolWaypoint` | enveloppée par : nuit_du_camp | `Scriptorium.jeu.accrocher_la_ronde(fonction)` (enveloppe `Scriptorium.hommes.pas_de_ronde`) |
| A15 | `BanditCampScale` | enveloppée par : assaut_des_convois | `Scriptorium.missions.taille_du_camp(lieu, niveau)` (accroche, fiche 17) |
| A16 | `BountyReservedSites` | enveloppée par : missions_en_parallele | `Scriptorium.missions.lieu_reserve(nom)` (accroche, fiche 17, tranche 3) |
| A17 | `BreakMercCamp` | enveloppée par : montage_du_camp | `Scriptorium.camp.lever()` |
| A18 | `CampIsNight` | enveloppée par : journee_du_camp | réglage : journee.sommeil.de (la nuit est la tranche du sommeil, fiche 16) |
| A19 | `CampRelativeOffset` | enveloppée par : camp_en_arc | `Scriptorium.camp.dans_le_monde(ancre, x, y, cap)` |
| A20 | `CampRingPos` | enveloppée par : camp_en_arc | pas utile : pas d'anneau de tentes ; le plan du socle est la table `Scriptorium.camp.plan` |
| A21 | `ChangeMercOutfit` | enveloppée par : armures_de_la_forge | `Scriptorium.hommes.donner_une_piece(id, objet, etat, porter)` |
| A22 | `EquipArcherWeapon` | enveloppée par : tenue_selon_le_grade | à ouvrir : `hommes.lua`, `choisir_l_equipement` |
| A23 | `EquipMercenaryWeapon` | enveloppée par : tenue_selon_le_grade | à ouvrir : `hommes.lua`, `choisir_l_equipement` |
| A24 | `FollowStalled` | enveloppée par : pantins_d_entrainement | `Scriptorium.hommes.rattraper(personnage, chef, nom)` |
| A25 | `GearWantsCustom` | enveloppée par : mercenaires_aux_bains | `Scriptorium.hommes.tenir(id, "bains", quoi)` (avec `ne_pas_rhabiller`) |
| A26 | `GetArcherStanceCode` | enveloppée par : duels_judiciaires | pas utile : le socle ne règle aucune posture de tir ; le cerveau du jeu la choisit |
| A27 | `GetPatrolWaypoint` | enveloppée par : nuit_du_camp | `Scriptorium.hommes.tenir(id, "ronde", quoi)` (le `chemin` donné par Scriptorium) |
| A28 | `IsCampGuard` | enveloppée par : sentinelles_du_camp | `Scriptorium.hommes.gardes(heure)` |
| A29 | `IsValidEnemy` | enveloppée par : agent | à ouvrir : `bataille.lua`, `lancer_l_attaque` (la liste des ennemis vivants) |
| A30 | `LogiProcessWages` | enveloppée par : banque_du_camp | `Scriptorium.hommes.payer_la_solde()` (interrupteur `solde_de_la_semaine`) |
| A31 | `LogiRemoveOneMerc` | enveloppée par : tenir_la_compagnie | `Scriptorium.hommes.retirer(id, cause)` |
| A32 | `LogiWealthRaidTick` | enveloppée par : tenir_la_compagnie | pas utile : le socle ne lève aucune bande de lui-même ; Scriptorium appelle `Scriptorium.bataille.lever_une_bande(ordre)` |
| A33 | `LootEligibleMercs` | les hommes qui peuvent aller fouiller les corps | étape 4 (la fouille des corps, le butin) |
| A34 | `SpawnCampHouseBed` | enveloppée par : editeur_du_camp | étape 5 (un meuble posé par JoVenGer rendu utilisable, NOTE_METIERS §0) |
| A35 | `SpawnCampPracticeYard` | enveloppée par : pantins_d_entrainement | étape 5 (poste d'entraînement) |
| A36 | `SpawnQuartermaster` | enveloppée par : intendant_du_camp | `Scriptorium.directeur.installer()` |
| A37 | `TowerSpotIsValid` | enveloppée par : camp_selon_le_terrain | `Scriptorium.jeu.sol_de(position, pas)` |
| A38 | `TryClaimTarget` | enveloppée par : duels_judiciaires | à ouvrir : `bataille.lua`, `lancer_l_attaque` (les cibles, `b.cibles`) |
| A39 | `UpdateFormationLeader` | enveloppée par : directeur_en_route | `Scriptorium.directeur.suivre(oui, formation, a_cheval)` |
| A40 | `WBRaidClear` | retirer la bande d'un raid | à ouvrir : `bataille.lua`, `finir` (la fin de bataille) |
| F1 | `LoadString` | relire une valeur texte enregistree dans la partie, par son nom (nil si absente) | `Scriptorium.registre.lire(nom)` (après `Scriptorium.registre.declarer_case(nom, version, par_defaut, migrations)`) |
| F2 | `SaveString` | enregistrer une valeur texte dans la partie, par son nom ; elle doit survivre a la sauvegarde | `Scriptorium.registre.enregistrer()` |
| F3 | `CampActorInvalidate` | faire oublier a un homme son activite en cours, pour qu'il en reprenne une | `Scriptorium.hommes.lacher(id, regle)` |
| F4 | `IsAliveAndWell` | vrai si le personnage est vivant et en etat | `Scriptorium.jeu.personnage_mort(identifiant)` (et `Scriptorium.hommes.fiche(id)`, champ `blessure`) |
| F5 | `IsCampOut` | vrai si un homme est dehors (en sortie, hors du camp) | `Scriptorium.hommes.qui_tient(id, heure)` (règle `escorte` ou `patrouille`) |
| F6 | `IsHero` | vrai si le personnage est Henry | pas utile : Henry n'est jamais dans les listes du socle (`Scriptorium.hommes.liste()`) |
| F7 | `LogiState` | l'etat de la logistique : le coffre (coffer), les reserves | `Scriptorium.coffre.bilan()` |
| F8 | `CampSnapToGround` | poser une position au niveau du sol | `Scriptorium.jeu.au_sol(position)` |
| F9 | `LogiAdjust` | ajouter ou retirer une quantite a la logistique (le coffre, une reserve), avec une raison | `Scriptorium.coffre.encaisser(montant, motif)` / `Scriptorium.coffre.payer(montant, motif)` / `Scriptorium.coffre.ajouter_reserve(sorte, quantite, motif)` |
| F10 | `ReleaseSpot` | 8 dossier(s) | `Scriptorium.camp.liberer(nom)` |
| F11 | `LogiSave` | 7 dossier(s) | `Scriptorium.registre.enregistrer()` |
| F12 | `FindValidGround` | trouver un sol valide pres d'une position | `Scriptorium.jeu.au_sol(position)` (et `Scriptorium.jeu.sol_de(position, pas)`) |
| F13 | `SpawnCampFurnitureSO` | 6 dossier(s) | `Scriptorium.jeu.poser_objet_du_jeu(nom, position, cap, proprietes)` |
| F14 | `CampHasFightTarget` | 5 dossier(s) | `Scriptorium.jeu.occupation_de(qui)` (« combat ») |
| F15 | `GetArcherWeaponType` | 5 dossier(s) | `Scriptorium.hommes.fiche(id)` (champ `role` : `archer` ou `arbaletrier`) |
| F16 | `SpawnEnemyAt` | faire apparaitre un ennemi d'un groupe a une position | `Scriptorium.jeu.faire_venir_ennemis(sorte, effectif, position, cap)` |
| F17 | `CUStowSave` | 4 dossier(s) | pas utile : pas de réserve d'objets rangés ; les objets du camp sont reposés depuis le registre |
| F18 | `LogiAddMorale` | changer le moral de la compagnie, avec une raison | `Scriptorium.hommes.moral_pour_tous(delta)` |
| F19 | `LogiAliveCount` | 4 dossier(s) | `Scriptorium.hommes.effectif()` |
| F20 | `NoteAttacker` | 4 dossier(s) | pas utile : l'ennemi est la bande levée (`Scriptorium.bataille.bande(id)`), pas un attaquant noté |
| F21 | `BanditCampSiteAnchor` | 3 dossier(s) | `Scriptorium.missions.lieux_de(carte)` et `ajouter_un_lieu(nom, carte, position, cap)` |
| F22 | `BeginFollowVerify` | 3 dossier(s) | `Scriptorium.hommes.tenir(id, "escorte", quoi)` |
| F23 | `CUCount` | 3 dossier(s) | étape 5 (postes posés par JoVenGer ; l'enceinte : `Scriptorium.enceinte.niveau()`) |
| F24 | `CUStatus` | 3 dossier(s) | étape 5 (postes posés par JoVenGer ; l'enceinte : `Scriptorium.enceinte.est_batie()`) |
| F25 | `EnsureMercIsAlwaysRendered` | 3 dossier(s) | pas utile : le socle ne force pas l'affichage ; le gardien (`Scriptorium.hommes.garder()`) repêche |
| F26 | `Hire` | 3 dossier(s) | `Scriptorium.hommes.embaucher(contrat)` |
| F27 | `HireArcher` | 3 dossier(s) | `Scriptorium.hommes.embaucher(contrat)` (rôle `archer` ou `arbaletrier`) |
| F28 | `IsHeroName` | 3 dossier(s) | pas utile : Henry n'est jamais dans les listes du socle (`Scriptorium.hommes.liste()`) |
| F29 | `Recount` | 3 dossier(s) | `Scriptorium.hommes.effectif()` |
| F30 | `AlxWear` | 2 dossier(s) | `Scriptorium.jeu.faire_porter(personnage, objets)` |
| F31 | `BanditCampWith` | 2 dossier(s) | `Scriptorium.missions.dresser_un_camp(lieu, niveau)` (le plan : réglage `plan_des_camps`) |
| F32 | `CampEnsureSpot` | 2 dossier(s) | `Scriptorium.camp.reserver(nom, qui)` |
| F33 | `CampMercKeys` | 2 dossier(s) | `Scriptorium.hommes.fiche(id)` (`id`, `nom`, `personnage`) |
| F34 | `EndPlacement` | 2 dossier(s) | pas utile : pas de mode de pose dans le socle (la pose est à Scriptorium) |
| F35 | `GateCount` | 2 dossier(s) | `Scriptorium.enceinte.porte()` (une seule porte) |
| F36 | `IsArcherName` | 2 dossier(s) | `Scriptorium.hommes.fiche(id)` (champ `role`) |
| F37 | `IsCombatViable` | 2 dossier(s) | `Scriptorium.jeu.sante_de(qui)` |
| F38 | `LogiApplyBuffs` | 2 dossier(s) | étape 5 (postes de travail : l'alchimie) |
| F39 | `LogiSpend` | retirer de l'argent a Henry, en refusant sous le prix et jamais zero | `Scriptorium.jeu.retirer_groschen_a_henry(montant)` |
| F40 | `LogiWageTotal` | 2 dossier(s) | `Scriptorium.hommes.solde_de(id)` (sommée sur `Scriptorium.hommes.liste()`) |
| F41 | `MercDropClaim` | 2 dossier(s) | à ouvrir : `bataille.lua`, `lancer_l_attaque` (les cibles, `b.cibles`) |
| F42 | `RequestForceTalk` | 2 dossier(s) | pas utile : les voix viennent plus tard (NOTE §8, étape 6 du plan) |
| F43 | `UpkeepOn` | 2 dossier(s) | interrupteur `repas_du_socle` (l'entretien : repas du socle allumés ou coupés ; gages : interrupteur `solde_de_la_semaine`) |
| F44 | `WBRaidAlive` | vrai tant que la bande d'un raid a des vivants | `Scriptorium.bataille.bandes()` (les bandes non finies) |
| F45 | `WallSetType` | 2 dossier(s) | `Scriptorium.enceinte.batir()` (une seule sorte de palissade) |
| F46 | `AlxStripOverLayers` | 1 dossier(s) | pas utile : `Scriptorium.jeu.equiper_homme(personnage, ordre)` retire la tenue de naissance ; les tenues à cotte de dessus sont exclues |
| F47 | `BanditCampDressUp` | 1 dossier(s) | pas utile : les bandits naissent équipés par leur âme (fiche 13) |
| F48 | `BanditCampPlaceRow` | 1 dossier(s) | `Scriptorium.missions.dresser_un_camp(lieu, niveau)` (le plan : réglage `plan_des_camps`) |
| F49 | `BanditCampSiteByName` | 1 dossier(s) | `Scriptorium.missions.lieux_de(carte)` (par nom) |
| F50 | `BanditCampSlots` | 1 dossier(s) | `Scriptorium.missions.camps()` |
| F51 | `BountyAccept` | 1 dossier(s) | `Scriptorium.missions.prendre_une_mission({ lieu, hommes, chef, niveau })` |
| F52 | `BountyLevelOK` | 1 dossier(s) | `Scriptorium.missions.peut_partir(ordre)` (accroche) |
| F53 | `BountyPickSite` | 1 dossier(s) | `Scriptorium.missions.choisir_un_lieu(carte)` |
| F54 | `BountyReport` | 1 dossier(s) | `Scriptorium.missions.rapport_de_mission(r)` (accroche) et `missions.rapport(id)` |
| F55 | `BountyTierFor` | 1 dossier(s) | `Scriptorium.missions.niveau_pour(force, lieu)` (accroche) |
| F56 | `CampActiveStations` | 1 dossier(s) | étape 5 (postes de travail) |
| F57 | `CampAdmitToCamp` | 1 dossier(s) | étape 5 (faire entrer au camp un personnage déjà né) |
| F58 | `CampFormationDirty` | 1 dossier(s) | pas utile : l'ordre est redonné dès que l'activité change (`Scriptorium.hommes.tenir(id, regle, quoi)`) |
| F59 | `CampOnMercJoined` | 1 dossier(s) | pas utile : `Scriptorium.hommes.embaucher(contrat)` inscrit l'homme au camp d'un seul coup |
| F60 | `CampReturnAll` | 1 dossier(s) | `Scriptorium.hommes.lacher(id, regle)` (l'escorte, pour chacun) |
| F61 | `CampReturnMerc` | 1 dossier(s) | `Scriptorium.hommes.lacher(id, regle)` (l'escorte) |
| F62 | `CampRotateRole` | 1 dossier(s) | `Scriptorium.hommes.tenir(id, regle, quoi)` |
| F63 | `CampSetAnchorEnt` | 1 dossier(s) | `Scriptorium.camp.fonder(position, cap)` |
| F64 | `CampSetComposition` | 1 dossier(s) | pas utile : réglage de l'ancien panneau ; la composition vient des embauches (`Scriptorium.hommes.embaucher(contrat)`) |
| F65 | `CampTakeParty` | 1 dossier(s) | `Scriptorium.hommes.tenir(id, "escorte", quoi)` |
| F66 | `CampTeleportToCamp` | 1 dossier(s) | `Scriptorium.jeu.poser_en_secours(identifiant, position)` |
| F67 | `CampValidateSpot` | 1 dossier(s) | `Scriptorium.jeu.sol_de(position, pas)` |
| F68 | `ChangeMercWeapon` | 1 dossier(s) | pas utile : la famille d'armes est tirée à l'embauche (ou donnée par le contrat) et gardée à vie |
| F69 | `ClearAnyLeftoverCamp` | 1 dossier(s) | `Scriptorium.camp.lever()` |
| F70 | `ClearCampHouse` | 1 dossier(s) | pas utile : pas de cabane dans le socle |
| F71 | `DefSave` | 1 dossier(s) | `Scriptorium.registre.enregistrer()` |
| F72 | `DespawnQuartermaster` | 1 dossier(s) | `Scriptorium.directeur.congedier()` |
| F73 | `DifficultyCeil` | 1 dossier(s) | réglage : bataille.effectif_max |
| F74 | `DifficultyCount` | 1 dossier(s) | pas utile : la taille de la bande est l'effectif que Scriptorium donne à `Scriptorium.bataille.lever_une_bande(ordre)` |
| F75 | `DifficultySetByIndex` | 1 dossier(s) | pas utile : pas de niveau de difficulté dans le socle |
| F76 | `EncountersSet` | 1 dossier(s) | réglage : interrupteurs.rencontres_de_patrouille |
| F77 | `EquipEnemy` | 1 dossier(s) | pas utile : les bandits naissent équipés par leur âme (fiche 13) |
| F78 | `FollowStaggerSquad` | 1 dossier(s) | pas utile : l'escorte suit en formation du moteur (`Scriptorium.hommes.formations`) |
| F79 | `FollowStalledWuid` | 1 dossier(s) | `Scriptorium.hommes.rattraper(personnage, chef, nom)` |
| F80 | `GatePositions` | 1 dossier(s) | `Scriptorium.enceinte.point_d_entree()` |
| F81 | `GearOpenWardrobe` | 1 dossier(s) | pas utile : écran de l'ancien mod, que le socle n'a jamais eu |
| F82 | `GearRemoveCustom` | 1 dossier(s) | `Scriptorium.hommes.piece_otee(id, objet)` |
| F83 | `GiveMoney` | donner de l'argent a Henry | `Scriptorium.jeu.donner_groschen_a_henry(montant)` (crédit simple, sans toucher au coffre : Scriptorium a déjà débité la source, l'amende d'un duel ; relecture du pair) |
| F84 | `HireCustomCompanion` | 1 dossier(s) | étape 5 (compagnons nommés) |
| F85 | `HorsesSet` | 1 dossier(s) | pas utile : à cheval ou non se dit à chaque sortie (`Scriptorium.hommes.tenir(id, regle, quoi)`, « a_cheval ») |
| F86 | `InjectInteraction` | 1 dossier(s) | pas utile : les dialogues restent à Scriptorium (NOTE §5) |
| F87 | `IsMercInSortie` | 1 dossier(s) | `Scriptorium.hommes.qui_tient(id, heure)` |
| F88 | `IsNavGotoActive` | 1 dossier(s) | `Scriptorium.hommes.qui_tient(id, heure)` |
| F89 | `IsRecentAttacker` | 1 dossier(s) | pas utile : l'ennemi est la bande levée (`Scriptorium.bataille.bande(id)`), pas un attaquant noté |
| F90 | `LivePatrolSetEnabled` | 1 dossier(s) | pas utile : le socle n'envoie de patrouille que sur ordre (`Scriptorium.patrouilles.envoyer(ordre)`) |
| F91 | `LoadCampOrigin` | 1 dossier(s) | `Scriptorium.camp.point(x, y, cap)` (en 0, 0 : le centre et le cap) |
| F92 | `LoadCampOutParty` | 1 dossier(s) | pas utile : les tenues (l'escorte) sont au registre et relues à l'entrée (`Scriptorium.hommes.relancer()`) |
| F93 | `LodBoostPin` | 1 dossier(s) | pas utile : le socle ne force pas l'affichage |
| F94 | `LogiInfo` | 1 dossier(s) | `Scriptorium.bandeau.annoncer(cle, options)` |
| F95 | `LogiUpkeepDay` | 1 dossier(s) | `Scriptorium.hommes.jour_d_entretien(heure)` (le jour change à `hommes.heure_d_entretien`, 20 h) |
| F96 | `LogiWithdrawCoffer` | 1 dossier(s) | `Scriptorium.coffre.verser_a_henry(montant, motif)` |
| F97 | `LootSweepForce` | 1 dossier(s) | étape 4 (la fouille des corps, le butin) |
| F98 | `PruneCombatClaims` | 1 dossier(s) | à ouvrir : `bataille.lua`, `lancer_l_attaque` (les cibles, `b.cibles`) |
| F99 | `RegionSpawnMan` | 1 dossier(s) | `Scriptorium.jeu.faire_venir_homme(ame, nom, position)` |
| F100 | `SaveCampOutParty` | 1 dossier(s) | pas utile : les tenues sont gardées au registre à chaque changement |
| F101 | `SaveStrings` | 1 dossier(s) | `Scriptorium.registre.enregistrer()` |
| F102 | `SetEngageStance` | 1 dossier(s) | pas utile : le socle n'a pas d'attitude de combat ; chaque combattant reçoit l'ordre d'attaque |
| F103 | `SpawnMercAt` | 1 dossier(s) | `Scriptorium.jeu.faire_venir_homme(ame, nom, position)` |
| F104 | `SpawnPlayerCampTent` | 1 dossier(s) | `Scriptorium.camp.fonder(position, cap)` |
| F105 | `SpawnTowerStation` | 1 dossier(s) | `Scriptorium.enceinte.batir()` (les tours au niveau 2) |
| F106 | `StatusIconsSet` | 1 dossier(s) | pas utile : les icônes viennent plus tard (NOTE §8, étape 6 du plan) |
| F107 | `TowerCacheCampBlockers` | 1 dossier(s) | pas utile : `Scriptorium.jeu.sol_de(position, pas)` lit l'encombrement à la demande |
| F108 | `UpkeepSetByIndex` | 1 dossier(s) | réglage : hommes.ration (le taux des repas) et interrupteur `repas_du_socle` |
| F109 | `WBAttackersNearCamp` | 1 dossier(s) | `Scriptorium.bataille.bande(id)` (champ `ennemis`) |
| F110 | `WBRaid` | faire venir une bande d'ennemis qui attaque le camp (nombre, groupe, distance, angle) | `Scriptorium.bataille.lever_une_bande(ordre)` (sorte, effectif, direction, délai) |
| F111 | `WBSetPhase` | 1 dossier(s) | `Scriptorium.bataille.resoudre_par_la_regle(id)` |
| D1 | `ActiveMercs` | la liste des hommes engages : nom -> personnage du jeu | `Scriptorium.hommes.liste()` et `Scriptorium.hommes.fiche(id)` (champ `personnage`) |
| D2 | `CampActive` | vrai si un camp est dresse | `Scriptorium.camp.est_fonde()` |
| D3 | `CampActivities` | ce que fait chaque homme au camp en ce moment (poste, siege, lit...) | `Scriptorium.hommes.qui_tient(id, heure)` |
| D4 | `CampCenter` | la position du centre du camp | `Scriptorium.camp.point(x, y, cap)` (en 0, 0) |
| D5 | `LootActivities` | les hommes partis fouiller des corps, et ce qu'ils font | étape 4 (la fouille des corps, le butin) |
| D6 | `CampFurniture` | les meubles poses au camp | `Scriptorium.camp.plan` et `Scriptorium.camp.objet_de(nom)` |
| D7 | `CampPatrollers` | les hommes de la ronde de garde | `Scriptorium.hommes.gardes(heure)` |
| D8 | `CampBuildOrigin` | le point d'origine et le sens du camp (la ou il a ete fonde) | `Scriptorium.camp.point(x, y, cap)` (en 0, 0 : l'origine et le cap) |
| D9 | `CampSeats` | les sieges du camp (ou les hommes s'assoient) | `Scriptorium.camp.places_libres(sorte, pour)` (« siege ») |
| D10 | `BanditCampActors` | les personnages d'un camp de bandits (missions) | `Scriptorium.missions.personnages_du_camp(id)`, `ajouter_un_personnage`, `retirer_un_personnage` |
| D11 | `CampNextRotate` | le prochain changement d'activite des hommes | `Scriptorium.hommes.tenir(id, regle, quoi)` (champ `fin`) |
| D12 | `CampBeds` | les lits du camp | `Scriptorium.camp.places_libres(sorte, pour)` (« lit ») |
| D13 | `CampMercSpots` | les places des hommes au camp | `Scriptorium.camp.occupant_de(nom)` |
| D14 | `CampForwardAngle` | le sens du camp (l'angle de face) | `Scriptorium.camp.point(x, y, cap)` (le cap rendu) |
| D15 | `CampTicks` | le battement du camp (son compteur) | `Scriptorium.jeu.heure_du_jeu()` |
| D16 | `ForcedTargetOf` | Scriptorium l'écrit aussi | à ouvrir : `bataille.lua`, `lancer_l_attaque` (les cibles, `b.cibles`) |
| D17 | `FeedRatio` | 7 dossier(s) | réglage : hommes.ration |
| D18 | `QuartermasterId` | le personnage de l'intendant (le Directeur de Scriptorium) | `Scriptorium.directeur.personnage()` |
| D19 | `CampEntities` | Scriptorium l'écrit aussi | `Scriptorium.camp.objet_de(nom)` |
| D20 | `MercTargetOf` | 6 dossier(s) | à ouvrir : `bataille.lua`, `lancer_l_attaque` (les cibles, `b.cibles`) |
| D21 | `CampModels` | 5 dossier(s) | `Scriptorium.camp.modeles` |
| D22 | `CampOutParty` | Scriptorium l'écrit aussi | `Scriptorium.hommes.qui_tient(id, heure)` (règle `escorte`) |
| D23 | `CampStationTiles` | 5 dossier(s) | étape 5 (postes de travail) |
| D24 | `CustomCompanionsData` | 5 dossier(s) | étape 5 (compagnons nommés) |
| D25 | `EnemyAlerted` | Scriptorium l'écrit aussi | `Scriptorium.bataille.bande(id)` (champs `annoncee`, `etat`) |
| D26 | `ArcherAmmoClass` | 4 dossier(s) | `Scriptorium.jeu.munition_de(nom)` |
| D27 | `CampStowed` | Scriptorium l'écrit aussi | pas utile : pas de réserve d'objets rangés |
| D28 | `TowerStations` | 4 dossier(s) | `Scriptorium.enceinte.objet_de(nom)` (les tours) |
| D29 | `ArcherArrowClasses` | 3 dossier(s) | `Scriptorium.jeu.munition_de(nom)` |
| D30 | `ArcherBoltClasses` | 3 dossier(s) | `Scriptorium.jeu.munition_de(nom)` |
| D31 | `ArcherWeaponOf` | Scriptorium l'écrit aussi | `Scriptorium.hommes.fiche(id)` (champ `role`) |
| D32 | `BanditCampChestShare` | 3 dossier(s) | `Scriptorium.bataille.partager_le_butin(butin, combattants)` (accroche) ; la part du coffre dans `bataille.resultats()` |
| D33 | `BanditCampColumn` | Scriptorium l'écrit aussi | `Scriptorium.missions.mission(id).hommes` |
| D34 | `CachedEnemies` | Scriptorium l'écrit aussi | `Scriptorium.bataille.bande(id)` (champ `personnages`) |
| D35 | `CampBedSO` | 3 dossier(s) | `Scriptorium.camp.objets_du_jeu` (« lit ») |
| D36 | `CampChairSO` | 3 dossier(s) | `Scriptorium.camp.objets_du_jeu` (« siege ») |
| D37 | `CampForgeSmithWuid` | 3 dossier(s) | étape 5 (la forge et son forgeron) |
| D38 | `CampPracticeYard` | 3 dossier(s) | étape 5 (poste d'entraînement) |
| D39 | `CampRoster` | 3 dossier(s) | `Scriptorium.hommes.liste()` |
| D40 | `CampSitSOOffset` | 3 dossier(s) | réglage : meubles.siege.places.assise.x (et .y) |
| D41 | `CampTrainCenter` | 3 dossier(s) | `Scriptorium.hommes.points` (« exercice ») |
| D42 | `KleinkriegPerHead` | 3 dossier(s) | réglage : bandes.brigands.butin_par_tete (une valeur par sorte) |
| D43 | `LootBattle` | 3 dossier(s) | étape 4 (la fouille des corps, le butin) |
| D44 | `MeleeStyleOf` | Scriptorium l'écrit aussi | `Scriptorium.hommes.fiche(id)` (champ `famille`) |
| D45 | `QuartermasterName` | Scriptorium l'écrit aussi | `Scriptorium.directeur.nom` |
| D46 | `WBRaidForce` | 3 dossier(s) | `Scriptorium.bataille.force_de_la_bande(b)` |
| D47 | `WagePerTier` | Scriptorium l'écrit aussi | réglage : soldes.homme_d_armes.solde (une valeur par rôle ; et rangs.*) |
| D48 | `ActivePlacement` | 2 dossier(s) | pas utile : pas de mode de pose dans le socle |
| D49 | `AlxKnightHarness` | 2 dossier(s) | étape 5 (tenues selon le grade) |
| D50 | `AlxSilver` | 2 dossier(s) | pas utile : donnée interne de l'ancien mod ; l'argent passe par `Scriptorium.jeu.donner_groschen_a_henry(montant)` |
| D51 | `BCQ_BO` | 2 dossier(s) | pas utile : état interne de l'ancien mod (le dernier lieu par carte) ; Scriptorium garde le sien |
| D52 | `BanditCampMoneyItem` | 2 dossier(s) | pas utile : le coffre d'un camp de bandits est une somme (fiche 17) |
| D53 | `CampClusterSize` | 2 dossier(s) | pas utile : géométrie de l'ancien camp ; le plan du socle est la table `Scriptorium.camp.plan` |
| D54 | `CampClusterSpacing` | Scriptorium l'écrit aussi | pas utile : géométrie de l'ancien camp ; le plan du socle est la table `Scriptorium.camp.plan` |
| D55 | `CampFoodCart` | 2 dossier(s) | étape 5 (la charrette de vivres) |
| D56 | `CampHouseCenter` | 2 dossier(s) | pas utile : pas de cabane dans le socle |
| D57 | `CampSitFacingFixDeg` | 2 dossier(s) | réglage : meubles.siege.places.assise.cap |
| D58 | `EnemyAlertRadius` | Scriptorium l'écrit aussi | pas utile : le socle prévient par l'heure d'arrivée de la bande (`bataille.avertissement`), pas par un rayon |
| D59 | `EnemyTargetOf` | 2 dossier(s) | à ouvrir : `bataille.lua`, `lancer_l_attaque_de_la_bande` (`b.cibles_de_la_bande`) |
| D60 | `FrameHooks` | Scriptorium l'écrit aussi | `Scriptorium.jeu.minuterie(millisecondes, fonction)` |
| D61 | `GateMax` | 2 dossier(s) | pas utile : une seule porte (`Scriptorium.enceinte.porte()`) |
| D62 | `LootBodies` | 2 dossier(s) | étape 4 (la fouille des corps, le butin) |
| D63 | `LootPerKillWages` | 2 dossier(s) | étape 4 (la fouille des corps, le butin) |
| D64 | `LootVisited` | Scriptorium l'écrit aussi | étape 4 (la fouille des corps, le butin) |
| D65 | `MaxCompanions` | 2 dossier(s) | `Scriptorium.camp.capacite()` (pas de plafond chiffré : un lit par homme) |
| D66 | `MercClaimAt` | Scriptorium l'écrit aussi | à ouvrir : `bataille.lua`, `lancer_l_attaque` (les cibles, `b.cibles`) |
| D67 | `QuartermasterClothing` | 2 dossier(s) | étape 5 (tenue du Directeur) |
| D68 | `QuartermasterPost` | Scriptorium l'écrit aussi | `Scriptorium.directeur.activite(heure)` (lieu et position) |
| D69 | `QuartermasterWeapon` | 2 dossier(s) | étape 5 (armes du Directeur) |
| D70 | `SaverValues` | 2 dossier(s) | `Scriptorium.registre.dernier_rapport()` |
| D71 | `UpdateOnAction` | 2 dossier(s) | pas utile : rafraîchissement de l'ancien panneau |
| D72 | `WBPhase` | 2 dossier(s) | `Scriptorium.bataille.bande(id)` (champ `etat`) |
| D73 | `WallBuildActive` | 2 dossier(s) | pas utile : pas de chantier en cours ; `Scriptorium.enceinte.batir()` bâtit d'un coup |
| D74 | `WallTypePalisade` | 2 dossier(s) | pas utile : une seule sorte de palissade |
| D75 | `ArcherPrice` | 1 dossier(s) | `Scriptorium.hommes.embaucher(contrat)` (champ `prime`) |
| D76 | `BCQ` | 1 dossier(s) | pas utile : état interne de l'ancien mod (le dernier lieu par carte) ; Scriptorium garde le sien |
| D77 | `BCQ_KK` | 1 dossier(s) | pas utile : état interne de l'ancien mod (le dernier lieu par carte) ; Scriptorium garde le sien |
| D78 | `BanditCampChestLoot` | 1 dossier(s) | réglage : niveaux_des_camps.<niveau>.coffre |
| D79 | `BanditCampForgetRange` | 1 dossier(s) | réglage : bataille.poste_vue_m (et missions.henry_loin_m) |
| D80 | `BanditCampLayouts` | 1 dossier(s) | réglage : plan_des_camps |
| D81 | `BanditCampSites` | 1 dossier(s) | `Scriptorium.missions.lieux_de(carte)` |
| D82 | `CCReinject` | 1 dossier(s) | étape 5 (compagnons nommés) |
| D83 | `CUHide` | Scriptorium l'écrit aussi | pas utile : écran de l'ancien mod, que le socle n'a jamais eu |
| D84 | `CUShow` | Scriptorium l'écrit aussi | pas utile : écran de l'ancien mod, que le socle n'a jamais eu |
| D85 | `CampAlchemy` | 1 dossier(s) | étape 5 (l'alchimie) |
| D86 | `CampArcherCart` | 1 dossier(s) | étape 5 (la charrette des archers) |
| D87 | `CampAtlas` | 1 dossier(s) | pas utile : géométrie de l'ancien camp ; le plan du socle est la table `Scriptorium.camp.plan` |
| D88 | `CampBuildMap` | Scriptorium l'écrit aussi | pas utile : géométrie de l'ancien camp ; le plan du socle est la table `Scriptorium.camp.plan` |
| D89 | `CampBusyUntil` | 1 dossier(s) | `Scriptorium.hommes.tenir(id, regle, quoi)` (champ `fin`) |
| D90 | `CampClusterTentRingSlots` | 1 dossier(s) | pas utile : géométrie de l'ancien camp ; le plan du socle est la table `Scriptorium.camp.plan` |
| D91 | `CampFireSeatRadius` | 1 dossier(s) | pas utile : géométrie de l'ancien camp ; le plan du socle est la table `Scriptorium.camp.plan` |
| D92 | `CampFoodCartLayout` | 1 dossier(s) | étape 5 (la charrette de vivres) |
| D93 | `CampForge` | 1 dossier(s) | étape 5 (la forge) |
| D94 | `CampGridOffsets` | Scriptorium l'écrit aussi | pas utile : géométrie de l'ancien camp ; le plan du socle est la table `Scriptorium.camp.plan` |
| D95 | `CampHunt` | 1 dossier(s) | étape 5 (la chasse) |
| D96 | `CampInn` | 1 dossier(s) | étape 5 (la taverne) |
| D97 | `CampJoinRadius` | Scriptorium l'écrit aussi | pas utile : pas de rayon d'entrée au camp ; l'homme est au camp dès `Scriptorium.hommes.embaucher(contrat)` |
| D98 | `CampLoadStationTiles` | Scriptorium l'écrit aussi | étape 5 (postes de travail) |
| D99 | `CampMaxCampingTiles` | Scriptorium l'écrit aussi | pas utile : la taille du camp est son niveau (`Scriptorium.camp.niveau()`, au plus `camp.niveau_maximal`) |
| D100 | `CampMaxConcurrentChats` | 1 dossier(s) | pas utile : les voix viennent plus tard (NOTE §8, étape 6 du plan) |
| D101 | `CampMaxTents` | Scriptorium l'écrit aussi | pas utile : les tentes viennent de `Scriptorium.camp.plan`, par niveau |
| D102 | `CampNightSleepChance` | Scriptorium l'écrit aussi | pas utile : la nuit, tous dorment sauf les gardes (tranche du sommeil, `Scriptorium.hommes.journee`) |
| D103 | `CampNightTorchTick` | Scriptorium l'écrit aussi | pas utile : pas de torches de nuit dans le socle |
| D104 | `CampNightWatchTick` | Scriptorium l'écrit aussi | `Scriptorium.hommes.gardes(heure)` |
| D105 | `CampNudgeMax` | Scriptorium l'écrit aussi | pas utile : géométrie de l'ancien camp ; le plan du socle est la table `Scriptorium.camp.plan` |
| D106 | `CampNudgeStep` | 1 dossier(s) | pas utile : géométrie de l'ancien camp ; le plan du socle est la table `Scriptorium.camp.plan` |
| D107 | `CampNudgeToValid` | Scriptorium l'écrit aussi | pas utile : le camp pose son plan tel quel, au sol (`Scriptorium.jeu.au_sol(position)`) |
| D108 | `CampRoleSeconds` | 1 dossier(s) | `Scriptorium.hommes.qui_tient(id, heure)` (champ `fin`) |
| D109 | `CampTentFootHalf` | Scriptorium l'écrit aussi | pas utile : géométrie de l'ancien camp ; le plan du socle est la table `Scriptorium.camp.plan` |
| D110 | `CampTentRingRadius` | Scriptorium l'écrit aussi | pas utile : géométrie de l'ancien camp ; le plan du socle est la table `Scriptorium.camp.plan` |
| D111 | `CampTentVariants` | Scriptorium l'écrit aussi | `Scriptorium.camp.modeles` (« tente ») |
| D112 | `CampTileHalf` | Scriptorium l'écrit aussi | pas utile : géométrie de l'ancien camp ; le plan du socle est la table `Scriptorium.camp.plan` |
| D113 | `CustomOutfitIndex` | 1 dossier(s) | étape 5 (tenues) |
| D114 | `DefRestorePending` | 1 dossier(s) | pas utile : l'enceinte est reposée d'un coup à l'entrée (`Scriptorium.enceinte.relancer()`) |
| D115 | `DefRestoring` | 1 dossier(s) | pas utile : l'enceinte est reposée d'un coup à l'entrée (`Scriptorium.enceinte.relancer()`) |
| D116 | `EnemyAlertRadiusDefault` | 1 dossier(s) | pas utile : le socle prévient par l'heure d'arrivée de la bande, pas par un rayon |
| D117 | `EnemyClaimWuid` | 1 dossier(s) | à ouvrir : `bataille.lua`, `lancer_l_attaque_de_la_bande` (`b.cibles_de_la_bande`) |
| D118 | `EnemyScanRadius` | 1 dossier(s) | pas utile : le socle prévient par l'heure d'arrivée de la bande, pas par un rayon |
| D119 | `EscortEnt` | 1 dossier(s) | `Scriptorium.hommes.qui_tient(id, heure)` (règle `escorte`) |
| D120 | `HealCost` | 1 dossier(s) | pas utile : le prix du soin est une règle de Scriptorium ; le geste : `Scriptorium.atelier.soigner(id, nom_du_soin)` |
| D121 | `HoldActive` | 1 dossier(s) | `Scriptorium.hommes.qui_tient(id, heure)` |
| D122 | `InnStationLayout` | 1 dossier(s) | étape 5 (la taverne) |
| D123 | `IsLootableCorpseName` | Scriptorium l'écrit aussi | étape 4 (la fouille des corps, le butin) |
| D124 | `LivePatrolsEnabled` | 1 dossier(s) | pas utile : le socle n'envoie de patrouille que sur ordre (`Scriptorium.patrouilles.envoyer(ordre)`) |
| D125 | `LogiTrackCombat` | Scriptorium l'écrit aussi | `Scriptorium.bataille.partager_le_butin(butin, combattants)` (accroche) ; l'issue : `bataille.issue_au_loin` (accroche) |
| D126 | `LootAdvance` | Scriptorium l'écrit aussi | étape 4 (la fouille des corps, le butin) |
| D127 | `LootAssign` | Scriptorium l'écrit aussi | étape 4 (la fouille des corps, le butin) |
| D128 | `LootClaims` | 1 dossier(s) | étape 4 (la fouille des corps, le butin) |
| D129 | `LootCorpseRadius` | Scriptorium l'écrit aussi | étape 4 (la fouille des corps, le butin) |
| D130 | `LootMaxSweepers` | Scriptorium l'écrit aussi | étape 4 (la fouille des corps, le butin) |
| D131 | `LootMercRange` | Scriptorium l'écrit aussi | étape 4 (la fouille des corps, le butin) |
| D132 | `LootPlayerRadius` | Scriptorium l'écrit aussi | étape 4 (la fouille des corps, le butin) |
| D133 | `LootWalkRange` | Scriptorium l'écrit aussi | étape 4 (la fouille des corps, le butin) |
| D134 | `LootWalkTimeout` | Scriptorium l'écrit aussi | étape 4 (la fouille des corps, le butin) |
| D135 | `LootWindow` | Scriptorium l'écrit aussi | étape 4 (la fouille des corps, le butin) |
| D136 | `MoralePerKill` | 1 dossier(s) | réglage : issues.victoire.moral (une valeur par issue) |
| D137 | `NavTentFootHalf` | Scriptorium l'écrit aussi | pas utile : géométrie de l'ancien camp ; le plan du socle est la table `Scriptorium.camp.plan` |
| D138 | `OurWuids` | 1 dossier(s) | `Scriptorium.hommes.liste()` et `Scriptorium.hommes.fiche(id)` (champ `personnage`) |
| D139 | `Outfits` | 1 dossier(s) | `Scriptorium.hommes.equipement` (« tenue », par palier) |
| D140 | `PatrolRouteData` | 1 dossier(s) | `Scriptorium.hommes.tenir(id, "ronde", quoi)` (le `chemin` donné par Scriptorium) |
| D141 | `PruneMercCache` | Scriptorium l'écrit aussi | `Scriptorium.hommes.retirer(id, cause)` |
| D142 | `RaidEnabled` | Scriptorium l'écrit aussi | pas utile : le socle ne lève aucune bande de lui-même |
| D143 | `RandomMeleeSetMax` | 1 dossier(s) | pas utile : la famille est tirée parmi `Scriptorium.hommes.equipement` (familles) ou donnée par le contrat |
| D144 | `RandomMeleeSetMin` | 1 dossier(s) | pas utile : la famille est tirée parmi `Scriptorium.hommes.equipement` (familles) ou donnée par le contrat |
| D145 | `SaverIds` | 1 dossier(s) | `Scriptorium.registre.lire(nom)` |
| D146 | `ScriptoriumEnPause` | Scriptorium l'écrit aussi | `Scriptorium.en_partie` (le registre est relu à chaque entrée en partie) |
| D147 | `ShieldWeaponTypes` | 1 dossier(s) | `Scriptorium.hommes.equipement` (familles à bouclier) |
| D148 | `SkalitzOutfitIndex` | 1 dossier(s) | pas utile : donnée interne de l'ancien mod |
| D149 | `SkalitzShieldPresets` | 1 dossier(s) | pas utile : donnée interne de l'ancien mod |
| D150 | `SpawnCampProp` | Scriptorium l'écrit aussi | pas utile : le socle ne pose pas de paillasse en plus du lit |
| D151 | `SpawnCampPropModel` | Scriptorium l'écrit aussi | `Scriptorium.camp.modeles` |
| D152 | `StaticArchers` | 1 dossier(s) | `Scriptorium.hommes.gardes(heure)` |
| D153 | `SwarmCap` | Scriptorium l'écrit aussi | à ouvrir : `bataille.lua`, `lancer_l_attaque` (le tourniquet des cibles) |
| D154 | `SwarmCapHard` | Scriptorium l'écrit aussi | à ouvrir : `bataille.lua`, `lancer_l_attaque` (le tourniquet des cibles) |
| D155 | `SwarmCapMax` | Scriptorium l'écrit aussi | à ouvrir : `bataille.lua`, `lancer_l_attaque` (le tourniquet des cibles) |
| D156 | `UpdateEnemyCache` | Scriptorium l'écrit aussi | à ouvrir : `bataille.lua`, `lancer_l_attaque` (la liste des ennemis vivants) |
| D157 | `WBDefenders` | Scriptorium l'écrit aussi | `Scriptorium.bataille.combattants()` |
| D158 | `WBRaidStaged` | 1 dossier(s) | `Scriptorium.bataille.bande(id)` (champ `etat`) |
| D159 | `WeaponSets` | 1 dossier(s) | `Scriptorium.hommes.equipement` (familles) |
| R1 | `28/09 — plus de touches U et H, ni de leurs aides à l'écran` |  | pas utile : écran de l'ancien mod, que le socle n'a jamais eu (ni ces touches) |
| R2 | `28/09 (suite) — les écrans U et H supprimés pour de bon` |  | pas utile : écran de l'ancien mod, que le socle n'a jamais eu |
| R3 | `Supprimés` |  | pas utile : aucun de ces fichiers dans le socle |
| R4 | `28/09 — plafond d’embauche : 50 → 80` |  | étape 5 (le plafond de 80 ; aujourd'hui un lit par homme, `Scriptorium.camp.capacite()`) |
| R5 | `28/09 — les raids n'apparaissent plus dans le camp` |  | réglage : bataille.distance_arrivee (déjà fait : la bande naît à 60 m du centre, hors du camp) |
| R6 | `28/09 — « Parle-moi un peu de toi » en tête du dialogue de chaque mercenaire` |  | pas utile : les dialogues restent à Scriptorium (NOTE §5) |
| R7 | `28/09 — l'arme de tir homme par homme (les arbalétriers)` |  | déjà fait : `Scriptorium.hommes.fiche(id)` (rôle `archer` ou `arbaletrier` par homme, `hommes.equipement.tir`) |
| R8 | `28/09 — le style de mêlée homme par homme (les styles à l'embauche)` |  | déjà fait : `Scriptorium.hommes.embaucher(contrat)` (famille tirée ou donnée, gardée à vie) |
| R9 | `28/09 — le pas de côté des tireurs (la fenêtre de tir)` |  | pas utile : le tir est mené par le cerveau du jeu sur nos âmes ; à revoir si l'essai en jeu montre des tirs dans l'obstacle |
| R10 | `1er/10 — les pillards des raids parlent (provocations et vengeance)` |  | pas utile : les voix viennent plus tard (NOTE §8, étape 6 du plan) |
| R11 | `1er/10 — l'alerte rompt les poses sans quitter la routine du camp` |  | déjà fait : `Scriptorium.hommes.tenir(id, "bataille", quoi)` (priorité 1), la routine reprend au `Scriptorium.hommes.lacher(id, regle)` |
| R12 | `1er/10 — le stratège des bandits choisit son angle ; leurs archers au dernier rang` |  | en partie : `Scriptorium.bataille.lever_une_bande(ordre)` (direction) ; les archers ennemis au dernier rang : non |
| R13 | `2/10 : le dialogue d'un mercenaire rangé en catégories (choses/dialogue_des_mercenaires)` |  | pas utile : les dialogues restent à Scriptorium (NOTE §5) |
| R14 | `2/10 (soir) : les choix du dialogue d'un homme passent par les anciens jetons des renforts` |  | pas utile : les dialogues restent à Scriptorium (NOTE §5) |
| R15 | `2/10 (nuit) : les réponses d'un mercenaire restent dans le dialogue du jeu` |  | pas utile : les dialogues restent à Scriptorium (NOTE §5) |
| R16 | `3/10 : les cris de marché du jeu (par métarôle)` |  | étape 5 (l'étal du marchand et ses cris) |
| R17 | `5/10 — plus de rhabillage au hasard à chaque chargement` |  | déjà fait : `Scriptorium.hommes.relancer()` (chaque homme remet ses propres pièces, rien n'est retiré au hasard) |
| R18 | `6/10 — la nuit, les dormeurs ne sont plus relancés toutes les 8 s` |  | déjà fait : `Scriptorium.hommes.garder()` (ne relance qu'un homme figé loin de son but ; l'ordre n'est redonné qu'au changement d'activité) |
| R19 | `6/10 — le titre « Mercenaire » pour tous, le grade sous le nom` |  | étape 5 (le grade affiché ; chaque homme a déjà son nom, `Scriptorium.hommes.nom_d_epoque(i)`) |
| R20 | `7/10 — le colonel garde sa tenue d'officier` |  | étape 5 (tenue d'officier ; le capitaine du socle est éteint, interrupteur `rangs_du_socle`) |
| R21 | `8/10 — des ordres au colonel, en lui parlant` |  | pas utile : les dialogues restent à Scriptorium (NOTE §5) |
| R22 | `8/10 — la réserve du camp vide s'enregistre enfin` |  | déjà fait : `Scriptorium.registre.enregistrer()` (tout le registre d'un coup, jamais une chaîne vide) |
| R23 | `8/10 au soir — les longues valeurs enregistrées en morceaux (la partie qui ne se rechargeait plus)` |  | déjà fait : `Scriptorium.jeu.ecrire_registre(chaine)` (tranches de 30 000 octets, plafond 65 535) |
| R24 | `8/10 au soir — rien de Scriptorium ne s'écrit quand il est en pause` |  | déjà fait : `Scriptorium.entrer_en_partie()` (le registre est invalidé et relu ; il porte l'identité de sa partie) |
| R25 | `10/10 — retirer zéro gros vidait la bourse d'Henry` |  | déjà fait : `Scriptorium.jeu.retirer_groschen_a_henry(montant)` (refuse 0, négatif, non entier, au-delà de la bourse) |
| R26 | `11/10 — un tireur en séance garde son arc et sa cible` |  | étape 5 (poste de tir à la cible) |
| R27 | `12/10 — le camp sans personne se monte enfin (le bivouac de la patente)` |  | déjà fait : `Scriptorium.camp.fonder(position, cap)` (aucun homme exigé) |

## Bilan

| valeur | lignes | accroches | fonctions | données | retouches |
|---|---|---|---|---|---|
| service existant | 163 | 23 | 69 | 60 | 11 |
| à ouvrir | 20 | 9 | 2 | 9 | 0 |
| étape 4 | 19 | 2 | 1 | 16 | 0 |
| étape 5 | 31 | 2 | 6 | 18 | 5 |
| pas utile | 89 | 3 | 29 | 47 | 10 |
| réglage | 15 | 1 | 4 | 9 | 1 |
| **total** | 337 | 40 | 111 | 159 | 27 |

« Service existant » compte aussi les retouches que le socle fait déjà (« déjà fait », « en partie »).

Les « à ouvrir » (décision du socle en fonction locale, à rendre enveloppable) :

- A2 : `bataille.lua`, `lancer_l_attaque` (et `lancer_l_attaque_de_la_bande`)
- A5 : `hommes.lua`, `equiper` (les munitions de `hommes.equipement.tir`)
- A7 : `hommes.lua`, `tenue_la_plus_forte` (l'arbitre des priorités)
- A13 : `bataille.lua`, `a_relancer` (le suivi au contact)
- A22 : `hommes.lua`, `choisir_l_equipement`
- A23 : `hommes.lua`, `choisir_l_equipement`
- A29 : `bataille.lua`, `lancer_l_attaque` (la liste des ennemis vivants)
- A38 : `bataille.lua`, `lancer_l_attaque` (les cibles, `b.cibles`)
- A40 : `bataille.lua`, `finir` (la fin de bataille)
- F41 : `bataille.lua`, `lancer_l_attaque` (les cibles, `b.cibles`)
- F98 : `bataille.lua`, `lancer_l_attaque` (les cibles, `b.cibles`)
- D16 : `bataille.lua`, `lancer_l_attaque` (les cibles, `b.cibles`)
- D20 : `bataille.lua`, `lancer_l_attaque` (les cibles, `b.cibles`)
- D59 : `bataille.lua`, `lancer_l_attaque_de_la_bande` (`b.cibles_de_la_bande`)
- D66 : `bataille.lua`, `lancer_l_attaque` (les cibles, `b.cibles`)
- D117 : `bataille.lua`, `lancer_l_attaque_de_la_bande` (`b.cibles_de_la_bande`)
- D153 : `bataille.lua`, `lancer_l_attaque` (le tourniquet des cibles)
- D154 : `bataille.lua`, `lancer_l_attaque` (le tourniquet des cibles)
- D155 : `bataille.lua`, `lancer_l_attaque` (le tourniquet des cibles)
- D156 : `bataille.lua`, `lancer_l_attaque` (la liste des ennemis vivants)
