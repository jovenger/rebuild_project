"""Écrit le fichier de réglages du socle : les valeurs des règles changées sans toucher au code (fiche 10).

Usage (sur le PC de JoVenGer) :
    py -3.13 outils/regler.py --jeu "G:\\SteamLibrary\\steamapps\\common\\KingdomComeDeliverance2" hommes.ration=3 bandes.brigands.butin_par_tete=20
    py -3.13 outils/regler.py --jeu "…" --retirer hommes.ration      la valeur revient à la valeur validée
    py -3.13 outils/regler.py --jeu "…" --voir                       ce que dit le fichier
    py -3.13 outils/regler.py --liste                                toutes les valeurs réglables et leur valeur validée

Le fichier écrit est <jeu>\\Mods\\scriptorium_socle\\reglages.lua. Il ne contient que des données :
    return { hommes = { ration = 3 } }
Le socle le relit à l'entrée en partie puis toutes les deux secondes, et l'applique dès qu'il change.
Une virgule décimale est acceptée (« 0,1 »).

Garanties :
- n'écrit que dans <jeu>\\Mods\\scriptorium_socle, par les mêmes refus que noyau/installer.py, et seulement
  si le socle y est installé ;
- chaque valeur est d'abord éprouvée par le code du socle lui-même (morceau « reglages ») : une valeur que le
  socle refuserait n'est pas écrite, et la raison est dite ;
- écrit d'abord un fichier provisoire puis le met en place d'un coup : le jeu ne lit jamais un fichier à moitié écrit.
"""

import os
import re
import sys

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCRIPTS = os.path.join(RACINE, "socle", "pak", "Scripts")
DEMARRAGE = os.path.join(SCRIPTS, "Mods", "scriptorium_socle.lua")
NOM_DU_FICHIER = "reglages.lua"

sys.path.insert(0, os.path.join(RACINE, "noyau"))
import installer  # noqa: E402

MOTIF_CHARGEMENT = re.compile(r'Script\.ReloadScript\("Scripts/scriptorium/([a-z_]+\.lua)"\)')
MOTIF_NOM = re.compile(r"^[a-z_][a-z0-9_]*$")
# Ni la liaison (elle parle au moteur), ni le poste d'essai : le reste du socle suffit à éprouver une valeur.
ECARTES = {"liaison.lua", "poste.lua"}

# Ce que le socle demande au jeu en se chargeant : le journal seulement.
JEU_MINIMAL = """
Scriptorium = Scriptorium or {}
Scriptorium.jeu = { lignes = {} }
function Scriptorium.jeu.journal(texte) table.insert(Scriptorium.jeu.lignes, tostring(texte)) end
function Scriptorium.jeu.maintenant() return 0 end
function Scriptorium.jeu.heure_du_jeu() return 0 end
"""


def refuser(message):
    installer.refuser(message)


def lire(chemin):
    with open(chemin, "r", encoding="utf-8") as fichier:
        return fichier.read()


def ordre_de_chargement():
    """L'ordre des morceaux, lu dans le démarrage du socle (une seule source)."""
    return [nom for nom in MOTIF_CHARGEMENT.findall(lire(DEMARRAGE)) if nom not in ECARTES]


def charger_le_socle():
    try:
        from lupa import lua51
    except ImportError:
        refuser("lupa (Lua 5.1) absent : py -3.13 -m pip install lupa")
    lua = lua51.LuaRuntime(unpack_returned_tuples=True)
    executer = lua.eval("function(code, nom) local f, err = loadstring(code, nom) if not f then error(err, 0) end return f() end")
    executer(JEU_MINIMAL, "=jeu_minimal")
    for nom in ordre_de_chargement():
        executer(lire(os.path.join(SCRIPTS, "scriptorium", nom)), "=" + nom)
    return lua


# ------------------------------------------------------------------ tables Lua <-> dictionnaires

def vers_lua(lua, valeur):
    if isinstance(valeur, dict):
        table = lua.table()
        for cle, sous_valeur in valeur.items():
            table[cle] = vers_lua(lua, sous_valeur)
        return table
    return valeur


def depuis_lua(lua, valeur):
    if lua.eval("type")(valeur) == "table":
        return {cle: depuis_lua(lua, sous_valeur) for cle, sous_valeur in valeur.items()}
    return valeur


def lire_le_fichier(chemin):
    """Le fichier de réglages en dictionnaire ; {} s'il n'existe pas. Lu comme le lit le socle : données seules."""
    if not os.path.exists(chemin):
        return {}
    from lupa import lua51
    lua = lua51.LuaRuntime(unpack_returned_tuples=True)
    charger = lua.eval("function(code) local f, err = loadstring(code) if not f then error(err, 0) end "
                       "setfenv(f, {}) return f() end")
    try:
        donnees = charger(lire(chemin))
    except Exception as exception:  # noqa: BLE001
        refuser("fichier de réglages illisible (%s) : %s" % (chemin, exception))
    if lua.eval("type")(donnees) != "table":
        refuser("le fichier de réglages ne rend pas de table : " + chemin)
    return depuis_lua(lua, donnees)


def texte_du_nombre(valeur):
    if isinstance(valeur, bool) or not isinstance(valeur, (int, float)):
        raise ValueError("pas un nombre : %r" % (valeur,))
    if isinstance(valeur, float) and valeur.is_integer():
        return str(int(valeur))
    return repr(valeur)


