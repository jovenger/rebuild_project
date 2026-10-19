"""Écrit les âmes du socle dans socle/pak/Libs/Tables/rpg/soul__scriptorium_socle.xml (fiche 13), et leur faction, « la
Compagnie », dans socle/pak/Libs/Tables/rpg/FactionTree__scriptorium_socle.xml (fiche 14).

Usage (sur le PC de JoVenGer) :
    py -3.13 outils/ames.py --jeu "G:\\SteamLibrary\\steamapps\\common\\KingdomComeDeliverance2"
    py -3.13 outils/ames.py --jeu "…" --releve <relevé JSON des hommes de Scriptorium>
        (la bascule : une âme faite pour chacun des hommes de JoVenGer, avec son nom ; la liste est gardée dans
        liaison.lua, entre les repères de la reprise, et relue à chaque passage sans --releve)

Lit en lecture seule, dans <jeu>\\Data\\Tables.pak, les personnages génériques du jeu (table skald_character) et les
identifiants des âmes du jeu et l'arbre des factions ; n'écrit que la table des âmes et la table des factions du socle. Les âmes d'essai déjà présentes (marcheur,
brigand d'essai) sont gardées telles quelles ; les réserves sont réécrites, toujours à l'identique.

Les bandes (étape 2, le nécessaire, fiche 14) : une âme par sorte, copiée sur une âme réelle du jeu lue dans
Tables.pak (son personnage, sa classe, sa voix, son niveau de combat) ; la faction change, et le cerveau est le nôtre
(règle scellée de Scriptorium « ennemis_au_contact » : une bande ne reste jamais sur place ; c'est notre ordre d'attaque
qui la fait venir, comme nos hommes) :
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
# Chaque homme son nom (décision de JoVenGer, 18/10, transmise par le pair) : un personnage du jeu à nous par âme des
# réserves (copie du personnage générique tiré, avec la clé de son nom affiché), et le texte de cette clé. Vu en jeu le
# 18/10 : le nom s'affiche au-dessus de la tête, et le visage suit l'âme, pas le personnage (aucun visage perdu).
TABLE_DES_PERSONNAGES = os.path.join(RACINE, "socle", "pak", "Libs", "Tables", "skald", "skald_character__scriptorium_socle.xml")
TEXTES_DES_NOMS = os.path.join(RACINE, "socle", "textes", "fr", "text_ui_soul__scriptorium_socle.xml")
HOMMES_LUA = os.path.join(RACINE, "socle", "pak", "Scripts", "scriptorium", "hommes.lua")
RESERVES_NOMMEES = ("combattant", "metier", "femme", "compagnon", "directeur")
# La reprise des hommes de JoVenGer (demande du pair, 18/10) : réserve « reprise », code 8, un palier ; la liste gardée
# dans la liaison (la même source que le jeu).
LIAISON = os.path.join(RACINE, "socle", "pak", "Scripts", "scriptorium", "liaison.lua")
DEBUT_REPRISE = "-- DÉBUT DE LA REPRISE (écrit par outils/ames.py ; ne pas modifier à la main)"
FIN_REPRISE = "-- FIN DE LA REPRISE"
CODE_REPRISE = 8
PALIERS_DU_RELEVE = {"weak": 1, "medium": 2, "strong": 3}
NIVEAUX_DE_LA_REPRISE = {1: "0.3", 2: "0.5", 3: "0.7"}

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
# Pas de jumeaux (demande du pair, 18/10 : « le camp ne doit pas être peuplé de jumeaux ») : le visage suit le personnage
# du jeu ; trois palettes sans personnage commun, le plus de visages possible par réserve (personnages génériques de
# skald_character.xml) : combattants 71, gens de métier 50, femmes 30 ; le personnage du Directeur hors des palettes.
# Le personnage d'une âme est le visage numéro (rang mod visages), rang compté sur tous les paliers de la réserve : la
# liaison le refait sans liste (liaison.visage_de), et le tirage écarte un visage déjà présent au camp.
RESERVES = [
    {"reserve": "combattant", "code": 1, "paliers": [80, 80, 80],
     "familles": ["char_GENERIC_MAN_SOLDIER", "char_GENERIC_MAN_GUARD", "char_GENERIC_MAN_ENEMY_BANDIT",
                  "char_GENERIC_MAN_TOWNSMAN", "char_GENERIC_MAN_GERMAN", "char_GENERIC_MAN_CUMAN"],
     "exclus": ["char_GENERIC_MAN_GUARD_08"],
     "classe": "33", "archetype": "0", "niveaux": ["0.3", "0.5", "0.7"]},
    {"reserve": "metier", "code": 2, "paliers": [50],
     "familles": ["char_GENERIC_MAN_COMMONER", "char_GENERIC_MAN_MINER", "char_GENERIC_MAN_GAMEKEEPER",
                  "char_GENERIC_MAN_MERCHANT_CZECH", "char_GENERIC_MAN_MERCHANT_GERMAN",
                  "char_GENERIC_MAN_MARKET_COALMAN_CZECH", "char_GENERIC_MAN_MARKET_POTTER_GERMAN"],
     "classe": "1", "archetype": "0", "niveaux": [None]},
    {"reserve": "femme", "code": 3, "paliers": [30],
     "familles": ["char_GENERIC_WOMAN_COMMONER", "char_GENERIC_WOMAN_TOWNSWOMAN", "char_GENERIC_WOMAN_MERCHANT_CZECH",
                  "char_GENERIC_WOMAN_GERMAN", "char_GENERIC_WOMAN_MARKET_POTTER_CZECH", "char_GENERIC_WOMAN_ROMA",
                  "char_GENERIC_WOMAN_MARKET_POTTER_GERMAN", "char_GENERIC_WOMAN_MERCHANT_GERMAN"],
     "classe": "1", "archetype": "1", "niveaux": [None]},
    # Le Directeur garde le personnage qu'il avait (extraGuards_dummy_6), avec la classe des soldats.
    {"reserve": "directeur", "code": 4, "paliers": [1], "personnages": ["char_GENERIC_MAN_GUARD_08"],
     "classe": "33", "archetype": "0", "niveaux": [None], "voix": "Guards"},
    # Les 31 compagnons nommés (demande du pair, liste validée par JoVenGer le 18/10, Scriptorium
    # docs/socle/COMPAGNONS.md) : une âme chacun, numéro = rang dans la liste (hommes.compagnons_nommes), un visage
    # fixe pris hors des trois palettes (aucun jumeau avec les hommes ordinaires ni entre eux), classe des soldats,
    # niveau du palier 3. Code 7 (le code 6 est celui des rôles, outils/dialogues.py). L'âge suit le surnom quand il y
    # en a un (le Vieux, le Chevalier déchu : âgés ; le Chauve : un prêtre ; Ulrich der Rote : la voix allemande).
    {"reserve": "compagnon", "code": 7, "paliers": [31], "personnages": [
        "char_GENERIC_MAN_ROMA_01", "char_GENERIC_MAN_ROMA_02", "char_GENERIC_MAN_NOBLEMAN_01",
        "char_GENERIC_MAN_JEW_03", "char_GENERIC_MAN_PRIEST_02", "char_GENERIC_MAN_NOBLEMAN_04",
        "char_GENERIC_MAN_MARKET_POTTER_CZECH_01", "char_GENERIC_MAN_PRIEST_01", "char_GENERIC_MAN_NOBLEMAN_11",
        "char_GENERIC_MAN_MERCHANT_JEW_01", "char_GENERIC_MAN_NOBLEMAN_07", "char_GENERIC_MAN_ROMA_03",
        "char_GENERIC_MAN_JEW_04", "char_GENERIC_MAN_NOBLEMAN_03", "char_GENERIC_MAN_PRIEST_06",
        "char_GENERIC_MAN_NOBLEMAN_08", "char_GENERIC_MAN_PRIEST_03", "char_GENERIC_MAN_MERCHANT_ROMANI_01",
        "char_GENERIC_MAN_NOBLEMAN_05", "char_GENERIC_MAN_NOBLEMAN_10", "char_GENERIC_MAN_PRIEST_07",
        "char_GENERIC_MAN_JEW_02", "char_GENERIC_MAN_MERCHANT_JEW_03", "char_GENERIC_MAN_PRIEST_09",
        "char_GENERIC_MAN_NOBLEMAN_09", "char_GENERIC_MAN_PRIEST_08", "char_GENERIC_MAN_JEW_01",
        "char_GENERIC_MAN_MERCHANT_JEW_02", "char_GENERIC_MAN_PRIEST_04", "char_GENERIC_MAN_NOBLEMAN_06",
        "char_GENERIC_MAN_NOBLEMAN_12"],
     "classe": "33", "archetype": "0", "niveaux": ["0.7"]},
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
        fiches = {}
        for balise in re.findall(r"<skald_character\s[^>]*>", personnages):
            attributs = dict(re.findall(r'(\w+)="([^"]*)"', balise))
            fiches[attributs.get("skald_character_name")] = attributs
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
    return set(re.findall(r'skald_character_name="([^"]+)"', personnages)), ames, factions, modeles, fiches


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
        a["brain_id"] = NOTRE_CERVEAU
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
        choix = r.get("personnages") or [p for p in palette(personnages, r["familles"]) if p not in r.get("exclus", [])]
        if not choix:
            raise SystemExit("REFUS : aucun personnage du jeu pour la réserve " + r["reserve"])
        for p in choix:
            if p not in personnages:
                raise SystemExit("REFUS : personnage introuvable dans le jeu : " + p)
        print("  réserve %s : %d visages" % (r["reserve"], len(choix)))
        if len(set(choix)) != len(choix):
            raise SystemExit("REFUS : un visage deux fois dans la réserve " + r["reserve"])
        for autre in RESERVES:
            if autre is not r:
                autres = autre.get("personnages") or palette(personnages, autre["familles"])
                commun = sorted(set(choix) & set(autres))
                if commun and r["reserve"] == "compagnon":
                    raise SystemExit("REFUS : visage de compagnon déjà pris par la réserve %s : %s" % (autre["reserve"], commun[0]))
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


def listes_de_hommes_lua():
    """Les listes de noms de hommes.lua (la même source que le jeu) : prénoms, surnoms, ceux des femmes, compagnons."""
    with open(HOMMES_LUA, "r", encoding="utf-8") as f:
        texte = f.read()

    def liste(nom):
        bloc = re.search(r"^hommes\.%s = \{(.*?)\}" % nom, texte, re.S | re.M)
        if not bloc:
            raise SystemExit("REFUS : liste hommes.%s introuvable dans hommes.lua" % nom)
        return re.findall(r'"([^"]+)"', bloc.group(1))
    bloc = texte.split("\nhommes.compagnons = {", 1)[1].split("\n}", 1)[0]
    compagnons = re.findall(r'^  \{ nom = "([^"]+)"', bloc, re.M)
    directeur = re.findall(r'^hommes\.nom_du_directeur = "([^"]+)"', texte, re.M)
    if len(directeur) != 1:
        raise SystemExit("REFUS : hommes.nom_du_directeur introuvable ou en double dans hommes.lua")
    return (liste("prenoms"), liste("surnoms"), liste("prenoms_de_femmes"), liste("surnoms_de_femmes"), compagnons,
            directeur[0])


def nom_combine(prenoms, surnoms, i):
    """hommes.nom_d_epoque et hommes.nom_de_femme, à l'identique."""
    np, ns = len(prenoms), len(surnoms)
    a, b = np, ns
    while b:
        a, b = b, a % b
    tranche = np * ns // a
    k = (i - 1) % (np * ns)
    decalage, reste = k // tranche, k % tranche
    return prenoms[reste % np] + " " + surnoms[(reste + decalage) % ns]


