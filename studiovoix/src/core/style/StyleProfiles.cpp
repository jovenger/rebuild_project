#include "StyleProfiles.h"

namespace sv::style
{
namespace
{
    struct StyleInfo
    {
        const char* id;
        const char* name;
    };

    constexpr StyleInfo kStyles[] = {
        { "rap", "Rap / Hip-hop" },
        { "trap", "Trap" },
        { "pop_urbaine", "Pop urbaine" },
        { "rnb", "R&B" },
        { "drill", "Drill" },
        { "afro", "Afro" },
        { "rock", "Rock" },
        { "latino", "Latino / Reggaeton" },
        { "rap_melodique", "Rap mélodique" },
        { "boom_bap", "Boom bap / Old school" },
        { "pop", "Pop" },
        { "variete", "Variété / Chanson" },
        { "dancehall", "Dancehall / Shatta" },
        { "zouk", "Zouk / Kompa" },
        { "amapiano", "Amapiano" },
        { "gospel", "Gospel / Soul" },
        { "electro", "Électro / House" },
        { "acoustique", "Acoustique / Folk" },
        { "rap_conscient", "Rap conscient" },
        { "rap_hardcore", "Rap hardcore" },
        { "cloud_rap", "Cloud rap" },
        { "rage", "Rage" },
        { "plugg", "Plugg / Pluggnb" },
        { "emo_rap", "Emo rap" },
        { "afro_trap", "Afro trap" },
        { "lofi", "Rap lo-fi / Chill" },
        { "phonk", "Phonk" },
        { "jersey_club", "Jersey club" },
        { "rai", "Raï / Raï'n'B" },
        { "bouyon", "Bouyon" },
        { "funk_bresilien", "Funk brésilien" },
        { "afro_house", "Afro house" },
        { "country", "Country" },
    };
    static_assert (std::size (kStyles) == static_cast<size_t> (Style::Count), "un nom par style");
    constexpr int kLastStyle = static_cast<int> (Style::Count) - 1;

    constexpr StyleInfo kRoles[] = {
        { "instru", "Instru" },
        { "lead", "Voix principale" },
        { "double", "Doublage" },
        { "harmony", "Harmonie" },
        { "keyword_back", "Backs mots clés" },
        { "adlib", "Ad-libs" },
        { "ambiance", "Ambiance" },
        { "manual_back", "Back enregistré" },
        { "instrument", "Instrument" },
    };
    static_assert (std::size (kRoles) == static_cast<size_t> (Role::Count), "un nom par rôle");
    constexpr int kLastRole = static_cast<int> (Role::Count) - 1;

    float lerp (float a, float b, float t) { return a + (b - a) * t; }

