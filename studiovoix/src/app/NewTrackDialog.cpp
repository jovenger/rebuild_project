#include "NewTrackDialog.h"

#include "core/Log.h"

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
} // namespace sv::app
