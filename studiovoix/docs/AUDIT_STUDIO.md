# Audit : ce qu'il manque à StudioVoix pour être un vrai programme de studio

État au build 36 (octobre 2026). Constat honnête : ce qui existe, ce qui manque par rapport à un studio
(Samplitude, Pro Tools, Logic, Studio One, et aux services « automatiques » type iZotope Neutron / Nectar,
Auphonic, Sonible smart:comp), pourquoi, et comment le faire. Les points sont classés par importance pour
Yann : enregistrer une voix sur une instru, obtenir un son propre et au bon niveau sans régler à la main.

## 1. Ce qui existe déjà (pour cadrer)

- Enregistrement multi-prises, punch-in, compte à rebours, métronome, recalage de latence, pistes armées.
- Chaîne voix complète par style (33 styles) : nettoyage, niveleur, autotune, EQ, résonances, 2 compresseurs,
  de-esser, saturation, réverb, délai. Positions des curseurs réelles par style (build 36).
- Ingénieur du son automatique par piste : analyse (niveau, crête, écrêtage, continu, bruit, boue, dureté,
  sifflantes, justesse, montées brusques, résonances, type d'instrument), correction mesurée, rapport.
- Mix auto (voix / instru, creux sous la voix), mastering par plateforme, export + stems.
- Effets intégrés en insert, plugins VST3, génération de doublages / backs / harmonies / ad-libs.
- Alertes : piste qui sature, qui monte en flèche, plus forte que la voix principale.

## 2. Les automatismes : comment ils doivent être faits (règle générale)

Un bon réglage automatique, c'est toujours la même boucle : **mesurer → viser une cible → borner → lisser →
expliquer**. Un automatisme qui « met tout à 0,5 » ne mesure rien : il ne peut pas être juste.

| Automatisme | Mesure | Cible | Borne | Lissage | État dans StudioVoix |
|---|---|---|---|---|---|
| Niveau d'entrée (gain staging) | RMS des passages actifs | −20 dBFS | ±30 dB | aucun (gain fixe) | fait |
| Niveleur (fader suivi) | RMS 400 ms | −20 dBFS, médiane de la piste | ±4 dB (style), ±8 dB (correction), −12 à −18 dB sur une montée brusque | attaque 250 ms, relâche 1,2 s | fait (build 36) |
| Compresseur | niveau crête / RMS | seuil par style, 4 à 7 dB de réduction | ratio ≤ 8 | attaque / relâche par style | fait, mais **le seuil n'est pas adapté au niveau mesuré** → à faire : seuil = niveau médian − X dB |
| De-esser | 5–9 kHz vs 1–4 kHz | sifflantes ≤ médium | max 6 dB | 2 ms / 60 ms | fait (dosé en correction, fixe dans les styles) |
| EQ corrective | spectre par tiers d'octave vs courbe attendue | boue ≤ médium, dureté ≤ médium − 3 dB | ±6 dB | – | fait en correction ; **pas dans les styles** → à faire : correction mesurée puis EQ de style par-dessus |
| Résonances | bande vs voisines et vs son niveau habituel | dépassement ≤ 3–6 dB | max 3 à 9 dB | 10 / 80 ms | fait (build 36) |
| Autotune | hauteur vs gamme | note la plus proche | quantité par style | vitesse par style | fait ; **la tonalité détectée doit être confirmée** (voir 3.4) |
| Mix voix / instru | LUFS voix et instru | voix X LU au-dessus de l'instru (par style) | ±6 dB | – | fait |
| Creux sous la voix | spectre de la voix | −3 à −6 dB à 1–4 kHz sur l'instru quand la voix chante | – | 20 / 200 ms | fait |
| Mastering | LUFS intégré, crête vraie | −14 LUFS / −1 dBTP (plateforme) | – | limiteur 5 ms | fait |
| Équilibre entre toutes les pistes (backs, ad-libs, instruments) | LUFS de chaque piste | hiérarchie par rôle (voix −0, doublages −6, backs −8, ad-libs −10, instrument −4 LU…) | ±3 dB | – | **manque** : seuls voix / instru sont équilibrés ; les autres pistes dépendent du réglage du style |
| Masquage entre pistes | spectre de chaque piste vs les autres | pas deux pistes qui occupent la même bande au même moment | ±3 dB | – | **manque** (seul l'instru est creusée sous la voix) |

## 3. Ce qui manque, par ordre d'importance

### 3.1 Mixage automatique de toutes les pistes (pas seulement voix / instru)
Aujourd'hui l'équilibre automatique concerne la voix principale et l'instru. Les doublages, backs, ad-libs,
instruments enregistrés gardent le niveau de leur style, sans mesure. Un studio fait : sonie de chaque piste
mesurée → gain par rôle (hiérarchie ci-dessus) → vérification du total (pas de saturation du bus) →
rapport. À faire en une passe après les rendus (comme les alertes) : `mix::balanceAll`.

### 3.2 Édition des blocs
Manque : couper (ciseaux), scinder, rogner les bords, fondus d'entrée / sortie, fondu enchaîné entre deux
blocs, copier / coller, déplacer d'une piste à l'autre, zoom à la molette sur la zone, sélection d'une zone
temporelle. Un studio n'est pas utilisable sans couper une respiration ou un début raté. La structure
existe (prises avec regionStart / regionEnd, déplacement) ; il faut les gestes et les fondus (5–20 ms).

### 3.3 Automation (courbes)
Volume, panoramique, envoi réverb dessinés dans le temps par piste. Le niveleur remplace l'automation de
volume pour l'essentiel, mais un studio veut aussi « plus de réverb sur ce mot », « couper le délai sur ce
couplet ». À faire : courbes à points par paramètre, appliquées au rendu (interpolation linéaire), dessinées
sur la piste.

### 3.4 Tonalité et tempo confirmés
L'autotune dépend de la tonalité détectée ; si elle est fausse, tout est faux (« vagues », notes tirées).
Manque : affichage clair de la tonalité et du tempo détectés avec leur confiance, validation en un clic,
choix manuel (menu), détection relancée sur une zone choisie. Les erreurs connues de tempo (double / moitié)
sont listées dans A_FAIRE.md.

### 3.5 Écoute en temps réel de la chaîne
Le rendu est hors temps réel : on entend le résultat après le traitement, pas pendant la prise. Un studio
donne le retour casque avec au moins réverb + compression légère (latence < 10 ms). À faire : version
temps réel allégée (EQ, compresseur, réverb courte) dans le moteur audio, sans autotune.

### 3.6 Mesures visibles
Manque : vumètres par piste (crête + RMS) en lecture, sonie du mix (LUFS court terme / intégré) en direct,
analyseur de spectre, indicateur de saturation qui reste allumé. Les mesures existent dans le code ; il
manque l'affichage.

### 3.7 Éditeur de justesse manuel
Après l'autotune automatique, pouvoir voir les notes (blocs) et en corriger une à la main (monter / baisser
d'un demi-ton, redresser, laisser une note volontairement fausse). Le suivi de hauteur existe (PitchTrack) ;
il manque la vue et l'édition.

### 3.8 Prises : vrai comping
« Meilleure prise par phrase » choisit une prise par créneau mais, avec des prises complètes qui se
recouvrent, une seule gagne tout. Il manque les couches de prises visibles sous la piste et le choix à la
souris d'un morceau de chaque prise (comping manuel), avec fondus.

### 3.9 Routage : bus et envois partagés
Chaque piste a sa réverb ; un studio envoie toutes les voix vers une même réverb (cohérence, moins de
calcul) et groupe les backs dans un bus avec sa compression. À faire : bus « Voix », « Backs »,
« Instruments », retour réverb commun, compression de bus.

### 3.10 Séparation de stems
Pour corriger une instru mixée (basse qui monte, batterie qui sature), le studio la sépare d'abord
(voix / batterie / basse / reste) puis traite chaque partie. Lourd (modèle Demucs, ~1 Go, GPU conseillé) :
à décider. Sans séparation, la correction d'instru stéréo liée (build 36) reste globale.

### 3.11 Petits manques d'usage
- Nommer une piste par double-clic (existe), couleur de piste au choix (manque).
- Raccourcis : couper, scinder, zoom, aller au marqueur précédent / suivant (manquent).
- Importer plusieurs fichiers d'un coup au bon endroit (existe pour le glisser-déposer).
- Annuler pour volume / pan / muet / solo (manque, listé dans A_FAIRE.md).
- Sauvegarde des réglages d'export par projet (manque).

## 4. Ce qui a été corrigé au build 36 à la suite des remarques de Yann

- Curseurs par style : positions réelles (fin du « tout à 0,5 ») ; chaque style a son autotune, sa présence,
  son espace, son énergie ; double-clic = position du style.
- Voix qui monte en flèche : détectée, horodatée, rabaissée ; alerte dans l'en-tête de piste.
- Piste qui sature ou plus forte que la voix principale : signalée.
- Instru corrigeable (analyse + réparation stéréo liée).
- Largeur des en-têtes et hauteur des pistes réglables à la souris, mémorisées.

## 5. Ordre proposé

1. Mixage automatique de toutes les pistes (3.1) et seuil de compression adapté au niveau mesuré (§ 2).
2. Édition des blocs avec fondus (3.2) et tonalité / tempo confirmés (3.4).
3. Vumètres et sonie en direct (3.6), alertes déjà en place.
4. Automation (3.3), comping manuel (3.8), bus et envois partagés (3.9).
5. Écoute temps réel (3.5), éditeur de justesse (3.7), séparation de stems (3.10, à décider).