    VocalParams leadBase (Style s)
    {
        VocalParams p;
        p.clean.enabled = true;
        p.clean.dePlosive = true;
        p.clean.gateRangeDb = 12.0f;
        p.clean.breathReductionDb = 8.0f;
        p.comp2.ratio = 1.0f;   // désactivé par défaut
        p.reverb.hpfHz = 250.0f;    // retour de réverb filtré : ne concurrence pas la voix (pratique studio : 200 Hz - 8-10 kHz)
        p.reverb.lpfHz = 8500.0f;
        p.delay.hpfHz = 350.0f;
        p.delay.lpfHz = 6000.0f;

        switch (s)
        {
            case Style::Rap:
                p.pitch = { true, 0.15f, 80.0f, 0.8f };
                p.clean.hpfHz = 90.0f;
                p.eq = { 90.0f, 200.0f, 0.0f, 300.0f, -2.0f, 1.0f, 4000.0f, 3.0f, 0.9f, 12000.0f, 2.0f, 0.0f };
                p.comp = { -20.0f, 4.0f, 6.0f, 5.0f, 80.0f, 0.0f, 1.0f, false };
                p.comp2 = { -26.0f, 2.0f, 8.0f, 20.0f, 200.0f, 0.0f, 1.0f, true };
                p.deEss = { 7000.0f, 0.6f, 6.0f, -8.0f };
                p.sat = { 3.0f, 0.3f, 0.1f };
                p.reverb.send = 0.08f; p.reverb.roomSize = 0.35f; p.reverb.damping = 0.6f; p.reverb.preDelayMs = 20.0f;
                p.delay.send = 0.10f; p.delay.noteBeats = 0.5f; p.delay.feedback = 0.2f; p.delay.throwsOnly = true;
                p.outputDb = -14.0f;
                break;
            case Style::Trap:
                p.pitch = { true, 1.0f, 5.0f, 0.0f };
                p.clean.hpfHz = 100.0f;
                p.eq = { 100.0f, 200.0f, 0.0f, 300.0f, -3.0f, 1.0f, 3500.0f, 3.0f, 0.9f, 12000.0f, 4.0f, 0.0f };
                p.comp = { -22.0f, 6.0f, 6.0f, 3.0f, 60.0f, 0.0f, 1.0f, false };
                p.comp2 = { -28.0f, 2.0f, 8.0f, 20.0f, 150.0f, 0.0f, 1.0f, true };
                p.deEss = { 7000.0f, 0.7f, 6.0f, -8.0f };
                p.sat = { 6.0f, 0.4f, 0.15f };
                p.reverb.send = 0.15f; p.reverb.roomSize = 0.5f; p.reverb.damping = 0.5f; p.reverb.preDelayMs = 25.0f;
                p.delay.send = 0.20f; p.delay.noteBeats = 1.0f; p.delay.feedback = 0.3f; p.delay.pingPong = true; p.delay.throwsOnly = true;
                p.outputDb = -14.0f;
                break;
            case Style::PopUrbaine:
                p.pitch = { true, 0.7f, 20.0f, 0.4f };
                p.clean.hpfHz = 90.0f;
                p.eq = { 90.0f, 200.0f, 0.0f, 300.0f, -2.0f, 1.0f, 3000.0f, 2.5f, 0.8f, 12000.0f, 4.0f, 0.0f };
                p.comp = { -20.0f, 4.0f, 6.0f, 8.0f, 100.0f, 0.0f, 1.0f, false };
                p.comp2 = { -26.0f, 2.0f, 8.0f, 25.0f, 200.0f, 0.0f, 1.0f, true };
                p.deEss = { 7000.0f, 0.7f, 6.0f, -8.0f };
                p.sat = { 3.0f, 0.25f, 0.1f };
                p.reverb.send = 0.20f; p.reverb.roomSize = 0.55f; p.reverb.damping = 0.5f; p.reverb.preDelayMs = 30.0f;
                p.delay.send = 0.12f; p.delay.noteBeats = 1.0f; p.delay.feedback = 0.25f;
                p.outputDb = -14.0f;
                break;
            case Style::RnB:
                p.pitch = { true, 0.5f, 40.0f, 0.7f };
                p.clean.hpfHz = 80.0f;
                p.eq = { 80.0f, 200.0f, 1.5f, 350.0f, -1.5f, 1.0f, 3000.0f, 1.5f, 0.8f, 11000.0f, 3.0f, 0.0f };
                p.comp = { -22.0f, 3.0f, 8.0f, 15.0f, 150.0f, 0.0f, 0.85f, true };
                p.comp2 = { -28.0f, 1.8f, 10.0f, 30.0f, 250.0f, 0.0f, 1.0f, true };
                p.deEss = { 7000.0f, 0.8f, 6.0f, -8.0f };
                p.sat = { 2.0f, 0.2f, 0.1f };
                p.reverb.send = 0.30f; p.reverb.roomSize = 0.75f; p.reverb.damping = 0.45f; p.reverb.preDelayMs = 40.0f;
                p.delay.send = 0.15f; p.delay.noteBeats = 0.75f; p.delay.feedback = 0.3f;
                p.outputDb = -14.0f;
                break;
            case Style::Drill:
                p.pitch = { true, 0.6f, 15.0f, 0.2f };
                p.clean.hpfHz = 110.0f;
                p.eq = { 110.0f, 200.0f, 0.0f, 300.0f, -3.0f, 1.0f, 2500.0f, 4.0f, 1.0f, 12000.0f, 2.0f, 0.0f };
                p.comp = { -20.0f, 6.0f, 4.0f, 2.0f, 50.0f, 0.0f, 1.0f, false };
                p.comp2 = { -26.0f, 2.0f, 8.0f, 15.0f, 150.0f, 0.0f, 1.0f, true };
                p.deEss = { 7000.0f, 0.6f, 6.0f, -8.0f };
                p.sat = { 7.0f, 0.45f, 0.2f };
                p.reverb.send = 0.08f; p.reverb.roomSize = 0.3f; p.reverb.damping = 0.6f; p.reverb.preDelayMs = 15.0f;
                p.delay.send = 0.10f; p.delay.noteBeats = 0.5f; p.delay.feedback = 0.25f; p.delay.throwsOnly = true;
                p.outputDb = -14.0f;
                break;
            case Style::Afro:
            case Style::Count:
                p.pitch = { true, 0.8f, 15.0f, 0.3f };
                p.clean.hpfHz = 90.0f;
                p.eq = { 90.0f, 200.0f, 0.0f, 300.0f, -2.0f, 1.0f, 3500.0f, 2.5f, 0.9f, 12000.0f, 4.0f, 0.0f };
                p.comp = { -20.0f, 4.0f, 6.0f, 8.0f, 100.0f, 0.0f, 1.0f, false };
                p.comp2 = { -26.0f, 2.0f, 8.0f, 25.0f, 200.0f, 0.0f, 1.0f, true };
                p.deEss = { 7000.0f, 0.7f, 6.0f, -8.0f };
                p.sat = { 3.0f, 0.25f, 0.1f };
                p.reverb.send = 0.25f; p.reverb.roomSize = 0.65f; p.reverb.damping = 0.5f; p.reverb.preDelayMs = 30.0f;
                p.delay.send = 0.20f; p.delay.noteBeats = 0.75f; p.delay.feedback = 0.35f; p.delay.pingPong = true;
                p.outputDb = -14.0f;
                break;
            case Style::Rock:
                // Voix naturelle et granuleuse : peu de justesse, compression franche, saturation, slapback court.
                p.pitch = { true, 0.1f, 100.0f, 0.9f };
                p.clean.hpfHz = 90.0f;
                p.eq = { 90.0f, 200.0f, 0.0f, 350.0f, -2.5f, 1.0f, 3000.0f, 3.0f, 0.8f, 10000.0f, 2.0f, 0.0f };
                p.comp = { -18.0f, 5.0f, 6.0f, 10.0f, 120.0f, 0.0f, 1.0f, false };
                p.comp2 = { -26.0f, 2.5f, 8.0f, 20.0f, 200.0f, 0.0f, 1.0f, true };
                p.deEss = { 7000.0f, 0.6f, 6.0f, -8.0f };
                p.sat = { 8.0f, 0.35f, 0.2f };
                p.reverb.send = 0.15f; p.reverb.roomSize = 0.5f; p.reverb.damping = 0.55f; p.reverb.preDelayMs = 30.0f;
                p.delay.send = 0.12f; p.delay.noteBeats = 0.25f; p.delay.feedback = 0.1f;
                p.outputDb = -14.0f;
                break;
            case Style::Latino:
                // Reggaeton / latino urbain : autotune marqué, voix brillante, délai croche pointée sur les fins.
                p.pitch = { true, 0.85f, 10.0f, 0.2f };
                p.clean.hpfHz = 100.0f;
                p.eq = { 100.0f, 200.0f, 0.0f, 300.0f, -2.5f, 1.0f, 3500.0f, 3.0f, 0.9f, 12000.0f, 4.0f, 0.0f };
                p.comp = { -22.0f, 5.0f, 6.0f, 4.0f, 70.0f, 0.0f, 1.0f, false };
                p.comp2 = { -28.0f, 2.0f, 8.0f, 20.0f, 150.0f, 0.0f, 1.0f, true };
                p.deEss = { 7000.0f, 0.7f, 6.0f, -8.0f };
                p.sat = { 4.0f, 0.25f, 0.1f };
                p.reverb.send = 0.18f; p.reverb.roomSize = 0.55f; p.reverb.damping = 0.5f; p.reverb.preDelayMs = 25.0f;
                p.delay.send = 0.18f; p.delay.noteBeats = 0.75f; p.delay.feedback = 0.3f; p.delay.pingPong = true; p.delay.throwsOnly = true;
                p.outputDb = -14.0f;
                break;
            case Style::RapMelodique:
                // Rap chanté (mélo) : autotune très présent mais pas robotique, voix devant, délai noire en fin de phrase.
                p.pitch = { true, 0.95f, 8.0f, 0.1f };
                p.clean.hpfHz = 100.0f;
                p.eq = { 100.0f, 200.0f, 0.0f, 300.0f, -2.5f, 1.0f, 3500.0f, 3.0f, 0.9f, 12000.0f, 4.0f, 0.0f };
                p.comp = { -22.0f, 5.0f, 6.0f, 4.0f, 70.0f, 0.0f, 1.0f, false };
                p.comp2 = { -28.0f, 2.0f, 8.0f, 20.0f, 150.0f, 0.0f, 1.0f, true };
                p.deEss = { 7000.0f, 0.7f, 6.0f, -8.0f };
                p.sat = { 4.0f, 0.3f, 0.1f };
                p.reverb.send = 0.18f; p.reverb.roomSize = 0.55f; p.reverb.damping = 0.5f; p.reverb.preDelayMs = 25.0f;
                p.delay.send = 0.18f; p.delay.noteBeats = 1.0f; p.delay.feedback = 0.3f; p.delay.pingPong = true; p.delay.throwsOnly = true;
                p.outputDb = -14.0f;
                break;
            case Style::BoomBap:
                // Rap old school : voix naturelle sans autotune, corps dans le bas-médium, compression qui laisse passer
                // l'attaque, saturation chaude, pièce courte presque sèche.
                p.pitch = { false, 0.0f, 100.0f, 1.0f };
                p.clean.hpfHz = 80.0f;
                p.eq = { 80.0f, 200.0f, 1.0f, 350.0f, -2.0f, 1.0f, 3000.0f, 3.5f, 0.9f, 12000.0f, 1.0f, 0.0f };
                p.comp = { -18.0f, 4.0f, 6.0f, 10.0f, 100.0f, 0.0f, 1.0f, false };
                p.comp2 = { -24.0f, 2.0f, 8.0f, 20.0f, 200.0f, 0.0f, 1.0f, true };
                p.deEss = { 7000.0f, 0.6f, 6.0f, -8.0f };
                p.sat = { 4.0f, 0.35f, 0.25f };
                p.reverb.send = 0.06f; p.reverb.roomSize = 0.3f; p.reverb.damping = 0.65f; p.reverb.preDelayMs = 15.0f;
                p.delay.send = 0.08f; p.delay.noteBeats = 0.5f; p.delay.feedback = 0.15f; p.delay.throwsOnly = true;
                p.outputDb = -14.0f;
                break;
            case Style::Pop:
                // Pop actuelle : justesse transparente, beaucoup d'air, de-esser plus haut, réverb et délai noire.
                p.pitch = { true, 0.6f, 25.0f, 0.5f };
                p.clean.hpfHz = 90.0f;
                p.eq = { 90.0f, 200.0f, 0.0f, 300.0f, -2.0f, 1.0f, 3500.0f, 2.5f, 0.8f, 12000.0f, 4.5f, 0.0f };
                p.comp = { -20.0f, 4.0f, 6.0f, 6.0f, 90.0f, 0.0f, 1.0f, false };
                p.comp2 = { -26.0f, 2.0f, 8.0f, 25.0f, 200.0f, 0.0f, 1.0f, true };
                p.deEss = { 7000.0f, 0.75f, 6.0f, -8.0f };
                p.sat = { 2.5f, 0.2f, 0.1f };
                p.reverb.send = 0.22f; p.reverb.roomSize = 0.6f; p.reverb.damping = 0.5f; p.reverb.preDelayMs = 35.0f;
                p.delay.send = 0.15f; p.delay.noteBeats = 1.0f; p.delay.feedback = 0.25f;
                p.outputDb = -14.0f;
                break;
            case Style::Variete:
                // Variété / chanson : texte intelligible, voix naturelle et chaude, compression douce, réverb de salle.
                p.pitch = { true, 0.3f, 50.0f, 0.8f };
                p.clean.hpfHz = 80.0f;
                p.eq = { 80.0f, 200.0f, 1.0f, 300.0f, -1.5f, 1.0f, 3000.0f, 2.0f, 0.8f, 12000.0f, 2.5f, 0.0f };
                p.comp = { -20.0f, 3.0f, 8.0f, 12.0f, 140.0f, 0.0f, 1.0f, true };
                p.comp2 = { -26.0f, 1.8f, 10.0f, 30.0f, 250.0f, 0.0f, 1.0f, true };
                p.deEss = { 7000.0f, 0.6f, 6.0f, -8.0f };
                p.sat = { 1.5f, 0.15f, 0.1f };
                p.reverb.send = 0.25f; p.reverb.roomSize = 0.65f; p.reverb.damping = 0.5f; p.reverb.preDelayMs = 35.0f;
                p.delay.send = 0.08f; p.delay.noteBeats = 1.0f; p.delay.feedback = 0.2f;
                p.outputDb = -14.0f;
                break;
            case Style::Dancehall:
                // Dancehall / shatta : autotune marqué, voix très en avant et saturée, échos croche façon dub.
                p.pitch = { true, 0.9f, 8.0f, 0.2f };
                p.clean.hpfHz = 110.0f;
                p.eq = { 110.0f, 200.0f, 0.0f, 300.0f, -3.0f, 1.0f, 3000.0f, 4.0f, 1.0f, 12000.0f, 3.0f, 0.0f };
                p.comp = { -22.0f, 6.0f, 4.0f, 3.0f, 60.0f, 0.0f, 1.0f, false };
                p.comp2 = { -28.0f, 2.0f, 8.0f, 15.0f, 150.0f, 0.0f, 1.0f, true };
                p.deEss = { 7000.0f, 0.65f, 6.0f, -8.0f };
                p.sat = { 6.0f, 0.4f, 0.15f };
                p.reverb.send = 0.12f; p.reverb.roomSize = 0.45f; p.reverb.damping = 0.55f; p.reverb.preDelayMs = 20.0f;
                p.delay.send = 0.22f; p.delay.noteBeats = 0.5f; p.delay.feedback = 0.35f; p.delay.pingPong = true; p.delay.throwsOnly = true;
                p.outputDb = -14.0f;
                break;
            case Style::Zouk:
                // Zouk / kompa : voix douce et brillante, autotune lissé, réverb ample, délai croche pointée.
                p.pitch = { true, 0.75f, 20.0f, 0.4f };
                p.clean.hpfHz = 90.0f;
                p.eq = { 90.0f, 200.0f, 1.0f, 300.0f, -1.5f, 1.0f, 3000.0f, 2.0f, 0.8f, 12000.0f, 3.5f, 0.0f };
                p.comp = { -22.0f, 3.5f, 8.0f, 10.0f, 120.0f, 0.0f, 1.0f, false };
                p.comp2 = { -28.0f, 2.0f, 8.0f, 25.0f, 200.0f, 0.0f, 1.0f, true };
                p.deEss = { 7000.0f, 0.75f, 6.0f, -8.0f };
                p.sat = { 2.0f, 0.2f, 0.1f };
                p.reverb.send = 0.28f; p.reverb.roomSize = 0.7f; p.reverb.damping = 0.45f; p.reverb.preDelayMs = 35.0f;
                p.delay.send = 0.15f; p.delay.noteBeats = 0.75f; p.delay.feedback = 0.3f;
                p.outputDb = -14.0f;
                break;
            case Style::Amapiano:
                // Amapiano : voix posée dans l'espace (log drums très présents), réverb longue, délai croche pointée ping-pong.
                p.pitch = { true, 0.6f, 20.0f, 0.4f };
                p.clean.hpfHz = 100.0f;
                p.eq = { 100.0f, 200.0f, 0.0f, 300.0f, -2.0f, 1.0f, 3500.0f, 2.5f, 0.9f, 12000.0f, 3.5f, 0.0f };
                p.comp = { -20.0f, 4.0f, 6.0f, 8.0f, 110.0f, 0.0f, 1.0f, false };
                p.comp2 = { -26.0f, 2.0f, 8.0f, 25.0f, 200.0f, 0.0f, 1.0f, true };
                p.deEss = { 7000.0f, 0.7f, 6.0f, -8.0f };
                p.sat = { 2.5f, 0.2f, 0.1f };
                p.reverb.send = 0.30f; p.reverb.roomSize = 0.75f; p.reverb.damping = 0.5f; p.reverb.preDelayMs = 40.0f;
                p.delay.send = 0.22f; p.delay.noteBeats = 0.75f; p.delay.feedback = 0.4f; p.delay.pingPong = true;
                p.outputDb = -14.0f;
                break;
            case Style::Gospel:
                // Gospel / soul : grosse dynamique gardée (compression parallèle), justesse discrète, réverb de grande salle.
                p.pitch = { true, 0.2f, 60.0f, 0.9f };
                p.clean.hpfHz = 80.0f;
                p.eq = { 80.0f, 200.0f, 1.5f, 350.0f, -1.5f, 1.0f, 3000.0f, 2.0f, 0.8f, 12000.0f, 3.0f, 0.0f };
                p.comp = { -22.0f, 3.0f, 8.0f, 15.0f, 160.0f, 0.0f, 0.85f, true };
                p.comp2 = { -28.0f, 2.0f, 10.0f, 30.0f, 250.0f, 0.0f, 1.0f, true };
                p.deEss = { 7000.0f, 0.7f, 6.0f, -8.0f };
                p.sat = { 2.0f, 0.2f, 0.1f };
                p.reverb.send = 0.32f; p.reverb.roomSize = 0.8f; p.reverb.damping = 0.45f; p.reverb.preDelayMs = 45.0f;
                p.delay.send = 0.08f; p.delay.noteBeats = 0.75f; p.delay.feedback = 0.2f;
                p.outputDb = -14.0f;
                break;
            case Style::Electro:
                // Électro / house : voix fine (coupe-bas haut) et très brillante pour passer au-dessus du kick,
                // compression rapide, grands espaces.
                p.pitch = { true, 0.8f, 12.0f, 0.2f };
                p.clean.hpfHz = 120.0f;
                p.eq = { 120.0f, 200.0f, 0.0f, 300.0f, -3.0f, 1.0f, 3500.0f, 3.0f, 0.9f, 12000.0f, 5.0f, 0.0f };
                p.comp = { -22.0f, 5.0f, 6.0f, 3.0f, 60.0f, 0.0f, 1.0f, false };
                p.comp2 = { -28.0f, 2.0f, 8.0f, 20.0f, 150.0f, 0.0f, 1.0f, true };
                p.deEss = { 7000.0f, 0.75f, 6.0f, -8.0f };
                p.sat = { 3.0f, 0.25f, 0.1f };
                p.reverb.send = 0.25f; p.reverb.roomSize = 0.7f; p.reverb.damping = 0.5f; p.reverb.preDelayMs = 40.0f;
                p.delay.send = 0.22f; p.delay.noteBeats = 0.75f; p.delay.feedback = 0.4f; p.delay.pingPong = true;
                p.outputDb = -14.0f;
                break;
            case Style::Acoustique:
                // Acoustique / folk : le plus naturel possible, compression légère, pièce moyenne, slapback discret.
                p.pitch = { true, 0.15f, 80.0f, 0.9f };
                p.clean.hpfHz = 75.0f;
                p.eq = { 75.0f, 200.0f, 1.0f, 300.0f, -2.0f, 1.0f, 3000.0f, 1.5f, 0.8f, 12000.0f, 3.0f, 0.0f };
                p.comp = { -20.0f, 2.5f, 10.0f, 15.0f, 150.0f, 0.0f, 1.0f, true };
                p.comp2 = { -26.0f, 1.6f, 10.0f, 30.0f, 250.0f, 0.0f, 1.0f, true };
                p.deEss = { 7000.0f, 0.6f, 6.0f, -8.0f };
                p.sat = { 1.0f, 0.1f, 0.1f };
                p.reverb.send = 0.20f; p.reverb.roomSize = 0.55f; p.reverb.damping = 0.5f; p.reverb.preDelayMs = 30.0f;
                p.delay.send = 0.06f; p.delay.noteBeats = 0.25f; p.delay.feedback = 0.1f;
                p.outputDb = -14.0f;
                break;
            case Style::RapConscient:
                // Texte avant tout : voix naturelle et intelligible, présence marquée, presque sèche.
                p.pitch = { true, 0.1f, 90.0f, 0.9f };
                p.clean.hpfHz = 85.0f;
                p.eq = { 85.0f, 200.0f, 0.5f, 300.0f, -2.0f, 1.0f, 3000.0f, 3.5f, 0.9f, 12000.0f, 1.5f, 0.0f };
                p.comp = { -20.0f, 4.0f, 6.0f, 8.0f, 100.0f, 0.0f, 1.0f, false };
                p.comp2 = { -26.0f, 2.0f, 8.0f, 20.0f, 200.0f, 0.0f, 1.0f, true };
                p.deEss = { 7000.0f, 0.6f, 6.0f, -8.0f };
                p.sat = { 2.0f, 0.2f, 0.1f };
                p.reverb.send = 0.07f; p.reverb.roomSize = 0.35f; p.reverb.damping = 0.6f; p.reverb.preDelayMs = 20.0f;
                p.delay.send = 0.06f; p.delay.noteBeats = 0.5f; p.delay.feedback = 0.15f; p.delay.throwsOnly = true;
                p.outputDb = -14.0f;
                break;
            case Style::RapHardcore:
                // Voix agressive et collée devant : compression très forte et rapide, saturation poussée, sèche.
                p.pitch = { true, 0.1f, 80.0f, 0.8f };
                p.clean.hpfHz = 110.0f;
                p.eq = { 110.0f, 200.0f, 0.0f, 300.0f, -3.5f, 1.0f, 2500.0f, 4.5f, 1.0f, 12000.0f, 2.0f, 0.0f };
                p.comp = { -16.0f, 8.0f, 4.0f, 1.0f, 40.0f, 0.0f, 1.0f, false };
                p.comp2 = { -24.0f, 3.0f, 8.0f, 10.0f, 120.0f, 0.0f, 1.0f, true };
                p.deEss = { 7000.0f, 0.6f, 6.0f, -8.0f };
                p.sat = { 9.0f, 0.5f, 0.25f };
                p.reverb.send = 0.05f; p.reverb.roomSize = 0.25f; p.reverb.damping = 0.65f; p.reverb.preDelayMs = 10.0f;
                p.delay.send = 0.08f; p.delay.noteBeats = 0.5f; p.delay.feedback = 0.15f; p.delay.throwsOnly = true;
                p.outputDb = -14.0f;
                break;
            case Style::CloudRap:
                // Voix aérienne noyée dans l'espace : beaucoup d'air, réverb longue, délai croche pointée.
                p.pitch = { true, 0.85f, 15.0f, 0.3f };
                p.clean.hpfHz = 110.0f;
                p.eq = { 110.0f, 200.0f, 0.0f, 300.0f, -2.5f, 1.0f, 3500.0f, 2.0f, 0.8f, 12000.0f, 5.0f, 0.0f };
                p.comp = { -22.0f, 4.0f, 6.0f, 6.0f, 100.0f, 0.0f, 1.0f, false };
                p.comp2 = { -28.0f, 2.0f, 8.0f, 25.0f, 200.0f, 0.0f, 1.0f, true };
                p.deEss = { 7000.0f, 0.75f, 6.0f, -8.0f };
                p.sat = { 2.0f, 0.2f, 0.1f };
                p.reverb.send = 0.38f; p.reverb.roomSize = 0.85f; p.reverb.damping = 0.45f; p.reverb.preDelayMs = 50.0f;
                p.delay.send = 0.25f; p.delay.noteBeats = 0.75f; p.delay.feedback = 0.45f; p.delay.pingPong = true;
                p.outputDb = -14.0f;
                break;
            case Style::Rage:
                // Autotune à fond, voix distordue et très compressée pour tenir face aux synthés saturés.
                p.pitch = { true, 1.0f, 3.0f, 0.0f };
                p.clean.hpfHz = 120.0f;
                p.eq = { 120.0f, 200.0f, 0.0f, 300.0f, -3.0f, 1.0f, 3000.0f, 3.0f, 0.9f, 12000.0f, 4.0f, 0.0f };
                p.comp = { -24.0f, 8.0f, 4.0f, 1.0f, 40.0f, 0.0f, 1.0f, false };
                p.comp2 = { -28.0f, 2.0f, 8.0f, 15.0f, 150.0f, 0.0f, 1.0f, true };
                p.deEss = { 7000.0f, 0.7f, 6.0f, -8.0f };
                p.sat = { 10.0f, 0.55f, 0.2f };
                p.reverb.send = 0.12f; p.reverb.roomSize = 0.5f; p.reverb.damping = 0.5f; p.reverb.preDelayMs = 20.0f;
                p.delay.send = 0.18f; p.delay.noteBeats = 0.5f; p.delay.feedback = 0.3f; p.delay.pingPong = true; p.delay.throwsOnly = true;
                p.outputDb = -14.0f;
                break;
            case Style::Plugg:
                // Voix douce et chantée, autotune serré mais lisse, réverb moyenne, délai noire ping-pong.
                p.pitch = { true, 0.9f, 10.0f, 0.2f };
                p.clean.hpfHz = 100.0f;
                p.eq = { 100.0f, 200.0f, 0.0f, 300.0f, -2.0f, 1.0f, 3500.0f, 2.5f, 0.9f, 12000.0f, 4.0f, 0.0f };
                p.comp = { -22.0f, 4.0f, 6.0f, 5.0f, 80.0f, 0.0f, 1.0f, false };
                p.comp2 = { -28.0f, 2.0f, 8.0f, 20.0f, 150.0f, 0.0f, 1.0f, true };
                p.deEss = { 7000.0f, 0.7f, 6.0f, -8.0f };
                p.sat = { 2.5f, 0.2f, 0.1f };
                p.reverb.send = 0.25f; p.reverb.roomSize = 0.65f; p.reverb.damping = 0.5f; p.reverb.preDelayMs = 30.0f;
                p.delay.send = 0.18f; p.delay.noteBeats = 1.0f; p.delay.feedback = 0.3f; p.delay.pingPong = true;
                p.outputDb = -14.0f;
                break;
            case Style::EmoRap:
                // Rap chanté mélancolique : autotune présent, voix un peu granuleuse, réverb et délai en fin de phrase.
                p.pitch = { true, 0.85f, 12.0f, 0.3f };
                p.clean.hpfHz = 100.0f;
                p.eq = { 100.0f, 200.0f, 0.0f, 300.0f, -2.5f, 1.0f, 3500.0f, 3.0f, 0.9f, 12000.0f, 3.0f, 0.0f };
                p.comp = { -22.0f, 5.0f, 6.0f, 5.0f, 80.0f, 0.0f, 1.0f, false };
                p.comp2 = { -28.0f, 2.0f, 8.0f, 20.0f, 150.0f, 0.0f, 1.0f, true };
                p.deEss = { 7000.0f, 0.7f, 6.0f, -8.0f };
                p.sat = { 4.0f, 0.3f, 0.15f };
                p.reverb.send = 0.28f; p.reverb.roomSize = 0.7f; p.reverb.damping = 0.5f; p.reverb.preDelayMs = 35.0f;
                p.delay.send = 0.2f; p.delay.noteBeats = 1.0f; p.delay.feedback = 0.35f; p.delay.throwsOnly = true;
                p.outputDb = -14.0f;
                break;
            case Style::AfroTrap:
                // Énergie trap sur groove afro : autotune marqué, voix devant, échos croche.
                p.pitch = { true, 0.85f, 12.0f, 0.3f };
                p.clean.hpfHz = 100.0f;
                p.eq = { 100.0f, 200.0f, 0.0f, 300.0f, -2.5f, 1.0f, 3500.0f, 3.0f, 0.9f, 12000.0f, 3.5f, 0.0f };
                p.comp = { -21.0f, 5.0f, 6.0f, 4.0f, 70.0f, 0.0f, 1.0f, false };
                p.comp2 = { -27.0f, 2.0f, 8.0f, 20.0f, 150.0f, 0.0f, 1.0f, true };
                p.deEss = { 7000.0f, 0.7f, 6.0f, -8.0f };
                p.sat = { 4.5f, 0.3f, 0.15f };
                p.reverb.send = 0.16f; p.reverb.roomSize = 0.5f; p.reverb.damping = 0.5f; p.reverb.preDelayMs = 25.0f;
                p.delay.send = 0.16f; p.delay.noteBeats = 0.5f; p.delay.feedback = 0.3f; p.delay.pingPong = true; p.delay.throwsOnly = true;
                p.outputDb = -14.0f;
                break;
            case Style::LoFi:
                // Voix chaude et feutrée : aigus adoucis (coupe-haut), saturation façon bande, compression douce.
                p.pitch = { true, 0.3f, 50.0f, 0.8f };
                p.clean.hpfHz = 100.0f;
                p.eq = { 100.0f, 200.0f, 1.0f, 300.0f, -1.5f, 1.0f, 3000.0f, 1.0f, 0.8f, 10000.0f, -1.0f, 11000.0f };
                p.comp = { -22.0f, 3.0f, 8.0f, 12.0f, 140.0f, 0.0f, 1.0f, true };
                p.comp2 = { -28.0f, 1.8f, 10.0f, 30.0f, 250.0f, 0.0f, 1.0f, true };
                p.deEss = { 7000.0f, 0.6f, 6.0f, -8.0f };
                p.sat = { 3.0f, 0.3f, 0.3f };
                p.reverb.send = 0.2f; p.reverb.roomSize = 0.55f; p.reverb.damping = 0.6f; p.reverb.preDelayMs = 25.0f;
                p.delay.send = 0.1f; p.delay.noteBeats = 1.0f; p.delay.feedback = 0.25f;
                p.outputDb = -14.0f;
                break;
            case Style::Phonk:
                // Voix sombre façon Memphis : bande étroite (coupe-bas et coupe-haut), très saturée, sans autotune.
                p.pitch = { false, 0.0f, 100.0f, 1.0f };
                p.clean.hpfHz = 150.0f;
                p.eq = { 150.0f, 200.0f, 0.0f, 300.0f, -3.0f, 1.0f, 2500.0f, 4.0f, 1.0f, 10000.0f, -2.0f, 9000.0f };
                p.comp = { -18.0f, 8.0f, 4.0f, 2.0f, 50.0f, 0.0f, 1.0f, false };
                p.comp2 = { -26.0f, 2.0f, 8.0f, 15.0f, 150.0f, 0.0f, 1.0f, true };
                p.deEss = { 7000.0f, 0.5f, 6.0f, -8.0f };
                p.sat = { 10.0f, 0.5f, 0.3f };
                p.reverb.send = 0.12f; p.reverb.roomSize = 0.45f; p.reverb.damping = 0.6f; p.reverb.preDelayMs = 15.0f;
                p.delay.send = 0.15f; p.delay.noteBeats = 0.5f; p.delay.feedback = 0.3f; p.delay.throwsOnly = true;
                p.outputDb = -14.0f;
                break;
            case Style::JerseyClub:
                // Voix brillante et rebondissante : autotune, beaucoup d'air, compression rapide, échos croche.
                p.pitch = { true, 0.8f, 10.0f, 0.2f };
                p.clean.hpfHz = 110.0f;
                p.eq = { 110.0f, 200.0f, 0.0f, 300.0f, -2.5f, 1.0f, 3500.0f, 3.0f, 0.9f, 12000.0f, 4.5f, 0.0f };
                p.comp = { -22.0f, 5.0f, 6.0f, 3.0f, 60.0f, 0.0f, 1.0f, false };
                p.comp2 = { -28.0f, 2.0f, 8.0f, 20.0f, 150.0f, 0.0f, 1.0f, true };
                p.deEss = { 7000.0f, 0.75f, 6.0f, -8.0f };
                p.sat = { 3.5f, 0.25f, 0.1f };
                p.reverb.send = 0.14f; p.reverb.roomSize = 0.5f; p.reverb.damping = 0.5f; p.reverb.preDelayMs = 20.0f;
                p.delay.send = 0.15f; p.delay.noteBeats = 0.5f; p.delay.feedback = 0.25f; p.delay.pingPong = true; p.delay.throwsOnly = true;
                p.outputDb = -14.0f;
                break;
            case Style::Rai:
                // Autotune très rapide qui suit les mélismes, voix brillante, grande réverb et délai croche pointée.
                p.pitch = { true, 0.95f, 5.0f, 0.1f };
                p.clean.hpfHz = 100.0f;
                p.eq = { 100.0f, 200.0f, 0.0f, 300.0f, -2.5f, 1.0f, 3000.0f, 3.0f, 0.9f, 12000.0f, 3.5f, 0.0f };
                p.comp = { -22.0f, 5.0f, 6.0f, 4.0f, 70.0f, 0.0f, 1.0f, false };
                p.comp2 = { -28.0f, 2.0f, 8.0f, 20.0f, 150.0f, 0.0f, 1.0f, true };
                p.deEss = { 7000.0f, 0.7f, 6.0f, -8.0f };
                p.sat = { 3.0f, 0.25f, 0.1f };
                p.reverb.send = 0.3f; p.reverb.roomSize = 0.7f; p.reverb.damping = 0.45f; p.reverb.preDelayMs = 30.0f;
                p.delay.send = 0.22f; p.delay.noteBeats = 0.75f; p.delay.feedback = 0.35f; p.delay.pingPong = true;
                p.outputDb = -14.0f;
                break;
            case Style::Bouyon:
                // Carnaval rapide : voix criée très en avant, compression forte, saturation, peu d'espace.
                p.pitch = { true, 0.8f, 10.0f, 0.3f };
                p.clean.hpfHz = 110.0f;
                p.eq = { 110.0f, 200.0f, 0.0f, 300.0f, -3.0f, 1.0f, 3000.0f, 4.0f, 1.0f, 12000.0f, 3.0f, 0.0f };
                p.comp = { -21.0f, 6.0f, 4.0f, 3.0f, 60.0f, 0.0f, 1.0f, false };
                p.comp2 = { -27.0f, 2.0f, 8.0f, 15.0f, 150.0f, 0.0f, 1.0f, true };
                p.deEss = { 7000.0f, 0.65f, 6.0f, -8.0f };
                p.sat = { 6.0f, 0.4f, 0.15f };
                p.reverb.send = 0.1f; p.reverb.roomSize = 0.4f; p.reverb.damping = 0.55f; p.reverb.preDelayMs = 15.0f;
                p.delay.send = 0.15f; p.delay.noteBeats = 0.5f; p.delay.feedback = 0.25f; p.delay.throwsOnly = true;
                p.outputDb = -14.0f;
                break;
            case Style::FunkBresilien:
                // Baile funk : voix scandée, sèche et saturée, compression très forte.
                p.pitch = { true, 0.5f, 20.0f, 0.5f };
                p.clean.hpfHz = 120.0f;
                p.eq = { 120.0f, 200.0f, 0.0f, 300.0f, -3.0f, 1.0f, 3000.0f, 4.0f, 1.0f, 12000.0f, 2.0f, 0.0f };
                p.comp = { -18.0f, 8.0f, 4.0f, 2.0f, 50.0f, 0.0f, 1.0f, false };
                p.comp2 = { -26.0f, 2.0f, 8.0f, 15.0f, 150.0f, 0.0f, 1.0f, true };
                p.deEss = { 7000.0f, 0.6f, 6.0f, -8.0f };
                p.sat = { 8.0f, 0.45f, 0.2f };
                p.reverb.send = 0.06f; p.reverb.roomSize = 0.3f; p.reverb.damping = 0.6f; p.reverb.preDelayMs = 10.0f;
                p.delay.send = 0.1f; p.delay.noteBeats = 0.5f; p.delay.feedback = 0.2f; p.delay.throwsOnly = true;
                p.outputDb = -14.0f;
                break;
            case Style::AfroHouse:
                // Voix posée dans un grand espace : réverb longue, délai croche pointée ping-pong, justesse discrète.
                p.pitch = { true, 0.5f, 25.0f, 0.5f };
                p.clean.hpfHz = 110.0f;
                p.eq = { 110.0f, 200.0f, 0.0f, 300.0f, -2.0f, 1.0f, 3500.0f, 2.5f, 0.9f, 12000.0f, 4.0f, 0.0f };
                p.comp = { -21.0f, 4.0f, 6.0f, 6.0f, 100.0f, 0.0f, 1.0f, false };
                p.comp2 = { -27.0f, 2.0f, 8.0f, 25.0f, 200.0f, 0.0f, 1.0f, true };
                p.deEss = { 7000.0f, 0.7f, 6.0f, -8.0f };
                p.sat = { 2.0f, 0.2f, 0.1f };
                p.reverb.send = 0.32f; p.reverb.roomSize = 0.8f; p.reverb.damping = 0.5f; p.reverb.preDelayMs = 45.0f;
                p.delay.send = 0.25f; p.delay.noteBeats = 0.75f; p.delay.feedback = 0.45f; p.delay.pingPong = true;
                p.outputDb = -14.0f;
                break;
            case Style::Country:
                // Voix naturelle et chaleureuse, doublée, slapback court typique, réverb moyenne.
                p.pitch = { true, 0.3f, 50.0f, 0.8f };
                p.clean.hpfHz = 80.0f;
                p.eq = { 80.0f, 200.0f, 1.0f, 300.0f, -2.0f, 1.0f, 3000.0f, 2.5f, 0.8f, 12000.0f, 2.5f, 0.0f };
                p.comp = { -20.0f, 4.0f, 6.0f, 10.0f, 120.0f, 0.0f, 1.0f, false };
                p.comp2 = { -26.0f, 2.0f, 8.0f, 25.0f, 200.0f, 0.0f, 1.0f, true };
                p.deEss = { 7000.0f, 0.6f, 6.0f, -8.0f };
                p.sat = { 2.0f, 0.2f, 0.1f };
                p.reverb.send = 0.18f; p.reverb.roomSize = 0.5f; p.reverb.damping = 0.5f; p.reverb.preDelayMs = 30.0f;
                p.delay.send = 0.12f; p.delay.noteBeats = 0.25f; p.delay.feedback = 0.1f;
                p.outputDb = -14.0f;
                break;
        }
        return p;
    }

