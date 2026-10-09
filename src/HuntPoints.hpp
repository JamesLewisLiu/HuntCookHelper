#pragma once
#include "Editor.hpp"

namespace hc {


inline std::int64_t huntPointsWriteValue(bool frozen, bool eligible,
                                        std::int32_t current, std::int64_t requested) {
    return frozen && eligible && current >= 0 && current <= huntPointsMaximum ? current : requested;
}
template<class Backend>
std::int64_t dispatchHuntPointsWrite(Backend &backend, bool frozen, std::int64_t requested) {
    auto selected = requested;
    if (frozen) {
        try {
            if (backend.eligible()) {
                const auto current = backend.read();
                if (current >= 0 && current <= huntPointsMaximum)
                    selected = huntPointsWriteValue(true, true, static_cast<std::int32_t>(current), requested);
            }
        } catch (...) {                                                   }
    }

    return backend.original(selected);
}
bool huntPointsSupported();
bool freezeHuntPoints();
void setFreezeHuntPoints(bool value);
void initializeHuntPoints();
EditResult readHuntPoints(std::int32_t &value);
EditResult editHuntPoints(std::int32_t value, std::int32_t expected);
}
