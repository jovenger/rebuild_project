"""Empreintes du mod d'Alex, pour le contrôle d'absence.

Usage (sur le PC de JoVenGer, en lecture seule sur la copie d'Alex) :
    py -3.13 outils/empreintes.py "C:\\Users\\maste\\Desktop\\Scriptorium\\mercenaires" docs/socle/empreintes_alex.json

Le fichier produit ne contient que des empreintes (sha256 raccourcies) : aucun fichier,
aucune ligne, aucun texte ni aucun nom d'Alex n'y figure en clair. Le contrôle d'absence
(essais/tout_verifier.py) compare les mêmes empreintes calculées sur le socle.

Ce que l'on relève :
- fichiers : empreinte du contenu de chaque fichier ;
- chemins  : chemin relatif, en minuscules ;
- lignes   : lignes de code normalisées (espaces réduits, commentaires ôtés), de 16 caractères ou plus ;
- noms     : identifiants définis dans le Lua (fonctions, champs de table) et noms de fichiers ;
- cles     : clés de textes (première cellule des tables de langue) ;
- textes   : textes de langue normalisés (minuscules, sans ponctuation), de 12 caractères ou plus.
"""

import hashlib
import json
import os
import re
import sys
from datetime import date

EXTENSIONS_TEXTE = {".lua", ".xml", ".cfg", ".txt", ".json", ".ent", ".mtl", ".cdf", ".ini"}
EXTENSIONS_IGNOREES = {".md"}  # notices écrites par JoVenGer, pas par Alex
# Noms de fichiers imposés par le jeu à tout mod (wiki de Warhorse) : leur nom n'est le choix de personne,
# il n'entre pas dans les noms comparés (leur contenu, leurs lignes et leur chemin restent relevés).
FICHIERS_IMPOSES = {"mod.manifest", "mod.cfg"}

LIGNE_MIN = 16
TEXTE_MIN = 12

MOTIF_IDENTIFIANT = re.compile(r"[A-Za-z_][A-Za-z0-9_]*")
MOTIF_FONCTION = re.compile(r"\bfunction\s+([A-Za-z_][A-Za-z0-9_.:]*)")
# Une vraie affectation « x.champ = … » : pas une comparaison « x.champ == … » (14/10 : les comparaisons étaient
# relevées comme des définitions). « ~= », « <= », « >= » ne passent pas : le signe précède le « = ».
MOTIF_CHAMP = re.compile(r"\b([A-Za-z_][A-Za-z0-9_]*)\.([A-Za-z_][A-Za-z0-9_]*)\s*=(?!=)")
MOTIF_CELLULE = re.compile(r"<Cell>(.*?)</Cell>", re.S)
MOTIF_PONCTUATION = re.compile(r"[^\w]+", re.U)


def empreinte(chaine):
    return hashlib.sha256(chaine.encode("utf-8")).hexdigest()[:20]


def empreinte_octets(octets):
    return hashlib.sha256(octets).hexdigest()[:20]


def lire_texte(chemin):
    with open(chemin, "rb") as fichier:
        octets = fichier.read()
    for encodage in ("utf-8-sig", "utf-8", "cp1252", "latin-1"):
        try:
            return octets.decode(encodage)
        except UnicodeDecodeError:
            continue
    return octets.decode("utf-8", errors="replace")


def normaliser_ligne(ligne, extension):
    if extension == ".lua":
        ligne = re.sub(r"--.*$", "", ligne)
    ligne = re.sub(r"\s+", " ", ligne).strip()
    return ligne


def lignes_normalisees(texte, extension):
    for ligne in texte.splitlines():
        ligne = normaliser_ligne(ligne, extension)
        if len(ligne) >= LIGNE_MIN:
            yield ligne


def noms_du_lua(texte):
    for correspondance in MOTIF_FONCTION.finditer(texte):
        nom = correspondance.group(1)
        yield nom
        for partie in re.split(r"[.:]", nom):
            if len(partie) >= 4:
                yield partie
    for correspondance in MOTIF_CHAMP.finditer(texte):
        yield correspondance.group(1) + "." + correspondance.group(2)
        if len(correspondance.group(2)) >= 4:
            yield correspondance.group(2)


def normaliser_texte(texte):
    return MOTIF_PONCTUATION.sub("", texte.lower())


def cellules_du_xml(texte):
    """Rend (cles, textes) d'une table de langue : première cellule = clé, les autres = textes."""
    cles, textes = [], []
    for rangee in re.findall(r"<Row>(.*?)</Row>", texte, re.S):
        cellules = [c.strip() for c in MOTIF_CELLULE.findall(rangee)]
        if not cellules:
            continue
        cles.append(cellules[0])
        for cellule in cellules[1:]:
            normalise = normaliser_texte(cellule)
            if len(normalise) >= TEXTE_MIN:
                textes.append(normalise)
    return cles, textes


def relever(dossier):
    """Relève tout d'un dossier. Rend un dictionnaire d'ensembles d'empreintes."""
    releve = {"fichiers": set(), "chemins": set(), "lignes": set(), "noms": set(), "cles": set(), "textes": set()}
    compte = 0
    for racine, _, fichiers in os.walk(dossier):
        for nom in fichiers:
            chemin = os.path.join(racine, nom)
            relatif = os.path.relpath(chemin, dossier).replace("\\", "/").lower()
            extension = os.path.splitext(nom)[1].lower()
            if extension in EXTENSIONS_IGNOREES:
                continue
            compte += 1
            with open(chemin, "rb") as fichier:
                releve["fichiers"].add(empreinte_octets(fichier.read()))
            releve["chemins"].add(empreinte(relatif))
            if nom.lower() not in FICHIERS_IMPOSES:
                releve["noms"].add(empreinte(os.path.splitext(nom)[0].lower()))
            if extension not in EXTENSIONS_TEXTE:
                continue
            texte = lire_texte(chemin)
            for ligne in lignes_normalisees(texte, extension):
                releve["lignes"].add(empreinte(ligne))
            if extension == ".lua":
                for identifiant in noms_du_lua(texte):
                    releve["noms"].add(empreinte(identifiant))
            if extension == ".xml":
                cles, textes = cellules_du_xml(texte)
                for cle in cles:
                    releve["cles"].add(empreinte(cle))
                    releve["noms"].add(empreinte(cle))
                for t in textes:
                    releve["textes"].add(empreinte(t))
    return releve, compte


def principal(arguments):
    if len(arguments) < 1:
        print(__doc__)
        return 2
    dossier = arguments[0]
    sortie = arguments[1] if len(arguments) > 1 else os.path.join("docs", "socle", "empreintes_alex.json")
    if not os.path.isdir(dossier):
        print("Dossier introuvable : " + dossier)
        return 2
    releve, compte = relever(dossier)
    contenu = {
        "origine": "copie du mod d'Alex (empreintes seulement)",
        "date": date.today().isoformat(),
        "fichiers_releves": compte,
    }
    for nom, ensemble in releve.items():
        contenu[nom] = sorted(ensemble)
    os.makedirs(os.path.dirname(sortie) or ".", exist_ok=True)
    with open(sortie, "w", encoding="utf-8") as fichier:
        json.dump(contenu, fichier, indent=0)
    print("Empreintes relevées sur %d fichiers -> %s" % (compte, sortie))
    for nom, ensemble in releve.items():
        print("  %-9s %6d" % (nom, len(ensemble)))
    return 0


if __name__ == "__main__":
    sys.exit(principal(sys.argv[1:]))
