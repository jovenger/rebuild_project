"""Écrit les âmes du socle dans socle/pak/Libs/Tables/rpg/soul__scriptorium_socle.xml (fiche 13), et leur faction, « la
Compagnie », dans socle/pak/Libs/Tables/rpg/FactionTree__scriptorium_socle.xml (fiche 14).

Usage (sur le PC de JoVenGer) :
    py -3.13 outils/ames.py --jeu "G:\\SteamLibrary\\steamapps\\common\\KingdomComeDeliverance2"

Lit en lecture seule, dans <jeu>\\Data\\Tables.pak, les personnages génériques du jeu (table skald_character) et les
identifiants des âmes du jeu et l'arbre des factions ; n'écrit que la table des âmes et la table des factions du socle. Les âmes d'essai déjà présentes (marcheur,
brigand d'essai) sont gardées telles quelles ; les réserves sont réécrites, toujours à l'identique.

Les bandes (étape 2, le nécessaire, fiche 14) : une âme par sorte, copiée sur une âme réelle du jeu lue dans
Tables.pak (son cerveau d'ennemi, son personnage, sa classe, sa voix, son niveau de combat) ; seule la faction change :
« scriptorium_socle_bande », écrite elle aussi dans la table des factions du socle. Plusieurs ennemis d'une même bande
partagent son âme (vu en V18).

Une âme par personne vivante, jamais partagée (fiche 13, validée par JoVenGer le 15/10/2026). L'identifiant se calcule à
partir de la réserve, du palier et du numéro : la liaison Lua le refait sans liste (liaison.ame_de), et
essais/tout_verifier.py vérifie que la table et la liaison s'accordent. Un identifiant publié ne change jamais : un homme
enregistré renvoie à son âme.
"""

import os
import re
import sys
import zipfile

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TABLE = os.path.join(RACINE, "socle", "pak", "Libs", "Tables", "rpg", "soul__scriptorium_socle.xml")
TABLE_DES_FACTIONS = os.path.join(RACINE, "socle", "pak", "Libs", "Tables", "rpg", "FactionTree__scriptorium_socle.xml")

PREFIXE = "5c7a5c7a"
NOTRE_CERVEAU = "b8a850d0-47c6-44a1-872e-ce7efcf4b9f9"
# La faction de toutes les âmes des réserves : « la Compagnie » (fiche 14, réponse 1 a de JoVenGer du 16/10/2026), de
# premier niveau, sans étiquette (une faction sans « settlement » reçoit crime_skipInformationBroadcast, règle Storm
# contexts_disabledInformationBroadcast), sans lieu ni carte, avec exactement les relations de la faction du chien et du
# cheval d'Henry (animalCompanions, FactionTree.xml du jeu).
FACTION = "scriptorium_socle_compagnie"
COMMENTAIRE_DE_LA_FACTION = "Scriptorium socle : la Compagnie, amie d'Henry ; relations de animalCompanions"
RELATIONS = [
    ("player", "1"),
    ("players_friends", "1"),
    ("kutnohorsko_allies", "1"),
    ("trosecko_allies", "1"),
    ("players_enemies", "-1"),
    ("trosecko_enemies", "-1"),
    ("kutnohorsko_enemies", "-1"),
    ("kutnohorsko_enemies_oblehaniSuchdoleEnemyArmy", "-1"),
]

# Étape 2 (fiche 14) : la faction des bandes, à la forme des ennemis du jeu (Labels « publicEnemy », sans lieu ni carte,
# comme players_enemies « pour les deux cartes ») ; la Compagnie lui est hostile aussi (RELATIONS, plus bas). Comme les
# factions de brigands du jeu (kutnohorsko_enemies_bandits_campOpatovicko ne déclare qu'un allié), aucune relation vers
# le joueur : son hostilité envers Henry vient de l'étiquette « publicEnemy » (à vérifier en jeu).
FACTION_BANDE = "scriptorium_socle_bande"
COMMENTAIRE_BANDE = ("Scriptorium socle : les bandes qui attaquent le camp ; ennemie du joueur et de la Compagnie, "
                     "pour les deux cartes")
RELATIONS_BANDE = [
    ("players_friends", "-1"),
    (FACTION, "-1"),
    ("kutnohorsko_allies", "-1"),
    ("trosecko_allies", "-1"),
]
RELATIONS.append((FACTION_BANDE, "-1"))
# Une âme par sorte (les noms de bataille.sortes), et l'âme du jeu sur laquelle elle est copiée. Les identifiants sont
# ceux de liaison.ames_ennemies (code 5, palier 1, numéro dans l'ordre).
CODE_BANDE = 5
BANDES = [
    ("brigands", "bohutovaVlozka_bandit_3"),
    ("deserteurs", "krab_deserter_1"),
    ("soudards", "kvrc_lapka_1"),
    ("coumans", "bratriZCimburka_cuman_1"),
]
COPIES = ("brain_id", "combat_level", "digestion_multiplier", "initial_clothing_dirt", "skald_character_name",
          "social_class_id", "soul_archetype_id", "soul_vip_class_id", "voice_group_name", "xp_multiplier")