def noms_des_reserves(reprise=()):
    """soul_name -> nom affiché, pour les réserves nommées et la reprise ; même calcul que hommes.nom_de_l_ame. Deux
    âmes des réserves n'ont jamais le même nom ; ceux de la reprise sont les noms de JoVenGer, tels quels."""
    prenoms, surnoms, prenoms_f, surnoms_f, compagnons, directeur = listes_de_hommes_lua()
    noms = {}
    combattants = sum(sum(r["paliers"]) for r in RESERVES if r["reserve"] == "combattant")
    for r in RESERVES:
        if r["reserve"] not in RESERVES_NOMMEES:
            continue
        rang = 0
        for palier, taille in enumerate(r["paliers"], start=1):
            for numero in range(1, taille + 1):
                ame = nom_de_l_ame(r["reserve"], palier, numero, len(r["paliers"]))
                if r["reserve"] == "combattant":
                    noms[ame] = nom_combine(prenoms, surnoms, rang + 1)
                elif r["reserve"] == "metier":
                    noms[ame] = nom_combine(prenoms, surnoms, combattants + rang + 1)
                elif r["reserve"] == "femme":
                    noms[ame] = nom_combine(prenoms_f, surnoms_f, rang + 1)
                elif r["reserve"] == "directeur":
                    noms[ame] = directeur
                else:
                    if rang >= len(compagnons):
                        raise SystemExit("REFUS : plus d'âmes de compagnon que de compagnons dans hommes.lua")
                    noms[ame] = compagnons[rang]
                rang += 1
    vus, doubles = set(), set()
    for n in noms.values():
        if n in vus:
            doubles.add(n)
        vus.add(n)
    if doubles:
        raise SystemExit("REFUS : noms en double : " + ", ".join(sorted(doubles)[:5]))
    for numero, (_, nom, _) in enumerate(reprise, start=1):
        noms["scriptorium_reprise_%03d" % numero] = nom
    return noms


