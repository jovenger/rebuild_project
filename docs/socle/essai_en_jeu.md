# Essai en jeu du socle (sur le PC de JoVenGer)

Rappel : rien de tout ceci ne touche au Scriptorium actuel, à son git ni à ses trois mods. Le socle s'installe dans `Mods\scriptorium_socle`, à part.

## 1. Préparer le PC (une fois)
1. Cloner ce dépôt : `git clone https://github.com/jovenger/rebuild_project "C:\Users\maste\Desktop\rebuild_project"` (décision D9), puis se placer sur la branche `ccr-c18b8b50-tespti`.
2. Installer le banc : `py -3.13 -m pip install lupa`.
3. Vérifier : `py -3.13 essais\tout_verifier.py` doit finir par « tout passe ».

## 2. Installer le socle dans le jeu
```
py -3.13 noyau\installer.py --jeu "G:\SteamLibrary\steamapps\common\KingdomComeDeliverance2"
```
- L'installateur relance la vérification, met de côté l'ancien mod d'essai dans `securite\`, puis écrit `Mods\scriptorium_socle` (manifeste, `Data\scriptorium_socle.pak`, `Localization\French_xml.pak`).
- Il refuse tout autre chemin.

## 3. Avant de lancer le jeu
- Désactiver les trois mods `scriptorium`, `scriptorium_regles`, `scriptorium_lumiere` par la liste des mods chargés du jeu (décision D10, à vérifier : `Mods\mod_order.txt`). Ne jamais renommer ni déplacer leurs dossiers.
- Jouer sur une **partie d'essai neuve**, jamais sur la partie actuelle.

## 4. Ce qu'il faut voir
1. Au lancement, dans le journal du jeu (`kcd.log`) : `[Scriptorium] Socle : morceau « bandeau » prêt`, puis `registre`, `coffre`, `poste`, puis `Socle 0.1.0 : 4 morceau(x) prêt(s), 0 en panne`.
2. En entrant dans la partie : le message « Le socle de Scriptorium est prêt. » à l'écran.
3. Dans la console du jeu (à vérifier : comment l'ouvrir) :
   - `scriptorium_essai_bandeau` → cinq annonces ; à l'écran, dans l'ordre : « Essai : une alerte, qui passe devant. », « Essai : une nouvelle ordinaire. », « Essai : plusieurs hommes sont arrivés au camp. » ;
   - `scriptorium_essai_registre` → « Essai : le registre a été écrit puis relu. » et, au journal, `appels = 1` ; relancer la commande : `appels = 2` ;
   - `scriptorium_essai_coffre` → au journal, `sorts = true, true, true, true, false ; solde = 70, vivres = 6, lignes = 4` et la bourse d'Henry diminuée de 100 (il faut au moins 100 groschen sur lui) ; à l'écran, « Le coffre du camp ne peut pas payer : il manque des groschen. » puis « Essai : le coffre a encaissé, payé et refusé comme il faut. » ;
   - `scriptorium_bilan` → résumé au journal.
4. Sauvegarder la partie d'essai, fermer le jeu, relancer, recharger, puis `scriptorium_essai_registre` : si `appels` repart à 1, le mécanisme de sauvegarde n'est pas encore le bon (attendu à ce stade : la liaison garde en mémoire seulement).

## 5. À vérifier en jeu, et à me rapporter
| N° | Question | Où ça se décide |
|---|---|---|
| V1 | Le texte s'affiche-t-il ? Où, et de quel aspect (bande noire en bas ou non) ? | `liaison.afficher` |
| V2 | Le texte est-il traduit (clé `@ui_scriptorium_…` remplacée par le français) ? Sinon, le nom du fichier de langue ou du pak est à changer | `socle/textes/fr`, installateur |
| V3 | Les commandes de console existent-elles (`System.AddCCommand`) ? Comment ouvrir la console ? | `liaison.commande` |
| V4 | Quel appel garde une chaîne dans la sauvegarde et la rend au chargement ? | `liaison.lire_registre` / `ecrire_registre` |
| V5 | Quel appel prévient qu'une partie vient d'être chargée ? | `registre.invalider` |
| V6 | Quel appel dit qu'un dialogue est en cours ? | `liaison.dialogue_en_cours` |
| V7 | Le manifeste est-il accepté (version du jeu dans `<kcd_version>`) ? | `socle/mod.manifest` |
| V8 | Reste-t-il un texte jaune à l'écran avec le socle seul ? | — |
| V9 | La bourse d'Henry bouge-t-elle avec `scriptorium_essai_coffre` (moins 100, puis rien de plus) ? Sinon, les appels `GetMoney`, `RemoveMoney`, `AddMoney` sont à corriger | `liaison.groschen_d_henry`, `retirer_groschen_a_henry`, `donner_groschen_a_henry` |
| V10 | Les lignes du livre ont-elles un `moment` autre que 0 (heure du jeu) ? | `liaison.heure_du_jeu` |

Pour me répondre : le contenu de `kcd.log` autour de `[Scriptorium]`, et une ligne par question.
