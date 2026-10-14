# Fiche de reprise — socle de Scriptorium (état au 14/10/2026, soir)

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
- Le camp paie au coffre, jamais avec la bourse d'Henry. Les tentes sont à JoVenGer. Les dépenses restent justes.

## 3. Ce qui est fait (tout est dans le dépôt)
- `CLAUDE.md` : règles et plan des dossiers. `docs/socle/plan_de_refonte.md` : le plan et les décisions D1 à D10. `docs/socle/avancement.md` : tableau des morceaux et résumé en une page. `docs/socle/fiches/00` à `08` : fiches de comportement (02 à 08 attendent la validation de JoVenGer). `docs/socle/essai_en_jeu.md` : marche à suivre et 24 points V1 à V24 à vérifier.
- `socle/pak/Scripts/scriptorium/` : `noyau.lua` (table `Scriptorium`, morceaux, démarrage, battement commun toutes les 30 s en partie), `liaison.lua` (**seul fichier qui parle au moteur**, 24 appels « à vérifier en jeu »), `bandeau.lua`, `registre.lua`, `coffre.lua`, `camp.lua`, `hommes.lua`, `bataille.lua`, `directeur.lua`, `enceinte.lua`, `atelier.lua`, `patrouilles.lua`, `discipline.lua` (décision D7 : fautes, jugements, réputation), `poste.lua` (quatorze commandes de console `scriptorium_*`).
- `socle/pak/Scripts/Startup/scriptorium_socle.lua` : démarrage. `socle/textes/fr/text_ui_scriptorium_socle.xml` : 77 textes. `socle/mod.manifest`.
- `essais/tout_verifier.py` : syntaxe Lua 5.1, banc (`essais/lua/essai_*.lua`, 1 322 vérifications dont un scénario complet d'une semaine, toutes passent), noms interdits, textes, manifeste, contrôle d'absence.
- `outils/empreintes.py` : relevé des empreintes d'Alex (sha256 seulement, rien en clair).
- `noyau/installer.py` : installe dans `Mods\scriptorium_socle` seulement, refuse les chemins interdits, met de côté dans `securite\` avant de remplacer, relance la vérification avant.

## 4. Ce qui n'est pas fait
- **Aucun essai en jeu.** Vingt-quatre appels du moteur restent à confirmer dans `liaison.lua` (affichage, dialogue, sauvegarde, chargement, console, manifeste, bourse d'Henry, heure, pose d'objets, position d'Henry, modèles, complément, venue des personnages et des ennemis, ordres, morts, Directeur, dialogue de gestion, porte, partie en cours). Tant que la sauvegarde n'est pas confirmée, le registre ne survit pas à la fermeture du jeu.
- **Les âmes** (`liaison.ames`, `liaison.ames_ennemies`, `liaison.ame_du_directeur`) et **les chemins des modèles** (`camp.modeles`, `enceinte.modeles`) sont vides ou provisoires : à relever dans le jeu.
- **Les tables du jeu** (âmes, personnages, apparence du Directeur), **la quête de fond**, **les dialogues** et **les voix** ne sont pas faits : le menu de la Gestion du camp existe en données, sans écran de jeu.
- **Empreintes d'Alex non relevées** : le contrôle d'absence ne tourne pas encore.
- Aucun morceau n'est scellé.

## 5. Décisions prises (accord de principe de JoVenGer le 14/10)
- D1 : éviter le mot « mercenaire » dans les textes (« la Compagnie », « soudoyers », « hommes d'armes », « soudards » pour les ennemis).
- D2 : voix du jeu de base pour les répliques courtes ; menus du Directeur sans voix.
- D3 : français seul au début.
- D4 : partie d'essai neuve pendant le chantier.
- D5 : salle blanche stricte (ne jamais ouvrir `mercenaires/` pour écrire le code).
- D6 : à la fin, seules les empreintes d'Alex sont gardées.
- D7 : toutes les nouveautés d'époque (contrat, solde, moral, vivres, rangs, pavois, guet, butin, barbier, usure, discipline, noms d'époque) — toutes faites au banc.
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

## 6 bis. Pour plus tard, pas maintenant
- `docs/socle/idees_pour_plus_tard.md` : vingt-six idées (contrats, chronique, discipline, histoires des hommes, calendrier, pavois et traits…). Consigne de JoVenGer : on termine d'abord ce qui est commencé.

## 7. Prochaines étapes, dans l'ordre
1. Essai en jeu, réponses aux points V1 à V24 ; corriger `liaison.lua`, renseigner les âmes et les modèles d'après ce que le jeu dit.
2. Relever les empreintes d'Alex, commettre `docs/socle/empreintes_alex.json`, vérifier que le contrôle d'absence donne 0 partout.
3. Faire valider les fiches 02 à 08 par JoVenGer ; sceller les morceaux un par un dans `avancement.md`, chacun après son essai en jeu.
4. Puis : les tables du jeu (âmes et personnages à nous, apparence neuve du Directeur), le dialogue de la Gestion du camp, la quête de fond, la discipline envers les paysans (D7), le contrôle d'absence en mode strict.
