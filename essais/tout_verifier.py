"""Vérification complète du socle. Rien ne se commet ni ne s'installe si elle ne passe pas.

Usage :
    py -3.13 essais/tout_verifier.py            # mode suivi
    py -3.13 essais/tout_verifier.py --strict   # mode strict : les empreintes d'Alex sont exigées

Étapes :
  1. syntaxe Lua (Lua 5.1, celui du moteur) de tous les scripts du socle ;
  2. banc d'essai Lua (essais/lua/essai_*.lua) sur le faux jeu ;
  3. noms interdits et brouillons oubliés dans le socle ;
  4. textes : tables de langue bien formées, clés uniques, clés employées <-> clés définies ;
  5. manifeste du mod ;
  6. contrôle d'absence : empreintes du socle comparées à celles d'Alex (docs/socle/empreintes_alex.json).
"""

import json
import os
import re
import sys
import xml.etree.ElementTree as ET

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOCLE = os.path.join(RACINE, "socle")
PAK = os.path.join(SOCLE, "pak")
TEXTES = os.path.join(SOCLE, "textes")
ESSAIS_LUA = os.path.join(RACINE, "essais", "lua")
EMPREINTES = os.path.join(RACINE, "docs", "socle", "empreintes_alex.json")

sys.path.insert(0, os.path.join(RACINE, "outils"))
import empreintes as outil_empreintes  # noqa: E402

MOTIFS_INTERDITS = [
    (re.compile(r"mercenar", re.I), "nom du mod d'Alex"),
    (re.compile(r"\bMerc[A-Z_]"), "personnage d'Alex"),
    (re.compile(r"\bmerc_"), "préfixe d'Alex"),
    (re.compile(r"\bQM[A-Z]"), "clé de sauvegarde d'Alex"),
    (re.compile(r"Quartermaster", re.I), "intendant d'Alex"),
    (re.compile(r"WBRaid"), "fonction de bataille d'Alex"),
    (re.compile(r"\b(TODO|FIXME|XXX)\b"), "brouillon oublié"),
]

MOTIF_CLE = re.compile(r"ui_scriptorium_[A-Za-z0-9_]+")

erreurs = []
avertissements = []


def erreur(message):
    erreurs.append(message)


def avertir(message):
    avertissements.append(message)


def fichiers(dossier, extensions):
    for racine, _, noms in os.walk(dossier):
        for nom in sorted(noms):
            if os.path.splitext(nom)[1].lower() in extensions:
                yield os.path.join(racine, nom)


def lire(chemin):
    with open(chemin, "r", encoding="utf-8") as fichier:
        return fichier.read()


def relatif(chemin):
    return os.path.relpath(chemin, RACINE).replace("\\", "/")


# ------------------------------------------------------------------ 1. syntaxe Lua

def runtime_lua():
    try:
        from lupa import lua51
    except ImportError:
        erreur("lupa (Lua 5.1) absent : py -3.13 -m pip install lupa")
        return None
    return lua51.LuaRuntime(unpack_returned_tuples=True)


def verifier_syntaxe(lua):
    compte = 0
    charger = lua.eval("function(code, nom) local f, err = loadstring(code, nom) if not f then error(err, 0) end return true end")
    for chemin in list(fichiers(PAK, {".lua"})) + list(fichiers(ESSAIS_LUA, {".lua"})):
        compte += 1
        try:
            charger(lire(chemin), "=" + relatif(chemin))
        except Exception as exception:  # noqa: BLE001
            erreur("syntaxe Lua : %s" % exception)
    return compte


# ------------------------------------------------------------------ 2. banc Lua

ORDRE_SOCLE = ["noyau.lua", "bandeau.lua", "registre.lua", "coffre.lua", "camp.lua", "hommes.lua", "bataille.lua", "directeur.lua", "enceinte.lua", "atelier.lua", "patrouilles.lua", "discipline.lua", "poste.lua"]


