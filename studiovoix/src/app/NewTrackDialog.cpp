#include "NewTrackDialog.h"

#include "core/AudioIO.h"
#include "core/Log.h"
#include "core/analysis/ContentClassifier.h"

namespace sv::app
{
void showNewTrackDialog (Session& session, style::Role preselected)
{
    if (session.isRecording())
    {
        session.setStatus ("Nouvelle piste : arrête d'abord l'enregistrement"_u8);
        return;
    }
    const auto& roles = style::userTrackRoles();
    auto* w = new juce::AlertWindow ("Nouvelle piste",
                                     "Quel type de piste ? Les effets (autotune, EQ, compresseur, réverb…) se règlent tout seuls "
                                     "selon le type et le style du projet ("_u8 + style::styleName (session.project().style) + ").",
                                     juce::MessageBoxIconType::QuestionIcon);
    juce::StringArray labels;
    int initial = 0;
    for (size_t i = 0; i < roles.size(); ++i)
    {
        labels.add (style::userTrackLabel (roles[i]));
        if (roles[i] == preselected)
            initial = static_cast<int> (i);
    }
    w->addComboBox ("type", labels, "Type");
    w->addTextEditor ("name", session.nextTrackName (roles[static_cast<size_t> (initial)]), "Nom");
    w->addTextBlock ("La nouvelle piste est armée (rond rouge) : la prochaine prise au micro ira dessus."_u8);
    w->addButton ("Créer"_u8, 1, juce::KeyPress (juce::KeyPress::returnKey));
    w->addButton ("Annuler", 0, juce::KeyPress (juce::KeyPress::escapeKey));
    auto* box = w->getComboBoxComponent ("type");
    auto* nameEd = w->getTextEditor ("name");
    juce::WeakReference<Session> weak (&session);
    if (box != nullptr)
    {
        box->setSelectedItemIndex (initial, juce::dontSendNotification);
        // Nom proposé selon le type ("Back 2", "Harmonie 1"…), tant que l'utilisateur ne l'a pas tapé lui-même.
        box->onChange = [weak, box, nameEd, &roles]
        {
            const int i = box->getSelectedItemIndex();
            if (auto* s = weak.get(); s != nullptr && nameEd != nullptr && i >= 0 && i < static_cast<int> (roles.size()))
                nameEd->setText (s->nextTrackName (roles[static_cast<size_t> (i)]), false);
        };
    }
    w->enterModalState (true, juce::ModalCallbackFunction::create ([weak, w, &roles] (int r)
    {
        const auto* b = w->getComboBoxComponent ("type");
        const int i = b != nullptr ? b->getSelectedItemIndex() : -1;
        const auto name = w->getTextEditorContents ("name").trim();
        delete w;
        auto* s = weak.get();
        if (s == nullptr || r != 1 || i < 0 || i >= static_cast<int> (roles.size()))
            return;
        const auto role = roles[static_cast<size_t> (i)];
        s->addUserTrack (role, name.isNotEmpty() ? name : s->nextTrackName (role));
    }), false);
}
bool isImportableAudioFile (const juce::String& path)
{
    const auto ext = juce::File (path).getFileExtension().toLowerCase();
    return ext == ".wav" || ext == ".mp3" || ext == ".flac" || ext == ".aif" || ext == ".aiff" || ext == ".ogg";
}

void showImportDialog (Session& session, const juce::StringArray& files, double startSec)
{
    juce::StringArray audioFiles;
    for (const auto& f : files)
        if (isImportableAudioFile (f) && juce::File (f).existsAsFile())
            audioFiles.add (f);
    if (audioFiles.isEmpty())
    {
        session.setStatus ("Glisser-déposer : formats acceptés WAV, MP3, FLAC, AIFF, OGG"_u8);
        return;
    }
    if (session.isRecording())
    {
        session.setStatus ("Glisser-déposer : arrête d'abord l'enregistrement"_u8);
        return;
    }
    const auto& p = session.project();
    const auto* lead = p.findTrack (p.leadTrackId());
    // Contenu du premier fichier reconnu (voix seule ou musique) avant de proposer le type : ~0,3 s par minute d'audio.
    int voiceContent = -1;
    juce::String detected;
    {
        const auto loaded = audio::loadStereo (juce::File (audioFiles[0]), p.sampleRate, 60.0);
        if (loaded.ok())
        {
            const auto g = analysis::classifyContent (loaded.buffer, p.sampleRate);
            if (g.confidence > 0.0f)
            {
                voiceContent = g.voice ? 1 : 0;
                detected = g.reason;
            }
        }
        else
            SV_LOG_WARN ("Import", "Contenu non reconnu (" + loaded.error + ") : type proposé d'après le nom"_u8);
    }
    const auto guess = style::guessRoleForImport (audioFiles[0], voiceContent, p.instruTrack() != nullptr, lead != nullptr && ! lead->takes.empty());

    // Types proposés : l'instru (beat) puis les types de « Nouvelle piste ».
    std::vector<style::Role> roles { style::Role::Instru };
    for (const auto r : style::userTrackRoles())
        roles.push_back (r);
    juce::StringArray labels;
    int initial = 0;
    for (size_t i = 0; i < roles.size(); ++i)
    {
        labels.add (roles[i] == style::Role::Instru ? juce::String ("Instru / beat (remplace l'instru du projet, analyse tempo et tonalité)"_u8)
                                                    : style::userTrackLabel (roles[i]));
        if (roles[i] == guess)
            initial = static_cast<int> (i);
    }
    const bool single = audioFiles.size() == 1;
    const auto title = single ? "Importer « "_u8 + juce::File (audioFiles[0]).getFileName() + " »"_u8
                              : "Importer "_u8 + juce::String (audioFiles.size()) + " fichiers";
    auto* w = new juce::AlertWindow (title,
                                     (detected.isNotEmpty() ? "Reconnu : "_u8 + detected + "\n" : juce::String())
                                         + "Une nouvelle piste par fichier, placée à "_u8 + juce::String (startSec, 1)
                                         + " s, brute (aucun effet). Pour la traiter : clique sur la piste puis choisis un style dans « Effets »."_u8,
                                     juce::MessageBoxIconType::QuestionIcon);
    w->addComboBox ("type", labels, "Type");
    if (single)
        w->addTextEditor ("name", juce::File (audioFiles[0]).getFileNameWithoutExtension().substring (0, 40), "Nom");
    w->addButton ("Importer", 1, juce::KeyPress (juce::KeyPress::returnKey));
    w->addButton ("Annuler", 0, juce::KeyPress (juce::KeyPress::escapeKey));
    if (auto* box = w->getComboBoxComponent ("type"))
        box->setSelectedItemIndex (initial, juce::dontSendNotification);
    juce::WeakReference<Session> weak (&session);
    w->enterModalState (true, juce::ModalCallbackFunction::create ([weak, w, roles, audioFiles, single, startSec] (int r)
    {
        const auto* b = w->getComboBoxComponent ("type");
        const int i = b != nullptr ? b->getSelectedItemIndex() : -1;
        const auto typedName = single ? w->getTextEditorContents ("name").trim() : juce::String();
        delete w;
        auto* s = weak.get();
        if (s == nullptr || r != 1 || i < 0 || i >= static_cast<int> (roles.size()))
            return;
        const auto role = roles[static_cast<size_t> (i)];
        int created = 0;
        for (int k = 0; k < audioFiles.size(); ++k)
        {
            const juce::File f (audioFiles[k]);
            // Une seule instru par projet : les fichiers suivants deviennent des pistes instrument.
            const auto fileRole = role == style::Role::Instru && k > 0 ? style::Role::Instrument : role;
            const auto name = typedName.isNotEmpty() ? typedName : f.getFileNameWithoutExtension().substring (0, 40);
            if (s->importAsNewTrack (f, fileRole, name.isNotEmpty() ? name : s->nextTrackName (fileRole), startSec) >= 0)
                ++created;
        }
        if (audioFiles.size() > 1)
            s->setStatus (juce::String (created) + " piste(s) créée(s) sur "_u8 + juce::String (audioFiles.size()) + " fichier(s) déposé(s)"_u8);
    }), false);
}
} // namespace sv::app