def ecrire_les_personnages(lignes_des_ames, fiches, fin, reprise=()):
    """Chaque âme d'une réserve nommée pointe vers son personnage ; rend les lignes d'âmes réécrites."""
    noms = noms_des_reserves(reprise)
    personnages, textes, sorties = [], [], []
    for l in lignes_des_ames:
        a = dict(re.findall(r'(\w+)="([^"]*)"', l))
        ame = a.get("soul_name")
        if ame not in noms:
            sorties.append(l)
            continue
        suffixe = ame[len("scriptorium_"):]
        modele = fiches.get(a["skald_character_name"])
        if modele is None:
            raise SystemExit("REFUS : personnage modèle introuvable : " + a["skald_character_name"])
        p = dict(modele)
        p["skald_character_name"] = "char_scriptorium_" + suffixe
        p["skald_character_full_name_string_name"] = "ui_scriptorium_ame_" + suffixe
        p["ui_name_string_name"] = "ui_scriptorium_ame_" + suffixe
        personnages.append("    <skald_character " + " ".join('%s="%s"' % (c, p[c]) for c in sorted(p)) + " />")
        nom = noms[ame].replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
        textes.append("  <Row><Cell>ui_scriptorium_ame_%s</Cell><Cell>%s</Cell><Cell>%s</Cell></Row>" % (suffixe, nom, nom))
        a["skald_character_name"] = p["skald_character_name"]
        sorties.append(ligne(a))
    table = fin.join(['<?xml version="1.0" encoding="us-ascii"?>',
                      '<database xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" name="barbora" '
                      'xsi:noNamespaceSchemaLocation="../database.xsd">', '  <skald_characters version="1">']
                     + personnages + ["  </skald_characters>", "</database>", ""])
    os.makedirs(os.path.dirname(TABLE_DES_PERSONNAGES), exist_ok=True)
    ecrire_si_change(TABLE_DES_PERSONNAGES, table, "Table des personnages (%d)" % len(personnages))
    texte = "\n".join(["<Table>"] + textes + ["</Table>", ""])
    ancien = open(TEXTES_DES_NOMS, encoding="utf-8").read() if os.path.isfile(TEXTES_DES_NOMS) else None
    if ancien != texte:
        with open(TEXTES_DES_NOMS, "w", encoding="utf-8", newline="\n") as f:
            f.write(texte)
        print("Textes des noms écrits (%d)" % len(textes))
    else:
        print("Textes des noms : déjà à jour")
    return sorties