def executer_banc(lua):
    executer = lua.eval("function(code, nom) local f, err = loadstring(code, nom) if not f then error(err, 0) end return f() end")
    executer(lire(os.path.join(ESSAIS_LUA, "faux_jeu.lua")), "=essais/lua/faux_jeu.lua")
    executer(lire(os.path.join(ESSAIS_LUA, "outils_essai.lua")), "=essais/lua/outils_essai.lua")
    for nom in ORDRE_SOCLE:
        chemin = os.path.join(PAK, "Scripts", "scriptorium", nom)
        try:
            executer(lire(chemin), "=" + relatif(chemin))
        except Exception as exception:  # noqa: BLE001
            erreur("banc Lua : chargement du socle en échec : %s" % exception)
            return 0, 1, 0
    essais = sorted(f for f in os.listdir(ESSAIS_LUA) if f.startswith("essai_") and f.endswith(".lua"))
    for nom in essais:
        chemin = os.path.join(ESSAIS_LUA, nom)
        try:
            executer(lire(chemin), "=" + relatif(chemin))
        except Exception as exception:  # noqa: BLE001
            erreur("banc Lua : %s interrompu : %s" % (nom, exception))
    resultats = lua.globals().Essais
    for message in list(resultats.messages.values()):
        erreur("banc Lua : " + message)
    return int(resultats.reussis), int(resultats.echecs), len(essais)


# ------------------------------------------------------------------ 2 bis. ordres par fichier

def verifier_ordres():
    """Un ordre écrit par outils/ordonner.py est relu tel quel par la vraie liaison ; un fichier qui
    voudrait toucher au jeu ne voit rien (environnement vide)."""
    import tempfile
    import ordonner
    connues = ordonner.commandes_du_poste()
    if len(connues) != 14:
        erreur("ordres : %d commandes lues dans poste.lua, 14 attendues" % len(connues))
    lua = runtime_lua()
    if lua is None:
        return len(connues)
    chemin_liaison = os.path.join(PAK, "Scripts", "scriptorium", "liaison.lua")
    lua.execute(lire(chemin_liaison))
    liaison = lua.globals().Scriptorium.liaison_reelle
    with tempfile.TemporaryDirectory() as dossier:
        chemin = os.path.join(dossier, ordonner.NOM_DU_FICHIER)
        liaison.chemins_des_ordres = lua.table_from([os.path.join(dossier, "absent.lua"), chemin])
        if liaison.lire_ordres() is not None:
            erreur("ordres : sans fichier, la liaison devrait ne rien rendre")
        for attendu in (1, 2):
            numero, _ = ordonner.ecrire(dossier, "scriptorium_bilan")
            donnees, lu_a = liaison.lire_ordres()
            if numero != attendu or donnees is None or donnees.numero != attendu \
                    or donnees.commande != "scriptorium_bilan" or lu_a != chemin:
                erreur("ordres : l'ordre n° %d écrit n'est pas relu tel quel par la liaison" % attendu)
        with open(chemin, "w", encoding="ascii") as fichier:
            fichier.write('return { numero = 3, commande = tostring(os) }\n')
        donnees, _, raison = liaison.lire_ordres()
        if donnees is not None or not raison:
            erreur("ordres : un fichier qui appelle le jeu devrait être refusé (environnement vide)")
    return len(connues)


# ------------------------------------------------------------------ 3. noms interdits

def verifier_noms():
    compte = 0
    for chemin in fichiers(SOCLE, {".lua", ".xml", ".cfg", ".manifest", ".txt"}):
        texte = lire(chemin)
        for numero, ligne in enumerate(texte.splitlines(), 1):
            for motif, raison in MOTIFS_INTERDITS:
                if motif.search(ligne):
                    compte += 1
                    erreur("nom interdit (%s) : %s:%d : %s" % (raison, relatif(chemin), numero, ligne.strip()))
    return compte


# ------------------------------------------------------------------ 4. textes

