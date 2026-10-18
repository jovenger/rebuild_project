#include "AiPanel.h"

#include "core/Log.h"

namespace sv::app
{
namespace
{
    constexpr const char* kMod = "AiPanel";

    void styleTitle (juce::Label& l, const juce::String& text)
    {
        l.setText (text, juce::dontSendNotification);
        l.setFont (juce::FontOptions (14.0f, juce::Font::bold));
        l.setColour (juce::Label::textColourId, juce::Colour (0xff3fa7ff));
    }

    void styleResult (juce::TextEditor& e)
    {
        e.setMultiLine (true, true);
        e.setReadOnly (true);
        e.setScrollbarsShown (true);
        e.setFont (juce::FontOptions (12.0f));
        e.setColour (juce::TextEditor::backgroundColourId, juce::Colour (0xff15181c));
    }
}

class AiPanel::Content final : public juce::Component
{
public:
    juce::Label status, t1, t2, t3, t4, t5, t6, beatFolderL, lengthL;
    juce::TextEditor askText, diagResult, writeText, writeResult, styleText, instruPrompt, instruResult, askResult;
    juce::TextButton askBtn { "Demander" }, diagBtn { "Diagnostic du mix" }, writeBtn { juce::String (juce::CharPointer_UTF8 ("Écrire")) },
        addLyricsBtn { "Ajouter aux paroles" }, styleBtn { juce::String (juce::CharPointer_UTF8 ("Créer le style")) }, applyStyleBtn { "Appliquer" },
        deleteStyleBtn { "Supprimer" }, beatFolderBtn { "Dossier de beats..." }, scanBtn { "Analyser le dossier" },
        findBtn { "Trouver l'instru qui colle" }, importBeatBtn { "Importer cette instru" }, briefBtn { "Décrire l'instru d'après mes paroles"_u8 },
        generateBtn { juce::String (juce::CharPointer_UTF8 ("Générer l'instru (clé musique)")) };
    juce::ComboBox customStyles, beatResults;
    juce::Slider length;
    std::vector<analysis::BeatInfo> lastResults;

    Content()
    {
        for (auto* c : std::initializer_list<juce::Component*> { &status, &t1, &t2, &t3, &t4, &t5, &t6, &beatFolderL, &lengthL, &askText, &askResult,
                                                                 &diagResult, &writeText, &writeResult, &styleText, &instruPrompt, &instruResult,
                                                                 &askBtn, &diagBtn, &writeBtn, &addLyricsBtn, &styleBtn, &applyStyleBtn, &deleteStyleBtn,
                                                                 &beatFolderBtn, &scanBtn, &findBtn, &importBeatBtn, &briefBtn, &generateBtn,
                                                                 &customStyles, &beatResults, &length })
            addAndMakeVisible (*c);
        status.setFont (juce::FontOptions (12.0f));
        status.setJustificationType (juce::Justification::topLeft);
        styleTitle (t1, "Assistant avancé (piste sélectionnée)"_u8);
        styleTitle (t2, "Diagnostic du mix");
        styleTitle (t3, "Aide à l'écriture (IA)"_u8);
        styleTitle (t4, "Style sur mesure (IA)");
        styleTitle (t5, "Trouver une instru dans mon dossier de beats");
        styleTitle (t6, "Générer une instru (clé de génération musicale)"_u8);
        askText.setTextToShowWhenEmpty ("Ex. : la voix est noyée dans l'instru au refrain, je veux un son plus froid"_u8, juce::Colours::grey);
        writeText.setTextToShowWhenEmpty ("Ex. : écris un couplet de 8 lignes sur la persévérance, rimes en -é"_u8, juce::Colours::grey);
        styleText.setTextToShowWhenEmpty ("Ex. : drill mélancolique avec beaucoup d'espace"_u8, juce::Colours::grey);
        for (auto* e : { &askResult, &diagResult, &instruResult })
            styleResult (*e);
        writeResult.setMultiLine (true, true);
        writeResult.setFont (juce::FontOptions (13.0f));
        instruPrompt.setMultiLine (true, true);
        instruPrompt.setTextToShowWhenEmpty ("Description de l'instru (en anglais de préférence), ou clique sur « Décrire l'instru d'après mes paroles »"_u8,
                                             juce::Colours::grey);
        lengthL.setText ("Durée"_u8, juce::dontSendNotification);
        length.setRange (30.0, 300.0, 10.0);
        length.setValue (120.0);
        length.setTextValueSuffix (" s");
        length.setTextBoxStyle (juce::Slider::TextBoxRight, false, 60, 18);
        beatFolderL.setFont (juce::FontOptions (11.0f));
        setSize (380, 1290);
    }

