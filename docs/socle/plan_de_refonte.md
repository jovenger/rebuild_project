# Refonte du socle de Scriptorium : ce qui doit changer par rapport au mod d'Alex

- Statut : proposition à valider par JoVenGer, datée du 14/10/2026. Aucune ligne de code n'est écrite.
- Source : la description de JoVenGer du 14/10/2026. Le code (`mercenaires/`, `choses/`, `noyau/`) n'est pas lisible depuis cette session. La liste fonction par fonction sera complétée à l'étape 0, l'inventaire (partie 1).
- Les mentions « à vérifier » désignent des points du jeu ou du projet qui ne sont pas encore confirmés.

---

## 0. En bref

- Tout ce qui vient d'Alex est remplacé : code, noms, voix, modèles, icônes, écrans, quêtes, dialogues, textes et réglages.
- **Méthode.** Pour chaque morceau, on écrit d'abord une fiche de comportement en français, qui dit *ce que* le camp doit faire. Le code neuf est ensuite écrit d'après la fiche seule ; c'est lui qui dit *comment*.
- **Où vit le socle.** Le socle vit dans un seul dossier de Scriptorium. Ses fonctions sont rangées sous la table Lua `Scriptorium`, avec des noms français, sans accents dans les identifiants.
- **Ressources.** On prend celles du jeu de base, appelées par leur chemin et jamais copiées, ou on en crée de neuves.
- **Contrôle.** Un « contrôle d'absence » est ajouté à `essais/tout_verifier.py`. Il compte ce qui reste d'Alex et doit finir à zéro partout.
- **Messages à l'écran.** Plus aucun texte jaune par-dessus l'image : chaque message passe par une bande noire en bas de l'écran, écrite proprement, au moment où la chose arrive (morceau 0, partie 2.0 bis).
- **Ordre.** D'abord le bandeau des messages (morceau 0), puis 8 morceaux, dans l'ordre fixé par JoVenGer. Chacun est testé en jeu et scellé avant le suivant. On finit sur une partie neuve.
- **Décisions.** 8 décisions restent à prendre par JoVenGer (partie 10).

---

## 1. Méthode (la même pour chaque morceau)

### Étape 0 : l'inventaire (une seule fois, avant le premier morceau)

- Lister les 88 scripts Lua et les 2 100 fonctions environ d'Alex, rangés par morceau.
- Lister chaque appel des 211 dossiers de `choses/` vers `mercenaries` : dossier, fonction appelée, morceau concerné.
- Lister aussi ce que lisent les programmes du PC (panneau, téléphone, veilleur) : clés de sauvegarde, noms, fichiers.
- Lister les clés de sauvegarde, les identifiants uniques des tables, les personnages, les clés de textes, les voix, les modèles, les icônes, les quêtes et les arbres d'intelligence artificielle.
- Résultat : le **registre de remplacement** (`docs/socle/registre.md`). Pour chaque élément d'Alex, il indique le morceau, le remplaçant et l'état (à faire, remplacé ou vérifié). C'est la version complète de la présente liste.
- Première mesure du contrôle d'absence (partie 8), qui sert de point de départ.

### Pour chaque morceau

1. **Fiche de comportement** (`docs/socle/fiches/<morceau>.md`) :
   - contenu : ce que le joueur voit, les règles et les chiffres, ce que demandent les dossiers de `choses/`, ce qui est sauvegardé, les essais à faire ;
   - sources : le jeu tel qu'on le joue, les souhaits de JoVenGer et les 27 retouches de `MODIFICATIONS.md` (qui deviennent des règles du socle) ;
   - interdits : le code d'Alex, ses noms internes et la façon dont il découpe ses fonctions.
2. Validation de la fiche par JoVenGer.
3. Écriture du code d'après la fiche seule, sans ouvrir `mercenaires/`.
4. Adaptation des dossiers de `choses/` et des programmes du PC concernés, un par un.
5. `noyau/mercenaires.py` cesse d'installer les fichiers d'Alex de ce morceau.
6. Banc d'essai, vérification complète, puis contrôle d'absence : le morceau doit être à zéro.
7. Mise de côté, installation, essai en jeu, et sauvegarde de la partie avant de fermer le jeu.
8. Scellé, puis morceau suivant.

### Salle blanche

- La garantie la plus sûre : la session qui écrit le code n'est pas celle qui a lu le code d'Alex. La première rédige la fiche, la seconde n'a que la fiche (décision D5).
- Les fiches et leur historique sont gardés : ils montrent que le code vient du comportement voulu et non du texte d'Alex.