def verifier_textes():
    definies = {}
    for chemin in fichiers(TEXTES, {".xml"}):
        # Le jeu ne charge comme textes de mod que les fichiers <nom>__<modid>.xml (constaté au journal le 14/10).
        if not os.path.basename(chemin).endswith("__scriptorium_socle.xml"):
            erreur("texte : %s : le nom doit finir par « __scriptorium_socle.xml », sinon le jeu ne le charge pas" % relatif(chemin))
        try:
            arbre = ET.parse(chemin)
        except ET.ParseError as exception:
            erreur("texte : %s mal formé : %s" % (relatif(chemin), exception))
            continue
        for rangee in arbre.getroot().iter("Row"):
            cellules = [(c.text or "").strip() for c in rangee.findall("Cell")]
            if len(cellules) != 3:
                erreur("texte : %s : une rangée n'a pas 3 cellules : %s" % (relatif(chemin), cellules))
                continue
            cle, source, traduction = cellules
            if not MOTIF_CLE.fullmatch(cle):
                erreur("texte : clé hors convention (ui_scriptorium_…) : %s" % cle)
            if cle in definies:
                erreur("texte : clé définie deux fois : %s" % cle)
            if not traduction:
                erreur("texte : traduction vide pour %s" % cle)
            if source != traduction:
                avertir("texte : source et traduction différentes pour %s" % cle)
            definies[cle] = traduction
    employees = {}
    for chemin in fichiers(PAK, {".lua"}):
        for numero, ligne in enumerate(lire(chemin).splitlines(), 1):
            for cle in MOTIF_CLE.findall(ligne):
                employees.setdefault(cle, []).append("%s:%d" % (relatif(chemin), numero))
    for cle, endroits in sorted(employees.items()):
        if cle not in definies:
            erreur("texte : clé employée mais jamais définie : %s (%s)" % (cle, endroits[0]))
    for cle in sorted(definies):
        if cle not in employees:
            erreur("texte : clé définie mais jamais employée : %s" % cle)
    return len(definies), len(employees)


# ------------------------------------------------------------------ 5. manifeste

def verifier_manifeste():
    chemin = os.path.join(SOCLE, "mod.manifest")
    if not os.path.exists(chemin):
        erreur("manifeste absent : socle/mod.manifest")
        return
    # Le jeu lit le manifeste en ASCII : un « — » est devenu « Scriptorium     socle » dans la sauvegarde (14/10).
    with open(chemin, "rb") as fichier:
        if any(octet > 127 for octet in fichier.read()):
            erreur("manifeste : caractère hors ASCII ; le jeu l'écrit mal dans la sauvegarde")
    try:
        racine = ET.parse(chemin).getroot()
    except ET.ParseError as exception:
        erreur("manifeste mal formé : %s" % exception)
        return
    modid = racine.findtext("info/modid")
    if modid != "scriptorium_socle":
        erreur("manifeste : modid attendu « scriptorium_socle », trouvé « %s »" % modid)
    for champ in ("name", "version", "author"):
        if not (racine.findtext("info/" + champ) or "").strip():
            erreur("manifeste : champ vide : " + champ)


# ------------------------------------------------------------------ 6. contrôle d'absence