def chaine_lua(texte):
    """Une chaîne Lua sûre (guillemets, barres obliques inverses, fins de ligne échappés)."""
    return '"' + texte.replace("\\", "\\\\").replace('"', '\\"').replace("\n", " ").replace("\r", " ") + '"'


def lire_la_reprise():
    """La liste de la reprise gardée dans la liaison : [(empreinte, nom, palier)]."""
    with open(LIAISON, "r", encoding="utf-8") as f:
        texte = f.read()
    if texte.count(DEBUT_REPRISE) != 1 or texte.count(FIN_REPRISE) != 1:
        raise SystemExit("REFUS : repères de la reprise absents ou en double dans liaison.lua")
    bloc = texte.split(DEBUT_REPRISE, 1)[1].split(FIN_REPRISE, 1)[0]
    liste = []
    for empreinte, nom, palier in re.findall(r'\{ empreinte = (\d+), nom = "((?:[^"\\]|\\.)*)", palier = (\d) \}', bloc):
        liste.append((int(empreinte), nom.replace('\\"', '"').replace("\\\\", "\\"), int(palier)))
    return liste


def empreinte_de_cle(cle):
    """hommes.empreinte_de_cle, à l'identique (sur les octets UTF-8 de la clé)."""
    h = 5381
    for octet in cle.encode("utf-8"):
        h = (h * 33 + octet) % 2147483647
    return h