### Pendant le chantier, les deux socles cohabitent

- **Passerelles.** Un morceau d'Alex encore en place peut appeler un morceau déjà remplacé. Une passerelle temporaire renvoie alors ces appels vers le nouveau code. Elle est notée dans le registre et disparaît avec le dernier morceau d'Alex qui s'en sert.
- **Données de la partie en cours.** Deux possibilités (décision D4) :
  - reprise unique des anciennes clés vers les nouvelles, supprimée à la fin ;
  - partie d'essai neuve.

---

## 2. Le code, morceau par morceau

Les grandes fonctions ci-dessous viennent de ta description. Le détail des 2 100 fonctions ira dans le registre (étape 0).

| N° | Morceau | Table Lua de Scriptorium |
|---|---|---|
| 0 | Bandeau des messages | `Scriptorium.bandeau` |
| 1 | Sauvegarde des données du camp | `Scriptorium.registre` |
| 2 | Coffre et logistique | `Scriptorium.coffre` |
| 3 | Camp : tentes, lits, feux, sièges | `Scriptorium.camp` |
| 4 | Hommes au camp | `Scriptorium.hommes` |
| 5 | Combat et batailles | `Scriptorium.bataille` |
| 6 | Directeur | `Scriptorium.directeur` |
| 7 | Murs, porte, alchimie | `Scriptorium.enceinte`, `Scriptorium.alchimie` |
| 8 | Patrouilles et le reste | `Scriptorium.patrouilles`, autres selon l'inventaire |

### 2.0 Démarrage et installation

**Chez Alex**
- `Scripts/mods/mercenaries.lua`, lancé par le script de démarrage de Scriptorium.
- `noyau/mercenaires.py` :
  - 368 fichiers ajoutés, 19 tables fusionnées, 8 fichiers où la version corrigée gagne ;
  - textes, voix et `mod.cfg` recopiés.

**Dans Scriptorium**
- Le script de démarrage de Scriptorium charge le socle directement, dans cet ordre : bandeau, registre, coffre, camp, hommes, bataille, directeur, enceinte, patrouilles.
- Chaque morceau signale qu'il est prêt. Un morceau qui échoue au chargement est annoncé en clair (journal et panneau) au lieu de bloquer les suivants.
- `noyau/mercenaires.py` rétrécit à chaque morceau, puis disparaît. Le noyau installe ensuite le socle comme le reste de Scriptorium.

**Vérification**
- Plus de `Scripts/mods/mercenaries.lua` dans le pak.
- `noyau/mercenaires.py` est absent, et plus rien dans `noyau/` ne l'appelle.

### 2.0 bis Le bandeau des messages (morceau 0, demandé le 14/10/2026)

**Aujourd'hui**
- Des textes jaunes s'écrivent par-dessus l'image du jeu. Ils viennent du mod d'Alex, et peut-être aussi de dossiers de Scriptorium.
- Leur origine exacte sera trouvée à l'inventaire : des appels d'affichage de débogage dans le code, ou un réglage de `mod.cfg` qui les allume (à vérifier).

**Dans Scriptorium**
- **Une seule porte de sortie.** Plus aucun texte jaune. Tout message destiné au joueur passe par une seule fonction : `Scriptorium.bandeau.annoncer(texte, importance)`.
- **Aspect.** Une bande noire, légèrement transparente, en bas de l'écran et sur toute sa largeur. Texte blanc cassé, centré, dans la police du jeu, sur 2 lignes au plus.
- **Moment.** Le message s'affiche quand la chose arrive dans le jeu, ni avant ni après.
- **Durée.** Elle dépend de la longueur : 3 secondes au moins, 8 au plus (environ 3 mots lus par seconde).
- **File d'attente.** Un seul message à la fois. Les alertes (raid, attaque du camp) passent devant les autres.
- **Pas de répétition.** Un même message n'est pas redit avant 30 secondes. Les messages semblables sont regroupés, par exemple « Trois hommes ont rejoint le camp ».
- **Dialogues, cinématiques, menus.** Le message attend qu'ils soient finis : il ne cache jamais les sous-titres du jeu.
- **Écriture.** Français propre, phrases courtes, mots d'époque. Jamais de nom de fonction, de valeur technique, d'anglais ni de message d'erreur brut.
- **Messages techniques.** Ils ne vont plus à l'écran, seulement dans le journal du jeu. Le veilleur et le panneau peuvent continuer à les lire (à vérifier : ce que lit le veilleur aujourd'hui).
- **Historique.** Les derniers messages se relisent dans la Gestion du camp et dans le panneau.
- **Textes.** Tous les textes du bandeau sont des textes de langue (`scriptorium_bandeau_*`), jamais écrits en dur dans le code.

