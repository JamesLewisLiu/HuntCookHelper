#pragma once
#include "Editor.hpp"
#include <algorithm>

namespace hc {
inline constexpr std::int32_t achievementMaximum = 999999999;
struct AchievementEntry {
    std::int32_t id = 0, current = 0, claimed = 0;
    std::string name, key;
    std::vector<std::int32_t> targets;
    std::size_t targetIndex = 0;
};

inline bool achievementStage(std::int32_t lastClaimed, std::size_t count, std::size_t &index) {
    if (!count || count > 128 || lastClaimed < -1 || lastClaimed >= static_cast<std::int32_t>(count)) return false;
    index = std::min(static_cast<std::size_t>(lastClaimed + 1), count - 1);
    return true;
}
template<class Backend>
EditResult writeAchievement(Backend &backend, std::int32_t value, std::int32_t expected) {
    if (value < 0 || value > achievementMaximum) return EditResult::invalidInput;
    const auto old = backend.read();
    if (old < 0 || old > achievementMaximum) return EditResult::invalidInput;
    if (old != expected) return EditResult::changed;
    if (old == value) return EditResult::ok;
    try {
        backend.write(value);
        if (backend.read() == value) return EditResult::ok;
    } catch (...) {                                                                      }
    try {
        backend.write(old);
        return backend.read() == old ? EditResult::writeFailed : EditResult::rollbackFailed;
    } catch (...) { return EditResult::rollbackFailed; }
}
EditResult listAchievements(std::vector<AchievementEntry> &out);
EditResult readAchievement(std::int32_t id, AchievementEntry &out);
EditResult editAchievement(std::int32_t id, const std::string &key, std::int32_t value, std::int32_t expected);
}
