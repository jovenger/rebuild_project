# Fiche 20 — Les paroles des hommes (répliques, conversations, dialogue vers Henry)

Source : la demande du pair (17/10) : deux choses de Scriptorium qui marchent aujourd'hui passent par des globales du
mod d'Alex (principe seulement) : un homme dit une ligne de dialogue de Scriptorium (ses alias « scr_… »), et deux
hommes se parlent ; l'arbre de chaque homme lit une demande posée pour lui, la joue une fois, puis l'efface. Formes
réelles des nœuds, relevées dans les arbres du jeu (`Scripts.pak`, lecture seule) : `AI/battle/battleLadderController.xml`
et `AI/carts/carts.xml` ; définitions dans `AI/speech/schedulermonolog.xml`, `schedulerpolylog_initiator.xml`,
`dialoginitiator.xml`.

Comportement :
- `hommes.dire_une_replique(id, { alias | metarole, regard_henry })` : `Function_speech_schedulerMonolog` (alias, ou
  metarole sans alias ; l'animation de dialogue coupée ; regard vers Henry si demandé).
- `hommes.conversation(id, partenaire, { alias | metarole })` : `Function_speech_schedulerPolylog_initiator`,
  l'initiateur et son partenaire (un autre homme de la Compagnie).
- `hommes.dialogue_force(id, alias)` : `Function_speech_dialogInitiator`, un dialogue du jeu vers Henry.
- La demande devient l'activité « parole » (ordre 23) : l'arbre la joue une fois, compte une parole jouée, et l'homme
  reprend sa journée au battement suivant. Une demande nouvelle remplace la précédente.
- **Jamais en combat, en bataille ni au lit** : la décision remplaçable `hommes.peut_parler(id, parole)` (par défaut :
  ni occupé en combat, ni tenu par la bataille, ni au sommeil) ; sinon la demande attend. Une demande qui attend plus de
  `parole_attente_max_h` heures du jeu est oubliée (une ligne au journal).
- Une demande n'est pas gardée au registre (une parole n'a de sens que sur le moment).
- Réponses prises d'office : une seule demande à la fois par homme ; la conversation se joue depuis l'initiateur seul (le
  jeu y fait entrer le partenaire).