**Moyen technique (à choisir après un essai en jeu)**
1. Les sous-titres du jeu, s'ils peuvent recevoir un texte libre depuis Lua : même place, même police, fond noir du jeu.
2. Sinon, un élément d'interface neuf (une bande noire et une zone de texte), commandé depuis Lua.

**Vérification**
- **Contrôle automatique** (partie 8, examen 10) :
  - 0 appel d'affichage direct à l'écran ailleurs que dans le bandeau (socle et `choses/`) ;
  - 0 réglage de `mod.cfg` qui allume du texte de débogage.
- **Banc d'essai :** file d'attente, priorité, non-répétition, durée.
- **En jeu :** raid, paie, embauche et patrouille donnent chacun un message propre en bas de l'écran, sans aucun texte jaune. Pendant un dialogue, le message attend.

**Pourquoi en premier**
- Le morceau est petit et se voit tout de suite. Tous les morceaux suivants s'en servent pour parler au joueur.
- Il peut être fait sur le Scriptorium actuel dès que le code est accessible. Pendant le chantier, les messages d'Alex sont envoyés vers le bandeau (retouche notée dans `MODIFICATIONS.md`). Ensuite, le socle neuf l'utilise directement.

### 2.1 Sauvegarde des données du camp (morceau 1)

**Chez Alex**
- Données du camp rangées sous des clés séparées (par exemple `QMCoffer`, l'état du camp).

**Dans Scriptorium**
- Un seul **registre**, avec un numéro de version.
- Chaque morceau a sa case dans le registre : coffre, camp, hommes, enceinte, patrouilles, etc.
- **Montée de version.** Quand une case change de forme, une fonction convertit l'ancienne. Les sauvegardes futures ne cassent plus.
- **Au chargement.** Une case absente ou abîmée reçoit sa valeur par défaut, avec un message en clair, jamais une erreur muette.
- Le mécanisme de sauvegarde du jeu reste à choisir pendant l'inventaire (à vérifier).

**Vérification**
- Aucune clé de sauvegarde d'Alex (liste tirée de l'inventaire) dans le code, ni dans une sauvegarde de la partie neuve.
- Banc d'essai :
  - enregistrer puis recharger donne les mêmes données ;
  - un registre vide donne un camp neuf ;
  - un registre d'ancienne version est mis à jour.

### 2.2 Coffre et logistique (morceau 2)

**Chez Alex**
- Coffre du camp, réserves, argent donné à Henry.

**Dans Scriptorium**
- **Livre de comptes.** Chaque entrée ou sortie d'argent ou de marchandise est inscrite avec la date du jeu, le motif et le montant.
- **Règle de JoVenGer, tenue par le code.** Toute dépense du camp passe par le coffre, jamais par la bourse d'Henry. Si le coffre ne peut pas la couvrir, la dépense est refusée : elle n'est pas prise ailleurs.
- **Réserves** comptées par sorte : vivres, bière, fourrage, flèches et carreaux, bois, herbes.
- **Versement à Henry** : une ligne du livre de comptes, avec son motif.
- Livre lisible dans la Gestion du camp et dans le panneau.

**Vérification**
- Banc d'essai : entrées moins sorties égale le solde.
- Recherche automatique : la bourse d'Henry n'est touchée nulle part, sauf par le versement autorisé.

### 2.3 Le camp : tentes, lits, feux, sièges (morceau 3)

**Chez Alex**
- Création du camp, tentes, lits, feux, sièges.
- Redressement après un chargement, y compris ta retouche « camp redressé sans homme ».

**Dans Scriptorium**
- Le plan du camp est une liste d'emplacements (sorte, position, orientation) écrite en données, pas dans le code.
- Il utilise les objets du jeu de base (tentes, paillasses, feux, bancs), appelés par leur chemin.
- Après chargement, le camp est reconstruit d'après le registre, avec ou sans hommes.
- Les tentes appartiennent à JoVenGer : le propriétaire est inscrit au registre.

**Vérification**
- Aucun objet ni modèle du dossier d'Alex.
- Plan du camp comparé au sien : positions et contenu différents.
- En jeu :
  - charger une partie donne un camp complet ;
  - un camp sans homme reste complet.

### 2.4 Les hommes au camp (morceau 4)

**Chez Alex**
- Embauche, comportement au camp, rondes de garde.
- Personnages « Merc… », arbres d'intelligence artificielle du camp, âmes et cerveaux dans les tables.

