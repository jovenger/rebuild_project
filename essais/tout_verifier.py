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
    if len(connues) != 26:
        erreur("ordres : %d commandes lues dans poste.lua, 26 attendues" % len(connues))
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


def verifier_identifiants():
    """Les entités posées par la vraie liaison sont désignées par leur nom (une chaîne que le registre
    sait garder), pas par entite.id, donnée du moteur refusée au registre (vu en jeu le 14/10)."""
    lua = runtime_lua()
    if lua is None:
        return
    lua.execute("""
        System = { entites = {} }
        function System.GetEntityByName(nom) return System.entites[nom] end
        function System.GetTerrainElevation(p) return 7 end
        function System.SpawnEntity(p)
          System.derniere_orientation = p.orientation
          System.derniere_position = p.position
          local e = { id = newproxy(), name = p.name }
          function e:SetWorldAngles(a) System.derniers_angles = a end
          System.entites[p.name] = e
          return e
        end
        function System.RemoveEntity(id)
          for nom, e in pairs(System.entites) do if e.id == id then System.entites[nom] = nil end end
        end
        function System.LogAlways() end
    """)
    lua.execute(lire(os.path.join(PAK, "Scripts", "scriptorium", "liaison.lua")))
    resultat = lua.eval("""(function()
        local l = Scriptorium.liaison_reelle
        local p = { x = 1, y = 2, z = 3 }
        local a = l.poser_objet("feu", "modele", p, 90, "feu_central")
        local b = l.poser_objet("feu", "modele", p, 90, "feu_central")
        if a ~= "scriptorium_feu_central" then return "premier nom : " .. tostring(a) end
        if b ~= "scriptorium_feu_central_2" then return "second nom : " .. tostring(b) end
        if not l.objet_existe(a) then return "objet posé introuvable" end
        if System.derniere_position.z ~= 7 then return "objet non posé au sol : z = " .. tostring(System.derniere_position.z) end
        l.retirer_objet(a)
        if l.objet_existe(a) then return "objet retiré encore là" end
        if not l.objet_existe(b) then return "l'autre objet a disparu" end
        local h = l.poser_objet("lit", "modele", p, 0, "Mikuláš Kladivo")
        if h ~= "scriptorium_Mikul_____Kladivo" then return "nom d'entité hors ASCII ou mal formé" end
        -- Henry face à l'ouest : +90° pour le moteur, 270° en cap de boussole ; et retour (vu en jeu le 14/10).
        player = { GetWorldAngles = function() return { x = 0, y = 0, z = math.rad(90) } end }
        local cap = l.cap_du_joueur()
        if math.abs(cap - 270) > 1e-6 then return "cap d'Henry face à l'ouest : " .. tostring(cap) .. ", 270 attendu" end
        l.poser_objet("tente", "modele", p, cap, "tente")
        -- « orientation » est un vecteur de direction (l'avant), à l'horizontale ; les angles sont posés à part.
        local o = System.derniere_orientation
        if math.abs(o.x + 1) > 1e-6 or math.abs(o.y) > 1e-6 or o.z ~= 0 then
          return "objet posé à 270 : avant (" .. o.x .. ", " .. o.y .. ", " .. o.z .. "), l'ouest (-1, 0, 0) attendu"
        end
        if math.abs(System.derniers_angles.z - math.pi / 2) > 1e-6 then
          return "objet posé à 270 : angle moteur " .. tostring(System.derniers_angles.z) .. ", +90° attendu"
        end
        -- Registre : par le jeton du jeu, relu même sans la mémoire ; mémoire de secours sans jeton.
        GameToken = { valeurs = {} }
        function GameToken.SetToken(nom, valeur) GameToken.valeurs[nom] = valeur end
        function GameToken.GetToken(nom) return GameToken.valeurs[nom] end
        l.ecrire_registre("{a=1}")
        l.memoire.registre = nil
        if l.lire_registre() ~= "{a=1}" then return "registre non relu depuis le jeton" end
        local marque = nil
        for nom in pairs(System.entites) do
          if string.find(nom, "^scriptorium_registre_") then marque = nom end
        end
        if not marque then return "pas de marque de la partie posée dans le monde" end
        -- Une autre partie (sauvegarde sans la marque) : le jeton est ignoré (vu en jeu le 14/10).
        System.entites[marque] = nil
        if l.lire_registre() ~= nil then return "le jeton d'une autre partie n'est pas ignoré" end
        l.ecrire_registre("{c=3}")
        if l.lire_registre() ~= "{c=3}" then return "nouvelle partie : registre non relu après marquage" end
        GameToken = nil
        l.memoire.registre = "{b=2}"
        if l.lire_registre() ~= "{b=2}" then return "sans jeton, la mémoire de secours n'est pas lue" end
        -- Bataille (V18) : hostilité dans les deux sens, cibles à tour de rôle, et une description qui ne casse pas
        -- quand le moteur n'a pas la fonction demandée.
        AI = { paires = {}, cibles = {} }
        function AI.AddPersonallyHostile(a, b) table.insert(AI.paires, { a, b }) end
        function AI.AddAggressiveTarget(a, b) table.insert(AI.cibles, { a, b }) end
        function AI.GetFactionOf(id) return "brigands" end
        local e1 = l.faire_venir_ennemis("brigands", 2, p, 0)
        local n1 = l.faire_venir_homme("archer", "homme_1", p)
        if type(e1) ~= "table" or #e1 ~= 2 or not n1 then return "ennemis ou homme non venus" end
        local faites = l.rendre_hostiles(e1, { n1 })
        if faites ~= 2 or #AI.paires ~= 4 then return "hostilité : " .. tostring(faites) .. " paire(s), " .. #AI.paires .. " appel(s), 2 et 4 attendus" end
        if AI.paires[1][1] ~= System.entites[e1[1]].id or AI.paires[2][1] ~= System.entites[n1].id then return "hostilité : pas dans les deux sens" end
        if l.cibler(e1, { n1 }) ~= 2 or AI.cibles[2][2] ~= System.entites[n1].id then return "cibles mal données" end
        local lignes = l.decrire_personnage(e1[1], n1, true)
        local texte = table.concat(lignes, " | ")
        if not string.find(texte, "faction = brigands", 1, true) then return "description sans faction : " .. texte end
        if not string.find(texte, "personnellement = absente", 1, true) then return "fonction absente mal dite : " .. texte end
        if l.decrire_personnage("personne")[1] ~= "introuvable" then return "personnage absent mal dit" end
        AI = nil
        return "ok"
    end)()""")
    if resultat != "ok":
        erreur("liaison : identifiants d'entités : " + str(resultat))


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