# Les réserves : code, nom des âmes, tailles par palier, personnages (familles du jeu), classe sociale, archétype,
# niveau de combat par palier. Les tailles doivent être celles de liaison.reserves_d_ames.
RESERVES = [
    {"reserve": "combattant", "code": 1, "paliers": [80, 80, 80], "familles": ["char_GENERIC_MAN_SOLDIER"],
     "classe": "33", "archetype": "0", "niveaux": ["0.3", "0.5", "0.7"]},
    {"reserve": "metier", "code": 2, "paliers": [40], "familles": ["char_GENERIC_MAN_COMMONER"],
     "classe": "1", "archetype": "0", "niveaux": [None]},
    {"reserve": "femme", "code": 3, "paliers": [12],
     "familles": ["char_GENERIC_WOMAN_COMMONER", "char_GENERIC_WOMAN_TOWNSWOMAN"],
     "classe": "1", "archetype": "1", "niveaux": [None]},
    # Le Directeur garde le personnage qu'il avait (extraGuards_dummy_6), avec la classe des soldats.
    {"reserve": "directeur", "code": 4, "paliers": [1], "personnages": ["char_GENERIC_MAN_GUARD_08"],
     "classe": "33", "archetype": "0", "niveaux": [None], "voix": "Guards"},
]


def identifiant(code, palier, numero):
    return "%s-%04x-4%03x-8000-%012x" % (PREFIXE, code, palier, numero)


def nom_de_l_ame(reserve, palier, numero, nb_paliers):
    if nb_paliers > 1:
        return "scriptorium_%s_%d_%02d" % (reserve, palier, numero)
    if reserve == "directeur":
        return "scriptorium_directeur"
    return "scriptorium_%s_%02d" % (reserve, numero)


def lire_le_jeu(jeu):
    chemin = os.path.join(jeu, "Data", "Tables.pak")
    with zipfile.ZipFile(chemin) as tables:
        personnages = tables.read("Libs/Tables/skald/skald_character.xml").decode("utf-8", "replace")
        ames = set()
        factions = set()
        modeles = {}
        voulus = {modele for _, modele in BANDES}
        for nom in tables.namelist():
            if re.search(r"libs/tables/rpg/soul(__[^/]+)?\.xml$", nom, re.I):
                texte = tables.read(nom).decode("utf-8", "replace")
                ames.update(i.lower() for i in re.findall(r'soul_id="([^"]+)"', texte))
                for balise in re.findall(r"<soul\s[^>]*>", texte):
                    attributs = dict(re.findall(r'(\w+)="([^"]*)"', balise))
                    if attributs.get("soul_name") in voulus:
                        modeles[attributs["soul_name"]] = attributs
            if re.search(r"libs/tables/rpg/factiontree(__[^/]+)?\.xml$", nom, re.I):
                texte = tables.read(nom).decode("utf-8", "replace")
                factions.update(re.findall(r'<Faction\s[^>]*?Name="([^"]+)"', texte))
    return set(re.findall(r'skald_character_name="([^"]+)"', personnages)), ames, factions, modeles


def texte_des_factions(fin):
    """La table des factions du socle, sur l'enveloppe des ajouts du jeu (FactionTree__tests.xml, FactionTree.xsd)."""
    lignes = [
        '<?xml version="1.0" encoding="us-ascii"?>',
        '<database xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" name="barbora" '
        'xsi:noNamespaceSchemaLocation="FactionTree.xsd">',
        '  <FactionTree version="1">',
        '    <Faction Name="%s" Comment="%s">' % (FACTION, COMMENTAIRE_DE_LA_FACTION),
        "      <Relations>",
    ]
    for cible, reputation in RELATIONS:
        lignes.append('        <Relation target="%s" reputation="%s" />' % (cible, reputation))
    lignes += ["      </Relations>", "    </Faction>"]
    lignes += ['    <Faction Name="%s" Comment="%s" Labels="publicEnemy">' % (FACTION_BANDE, COMMENTAIRE_BANDE),
               "      <Relations>"]
    for cible, reputation in RELATIONS_BANDE:
        lignes.append('        <Relation target="%s" reputation="%s" />' % (cible, reputation))
    lignes += ["      </Relations>", "    </Faction>", "  </FactionTree>", "</database>", ""]
    return fin.join(lignes)


def lignes_des_bandes(modeles, personnages):
    lignes = []
    for numero, (sorte, modele) in enumerate(BANDES, start=1):
        m = modeles.get(modele)
        if m is None:
            raise SystemExit("REFUS : âme modèle introuvable dans le jeu : " + modele)
        if m.get("skald_character_name") not in personnages:
            raise SystemExit("REFUS : personnage introuvable dans le jeu : " + str(m.get("skald_character_name")))
        a = {cle: m[cle] for cle in COPIES if cle in m}
        a["factionName"] = FACTION_BANDE
        a["soul_id"] = identifiant(CODE_BANDE, 1, numero)
        a["soul_name"] = "scriptorium_bande_" + sorte
        lignes.append(ligne(a))
    return lignes