**Dans Scriptorium**
- Une fiche par homme : nom, rôle, rang, contrat, solde, moral, blessures, équipement.
- Embauche par contrat (partie 7).
- **Journée réglée sur les heures du jour** : lever, repas, exercice, garde, veillée, sommeil. On s'appuie d'abord sur les comportements du jeu (s'asseoir au feu, manger, dormir dans un lit) plutôt que sur des arbres faits sur mesure.
- **Garde.** Le nombre de postes ne dépasse jamais le nombre d'hommes (ta retouche devient une règle), et la relève se fait par tours de veille.
- Âmes et cerveaux neufs, avec de nouveaux identifiants uniques.
- Noms tirés de prénoms bohêmes et allemands des années 1400.

**Vérification**
- Aucun identifiant unique, nom d'âme, nom de cerveau ni ligne de table d'Alex. Les lignes sont aussi comparées sans leurs identifiants.
- Arbres d'intelligence artificielle comparés par leur structure (partie 8).

### 2.5 Combat et batailles (morceau 5)

**Chez Alex**
- Raids, batailles aux murs, embuscades, tours.
- Fonction de bataille `WBRaid`, utilisée par les raids de Scriptorium.
- Tes retouches : archers qui cherchent une ligne de tir, archers au dernier rang.

**Dans Scriptorium**
- **Une seule entrée, « lever une bande »** (qui, combien, d'où, vers où, quand), utilisée par tous les raids de Scriptorium.
- **Ordre de bataille d'époque.** Devant : porteurs de pavois et hommes d'armes. Derrière : arbalétriers et archers, qui cherchent une ligne de tir (tes retouches deviennent des règles).
- **Fin de bataille.** Morts, blessés et butin sont inscrits au registre et au livre de comptes.
- Les embuscades et les tours vont dans ce morceau ou dans le morceau 8, selon l'inventaire.

**Vérification**
- Plus aucun appel à `WBRaid`, ni dans `choses/`, ni ailleurs.
- Code comparé par sa forme (partie 8).
- En jeu : un raid réel. Pour avancer l'heure, un saut d'horloge, raids coupés pendant le saut (ta règle).

### 2.6 Le Directeur (morceau 6)

**Chez Alex**
- L'intendant `MercQuartermaster`, avec ses dialogues et ses voix.

**Dans Scriptorium**
- **Personnage neuf, `Scriptorium_Directeur`.** Nouvelle âme et nouvel identifiant. Son apparence est choisie parmi les têtes et habits du jeu, et doit être différente de celle d'Alex.
- **Rôle.** Il tient le livre de comptes, paie la solde, signe les contrats et ouvre la Gestion du camp.
- Dialogues neufs, écrits en français (partie 5).

**Vérification**
- Aucun « Merc » ni « Quartermaster » nulle part.
- Apparence comparée ligne à ligne à celle d'Alex : elle doit être différente.

### 2.7 Murs, porte, alchimie (morceau 7)

**Chez Alex**
- 54 modèles de murs, la porte (`Entities/mercenaries_Gate.ent`), l'alchimie, la forge.

**Dans Scriptorium**
- **Enceinte** : palissade de pieux, fossé, talus et porte de bois, faits avec les modèles du jeu de base (à recenser, à vérifier).
- **Porte** : entité neuve `Scriptorium_Porte`, qui s'ouvre, se ferme la nuit et peut être barrée.
- **Alchimie** dans la Gestion du camp, comme tu le souhaites, en s'appuyant sur l'alchimie du jeu.
- **Forge** rangée au métier « armurier » de Scriptorium : une nouveauté reste dans le dossier de son métier.

**Vérification**
- Aucun modèle d'Alex dans les paks (comparaison d'empreintes).
- Aucun chemin `Objects/mercenaries` ni `mercenaries_Gate`.

### 2.8 Patrouilles et le reste (morceau 8)

**Chez Alex**
- Patrouilles, tours, embuscades, interface.
- 2 classes d'entités : « objets » et « interface ».

**Dans Scriptorium**
- **Patrouilles.** Chemins écrits en données, avec heure de départ, effectif et retour au camp. Chaque patrouille rend compte au Directeur.
- **Interface.** La Gestion du camp, les dialogues et le panneau remplacent les écrans d'Alex.
- **Classe « objets ».** Refaite seulement si l'inventaire montre un vrai besoin, sinon supprimée.

**Vérification**
- Les 3 classes d'entités d'Alex sont absentes.
- Le compteur des appels à `mercenaries` dans `choses/` arrive à 0.

### 2.9 Les tables du jeu (54) et les arbres d'intelligence artificielle (27)

**Chez Alex**
- 54 tables : âmes, cerveaux, objets, buffs, rôles, personnages.
- 27 arbres d'intelligence artificielle.

**Dans Scriptorium**
- Tables neuves, rangées par morceau :
  - chaque ligne est créée pour un besoin de la fiche ;
  - tous les identifiants uniques sont neufs.
- Arbres : on prend d'abord les comportements du jeu. Un arbre sur mesure n'est écrit que si la fiche l'exige.

**Vérification**
- 0 identifiant unique d'Alex.
- 0 ligne de table identique, même une fois les identifiants retirés.
- 0 arbre de même structure.

---

## 3. Les noms

| Chez Alex | Dans Scriptorium |
|---|---|
| Table Lua `mercenaries` (environ 2 100 fonctions) | Table `Scriptorium`, découpée en `registre`, `coffre`, `camp`, `hommes`, `bataille`, `directeur`, `enceinte`, `alchimie`, `patrouilles` |
| 88 fichiers `mercenaries_*.lua` | Un fichier par morceau, dans le dossier du socle (emplacement exact à l'inventaire) |
| `Scripts/mods/mercenaries.lua` | Supprimé : le démarrage de Scriptorium charge le socle |
| `Entities/mercenaries_Gate.ent` | `Entities/Scriptorium_Porte.ent` |
| `Objects/mercenaries/walls/…` | Aucun dossier : modèles du jeu de base, appelés par leur chemin |
| `AI/mercenary_scheduler.xml` | `AI/scriptorium_journee.xml`, seulement si un arbre sur mesure reste nécessaire |
| `Quests/mercenaries/…` | `Quests/scriptorium/…` |
| `MercQuartermaster` | `Scriptorium_Directeur` |
| Autres personnages `Merc…` | `Scriptorium_<rôle>` : `Capitaine`, `Dizainier`, `Arbaletrier`, `Pavoisier`, `Archer`, `HommeDArmes`, `Barbier`, `Cuisinier`, `Armurier` |
| Clés de sauvegarde (`QMCoffer`, état du camp…) | Cases du registre : `coffre`, `camp`, `hommes`… |
| Environ 1 000 clés de textes | `scriptorium_<morceau>_<sujet>` |
| Identifiants uniques des âmes, cerveaux, objets, buffs et rôles | Nouveaux identifiants, générés |
| Quête de fond et quêtes d'Alex | Quête de fond neuve, nom à choisir (exemple : « La Compagnie ») |
| `noyau/mercenaires.py`, `mercenaires.comparer()` | Supprimés, remplacés par le contrôle d'absence |
| Dossier `mercenaires/` | Quitte le projet à la fin (décision D6) |

**Règles de nommage**
- Mots français.
- Ni accents ni espaces dans les identifiants et les chemins : le moteur risque de mal les lire (à vérifier ; prudence en attendant).
- Tout ce qui appartient au socle commence par `Scriptorium` ou `scriptorium`.
- Rien d'Alex n'est gardé sous un autre nom : un nom simplement traduit compte comme copié. On nomme d'après la fiche.

**Vérification** : partie 8, examen 3.

---

## 4. Voix, modèles de murs, icônes, écrans

### Voix

**Chez Alex**
- 1 084 voix en anglais, copiées dans les paks de langue de Scriptorium.

**Dans Scriptorium** (décision D2)
- Répliques déjà enregistrées du jeu de base (salut, acquiescement, cris de combat), appelées par leur identifiant, sans copie.
- Dialogues de gestion avec le Directeur sans voix, en texte seul (à vérifier : le jeu doit accepter une réplique sans son).
- Plus tard, si tu le souhaites, des voix neuves enregistrées pour Scriptorium.

**Vérification**
- 0 fichier son d'Alex dans les paks (empreintes et noms).
- 0 référence à ses sons dans le code, les quêtes ou les dialogues.

### Modèles de murs (54)

**Chez Alex**
- 54 modèles dans `Objects/mercenaries/walls/`.

**Dans Scriptorium**
- Palissades, pieux, portes et tours de bois du jeu de base, appelés par leur chemin. Aucun modèle copié dans le pak.

**Vérification**
- 0 fichier de modèle, de matière ou de texture d'Alex (empreintes).
- 0 chemin vers `Objects/mercenaries`.
- Chaque modèle appelé existe bien dans le jeu de base.

### Icônes

**Chez Alex**
- Icônes de ses objets et buffs.

**Dans Scriptorium**
- Icônes du jeu de base, ou icônes neuves dessinées pour Scriptorium.

**Vérification**
- 0 image identique (empreintes).
- 0 nom d'icône d'Alex.

### Écrans

**Chez Alex**
- Son interface, avec sa classe d'entité « interface ».
- Ses textes jaunes écrits par-dessus l'image.

**Dans Scriptorium**
- La Gestion du camp, les menus de dialogue du Directeur et le panneau du PC.
- Le bandeau des messages en bas de l'écran (partie 2.0 bis).

**Vérification**
- 0 fichier d'écran d'Alex.
- Classe « interface » absente.

---

## 5. Quêtes, dialogues et textes

### Quêtes

**Chez Alex**
- 163 fichiers de quêtes et de dialogues, dont une quête de fond sur les deux cartes.

**Dans Scriptorium**
- Une quête de fond neuve, qui tient le camp en vie sur les deux cartes, avec ses propres étapes et objectifs (payer la solde, tenir les vivres, garder le camp).

**Vérification**
- 0 nom de quête, 0 identifiant d'étape, 0 structure identique (partie 8, examen 9).

### Dialogues

**Chez Alex**
- Les dialogues de l'intendant et des hommes.

**Dans Scriptorium**
- Arbres neufs écrits en français pour le Directeur, le capitaine et les hommes.
- Parler d'époque, sobre, sans mot moderne : jamais « ok », « équipe » ou « manager ».

**Vérification**
- 0 identifiant de nœud d'Alex.
- 0 texte au-dessus du seuil de ressemblance (examen 7).

### Textes

**Chez Alex**
- Environ 1 000 textes, en 16 langues.

**Dans Scriptorium**
- Textes neufs écrits d'abord en français ; les autres langues viennent ensuite (décision D3).
- Vocabulaire : solde, gages, guet, dizaine, pavois, compagnie, livre de comptes, groschen.

**Vérification**
- Comparaison exacte, normalisée, puis par ressemblance avec ses textes dans les 16 langues. La comparaison avec ses textes français attrape aussi une traduction de son anglais.

---

## 6. Réglages (`mod.cfg`) et manifeste

### `mod.cfg`

**Chez Alex**
- Son `mod.cfg`, ajouté à celui de Scriptorium.

**Dans Scriptorium**
- Son ajout est retiré.
- Chaque réglage dont le socle a besoin est choisi de nouveau, d'après la fiche, avec une ligne de commentaire en français qui dit pourquoi.

**Vérification**
- 0 ligne identique à son `mod.cfg`.
- Seule exception : un réglage du moteur dont Scriptorium a réellement besoin. Il est nommé un par un dans le contrôle, avec la raison, après accord de JoVenGer.

### Manifeste

**Chez Alex**
- Son manifeste, qui n'est déjà plus installé depuis le 12/10.

**Dans Scriptorium**
- Seuls les manifestes de Scriptorium.

**Vérification**
- 0 nom, description ou identifiant d'Alex dans les manifestes installés.

---

## 7. La façon de jouer : ce qui sera différent et meilleur

Pour chaque nouveauté, l'inventaire (étape 0) dira ce qu'Alex fait déjà sur le sujet. La nouveauté est de toute façon écrite d'après sa propre fiche.

| Nouveauté | Comment ça marche | Pourquoi c'est d'époque | Morceau |
|---|---|---|---|
| Contrat d'engagement | Durée en semaines, prime à la signature, solde convenue ; à la fin, l'homme renouvelle ou s'en va | Les compagnies se louaient par contrat à durée fixe | 4, 6 |
| Solde hebdomadaire | Payée par le Directeur, au coffre, le même jour chaque semaine ; un retard fait baisser le moral, puis provoque des départs | La solde était le cœur du métier de soudoyer | 2, 6 |
| Moral | Quatre niveaux, selon la solde, les vivres, le repos, les victoires, les pertes et le butin ; il agit sur le courage au combat et sur les départs | Une troupe mal payée ou affamée se débande | 4, 5 |
| Vivres et jours maigres | Ration par homme et par jour (pain, bière, potage, viande ou poisson) ; pas de viande le vendredi ni en carême (à vérifier : calendrier du jeu) ; un manque fait baisser le moral | Règles de l'Église respectées par tous | 2, 4 |
| Rangs | Un dizainier pour dix hommes, un capitaine (hejtman) pour la compagnie ; promotions au mérite | Dizaines et capitaines, usage courant vers 1400 | 4 |
| Pavois et arbalètes | Un porteur de pavois couvre un arbalétrier ; les archers restent derrière (si le jeu fournit les pavois, à vérifier ; sinon, grands écus) | Le pavois de Bohême était réputé dans toute l'Europe | 5 |
| Guet de nuit | Tours de veille, relève, mot du guet changé chaque soir ; la porte est fermée et barrée la nuit | Garde des camps et des villes | 4, 7 |
| Butin | Partagé selon la coutume : part du capitaine, part des hommes, part du coffre, tout inscrit au livre de comptes | Partage du butin fixé par contrat | 2, 5 |
| Barbier-chirurgien | Soigne les blessés au camp ; un blessé ne combat pas tant qu'il n'est pas guéri | Barbiers et étuves sont dans le jeu | 4 |
| Usure et entretien | L'équipement s'use ; l'armurier du camp le répare en consommant les réserves (fer, cuir) | Entretien quotidien des armes | 7 (armurier) |
| Discipline | Vol ou violence chez les paysans : amende retenue sur la solde, puis renvoi ; la réputation de la compagnie auprès des villages s'en ressent | Ordonnances de discipline des compagnies | 4, 6 |
| Noms d'époque | Prénoms et surnoms bohêmes et allemands vers 1400 (Jan, Mikuláš, Ondřej, Hanuš, Kunrát…) | Population mêlée de la Bohême | 4 |

**Écartés parce qu'ils ne sont pas de l'époque**
- Le fort de chariots (« vozová hradba ») : années 1420.
- Les armes à feu en nombre : rares en 1403.
- Uniformes et grades modernes.

**Règles de JoVenGer gardées telles quelles**
- Le camp paie au coffre, les tentes sont à JoVenGer, les dépenses restent justes.
- Jamais le temps du jeu accéléré avec Henry seul.

---

## 8. Le contrôle d'absence (dans `essais/tout_verifier.py`)

Il remplace `mercenaires.comparer()`.

### Ce qu'il examine

- **Le mod installé :** les paks de `scriptorium`, `scriptorium_regles` et `scriptorium_lumiere`, les paks de langue, `mod.cfg` et les manifestes.
- **Les sources du projet :** le dossier du socle, `choses/`, `noyau/` et les programmes du PC (panneau, téléphone, veilleur).
- **La référence :** la copie d'Alex (`mercenaires/`), ou son fichier d'empreintes (voir plus bas).

### Ce qu'il écarte avant de comparer

- Tout ce qui existe aussi dans le jeu de base (`Data/*.pak`, lu sans être modifié). Ce n'est pas l'œuvre d'Alex : en-têtes de fichiers, fonctions du moteur, mots du langage.
- Les lignes trop courtes pour appartenir à quelqu'un, comme `end` ou `else`.

### Les 9 examens (objectif : 0 partout)

1. **Fichiers.** L'empreinte de chaque fichier installé est comparée à celle de chaque fichier d'Alex.
2. **Chemins.** Aucun chemin de fichier identique, majuscules et minuscules confondues.
3. **Noms.**
   - Recherche des motifs `mercenar` (toutes casses), `Merc` suivi d'une majuscule ou d'un `_`, `merc_`, `QM` suivi d'une majuscule.
   - Recherche de la liste des noms tirés d'Alex : fonctions, champs, classes, âmes, quêtes, clés de textes, clés de sauvegarde, identifiants uniques.
   - Les motifs visent les identifiants, pas les mots courants : « merci », « mercredi » ou « commerce » ne déclenchent rien.
   - Si D1 interdit aussi le mot « mercenaire », le motif `mercenair` s'ajoute.
4. **Lignes de code.** Chaque ligne, sans espaces ni commentaires, est comparée à celles d'Alex.
5. **Forme du code.**
   - Les noms, textes et nombres sont remplacés par des marques neutres.
   - Les suites d'environ 25 mots de code sont ensuite comparées.
   - Cet examen attrape le code renommé ou traduit ligne à ligne. Le seuil sera réglé avant le chantier.
6. **Tables.** Comparaison des identifiants uniques, et des lignes une fois leurs identifiants retirés. Une même âme sous un autre numéro compte comme une copie.
7. **Textes.**
   - Dans les 16 langues, comparaison exacte, puis normalisée (majuscules, ponctuation), puis par ressemblance (suites de 5 mots en commun).
   - Le seuil de ressemblance sera réglé avant le chantier.
8. **Sons, modèles, images.** Empreintes, noms, et références dans le code et les données.
9. **Arbres d'intelligence artificielle, quêtes, dialogues.** Comparaison de la suite des nœuds.
10. **Affichage.** 0 appel qui écrit directement à l'écran ailleurs que dans le bandeau, et 0 réglage de `mod.cfg` qui allume du texte de débogage. Cet examen bloque dès que le morceau 0 est scellé.

### Fonctionnement

- **Pendant le chantier : mode « suivi ».**
  - Il affiche les compteurs, et `tout_verifier.py` passe.
  - Il échoue seulement si un compteur augmente, ou si un morceau déclaré remplacé n'est pas à zéro.
- **À la fin : mode « strict ».** Tout compteur au-dessus de zéro fait échouer la vérification complète, donc bloque le commit.
- **Compte rendu en français**, par exemple : `Contrôle d'absence — fichiers 0 · chemins 0 · noms 0 · lignes 0 · forme 0 · tables 0 · textes 0 · sons/modèles/images 0 · structures 0 · affichage 0`.
- **Empreintes.**
  - Le contrôle peut travailler à partir d'un fichier qui ne contient que des empreintes, sans aucun contenu d'Alex.
  - La copie `mercenaires/` peut donc quitter le projet sans affaiblir le contrôle (décision D6).

### Limite à connaître

- Le contrôle prouve qu'il ne reste aucun fichier, aucune ligne, aucun nom et aucun texte d'Alex.
- Il ne prouve pas à lui seul que le code a été écrit de façon indépendante. C'est le rôle de la méthode : fiches, salle blanche et historique gardé.

---

## 9. Ce qui quitte le projet à la fin

Toutes ces suppressions se font avec l'accord de JoVenGer, donné juste avant.

- `mercenaires/` : la copie, avec `LISEZMOI.md` et `MODIFICATIONS.md`. Les 27 retouches vivent désormais comme règles dans les fiches.
- `noyau/mercenaires.py` et `mercenaires.comparer()`.
- Les passerelles et la reprise unique.
- La partie actuelle : on recommence sur une partie neuve. Garder ou non les anciennes sauvegardes, c'est à toi de décider.
- Rien n'est fait sur la copie de sécurité Scriptorium V2 (`D:\Scriptorium V2\Scriptorium`), sauf si tu le demandes.

---

## 10. Décisions à prendre par JoVenGer

| N° | Question | Recommandation |
|---|---|---|
| D1 | Le mot français « mercenaire » est-il permis dans les textes du jeu ? | L'éviter : « la Compagnie », « soudoyers », « hommes d'armes » |
| D2 | Voix : celles du jeu de base, pas de voix, ou des voix neuves ? | Répliques courtes du jeu de base, et menus du Directeur sans voix |
| D3 | Langues : le français seul au début ? | Oui ; les autres langues ensuite |
| D4 | Pendant le chantier : reprise unique des données de la partie actuelle, ou partie d'essai neuve ? | Reprise unique (les essais gardent le camp actuel), supprimée à la fin |
| D5 | Salle blanche stricte (la session qui écrit le code ne lit jamais `mercenaires/`) ou simple ? | Stricte |
| D6 | À la fin, la copie `mercenaires/` quitte le projet et le contrôle garde seulement les empreintes ? | Oui |
| D7 | Quelles nouveautés de la partie 7 garder ? | Toutes, dans l'ordre des morceaux |
| D8 | Bandeau des messages : aspect proposé (bande noire transparente à 80 %, texte blanc cassé, 2 lignes, de 3 à 8 secondes) et place en tête du chantier (morceau 0) ? | Oui, à ajuster après le premier essai en jeu |

---

## 11. À vérifier sur le PC ou dans le jeu, avant ou pendant l'inventaire

- Le nom de la table Lua actuelle de Scriptorium, et la place du dossier du socle selon les conventions du projet (`choses/`, sceaux).
- Le mécanisme de sauvegarde du jeu à utiliser pour le registre.
- Si le jeu accepte les accents dans les identifiants et les chemins.
- Les modèles du jeu de base pour la palissade, la porte et les tours.
- Si le jeu fournit les pavois et les arbalètes à un personnage non joueur.
- Si un dialogue peut se passer de voix.
- Ce que voit un joueur d'une autre langue quand un texte manque.
- Si le calendrier du jeu distingue le vendredi et le carême.
- D'où viennent exactement les textes jaunes : appels dans le code, ou réglage de `mod.cfg`.
- Comment le jeu permet d'afficher un texte libre en bas de l'écran : sous-titres du jeu, ou élément d'interface neuf.
- Ce que le veilleur lit aujourd'hui dans le journal du jeu.
