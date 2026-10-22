# Fiche 09 — La discipline et la justice du camp

- Morceau : 9. Table : `Scriptorium.discipline`. Fichier : `socle/pak/Scripts/scriptorium/discipline.lua`.
- Vient de la décision D7 (nouveautés d'époque) : « vol ou violence chez les paysans : amende retenue sur la solde, puis renvoi ; la réputation de la Compagnie auprès des villages s'en ressent ».
- État : écrit et passé au banc. Validée par JoVenGer le 14/10/2026 : chances de faute, quatre fautes, cinq peines, laxisme et réputation tels quels. À voir en jeu à l'aube, dans la Partie 1 (le temps y tourne).
- Avec la fiche 11 (caractère, 15/10) : la chance de faute est multipliée par 1,5 − jugement ⁄ 100 ; la sorte de faute suit les penchants du coupable (un homme sans penchant n'en commet aucune) ; la première faute révèle le penchant ; la victime d'une rixe perd un point de forme.

## Ce que le joueur voit
- Des fautes au camp, de temps en temps, surtout quand le moral est bas : « Rixe au camp : Jan Kladivo », « Un vol au coffre : … », « Ivresse au camp : … », « Exaction chez les paysans : … ».
- Le Directeur présente les fautes à juger dans la Gestion du camp (« Rendre justice au camp ») : pardon, amende, corvée, pilori, renvoi. « Jugement rendu au camp : … »
- Une faute laissée sans jugement deux jours : « Une faute est restée impunie : les hommes murmurent. »
- La réputation de la Compagnie auprès des villages change le prix des réserves.

## Règles
- **Les fautes.** Chaque jour à l'aube, chaque homme a une chance de faute : 3 % de base, 6 % s'il est morose, 10 % s'il est abattu. Sortes, par poids : rixe (4), vol (2,5), ivresse (2), exaction (1,5). Le hasard est celui de la bataille (graine au registre).
  - **Rixe** : avec le camarade suivant sur la liste ; les deux perdent 5 de moral, l'autre est blessé un jour. Il faut deux hommes.
  - **Vol** : de 5 à 20 groschen pris au coffre (ligne « vol » au livre), pas plus que le coffre n'en a.
  - **Ivresse** : deux bières prises à la réserve s'il y en a ; l'homme est hors d'état un jour (soigné comme une blessure), moral − 2.
  - **Exaction** chez les paysans : réputation − 5, alerte au joueur.
- **Juger** (`juger(incident, peine)`), par la Gestion du camp :
  - `pardon` : les autres hommes perdent 2 de moral (laxisme) ;
  - `amende` : la moitié de sa prochaine solde est retenue (`hommes.retenir`), moral − 5 ;
  - `corvee` : vingt-quatre heures de corvée (affectation qui passe devant sa journée), moral − 3 ;
  - `pilori` : un jour hors d'état, moral − 10 ;
  - `renvoi` : renvoyé de la Compagnie.
  - Une exaction jugée autrement que par le pardon rend 2 de réputation (justice rendue).
- **Laxisme.** Une faute non jugée après deux jours est prescrite : tous les hommes perdent 2 de moral ; si c'était une exaction, réputation − 1 de plus.
- **Réputation** auprès des villages : de 0 à 100, 50 au départ. Le coût d'un achat de réserves est prix de base × quantité × (1,5 − réputation ⁄ 100), arrondi sur le total : à 50, le prix de base ; à 0, une fois et demie ; à 100, la moitié (`directeur.cout_de`, `directeur.prix_de` pour l'unité).
- **Enregistrement** à chaque faute, jugement ou prescription.

## Sorts rendus
`juger` : `incident_inconnu`, `deja_juge`, `peine_inconnue`, `homme_parti` (le coupable n'est plus là : la faute est classée).

## Ce qui est sauvegardé (case `discipline`, version 1)
`{ prochain = 1, a_juger = {…}, juges = {…}, reputation = 50, derniere_aube }`. Vingt fautes gardées de chaque côté.

## Ce que le morceau demande au jeu (liaison)
Rien de nouveau : `heure_du_jeu`, `journal`.

## Essais au banc (`essais/lua/essai_discipline.lua`)
Pas de faute sans homme ; chaque sorte de faute et ses effets ; chaque peine ; refus ; amende retenue à la paie ; corvée levée après vingt-quatre heures ; laxisme ; réputation et prix ; entrée de la Gestion ; relecture.