    void applyRole (VocalParams& p, Role r)
    {
        switch (r)
        {
            case Role::Lead:
            case Role::Instru:
            case Role::Count:
                break;
            case Role::Double:
                p.outputDb -= 7.0f;
                p.pitch.enabled = false;
                p.clean.breathReductionDb = 14.0f;
                p.eq.lowCutHz = 150.0f;
                p.eq.presenceDb -= 2.0f;
                p.eq.airDb -= 1.0f;
                p.comp.ratio += 2.0f;
                p.deEss.amount = std::min (1.0f, p.deEss.amount + 0.2f);
                p.sat.mix *= 0.7f;
                p.reverb.send *= 0.6f;
                p.delay.send = 0.0f;
                p.timing.strength = 0.0f;
                break;
            case Role::Harmony:
                p.outputDb -= 11.0f;
                p.pitch.enabled = false;
                p.clean.breathReductionDb = 14.0f;
                p.eq.lowCutHz = 200.0f;
                p.eq.presenceDb -= 3.0f;
                p.eq.airDb += 1.0f;
                p.comp.ratio += 2.0f;
                p.comp.thresholdDb -= 3.0f;
                p.deEss.amount = std::min (1.0f, p.deEss.amount + 0.3f);
                p.sat.mix *= 0.5f;
                p.reverb.send = p.reverb.send * 1.5f + 0.05f;
                p.delay.send *= 0.5f;
                break;
            case Role::KeywordBack:
                p.outputDb -= 6.0f;
                p.pitch.enabled = false;
                p.clean.gateRangeDb = 20.0f;
                p.eq.lowCutHz = 180.0f;
                p.eq.mudDb -= 1.0f;
                p.eq.presenceDb += 1.0f;
                p.sat.driveDb += 4.0f;
                p.sat.mix = std::min (0.8f, p.sat.mix + 0.15f);
                p.reverb.send *= 0.5f;
                p.delay.send = 0.0f;
                p.width = 0.6f;
                break;
            case Role::AdLib:
                p.outputDb -= 9.0f;
                p.pitch.enabled = false;
                p.eq.lowCutHz = 220.0f;
                p.eq.highCutHz = 9000.0f;
                p.sat.driveDb += 6.0f;
                p.sat.mix = std::min (0.8f, p.sat.mix + 0.25f);
                p.delay.send = std::max (0.25f, p.delay.send);
                p.delay.throwsOnly = false;
                p.delay.feedback = 0.35f;
                p.reverb.send *= 1.3f;
                break;
            case Role::Ambiance:
                p.outputDb -= 18.0f;
                p.pitch.enabled = false;
                p.clean.breathReductionDb = 20.0f;
                p.eq.lowCutHz = 250.0f;
                p.eq.highCutHz = 6000.0f;
                p.dryGain = 0.15f;
                p.reverb.send = 1.0f;
                p.reverb.roomSize = 0.95f;
                p.reverb.damping = 0.6f;
                p.reverb.width = 1.0f;
                p.reverb.preDelayMs = 60.0f;
                p.delay.send = 0.2f;
                p.delay.noteBeats = 2.0f;
                p.delay.feedback = 0.4f;
                p.delay.throwsOnly = false;
                p.comp.ratio = 2.0f;
                p.comp2.ratio = 1.0f;
                p.sat.mix = 0.0f;
                p.width = 1.0f;
                p.deEss.amount = 0.9f;
                break;
            case Role::ManualBack:
                p.outputDb -= 6.0f;
                p.eq.lowCutHz = 160.0f;
                p.eq.presenceDb += 1.0f;
                p.sat.driveDb += 3.0f;
                p.reverb.send *= 0.7f;
                p.delay.send *= 0.5f;
                p.width = 0.4f;
                break;
            case Role::Instrument:
                // Instrument : pas de correction de justesse ni de de-esser, nettoyage léger, compression douce,
                // EQ presque neutre (le bas reste : basse, guitare), un peu de la réverb du style, pas de délai.
                p.pitch.enabled = false;
                p.pitch.amount = 0.0f;
                p.clean.dePlosive = false;
                p.clean.breathReductionDb = 0.0f;
                p.clean.gateRangeDb = 6.0f;
                p.clean.denoiseDb = 6.0f;
                p.clean.hpfHz = 30.0f;
                p.eq = { 30.0f, 200.0f, 0.0f, 300.0f, -1.0f, 1.0f, 3000.0f, 1.0f, 0.8f, 12000.0f, 1.0f, 0.0f };
                p.comp = { -20.0f, 2.5f, 10.0f, 15.0f, 150.0f, 0.0f, 1.0f, true };
                p.comp2.ratio = 1.0f;
                p.deEss.amount = 0.0f;
                p.sat = { 1.5f, 0.15f, 0.1f };
                p.reverb.send *= 0.6f;
                p.delay.send = 0.0f;
                p.timing.strength = 0.0f;
                p.outputDb -= 4.0f;
                break;
        }
    }