    void resized() override
    {
        auto r = getLocalBounds().reduced (8);
        auto row = [&r] (int h) { auto x = r.removeFromTop (h); r.removeFromTop (4); return x; };
        status.setBounds (row (48));
        t1.setBounds (row (20));
        auto a = row (26);
        askBtn.setBounds (a.removeFromRight (90));
        a.removeFromRight (4);
        askText.setBounds (a);
        askResult.setBounds (row (60));
        r.removeFromTop (6);
        t2.setBounds (row (20));
        diagBtn.setBounds (row (28));
        diagResult.setBounds (row (150));
        r.removeFromTop (6);
        t3.setBounds (row (20));
        a = row (26);
        writeBtn.setBounds (a.removeFromRight (90));
        a.removeFromRight (4);
        writeText.setBounds (a);
        writeResult.setBounds (row (160));
        addLyricsBtn.setBounds (row (26));
        r.removeFromTop (6);
        t4.setBounds (row (20));
        a = row (26);
        styleBtn.setBounds (a.removeFromRight (110));
        a.removeFromRight (4);
        styleText.setBounds (a);
        a = row (26);
        deleteStyleBtn.setBounds (a.removeFromRight (80));
        a.removeFromRight (4);
        applyStyleBtn.setBounds (a.removeFromRight (80));
        a.removeFromRight (4);
        customStyles.setBounds (a);
        r.removeFromTop (6);
        t5.setBounds (row (20));
        a = row (26);
        beatFolderBtn.setBounds (a.removeFromLeft (150));
        a.removeFromLeft (4);
        scanBtn.setBounds (a);
        beatFolderL.setBounds (row (18));
        findBtn.setBounds (row (28));
        beatResults.setBounds (row (26));
        importBeatBtn.setBounds (row (26));
        r.removeFromTop (6);
        t6.setBounds (row (20));
        briefBtn.setBounds (row (26));
        instruPrompt.setBounds (row (80));
        a = row (26);
        lengthL.setBounds (a.removeFromLeft (50));
        length.setBounds (a);
        generateBtn.setBounds (row (28));
        instruResult.setBounds (row (90));
    }
};

AiPanel::AiPanel (Session& s) : session (s), content (std::make_unique<Content>())
{
    addAndMakeVisible (viewport);
    viewport.setViewedComponent (content.get(), false);
    viewport.setScrollBarsShown (true, false);
    auto& c = *content;

    c.askBtn.onClick = [this]
    {
        const auto request = content->askText.getText().trim();
        const int trackId = session.selectedTrack();
        if (request.isEmpty() || session.project().findTrack (trackId) == nullptr)
            return;
        auto p = std::make_shared<project::Project> (session.project());
        const auto summary = ai::describeProjectForAi (session.project(), {}, session.vocalAutoGainDb());
        const auto settings = aiSettings();
        runAsync ("Assistant", [this, p, request, trackId, summary, settings]
        {
            auto advice = std::make_shared<ai::MacroAdvice> (ai::adviseMacros (settings, request, *p, trackId, summary));
            return std::function<void()> ([this, advice, trackId, request]
            {
                content->askResult.setText (advice->explanation.isNotEmpty() ? advice->explanation : advice->error, false);
                if (advice->ok)
                {
                    session.updateTrack (trackId, [advice] (project::Track& t) { t.macros = advice->macros; t.timingStrength = advice->timingStrength; },
                                         true, (advice->usedAi ? "IA : " : "Assistant : ") + request);
                    content->askText.clear();
                }
            });
        });
    };

    c.diagBtn.onClick = [this]
    {
        auto p = std::make_shared<project::Project> (session.project());
        auto renders = std::make_shared<render::RenderSet>();
        for (const auto& t : session.project().tracks)
            if (auto r = session.renderFor (t.id))
                (*renders)[t.id] = r;
        const float gain = session.vocalAutoGainDb();
        const auto settings = aiSettings();
        runAsync ("Diagnostic", [this, p, renders, gain, settings]
        {
            auto d = std::make_shared<ai::MixDiagnosis> (ai::diagnoseMix (settings, *p, *renders, gain));
            return std::function<void()> ([this, d] { content->diagResult.setText (d->ok ? d->text : d->error, false); });
        });
    };

    c.writeBtn.onClick = [this]
    {
        const auto request = content->writeText.getText().trim();
        if (request.isEmpty())
            return;
        auto p = std::make_shared<project::Project> (session.project());
        const auto settings = aiSettings();
        runAsync ("Écriture"_u8, [this, p, request, settings]
        {
            auto w = std::make_shared<ai::WritingResult> (ai::helpWrite (settings, request, *p));
            return std::function<void()> ([this, w]
            {
                content->writeResult.setText (w->ok ? w->lyrics + (w->notes.isNotEmpty() ? "\n\n— Conseils : "_u8 + w->notes : juce::String()) : w->error, false);
            });
        });
    };
    c.addLyricsBtn.onClick = [this]
    {
        auto txt = content->writeResult.getText();
        const int cut = txt.indexOf ("\n\n— Conseils"_u8);
        if (cut >= 0)
            txt = txt.substring (0, cut);
        if (txt.trim().isEmpty())
            return;
        session.updateProject ([txt] (project::Project& p) { p.lyrics = p.lyrics.trim().isEmpty() ? txt.trim() : p.lyrics.trimEnd() + "\n" + txt.trim(); },
                               false, "Paroles ajoutées depuis l'IA"_u8);
        session.setStatus ("Texte ajouté à l'onglet Paroles"_u8);
    };

    c.styleBtn.onClick = [this]
    {
        const auto desc = content->styleText.getText().trim();
        if (desc.isEmpty())
            return;
        const auto settings = aiSettings();
        runAsync ("Style sur mesure", [this, desc, settings]
        {
            auto cs = std::make_shared<ai::CustomStyle> (ai::createCustomStyle (settings, desc));
            return std::function<void()> ([this, cs]
            {
                if (! cs->ok)
                {
                    session.setStatus (cs->error);
                    return;
                }
                auto list = session.settings().customStyles();
                if (auto* arr = list.getArray())
                    arr->add (cs->toVar());
                session.settings().setCustomStyles (list);
                session.settings().save();
                session.setStatus ("Style créé : "_u8 + cs->name + " — " + cs->explanation);
                content->styleText.clear();
                refresh();
                content->customStyles.setSelectedItemIndex (content->customStyles.getNumItems() - 1, juce::dontSendNotification);
            });
        });
    };
    c.applyStyleBtn.onClick = [this]
    {
        const int idx = content->customStyles.getSelectedItemIndex();
        const auto list = session.settings().customStyles();
        if (idx < 0 || list.getArray() == nullptr || idx >= list.getArray()->size())
            return;
        const auto cs = ai::CustomStyle::fromVar (list.getArray()->getReference (idx));
        session.setStyle (cs.base);
        const int trackId = session.selectedTrack();
        session.updateTrack (trackId, [cs] (project::Track& t) { t.macros = cs.macros; }, true, "Style sur mesure : " + cs.name);
        session.setStatus ("Style « "_u8 + cs.name + " » appliqué (base " + style::styleName (cs.base) + ")");
    };
    c.deleteStyleBtn.onClick = [this]
    {
        const int idx = content->customStyles.getSelectedItemIndex();
        auto list = session.settings().customStyles();
        if (auto* arr = list.getArray(); arr != nullptr && idx >= 0 && idx < arr->size())
        {
            arr->remove (idx);
            session.settings().setCustomStyles (list);
            refresh();
        }
    };

    c.beatFolderBtn.onClick = [this]
    {
        auto chooser = std::make_shared<juce::FileChooser> ("Dossier contenant tes instrus", session.settings().beatFolder());
        juce::Component::SafePointer<AiPanel> safe (this);
        chooser->launchAsync (juce::FileBrowserComponent::openMode | juce::FileBrowserComponent::canSelectDirectories,
                              [safe, chooser] (const juce::FileChooser& fc)
                              {
                                  if (safe != nullptr && fc.getResult() != juce::File())
                                  {
                                      safe->session.settings().setBeatFolder (fc.getResult());
                                      safe->refresh();
                                  }
                              });
    };
    c.scanBtn.onClick = [this]
    {
        const auto folder = session.settings().beatFolder();
        if (! folder.isDirectory())
        {
            session.setStatus ("Choisis d'abord ton dossier de beats");
            return;
        }
        runAsync ("Analyse des beats", [this, folder]
        {
            auto lib = std::make_shared<analysis::BeatLibrary>();
            const int n = lib->scan (folder);
            return std::function<void()> ([this, lib, n]
            {
                content->instruResult.setText (juce::String ((int) lib->beats.size()) + " instrus dans la bibliothèque ("_u8 + juce::String (n)
                                                   + " nouvellement analysées)"_u8, false);
            });
        });
    };
    c.findBtn.onClick = [this]
    {
        const auto folder = session.settings().beatFolder();
        if (! folder.isDirectory())
        {
            session.setStatus ("Choisis d'abord ton dossier de beats");
            return;
        }
        const auto lyrics = session.project().lyrics;
        const auto st = session.project().style;
        const auto settings = aiSettings();
        runAsync ("Recherche d'instru", [this, folder, lyrics, st, settings]
        {
            auto lib = std::make_shared<analysis::BeatLibrary>();
            lib->scan (folder);
            auto brief = std::make_shared<ai::InstruBrief> (ai::briefFromLyrics (settings, lyrics, st));
            analysis::BeatCriteria crit;
            crit.bpmMin = brief->bpmMin;
            crit.bpmMax = brief->bpmMax;
            crit.energy = brief->energy;
            crit.minor = brief->minor;
            auto ranked = std::make_shared<std::vector<std::pair<float, analysis::BeatInfo>>> (lib->rank (crit));
            return std::function<void()> ([this, brief, ranked]
            {
                content->beatResults.clear (juce::dontSendNotification);
                content->lastResults.clear();
                int id = 1;
                for (const auto& [score, b] : *ranked)
                {
                    if (id > 10)
                        break;
                    content->lastResults.push_back (b);
                    content->beatResults.addItem (juce::String (juce::roundToInt (score * 100)) + " % — "_u8 + juce::File (b.path).getFileNameWithoutExtension()
                                                      + " (" + juce::String (b.bpm, 0) + " BPM, " + b.key.toFrench() + ")", id++);
                }
                if (! content->lastResults.empty())
                    content->beatResults.setSelectedId (1, juce::dontSendNotification);
                content->instruResult.setText ("Critères : "_u8 + juce::String (brief->bpmMin, 0) + "-" + juce::String (brief->bpmMax, 0) + " BPM, énergie "_u8
                                                   + juce::String (brief->energy, 2) + (brief->minor ? ", mineur" : ", majeur") + "\n" + brief->explanation
                                                   + (ranked->empty() ? "\nAucune instru trouvée dans le dossier."_u8 : juce::String()),
                                               false);
            });
        });
    };
    c.importBeatBtn.onClick = [this]
    {
        const int idx = content->beatResults.getSelectedId() - 1;
        if (idx >= 0 && idx < static_cast<int> (content->lastResults.size()))
            session.importInstru (juce::File (content->lastResults[static_cast<size_t> (idx)].path));
    };

    c.briefBtn.onClick = [this]
    {
        const auto lyrics = session.project().lyrics;
        const auto st = session.project().style;
        const auto settings = aiSettings();
        runAsync ("Description de l'instru", [this, lyrics, st, settings]
        {
            auto brief = std::make_shared<ai::InstruBrief> (ai::briefFromLyrics (settings, lyrics, st));
            return std::function<void()> ([this, brief]
            {
                content->instruPrompt.setText (brief->prompt + ", " + juce::String (juce::roundToInt (0.5 * (brief->bpmMin + brief->bpmMax))) + " BPM, "
                                                   + (brief->minor ? "minor key" : "major key") + ", instrumental only",
                                               false);
                content->length.setValue (brief->lengthSec, juce::dontSendNotification);
                content->instruResult.setText (brief->explanation, false);
            });
        });
    };
    c.generateBtn.onClick = [this]
    {
        const auto settings = aiSettings();
        if (! settings.musicAvailable())
        {
            content->instruResult.setText ("La génération d'instru nécessite une clé de génération musicale (Paramètres > IA connectée)."_u8, false);
            return;
        }
        ai::MusicRequest rq;
        rq.apiKey = settings.musicKey;
        rq.prompt = content->instruPrompt.getText().trim();
        rq.lengthMs = static_cast<int> (content->length.getValue() * 1000.0);
        if (rq.prompt.isEmpty())
        {
            content->instruResult.setText ("Écris une description ou clique sur « Décrire l'instru d'après mes paroles »."_u8, false);
            return;
        }
        const auto out = session.project().audioDir().getChildFile ("instru_ia_" + juce::Time::getCurrentTime().formatted ("%Y%m%d_%H%M%S"));
        runAsync ("Génération d'instru"_u8, [this, rq, out]
        {
            auto res = std::make_shared<ai::MusicResponse> (ai::composeMusic (rq, out));
            return std::function<void()> ([this, res]
            {
                if (! res->ok)
                {
                    content->instruResult.setText ("Échec : "_u8 + res->error, false);
                    return;
                }
                content->instruResult.setText ("Instru générée : "_u8 + res->file.getFileName()
                                                   + "\nVérifie les conditions d'utilisation du service avant de sortir un morceau."_u8,
                                               false);
                session.importInstru (res->file);
            });
        });
    };
    refresh();
}

ai::AiSettings AiPanel::aiSettings() const
{
    ai::AiSettings s;
    auto& st = session.settings();
    s.enabled = st.aiEnabled();
    s.textKey = st.textAiKey();
    s.model = st.textAiModel().isNotEmpty() ? st.textAiModel() : juce::String (ai::kDefaultClaudeModel);
    s.musicKey = st.musicAiKey();
    return s;
}

void AiPanel::setBusy (bool b, const juce::String& what)
{
    busy = b;
    auto& c = *content;
    for (auto* btn : { &c.askBtn, &c.diagBtn, &c.writeBtn, &c.styleBtn, &c.scanBtn, &c.findBtn, &c.briefBtn, &c.generateBtn })
        btn->setEnabled (! b);
    if (b)
        session.setStatus (what + " en cours…"_u8);
}

void AiPanel::runAsync (const juce::String& what, std::function<std::function<void()> ()> job)
{
    if (busy)
        return;
    setBusy (true, what);
    SV_LOG_INFO (kMod, "Tâche IA : "_u8 + what);
    juce::Component::SafePointer<AiPanel> safe (this);
    juce::Thread::launch ([safe, job, what]
    {
        std::function<void()> done;
        try
        {
            done = job();
        }
        catch (const std::exception& e)
        {
            const juce::String msg = juce::String ("Erreur pendant « "_u8) + what + " » : "_u8 + e.what();
            done = [msg] { SV_LOG_ERROR (kMod, msg); };
        }
        juce::MessageManager::callAsync ([safe, done, what]
        {
            if (safe == nullptr)
                return;
            safe->setBusy (false, what);
            if (done)
                done();
            safe->session.setStatus (what + " terminé"_u8);
        });
    });
}

void AiPanel::refresh()
{
    auto& c = *content;
    const auto s = aiSettings();
    juce::String txt;
    txt << (s.textAvailable() ? "IA texte : ACTIVE ("_u8 + s.model + ")" : juce::String ("IA texte : inactive — mode local (assistant simple, diagnostic par règles)"))
        << "\n" << (s.musicAvailable() ? juce::String ("Génération d'instru : ACTIVE"_u8) : juce::String ("Génération d'instru : inactive (pas de clé)"_u8))
        << "\nSeul du texte est envoyé (jamais ton audio)."_u8;
    c.status.setText (txt, juce::dontSendNotification);
    c.writeBtn.setEnabled (! busy && s.textAvailable());
    c.styleBtn.setEnabled (! busy && s.textAvailable());
    c.generateBtn.setEnabled (! busy && s.musicAvailable());

    const auto folder = session.settings().beatFolder();
    c.beatFolderL.setText (folder.isDirectory() ? "Dossier : " + folder.getFullPathName() : juce::String ("Aucun dossier de beats choisi"),
                           juce::dontSendNotification);

    const int prev = c.customStyles.getSelectedItemIndex();
    c.customStyles.clear (juce::dontSendNotification);
    if (const auto* arr = session.settings().customStyles().getArray())
        for (int i = 0; i < arr->size(); ++i)
        {
            const auto cs = ai::CustomStyle::fromVar (arr->getReference (i));
            c.customStyles.addItem (cs.name + " (" + style::styleName (cs.base) + ")", i + 1);
        }
    if (prev >= 0 && prev < c.customStyles.getNumItems())
        c.customStyles.setSelectedItemIndex (prev, juce::dontSendNotification);
    c.customStyles.setTextWhenNothingSelected (c.customStyles.getNumItems() == 0 ? "Aucun style sur mesure" : "Choisir un style");
}

void AiPanel::paint (juce::Graphics& g)
{
    g.fillAll (juce::Colour (0xff1e2228));
}

void AiPanel::resized()
{
    viewport.setBounds (getLocalBounds());
    content->setSize (std::max (300, getWidth() - viewport.getScrollBarThickness()), content->getHeight());
}
} // namespace sv::app