def ecrire_la_reprise(releve):
    """Lit le relevé JSON de Scriptorium et écrit la liste de la reprise dans la liaison. Rend la liste."""
    import json
    with open(releve, "r", encoding="utf-8") as f:
        donnees = json.load(f)
    if donnees.get("version") != 1 or not isinstance(donnees.get("hommes"), list):
        raise SystemExit("REFUS : relevé de version inconnue ou sans « hommes » : " + releve)
    liste, cles = [], set()
    for h in donnees["hommes"]:
        cle = h.get("cle")
        if not isinstance(cle, str) or not cle or cle in cles:
            raise SystemExit("REFUS : clé manquante ou en double dans le relevé : %r" % cle)
        cles.add(cle)
        nom = h.get("nom") if isinstance(h.get("nom"), str) and h.get("nom").strip() else "Homme de la Compagnie"
        palier = 3 if h.get("compagnon") is True else PALIERS_DU_RELEVE.get(h.get("rang"), 1)
        liste.append((empreinte_de_cle(cle), nom.strip(), palier))
    if len({e for e, _, _ in liste}) != len(liste):
        raise SystemExit("REFUS : deux clés du relevé ont la même empreinte")
    with open(LIAISON, "r", encoding="utf-8", newline="") as f:
        texte = f.read()
    fin = "\r\n" if "\r\n" in texte else "\n"
    avant, reste = texte.split(DEBUT_REPRISE, 1)
    _, apres = reste.split(FIN_REPRISE, 1)
    bloc = [DEBUT_REPRISE, "liaison.reprise_des_hommes = {"]
    bloc += ["  { empreinte = %d, nom = %s, palier = %d }," % (e, chaine_lua(n), p) for e, n, p in liste]
    bloc += ["}", ""]
    nouveau = avant + fin.join(bloc) + FIN_REPRISE + apres
    if nouveau != texte:
        with open(LIAISON, "w", encoding="utf-8", newline="") as f:
            f.write(nouveau)
    print("Reprise : %d homme(s) écrits dans la liaison" % len(liste))
    return liste


def lignes_de_la_reprise(liste, personnages):
    """Une âme par homme de la reprise (palette des combattants, notre cerveau, la Compagnie)."""
    r = [x for x in RESERVES if x["reserve"] == "combattant"][0]
    choix = [p for p in palette(personnages, r["familles"]) if p not in r.get("exclus", [])]
    lignes = []
    for numero, (cle, nom, palier) in enumerate(liste, start=1):
        lignes.append(ligne({
            "brain_id": NOTRE_CERVEAU, "combat_level": NIVEAUX_DE_LA_REPRISE[palier], "digestion_multiplier": "0",
            "factionName": FACTION, "initial_clothing_dirt": "0", "skald_character_name": choix[(numero - 1) % len(choix)],
            "social_class_id": r["classe"], "soul_archetype_id": r["archetype"],
            "soul_id": identifiant(CODE_REPRISE, 1, numero), "soul_name": "scriptorium_reprise_%03d" % numero,
            "soul_vip_class_id": "0", "xp_multiplier": "0"}))
    return lignes


def principal(arguments):
    if "--jeu" not in arguments or arguments.index("--jeu") + 1 >= len(arguments):
        print(__doc__)
        return 2
    jeu = arguments[arguments.index("--jeu") + 1]
    if not os.path.isfile(os.path.join(jeu, "Data", "Tables.pak")):
        print("REFUS : Tables.pak introuvable sous " + jeu)
        return 2
    personnages, ames_du_jeu, factions_du_jeu, modeles, fiches = lire_le_jeu(jeu)
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
    if "--releve" in arguments:
        reprise = ecrire_la_reprise(arguments[arguments.index("--releve") + 1])
    else:
        reprise = lire_la_reprise()
    neuves = (ecrire_les_personnages(lignes_des_reserves(personnages) + lignes_de_la_reprise(reprise, personnages), fiches,
                                     fin, reprise)
              + lignes_des_bandes(modeles, personnages))
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
