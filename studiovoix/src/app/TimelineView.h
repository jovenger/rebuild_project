#pragma once

#include <juce_gui_basics/juce_gui_basics.h>

#include "Session.h"
#include "TransportBar.h"

// Timeline : règle (mesures, sections, marqueurs, zones punch / boucle), pistes avec forme d'onde,
// tête de lecture. Molette = défilement vertical, Maj+molette = horizontal, Ctrl+molette = zoom.
namespace sv::app
{
/** Bouton REC d'une piste (rond) : rouge plein = piste armée, le micro enregistre sur elle. */
class RecArmButton final : public juce::Button
{
public:
    RecArmButton() : juce::Button ("REC") {}
    void paintButton (juce::Graphics& g, bool highlighted, bool down) override;
};

class TrackHeader final : public juce::Component
{
public:
    TrackHeader (Session& session, int trackId);
    void refresh();
    void updateMeter();   // ~30 fois par seconde pendant la lecture
    void resized() override;
    void paint (juce::Graphics& g) override;
    void mouseDown (const juce::MouseEvent& e) override;
    int trackId() const { return id; }

private:
    Session& session;
    const int id;
    juce::Label name, info;
    RecArmButton arm;
    juce::TextButton mute { "M" }, solo { "S" }, raw { "Brut" }, remove { "X" };
    juce::Slider volume, pan;
    LevelMeter meter;
    float meterLevel = 0.0f;
    bool updating = false;
};

class TimelineView final : public juce::Component
{
public:
    explicit TimelineView (Session& session);

    void refresh();             // structure des pistes modifiée
    void updatePlayhead();      // ~30 fois par seconde
    void paint (juce::Graphics& g) override;
    void resized() override;
    void mouseDown (const juce::MouseEvent& e) override;
    void mouseDrag (const juce::MouseEvent& e) override;
    void mouseUp (const juce::MouseEvent& e) override;
    void mouseDoubleClick (const juce::MouseEvent& e) override;
    void mouseMove (const juce::MouseEvent& e) override;
    void mouseWheelMove (const juce::MouseEvent& e, const juce::MouseWheelDetails& w) override;

    /** Position (s) sous un point de la zone des pistes ; false hors de cette zone (en-têtes, règle). */
    bool timeAtPoint (juce::Point<int> p, double& sec) const
    {
        if (p.x < headerWidth || p.y < kRulerHeight || p.x >= getWidth() || p.y >= getHeight())
            return false;
        sec = std::max (0.0, xToSec (p.x));
        return true;
    }

    /** Menu clic droit d'une piste (aussi depuis son en-tête). */
    void openTrackMenu (int trackId) { showTrackMenu (trackId, -1, -1.0); }

    double punchInSec() const { return punchIn; }
    double punchOutSec() const { return punchOut; }
    double loopStartSec() const { return loopA; }
    double loopEndSec() const { return loopB; }
    std::function<void()> onRegionsChanged;

    static constexpr int kDefaultHeaderWidth = 260;
    static constexpr int kRulerHeight = 48;
    static constexpr int kDefaultTrackHeight = 78;
    /** Largeur de la colonne des en-têtes et hauteur des pistes : réglables en tirant leur bord à la souris, mémorisées. */
    int headerWidth = kDefaultHeaderWidth;
    int trackHeight = kDefaultTrackHeight;

private:
    struct WaveCache
    {
        const void* key = nullptr;
        bool raw = false;
        std::vector<float> peaks;   // max abs par case de 10 ms
        long start = 0;
    };

    double xToSec (int x) const;
    int secToX (double s) const;
    int trackIndexAt (int y) const;
    const WaveCache* waveFor (const project::Track& t);
    /** takeId >= 0 : le clic était sur ce bloc à atSec, le menu propose aussi couper / fondus / supprimer le bloc. */
    void showTrackMenu (int trackId, int takeId, double atSec);
    void showSectionMenu (int sectionIndex);
    void clampView();

    Session& session;
    std::vector<std::unique_ptr<TrackHeader>> headers;
    std::map<int, WaveCache> waves;
    double pxPerSec = 40.0;
    double viewStart = 0.0;
    int scrollY = 0;
    double punchIn = 0.0, punchOut = 0.0, loopA = 0.0, loopB = 0.0;
    enum class Drag { None, Playhead, Punch, Loop, Clip, HeaderEdge, RowEdge, ClipEdgeL, ClipEdgeR, FadeIn, FadeOut } drag = Drag::None;
    // Édition d'un bloc en cours (bords, fondus) : valeurs provisoires affichées, le projet est modifié au relâchement.
    long editStart = 0, editEnd = 0, editFadeIn = 0, editFadeOut = 0, editFileLen = 0;
    static constexpr int kHandle = 7;   // taille (px) des poignées de fondu, en haut du bloc
    /** Poignée sous le point : 0 aucune, 1 bord gauche, 2 bord droit, 3 fondu d'entrée, 4 fondu de sortie. */
    int clipHandleAt (const project::Track& t, juce::Point<int> p, int rowY, int& takeId) const;
    int rowEdgeTop = 0;                  // haut (pixels) de la piste dont on tire le bord bas
    bool overHeaderEdge (juce::Point<int> p) const { return p.y >= kRulerHeight && std::abs (p.x - headerWidth) <= 5; }
    bool overRowEdge (juce::Point<int> p, int& rowTop) const;
    double dragAnchor = 0.0;
    int clipTrack = -1, clipTake = -1;   // bloc audio en cours de déplacement
    double clipOffsetSec = 0.0;          // décalage provisoire (affiché pendant le glisser)
    double clipStartSec (const project::Track& t, int takeId) const;
    /** Prise (ou fichier source : -1) sous le point (x, piste) ; false si rien. */
    bool clipAt (const project::Track& t, double sec, int& takeId) const;
    int lastPlayheadX = -1;
};
} // namespace sv::app
