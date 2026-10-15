"""Écrit dans la liaison les pièces de chaque préréglage d'équipement retenu (fiche 13, V71 b).

Usage :
    py -3.13 outils/equipement.py --jeu "G:\\SteamLibrary\\steamapps\\common\\KingdomComeDeliverance2"

Vu en jeu le 15/10 (V71 a à a6) : un équipement posé d'un coup par un préréglage du jeu (actor:EquipClothingPreset,
actor:EquipWeaponPreset) n'est pas gardé au rechargement ; une pièce créée une à une (inventory:CreateItem) l'est, avec
son usure. Le socle crée donc chaque pièce d'un préréglage une à une ; cet outil en relève la liste.

Lit en lecture seule, dans <jeu>\\Data\\Tables.pak : Libs/Tables/item/clothing_preset.xml (<Items><Guid>),
Libs/Tables/item/weapon_preset.xml (weapon_preset_item item_class_id), Libs/Tables/item/item.xml (chaque objet doit
y être) et Libs/Tables/item/equipment_slot.xml (la couche de chaque place : les pièces d'une tenue sont écrites des
dessous aux dessus, V71 d). N'écrit que le bloc compris entre les deux repères de socle/pak/Scripts/scriptorium/liaison.lua, à l'identique
quand rien n'a changé. Les règles (quel préréglage à quel grade, combien de munitions) sont dans hommes.equipement ;
essais/tout_verifier.py vérifie que chaque nom qu'elles citent est dans le bloc.
"""

import io
import os
import re
import sys
import zipfile

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LIAISON = os.path.join(RACINE, "socle", "pak", "Scripts", "scriptorium", "liaison.lua")
DEBUT = "-- DÉBUT DES PIÈCES (écrit par outils/equipement.py ; ne pas modifier à la main)"
FIN = "-- FIN DES PIÈCES"

# Les sortes de préréglages du jeu retenues (fiche 13, section validée) : tenues de soldat et les six familles.
TENUES = re.compile(r"^soldier_generic_[1-6]_\d+$")
FAMILLES = re.compile(r"^(sword_shield|axe_shield|longsword|mace_shield|axe|polearm)_[2-6]_\d+$")
# Les préréglages à pavois peint (réponse 3 de JoVenGer), dont trois hors des six familles.
PAVOIS = ["mace_shield_2_02", "mace_shield_2_03", "mace_shield_3_04", "mace_shield_4_02", "axe_shield_3_02",
          "axe_shield_3_03", "axe_shield_4_02", "huntingsword_shield_3_01", "huntingsword_shield_3_02",
          "huntingsword_shield_4_01"]
# Nos assemblages de tir (règles de JoVenGer dans Scriptorium), par noms d'objets du jeu : l'arme de tir, l'épée courte,
# puis les munitions (à part : leur nombre est une règle de hommes.equipement).
TIR = {
    "scriptorium_archer_1": (["bow_b", "shortswordCommon"], "arrow_crude"),
    "scriptorium_archer_2": (["bow_c", "shortswordBroad"], "arrow_normal"),
    "scriptorium_archer_3": (["bow_d_a", "shortswordHeavy"], "arrow_hunting"),
    "scriptorium_arbaletrier_1_a": (["crossbowLightCheap01", "shortswordCommon"], "bolt_crude"),
    "scriptorium_arbaletrier_1_b": (["crossbowLightNormal01", "shortswordCommon"], "bolt_crude"),
    "scriptorium_arbaletrier_2_a": (["crossbowMediumCheap01", "shortswordCommon"], "bolt_normal"),
    "scriptorium_arbaletrier_2_b": (["crossbowMediumNormal01", "shortswordCommon"], "bolt_normal"),
    "scriptorium_arbaletrier_3_a": (["crossbowHeavyNormal01", "shortswordCommon"], "bolt_enh_precise"),
    "scriptorium_arbaletrier_3_b": (["crossbowHeavyCheap01", "shortswordCommon"], "bolt_enh_precise"),
}
GUID = re.compile(r"^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$")
# V71 d (fiche 13) : les pièces d'une tenue se portent par couches, des dessous aux dessus (V71 c : la coiffe mise après
# le chapel l'ôtait). La couche d'une place est son BodyLayerTypeId (equipment_slot.xml) ; une place liste ses types
# d'armure (ArmorTypes) ; le type d'une pièce est le début du nom de son modèle (attribut Clothing de item.xml :
# « LegsPadded03_m01 » -> LegsPadded). Les places sans liste de types sont nommées ici d'après leur nom de place.
PLACES_SANS_TYPES = {"Gauntlets": "gloves", "Gloves": "gloves", "HandWrap": "gloves", "Shoes": "boot", "BootsAnkle": "boot",
                     "BootsKnee": "boot", "Coat": "body_coat", "Waffenrock": "body_coat", "CollarChain": "collar",
                     "CollarPadded": "collar", "BrigandineArm": "sleeves", "Hood": "head_hood"}
