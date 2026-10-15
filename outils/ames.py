"""Écrit les âmes du socle dans socle/pak/Libs/Tables/rpg/soul__scriptorium_socle.xml (fiche 13).

Usage (sur le PC de JoVenGer) :
    py -3.13 outils/ames.py --jeu "G:\\SteamLibrary\\steamapps\\common\\KingdomComeDeliverance2"

Lit en lecture seule, dans <jeu>\\Data\\Tables.pak, les personnages génériques du jeu (table skald_character) et les
identifiants des âmes du jeu ; n'écrit que la table des âmes du socle. Les âmes d'essai déjà présentes (marcheur,
brigand d'essai) sont gardées telles quelles ; les réserves sont réécrites, toujours à l'identique.

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

PREFIXE = "5c7a5c7a"
NOTRE_CERVEAU = "b8a850d0-47c6-44a1-872e-ce7efcf4b9f9"
# Faction provisoire de toutes nos âmes : celle du marcheur, jusqu'à l'essai de la faction « la Compagnie » (fiche 13).
FACTION = "trosecko_settlements_trosky_soldiers_guards"

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
        for nom in tables.namelist():
            if re.search(r"libs/tables/rpg/soul(__[^/]+)?\.xml$", nom, re.I):
                texte = tables.read(nom).decode("utf-8", "replace")
                ames.update(i.lower() for i in re.findall(r'soul_id="([^"]+)"', texte))
    return set(re.findall(r'skald_character_name="([^"]+)"', personnages)), ames


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
    personnages, ames_du_jeu = lire_le_jeu(jeu)
    pris = sorted(i for i in ames_du_jeu if i.startswith(PREFIXE))
    if pris:
        print("REFUS : le préfixe %s est déjà pris par le jeu : %s" % (PREFIXE, ", ".join(pris[:5])))
        return 1
    with open(TABLE, "r", encoding="ascii", newline="") as fichier:
        texte = fichier.read()
    fin = "\r\n" if "\r\n" in texte else "\n"
    anciennes = texte.split(fin)
    # Les âmes d'essai (hors réserves) sont gardées telles quelles, dans leur ordre.
    gardees = [l for l in anciennes if "<soul " in l and ('soul_id="' + PREFIXE) not in l]
    neuves = lignes_des_reserves(personnages)
    tete = [l for l in anciennes if "<soul " not in l and "</souls>" not in l and "</database>" not in l and l.strip()]
    sortie = tete + gardees + neuves + ["  </souls>", "</database>", ""]
    nouveau = fin.join(sortie)
    nouveau.encode("ascii")
    if nouveau == texte:
        print("Table des âmes : déjà à jour (%d âmes d'essai, %d âmes des réserves)" % (len(gardees), len(neuves)))
        return 0
    with open(TABLE, "w", encoding="ascii", newline="") as fichier:
        fichier.write(nouveau)
    print("Table des âmes écrite : %d âmes d'essai gardées, %d âmes des réserves" % (len(gardees), len(neuves)))
    return 0


if __name__ == "__main__":
    sys.exit(principal(sys.argv[1:]))