def ecrire_si_change(chemin, texte, quoi):
    texte.encode("ascii")
    ancien = None
    if os.path.isfile(chemin):
        with open(chemin, "r", encoding="ascii", newline="") as fichier:
            ancien = fichier.read()
    if ancien == texte:
        print("%s : déjà à jour" % quoi)
        return
    with open(chemin, "w", encoding="ascii", newline="") as fichier:
        fichier.write(texte)
    print("%s écrite" % quoi)


def palette(personnages, familles):
    liste = []
    for famille in familles:
        liste.extend(sorted(p for p in personnages if re.fullmatch(re.escape(famille) + r"_\d+", p)))
    return liste


def ligne(attributs):
    return "    <soul " + " ".join('%s="%s"' % (cle, attributs[cle]) for cle in sorted(attributs)) + " />"


def lignes_des_reserves(personnages):
    lignes = []
    for r in RESERVES:
        choix = r.get("personnages") or palette(personnages, r["familles"])
        if not choix:
            raise SystemExit("REFUS : aucun personnage du jeu pour la réserve " + r["reserve"])
        for p in choix:
            if p not in personnages:
                raise SystemExit("REFUS : personnage introuvable dans le jeu : " + p)
        rang = 0
        for palier, taille in enumerate(r["paliers"], start=1):
            for numero in range(1, taille + 1):
                a = {
                    "brain_id": NOTRE_CERVEAU,
                    "digestion_multiplier": "0",
                    "factionName": FACTION,
                    "initial_clothing_dirt": "0",
                    "skald_character_name": choix[rang % len(choix)],
                    "social_class_id": r["classe"],
                    "soul_archetype_id": r["archetype"],
                    "soul_id": identifiant(r["code"], palier, numero),
                    "soul_name": nom_de_l_ame(r["reserve"], palier, numero, len(r["paliers"])),
                    "soul_vip_class_id": "0",
                    "xp_multiplier": "0",
                }
                if r["niveaux"][palier - 1] is not None:
                    a["combat_level"] = r["niveaux"][palier - 1]
                if r.get("voix"):
                    a["voice_group_name"] = r["voix"]
                lignes.append(ligne(a))
                rang += 1
    return lignes


def principal(arguments):
    if "--jeu" not in arguments or arguments.index("--jeu") + 1 >= len(arguments):
        print(__doc__)
        return 2
    jeu = arguments[arguments.index("--jeu") + 1]
    if not os.path.isfile(os.path.join(jeu, "Data", "Tables.pak")):
        print("REFUS : Tables.pak introuvable sous " + jeu)
        return 2
    personnages, ames_du_jeu, factions_du_jeu, modeles = lire_le_jeu(jeu)
    pris = sorted(i for i in ames_du_jeu if i.startswith(PREFIXE))
    if pris:
        print("REFUS : le préfixe %s est déjà pris par le jeu : %s" % (PREFIXE, ", ".join(pris[:5])))
        return 1
    if len(factions_du_jeu) < 1000:
        print("REFUS : arbre des factions du jeu illisible (%d factions lues)" % len(factions_du_jeu))
        return 1
    for nom in (FACTION, FACTION_BANDE):
        if nom in factions_du_jeu:
            print("REFUS : la faction %s existe déjà dans le jeu" % nom)
            return 1
    absentes = [cible for cible, _ in RELATIONS + RELATIONS_BANDE
                if cible not in factions_du_jeu and cible not in (FACTION, FACTION_BANDE)]
    if absentes:
        print("REFUS : relation vers une faction absente du jeu : " + ", ".join(absentes))
        return 1
    with open(TABLE, "r", encoding="ascii", newline="") as fichier:
        texte = fichier.read()
    fin = "\r\n" if "\r\n" in texte else "\n"
    anciennes = texte.split(fin)
    # Les âmes d'essai (hors réserves) sont gardées telles quelles, dans leur ordre.
    gardees = [l for l in anciennes if "<soul " in l and ('soul_id="' + PREFIXE) not in l]
    neuves = lignes_des_reserves(personnages) + lignes_des_bandes(modeles, personnages)
    tete = [l for l in anciennes if "<soul " not in l and "</souls>" not in l and "</database>" not in l and l.strip()]
    sortie = tete + gardees + neuves + ["  </souls>", "</database>", ""]
    nouveau = fin.join(sortie)
    nouveau.encode("ascii")
    ecrire_si_change(TABLE_DES_FACTIONS, texte_des_factions(fin), "Table des factions (%s, %d relations)" % (FACTION, len(RELATIONS)))
    if nouveau == texte:
        print("Table des âmes : déjà à jour (%d âmes d'essai, %d âmes des réserves)" % (len(gardees), len(neuves)))
        return 0
    with open(TABLE, "w", encoding="ascii", newline="") as fichier:
        fichier.write(nouveau)
    print("Table des âmes écrite : %d âmes d'essai gardées, %d âmes des réserves" % (len(gardees), len(neuves)))
    return 0


if __name__ == "__main__":
    sys.exit(principal(sys.argv[1:]))