def contenu(donnees, marge="  "):
    """Le texte Lua du fichier : noms triés, ASCII."""
    def ecrire_table(table, retrait):
        lignes = ["{"]
        for cle in sorted(table):
            valeur = table[cle]
            if isinstance(valeur, dict):
                lignes.append("%s%s%s = %s," % (retrait, marge, cle, ecrire_table(valeur, retrait + marge)))
            else:
                lignes.append("%s%s%s = %s," % (retrait, marge, cle, texte_du_nombre(valeur)))
        lignes.append(retrait + "}")
        return "\n".join(lignes)
    if not donnees:
        return "return {}\n"
    return "return " + ecrire_table(donnees, "") + "\n"


# ------------------------------------------------------------------ chemins et valeurs

def lire_la_valeur(texte):
    texte = texte.strip().replace(",", ".")
    try:
        return int(texte)
    except ValueError:
        pass
    try:
        return float(texte)
    except ValueError:
        refuser("pas un nombre : %s" % texte)


def morceaux_du_chemin(chemin):
    morceaux = chemin.split(".")
    if len(morceaux) < 2 or not all(MOTIF_NOM.match(m) for m in morceaux):
        refuser("chemin mal formé : %s (exemple : hommes.ration)" % chemin)
    return morceaux


def poser(donnees, chemin, valeur):
    table = donnees
    morceaux = morceaux_du_chemin(chemin)
    for morceau in morceaux[:-1]:
        suivant = table.get(morceau)
        if not isinstance(suivant, dict):
            suivant = {}
            table[morceau] = suivant
        table = suivant
    table[morceaux[-1]] = valeur


def retirer(donnees, chemin):
    """Retire une valeur du fichier, et les sections restées vides. Vrai si elle y était."""
    def enlever(table, reste):
        if len(reste) == 1:
            if reste[0] not in table:
                return False
            del table[reste[0]]
            return True
        suivant = table.get(reste[0])
        if not isinstance(suivant, dict):
            return False
        fait = enlever(suivant, reste[1:])
        if fait and not suivant:
            del table[reste[0]]
        return fait
    return enlever(donnees, morceaux_du_chemin(chemin))


def feuilles(donnees, prefixe=""):
    for cle in sorted(donnees):
        chemin = prefixe + cle
        if isinstance(donnees[cle], dict):
            yield from feuilles(donnees[cle], chemin + ".")
        else:
            yield chemin, donnees[cle]


def eprouver(lua, donnees):
    """Les refus que ferait le socle pour ce contenu : [(chemin, valeur, raison)]."""
    reglages = lua.globals().Scriptorium.reglages
    _, refus = reglages.poser_les_valeurs(vers_lua(lua, donnees), "lancement")
    resultat = [(r.chemin, r.valeur, r.raison) for r in refus.values()]
    reglages.poser_les_valeurs(vers_lua(lua, {}), "lancement")
    return resultat


def ecrire(dossier, donnees):
    chemin = os.path.join(dossier, NOM_DU_FICHIER)
    provisoire = chemin + ".provisoire"
    with open(provisoire, "wb") as fichier:
        fichier.write(contenu(donnees).encode("ascii"))
    os.replace(provisoire, chemin)
    return chemin


# ------------------------------------------------------------------ principal

def principal(arguments):
    if "--liste" in arguments:
        lua = charger_le_socle()
        for valeur in lua.globals().Scriptorium.reglages.liste_des_valeurs().values():
            print("%s = %s" % (valeur.chemin, texte_du_nombre(valeur.validee)))
        return 0
    if "--jeu" not in arguments or arguments.index("--jeu") + 1 >= len(arguments):
        print(__doc__)
        return 2
    position = arguments.index("--jeu")
    jeu = arguments[position + 1]
    reste = arguments[:position] + arguments[position + 2:]
    cible = installer.verifier_cible(jeu)
    if not os.path.isfile(os.path.join(cible, "mod.manifest")):
        refuser("le socle n'est pas installé dans " + cible)
    chemin = os.path.join(cible, NOM_DU_FICHIER)
    donnees = lire_le_fichier(chemin)
    if reste == ["--voir"]:
        if not donnees:
            print("Pas de réglage dans le fichier : les valeurs validées s'appliquent.")
        for cle, valeur in feuilles(donnees):
            print("%s = %s" % (cle, texte_du_nombre(valeur)))
        return 0
    if not reste:
        print(__doc__)
        return 2
    installer.exiger_une_seance()
    if reste[0] == "--retirer":
        for chemin_de_valeur in reste[1:]:
            if not retirer(donnees, chemin_de_valeur):
                print("Rien à retirer pour %s" % chemin_de_valeur)
    else:
        for argument in reste:
            if "=" not in argument:
                refuser("attendu chemin=valeur : %s" % argument)
            chemin_de_valeur, texte = argument.split("=", 1)
            poser(donnees, chemin_de_valeur.strip(), lire_la_valeur(texte))
    refus = eprouver(charger_le_socle(), donnees)
    if refus:
        for chemin_refuse, valeur, raison in refus:
            print("Refusé par le socle : %s = %s (%s)" % (chemin_refuse, valeur, raison))
        refuser("rien n'est écrit")
    ecrit = ecrire(cible, donnees)
    print("Réglages écrits : %s" % ecrit)
    for cle, valeur in feuilles(donnees):
        print("  %s = %s" % (cle, texte_du_nombre(valeur)))
    return 0


if __name__ == "__main__":
    sys.exit(principal(sys.argv[1:]))
