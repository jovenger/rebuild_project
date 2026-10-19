#pragma once

#include <juce_core/juce_core.h>

/** Littéral UTF-8 : "é"_u8 donne une juce::String correctement décodée
    (juce::String ("é") interprète les octets comme de l'ASCII et produit "Ã©"). */
inline juce::String operator""_u8 (const char* text, std::size_t length)
{
    return juce::String::fromUTF8 (text, static_cast<int> (length));
}
