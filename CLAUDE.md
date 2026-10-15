# Règles de travail — Yann (jovenger)

Ce fichier est chargé automatiquement au début de chaque session. Ces règles s'appliquent à tout le travail dans ce dépôt.

## Style de réponse
- En français. Direct, technique, concis, listes à puces.
- Pas d'introduction, pas de formules de politesse, pas de conclusion superflue.
- Synthèse courte d'abord, détail seulement sur demande.

## Règles absolues
- **Jamais de faux succès.** Ne jamais annoncer « ça marche » ou « corrigé » sans test réellement exécuté. Sinon, écrire « non vérifié » avec la raison.
- **Rapidité prioritaire.** Signaler tout choix qui ajoute latence, dépendance lourde ou complexité.
- **Logging exhaustif.** Logs avec niveau, horodatage et module sur chaque étape importante. Ne jamais supprimer de logs existants.
- **Lire avant de modifier.** Diff minimal plutôt que réécriture complète. Pas de refactoring non demandé.
- **Doc à jour.** Pour toute librairie, API ou outil (moteur de jeu, framework de modding, Python…), vérifier la doc actuelle (Context7 si disponible) plutôt que de se fier à la mémoire.

## Rapidité (éviter la latence)
- Gros fichiers : Grep d'abord, puis Read avec offset/limit sur la zone utile. Jamais de lecture complète inutile.
- Regrouper les lectures et commandes indépendantes dans le même tour.
- Ne pas relire un fichier qu'on vient d'éditer sans raison.
- Recherche large (plusieurs fichiers ou dossiers) : déléguer à un sous-agent Explore et ne garder que la conclusion.
- Commandes longues : en arrière-plan avec timeout, ne jamais bloquer en attente.
- Session longue : proposer `/compact` quand le contexte devient lourd.

## Anti-boucle (obligatoire)
- 2 échecs avec la même approche → STOP. Pas de 3e variante du même correctif.
- Repartir du diagnostic : relire l'erreur exacte, tester une hypothèse différente.
- Si toujours bloqué : rapport court à Yann (essayé / observé / hypothèses restantes / ce qu'il faut de lui) et attendre.
- Interdit : relancer la même commande en espérant un autre résultat, élargir le correctif à l'aveugle.

## Sûreté
- Avant une modification importante : vérifier qu'un commit existe. Sinon, en proposer un.
- Aucune commande destructive (suppression, écrasement, `git reset --hard`, `git push --force`, `rm -rf`) sans confirmation explicite.
- Jamais de secrets (clés API, mots de passe, tokens) en dur : `.env` + `.gitignore`.
- Valider les entrées externes (fichiers, réseau, saisie). Gérer les exceptions avec un log explicite, jamais de `except: pass` ni d'erreur avalée en silence.
- Pas de nouvelle dépendance sans le signaler. Versions épinglées.
- Pour les mods de jeu : ne jamais modifier les fichiers originaux du jeu ; travailler sur des copies ou dans le dossier de mod, et garder une sauvegarde.

## Vérification (aller aussi loin que possible, et dire où on s'est arrêté)
1. Syntaxe / compilation / chargement du fichier.
2. Lint si disponible.
3. Exécution réelle du chemin modifié.
4. Test ciblé ou script de reproduction.

## Débogage
Collecter (erreur complète, logs, ce qui a changé) → reproduire → 2 à 4 hypothèses classées → tester la plus probable avec la preuve la moins coûteuse → correctif minimal sur la cause racine → rejouer la reproduction → ajouter un garde-fou (log, assertion, test).
Interdits : masquer l'erreur, changer plusieurs choses à la fois, dire « corrigé » sans rejouer.
Pièges fréquents sous Windows : encodage (UTF-8 vs cp1252), chemins avec espaces ou accents, mauvais environnement Python, fichier verrouillé par une autre instance.

## Performance
Mesurer avant d'optimiser (`time.perf_counter()`, profiler). Cibler l'étape la plus lente, une optimisation à la fois, re-mesurer, donner le gain en ms. Ne jamais sacrifier fiabilité ou logs pour quelques millisecondes.

## Fin de chaque tâche
- Fait / testé / non testé / en attente.
- Régressions possibles.
- Liste à jour des points en attente.
