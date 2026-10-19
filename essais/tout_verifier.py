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
import zipfile

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOCLE = os.path.join(RACINE, "socle")
PAK = os.path.join(SOCLE, "pak")
TEXTES = os.path.join(SOCLE, "textes")
ESSAIS_LUA = os.path.join(RACINE, "essais", "lua")
EMPREINTES = os.path.join(RACINE, "docs", "socle", "empreintes_alex.json")

sys.path.insert(0, os.path.join(RACINE, "outils"))
sys.path.insert(0, os.path.join(RACINE, "noyau"))
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

ORDRE_SOCLE = ["noyau.lua", "bandeau.lua", "registre.lua", "coffre.lua", "camp.lua", "hommes.lua", "bataille.lua", "directeur.lua", "enceinte.lua", "atelier.lua", "patrouilles.lua", "missions.lua", "discipline.lua", "caractere.lua", "reglages.lua", "poste.lua"]


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
    if len(connues) != 218:
        erreur("ordres : %d commandes lues dans poste.lua, 218 attendues" % len(connues))
    lua = runtime_lua()
    if lua is None:
        return len(connues)
    chemin_liaison = os.path.join(PAK, "Scripts", "scriptorium", "liaison.lua")
    lua.execute(lire(os.path.join(PAK, "Scripts", "scriptorium", "noyau.lua")))
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


def verifier_reglages_par_fichier():
    """Fiche 10 : un fichier écrit par outils/regler.py est relu tel quel par la vraie liaison ; l'outil fait
    éprouver chaque valeur par le socle avant d'écrire ; l'installateur garde le fichier d'une installation à l'autre.
    Rend le nombre de valeurs réglables."""
    import tempfile
    import regler
    import installer
    lua = runtime_lua()
    if lua is None:
        return 0
    socle = regler.charger_le_socle()
    nombre = len(socle.globals().Scriptorium.reglages.liste_des_valeurs())
    if nombre < 100:
        erreur("réglages : %d valeurs réglables seulement" % nombre)
    if regler.eprouver(socle, {"hommes": {"ration": 3}, "issues": {"victoire": {"blesses": 0.1}}}):
        erreur("réglages : des valeurs justes refusées par l'outil")
    refus = regler.eprouver(socle, {"hommes": {"ration": 2.5}, "magie": {"mana": 1}})
    if sorted(r[2] for r in refus) != ["pas_entier", "section_inconnue"]:
        erreur("réglages : refus de l'outil inattendus : %s" % refus)
    donnees = {}
    regler.poser(donnees, "hommes.ration", regler.lire_la_valeur("3"))
    regler.poser(donnees, "issues.victoire.blesses", regler.lire_la_valeur("0,1"))
    if not regler.retirer(donnees, "hommes.ration") or "hommes" in donnees:
        erreur("réglages : retirer une valeur devrait vider sa section")
    regler.poser(donnees, "hommes.ration", 3)
    lua.execute(lire(os.path.join(PAK, "Scripts", "scriptorium", "noyau.lua")))
    lua.execute(lire(os.path.join(PAK, "Scripts", "scriptorium", "liaison.lua")))
    liaison = lua.globals().Scriptorium.liaison_reelle
    with tempfile.TemporaryDirectory() as dossier:
        chemin = regler.ecrire(dossier, donnees)
        liaison.chemins_des_reglages = lua.table_from([os.path.join(dossier, "absent.lua"), chemin])
        lu, lu_a = liaison.lire_reglages()
        if lu is None or lu_a != chemin or lu.hommes.ration != 3 or abs(lu.issues.victoire.blesses - 0.1) > 1e-12:
            erreur("réglages : le fichier écrit par l'outil n'est pas relu tel quel par la liaison")
        if regler.lire_le_fichier(chemin) != donnees:
            erreur("réglages : l'outil ne relit pas ce qu'il a écrit")
        with open(chemin, "w", encoding="ascii") as fichier:
            fichier.write("return { hommes = { ration = tostring(os) } }\n")
        lu, _, raison = liaison.lire_reglages()
        if lu is not None or not raison:
            erreur("réglages : un fichier qui appelle le jeu devrait être refusé (environnement vide)")
        cible = os.path.join(dossier, "Mods", installer.NOM_DU_MOD)
        os.makedirs(cible)
        with open(os.path.join(cible, installer.NOM_DES_REGLAGES), "w", encoding="ascii") as fichier:
            fichier.write("return { hommes = { ration = 4 } }\n")
        sortie = sys.stdout
        try:
            sys.stdout = open(os.devnull, "w", encoding="utf-8")
            installer.installer(cible)
        finally:
            sys.stdout.close()
            sys.stdout = sortie
        if not os.path.isfile(os.path.join(cible, "mod.manifest")):
            erreur("réglages : l'installation d'essai n'a pas posé le socle")
        if regler.lire_le_fichier(os.path.join(cible, installer.NOM_DES_REGLAGES)) != {"hommes": {"ration": 4}}:
            erreur("réglages : l'installateur n'a pas gardé le fichier de réglages")
    return nombre


