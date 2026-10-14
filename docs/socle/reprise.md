# Fiche de reprise — socle de Scriptorium (état au 14/10/2026)

À coller au début d'une nouvelle conversation Claude Code, lancée sur l'ordinateur de JoVenGer.

## 1. Le projet
- JoVenGer construit « Scriptorium », un grand mod pour Kingdom Come: Deliverance II (camp de mercenaires, Directeur, hommes, raids, coffre, Gestion du camp). Il vit dans `C:\Users\maste\Desktop\Scriptorium`, git local seulement.
- Scriptorium repose aujourd'hui sur le mod « Mercenaries » d'Alex (Steam Workshop n° 3689921142, version 3.0), copié dans `Scriptorium\mercenaires\`.
- **Mission :** refaire entièrement ce mod, à notre façon, comme un mod à part, sans jamais copier, traduire ni renommer le code d'Alex. Son adaptation à Scriptorium viendra après, hors de ce chantier.
- Dépôt du chantier : `https://github.com/jovenger/rebuild_project`, branche `ccr-c18b8b50-tespti`, PR brouillon n° 2.

## 2. Règles de JoVenGer (obligatoires)
- Tout en français, sans exception. Réponses concises, techniques, en listes.
- **Ne jamais toucher au Scriptorium actuel**, ni à son git, ni à la copie `D:\Scriptorium V2\Scriptorium`, ni aux trois mods installés (`Mods\scriptorium`, `scriptorium_regles`, `scriptorium_lumiere`), ni à `Data\` du jeu. Lecture seule si besoin.
- Le socle neuf s'installe dans `Mods\scriptorium_socle` seulement, et se joue sur une partie d'essai neuve, jamais sur la partie actuelle.
- Jamais le code d'Alex : fiche de comportement d'abord, code neuf d'après la fiche seule.
- Une chose à la fois, menée jusqu'au bout ; rien laissé en essai ; pas de `TODO`.
- Pas de commit si `essais\tout_verifier.py` ne passe pas entièrement.
- Aucune action destructive sans l'accord de JoVenGer juste avant.
- Un message de JoVenGer pendant le travail se prend en compte tout de suite.
- Plus aucun texte jaune par-dessus l'image du jeu : tout message passe par le bandeau en bas de l'écran.

## 3. Ce qui est fait (tout est dans le dépôt)
- `CLAUDE.md` : règles et plan des dossiers.
- `docs/socle/plan_de_refonte.md` : tout ce qui change par rapport au mod d'Alex, partie par partie, et les décisions D1 à D10.
- `docs/socle/avancement.md` : tableau des morceaux.
- `docs/socle/fiches/00_bandeau.md` à `04_hommes.md` : fiches de comportement (02 à 04 attendent la validation de JoVenGer).
- `docs/socle/essai_en_jeu.md` : marche à suivre pour l'essai en jeu, 17 points V1 à V17 à vérifier.
- `socle/pak/Scripts/scriptorium/` :
  - `noyau.lua` : table `Scriptorium`, morceaux, démarrage tolérant aux pannes ;
  - `liaison.lua` : **seul fichier qui parle au moteur** ; six appels marqués « à vérifier en jeu » ;
  - `bandeau.lua` (morceau 0) : messages au joueur, un à la fois, 3 à 8 s, alertes devant, pas de répétition avant 30 s, regroupement, attente pendant un dialogue, historique ;
  - `registre.lua` (morceau 1) : sauvegarde versionnée, une case par morceau, montées de version, remise à neuf, bac à sable ;
  - `coffre.lua` (morceau 2) : groschen du camp, livre de comptes, réserves par sorte (vivres, bière, fourrage, traits, bois, herbes, fer, cuir), dépôt et versement avec Henry ; le camp ne paie jamais avec la bourse d'Henry ;
  - `camp.lua` (morceau 3) : plan du camp en données sur 3 niveaux (feu, sièges, tentes, paillasses, coffre), fondation là où se tient Henry, agrandissement, redressement après chargement avec ou sans homme, levée, places (lits, sièges) réservables ;
  - `hommes.lua` (morceau 4) : fiche par homme (nom d'époque, rôle, rang, contrat, moral, blessure), embauche par contrat avec prime au coffre et paillasse, solde hebdomadaire selon le rang, rations et faim, journée réglée sur les heures, garde bornée au nombre d'hommes par tours de veille, dizainiers et capitaine, fin de contrat, désertion, renvoi, mort, soins avec barbier, ordres au jeu seulement au changement, redressement des personnages ;
  - `poste.lua` : commandes de console `scriptorium_essai_bandeau`, `scriptorium_essai_registre`, `scriptorium_essai_coffre`, `scriptorium_essai_camp`, `scriptorium_essai_camp_agrandir`, `scriptorium_essai_camp_lever`, `scriptorium_essai_hommes`, `scriptorium_bilan`.
- `socle/pak/Scripts/Startup/scriptorium_socle.lua` : démarrage. `socle/textes/fr/text_ui_scriptorium_socle.xml` : 35 textes. `socle/mod.manifest`.
- `essais/tout_verifier.py` : syntaxe Lua 5.1, banc (`essais/lua/essai_*.lua`, 591 vérifications, toutes passent), noms interdits, textes, manifeste, contrôle d'absence.
- `outils/empreintes.py` : relevé des empreintes d'Alex (sha256 seulement, rien en clair).
- `noyau/installer.py` : installe dans `Mods\scriptorium_socle` seulement, refuse les chemins interdits, met de côté dans `securite\` avant de remplacer, relance la vérification avant.

## 4. Ce qui n'est pas fait
- **Aucun essai en jeu.** Dix-sept appels du moteur restent à confirmer dans `liaison.lua` : affichage (`Game.SendInfoText`, aspect bande noire), dialogue en cours, lecture et écriture du registre dans la sauvegarde (en attendant : mémoire de session, perdue à la fermeture), chargement d'une partie (`registre.invalider`), commandes de console (`System.AddCCommand`), version du jeu dans le manifeste (`1.4`), bourse d'Henry (`player.inventory:GetMoney` / `RemoveMoney` / `AddMoney`), heure du jeu (`Calendar.GetWorldTime`), pose et retrait d'objets (`System.SpawnEntity` BasicEntity + `object_Model`, `System.RemoveEntity`, `System.GetEntity`), position et cap d'Henry (`player:GetWorldPos`, `player:GetWorldAngles`), chemins des modèles du jeu de base (`camp.modeles`), message avec complément, venue d'un personnage (`System.SpawnEntity` classe `NPC`, `sharedSoulGuid`, âmes à renseigner dans `liaison.ames`), ordres aux personnages (`liaison.ordonner`, journal seulement pour l'instant).
- **Empreintes d'Alex non relevées** : le contrôle d'absence ne tourne pas encore.
- Morceaux 5 à 8 : rien.

## 5. Décisions prises (accord de principe de JoVenGer le 14/10)
- D1 : éviter le mot « mercenaire » dans les textes (« la Compagnie », « soudoyers », « hommes d'armes »).
- D2 : voix du jeu de base pour les répliques courtes ; menus du Directeur sans voix.
- D3 : français seul au début.
- D4 : partie d'essai neuve pendant le chantier.
- D5 : salle blanche stricte (ne jamais ouvrir `mercenaires/` pour écrire le code).
- D6 : à la fin, seules les empreintes d'Alex sont gardées.
- D7 : toutes les nouveautés d'époque (contrat, solde, moral, vivres, rangs, pavois, guet, butin, barbier, usure, discipline, noms d'époque).
- D8 : bandeau en bas de l'écran, premier morceau.
- D9 : projet dans `C:\Users\maste\Desktop\rebuild_project`, mod d'essai `Mods\scriptorium_socle`.
- D10 : pendant un essai, désactiver les trois mods Scriptorium par la liste des mods chargés (`mod_order.txt`, à vérifier), jamais en renommant un dossier.

## 6. Pour démarrer sur l'ordinateur
```
git clone https://github.com/jovenger/rebuild_project "C:\Users\maste\Desktop\rebuild_project"
cd "C:\Users\maste\Desktop\rebuild_project"
git checkout ccr-c18b8b50-tespti
py -3.13 -m pip install lupa
py -3.13 essais\tout_verifier.py
```
Puis, pour l'essai en jeu (voir `docs\socle\essai_en_jeu.md`) :
```
py -3.13 noyau\installer.py --jeu "G:\SteamLibrary\steamapps\common\KingdomComeDeliverance2"
```
Et pour les empreintes (lecture seule sur la copie d'Alex) :
```
py -3.13 outils\empreintes.py "C:\Users\maste\Desktop\Scriptorium\mercenaires" docs\socle\empreintes_alex.json
```

## 7. Prochaines étapes, dans l'ordre
1. Essai en jeu des morceaux 0 à 4 ; réponses aux points V1 à V17 ; corriger `liaison.lua`, `camp.modeles` et `liaison.ames` d'après ce que le jeu dit.
2. Relever les empreintes d'Alex, commettre `docs/socle/empreintes_alex.json`, vérifier que le contrôle d'absence donne 0 partout.
3. Faire valider les fiches 02 à 04 par JoVenGer ; sceller les morceaux 0 à 4 dans `avancement.md`.
4. Morceau 5, le combat et les batailles : fiche `05_bataille.md` d'abord (une seule entrée « lever une bande » : qui, combien, d'où, vers où, quand ; ordre de bataille d'époque, pavois et hommes d'armes devant, arbalétriers et archers derrière avec ligne de tir ; fin de bataille : morts, blessés, butin au registre et au livre, moral par `hommes.moral_pour_tous`), validation, puis code et banc.
5. Puis, dans l'ordre : Directeur (6), murs, porte, alchimie (7), patrouilles et le reste (8).
