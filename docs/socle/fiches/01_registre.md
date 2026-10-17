# Fiche 01 — Le registre (sauvegarde des données du camp)

- Morceau : 1. Table : `Scriptorium.registre`. Fichier : `socle/pak/Scripts/scriptorium/registre.lua`.
- État : écrit et passé au banc (12 essais). En attente de l'essai en jeu, surtout pour le mécanisme de sauvegarde.
- **Taille (note de JoVenGer du 15/10 : aucune valeur enregistrée de plus de 65 535 octets).** Mesuré au banc : le registre d'un camp plein (80 hommes avec leur caractère, livre plein, enceinte, réserves, batailles, fautes, patrouilles) pèse 87 819 octets. La liaison le coupe donc en tranches de 30 000 caractères, une par jeton du jeu, sous un en-tête (identité, nombre de tranches, longueur, somme de contrôle de tous les octets) ; à la lecture, tout est recollé et vérifié, et une tranche manquante, abîmée ou d'une autre partie fait tout refuser. L'ancien format en un seul jeton se lit toujours. Les nombres s'écrivent courts : un entier sans décimales, un autre à neuf chiffres significatifs. Vérifié au banc : un registre de 200 Ko se coupe, se recolle et se relit à l'identique.
- **Vu en jeu le 15/10.** Le Lua du jeu compte en simple précision (entiers justes jusqu'à 16 777 216 seulement) et écrit un nombre collé à une chaîne avec six chiffres (« 1.03997e+09 ») : l'en-tête était illisible, d'où « jeton du jeu refusé ». La somme de contrôle se calcule donc modulo 65 521 et l'en-tête s'écrit par « %d » ; un en-tête illisible est refusé avec sa raison. Le registre en tranches est alors « en service » en jeu. Les noms de jetons à plusieurs points sont acceptés. Des jetons d'essai de 16 000 à 200 000 caractères se relisent intacts avant la sauvegarde, mais la sauvegarde qui en portait de 66 000 à 200 000 n'a plus pu être rechargée (« Échec du chargement ») : aucun jeton ne s'écrit au-delà de 65 535 octets, essais compris (barrière unique dans la liaison). Puis, depuis `autosave003` (accord de JoVenGer) : une sauvegarde avec le registre en tranches seul se recharge, le registre revient avec la même identité de partie ; une sauvegarde avec en plus des jetons de 16 000, 32 000, 60 000 et 65 000 caractères se recharge aussi, tous intacts. Jusqu'à 65 000 caractères par jeton, la sauvegarde tient ; à partir de 66 000 (ou par le total, 539 000 caractères ce jour-là contre 173 000), elle casse. Les tranches de 30 000 restent loin de la limite.

## Ce que le joueur voit
- Rien, en temps normal.
- « Le registre du camp a été remis à neuf. » si le contenu de la partie est illisible ou si une case est abîmée.
- Une montée de version se fait en silence (journal seulement).

## Règles
- **Un seul registre**, une enveloppe `{ format = 1, cases = { <nom> = { version, donnees } } }`, écrite dans la partie sous forme d'une seule chaîne.
- **Une case par morceau.** `declarer_case(nom, version, par_defaut, migrations)` ; `par_defaut` est une fonction qui rend les données d'une case neuve.
- **Lecture.** `lire(nom)` rend la table vivante ; le premier `lire` charge tout depuis la partie. Les morceaux modifient la table puis appellent `enregistrer()`.
- **Montée de version.** Si la case stockée est d'une version plus ancienne, les migrations `[v]` s'appliquent une par une, de `v` à `v+1`. Une migration manquante ou en échec remet la case à neuf.
- **Plus récent que le socle.** Une case stockée avec une version plus grande n'est pas devinée : remise à neuf, notée au journal.
- **Case abîmée.** Contenu mal formé ⇒ valeur par défaut, message au journal, mot au joueur.
- **Case déclarée après le chargement** (un morceau chargé tard) : servie tout de suite depuis le contenu lu.
- **Cases inconnues** du contenu lu (d'un socle plus récent, par exemple) : conservées telles quelles à l'écriture.
- **Sérialisation stable** : clés triées, mêmes données ⇒ même chaîne. Fonctions, clés booléennes, nombres impossibles et boucles sont refusés.
- **Lecture en bac à sable** : la chaîne est relue sans aucun accès aux globales du jeu.
- **`invalider()`** oublie ce qui est chargé : à appeler quand le joueur charge une autre partie.
- **`enregistrer()` avant toute lecture** charge d'abord : il n'écrase jamais la partie avec des valeurs par défaut.

## Rapport de `charger()`
`{ source = "vide" | "lu" | "illisible", chargees, neuves, migrees, abimees }`.

## Ce que le registre demande au jeu (liaison)
`lire_registre()` → chaîne ou nil ; `ecrire_registre(chaine)` ; `journal(texte)`.

## À vérifier en jeu
- **Le mécanisme de sauvegarde** : quel appel du moteur garde une chaîne dans la partie et la rend au chargement. En attendant, la liaison garde la chaîne en mémoire : elle ne survit pas à la fermeture du jeu.
- **Le moment du chargement** : l'appel du jeu qui dit « une partie vient d'être chargée », pour appeler `invalider()`.
- **La taille** : si le mécanisme limite la longueur, découper la chaîne en plusieurs morceaux.

## Essais au banc (`essais/lua/essai_registre.lua`)
Écrire puis relire ; registre vide ; contenu illisible ; bac à sable ; montée de version en deux pas ; montée manquante ou en échec ; version plus récente ; déclaration après chargement ; cases inconnues conservées ; enregistrer avant lecture ; sérialisation stable et refus ; déclarations invalides.

## Les écritures regroupées (demande du pair, 17/10)

Scriptorium gardera ses valeurs (141 fichiers, des centaines de clés, écrites souvent) dans des cases du registre
(`registre.declarer_case(nom, version, par_defaut)`, puis `registre.lire(nom)` : une table vivante, une valeur par clé,
de toute taille ; l'ensemble est écrit en tranches de 30 000 caractères, jamais au-delà de 65 535 octets). Chaque
écriture sérialise tout le registre (mesuré au banc : 10 000 clés, 1 Mo, 34 ms ; 50 000 clés, 5 Mo, 203 ms). Les
écritures sont donc regroupées : une au plus par `registre_intervalle_s` secondes réelles (réglage du noyau, 2 s) ; une
demande plus rapprochée attend, et le battement commun la vide ; `registre.enregistrer(true)` écrit tout de suite. Au
banc, l'intervalle vaut 0 (écritures immédiates), sauf l'essai du regroupement. Non vérifié en jeu.

## L'écriture par case (demande du pair, 17/10 ; conception relue)

Avec les valeurs de Scriptorium dedans, réécrire tout le registre à chaque changement ferait un à-coup régulier. Le
registre s'écrit donc **par case** :
- **Un index léger** (format 2) : la liste des noms de cases, réécrit seulement quand la liste change ; l'identité de
  la partie et sa marque portent sur lui.
- **Une chaîne par case** (`{ version, donnees }`, clés triées), écrite dans ses propres jetons en tranches (même
  identité, même somme de contrôle, même borne de 65 535 octets par jeton) ; une case qui rétrécit vide ses tranches en
  trop. Une case illisible (tranche manquante, somme fausse) ne perd plus tout le registre : elle seule est remise à
  neuf (ou reprise de la mémoire de secours), et le journal la nomme.
- **`registre.enregistrer(nom)`** marque la case nommée ; seules les cases marquées sont sérialisées et écrites
  (regroupées comme avant : au plus une écriture par `registre_intervalle_s`, l'attente vidée au battement ;
  `enregistrer(nom, true)` force). **Sans nom : toutes les cases**, une ligne au journal (le repli, cher). Chaque
  morceau nomme sa case ; Scriptorium nommera les siennes. Un nom de case est un nom de jeton : lettres, chiffres, `_`.
- **Les cases inconnues** (d'une version plus récente, ou de Scriptorium avant sa déclaration) restent dans l'index et
  dans leurs jetons, jamais réécrites.
- **L'ancien format** (format 1, un seul flux) se lit toujours : à la première écriture, toutes ses cases sont écrites
  par case, l'index posé, l'ancien flux vidé.
- **Le détecteur des oublis** (au banc seulement, réglage `registre_detecteur`) : à chaque écriture, une case changée
  sans être nommée est écrite quand même et dénoncée au journal ; le banc entier doit n'en dénoncer aucune.
- **Le journal des écritures** (réglage `registre_journal`, éteint par défaut) : une ligne par écriture réelle (cases,
  octets, tranches, durée).