def verifier_seances():
    """Après la bascule (19/10/2026) : l'installateur, ordonner, regler et recharger n'écrivent dans
    Mods\\scriptorium_socle (le mod de tous les jours de JoVenGer) que pendant une séance ouverte par le programme
    Scriptorium (installer.seance_ouverte). Rend le nombre de cas éprouvés."""
    import tempfile
    import installer
    import ordonner
    import recharger
    import regler

    def etat(dossier, nom, contenu):
        os.makedirs(os.path.join(dossier, nom))
        if contenu is not None:
            with open(os.path.join(dossier, nom, "etat.txt"), "wb") as fichier:
                fichier.write(contenu)

    cas = 0
    with tempfile.TemporaryDirectory() as dossier:
        seances = os.path.join(dossier, "Scriptorium_securite")
        ouverte_a = "20261019_120000_000003_seance_du_socle"
        # Chaque étape remplit un peu plus le dossier, puis la séance attendue (None : pas de séance).
        etapes = [
            (lambda: None, None),                                                       # dossier absent
            (lambda: os.makedirs(seances), None),                                       # aucune séance
            (lambda: etat(seances, "20261019_084036_seance_du_socle", None), None),     # ancien, sans etat.txt
            (lambda: etat(seances, "20261019_090000_123456_seance_du_socle", b"en cours"),
             "20261019_090000_123456_seance_du_socle"),
            (lambda: etat(seances, "20261019_100000_000001_seance_du_socle", b"remise"), None),  # la dernière compte
            (lambda: etat(seances, "20261019_110000_000002_seance_du_socle", b"gardee"), None),
            (lambda: etat(seances, ouverte_a, "﻿  En Cours  \r\n".encode("utf-8")), ouverte_a),  # BOM, casse
            (lambda: open(os.path.join(seances, "20261019_130000_000004_seance_du_socle"), "w").close(),
             ouverte_a),                                                                # un fichier n'en est pas une
        ]
        for numero, (etape, nom) in enumerate(etapes, start=1):
            ouverte = nom is not None
            etape()
            vu, detail = installer.seance_ouverte(seances)
            cas += 1
            if vu != ouverte or (ouverte and detail != nom):
                erreur("séance, cas %d : attendu %s %s, vu %s %s" % (numero, ouverte, nom, vu, detail))

        # Les outils refusent AVANT d'écrire, et écrivent pendant une séance.
        jeu = os.path.join(dossier, "jeu")
        cible = os.path.join(jeu, "Mods", installer.NOM_DU_MOD)
        os.makedirs(os.path.join(jeu, "Data"))
        os.makedirs(cible)
        with open(os.path.join(cible, "mod.manifest"), "w", encoding="ascii") as fichier:
            fichier.write("<kcd_mod/>")
        appels = [
            ("installateur", lambda: installer.principal(["--jeu", jeu, "--sans-verification", "--sans-mise-de-cote"])),
            ("ordonner", lambda: ordonner.principal(["--jeu", jeu, "scriptorium_bilan"])),
            ("regler", lambda: regler.principal(["--jeu", jeu, "--retirer", "hommes.ration"])),
            ("recharger", lambda: recharger.principal(["--jeu", jeu, "hommes"])),
        ]
        ancien = installer.SEANCES
        sortie = sys.stdout
        try:
            installer.SEANCES = os.path.join(dossier, "aucune")
            for nom, appel in appels:
                avant = sorted(os.listdir(cible))
                code = None
                try:
                    sys.stdout = open(os.devnull, "w", encoding="utf-8")
                    code = appel()
                except SystemExit as sortie_outil:
                    code = sortie_outil.code
                finally:
                    sys.stdout.close()
                    sys.stdout = sortie
                cas += 1
                if code != 2 or sorted(os.listdir(cible)) != avant:
                    erreur("séance : %s hors séance devrait refuser sans rien écrire (code %s)" % (nom, code))
            installer.SEANCES = seances
            try:
                sys.stdout = open(os.devnull, "w", encoding="utf-8")
                code = ordonner.principal(["--jeu", jeu, "scriptorium_bilan"])
            finally:
                sys.stdout.close()
                sys.stdout = sortie
            cas += 1
            if code != 0 or not os.path.isfile(os.path.join(cible, ordonner.NOM_DU_FICHIER)):
                erreur("séance : pendant une séance, ordonner devrait écrire son ordre")
        finally:
            installer.SEANCES = ancien
            sys.stdout = sortie
    return cas


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
    lua.execute(lire(os.path.join(PAK, "Scripts", "scriptorium", "noyau.lua")))
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
        -- V73 f 3 b (relecture du pair) : sans marque ici et avec la même identité, un passage de carte n'est cru qu'à
        -- trois conditions : la carte a changé, l'horloge a avancé de 10 jours au plus depuis la dernière écriture.
        local heure_avant_l = l.heure_du_jeu
        local h_l = 100
        l.heure_du_jeu = function() return h_l end
        l.ecrire_registre("{a=1}")
        l.memoire.registre = nil   -- vidée à chaque entrée en partie, comme en jeu
        l.accrocher_le_passage(function(avant, maintenant) return avant ~= nil and maintenant >= avant and maintenant - avant <= 240 end)
        System.entites[marque] = nil
        l.memoire.carte_d_avant, l.memoire.carte = "kutnohorsko", "kutnohorsko"
        if l.lire_registre() ~= nil then return "ancienne sauvegarde sans jeton, même carte : le jeton n'est pas ignoré" end
        if System.entites[marque] then return "même carte : une marque posée à tort" end
        l.memoire.carte_d_avant, l.memoire.carte = "kutnohorsko", "trosecko"
        h_l = 90
        if l.lire_registre() ~= nil then return "autre carte, horloge en arrière : le jeton n'est pas ignoré" end
        h_l = 100 + 11 * 24
        if l.lire_registre() ~= nil then return "autre carte, onze jours plus tard : le jeton n'est pas ignoré" end
        l.accrocher_le_passage(nil)
        h_l = 130
        if l.lire_registre() ~= nil then return "sans règle du passage, un passage est cru" end
        l.accrocher_le_passage(function(avant, maintenant) return avant ~= nil and maintenant >= avant and maintenant - avant <= 240 end)
        if l.lire_registre() ~= "{a=1}" then return "passage de carte : le jeton de la même partie n'est pas cru" end
        if not System.entites[marque] then return "passage de carte : la marque n'est pas posée sur la nouvelle carte" end
        l.heure_du_jeu = heure_avant_l
        l.accrocher_le_passage(nil)
        l.memoire.carte_d_avant, l.memoire.carte = nil, nil
        -- Une autre partie (sauvegarde sans la marque, une autre identité en mémoire) : le jeton est ignoré (vu en jeu le
        -- 14/10).
        System.entites[marque] = nil
        local identite_avant = l.memoire.identite
        l.memoire.identite = "p_une_autre_partie"
        if l.lire_registre() ~= nil then return "le jeton d'une autre partie n'est pas ignoré" end
        if System.entites[marque] then return "une autre partie : sa marque posée à tort" end
        l.memoire.identite = identite_avant
        l.ecrire_registre("{c=3}")
        if l.lire_registre() ~= "{c=3}" then return "nouvelle partie : registre non relu après marquage" end
        GameToken = nil
        l.memoire.registre = "{b=2}"
        if l.lire_registre() ~= "{b=2}" then return "sans jeton, la mémoire de secours n'est pas lue" end
        -- Bataille (V18, V19) : une description qui ne casse pas quand le moteur n'a pas la fonction demandée.
        AI = {}
        function AI.GetFactionOf(id) return "brigands" end
        local e1 = l.faire_venir_ennemis("brigands", 2, p, 0)
        local n1 = l.faire_venir_homme(l.ame_de("combattant", 1, 1), "homme_1", p)
        if type(e1) ~= "table" or #e1 ~= 2 or not n1 then return "ennemis ou homme non venus" end
        local lignes = l.decrire_personnage(e1[1], n1, true)
        local texte = table.concat(lignes, " | ")
        if not string.find(texte, "faction = brigands", 1, true) then return "description sans faction : " .. texte end
        if not string.find(texte, "personnellement = absente", 1, true) then return "fonction absente mal dite : " .. texte end
        if l.decrire_personnage("personne")[1] ~= "introuvable" then return "personnage absent mal dit" end
        -- Blesser (soul:DealDamage : vie, endurance, rien, vrai ; vu en jeu le 14/10, V19).
        local brigand = System.entites[e1[1]]
        brigand.soul = { DealDamage = function(self, vie, endurance, rien, drapeau) AI.coup = { vie, endurance, drapeau } end }
        if not l.blesser(e1[1], 1000) or AI.coup[1] ~= 1000 or AI.coup[2] ~= 1000 or AI.coup[3] ~= true then return "blessure mal donnée" end
        if l.blesser("personne", 1) then return "un absent blessé" end
        AI = nil
        -- Personnages : les propriétés données remplacent celles de la classe (vu le 14/10 : avec la seule âme, ils
        -- restaient inertes) ; un personnage reçoit une copie des propriétés de sa classe, plus son âme. Les objets,
        -- non (une copie de leurs propriétés physiques n'a pas été essayée en jeu).
        NPC = { Properties = { bWH_PerceptorObject = true, esNavigationType = "MediumSizedCharacters", CharacterSounds = { foleyEffect = "foleys_npc" } } }
        local recu = nil
        local naissance_d_origine = System.SpawnEntity
        function System.SpawnEntity(params) recu = params.properties ; return naissance_d_origine(params) end
        local h2 = l.faire_venir_homme(l.ame_de("combattant", 1, 2), "homme_2", p)
        if not h2 or not recu then return "personnage non venu" end
        if recu.guidSharedSoulId ~= "5c7a5c7a-0001-4001-8000-000000000002" then return "âme perdue dans les propriétés complètes" end
        if l.faire_venir_homme(nil, "homme_3", p) ~= nil then return "un homme venu sans âme" end
        if l.ame_de("combattant", 4, 1) or l.ame_de("combattant", 1, 81) or l.ame_de("femme", 1, 0) or l.ame_de("aucune", 1, 1) then
          return "âme rendue hors des réserves"
        end
        if recu.bWH_PerceptorObject ~= true or recu.esNavigationType ~= "MediumSizedCharacters" then return "propriétés de la classe NPC perdues" end
        recu.CharacterSounds.foleyEffect = "change"
        if NPC.Properties.CharacterSounds.foleyEffect ~= "foleys_npc" then return "propriétés de la classe partagées au lieu d'être copiées" end
        if NPC.Properties.guidSharedSoulId ~= nil then return "l'âme écrite dans la classe du jeu" end
        l.poser_objet("feu", "modele", p, 0, "feu_x")
        if recu.bWH_PerceptorObject ~= nil or recu.object_Model ~= "modele" then return "un objet a reçu les propriétés d'un personnage" end
        System.SpawnEntity = naissance_d_origine
        NPC = nil
        -- Argent d'Henry (règle de JoVenGer) : jamais un retrait de zéro, négatif, non entier, au-dessus de la bourse,
        -- ni avec une bourse illisible ; le 10/10, RemoveMoney(0) a vidé toute la bourse. Le moteur n'est jamais appelé
        -- pour un montant refusé.
        local bourse, appels = 100, {}
        player = { inventory = {
          GetMoney = function(self) return bourse end,
          RemoveMoney = function(self, n) table.insert(appels, "retirer " .. tostring(n)); bourse = bourse - n end,
          AddMoney = function(self, n) table.insert(appels, "donner " .. tostring(n)); bourse = bourse + n end,
        } }
        for _, montant in ipairs({ 0, -5, 2.5, 101, "10", 0 / 0, math.huge }) do
          if l.retirer_groschen_a_henry(montant) then return "retrait accepté : " .. tostring(montant) end
        end
        -- Relecture du pair (17/10) : le versement a les gardes du retrait, plafond compris (1 000 000 par défaut).
        local journal_d_origine, refus = l.journal, 0
        l.journal = function(texte) if string.find(texte, "versement refusé", 1, true) then refus = refus + 1 end end
        for _, montant in ipairs({ 0, -3, 1.5, "5", 0 / 0, math.huge, -math.huge, 1000001, 1e12 }) do
          if l.donner_groschen_a_henry(montant) then return "versement accepté : " .. tostring(montant) end
        end
        l.journal = journal_d_origine
        if refus ~= 9 then return "une ligne au journal par versement refusé : " .. refus .. " sur 9" end
        local plafond_avant = Scriptorium.noyau.reglages.argent_d_henry_max
        Scriptorium.noyau.reglages.argent_d_henry_max = nil
        if l.donner_groschen_a_henry(5) then return "versement accepté sans plafond lisible" end
        Scriptorium.noyau.reglages.argent_d_henry_max = 20
        if l.donner_groschen_a_henry(21) then return "versement accepté au-dessus d'un plafond réglé à 20" end
        Scriptorium.noyau.reglages.argent_d_henry_max = plafond_avant
        if #appels > 0 then return "le moteur a été appelé pour un montant refusé : " .. appels[1] end
        if not l.retirer_groschen_a_henry(100) or bourse ~= 0 then return "retrait juste refusé" end
        if not l.donner_groschen_a_henry(30) or bourse ~= 30 then return "versement juste refusé" end
        player.inventory.GetMoney = function(self) error("bourse illisible") end
        if l.retirer_groschen_a_henry(10) then return "retrait accepté avec une bourse illisible" end
        if #appels ~= 2 then return "appels au moteur inattendus : " .. #appels end
        player = nil
        -- Registre en tranches (note de JoVenGer : aucune valeur de plus de 65 535 octets). Un registre de 200 Ko se
        -- coupe, se recolle et se relit à l'identique ; une tranche abîmée ou d'une autre partie fait tout refuser.
        GameToken = { valeurs = {} }
        function GameToken.SetToken(nom, valeur) GameToken.valeurs[nom] = valeur end
        function GameToken.GetToken(nom) return GameToken.valeurs[nom] end
        local morceaux = {}
        for i = 1, 4000 do morceaux[i] = string.format("[%d]={[\\"nom\\"]=\\"homme_%d\\",[\\"moral\\"]=%d},", i, i, i % 100) end
        local gros = "{" .. table.concat(morceaux) .. "}"
        while #gros < 200000 do gros = "{[1]=" .. gros .. "}" end
        l.ecrire_registre(gros)
        l.memoire.registre = nil
        if l.lire_registre() ~= gros then return "registre de " .. #gros .. " octets mal recollé" end
        local tranches, plus_long = 0, 0
        for nom, valeur in pairs(GameToken.valeurs) do
          if string.find(nom, "^scriptorium_socle%.registre%.%d+$") and valeur ~= "" then
            tranches = tranches + 1
            plus_long = math.max(plus_long, #valeur)
          end
        end
        if tranches ~= math.ceil(#gros / l.taille_des_tranches) then return "nombre de tranches : " .. tranches end
        -- Le Lua du jeu compte en simple précision et écrit les grands nombres « 1.03997e+09 » (vu en jeu le 15/10) :
        -- l'en-tête ne porte que des chiffres, et sa somme reste sous 65 521.
        local entete = GameToken.valeurs["scriptorium_socle.registre"]
        local somme = tonumber(string.match(entete, "^[%w_]+|tranches|%d+|%d+|(%d+)$") or "")
        if not somme or somme >= 65521 then return "en-tête mal formé : " .. entete end
        if not string.find(l.entete_du_registre("p1", 2, string.rep("x", 1000000)), "^p1|tranches|2|1000000|%d+$") then
          return "en-tête d'un million de caractères mal écrit"
        end
        GameToken.valeurs["scriptorium_socle.registre"] = string.match(entete, "^([%w_]+)|") .. "|tranches|1|5434|1.03997e+09"
        l.memoire.registre = "{secours=1}"
        if l.lire_registre() ~= "{secours=1}" then return "un en-tête illisible n'est pas refusé" end
        GameToken.valeurs["scriptorium_socle.registre"] = entete
        l.memoire.registre = nil
        -- Les calculs qui doivent rester justes dans le jeu : mêmes valeurs qu'au banc, et aucun produit du hasard
        -- au-dessus de 2^24.
        local justes, ligne = l.verifier_les_nombres()
        if not justes then return "nombres attendus faux au banc : " .. ligne end
        for i, module in ipairs(Scriptorium.modules_du_hasard) do
          if Scriptorium.facteurs_du_hasard[i] * (module - 1) >= 16777216 then return "hasard au-dessus de 2^24" end
        end
        if plus_long > 65535 then return "une tranche dépasse 65 535 octets : " .. plus_long end
        -- Aucun jeton au-delà de 65 535 octets, essais compris (vu en jeu le 15/10 : la sauvegarde ne se recharge plus).
        local poses = 0
        local pose_d_origine = GameToken.SetToken
        GameToken.SetToken = function(nom, valeur) poses = poses + 1 ; return pose_d_origine(nom, valeur) end
        if l.essayer_un_jeton(65536) or poses ~= 0 then return "un jeton d'essai de 65 536 octets a été écrit" end
        local relu, intact = l.essayer_un_jeton(65535)
        if relu ~= 65535 or not intact or poses ~= 1 then return "le jeton d'essai de 65 535 octets n'est pas écrit et relu" end
        GameToken.SetToken = pose_d_origine
        GameToken.valeurs["scriptorium_socle.essai_jeton_65535"] = nil
        local juste = GameToken.valeurs["scriptorium_socle.registre.2"]
        GameToken.valeurs["scriptorium_socle.registre.2"] = string.gsub(juste, "homme", "hommx", 1)
        if l.lire_registre() ~= nil then return "une tranche abîmée n'est pas refusée" end
        GameToken.valeurs["scriptorium_socle.registre.2"] = string.gsub(juste, "^[%w_]+|", "p_autre|")
        if l.lire_registre() ~= nil then return "une tranche d'une autre partie n'est pas refusée" end
        GameToken.valeurs["scriptorium_socle.registre.2"] = juste
        if l.lire_registre() ~= gros then return "registre non relu une fois la tranche rendue" end
        -- La ronde (fiche 15, V73 d 2) : appelée par l'arbre, la liaison pose le point suivant et le regard, et écrit la
        -- pause dans les variables de l'arbre ; sans accroche, sans pas, ou sur une erreur, rien ne casse, et le journal
        -- le dit.
        local lignes, journal_d_origine = {}, System.LogAlways
        System.LogAlways = function(texte) table.insert(lignes, texte) end
        XGenAIModule = { variables = {} }
        function XGenAIModule.SetBrainVariable(id, nom, valeur) XGenAIModule.variables[nom] = valeur end
        local rondier = { this = { id = "wuid_rondier" } }
        function rondier:GetName() return "scriptorium_rondier" end
        local donnees = { ronde_pause = "2000ms" }
        l.pas_de_ronde = nil
        l.au_point_de_ronde(rondier, donnees)
        if donnees.ronde_pause ~= "2000ms" or XGenAIModule.variables.scriptorium_essai_point then
          return "ronde sans accroche : quelque chose a été posé"
        end
        l.accrocher_la_ronde(function(nom)
          if nom ~= "scriptorium_rondier" then return nil, "homme inconnu" end
          return { point = { x = 3, y = 4 }, regard = { x = 10, y = 0 }, pause_ms = 6500, longue = true, ici = 1,
                   suivant = 2, pas = 1, ecart = 0.4 }
        end)
        l.au_point_de_ronde(rondier, donnees)
        local pose, vers = XGenAIModule.variables.scriptorium_essai_point, XGenAIModule.variables.scriptorium_regard
        if donnees.ronde_pause ~= "6500ms" then return "pause de la ronde : " .. tostring(donnees.ronde_pause) end
        if not pose or pose.x ~= 3 or pose.y ~= 4 or pose.z ~= 7 then return "point de la ronde mal posé" end
        if not vers or vers.x ~= 10 or vers.y ~= 0 or vers.z ~= 7 then return "regard de la ronde mal posé" end
        if l.buts["scriptorium_rondier"] ~= pose or l.regards["scriptorium_rondier"] ~= vers then
          return "but ou regard de la ronde non retenus pour le poste d'essai"
        end
        if l.pas_de_ronde_vus["scriptorium_rondier"] ~= 1 then return "pas de ronde non comptés" end
        if not string.find(lignes[#lignes], "pas 1, au point 1 (à 0.4 m), vers le point 2 (3.0, 4.0), pause 6500 ms (longue)", 1, true) then
          return "ligne du pas de ronde : " .. tostring(lignes[#lignes])
        end
        local autre = { this = { id = "wuid_autre" } }
        function autre:GetName() return "scriptorium_autre" end
        XGenAIModule.variables = {}
        donnees.ronde_pause = "2000ms"
        l.au_point_de_ronde(autre, donnees)
        if donnees.ronde_pause ~= "2000ms" or XGenAIModule.variables.scriptorium_essai_point then
          return "un homme sans ronde a reçu un pas"
        end
        if not string.find(lignes[#lignes], "aucun pas (homme inconnu)", 1, true) then return "sans pas, rien n'est dit" end
        l.accrocher_la_ronde(function() error("panne") end)
        l.au_point_de_ronde(rondier, donnees)
        if not string.find(lignes[#lignes], "Ronde : erreur au point", 1, true) then return "une erreur de la ronde n'est pas écrite" end
        l.au_point_de_ronde(nil, donnees)
        if not string.find(lignes[#lignes], "Ronde : erreur au point", 1, true) then return "une entité absente n'est pas dite" end
        -- Le rassemblement (fiche 15, V73 e) : l'ordre de poste écrit l'allure, 1 en courant, 0 sinon (une garde qui suit
        -- un briefing ne court pas).
        System.entites["scriptorium_rondier"] = rondier
        XGenAIModule.variables = {}
        local but_avant, regard_avant = l.buts["scriptorium_rondier"], l.regards["scriptorium_rondier"]
        l.ordonner("scriptorium_rondier", "rassemblement", { x = 1, y = 1 }, "briefing", nil, nil, { x = 2, y = 2 }, "course")
        if XGenAIModule.variables.scriptorium_allure ~= 1 then return "rassemblement : allure " .. tostring(XGenAIModule.variables.scriptorium_allure) end
        if not string.find(lignes[#lignes], "en courant", 1, true) then return "l'ordre ne dit pas « en courant »" end
        l.ordonner("scriptorium_rondier", "garde", { x = 1, y = 1 }, "poste_1", nil, nil, { x = 2, y = 2 })
        if XGenAIModule.variables.scriptorium_allure ~= 0 then return "garde : allure " .. tostring(XGenAIModule.variables.scriptorium_allure) end
        System.entites["scriptorium_rondier"] = nil
        l.buts["scriptorium_rondier"], l.regards["scriptorium_rondier"] = but_avant, regard_avant
        -- Suivre (fiche 15, V73 f 1) : le WUID du chef écrit avant l'ordre 14 ; un chef introuvable : une marche.
        System.entites["scriptorium_rondier"] = rondier
        player = { nom = "henry" }
        local suivi = { GetName = function() return "scriptorium_chef_d_essai" end }
        System.entites["scriptorium_chef_d_essai"] = suivi
        XGenAIModule.GetMyWUID = function(e) return e == player and "wuid_henry" or (e == suivi and "wuid_chef" or nil) end
        XGenAIModule.variables = {}
        l.ordonner("scriptorium_rondier", "suivre", { x = 1, y = 1 }, "escorte", nil, nil, nil, nil, "henry")
        if XGenAIModule.variables.scriptorium_chef ~= "wuid_henry" then return "suivre Henry : chef " .. tostring(XGenAIModule.variables.scriptorium_chef) end
        if not string.find(lignes[#lignes], "suit « henry »", 1, true) then return "la ligne ne dit pas qui il suit" end
        l.ordonner("scriptorium_rondier", "suivre", { x = 1, y = 1 }, "escorte", nil, nil, nil, nil, "scriptorium_chef_d_essai")
        if XGenAIModule.variables.scriptorium_chef ~= "wuid_chef" then return "suivre un homme : chef " .. tostring(XGenAIModule.variables.scriptorium_chef) end
        l.ordonner("scriptorium_rondier", "suivre", { x = 1, y = 1 }, "escorte", nil, nil, nil, nil, "personne")
        if not string.find(lignes[#lignes], "introuvable, marche", 1, true) then return "un chef introuvable : " .. lignes[#lignes] end
        -- V73 f 1 bis : mener une formation (ordre 15, le modèle retenu pour l'arbre), s'y ranger (ordre 16).
        l.ordonner("scriptorium_rondier", "suivre", { x = 1, y = 1 }, "escorte", nil, nil, nil, nil, "henry", { mode = "mener", formation = "followNPC" })
        if not string.find(lignes[#lignes], "mène la formation « followNPC »", 1, true) then return "mener : " .. lignes[#lignes] end
        local donnees_f = {}
        l.nom_de_la_formation(rondier, donnees_f)
        if donnees_f.formation_nom ~= "followNPC" then return "le modèle n'est pas écrit pour l'arbre : " .. tostring(donnees_f.formation_nom) end
        l.ordonner("scriptorium_rondier", "suivre", { x = 1, y = 1 }, "escorte", nil, nil, nil, nil, "scriptorium_chef_d_essai", { mode = "formation" })
        if not string.find(lignes[#lignes], "se range dans la formation", 1, true) then return "se ranger : " .. lignes[#lignes] end
        donnees_f = {}
        l.nom_de_la_formation(rondier, donnees_f)
        if donnees_f.formation_nom ~= nil then return "un suiveur reçoit un modèle à ouvrir" end
        l.nom_de_la_formation(nil, donnees_f)
        if not string.find(lignes[#lignes], "Formation : erreur", 1, true) then return "une entité absente n'est pas dite" end
        -- V73 f 2 a : à cheval (ordre 17, le WUID du cheval) ; un cheval introuvable, à pied (ordre 14).
        local monture = { GetName = function() return "scriptorium_cheval_essai" end }
        System.entites["scriptorium_cheval_essai"] = monture
        XGenAIModule.GetMyWUID = function(e) return e == player and "wuid_henry" or (e == monture and "wuid_cheval" or nil) end
        XGenAIModule.variables = {}
        l.ordonner("scriptorium_rondier", "suivre", { x = 1, y = 1 }, "cavaliers", nil, nil, nil, nil, "henry", { mode = "cheval", cheval = "scriptorium_cheval_essai" })
        if XGenAIModule.variables.scriptorium_cheval ~= "wuid_cheval" then return "à cheval : WUID " .. tostring(XGenAIModule.variables.scriptorium_cheval) end
        if not string.find(lignes[#lignes], "monte « scriptorium_cheval_essai »", 1, true) then return "à cheval : " .. lignes[#lignes] end
        -- V73 f 2 b : monter et mener (ordre 18, le modèle retenu), monter et se ranger (ordre 19) ; le compte des montes
        -- manquées lu dans le cerveau.
        l.ordonner("scriptorium_rondier", "suivre", { x = 1, y = 1 }, "cavaliers", nil, nil, nil, nil, "henry",
          { mode = "cheval", cheval = "scriptorium_cheval_essai", role = "mener", formation = "followNPC" })
        if not string.find(lignes[#lignes], "et mène la formation « followNPC »", 1, true)
            or not string.find(lignes[#lignes], "activité 18", 1, true) then return "mener à cheval : " .. lignes[#lignes] end
        if l.formations_menees["scriptorium_rondier"] ~= "followNPC" then return "mener à cheval : le modèle n'est pas retenu" end
        l.ordonner("scriptorium_rondier", "suivre", { x = 1, y = 1 }, "cavaliers", nil, nil, nil, nil, "henry",
          { mode = "cheval", cheval = "scriptorium_cheval_essai", role = "formation" })
        if not string.find(lignes[#lignes], "et se range dans la formation", 1, true)
            or not string.find(lignes[#lignes], "activité 19", 1, true) then return "se ranger à cheval : " .. lignes[#lignes] end
        local lire_avant = XGenAIModule.GetBrainVariable
        XGenAIModule.GetBrainVariable = function(id, nom) return nom == "scriptorium_monte_manquee" and 2 or 0 end
        if l.montes_manquees("scriptorium_rondier") ~= 2 then return "les montes manquées ne sont pas lues" end
        if l.montes_manquees("personne") ~= nil then return "un homme absent : un compte rendu" end
        XGenAIModule.GetBrainVariable = lire_avant
        System.entites["scriptorium_cheval_essai"] = nil
        l.ordonner("scriptorium_rondier", "suivre", { x = 1, y = 1 }, "cavaliers", nil, nil, nil, nil, "henry", { mode = "cheval", cheval = "scriptorium_cheval_essai" })
        if not string.find(lignes[#lignes], "introuvable, suit « henry » à pied", 1, true) then return "cheval absent : " .. lignes[#lignes] end
        l.ordonner("scriptorium_rondier", "suivre", { x = 1, y = 1 }, "cavaliers", nil, nil, nil, nil, "henry",
          { mode = "cheval", cheval = "scriptorium_cheval_essai", role = "mener", formation = "followNPC" })
        if not string.find(lignes[#lignes], "mène la formation « followNPC » à pied", 1, true)
            or not string.find(lignes[#lignes], "activité 15", 1, true) then return "mener, cheval absent : " .. lignes[#lignes] end
        l.ordonner("scriptorium_rondier", "suivre", { x = 1, y = 1 }, "cavaliers", nil, nil, nil, nil, "henry",
          { mode = "cheval", cheval = "scriptorium_cheval_essai", role = "formation" })
        if not string.find(lignes[#lignes], "à pied", 1, true)
            or not string.find(lignes[#lignes], "activité 16", 1, true) then return "se ranger, cheval absent : " .. lignes[#lignes] end
        l.formations_menees["scriptorium_rondier"] = nil
        -- Le piège des doublures (transmis par le pair, 17/10) : pendant un dialogue, le jeu crée des doublures dont le nom
        -- contient celui de l'original (« DialogTwin_… ») ; en retirer une fait planter le jeu. Le retrait se fait par le
        -- nom exact : la doublure reste, même quand l'original n'est plus là.
        local doublure = "DialogTwin_scriptorium_cheval_essai"
        System.entites["scriptorium_cheval_essai"] = { id = newproxy() }
        System.entites[doublure] = { id = newproxy() }
        l.retirer_cheval("scriptorium_cheval_essai")
        if System.entites["scriptorium_cheval_essai"] ~= nil then return "cheval d'essai non retiré" end
        l.retirer_cheval("scriptorium_cheval_essai")
        if System.entites[doublure] == nil then return "une doublure de dialogue retirée avec le cheval" end
        System.entites[doublure] = nil
        -- V73 f 2 c : le sol d'une place, pour un cheval (la pente par le terrain, l'encombrement par un rayon descendu ;
        -- l'eau seulement si le jeu donne ent_water).
        local sol = l.sol_de({ x = 1, y = 1, z = 7 }, 1.5)
        if not sol or sol.pente ~= 0 or sol.encombre ~= nil then return "sol plat, rayon illisible : " .. tostring(sol and sol.pente) .. " " .. tostring(sol and sol.encombre) end
        ent_all = 1
        Physics = { RayWorldIntersection = function(depart, dir, n, masque, a, b, touches) touches[1] = { pos = { x = depart.x, y = depart.y, z = 7 } } return 1 end }
        sol = l.sol_de({ x = 1, y = 1, z = 7 }, 1.5)
        if sol.encombre ~= false or sol.eau_lisible ~= false then return "sol libre : " .. tostring(sol.encombre) .. " " .. tostring(sol.eau_lisible) end
        Physics.RayWorldIntersection = function(depart, dir, n, masque, a, b, touches) touches[1] = { pos = { x = depart.x, y = depart.y, z = 8 } } return 1 end
        ent_water = 512
        sol = l.sol_de({ x = 1, y = 1, z = 7 }, 1.5)
        if sol.encombre ~= true or sol.eau_lisible ~= true then return "sol encombré : " .. tostring(sol.encombre) .. " " .. tostring(sol.eau_lisible) end
        local terrain_avant = System.GetTerrainElevation
        System.GetTerrainElevation = function(p) return p.x end
        sol = l.sol_de({ x = 1, y = 1, z = 7 }, 2)
        if math.abs(sol.pente - 1) > 1e-6 then return "pente : " .. tostring(sol.pente) end
        System.GetTerrainElevation = function() error("terrain illisible") end
        if l.sol_de({ x = 1, y = 1, z = 7 }, 2) ~= nil then return "un terrain illisible rend un sol" end
        System.GetTerrainElevation = terrain_avant
        Physics, ent_all, ent_water = nil, nil, nil
        -- V73 f 2 f : l'allure mesurée sur la vitesse de celui que le cavalier suit (Henry), pas la sienne ; deux relevés
        -- trop proches gardent la vitesse d'avant ; une ligne au journal seulement quand l'allure change.
        local vus_allure = {}
        l.accrocher_l_allure(function(v, e, fond) table.insert(vus_allure, { v = v, e = e }); if v > 3 then return 2, 2 end return 0, 0 end)
        local cavalier = { GetName = function() return "scriptorium_cavalier" end, GetWorldPos = function() return { x = 0, y = -7, z = 0 } end }
        l.chefs["scriptorium_cavalier"] = "henry"
        local t_h, pos_h = 100, { x = 0, y = 0, z = 0 }
        local horloge_avant = System.GetCurrTime
        System.GetCurrTime = function() return t_h end
        player = { GetWorldPos = function() return pos_h end }
        local donnees_a = { allure_cadence_ms = 300 }
        local lignes_avant = #lignes
        l.allure_vers_chef(cavalier, donnees_a)
        if donnees_a.allure_code ~= 0 or vus_allure[1].v ~= 0 or math.abs(vus_allure[1].e - 7) > 1e-6 then return "allure : premier relevé" end
        t_h, pos_h = 101, { x = 0, y = 5, z = 0 }
        l.allure_vers_chef(cavalier, donnees_a)
        if math.abs(vus_allure[2].v - 5) > 1e-6 or donnees_a.allure_code ~= 2 then return "allure : la vitesse d'Henry " .. tostring(vus_allure[2].v) end
        t_h = 102
        cavalier.GetWorldPos = function() return { x = 0, y = 100, z = 0 } end
        l.allure_vers_chef(cavalier, donnees_a)
        if vus_allure[3].v ~= 0 then return "allure : c'est la vitesse du cavalier qui est mesurée" end
        t_h, pos_h = 102.05, { x = 0, y = 50, z = 0 }
        l.allure_vers_chef(cavalier, donnees_a)
        if vus_allure[4].v ~= 0 then return "allure : un relevé trop proche change la vitesse" end
        local dites = 0
        for i = lignes_avant + 1, #lignes do
          if string.find(lignes[i], "Allure de scriptorium_cavalier", 1, true) then dites = dites + 1 end
        end
        if dites ~= 3 then return "allure : " .. dites .. " lignes au journal pour trois changements" end
        -- V73 f 2 g : une mesure par homme suivi, partagée par ses suiveurs ; un saut d'Henry écarté par le filtre des hommes.
        l.vitesses_des_chefs = {}
        l.accrocher_l_allure(function(v, e) table.insert(vus_allure, { v = v, e = e }); return 0, 0, 0, e > 13 end,
          function(m, avant) if m > 20 then return avant or 0 end return m end)
        local second = { GetName = function() return "scriptorium_second" end, GetWorldPos = function() return { x = 0, y = -20, z = 0 } end }
        l.chefs["scriptorium_second"] = "henry"
        t_h, pos_h = 200, { x = 0, y = 0, z = 0 }
        l.allure_vers_chef(cavalier, donnees_a)
        t_h, pos_h = 201, { x = 0, y = 3, z = 0 }
        l.allure_vers_chef(cavalier, donnees_a)
        local n_avant = #vus_allure
        l.allure_vers_chef(second, donnees_a)
        if math.abs(vus_allure[n_avant + 1].v - 3) > 1e-6 then return "allure : mesure non partagée " .. tostring(vus_allure[n_avant + 1].v) end
        if donnees_a.allure_perdu ~= 1 then return "allure : le second, à 23 m de son chef, n'est pas perdu" end
        t_h, pos_h = 202, { x = 0, y = 43, z = 0 }
        l.allure_vers_chef(cavalier, donnees_a)
        if math.abs(vus_allure[#vus_allure].v - 3) > 1e-6 then return "allure : un saut d'Henry pris pour une course" end
        -- La ligne « perdu » seulement pour qui suit un autre cavalier : rien pour qui suit Henry.
        second.GetWorldPos = function() return { x = 0, y = 40, z = 0 } end
        t_h = 203
        l.allure_vers_chef(second, donnees_a)
        if donnees_a.allure_perdu ~= 0 then return "allure : le second, revenu près de son chef, toujours perdu" end
        local perdus_dits = 0
        for i = 1, #lignes do
          if string.find(lignes[i], "sa place perdue", 1, true) then perdus_dits = perdus_dits + 1 end
        end
        if perdus_dits ~= 0 then return "allure : « perdu » dit pour un cavalier qui suit Henry" end
        l.chefs["scriptorium_second"] = nil
        -- V73 f 3 b : Henry posé à une position exacte, la pose relue ; une pose perdue n'est pas dite réussie.
        local pose_l = nil
        local joueur_avant_l = player
        player = { SetWorldPos = function(self, p) pose_l = { x = p.x, y = p.y, z = p.z } end,
                   GetWorldPos = function(self) return pose_l or { x = 0, y = 0, z = 0 } end }
        local ok_p, cr_p = l.poser_le_joueur({ x = 10, y = 20, z = 107.1 })
        if not ok_p or not pose_l or pose_l.z ~= 107.1 then return "poser le joueur : " .. tostring(cr_p) end
        player.SetWorldPos = function() end
        if l.poser_le_joueur({ x = 50, y = 20, z = 107.1 }) then return "poser le joueur : une pose perdue dite réussie" end
        player = joueur_avant_l
        -- V73 f 3 b : le plancher sous un point (rayon statique + terrain) ; masques absents : nil et la raison.
        local physique_avant_l, statique_avant_l, terrain_avant_l = Physics, ent_static, ent_terrain
        ent_static, ent_terrain = nil, nil
        local z_r, raison_r = l.plancher_sous(1, 2, 111.5, 6)
        if z_r ~= nil or not string.find(tostring(raison_r), "masques", 1, true) then return "plancher : masques absents mal dits" end
        ent_static, ent_terrain = 1, 2
        local masque_r = nil
        Physics = { RayWorldIntersection = function(depart, dir, n, masque, a, b, touches)
          masque_r = masque
          touches[1] = { pos = { x = depart.x, y = depart.y, z = 110.2 } }
          return 1 end }
        z_r = l.plancher_sous(1, 2, 111.5, 6)
        if z_r ~= 110.2 or masque_r ~= 3 then return "plancher : " .. tostring(z_r) .. " masque " .. tostring(masque_r) end
        Physics, ent_static, ent_terrain = physique_avant_l, statique_avant_l, terrain_avant_l
        -- V73 f 3 b : la selle d'un de nos chevaux (horse:HasRider, la lecture d'Henry à cheval) ; illisible : nil.
        local selle = { HasRider = function() return 1 end }
        System.entites["scriptorium_cheval_essai"] = { horse = selle }
        if l.cheval_monte("scriptorium_cheval_essai") ~= true then return "selle : en selle non lu" end
        selle.HasRider = function() return nil end
        if l.cheval_monte("scriptorium_cheval_essai") ~= false then return "selle : à pied non lu" end
        System.entites["scriptorium_cheval_essai"] = {}
        if l.cheval_monte("scriptorium_cheval_essai") ~= nil then return "selle illisible : pas nil" end
        System.entites["scriptorium_cheval_essai"] = nil
        if l.cheval_monte("scriptorium_cheval_essai") ~= nil then return "cheval absent : pas nil" end
        -- V73 f 3 a : la carte lue (la première lecture qui répond), les abonnements de chargement et leur ligne.
        System.GetCVar = function(nom) if nom == "sv_map" then return "kutnohorsko" end return nil end
        local carte_l, source_l = l.carte_courante()
        if carte_l ~= "kutnohorsko" or source_l ~= "sv_map" then return "carte : " .. tostring(carte_l) .. " " .. tostring(source_l) end
        System.GetCVar = nil
        local altitude_avant = System.GetTerrainElevation
        System.GetTerrainElevation = function(p) if math.abs(p.x - 1997.568) < 0.01 then return 115.9 end return 7 end
        local carte_a, source_a = l.carte_courante()
        if carte_a ~= "trosecko" or source_a ~= "altitude du terrain" then return "carte par l'altitude : " .. tostring(carte_a) .. " " .. tostring(source_a) end
        System.GetTerrainElevation = altitude_avant
        local carte_n, essais_n = l.carte_courante()
        if carte_n ~= nil or not string.find(essais_n, "sv_map : refusée", 1, true) or not string.find(essais_n, "kutnohorsko : 7.00 m", 1, true) then return "carte illisible : " .. tostring(essais_n) end
        local inscrits = {}
        UIAction = { RegisterEventSystemListener = function(ecouteur, groupe, evenement, methode) inscrits[evenement] = methode return true end }
        l.ecouter_la_partie(function() end, function() end)
        UIAction = nil
        for _, e in ipairs({ "OnGameplayStarted", "OnGameplayEnded", "OnLoadingStart", "OnLoadingComplete", "OnLoadingError", "OnUnloadStart", "OnUnloadComplete" }) do
          if not inscrits[e] then return "abonnement manquant : " .. e end
        end
        l.ecouteur[inscrits.OnLoadingStart](l.ecouteur, { LevelName = "trosecko" })
        if not string.find(lignes[#lignes], "Chargement : OnLoadingStart (LevelName=trosecko)", 1, true) then return "chargement : " .. lignes[#lignes] end
        if not l.dernier_chargement or l.dernier_chargement.evenement ~= "OnLoadingStart" then return "le dernier chargement n'est pas gardé" end
        System.GetCurrTime, player = horloge_avant, nil
        l.chefs["scriptorium_cavalier"] = nil
        l.accrocher_l_allure(nil)
        -- V73 f 2 d : Henry à cheval (un cheval monté près de lui, n'importe lequel, pas les nôtres) ; son cheval amené.
        local monture_h = { horse = { HasRider = function() return true end }, GetName = function() return "cheval_d_un_paysan" end }
        local notre = { horse = { HasRider = function() return true end }, GetName = function() return "scriptorium_cheval_homme_1_1" end }
        local autour = { monture_h }
        System.GetEntitiesInSphereByClass = function(p, r, classe) if classe == "Horse" then return autour end return {} end
        player = { GetWorldPos = function() return { x = 0, y = 0, z = 0 } end, GetWorldAngles = function() return { x = 0, y = 0, z = 0 } end,
                   player = { GetPlayerHorse = function() return "wuid_henry_cheval" end } }
        if l.henry_a_cheval(1.5) ~= true then return "Henry sur un cheval (même emprunté)" end
        monture_h.horse.HasRider = function() return false end
        if l.henry_a_cheval(1.5) ~= false then return "un cheval sans cavalier près d'Henry" end
        autour = { notre }
        if l.henry_a_cheval(1.5) ~= false then return "un de nos cavaliers près d'Henry compté" end
        autour = {}
        if l.henry_a_cheval(1.5) ~= false then return "aucun cheval près d'Henry" end
        monture_h.horse.HasRider = function() error("illisible") end
        autour = { monture_h }
        if l.henry_a_cheval(1.5) ~= nil then return "un cheval illisible" end
        System.GetEntitiesInSphereByClass = function() error("illisible") end
        if l.henry_a_cheval(1.5) ~= nil then return "la recherche illisible" end
        System.GetEntitiesInSphereByClass = nil
        local cheval_h = { GetName = function() return "cheval_henry" end, SetWorldPos = function(self, p) self.pose = p end }
        local par_wuid_avant = XGenAIModule.GetEntityByWUID
        XGenAIModule.GetEntityByWUID = function(w) return w == "wuid_henry_cheval" and cheval_h or nil end
        local amene, ligne_a = l.amener_le_cheval_d_henry(4)
        if not amene or not cheval_h.pose or math.abs(cheval_h.pose.y - 4) > 1e-6 then return "cheval amené : " .. tostring(ligne_a) end
        player.player.GetPlayerHorse = function() return nil end
        if l.amener_le_cheval_d_henry(4) then return "Henry sans cheval : rien d'amené" end
        XGenAIModule.GetEntityByWUID = par_wuid_avant
        player = nil
        System.entites["scriptorium_rondier"], System.entites["scriptorium_chef_d_essai"] = nil, nil
        XGenAIModule.GetMyWUID = nil
        l.buts["scriptorium_rondier"], l.regards["scriptorium_rondier"] = but_avant, regard_avant
        l.chefs["scriptorium_rondier"] = nil   -- la suite à pied ci-dessus lui a laissé Henry pour chef
        -- La vue d'Henry : à moins de 60° de son regard, il voit ; derrière lui, non ; sans Henry, rien de lisible.
        player = { GetWorldPos = function() return { x = 0, y = 0, z = 0 } end,
                   GetWorldAngles = function() return { x = 0, y = 0, z = 0 } end }   -- face au nord
        if l.henry_voit({ x = 1, y = 10 }, 0.5) ~= true then return "Henry ne voit pas devant lui" end
        if l.henry_voit({ x = 10, y = 1 }, 0.5) ~= false then return "Henry voit à 84° de son regard" end
        if l.henry_voit({ x = 0, y = -10 }, 0.5) ~= false then return "Henry voit derrière lui" end
        player = nil
        if l.henry_voit({ x = 1, y = 10 }, 0.5) ~= nil then return "sans Henry, une vue est rendue" end
        -- La lecture du poste d'essai (voir_sur_la_place) sur ce rondier : l'écart au but et les pas de ronde, sans
        -- erreur de format (sinon la seule lecture de la séance manquerait en jeu).
        function XGenAIModule.GetBrainVariable(id, nom) return 0 end
        function rondier:GetWorldPos() return { x = 0, y = 0, z = 7 } end
        function rondier:GetWorldAngles() return { x = 0, y = 0, z = 0 } end
        System.entites["scriptorium_rondier"] = rondier
        local lu, vue = pcall(l.voir_sur_la_place, "scriptorium_rondier", nil)
        System.entites["scriptorium_rondier"] = nil
        if not lu then return "lecture du poste sur un rondier : " .. tostring(vue) end
        if not string.find(vue, "à 5.00 m de son but, pas de ronde 1, à - m de son chef, en selle", 1, true) then return "lecture du poste : " .. vue end
        XGenAIModule = nil
        l.pas_de_ronde = nil
        System.LogAlways = journal_d_origine
        l.ecrire_registre("{a=2}")
        l.memoire.registre = nil
        if l.lire_registre() ~= "{a=2}" then return "un registre plus court n'est pas relu" end
        if GameToken.valeurs["scriptorium_socle.registre.3"] ~= "" then return "les tranches d'une écriture plus longue restent" end
        local identite = string.match(GameToken.valeurs["scriptorium_socle.registre"], "^([%w_]+)|")
        GameToken.valeurs["scriptorium_socle.registre"] = identite .. "|{ancien=1}"
        if l.lire_registre() ~= "{ancien=1}" then return "l'ancien format en un seul jeton n'est plus lu" end
        -- Étape 2 : deux bandes de la même sorte n'ont jamais les mêmes noms (un numéro par ennemi né).
        local bande1 = l.faire_venir_ennemis("brigands", 2, { x = 0, y = 0, z = 0 }, 0)
        local bande2 = l.faire_venir_ennemis("brigands", 2, { x = 0, y = 0, z = 0 }, 0)
        if not bande1 or not bande2 or #bande1 ~= 2 or bande1[1] == bande2[1] or bande1[2] == bande2[2] then
          return "bandes : noms en double ou bande absente"
        end
        if l.faire_venir_ennemis("inconnus", 2, { x = 0, y = 0, z = 0 }, 0) ~= nil then return "bandes : une sorte sans âme est née" end
        -- V73 g 0 : la liaison relue (outils/recharger.py) garde sa table, sa mémoire, ses relevés et son état de
        -- fichier ; ses fonctions sont remplacées ; le registre se relit ensuite comme avant.
        local identite_relue = l.etat_du_fichier.identite_de_la_partie
        l.memoire.carte = "relue"
        l.chefs["essai_relecture"] = 7
        l.carte_courante = "remplacee"
        local morceau_l, erreur_l = loadfile("socle/pak/Scripts/scriptorium/liaison.lua")
        if not morceau_l then return "relecture : liaison.lua illisible : " .. tostring(erreur_l) end
        morceau_l()
        if Scriptorium.liaison_reelle ~= l then return "relecture : la table de la liaison a changé" end
        if l.memoire.carte ~= "relue" or l.chefs["essai_relecture"] ~= 7 then return "relecture : la mémoire perdue" end
        if l.etat_du_fichier.identite_de_la_partie ~= identite_relue then return "relecture : l'identité de la partie perdue" end
        if type(l.carte_courante) ~= "function" then return "relecture : une fonction non remplacée" end
        if l.lire_registre() ~= "{ancien=1}" then return "relecture : le registre ne se relit plus" end
        l.memoire.carte, l.chefs["essai_relecture"] = nil, nil
        GameToken = nil
        return "ok"
    end)()""")
    if resultat != "ok":
        erreur("liaison : identifiants d'entités : " + str(resultat))
    # Les longueurs des jetons d'essai du poste restent sous 65 535 octets (vu en jeu le 15/10).
    longueurs = re.search(r"poste\.longueurs_de_jetons = \{([^}]*)\}", lire(os.path.join(PAK, "Scripts", "scriptorium", "poste.lua")))
    if not longueurs:
        erreur("poste : longueurs des jetons d'essai introuvables")
    else:
        trop = [n for n in (int(x) for x in re.findall(r"\d+", longueurs.group(1))) if n > 65535]
        if trop:
            erreur("poste : jetons d'essai au-delà de 65 535 octets : " + str(trop))


# ------------------------------------------------------------------ 3. noms interdits

TABLE_DES_AMES = os.path.join(PAK, "Libs", "Tables", "rpg", "soul__scriptorium_socle.xml")
TABLE_DES_FACTIONS = os.path.join(PAK, "Libs", "Tables", "rpg", "FactionTree__scriptorium_socle.xml")
NOTRE_CERVEAU = "b8a850d0-47c6-44a1-872e-ce7efcf4b9f9"


def verifier_ames():
    """Fiche 13 : la table des âmes (écrite par outils/ames.py) et les réserves de la liaison s'accordent, âme par âme ;
    chaque âme a notre cerveau, un nom et un identifiant uniques ; les femmes ont l'archétype féminin du jeu (1), les
    combattants un niveau de combat. Fiche 14 : toutes les âmes des réserves sont de la Compagnie, seule faction de la
    table des factions du socle, amie d'Henry, sans étiquette, sans lieu ni carte. Rend le nombre d'âmes des réserves."""
    lua = runtime_lua()
    if lua is None:
        return 0
    lua.execute("System = { LogAlways = function() end }")
    lua.execute(lire(os.path.join(PAK, "Scripts", "scriptorium", "noyau.lua")))
    lua.execute(lire(os.path.join(PAK, "Scripts", "scriptorium", "liaison.lua")))
    lignes = lua.eval("""(function()
        local l = Scriptorium.liaison_reelle
        local lignes = {}
        for reserve, r in pairs(l.reserves_d_ames) do
          for palier, taille in ipairs(r.paliers) do
            for numero = 1, taille do
              table.insert(lignes, reserve .. "|" .. palier .. "|" .. tostring(l.ame_de(reserve, palier, numero)))
            end
          end
        end
        return table.concat(lignes, "\\n")
    end)()""")
    attendues = {}
    for ligne in lignes.split("\n"):
        reserve, palier, ame = ligne.split("|")
        attendues[ame] = (reserve, int(palier))
    racine = ET.parse(TABLE_DES_AMES).getroot()
    ames = [s.attrib for s in racine.iter("soul")]
    # Pas de jumeaux (demande du pair, 18/10) : deux âmes d'une réserve ont le même visage pour la liaison
    # (liaison.visage_de) si et seulement si elles ont le même personnage du jeu dans la table.
    visage_de = {}
    for ligne in lua.eval("""(function()
        local l, lignes = Scriptorium.liaison_reelle, {}
        for reserve, r in pairs(l.reserves_d_ames) do
          for palier, taille in ipairs(r.paliers) do
            for numero = 1, taille do
              local ame = l.ame_de(reserve, palier, numero)
              table.insert(lignes, string.lower(ame) .. "|" .. tostring(l.visage_de(ame)))
            end
          end
        end
        return table.concat(lignes, "\\n")
    end)()""").split("\n"):
        ame, visage = ligne.split("|")
        visage_de[ame] = visage
    # Vu en jeu le 18/10 : le visage suit l'âme, pas le personnage ; l'accord visage <-> personnage ne se vérifie plus.
    # Chaque homme son nom (décision de JoVenGer, 18/10) : chaque âme des réserves nommées pointe vers un personnage à
    # nous (table des personnages) dont le nom affiché (clé ui_name_string_name, table des textes) est celui que
    # hommes.nom_de_l_ame donne à l'âme, et deux âmes n'ont jamais le même nom.
    lua.execute(lire(os.path.join(PAK, "Scripts", "scriptorium", "hommes.lua")))
    lua.execute("Scriptorium.jeu = Scriptorium.liaison_reelle")
    personnages = {}
    chemin_des_personnages = os.path.join(PAK, "Libs", "Tables", "skald", "skald_character__scriptorium_socle.xml")
    if os.path.exists(chemin_des_personnages):
        for s in ET.parse(chemin_des_personnages).getroot().iter("skald_character"):
            personnages[s.attrib.get("skald_character_name")] = s.attrib.get("ui_name_string_name")
    textes_des_noms = {}
    chemin_des_textes = os.path.join(SOCLE, "textes", "fr", "text_ui_soul__scriptorium_socle.xml")
    if os.path.exists(chemin_des_textes):
        for rangee in ET.parse(chemin_des_textes).getroot().iter("Row"):
            cellules = [(c.text or "").strip() for c in rangee.findall("Cell")]
            if len(cellules) == 3:
                textes_des_noms[cellules[0]] = cellules[2]
    nom_lua = lua.eval("function(ame) return Scriptorium.hommes.nom_de_l_ame(ame) end")
    noms_vus, nommees = {}, 0
    for a in ames:
        attendu = nom_lua(a.get("soul_id", ""))
        if attendu is None:
            continue
        nommees += 1
        cle = personnages.get(a.get("skald_character_name"))
        affiche = textes_des_noms.get(cle)
        if affiche != attendu:
            erreur("âmes : %s affiche « %s », hommes.nom_de_l_ame dit « %s »" % (a.get("soul_name"), affiche, attendu))
        # Les hommes de la reprise gardent les noms de JoVenGer, même s'ils croisent ceux des réserves.
        if attendu in noms_vus and not a.get("soul_name", "").startswith("scriptorium_reprise_"):
            erreur("âmes : nom « %s » pour %s et %s" % (attendu, noms_vus[attendu], a.get("soul_name")))
        if not a.get("soul_name", "").startswith("scriptorium_reprise_"):
            noms_vus[attendu] = a.get("soul_name")
    if nommees == 0:
        erreur("âmes : aucune âme nommée")
    noms = [a.get("soul_name") for a in ames]
    ids = [a.get("soul_id", "").lower() for a in ames]
    if len(set(noms)) != len(noms) or len(set(ids)) != len(ids):
        erreur("âmes : nom ou identifiant en double dans la table")
    # Étape 2 (fiche 14) : les âmes de bande, une par sorte, copiées sur des âmes du jeu (leur cerveau d'ennemi) ; ce
    # sont celles de liaison.ames_ennemies, de la faction des bandes.
    bandes_de_la_liaison = set(lua.eval("""(function()
        local ids = {}
        for _, ame in pairs(Scriptorium.liaison_reelle.ames_ennemies) do table.insert(ids, string.lower(ame)) end
        return table.concat(ids, ",")
    end)()""").split(","))
    bandes = {a["soul_id"].lower(): a for a in ames if a.get("soul_name", "").startswith("scriptorium_bande_")}
    if set(bandes) != bandes_de_la_liaison:
        erreur("âmes : les âmes de bande de la table et de la liaison diffèrent")
    for a in bandes.values():
        if a.get("factionName") != "scriptorium_socle_bande" or not a.get("combat_level"):
            erreur("âmes : %s, une âme de bande sans sa faction ou son niveau" % a.get("soul_name"))
    # Toutes nos âmes ont notre cerveau, celles des bandes aussi (étape 2 : notre ordre d'attaque les fait venir).
    for a in ames:
        if a.get("brain_id") != NOTRE_CERVEAU:
            erreur("âmes : %s n'a pas notre cerveau" % a.get("soul_name"))
    du_mod = {a["soul_id"].lower(): a for a in ames
              if a.get("soul_id", "").lower().startswith("5c7a5c7a") and a.get("soul_id", "").lower() not in bandes}
    for ame, (reserve, palier) in attendues.items():
        a = du_mod.get(ame)
        if a is None:
            erreur("âmes : %s (réserve %s, palier %d) absente de la table" % (ame, reserve, palier))
            continue
        if reserve == "femme" and a.get("soul_archetype_id") != "1":
            erreur("âmes : %s, une femme sans l'archétype féminin" % a.get("soul_name"))
        if reserve == "combattant" and not a.get("combat_level"):
            erreur("âmes : %s, un combattant sans niveau de combat" % a.get("soul_name"))
    for ame in du_mod:
        if ame not in attendues:
            erreur("âmes : %s dans la table, hors des réserves de la liaison" % du_mod[ame].get("soul_name"))
    compagnie = verifier_la_compagnie()
    for a in du_mod.values():
        if compagnie and a.get("factionName") != compagnie:
            erreur("âmes : %s n'est pas de la Compagnie (%s)" % (a.get("soul_name"), a.get("factionName")))
    return len(attendues)


def verifier_la_compagnie():
    """Fiche 14 : la table des factions du socle (écrite par outils/ames.py, qui vérifie les cibles dans l'arbre du jeu).
    Rend le nom de la Compagnie, ou None."""
    racine = ET.parse(TABLE_DES_FACTIONS).getroot()
    factions = list(racine.iter("Faction"))
    if racine.tag != "database" or racine.find("FactionTree") is None or len(factions) != 2:
        erreur("factions : deux factions attendues (la Compagnie, les bandes), sous database/FactionTree")
        return None
    f, bande = factions[0], factions[1]
    # Étape 2 (fiche 14) : la faction des bandes, ennemie publique, hostile à Henry et à la Compagnie, et réciproquement.
    relations_bande = [(r.get("target", ""), r.get("reputation", "")) for r in bande.iter("Relation")]
    if bande.get("Name") != "scriptorium_socle_bande" or bande.get("Labels") != "publicEnemy" \
            or bande.get("LocationId") or bande.get("LevelId"):
        erreur("factions : la faction des bandes n'a pas sa forme (nom, publicEnemy, sans lieu ni carte)")
    if (f.get("Name"), "-1") not in relations_bande:
        erreur("factions : les bandes ne sont pas hostiles à la Compagnie")
    if ("scriptorium_socle_bande", "-1") not in [(r.get("target", ""), r.get("reputation", "")) for r in f.iter("Relation")]:
        erreur("factions : la Compagnie n'est pas hostile aux bandes")
    nom = f.get("Name", "")
    if not nom.startswith("scriptorium_socle_"):
        erreur("factions : %s n'a pas le préfixe du socle" % nom)
    # Sans étiquette : « settlement » lui ôterait crime_skipInformationBroadcast ; « camp » ou « publicEnemy » ferait de nos
    # hommes des brigands pour les règles du jeu (isBandit). Sans lieu ni carte : valable partout, comme animalCompanions.
    for attribut in ("Labels", "LocationId", "LevelId"):
        if f.get(attribut):
            erreur("factions : la Compagnie porte %s" % attribut)
    relations = [(r.get("target", ""), r.get("reputation", "")) for r in f.iter("Relation")]
    for cible, reputation in relations:
        try:
            juste = cible != "" and -1 <= float(reputation) <= 1
        except ValueError:
            juste = False
        if not juste:
            erreur("factions : relation mal formée (%s, %s)" % (cible, reputation))
    if ("player", "1") not in relations:
        erreur("factions : la Compagnie n'est pas amie d'Henry")
    return nom


def verifier_equipement():
    """Fiche 13, V71 b : chaque préréglage que citent les règles d'équipement (hommes.equipement) est dans le bloc des
    pièces de la liaison (écrit par outils/equipement.py) ; chaque palier de chaque famille et de la tenue a au moins un
    préréglage ; chaque assemblage de tir a ses munitions ; chaque objet a la forme d'un identifiant. Rend le nombre de
    préréglages du bloc."""
    lua = runtime_lua()
    if lua is None:
        return 0
    lua.execute("System = { LogAlways = function() end }")
    for nom in ("noyau.lua", "liaison.lua", "hommes.lua"):
        lua.execute(lire(os.path.join(PAK, "Scripts", "scriptorium", nom)))
    rendu = lua.eval("""(function()
        local l = Scriptorium.liaison_reelle
        local e = Scriptorium.hommes.equipement
        local erreurs, noms = {}, l.noms_des_prereglages()
        local pavois = {}
        for _, liste in pairs(e.pavois) do for _, p in ipairs(liste) do pavois[p] = true end end
        local exclues = {}
        for _, nom in ipairs(e.tenue.exclues or {}) do
          if not l.pieces_de(nom) then table.insert(erreurs, "tenue exclue inconnue " .. nom) end
          exclues[nom] = true
        end
        local function candidats(sorte, bornes)
          local n = 0
          for _, nom in ipairs(noms) do
            local s, niveau = string.match(nom, "^(.-)_(%d+)_%d+$")
            niveau = tonumber(niveau)
            if s == sorte and niveau and niveau >= bornes.de and niveau <= bornes.a and not pavois[nom] and not exclues[nom] then n = n + 1 end
          end
          return n
        end
        for palier = 1, 3 do
          local cle = "palier_" .. palier
          if candidats(e.tenue.sorte, e.tenue[cle]) == 0 then table.insert(erreurs, "tenue " .. cle) end
          for famille, f in pairs(e.familles) do
            if candidats(f.sorte, f[cle]) == 0 then table.insert(erreurs, famille .. " " .. cle) end
          end
          for _, p in ipairs(e.pavois[cle] or {}) do
            if not l.pieces_de(p) then table.insert(erreurs, "pavois absent " .. p) end
          end
          if #(e.pavois[cle] or {}) == 0 then table.insert(erreurs, "pavois " .. cle) end
          for role, t in pairs(e.tir) do
            if #((t[cle] or {}).prereglages or {}) == 0 then table.insert(erreurs, role .. " " .. cle) end
            for _, p in ipairs((t[cle] or {}).prereglages or {}) do
              if not l.pieces_de(p) then table.insert(erreurs, "tir absent " .. p) end
              if not l.munition_de(p) then table.insert(erreurs, "munitions absentes " .. p) end
            end
          end
        end
        for _, nom in ipairs(noms) do
          for _, objet in ipairs(l.pieces_de(nom)) do
            if not string.match(objet, "^%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$") then
              table.insert(erreurs, nom .. " : objet mal formé " .. tostring(objet))
            end
          end
        end
        return #noms .. "|" .. table.concat(erreurs, ";")
    end)()""")
    nombre, erreurs = rendu.split("|", 1)
    for e in [x for x in erreurs.split(";") if x]:
        erreur("équipement : " + e)
    if int(nombre) == 0:
        erreur("équipement : bloc des pièces vide (lancer outils/equipement.py)")
    return int(nombre)


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


# ------------------------------------------------------------------ 3 bis. un seul nom par table

# Note de JoVenGer (partie 2, point 5) : à la bascule, la table du socle deviendra « scriptorium.socle ». Seul le noyau
# la pose ; chaque autre fichier la reprend par sa première ligne de code ; aucune chaîne ne porte son nom ; aucun nom
# du socle ne diffère d'un autre par une majuscule seulement, sauf les noms imposés par le moteur.
REPRISE_DE_LA_TABLE = "local Scriptorium = Scriptorium"
NOMS_DU_MOTEUR = {"properties": "Properties des classes d'entités, properties de System.SpawnEntity",
                  "name": "Name de la classe sociale (soul:GetSocialClass().Name, Scripts/Utils/EntityUtils.lua)",
                  "horse": "le composant horse des chevaux (horse:HasRider, Scripts/Entities/AI/Horse.lua)",
                  "action": "Action() et sa méthode action() (Scripts/Utils/InteractorAction.lua ; « Parler », fiche 18, 5 b)"}


def lignes_de_code(texte):
    """Les lignes sans commentaires ni contenu de chaînes (assez pour des noms)."""
    texte = re.sub(r"--\[\[.*?\]\]", " ", texte, flags=re.S)
    resultat = []
    for ligne in texte.splitlines():
        ligne = re.sub(r'"(?:[^"\\]|\\.)*"', '""', ligne)
        ligne = re.sub(r"'(?:[^'\\]|\\.)*'", "''", ligne)
        resultat.append(re.sub(r"--.*$", "", ligne).rstrip())
    return resultat


def verifier_un_seul_nom():
    morceaux = os.path.join(PAK, "Scripts", "scriptorium")
    formes = {}
    for chemin in fichiers(os.path.join(PAK, "Scripts"), {".lua"}):
        texte = lire(chemin)
        code = lignes_de_code(texte)
        nom = os.path.basename(chemin)
        poses = [i + 1 for i, ligne in enumerate(code) if re.match(r"^\s*Scriptorium\s*=", ligne)]
        if os.path.dirname(chemin) == morceaux and nom != "noyau.lua":
            if poses:
                erreur("un seul nom par table : %s pose la table du socle (ligne %d)" % (relatif(chemin), poses[0]))
            premiere = next((ligne.strip() for ligne in code if ligne.strip()), "")
            if premiere != REPRISE_DE_LA_TABLE:
                erreur("un seul nom par table : %s ne commence pas par « %s » : %s" % (relatif(chemin), REPRISE_DE_LA_TABLE, premiere))
        elif nom == "noyau.lua" and len(poses) != 1:
            erreur("un seul nom par table : le noyau doit poser la table une fois (%d)" % len(poses))
        for numero, ligne in enumerate(texte.splitlines(), 1):
            sans_commentaire = re.sub(r"--.*$", "", ligne)
            if re.search(r"""["']Scriptorium[.:]""", sans_commentaire):
                erreur("un seul nom par table : nom de la table dans une chaîne, %s:%d : %s" % (relatif(chemin), numero, ligne.strip()))
        for ligne in code:
            for mot in re.findall(r"[A-Za-z_][A-Za-z0-9_]*", ligne):
                formes.setdefault(mot.lower(), set()).add(mot)
    doubles = {cle: sorted(f) for cle, f in formes.items() if len(f) > 1 and cle not in NOMS_DU_MOTEUR}
    for cle, f in sorted(doubles.items()):
        erreur("un seul nom par table : noms qui ne diffèrent que par une majuscule : " + ", ".join(f))
    return len(formes)


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
    # Chaque homme son nom (18/10) : les clés des noms sont employées par la table des personnages (outils/ames.py).
    for chemin in fichiers(os.path.join(PAK, "Libs", "Tables", "skald"), {".xml"}):
        for numero, ligne in enumerate(lire(chemin).splitlines(), 1):
            for cle in re.findall(r'_string_name="(ui_scriptorium_[A-Za-z0-9_]+)"', ligne):
                employees.setdefault(cle, []).append("%s:%d" % (relatif(chemin), numero))
    # Fiche 21 : les clés des dialogues sont employées par nos fichiers de quêtes (StringName), écrits par
    # outils/dialogues.py, qui doivent être à jour.
    for chemin in fichiers(os.path.join(PAK, "Quests"), {".xml"}):
        for numero, ligne in enumerate(lire(chemin).splitlines(), 1):
            for cle in re.findall(r'StringName="(ui_scriptorium_[A-Za-z0-9_]+)"', ligne):
                employees.setdefault(cle, []).append("%s:%d" % (relatif(chemin), numero))
    import subprocess
    a_jour = subprocess.run([sys.executable, os.path.join(RACINE, "outils", "dialogues.py"), "--verifier"],
                            capture_output=True, text=True, encoding="utf-8", errors="replace")
    if a_jour.returncode != 0:
        erreur("dialogues : fichiers écrits par outils/dialogues.py pas à jour : " + " ; ".join(a_jour.stdout.split()))
    # Demande du pair (19/10) : « Des fautes aujourd'hui ? » : la réponse « Rien, chef » (code 4) revient directement au
    # menu, sans le sous-menu « Je pardonne / Sanctionne-le » ; une faute rapportée (codes 1 à 3) l'ouvre.
    for chemin in fichiers(os.path.join(PAK, "Quests"), {".xml"}):
        if "directeur" not in os.path.basename(chemin):
            continue
        bloc = lire(chemin).split('DesignName="les_fautes"', 1)[-1].split('DesignName="le_coffre"', 1)[0]
        directs = {code: "GoTo" in balise for balise, code in
                   re.findall(r'(<Sequence [^>]*DesignName="code (\d)"[^>]*>)', bloc) if code in "1234"}
        if directs != {"1": False, "2": False, "3": False, "4": True}:
            erreur("dialogues : %s : les fautes, sous-menu pour les codes 1 à 3 et retour direct pour le code 4 ; trouvé %s"
                   % (relatif(chemin), directs))
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


JEU = r"G:\SteamLibrary\steamapps\common\KingdomComeDeliverance2"
# Les familles de fichiers XML du jeu de base dont le socle reprend la forme : (pak, début des chemins).
FAMILLES_DU_JEU = [(os.path.join("Data", "Tables.pak"), "Libs/Tables/"), (os.path.join("Data", "Scripts.pak"), "AI/")]


FORMES_ADMISES_AU_PLUS = 36   # 18/10 : 36 avec <skald_characters version="1"> et sa fermante (la table des personnages nommés ; revue) ; 33 (la balise fermante </WeaponAutomationDecorator>, forme du jeu ; revue) ; 34 avec </ProcessMessage> (les branches 'dialogMailbox', fiche 21 ; revue). Au-delà, le banc échoue : revoir la liste, puis relever cette borne en connaissance
# (15/10 : 19 avec l'arbre qui s'assoit : Then, Else, IfElseCondition, StanceElement ; 21 avec CombatMoveDecorator ; 25 avec les balises fermantes de la chaîne de combat et SuppressFailure ; 26 avec MeleeOffenseAutomationDecorator ; 27 avec EntityContext ; revues)
# (16/10, V73 d 1 : 32 avec « <Else canSkip="1"> », la branche « sinon » de IsNightTimeOfDay, telle quelle dans
# AI/events/randomEventsBehaviors.xml du jeu ; revue)
# Les attributs d'une ligne de forme : structure des tables et des arbres, jamais un nom, une valeur ni un comportement.
ATTRIBUTS_DE_FORME = {"version", "xmlns:xsi", "xsi:noNamespaceSchemaLocation", "OneTimeOnly", "FailState", "saveVersion",
                      "canSkip", "is_function", "successMode", "failureMode"}
NOMS_DE_FORME = {"barbora", "onUpdate"}   # le nom de toutes les bases du jeu, le nom d'entrée des arbres


def est_une_ligne_de_forme(ligne):
    """Vrai pour une ligne de structure : déclaration XML, balise fermante, balise vide sans attribut, ou balise dont
    tous les attributs sont de structure (ATTRIBUTS_DE_FORME, et « name » seulement s'il vaut un NOMS_DE_FORME)."""
    if re.fullmatch(r'<\?xml version="1\.0" encoding="us-ascii"\?>', ligne) or re.fullmatch(r"</\w+>", ligne):
        return True
    balise = re.fullmatch(r"<\w+((?:\s+[\w:]+=\"[^\"]*\")*)\s*/?>", ligne)
    if not balise:
        return False
    for nom, valeur in re.findall(r'([\w:]+)="([^"]*)"', balise.group(1)):
        if nom == "name" and valeur in NOMS_DE_FORME:
            continue
        if nom not in ATTRIBUTS_DE_FORME:
            return False
    return True


def verifier_le_filtre_des_formes():
    """Le filtre des lignes de forme refuse toute ligne qui porte un nom, une valeur ou un comportement."""
    admises = ['<?xml version="1.0" encoding="us-ascii"?>', "</brains>", '<brains version="1">', "<ForestContainer />",
               '<Root OneTimeOnly="false" FailState="Recoverable" saveVersion="2">']
    refusees = ['<brain brain_id="b8a850d0" brain_name="scriptorium_essai_marche" />', '<Move speed="Walk" />',
                '<BehaviorTree name="secret" is_function="0">', '<Wait duration="5s" />', "<Sequence> <Move />"]
    for ligne in admises:
        if not est_une_ligne_de_forme(ligne):
            erreur("filtre des lignes de forme : ligne de structure refusée : " + ligne)
    for ligne in refusees:
        if est_une_ligne_de_forme(ligne):
            erreur("filtre des lignes de forme : ligne admise à tort : " + ligne)


# Les noms du jeu admis (décision de JoVenGer du 17/10, transmise par le pair) : une liste fermée de noms que le moteur
# appelle sur une entité et qu'Alex emploie aussi. Un nom n'y est admis que s'il est DÉFINI comme fonction dans les
# scripts du jeu de base (vérifié dans Data/Scripts.pak à chaque passage ; sans le jeu, refusé), affiché au rapport. Au
# plus un ; un nom de plus se demande à JoVenGer, on ne relève jamais la borne seul.
NOMS_DU_JEU_ADMIS = {"GetActions": "les actions d'un personnage, BasicAIActions:GetActions "
                                   "(Scripts/Entities/AI/Shared/BasicAIActions.lua) ; « Parler », fiche 18, 5 b"}
NOMS_DU_JEU_AU_PLUS = 1


def noms_du_jeu_admis():
    """Les noms de NOMS_DU_JEU_ADMIS définis comme fonction dans Data/Scripts.pak du jeu de base. Rend { nom : fichier
    du jeu }. Sans le jeu, aucun."""
    pak = os.path.join(JEU, "Data", "Scripts.pak")
    trouves = {}
    if not os.path.exists(pak):
        return trouves
    motifs = {nom: re.compile(r"\bfunction\s+[A-Za-z_][A-Za-z0-9_.]*[.:]" + re.escape(nom) + r"\s*\(")
              for nom in NOMS_DU_JEU_ADMIS}
    with zipfile.ZipFile(pak) as archive:
        for info in archive.infolist():
            if not info.filename.lower().endswith(".lua"):
                continue
            texte = archive.open(info).read().decode("utf-8", "replace")
            for nom, motif in motifs.items():
                if nom not in trouves and motif.search(texte):
                    trouves[nom] = info.filename
            if len(trouves) == len(motifs):
                break
    return trouves


def formes_du_jeu(lignes_d_alex):
    """Les lignes XML du socle communes avec Alex qui sont des lignes de forme (est_une_ligne_de_forme) et figurent
    aussi, telles quelles, dans les fichiers XML du jeu de base (lecture seule, en mémoire : rien n'est extrait), à
    chaque passage. Rend { empreinte : ligne }. Sans le jeu, aucune."""
    voulues = {}
    for chemin in fichiers(PAK, {".xml"}):
        for ligne in lire(chemin).splitlines():
            normalisee = outil_empreintes.normaliser_ligne(ligne, ".xml")
            marque = outil_empreintes.empreinte(normalisee)
            if len(normalisee) >= outil_empreintes.LIGNE_MIN and marque in lignes_d_alex and est_une_ligne_de_forme(normalisee):
                voulues[normalisee] = marque
    trouvees = {}
    for pak, debut in FAMILLES_DU_JEU:
        chemin_du_pak = os.path.join(JEU, pak)
        if not voulues or not os.path.exists(chemin_du_pak):
            continue
        with zipfile.ZipFile(chemin_du_pak) as archive:
            for info in archive.infolist():
                if not voulues or not info.filename.startswith(debut) or not info.filename.lower().endswith(".xml"):
                    continue
                info.orig_filename = info.filename.replace("/", "\\") if "\\" in info.orig_filename else info.orig_filename
                try:
                    texte = archive.open(info).read().decode("utf-8", "replace")
                except zipfile.BadZipFile:
                    continue
                for ligne in texte.splitlines():
                    normalisee = outil_empreintes.normaliser_ligne(ligne, ".xml")
                    if normalisee in voulues:
                        trouvees[voulues.pop(normalisee)] = normalisee
    return trouvees


# Décision de JoVenGer du 16/10/2026 (fiche 14) : les relations de la Compagnie sont celles de la faction du chien et du
# cheval d'Henry, recopiées de l'arbre des factions du jeu ; Alex a repris les mêmes lignes du jeu. Seules ces lignes-là
# sont admises : celles de la table des factions du socle qui sont, telles quelles, une relation de animalCompanions dans
# l'arbre du jeu (relu à chaque passage, en mémoire), au plus RELATIONS_DU_JEU_AU_PLUS. Sans le jeu, aucune.
FACTION_MODELE = "animalCompanions"
RELATIONS_DU_JEU_AU_PLUS = 8


# Fiche 21 (les dialogues, 18/10) : nos fichiers de quêtes et de règles Storm sont écrits par outils/dialogues.py à la
# forme des fichiers du jeu ; une ligne qui y figure TELLE QUELLE dans les fichiers du jeu de la même famille
# (Scripts.pak Quests/, IPL_GameData.pak Libs/Storm/) est une forme imposée par le jeu (en-têtes, ObjectiveValueTypes du
# projet, tâche « roles » de Storm, en-tête d'un Dialogue), pas une ligne d'Alex : comptée à part, plafonnée, listée
# à chaque passage. Toute autre ligne en commun reste une erreur.
FAMILLES_DES_QUETES = [("Quests", os.path.join("Data", "Scripts.pak"), "Quests/"),
                       (os.path.join("Libs", "Storm"), os.path.join("Data", "IPL_GameData.pak"), "Libs/Storm/")]
LIGNES_DES_QUETES_AU_PLUS = 16   # 18/10 : 13 relevées et revues ; au-delà, revoir la liste
# 18/10, décision de JoVenGer : la commande de caméra de chaque réplique (<Commands>, <CameraCommand />, </Commands>)
# est une ligne du jeu admise ici (Data/Scripts.pak, Quests/Final/Barbora/klaster/…/albik_o_leku/albik_o_leku.xml,
# 22 fois, et d'autres dialogues des quêtes du jeu).


def lignes_des_quetes_du_jeu(lignes_d_alex):
    """Les lignes de nos fichiers de quêtes et de Storm communes avec Alex qui figurent telles quelles dans les fichiers
    du jeu de la même famille (lecture seule, en mémoire). Rend { empreinte : ligne }. Sans le jeu, aucune."""
    trouvees = {}
    for dossier, pak, debut in FAMILLES_DES_QUETES:
        voulues = {}
        for chemin in fichiers(os.path.join(PAK, dossier), {".xml"}):
            for ligne in lire(chemin).splitlines():
                normalisee = outil_empreintes.normaliser_ligne(ligne, ".xml")
                marque = outil_empreintes.empreinte(normalisee)
                if len(normalisee) >= outil_empreintes.LIGNE_MIN and marque in lignes_d_alex:
                    voulues[normalisee] = marque
        chemin_du_pak = os.path.join(JEU, pak)
        if not voulues or not os.path.exists(chemin_du_pak):
            continue
        with zipfile.ZipFile(chemin_du_pak) as archive:
            for info in archive.infolist():
                if not voulues:
                    break
                if not info.filename.startswith(debut) or not info.filename.lower().endswith(".xml"):
                    continue
                for ligne in archive.open(info).read().decode("utf-8", "replace").splitlines():
                    normalisee = outil_empreintes.normaliser_ligne(ligne.lstrip("\ufeff"), ".xml")
                    if normalisee in voulues:
                        trouvees[voulues.pop(normalisee)] = normalisee
    return trouvees


def relations_du_jeu(lignes_d_alex):
    """Les lignes de la table des factions du socle communes avec Alex qui sont une relation de FACTION_MODELE dans
    Libs/Tables/rpg/FactionTree.xml du jeu. Rend { empreinte : ligne }."""
    voulues = {}
    for ligne in lire(TABLE_DES_FACTIONS).splitlines():
        normalisee = outil_empreintes.normaliser_ligne(ligne, ".xml")
        marque = outil_empreintes.empreinte(normalisee)
        if marque in lignes_d_alex and re.fullmatch(r'<Relation target="[^"]+" reputation="[^"]+" />', normalisee):
            voulues[normalisee] = marque
    chemin_du_pak = os.path.join(JEU, "Data", "Tables.pak")
    if not voulues or not os.path.exists(chemin_du_pak):
        return {}
    with zipfile.ZipFile(chemin_du_pak) as archive:
        texte = archive.read("Libs/Tables/rpg/FactionTree.xml").decode("utf-8", "replace")
    debut = texte.find('<Faction Name="%s"' % FACTION_MODELE)
    fin = texte.find("</Faction>", debut)
    if debut < 0 or fin < 0:
        return {}
    du_modele = {outil_empreintes.normaliser_ligne(l, ".xml") for l in texte[debut:fin].splitlines()}
    return {marque: ligne for ligne, marque in voulues.items() if ligne in du_modele}


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

    # Les lignes XML qui figurent telles quelles dans les fichiers du jeu de base (en-têtes des tables, nœuds des
    # arbres de comportement) sont la forme imposée par le jeu à tout mod, pas des lignes d'Alex : elles sont comptées
    # à part. Toute autre ligne en commun reste une erreur.
    verifier_le_filtre_des_formes()
    formes = formes_du_jeu(alex["lignes"])
    socle["lignes"] = socle["lignes"] - set(formes)
    for ligne in sorted(formes.values()):
        print("   ligne de forme du jeu : " + ligne)
    if len(formes) > FORMES_ADMISES_AU_PLUS:
        erreur("contrôle d'absence : %d lignes de forme du jeu, plus que les %d admises : revoir la liste"
               % (len(formes), FORMES_ADMISES_AU_PLUS))
    relations = relations_du_jeu(alex["lignes"])
    socle["lignes"] = socle["lignes"] - set(relations)
    for ligne in sorted(relations.values()):
        print("   relation du jeu (%s) : %s" % (FACTION_MODELE, ligne))
    if len(relations) > RELATIONS_DU_JEU_AU_PLUS:
        erreur("contrôle d'absence : %d relations du jeu, plus que les %d admises" % (len(relations), RELATIONS_DU_JEU_AU_PLUS))
    des_quetes = lignes_des_quetes_du_jeu(alex["lignes"])
    socle["lignes"] = socle["lignes"] - set(des_quetes)
    for ligne in sorted(des_quetes.values()):
        print("   ligne des quêtes du jeu : " + ligne)
    if len(des_quetes) > LIGNES_DES_QUETES_AU_PLUS:
        erreur("contrôle d'absence : %d lignes des quêtes du jeu, plus que les %d admises : revoir la liste"
               % (len(des_quetes), LIGNES_DES_QUETES_AU_PLUS))

    if len(NOMS_DU_JEU_ADMIS) > NOMS_DU_JEU_AU_PLUS:
        erreur("contrôle d'absence : %d noms du jeu admis, plus que les %d permis par JoVenGer"
               % (len(NOMS_DU_JEU_ADMIS), NOMS_DU_JEU_AU_PLUS))
    admis = noms_du_jeu_admis()
    noms_admis = {outil_empreintes.empreinte(nom) for nom in admis}
    socle["noms"] = socle["noms"] - noms_admis
    for nom, fichier in sorted(admis.items()):
        print("   nom du jeu admis : %s (défini dans %s) : %s" % (nom, fichier, NOMS_DU_JEU_ADMIS[nom]))

    resultats = {}
    for nom in ("fichiers", "chemins", "lignes", "noms", "cles", "textes"):
        communs = socle[nom] & alex[nom]
        resultats[nom] = len(communs)
        if communs:
            erreur("contrôle d'absence : %d %s en commun avec Alex" % (len(communs), nom))
    resultats["lignes de forme du jeu"] = len(formes)
    resultats["noms du jeu admis"] = len(admis)
    resultats["relations du jeu"] = len(relations)
    if resultats["lignes"] or resultats["noms"] or resultats["textes"]:
        # Nommer les coupables, pour corriger vite.
        for chemin in list(fichiers(PAK, {".lua", ".xml", ".cfg"})) + list(fichiers(TEXTES, {".xml"})):
            texte = lire(chemin)
            extension = os.path.splitext(chemin)[1].lower()
            for numero, ligne in enumerate(texte.splitlines(), 1):
                normalisee = outil_empreintes.normaliser_ligne(ligne, extension)
                marque = outil_empreintes.empreinte(normalisee)
                if len(normalisee) >= outil_empreintes.LIGNE_MIN and marque in alex["lignes"] and marque not in formes \
                        and marque not in relations and marque not in des_quetes:
                    erreur("  ligne d'Alex : %s:%d" % (relatif(chemin), numero))
            if extension == ".lua":
                for identifiant in set(outil_empreintes.noms_du_lua(texte)):
                    if outil_empreintes.empreinte(identifiant) in alex["noms"] and identifiant not in admis:
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

ARBRES = os.path.join(PAK, "AI", "scriptorium")
TABLE_DES_VARIABLES = os.path.join(PAK, "Libs", "Tables", "ai", "brain_variable__scriptorium_socle.xml")
TABLE_DES_COMPORTEMENTS = os.path.join(PAK, "Libs", "Tables", "ai", "smartEntity", "SmartEntity__so_interrupt__scriptorium_socle.xml")


def verifier_l_ordre_des_locales():
    """Vu en jeu le 18/10 (liaison.jouer_un_son) : une fonction locale appelée plus haut que sa définition est, à cet
    endroit, une globale vide : l'appel casse en jeu, et le faux jeu ne le voit pas. Dans chacun de nos fichiers Lua,
    aucun nom de « local function » n'est employé avant la ligne qui le définit (commentaires ôtés)."""
    for racine, _, noms in os.walk(os.path.join(PAK, "Scripts")):
        for nom in sorted(noms):
            if not nom.endswith(".lua"):
                continue
            chemin = os.path.join(racine, nom)
            lignes = [re.sub(r"--.*$", "", l) for l in lire(chemin).splitlines()]
            definies = {}
            for n, ligne in enumerate(lignes):
                m = re.match(r"\s*local\s+function\s+([A-Za-z_][A-Za-z0-9_]*)", ligne)
                if m and m.group(1) not in definies:
                    definies[m.group(1)] = n
            for fonction, ligne_def in definies.items():
                motif = re.compile(r"(?<![\w.:])" + re.escape(fonction) + r"\s*\(")
                for n in range(ligne_def):
                    if motif.search(lignes[n]) and not re.match(r"\s*local\s+" + re.escape(fonction) + r"\b", lignes[n]):
                        erreur("ordre des locales : %s:%d emploie « %s », définie plus bas (ligne %d)"
                               % (os.path.relpath(chemin, RACINE).replace("\\", "/"), n + 1, fonction, ligne_def + 1))
                        break


def verifier_la_vie_du_camp():
    """Fiche 12, révision du 16/10 : un oubli ici ne se verrait qu'en jeu, en silence. Chaque activité que la liaison
    donne a sa branche dans le comportement long ; chaque comportement lancé par le switch est déclaré auprès du jeu,
    et son arbre existe ; chaque variable du cerveau employée par nos arbres est déclarée. Rend (activités, variables)."""
    liaison = lire(os.path.join(PAK, "Scripts", "scriptorium", "liaison.lua"))
    arbres = {nom: lire(os.path.join(ARBRES, nom)) for nom in sorted(os.listdir(ARBRES)) if nom.endswith(".xml")}
    comportements = arbres.get("comportements.xml", "")
    donnees = set(re.findall(r"poser_l_activite\([^,()]*(?:\([^()]*\))?[^,()]*,\s*(\d+)\)", liaison))
    places = re.search(r"ordres_des_places\s*=\s*\{([^}]*)\}", liaison)
    if places:
        donnees |= set(re.findall(r"=\s*(\d+)", places.group(1)))
    if not donnees:
        erreur("vie du camp : aucune activité trouvée dans liaison.lua (poser_l_activite, ordres_des_places)")
    # L'activité 0 (attendre sur place, fiche 15, V73 b 3) n'a pas de branche : c'est la garde seule, au bas de la boucle.
    donnees.discard("0")
    branches = set(re.findall(r"\$scriptorium_activite == (\d+)", comportements))
    for activite in sorted(donnees - branches, key=int):
        erreur("vie du camp : l'activité %s est donnée par la liaison mais n'a pas de branche dans comportements.xml" % activite)
    declares = dict(re.findall(r'<SmartBehaviorTemplate Name="([^"]+)"[^>]*>\s*<TreeLocation TreeName="([^"]+)"', lire(TABLE_DES_COMPORTEMENTS)))
    noms_d_arbres = set(re.findall(r'<BehaviorTree name="([^"]+)"', comportements))
    for nom, texte in arbres.items():
        for lance in re.findall(r"<AddInterrupt Behavior=\"&apos;([^&]+)&apos;\"", texte):
            if lance not in declares:
                erreur("vie du camp : %s lance « %s », absent de %s" % (nom, lance, os.path.basename(TABLE_DES_COMPORTEMENTS)))
    for nom, arbre in declares.items():
        if arbre not in noms_d_arbres:
            erreur("vie du camp : « %s » est déclaré, mais son arbre « %s » n'est pas dans comportements.xml" % (nom, arbre))
    variables = set(re.findall(r'brain_variable_name="([^"]+)"', lire(TABLE_DES_VARIABLES)))
    employees = set()
    for texte in arbres.values():
        employees |= set(re.findall(r"\$(scriptorium_[a-z_]+)", texte))
    for variable in sorted(employees - variables):
        erreur("vie du camp : la variable du cerveau « %s » est employée par nos arbres mais pas déclarée" % variable)
    # V73 c 5 : « 0.5s » ne prend pas (la garde tournait sans attendre) ; les arbres du jeu n'écrivent que des nombres
    # entiers suivis de ms, s ou m, ou -1 (relevé du 16/10 dans Data/Scripts.pak), ou une variable (76 fois).
    for nom, texte in arbres.items():
        for duree in re.findall(r'duration="([^"]*)"', texte):
            litterale = re.fullmatch(r"&apos;(-1|\d+(ms|s|m))&apos;", duree)
            if not litterale and not re.fullmatch(r"\$[a-z_]+", duree):
                erreur("vie du camp : %s : durée « %s » hors des formes du jeu (entier suivi de ms, s ou m, ou -1, ou une variable)" % (nom, duree))
    # Fiche 18 (vu en jeu le 17/10 : un geste à un coup, fini, n'était pas relancé) : le geste du poste (CallBehavior
    # « $poste_geste ») et le geste tenu (UnstanceAction) sont chacun dans une boucle While, qui les relance quand ils finissent.
    # Lu par une pile de balises (les commentaires ôtés), pas par un lecteur XML strict : nos arbres ont des commentaires
    # que le jeu lit mais qu'ElementTree refuse.
    pile, gestes = [], 0
    for m in re.finditer(r"<(/?)([A-Za-z_]+)([^>]*?)(/?)>", re.sub(r"<!--.*?-->", "", comportements, flags=re.S)):
        fermante, balise, attributs, seule = m.groups()
        if fermante:
            while pile and pile.pop() != balise:
                pass
            continue
        if (balise == "CallBehavior" and 'BehaviorName="$poste_geste"' in attributs) or balise == "UnstanceAction":
            gestes += 1
            englobante = next((b for b in reversed(pile) if b in ("While", "IfCondition")), None)
            if englobante != "While":
                erreur("vie du camp : « %s » n'est dans aucune boucle While : il ne serait pas relancé quand il finit" % balise)
        if not seule:
            pile.append(balise)
    if gestes < 2:
        erreur("vie du camp : le geste du poste ou le geste tenu est introuvable dans comportements.xml")
    # Fiche 12 (les valeurs de l'arbre en données) : chaque valeur de hommes.cerveau a sa variable de cerveau, déclarée,
    # lue par un arbre ; chaque variable du cerveau lue par un arbre a sa valeur au catalogue ; et l'arbre ne la lit
    # jamais seule, mais avec la valeur par défaut du catalogue (« (a > 0 ? a : défaut) »), qui doit être la même (V73 c 10).
    hommes_lua = lire(os.path.join(PAK, "Scripts", "scriptorium", "hommes.lua"))
    bloc = re.search(r"hommes\.cerveau = \{(.*?)\n\}", hommes_lua, re.S)
    cles = set(re.findall(r"^\s*([a-z_]+) = \d+", bloc.group(1), re.M)) if bloc else set()
    if not cles:
        erreur("vie du camp : la table hommes.cerveau est introuvable ou vide dans hommes.lua")
    declarees = set(re.findall(r'brain_variable_name="scriptorium_cerveau_([a-z_]+)" type="int"', lire(TABLE_DES_VARIABLES)))
    valeurs = dict((cle, int(v)) for cle, v in re.findall(r"^\s*([a-z_]+) = (\d+)", bloc.group(1), re.M)) if bloc else {}
    lues = set()
    for texte in arbres.values():
        lues |= set(re.findall(r"\$scriptorium_cerveau_([a-z_]+)", texte))
    for cle in sorted(cles - declarees):
        erreur("vie du camp : hommes.cerveau.%s n'a pas sa variable scriptorium_cerveau_%s déclarée" % (cle, cle))
    for nom, texte in arbres.items():
        lectures = re.findall(r"\$scriptorium_cerveau_([a-z_]+)", texte)
        defauts = re.findall(r"\(\$scriptorium_cerveau_([a-z_]+) &gt; 0 \? \$scriptorium_cerveau_([a-z_]+) : (\d+)\)", texte)
        if len(lectures) != 2 * len(defauts):
            erreur("vie du camp : %s lit une valeur du cerveau sans sa valeur par défaut" % nom)
        for cle, cle2, defaut in defauts:
            if cle != cle2 or valeurs.get(cle) != int(defaut):
                erreur("vie du camp : %s : défaut de %s = %s, le catalogue dit %s" % (nom, cle, defaut, valeurs.get(cle)))
    for cle in sorted(cles - lues):
        erreur("vie du camp : hommes.cerveau.%s n'est lue par aucun arbre" % cle)
    for cle in sorted(lues - cles):
        erreur("vie du camp : scriptorium_cerveau_%s est lue par un arbre mais n'est pas dans hommes.cerveau" % cle)
    # Fiche 15, V73 b 1 : la liaison (le secours, la lecture au poste) et le switch (la relance) disent « occupé » par
    # les mêmes contextes ; un nom changé d'un seul côté ne se verrait qu'en jeu.
    ligne = re.search(r"^local CONTEXTES_OCCUPE = (.*)$", liaison, re.M)
    occupe_liaison = set(re.findall(r'"([A-Za-z_]+)" \}', ligne.group(1))) if ligne else set()
    occupe_switch = set(re.findall(r'<EntityContextCheck context="([^"]+)"', arbres.get("essai_ordres.xml", "")))
    if not occupe_liaison or occupe_liaison != occupe_switch:
        erreur("vie du camp : contextes « occupé » de la liaison %s, du switch %s : ils doivent être les mêmes"
               % (sorted(occupe_liaison), sorted(occupe_switch)))
    # Fiche 15, V73 b 2 (le plafond de relances, proposition du pair) : le switch ne lance jamais la vie du camp hors de
    # son plafond, et il compte ses arrêts, que le battement dit au journal. Le banc ne joue pas les arbres : le
    # « 3 relances, puis arrêt » se mesure en jeu.
    switch = arbres.get("essai_ordres.xml", "")
    ouverts, gardes, lancements = [], 0, 0
    for fermant, nom, attributs, seul in re.findall(r"<(/?)(\w+)([^>]*?)(/?)>", switch):
        if nom == "IfCondition" and not fermant and not seul:
            condition = re.search(r'condition="([^"]*)"', attributs)
            ouverts.append(condition.group(1) if condition else "")
        elif nom == "IfCondition" and fermant and ouverts:
            ouverts.pop()
        elif nom == "AddInterrupt" and "&apos;scriptorium_vie_du_camp&apos;" in attributs:
            lancements += 1
            if any("$relances &lt; $relances_max" in c for c in ouverts):
                gardes += 1
    if lancements == 0 or gardes != lancements:
        erreur("vie du camp : %d lancement(s) de la vie du camp dans le switch, %d sous le plafond de relances"
               % (lancements, gardes))
    # Fiche 21 (vu en jeu le 18/10) : sans ses deux branches parallèles qui traitent la boîte 'dialogMailbox' sans fin,
    # Henry voit « Parler » mais rien ne s'ouvre. Le switch doit garder un Parallel avec ces deux branches.
    paralleles = switch.split("<Parallel ", 1)
    branches = re.findall(r"<ProcessMessage inbox=\"&apos;dialogMailbox&apos;\"[^>]*timeout=\"&apos;-1&apos;\"[^>]*>\s*"
                          r"<(Function_switch_handleDialog|Function_switch_handleChat) ", paralleles[-1])
    if len(paralleles) != 2 or sorted(branches) != ["Function_switch_handleChat", "Function_switch_handleDialog"]:
        erreur("dialogues : le switch doit traiter 'dialogMailbox' dans deux branches parallèles sans fin (dialogue, "
               "conversation) ; trouvé : %s" % sorted(branches))
    if "$scriptorium_vie_arrets = $scriptorium_vie_arrets + 1" not in switch:
        erreur("vie du camp : le switch ne compte pas ses arrêts (scriptorium_vie_arrets)")
    # V73 b 2, vu en jeu : retenu par le plafond, le switch restait « à lancer » alors que le pouls repartait, et relançait
    # à la fin de la fenêtre un comportement vivant. Un pouls qui avance le remet « en marche », quel que soit son état.
    if '<IfCondition condition="$scriptorium_vie_pouls ~= $pouls_vu"' not in switch:
        erreur("vie du camp : le pouls qui avance doit remettre le switch en marche quel que soit son état")
    # Fiche 13, la garde de la tenue (relecture du pair, principe d'Alex) : le switch compte les fins de combat au front
    # descendant du contexte de combat, lu à chaque tour ; le battement les relit pour rhabiller l'homme.
    front = re.search(r'<IfCondition condition="\$etait_en_combat &amp; ~\$en_combat"[^>]*>\s*'
                      r'<Expression expressions="\$scriptorium_fins_de_combat = \$scriptorium_fins_de_combat \+ 1" />', switch)
    if not front or '<Expression expressions="$etait_en_combat = $en_combat" />' not in switch:
        erreur("vie du camp : le switch doit compter les fins de combat au front descendant du contexte de combat")
    # Fiche 15, V73 d 1 (tenir un poste) : la liaison pose le point regardé avant l'ordre 12, et la branche 12 marche au
    # poste puis se tourne vers ce point ; un nom changé d'un seul côté ne se verrait qu'en jeu.
    if '"scriptorium_regard"' not in liaison or "poser_l_activite(entite, 12)" not in liaison:
        erreur("vie du camp : la liaison ne pose pas le point regardé (scriptorium_regard) avec l'ordre 12")
    branche = comportements.split("$scriptorium_activite == 12", 1)
    tourne = r'<Turn target="\$scriptorium_regard" align="false" />'
    if (len(branche) != 2 or 'destinationSpecification="$scriptorium_essai_point"' not in branche[1]
            or not re.search(tourne + r'\s*<Expression expressions="\$scriptorium_en_poste = \$scriptorium_en_poste \+ 1" />',
                             branche[1])
            or not re.search(r'<UnstanceAction unstance="LookingAround" locationObject="" slaveObject="" />\s*'
                             r'<SuppressFailure>\s*' + tourne, branche[1])):
        erreur("vie du camp : la branche 12 (tenir un poste) doit marcher au poste, se tourner vers $scriptorium_regard "
               "avant de se dire « en poste », et de nouveau après chaque geste")
    # Fiche 15, V73 d 2 (la ronde) : la liaison donne l'ordre 13 et sait recevoir l'appel de l'arbre ; la branche 13
    # marche au point, compte l'arrivée, met la pause par défaut, appelle la liaison sous pcall (relecture du pair : une
    # erreur non attrapée casse la branche) au nom de la table du socle, se tourne vers le dehors, puis attend la pause
    # écrite par le Lua. Aucun commentaire Lua dans un appel de l'arbre (le pair : « -- » coupe tout le reste, en silence).
    chemin = re.search(r'^Scriptorium\.chemin = "([A-Za-z_.]+)"', lire(os.path.join(PAK, "Scripts", "scriptorium", "noyau.lua")), re.M)
    appel = '<ExecuteLua code="pcall(function() %s.jeu.au_point_de_ronde(entity, data) end)" />' % (chemin.group(1) if chemin else "?")
    if ("poser_l_activite(entite, 13)" not in liaison or "function liaison.au_point_de_ronde(entite, donnees)" not in liaison
            or 'donnees.ronde_pause = string.format("%dms", pas.pause_ms)' not in liaison):
        erreur("vie du camp : la liaison doit donner l'ordre 13 et écrire la pause de la ronde (liaison.au_point_de_ronde)")
    branche = comportements.split("$scriptorium_activite == 13", 1)
    motif = (r'destinationSpecification="\$scriptorium_essai_point"[^>]*stopWithinDistance="\$ronde_arret" '
             r'stopDistanceVariation="\$ronde_ecart"[^>]*/>[\s\S]*?'
             r'<Expression expressions="\$scriptorium_essai_arrive = \$scriptorium_essai_arrive \+ 1" />\s*'
             r'</Sequence>\s*</SuppressFailure>\s*<Expression expressions="\$ronde_pause = concat\(\$sortie_ms, &apos;ms&apos;\)" />\s*'
             r'<SuppressFailure>\s*' + re.escape(appel) + r'\s*</SuppressFailure>\s*<SuppressFailure>\s*' + tourne
             + r'\s*</SuppressFailure>\s*<Wait duration="\$ronde_pause" ')
    if len(branche) != 2 or not re.search(motif, branche[1]):
        erreur("vie du camp : la branche 13 (la ronde) doit marcher au point, compter l'arrivée, appeler "
               "%s.jeu.au_point_de_ronde sous pcall, se tourner vers $scriptorium_regard, puis attendre $ronde_pause"
               % (chemin.group(1) if chemin else "?"))
    # Fiche 15, V73 e (le rassemblement) : la branche 12 écrit l'allure sous condition, sous la forme du jeu
    # (`$speed = $enum:movementSpeed.run`, AI/crime/followhelpingnpc.xml), et la donne au Move ; la liaison l'écrit avec
    # le point et le regard.
    branche12 = comportements.split("$scriptorium_activite == 12", 1)
    allure = (r'<Expression expressions="\$allure = \$enum:movementSpeed\.walk" />\s*'
              r'<IfCondition condition="\$scriptorium_allure == 1" failOnCondition="false">\s*'
              r'<Expression expressions="\$allure = \$enum:movementSpeed\.run" />\s*</IfCondition>[\s\S]*?'
              r'<Move destinationSpecification="\$scriptorium_essai_point"[^>]*speed="\$allure" stopWithinDistance="\$poste_arret"')
    if len(branche12) != 2 or not re.search(allure, branche12[1].split("$scriptorium_activite == 13")[0]):
        erreur("vie du camp : la branche 12 doit écrire l'allure (marche, puis course si $scriptorium_allure == 1) et la "
               "donner au Move du poste")
    if '<Variable name="allure" type="enum:movementSpeed"' not in comportements:
        erreur("vie du camp : la variable de l'arbre allure (enum:movementSpeed) n'est pas déclarée")
    if '"scriptorium_allure", allure == "course" and 1 or 0' not in liaison:
        erreur("vie du camp : la liaison doit écrire scriptorium_allure à chaque ordre de poste")
    # Fiche 15, V73 f 1 (suivre Henry) : la branche 14 appelle la fonction de suivi du jeu avec le chef du cerveau et nos
    # huit distances ; la liaison écrit le chef avant l'ordre 14 ; et la fonction du jeu a toujours ses paramètres (une
    # mise à jour du jeu casserait l'appel en silence).
    branche14 = comportements.split("$scriptorium_activite == 14", 1)
    attendus = {"leader": "$scriptorium_chef", "run2sprint": "$suivi_course_sprint", "run2walk": "$suivi_course_marche",
                "sprint2run": "$suivi_sprint_course", "sprint2walk": "$suivi_sprint_marche", "startDistance": "$suivi_depart",
                "stopDistance": "$suivi_arret", "walk2run": "$suivi_marche_course", "walk2sprint": "$suivi_marche_sprint"}
    appel_suivi = re.search(r"<Function_followNpc\b([^>]*)/>", branche14[1]) if len(branche14) == 2 else None
    trouves = dict(re.findall(r'(\w+)="([^"]*)"', appel_suivi.group(1))) if appel_suivi else {}
    if not appel_suivi or any(trouves.get(k) != v for k, v in attendus.items()):
        erreur("vie du camp : la branche 14 doit appeler Function_followNpc avec $scriptorium_chef et les huit distances : %s" % trouves)
    if "poser_l_activite(entite, 14)" not in liaison or '"scriptorium_chef", wuid' not in liaison:
        erreur("vie du camp : la liaison doit écrire scriptorium_chef avant l'ordre 14")
    pak = os.path.join(JEU, "Data", "Scripts.pak")
    if os.path.exists(pak):
        with zipfile.ZipFile(pak) as archive:
            utils = archive.read("AI/move/moveUtils.xml").decode("utf-8", "replace")
        fonction = re.search(r'<BehaviorTree name="followNpc" is_function="1">(.*?)</BehaviorTree>', utils, re.S)
        parametres = dict(re.findall(r'<Variable name="(\w+)" type="([^"]+)"[^>]*requirementType="In"', fonction.group(1))) if fonction else {}
        if not fonction or parametres.get("leader") != "_wuid" or set(attendus) - set(parametres):
            erreur("vie du camp : la fonction followNpc du jeu a changé (paramètres : %s)" % parametres)
    # Fiche 15, V73 f 1 bis (l'escorte en formation) : la branche 15 lit le modèle par le Lua, ouvre la formation et suit
    # son chef ; la branche 16 retrouve la formation du chef et s'y range ; chaque modèle du catalogue existe dans le jeu.
    branche15 = comportements.split("$scriptorium_activite == 15", 1)
    branche16 = comportements.split("$scriptorium_activite == 16", 1)
    appel15 = '<ExecuteLua code="pcall(function() %s.jeu.nom_de_la_formation(entity, data) end)" />' % (chemin.group(1) if chemin else "?")
    if (len(branche15) != 2 or appel15 not in branche15[1].split("$scriptorium_activite == 16")[0]
            or '<MakeFormation FormationName="$formation_nom" HandleVariable="$formation_menee" />' not in branche15[1]
            or '<Function_followNpc leader="$scriptorium_chef"' not in branche15[1].split("$scriptorium_activite == 16")[0]):
        erreur("vie du camp : la branche 15 doit lire le modèle par le Lua, ouvrir la formation et suivre son chef")
    if (len(branche16) != 2
            or '<GetMemberFormation MemberWUID="$scriptorium_chef" FormationHandleOut="$formation_suivie" />' not in branche16[1]
            or branche16[1].split("$scriptorium_activite == 17")[0].count('<FormationFollower FormationHandle="$formation_suivie"') != 4
            or '<Function_followNpc leader="$scriptorium_chef"' not in branche16[1]):
        erreur("vie du camp : la branche 16 doit retrouver la formation de son chef, s'y ranger (un nœud par mode), et le "
               "suivre normalement tant qu'elle n'est pas ouverte")
    # Relecture du pair : la formation n'est fermée que quand le chef cesse de mener (jamais au premier échec de sa marche :
    # chez Alex, cela défaisait toute la troupe) ; et « fermer avant d'ouvrir » : la branche 15 ferme l'ancienne formation
    # du même chef juste avant d'en ouvrir une (après un rattrapage, l'ordre redonné rouvrait sans fermer).
    fermer = re.search(r'<IfCondition condition="\$scriptorium_activite ~= 15 &amp; \$scriptorium_activite ~= 18 &amp; '
                       r'\$scriptorium_activite ~= 20 &amp; \$formation_menee ~= \$__null"[^>]*>\s*'
                       r'<SuppressFailure>\s*<EndFormation FormationHandle="\$formation_menee" />', comportements)
    avant_d_ouvrir = re.findall(r'<SuppressFailure>\s*<EndFormation FormationHandle="\$formation_menee" />\s*</SuppressFailure>\s*'
                                r'<SuppressFailure>\s*<MakeFormation FormationName="\$formation_nom"', comportements)
    if not fermer or len(avant_d_ouvrir) != 3 or comportements.count("<EndFormation") != 4 or "<FuseBox" in comportements:
        erreur("vie du camp : la formation se ferme quand le chef cesse de mener (ni 15, ni 18, ni 20), et juste avant d'en "
               "rouvrir une, à pied, à cheval et vers un point (quatre EndFormation, aucun FuseBox)")
    if "poser_l_activite(entite, 15)" not in liaison or "poser_l_activite(entite, 16)" not in liaison:
        erreur("vie du camp : la liaison doit donner les ordres 15 et 16")
    bloc_formations = re.search(r"hommes\.formations = \{(.*?)\n\}", hommes_lua, re.S)
    modeles = re.findall(r"^\s*([A-Za-z_0-9]+) = \d+", bloc_formations.group(1), re.M) if bloc_formations else []
    if not modeles:
        erreur("vie du camp : la table hommes.formations est introuvable ou vide")
    if os.path.exists(pak):
        with zipfile.ZipFile(pak) as archive:
            definitions = archive.read("AI/FormationDefinitions.xml").decode("utf-8", "replace")
        for modele in modeles:
            if '<Formation name="%s">' % modele not in definitions:
                erreur("vie du camp : la formation « %s » du catalogue n'existe plus dans le jeu" % modele)
    # Fiche 15, V73 f 2 a (la sonde à cheval) : la branche 17 monte le cheval du cerveau par la posture « horse » du jeu
    # (la forme de moveOnHorse), y attend que la monture se stabilise, compte « en selle » et suit son chef ; si la monte
    # échoue, elle le suit à pied (jamais figé).
    branche17 = comportements.split("$scriptorium_activite == 17", 1)
    selle = (r'<Expression expressions="\$selle_avant = \$scriptorium_en_selle" />\s*<Parallel successMode="Any" failureMode="Any">\s*'
             r'<SuppressFailure>\s*'
             r'<StanceElement smartObject="\$scriptorium_cheval" stance="horse"[^>]*>\s*<Sequence>\s*<WaitAction />\s*'
             r'<Expression expressions="\$scriptorium_en_selle = \$scriptorium_en_selle \+ 1" />\s*'
             r'<While [^>]*>\s*<Sequence>\s*<SuppressFailure>\s*'
             r'<ExecuteLua code="pcall\(function\(\) [A-Za-z_.]+\.jeu\.allure_vers_chef\(entity, data\) end\)" />[\s\S]*?'
             r'</While>\s*</Sequence>\s*</StanceElement>\s*</SuppressFailure>\s*'
             r'<Sequence>\s*<Wait duration="\$monte_delai"[^>]*/>\s*'
             r'<While doFail="false" propagateChildFail="false" condition="\$scriptorium_en_selle &gt; \$selle_avant">[\s\S]*?</Parallel>\s*'
             r'<Function_followNpc leader="\$scriptorium_chef"')
    if len(branche17) != 2 or not re.search(selle, branche17[1]):
        erreur("vie du camp : la branche 17 doit monter le cheval par la posture horse, le mener à l'allure de son chef (V73 f 2 g), "
               "et à pied si la monte échoue")
    if "poser_l_activite(entite, 17)" not in liaison or '"scriptorium_cheval", wuid_monture' not in liaison:
        erreur("vie du camp : la liaison doit écrire scriptorium_cheval avant l'ordre 17")
    # Fiche 15, V73 f 2 b (la troupe à cheval, relue par le pair) : la branche 18 mène à cheval, la formation ouverte
    # HORS de la posture (dans la branche à part sans marche) ; la branche 19 se range à cheval, en MoveHistory ou
    # Relaxed, dans la posture ; les deux bornent la monte et comptent la monte manquée ; la liaison donne 18 et 19.
    branche18 = comportements.split("$scriptorium_activite == 18", 1)
    branche19 = comportements.split("$scriptorium_activite == 19", 1)
    corps18 = branche18[1].split("$scriptorium_activite == 19")[0] if len(branche18) == 2 else ""
    corps19 = branche19[1].split("$scriptorium_activite == 20")[0] if len(branche19) == 2 else ""
    # Fiche 17, 4 b (la sonde du 17/10 : l'ordre 18 ne mène pas vers un objet du monde) : la branche 20, la 18 vers un
    # point (scriptorium_essai_point) ; la monte manquée : à pied vers le point.
    branche20 = comportements.split("$scriptorium_activite == 20", 1)
    corps20 = branche20[1] if len(branche20) == 2 else ""
    manquee = '<Expression expressions="$scriptorium_monte_manquee = $scriptorium_monte_manquee + 1" />'
    mener_a_cheval = (r'<Parallel successMode="Any" failureMode="Any">\s*<Sequence>\s*<SuppressFailure>\s*'
                      r'<EndFormation FormationHandle="\$formation_menee" />\s*</SuppressFailure>\s*<SuppressFailure>\s*'
                      r'<MakeFormation FormationName="\$formation_nom" HandleVariable="\$formation_menee" />\s*</SuppressFailure>\s*'
                      r'<Wait duration="&apos;-1&apos;"[^>]*/>\s*</Sequence>\s*<Sequence>\s*'
                      r'<Expression expressions="\$selle_avant = \$scriptorium_en_selle" />\s*<Parallel successMode="Any" failureMode="Any">\s*'
                      r'<SuppressFailure>\s*<StanceElement smartObject="\$scriptorium_cheval" stance="horse"[^>]*>\s*<Sequence>\s*'
                      r'<WaitAction />\s*<Expression expressions="\$scriptorium_en_selle = \$scriptorium_en_selle \+ 1" />\s*'
                      r'<While [^>]*>\s*<Sequence>\s*<SuppressFailure>\s*'
                      r'<ExecuteLua code="pcall\(function\(\) [A-Za-z_.]+\.jeu\.allure_vers_chef\(entity, data\) end\)" />')
    # V73 f 2 f (principe d'Alex, relu par le pair) : le chef monté se mène lui-même par un Move vers son chef, à l'allure
    # mesurée toutes les « allure_cadence », redonné quand l'allure change ; une allure par IfCondition.
    allures18 = re.findall(r'<IfCondition condition="\$allure_tenue == (\d)" failOnCondition="false">\s*'
                           r'<Expression expressions="\$allure = \$enum:movementSpeed\.(\w+)" />', corps18)
    if (sorted(allures18) != [("0", "walk"), ("1", "run"), ("2", "dash"), ("3", "sprint")]
            or not re.search(r'<Move destinationSpecification="\$scriptorium_chef"[^>]*speed="\$allure" stopWithinDistance="\$allure_arret"'
                             r'[^>]*additionalParams="\$allure_parametres"[^>]*/>\s*</SuppressFailure>\s*</IfCondition>\s*'
                             r'<Wait duration="\$allure_cadence"', corps18)
            or 'name="allure_parametres" type="additionalMoveParams" values="destChangedThreshold(' not in comportements
            or '<While doFail="false" propagateChildFail="false" condition="$allure_code == $allure_tenue">' not in corps18
            or corps18.count('allure_vers_chef(entity, data)') != 2 or '<Wait duration="$allure_cadence"' not in corps18):
        erreur("vie du camp : la branche 18 doit régler l'allure du chef monté sur la vitesse mesurée de son chef (quatre "
               "allures, un Move vers son chef qui suit sa cible et se redonne à chaque cadence, une mesure à chaque cadence)")
    if (not corps18 or not re.search(mener_a_cheval, corps18) or appel15 not in corps18 or manquee not in corps18
            or '<Wait duration="$monte_delai"' not in corps18):
        erreur("vie du camp : la branche 18 doit ouvrir la formation hors de la posture et mener à cheval, la monte bornée "
               "et la monte manquée comptée")
    ranger_a_cheval = (r'<StanceElement smartObject="\$scriptorium_cheval" stance="horse"[^>]*>\s*<Sequence>\s*<WaitAction />\s*'
                       r'<Expression expressions="\$scriptorium_en_selle = \$scriptorium_en_selle \+ 1" />\s*'
                       r'<While [^>]*>\s*<Sequence>\s*<SuppressFailure>\s*'
                       r'<ExecuteLua code="pcall\(function\(\) [A-Za-z_.]+\.jeu\.allure_vers_chef\(entity, data\) end\)" />\s*</SuppressFailure>\s*'
                       r'<IfCondition condition="\$allure_perdu == 1" failOnCondition="false">\s*'
                       r'<While doFail="false" propagateChildFail="false" condition="\$scriptorium_essai_numero == \$numero_tenu &amp; \$allure_perdu == 1">'
                       r'[\s\S]*?</IfCondition>\s*<IfCondition condition="\$allure_perdu == 0" failOnCondition="false">\s*'
                       r'<Parallel successMode="Any" failureMode="Any">\s*<Sequence>\s*<Expression expressions="\$en_formation = 0" />\s*'
                       r'<SuppressFailure>\s*<Sequence>\s*'
                       r'<GetMemberFormation MemberWUID="\$scriptorium_chef" FormationHandleOut="\$formation_suivie" />')
    # V73 f 2 g : perdu, la boucle d'allure vers son chef ; rangé, une mesure toutes les « reessai » ; sans formation, la
    # boucle d'allure bornée par le réessai (plus de followNpc en selle).
    rang19 = corps19.split('stance="horse"', 1)[-1].split("</StanceElement>")[0]
    if ('<While doFail="false" propagateChildFail="false" condition="$allure_perdu == 0">' not in rang19
            or rang19.count("allure_vers_chef(entity, data)") != 6 or 'nodeLabel="73110810"' in comportements):
        erreur("vie du camp : la branche 19 doit mener un suiveur perdu à l'allure de son chef, mesurer le suiveur rangé, et "
               "ne plus suivre en selle par followNpc")
    modes19 = re.findall(r'FormationMode="(\w+)"', corps19.split('stance="horse"', 1)[-1].split("</StanceElement>")[0])
    if (not corps19 or not re.search(ranger_a_cheval, corps19) or sorted(modes19) != ["MoveHistory", "Relaxed"]
            or manquee not in corps19 or '<Wait duration="$monte_delai"' not in corps19):
        erreur("vie du camp : la branche 19 doit se ranger à cheval dans la formation de son chef (MoveHistory ou Relaxed, "
               "un nœud par mode), se mener vers lui quand il est perdu, la monte bornée et la monte manquée comptée")
    allures20 = re.findall(r'<IfCondition condition="\$allure_tenue == (\d)" failOnCondition="false">\s*'
                           r'<Expression expressions="\$allure = \$enum:movementSpeed\.(\w+)" />', corps20)
    if (not corps20 or not re.search(mener_a_cheval, corps20) or appel15 not in corps20 or manquee not in corps20
            or '<Wait duration="$monte_delai"' not in corps20
            or sorted(allures20) != [("0", "walk"), ("1", "run"), ("2", "dash"), ("3", "sprint")]
            or not re.search(r'<Move destinationSpecification="\$scriptorium_essai_point"[^>]*speed="\$allure" '
                             r'stopWithinDistance="\$allure_arret"', corps20)
            or not re.search(r'<Move destinationSpecification="\$scriptorium_essai_point"[^>]*speed="Run"', corps20)
            or "$scriptorium_chef" in corps20 or corps20.count('allure_vers_chef(entity, data)') != 2):
        erreur("vie du camp : la branche 20 doit ouvrir la formation et mener à cheval vers le point (quatre allures, un Move "
               "vers scriptorium_essai_point), la monte bornée, la monte manquée comptée et finie à pied vers le point")
    if comportements.count(manquee) != 4:
        erreur("vie du camp : les branches 17, 18, 19 et 20 comptent chacune la monte manquée")
    # Fiche 15, V73 f 2 c : l'homme marche jusqu'à son cheval ; la liaison écrit la marche, l'arbre l'ajoute au délai.
    approche = re.search(r'<Expression expressions="\$monte_delai_ms = \(\$scriptorium_cerveau_monte_delai_ms[^>]*/>\s*'
                         r'<Expression expressions="\$monte_delai_ms = \$monte_delai_ms \+ \(\$scriptorium_monte_approche_ms &gt; 0 \? '
                         r'\$scriptorium_monte_approche_ms : 0\)" />\s*<Expression expressions="\$monte_delai = concat', comportements)
    if not approche or '"scriptorium_monte_approche_ms", approche' not in liaison:
        erreur("vie du camp : le délai de la monte s'allonge de la marche jusqu'au cheval (écrite par la liaison, ajoutée par "
               "l'arbre avant la durée)")
    if ("poser_l_activite(entite, 18)" not in liaison or "poser_l_activite(entite, 19)" not in liaison
            or '"scriptorium_monte_manquee"' not in liaison):
        erreur("vie du camp : la liaison doit donner les ordres 18 et 19 et lire les montes manquées")
    # Relecture du pair (V73 f 2 a) : le cheval naît sur une âme de cheval du jeu (archétype 3, classe 7, relue dans
    # Tables.pak, lecture seule), hors de la sauvegarde.
    ame = re.search(r'liaison\.ame_de_cheval = "([0-9a-f-]{36})"', liaison)
    if not ame or "guidSharedSoulId = liaison.ame_de_cheval, bSaved_by_game = false" not in liaison:
        erreur("vie du camp : le cheval doit naître sur une âme de cheval du jeu (liaison.ame_de_cheval), hors de la sauvegarde")
    tables = os.path.join(JEU, "Data", "Tables.pak")
    if ame and os.path.exists(tables):
        with zipfile.ZipFile(tables) as archive:
            ames = archive.read("Libs/Tables/rpg/soul.xml").decode("utf-8", "replace")
        ligne = re.search(r'<soul [^>]*soul_id="%s"[^>]*/>' % ame.group(1), ames)
        if not ligne or 'soul_archetype_id="3"' not in ligne.group(0) or 'soul_class_id="7"' not in ligne.group(0):
            erreur("vie du camp : l'âme %s n'est pas une âme de cheval du jeu (archétype 3, classe 7)" % ame.group(1))
    if '<Variable name="ronde_pause" type="_string"' not in comportements:
        erreur("vie du camp : la variable de l'arbre ronde_pause (_string) n'est pas déclarée")
    for nom, texte in arbres.items():
        for code in re.findall(r'<ExecuteLua code="([^"]*)"', texte):
            if "--" in code or "&#10;" in code:
                erreur("vie du camp : %s : un appel au Lua avec un commentaire ou sur plusieurs lignes : %s" % (nom, code))
    return len(donnees), len(employees)


def principal(arguments):
    # Un nom tchèque (« ř ») dans un message ne doit pas faire planter l'affichage sous cp1252 (vu le 17/10).
    try:
        sys.stdout.reconfigure(errors="replace")
    except (AttributeError, ValueError) as exc:
        print("affichage : réglage des caractères impossible (%s)" % exc)
    strict = "--strict" in arguments
    print("Vérification complète du socle (%s)" % ("mode strict" if strict else "mode suivi"))

    lua = runtime_lua()
    if lua is not None:
        print("1. syntaxe Lua : %d fichiers" % verifier_syntaxe(lua))
        if not erreurs:
            reussis, echecs, nb_fichiers = executer_banc(lua)
            print("2. banc Lua : %d fichiers d'essais, %d vérifications réussies, %d échecs" % (nb_fichiers, reussis, echecs))
            taille = lua.globals().Essais.taille_du_registre_plein
            if taille:
                print("   registre d'un camp plein (80 hommes, livre plein, enceinte, réserves) : %d octets, %d tranche(s) de 30 000"
                      % (taille, -(-taille // 30000)))
            print("2 bis. ordres par fichier : %d commandes, aller-retour avec la liaison vérifié" % verifier_ordres())
            verifier_identifiants()
            print("2 ter. liaison : entités désignées par leur nom, caps de boussole, pose au sol, registre par jeton, argent d'Henry sûr, vérifié")
            print("2 quater. réglages par fichier : %d valeurs réglables, outil, liaison et installateur vérifiés"
                  % verifier_reglages_par_fichier())
        else:
            print("2. banc Lua : non lancé (syntaxe en erreur)")

    print("2 quater bis. séances : %d cas éprouvés ; installateur, ordonner, regler et recharger refusent hors séance "
          "sans rien écrire" % verifier_seances())

    print("2 quinquies. âmes : %d âmes des réserves, table et liaison accordées, notre cerveau et la Compagnie partout" % verifier_ames())
    print("2 sexies. équipement : %d préréglages dans la liaison, chaque règle trouve les siens" % verifier_equipement())
    print("2 septies. vie du camp : %d activités données par la liaison, chacune a sa branche ; %d variables du cerveau "
          "employées par nos arbres, toutes déclarées ; comportements lancés déclarés" % verifier_la_vie_du_camp())
    verifier_l_ordre_des_locales()
    print("2 octies. ordre des locales : aucune fonction locale employée avant sa définition")
    print("3. noms interdits : %d" % verifier_noms())
    print("3 bis. un seul nom par table : %d noms relevés, table posée par le seul noyau" % verifier_un_seul_nom())
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