def controle_absence(strict):
    if not os.path.exists(EMPREINTES):
        message = ("contrôle d'absence : empreintes d'Alex absentes (docs/socle/empreintes_alex.json) ; "
                   "examens fichiers, chemins, lignes, noms, clés et textes non faits. "
                   "Les relever avec outils/empreintes.py sur le PC.")
        if strict:
            erreur(message)
        else:
            avertir(message)
        return None
    with open(EMPREINTES, "r", encoding="utf-8") as fichier:
        alex = json.load(fichier)
    alex = {nom: set(alex.get(nom, [])) for nom in ("fichiers", "chemins", "lignes", "noms", "cles", "textes")}
    socle, _ = outil_empreintes.relever(SOCLE)

    # Chemins : on compare les chemins tels qu'ils seront dans le pak (socle/pak/…) et les textes.
    chemins_installes = set()
    for base in (PAK, os.path.join(TEXTES, "fr")):
        for racine, _, noms in os.walk(base):
            for nom in noms:
                chemins_installes.add(outil_empreintes.empreinte(
                    os.path.relpath(os.path.join(racine, nom), base).replace("\\", "/").lower()))
    socle["chemins"] = chemins_installes

    resultats = {}
    for nom in ("fichiers", "chemins", "lignes", "noms", "cles", "textes"):
        communs = socle[nom] & alex[nom]
        resultats[nom] = len(communs)
        if communs:
            erreur("contrôle d'absence : %d %s en commun avec Alex" % (len(communs), nom))
    if resultats["lignes"] or resultats["noms"] or resultats["textes"]:
        # Nommer les coupables, pour corriger vite.
        for chemin in list(fichiers(PAK, {".lua", ".xml", ".cfg"})) + list(fichiers(TEXTES, {".xml"})):
            texte = lire(chemin)
            extension = os.path.splitext(chemin)[1].lower()
            for numero, ligne in enumerate(texte.splitlines(), 1):
                normalisee = outil_empreintes.normaliser_ligne(ligne, extension)
                if len(normalisee) >= outil_empreintes.LIGNE_MIN and outil_empreintes.empreinte(normalisee) in alex["lignes"]:
                    erreur("  ligne d'Alex : %s:%d" % (relatif(chemin), numero))
            if extension == ".lua":
                for identifiant in set(outil_empreintes.noms_du_lua(texte)):
                    if outil_empreintes.empreinte(identifiant) in alex["noms"]:
                        erreur("  nom d'Alex : %s : %s" % (relatif(chemin), identifiant))
            if extension == ".xml":
                cles, textes = outil_empreintes.cellules_du_xml(texte)
                for cle in cles:
                    if outil_empreintes.empreinte(cle) in alex["cles"]:
                        erreur("  clé d'Alex : %s : %s" % (relatif(chemin), cle))
                for t in textes:
                    if outil_empreintes.empreinte(t) in alex["textes"]:
                        erreur("  texte d'Alex : %s : %s…" % (relatif(chemin), t[:40]))
    return resultats


# ------------------------------------------------------------------ principal

def principal(arguments):
    strict = "--strict" in arguments
    print("Vérification complète du socle (%s)" % ("mode strict" if strict else "mode suivi"))

    lua = runtime_lua()
    if lua is not None:
        print("1. syntaxe Lua : %d fichiers" % verifier_syntaxe(lua))
        if not erreurs:
            reussis, echecs, nb_fichiers = executer_banc(lua)
            print("2. banc Lua : %d fichiers d'essais, %d vérifications réussies, %d échecs" % (nb_fichiers, reussis, echecs))
            print("2 bis. ordres par fichier : %d commandes, aller-retour avec la liaison vérifié" % verifier_ordres())
        else:
            print("2. banc Lua : non lancé (syntaxe en erreur)")

    print("3. noms interdits : %d" % verifier_noms())
    definies, employees = verifier_textes()
    print("4. textes : %d clés définies, %d employées" % (definies, employees))
    verifier_manifeste()
    print("5. manifeste : vérifié")
    resultats = controle_absence(strict)
    if resultats is None:
        print("6. contrôle d'absence : non fait (empreintes absentes)")
    else:
        print("6. contrôle d'absence — " + " · ".join("%s %d" % (nom, n) for nom, n in resultats.items()))

    for message in avertissements:
        print("Avertissement : " + message)
    for message in erreurs:
        print("ERREUR : " + message)
    if erreurs:
        print("\nVérification complète : ÉCHEC (%d erreur(s))" % len(erreurs))
        return 1
    print("\nVérification complète : tout passe")
    return 0


if __name__ == "__main__":
    sys.exit(principal(sys.argv[1:]))
