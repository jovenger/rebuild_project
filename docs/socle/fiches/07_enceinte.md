# Fiche 07 — L'enceinte, la porte, l'atelier (alchimie et armurerie)

- Morceau : 7. Tables : `Scriptorium.enceinte`, `Scriptorium.atelier`. Fichiers : `socle/pak/Scripts/scriptorium/enceinte.lua`, `atelier.lua`.
- État : écrit et passé au banc. En attente de l'essai en jeu (modèles de palissade et de porte, objets posés) et de la validation de la fiche par JoVenGer.

## Ce que le joueur voit
- **L'enceinte :** une palissade de pieux autour du camp, à quinze mètres, avec une porte de bois ; au niveau 2, deux tours de guet. Bâtie par la Gestion du camp, contre du bois et du travail.
- **La porte :** ouverte le jour, fermée la nuit, barrée dès qu'une bande est annoncée. « La porte du camp est fermée pour la nuit. », « La porte est barrée : une bande approche. »
- **L'atelier,** dans la Gestion du camp : l'alchimie (des herbes en remèdes) et l'armurerie (l'entretien des armes par l'armurier).

## Règles de l'enceinte
- **Plan en données** (`enceinte.plan`) : seize pans de palissade sur un cercle de quinze mètres, une porte au nord (face à la direction 0 du camp), deux tours au niveau 2 (nord-est et nord-ouest). Modèles du jeu de base appelés par leur chemin (`enceinte.modeles`, à confirmer).
- **Bâtir** (`batir()`) : il faut le camp fondé, 80 bois au coffre pour le niveau 1, 40 de plus pour les tours ; le bois est pris, les objets sont posés, comme pour le camp. `redresser()` repose ce qui manque. Levée avec le camp (`demolir()`).
- **Bonus de défense** (`bonus()`) : × 1,3 avec la palissade, × 1,4 avec les tours ; lu par la bataille.
- **Avance de guet** (`avance_de_guet()`) : une heure de plus d'avertissement avec les tours ; lu par la bataille.
- **Point d'entrée** (`point_d_entree()`) : la porte ; la bande marche dessus.
- **La porte :** états `ouverte`, `fermee`, `barree`. `ouvrir()`, `fermer()`, `barrer()` ; le battement la ferme de 22 h à 5 h, l'ouvre le jour, la barre tant qu'une bande est en marche ou au contact, puis revient à l'état du moment. Le jeu reçoit l'ordre (`changer_porte(identifiant, etat)`) seulement au changement.

## Règles de l'atelier
- **Alchimie :** recettes en données (`atelier.recettes`) : `remede` (3 herbes, 1 bière → 1 remède), `onguent` (2 herbes, 1 cuir → 1 onguent). `preparer(recette, nombre)` prend au coffre et met la réserve `remedes` ou `onguents` (deux sortes de plus au coffre). `soigner(id)` prend un remède et ôte deux jours de soins à un blessé.
- **Armurerie :** chaque homme a une usure d'équipement (0 à 100). Une bataille use les combattants de 20 ; au-delà de 60, un homme pèse 30 % de moins au combat. `entretenir()` chaque jour au repas : un armurier valide répare 25 points à chacun des cinq hommes les plus usés, contre 1 fer et 1 cuir par homme réparé, tant qu'il y en a.
- **Entrées de la Gestion du camp :** `batir_enceinte`, `batir_tours`, `preparer_remede`, `preparer_onguent`, `soigner`.

## Sorts rendus
`batir` : `camp_absent`, `deja_batie`, `bois_insuffisant`, `niveau_maximal`. `preparer` : `recette_inconnue`, `nombre_invalide`, `ingredients_insuffisants`. `soigner` : `homme_inconnu`, `pas_blesse`, `pas_de_remede`.

## Ce qui est sauvegardé
Case `enceinte` (version 1) : `{ batie, niveau, objets, porte = { etat, identifiant, voulu }, derniere_heure }`. Case `atelier` (version 1) : `{ usure = { [id] = n }, dernier_jour_entretien }`. Les réserves `remedes` et `onguents` sont au coffre.

## Ce que le morceau demande au jeu (liaison)
`poser_objet`, `retirer_objet`, `objet_existe` (comme le camp) ; `changer_porte(identifiant, etat)` ; `heure_du_jeu` ; `journal`.

## À vérifier en jeu
- Les chemins des modèles de palissade, de porte et de tour du jeu de base.
- Comment ouvrir, fermer et barrer une porte posée (animation ou remplacement du modèle).

## Essais au banc (`essais/lua/essai_enceinte.lua`)
Plan cohérent ; bâtir et refus ; bois pris ; bonus et avance de guet ; porte selon l'heure et les bandes, ordres au changement ; démolition avec le camp ; redressement ; recettes et refus ; soins par remède ; usure par bataille et poids ; entretien par l'armurier contre fer et cuir ; entrées de la Gestion ; relecture.