def verifier_releve_des_noms():
    """Le relevé des noms ne prend que les définitions (affectations, fonctions), jamais les comparaisons."""
    noms = set(outil_empreintes.noms_du_lua("if a.role == 1 then end\nif b.total ~= 2 then end\nif c.lieu <= 3 then end"))
    if noms:
        erreur("contrôle d'absence : des comparaisons sont relevées comme des noms : " + ", ".join(sorted(noms)))
    noms = set(outil_empreintes.noms_du_lua("a.metier = 1\nfunction b.chercher() end"))
    if not {"metier", "chercher"} <= noms:
        erreur("contrôle d'absence : une affectation ou une fonction n'est pas relevée : " + ", ".join(sorted(noms)))
    # Le nom d'un fichier imposé par le jeu (mod.manifest) n'est pas un nom choisi ; un autre nom de fichier l'est.
    import tempfile
    with tempfile.TemporaryDirectory() as dossier:
        for nom in ("mod.manifest", "camp.lua"):
            with open(os.path.join(dossier, nom), "w", encoding="utf-8") as fichier:
                fichier.write("-- essai\n")
        releve, _ = outil_empreintes.relever(dossier)
        if outil_empreintes.empreinte("mod") in releve["noms"] or outil_empreintes.empreinte("camp") not in releve["noms"]:
            erreur("contrôle d'absence : noms de fichiers mal relevés (imposés par le jeu ou choisis)")


def controle_absence(strict):
    verifier_releve_des_noms()
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
            verifier_identifiants()
            print("2 ter. liaison : entités désignées par leur nom, caps de boussole, pose au sol, registre par jeton, vérifié")
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