    void applyMacros (VocalParams& p, const Macros& userMacros)
    {
        // Les curseurs sont des positions réelles : la position « du style » (styleMacros) laisse le son du style
        // intact ; s'en écarter modifie les réglages d'autant. Chaque style a donc ses propres positions de départ.
        const Macros pos = styleMacros (p);
        const Macros m = resolveMacros (userMacros, p);

        // Autotune : la position est la quantité de correction ; vers la droite la vitesse se durcit (effet robot).
        const float a = juce::jlimit (0.0f, 1.0f, m.autotune);
        if (a < 0.02f)
        {
            p.pitch.amount = 0.0f;
            p.pitch.enabled = false;
        }
        else
        {
            p.pitch.enabled = true;
            p.pitch.amount = a;
            if (a > pos.autotune + 0.001f && pos.autotune < 0.999f)
            {
                const float t = (a - pos.autotune) / (1.0f - pos.autotune);
                p.pitch.retuneMs = lerp (p.pitch.retuneMs, 2.0f, t);
                p.pitch.humanize = lerp (p.pitch.humanize, 0.0f, t);
            }
        }

        // Présence : ±0,5 autour de la position du style = ±8 dB de présence, ±6 dB d'air, ∓2 dB de bas-médium.
        const float pr = (juce::jlimit (0.0f, 1.0f, m.presence) - pos.presence) * 2.0f;
        p.eq.presenceDb += pr * 8.0f;
        p.eq.airDb += pr * 6.0f;
        p.eq.mudDb -= pr * 2.0f;

        // Espace : les envois du style sont multipliés par position / position du style (0 = sec).
        const float rt = juce::jlimit (0.0f, 1.0f, m.reverbTrim) * 2.0f;
        const float dt = juce::jlimit (0.0f, 1.0f, m.delayTrim) * 2.0f;
        const float spPos = juce::jlimit (0.0f, 1.0f, m.space);
        if (pos.space > 0.01f)
        {
            const float f = spPos / pos.space;
            p.reverb.send = juce::jlimit (0.0f, 1.5f, p.reverb.send * f * rt);
            p.delay.send = juce::jlimit (0.0f, 1.0f, p.delay.send * f * dt);
        }
        else
        {
            p.reverb.send = juce::jlimit (0.0f, 1.5f, spPos * 0.3f * rt);
            p.delay.send = juce::jlimit (0.0f, 1.0f, spPos * 0.15f * dt);
        }

        // Énergie : ±0,5 autour de la position du style.
        const float en = (juce::jlimit (0.0f, 1.0f, m.energy) - pos.energy) * 2.0f;
        if (p.comp.ratio > 1.0f)
        {
            p.comp.ratio = std::max (1.5f, p.comp.ratio * (1.0f + 0.5f * en));
            p.comp.thresholdDb -= en * 6.0f;
        }
        p.sat.driveDb = std::max (0.0f, p.sat.driveDb + en * 6.0f);
        if (p.sat.mix > 0.0f || en > 0.0f)
            p.sat.mix = juce::jlimit (0.0f, 0.8f, p.sat.mix + en * 0.2f);

        // Volume
        p.outputDb += (juce::jlimit (0.0f, 1.0f, m.level) - 0.5f) * 24.0f;
    }
}

const std::vector<StyleGroup>& styleGroups()
{
    static const std::vector<StyleGroup> groups = {
        { "Rap", { Style::Rap, Style::RapConscient, Style::RapHardcore, Style::BoomBap, Style::Trap, Style::Drill,
                   Style::RapMelodique, Style::CloudRap, Style::Rage, Style::Plugg, Style::EmoRap, Style::AfroTrap,
                   Style::LoFi, Style::Phonk, Style::JerseyClub } },
        { "Chant / Pop / R&B", { Style::PopUrbaine, Style::Pop, Style::RnB, Style::Gospel, Style::Variete, Style::Rai,
                                 Style::Rock, Style::Acoustique, Style::Country } },
        { "Afro / Caraïbes / Latino", { Style::Afro, Style::Amapiano, Style::Dancehall, Style::Bouyon, Style::Zouk,
                                        Style::Latino, Style::FunkBresilien } },
        { "Électro", { Style::Electro, Style::AfroHouse } },
    };
    return groups;
}

juce::String styleId (Style s) { return kStyles[juce::jlimit (0, kLastStyle, static_cast<int> (s))].id; }
juce::String styleName (Style s) { return juce::String (juce::CharPointer_UTF8 (kStyles[juce::jlimit (0, kLastStyle, static_cast<int> (s))].name)); }

Style styleFromId (const juce::String& id)
{
    for (int i = 0; i < static_cast<int> (Style::Count); ++i)
        if (id == kStyles[i].id)
            return static_cast<Style> (i);
    return Style::Rap;
}

juce::String roleId (Role r) { return kRoles[juce::jlimit (0, kLastRole, static_cast<int> (r))].id; }
juce::String roleName (Role r) { return juce::String (juce::CharPointer_UTF8 (kRoles[juce::jlimit (0, kLastRole, static_cast<int> (r))].name)); }

const std::vector<Role>& userTrackRoles()
{
    static const std::vector<Role> roles = { Role::Lead, Role::ManualBack, Role::Double, Role::Harmony, Role::AdLib,
                                             Role::Ambiance, Role::Instrument };
    return roles;
}

juce::String userTrackLabel (Role r)
{
    switch (r)
    {
        case Role::Lead:        return "Voix principale (lead)";
        case Role::ManualBack:  return "Back (voix d'appui sur les mots forts)";
        case Role::Double:      return "Doublage (même texte, chanté par-dessus)"_u8;
        case Role::Harmony:     return "Harmonie (chantée au-dessus ou en dessous)"_u8;
        case Role::AdLib:       return "Ad-libs (interjections, cris, « yeah »)"_u8;
        case Role::Ambiance:    return "Ambiance / chœurs lointains"_u8;
        case Role::Instrument:  return "Instrument (guitare, clavier, basse…)"_u8;
        case Role::Instru:
        case Role::KeywordBack:
        case Role::Count:       break;
    }
    return roleName (r);
}

Role guessRoleForImport (const juce::String& fileName, int voiceContent, bool projectHasInstru, bool leadHasTakes)
{
    const auto byName = guessRoleForFile (fileName, projectHasInstru, leadHasTakes);
    // Nom explicite (« voix », « instru », « guitare »…) : le résultat ne dépend pas de l'état du projet.
    const bool explicitName = guessRoleForFile (fileName, true, leadHasTakes) == guessRoleForFile (fileName, false, leadHasTakes);
    const auto fallback = projectHasInstru ? Role::Instrument : Role::Instru;
    if (explicitName || voiceContent < 0)
        return byName;
    if (voiceContent == 1)
        return leadHasTakes ? Role::ManualBack : Role::Lead;
    return fallback;
}

Role guessRoleForFile (const juce::String& fileName, bool projectHasInstru, bool leadHasTakes)
{
    const auto n = fileName.fromLastOccurrenceOf ("/", false, false).fromLastOccurrenceOf ("\\", false, false)
                       .upToLastOccurrenceOf (".", false, false).toLowerCase();
    auto has = [&n] (std::initializer_list<const char*> words)
    {
        for (const auto* w : words)
            if (n.contains (juce::String (juce::CharPointer_UTF8 (w))))
                return true;
        return false;
    };
    if (has ({ "instru", "beat", "prod", "riddim" }))
        return Role::Instru;
    if (has ({ "adlib", "ad-lib", "ad lib" }))
        return Role::AdLib;
    if (has ({ "harmo" }))
        return Role::Harmony;
    if (has ({ "double", "doublage", "dbl" }))
        return Role::Double;
    if (has ({ "back", "choeur", "chœur", "choir", "chorus" }))
        return Role::ManualBack;
    if (has ({ "ambiance", "ambient", "foule", "crowd" }))
        return Role::Ambiance;
    if (has ({ "voix", "vocal", "vox", "lead", "acapella", "a cappella", "acappella", "chant" }))
        return leadHasTakes ? Role::ManualBack : Role::Lead;
    if (has ({ "guitar", "piano", "clavier", "keys", "bass", "basse", "synth", "melod", "violon", "violin", "drum", "batterie", "loop" }))
        return Role::Instrument;
    return projectHasInstru ? Role::Instrument : Role::Instru;
}

juce::String userTrackBaseName (Role r)
{
    switch (r)
    {
        case Role::Lead:        return "Voix principale";
        case Role::ManualBack:  return "Back";
        case Role::Double:      return "Doublage";
        case Role::Harmony:     return "Harmonie";
        case Role::AdLib:       return "Ad-libs";
        case Role::Ambiance:    return "Ambiance";
        case Role::Instrument:  return "Instrument";
        case Role::Instru:
        case Role::KeywordBack:
        case Role::Count:       break;
    }
    return roleName (r);
}

Role roleFromId (const juce::String& id)
{
    for (int i = 0; i < static_cast<int> (Role::Count); ++i)
        if (id == kRoles[i].id)
            return static_cast<Role> (i);
    return Role::Lead;
}

Macros styleMacros (const VocalParams& base)
{
    Macros m;
    m.custom = true;
    m.autotune = base.pitch.enabled ? juce::jlimit (0.0f, 1.0f, base.pitch.amount) : 0.0f;
    m.presence = juce::jlimit (0.0f, 1.0f, 0.5f + base.eq.presenceDb / 16.0f);
    m.space = juce::jlimit (0.0f, 1.0f, (base.reverb.send + 0.5f * base.delay.send) / 0.4f);
    m.energy = juce::jlimit (0.0f, 1.0f, 0.2f + (std::max (1.0f, base.comp.ratio) - 1.0f) / 8.0f + base.sat.mix * 0.5f);
    m.level = 0.5f;
    return m;
}

Macros resolveMacros (const Macros& m, const VocalParams& base)
{
    if (m.custom)
        return m;
    Macros r = styleMacros (base);
    r.level = m.level;
    r.reverbTrim = m.reverbTrim;
    r.delayTrim = m.delayTrim;
    r.custom = false;
    return r;
}

juce::var Macros::toVar() const
{
    auto* o = new juce::DynamicObject();
    o->setProperty ("custom", custom);
    o->setProperty ("autotune", autotune);
    o->setProperty ("presence", presence);
    o->setProperty ("space", space);
    o->setProperty ("energy", energy);
    o->setProperty ("level", level);
    o->setProperty ("reverbTrim", reverbTrim);
    o->setProperty ("delayTrim", delayTrim);
    return juce::var (o);
}

Macros Macros::fromVar (const juce::var& v)
{
    Macros m;
    auto get = [&] (const char* key, float def)
    {
        const auto x = v.getProperty (key, def);
        const float f = static_cast<float> (static_cast<double> (x));
        return std::isfinite (f) ? juce::jlimit (0.0f, 1.0f, f) : def;
    };
    m.autotune = get ("autotune", 0.5f);
    m.presence = get ("presence", 0.5f);
    m.space = get ("space", 0.5f);
    m.energy = get ("energy", 0.5f);
    m.level = get ("level", 0.5f);
    m.reverbTrim = get ("reverbTrim", 0.5f);
    m.delayTrim = get ("delayTrim", 0.5f);
    // Anciens projets (sans « custom ») : les curseurs étaient des écarts autour de 0,5 ; ils reprennent les positions du style.
    m.custom = static_cast<bool> (v.getProperty ("custom", false));
    return m;
}

VocalParams makeParams (Style s, Role r, const Macros& macros, bool recordedByUser)
{
    VocalParams p = leadBase (s);
    applyRole (p, r);
    if (r != Role::Instrument && r != Role::Instru)
    {
        // Voix : fader suivi (±4 dB autour du niveau d'entrée) avant les compresseurs, puis résonances rabaissées
        // doucement (dureté variable) — comme un « vocal rider » puis un suppresseur de résonances en studio.
        p.leveler.enabled = true;
        p.leveler.targetDb = p.inputTargetDb;
        p.leveler.maxBoostDb = 4.0f;
        p.leveler.maxCutDb = 4.0f;
        p.resonance.enabled = true;
        p.resonance.thresholdDb = 6.0f;
        p.resonance.maxReductionDb = 3.0f;
        p.resonance.protectBelowHz = 600.0f;
    }
    if (recordedByUser && (r == Role::Double || r == Role::Harmony || r == Role::KeywordBack || r == Role::AdLib || r == Role::Ambiance))
        p.pitch = leadBase (s).pitch;   // chanté au micro : justesse du style (les pistes générées sont déjà corrigées)
    applyMacros (p, macros);
    return p;
}

GenerationDefaults generationDefaults (Style s)
{
    GenerationDefaults g;
    switch (s)
    {
        case Style::Rap:        g = { 1, 0, true, true, true, 0.3f, 2, 0.45f }; break;
        case Style::Trap:       g = { 2, 1, true, true, true, 0.3f, 2, 0.6f }; break;
        case Style::PopUrbaine: g = { 1, 1, true, false, true, 0.5f, 2, 0.3f }; break;
        case Style::RnB:        g = { 1, 2, false, true, true, 0.8f, 1, 0.25f }; break;
        case Style::Drill:      g = { 1, 0, true, true, false, 0.0f, 1, 0.5f }; break;
        case Style::Rock:       g = { 2, 1, true, false, false, 0.0f, 2, 0.2f }; break;
        case Style::Latino:     g = { 1, 2, true, true, true, 0.4f, 2, 0.55f }; break;
        case Style::RapMelodique: g = { 2, 1, true, true, true, 0.4f, 2, 0.5f }; break;
        case Style::BoomBap:    g = { 1, 0, true, true, false, 0.0f, 2, 0.35f }; break;
        case Style::Pop:        g = { 2, 2, true, false, true, 0.5f, 2, 0.25f }; break;
        case Style::Variete:    g = { 1, 1, false, false, true, 0.4f, 1, 0.1f }; break;
        case Style::Dancehall:  g = { 1, 1, true, true, false, 0.0f, 2, 0.65f }; break;
        case Style::Zouk:       g = { 1, 2, false, true, true, 0.6f, 2, 0.3f }; break;
        case Style::Amapiano:   g = { 1, 2, false, true, true, 0.7f, 2, 0.4f }; break;
        case Style::Gospel:     g = { 1, 2, false, true, true, 0.6f, 1, 0.3f }; break;
        case Style::Electro:    g = { 2, 1, true, false, true, 0.6f, 2, 0.2f }; break;
        case Style::Acoustique: g = { 1, 1, false, false, false, 0.0f, 1, 0.1f }; break;
        case Style::RapConscient: g = { 1, 0, true, false, false, 0.0f, 2, 0.2f }; break;
        case Style::RapHardcore: g = { 2, 0, true, true, false, 0.0f, 2, 0.6f }; break;
        case Style::CloudRap: g = { 1, 1, false, true, true, 0.8f, 2, 0.4f }; break;
        case Style::Rage: g = { 2, 0, true, true, false, 0.0f, 2, 0.75f }; break;
        case Style::Plugg: g = { 1, 1, true, true, true, 0.5f, 2, 0.5f }; break;
        case Style::EmoRap: g = { 2, 1, true, true, true, 0.6f, 2, 0.4f }; break;
        case Style::AfroTrap: g = { 2, 1, true, true, false, 0.0f, 2, 0.65f }; break;
        case Style::LoFi: g = { 1, 0, false, false, true, 0.5f, 1, 0.2f }; break;
        case Style::Phonk: g = { 2, 0, true, true, false, 0.0f, 2, 0.5f }; break;
        case Style::JerseyClub: g = { 2, 1, true, true, false, 0.0f, 2, 0.6f }; break;
        case Style::Rai: g = { 1, 2, false, true, true, 0.5f, 2, 0.4f }; break;
        case Style::Bouyon: g = { 2, 0, true, true, false, 0.0f, 2, 0.7f }; break;
        case Style::FunkBresilien: g = { 2, 0, true, true, false, 0.0f, 1, 0.7f }; break;
        case Style::AfroHouse: g = { 1, 2, false, true, true, 0.7f, 2, 0.3f }; break;
        case Style::Country: g = { 2, 1, false, false, false, 0.0f, 1, 0.1f }; break;
        case Style::Afro:
        case Style::Count:      g = { 1, 2, false, true, true, 0.6f, 2, 0.5f }; break;
    }
    return g;
}

MasterTone masterTone (Style s)
{
    switch (s)
    {
        case Style::Rap:        return { 1.0f, 0.5f, 1.5f };
        case Style::Trap:       return { 1.5f, 1.0f, 0.5f };
        case Style::PopUrbaine: return { 0.5f, 1.5f, 1.5f };
        case Style::RnB:        return { 1.0f, 1.0f, 1.0f };
        case Style::Drill:      return { 1.5f, 0.5f, 0.5f };
        case Style::Rock:       return { 0.5f, 1.0f, 0.0f };
        case Style::Latino:     return { 1.5f, 1.0f, 1.0f };
        case Style::RapMelodique: return { 1.5f, 1.0f, 1.0f };
        case Style::BoomBap:    return { 1.0f, 0.0f, 2.0f };
        case Style::Pop:        return { 0.5f, 1.5f, 1.5f };
        case Style::Variete:    return { 0.5f, 1.0f, 2.0f };
        case Style::Dancehall:  return { 1.5f, 1.0f, 1.0f };
        case Style::Zouk:       return { 1.0f, 1.0f, 1.0f };
        case Style::Amapiano:   return { 1.5f, 0.5f, 0.5f };
        case Style::Gospel:     return { 1.0f, 1.0f, 1.0f };
        case Style::Electro:    return { 1.5f, 1.5f, 0.0f };
        case Style::Acoustique: return { 0.0f, 1.0f, 1.5f };
        case Style::RapConscient: return { 1.0f, 0.5f, 2.0f };
        case Style::RapHardcore: return { 1.5f, 0.5f, 1.5f };
        case Style::CloudRap: return { 1.0f, 1.0f, 0.0f };
        case Style::Rage: return { 1.5f, 1.5f, 0.0f };
        case Style::Plugg: return { 1.5f, 1.0f, 0.5f };
        case Style::EmoRap: return { 1.0f, 1.0f, 0.5f };
        case Style::AfroTrap: return { 1.5f, 1.0f, 1.0f };
        case Style::LoFi: return { 1.0f, -1.0f, 0.5f };
        case Style::Phonk: return { 2.0f, 0.0f, 0.0f };
        case Style::JerseyClub: return { 1.5f, 1.5f, 0.5f };
        case Style::Rai: return { 1.0f, 1.0f, 1.0f };
        case Style::Bouyon: return { 1.5f, 1.0f, 0.5f };
        case Style::FunkBresilien: return { 2.0f, 1.0f, 0.5f };
        case Style::AfroHouse: return { 1.5f, 1.0f, 0.0f };
        case Style::Country: return { 0.5f, 1.0f, 1.5f };
        case Style::Afro:
        case Style::Count:      return { 1.0f, 1.0f, 1.0f };
    }
    return {};
}
} // namespace sv::style
