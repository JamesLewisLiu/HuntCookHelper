#pragma once
#include "AchievementSample.hpp"
#include "CookingSample.hpp"
#include "EditorSample.hpp"
#include "HuntPointsSample.hpp"
#include "HuntRecipeSample.hpp"

namespace hc {
struct ExecutableProfile {
    const char *name;
    const sample::Profile &core;
    const editorSample::Profile &editor;
    const achievementSample::Profile &achievement;
    const cookingSample::Profile &cooking;
    const huntRecipeSample::Profile &hunt;
    const huntPointsSample::Profile &huntPoints;
};
inline constexpr ExecutableProfile supportedProfiles[] = {
    {"original", sample::original, editorSample::original, achievementSample::original,
        cookingSample::original, huntRecipeSample::original, huntPointsSample::original},
    {"jp", sample::japanese, editorSample::japanese, achievementSample::japanese,
        cookingSample::japanese, huntRecipeSample::japanese, huntPointsSample::japanese},
};
inline const ExecutableProfile *findProfile(const std::array<std::uint8_t, 16> &uuid) {
    for (const auto &profile : supportedProfiles) if (profile.core.uuid == uuid) return &profile;
    return nullptr;
}


inline const ExecutableProfile *loadedProfile = &supportedProfiles[0];
inline const ExecutableProfile &activeProfile() { return *loadedProfile; }
}