COUCHE_INCONNUE = 9


def lire_les_tables(jeu):
    chemin = os.path.join(jeu, "Data", "Tables.pak")
    with zipfile.ZipFile(chemin) as pak:
        def lire(nom):
            return pak.read(nom).decode("utf-8", "replace")
        return (lire("Libs/Tables/item/clothing_preset.xml"), lire("Libs/Tables/item/weapon_preset.xml"),
                lire("Libs/Tables/item/item.xml"), lire("Libs/Tables/item/equipment_slot.xml"))


def couches_des_objets(item_xml, slot_xml):
    """Identifiant (minuscules) -> couche (1 dessous … 4 dessus), et les types restés sans couche."""
    couche_de_place, couche_de_type = {}, {}
    for attributs in re.findall(r"<EquipmentSlot ([^>]*?)/?>", slot_xml):
        a = dict(re.findall(r'(\w+)="([^"]*)"', attributs))
        couche = int(a.get("BodyLayerTypeId", COUCHE_INCONNUE))
        couche_de_place[a.get("Name")] = couche
        for t in a.get("ArmorTypes", "").split():
            couche_de_type[t] = couche
    couches, inconnus = {}, set()
    for attributs in re.findall(r"<\w+ ([^>]*?)/?>", item_xml):
        a = dict(re.findall(r'(\w+)="([^"]*)"', attributs))
        if "Id" not in a or not a.get("Clothing"):
            continue
        sorte = re.match(r"[A-Za-z]+", a["Clothing"])
        sorte = sorte.group(0) if sorte else ""
        couche = couche_de_type.get(sorte)
        if couche is None and sorte in PLACES_SANS_TYPES:
            couche = couche_de_place.get(PLACES_SANS_TYPES[sorte])
        if couche is None:
            inconnus.add(sorte)
            couche = COUCHE_INCONNUE
        couches[a["Id"].lower()] = couche
    return couches, inconnus


def objets_du_jeu(item_xml):
    """Identifiant (minuscules) -> nom, et nom -> identifiant, pour chaque objet de item.xml."""
    par_id, par_nom = {}, {}
    for attributs in re.findall(r"<\w+ ([^>]*?)/?>", item_xml):
        a = dict(re.findall(r'(\w+)="([^"]*)"', attributs))
        if "Id" in a and "Name" in a:
            par_id[a["Id"].lower()] = a["Name"]
            par_nom.setdefault(a["Name"], a["Id"].lower())
    return par_id, par_nom


def pieces_des_prereglages(clothing_xml, weapon_xml):
    pieces = {}
    for nom, corps in re.findall(r'<clothing_preset [^>]*clothing_preset_name="([^"]+)"[^>]*>(.*?)</clothing_preset>',
                                 clothing_xml, re.S):
        if TENUES.match(nom) and "crimeScene" not in nom:
            pieces[nom] = [g.lower() for g in re.findall(r"<Guid>([^<]+)</Guid>", corps)]
    for nom, corps in re.findall(r'<weapon_preset [^>]*weapon_preset_name="([^"]+)"[^>]*>(.*?)</weapon_preset>',
                                 weapon_xml, re.S):
        if FAMILLES.match(nom) or nom in PAVOIS:
            pieces[nom] = [g.lower() for g in re.findall(r'item_class_id="([^"]+)"', corps)]
    return pieces


def bloc_lua(pieces, munitions):
    lignes = [DEBUT,
              "-- Les pièces de chaque préréglage retenu (fiche 13, V71 b), dans l'ordre du jeu, créées une à une par le socle ;",
              "-- et l'objet des munitions de nos assemblages de tir (leur nombre est une règle de hommes.equipement).",
              "liaison.pieces_des_prereglages = {"]
    for nom in sorted(pieces):
        lignes.append('  ["%s"] = { %s },' % (nom, ", ".join('"%s"' % g for g in pieces[nom])))
    lignes.append("}")
    lignes.append("liaison.munitions_des_prereglages = {")
    for nom in sorted(munitions):
        lignes.append('  ["%s"] = "%s",' % (nom, munitions[nom]))
    lignes.append("}")
    lignes.append(FIN)
    return lignes


def principal(arguments):
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")
    if "--jeu" not in arguments or arguments.index("--jeu") + 1 >= len(arguments):
        print(__doc__)
        return 2
    jeu = arguments[arguments.index("--jeu") + 1]
    clothing_xml, weapon_xml, item_xml, slot_xml = lire_les_tables(jeu)
    par_id, par_nom = objets_du_jeu(item_xml)
    pieces = pieces_des_prereglages(clothing_xml, weapon_xml)
    couches, _ = couches_des_objets(item_xml, slot_xml)
    sans_couche = set()
    for nom in pieces:
        if nom.startswith("soldier_generic"):
            for g in pieces[nom]:
                if couches.get(g, COUCHE_INCONNUE) == COUCHE_INCONNUE:
                    sans_couche.add(g)
            rang = {g: i for i, g in enumerate(pieces[nom])}
            pieces[nom] = sorted(pieces[nom], key=lambda g: (couches.get(g, COUCHE_INCONNUE), rang[g]))
    if sans_couche:
        print("Attention : %d pièce(s) de tenue sans couche connue, portées en dernier" % len(sans_couche))
    munitions = {}
    for nom, (armes, munition) in TIR.items():
        manquants = [n for n in armes + [munition] if n not in par_nom]
        if manquants:
            print("Erreur : objets absents de item.xml pour %s : %s" % (nom, ", ".join(manquants)))
            return 1
        pieces[nom] = [par_nom[n] for n in armes]
        munitions[nom] = par_nom[munition]
    erreurs = []
    for nom in PAVOIS:
        if nom not in pieces:
            erreurs.append("préréglage à pavois absent du jeu : " + nom)
    for nom, liste in pieces.items():
        if not liste:
            erreurs.append("préréglage sans pièce : " + nom)
        for g in liste:
            if not GUID.match(g):
                erreurs.append("%s : identifiant mal formé %s" % (nom, g))
            elif g not in par_id:
                erreurs.append("%s : objet %s absent de item.xml" % (nom, g))
    if erreurs:
        for e in erreurs:
            print("Erreur : " + e)
        return 1
    with open(LIAISON, encoding="utf-8", newline="") as f:
        texte = f.read()
    nl = "\r\n" if "\r\n" in texte else "\n"
    if texte.count(DEBUT) != 1 or texte.count(FIN) != 1 or texte.index(DEBUT) > texte.index(FIN):
        print("Erreur : les repères du bloc des pièces manquent dans liaison.lua (ou sont en double)")
        return 1
    debut = texte.index(DEBUT)
    fin = texte.index(FIN) + len(FIN)
    neuf = texte[:debut] + nl.join(bloc_lua(pieces, munitions)) + texte[fin:]
    tenues = sum(1 for n in pieces if n.startswith("soldier_generic"))
    if neuf == texte:
        print("Pièces des préréglages : déjà à jour (%d préréglages, dont %d tenues, %d assemblages de tir)"
              % (len(pieces), tenues, len(TIR)))
        return 0
    with open(LIAISON, "w", encoding="utf-8", newline="") as f:
        f.write(neuf)
    print("Pièces des préréglages écrites : %d préréglages, dont %d tenues, %d assemblages de tir"
          % (len(pieces), tenues, len(TIR)))
    return 0


if __name__ == "__main__":
    sys.exit(principal(sys.argv[1:]))
