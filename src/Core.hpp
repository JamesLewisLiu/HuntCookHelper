#pragma once
#include "Sample.hpp"
#include <cstring>

namespace hc {
template<class T> T load(const void *object, std::size_t offset) {
    T value;
    std::memcpy(&value, static_cast<const unsigned char *>(object) + offset, sizeof(value));
    return value;
}
template<class T> void store(void *object, std::size_t offset, T value) {
    std::memcpy(static_cast<unsigned char *>(object) + offset, &value, sizeof(value));
}

using TimerFunction = void (*)(void *, float);
using VoidFunction = void (*)(void *);
struct MemberCall { void *target; std::uintptr_t function; };



inline MemberCall decodeMember(void *target, std::uintptr_t member, std::intptr_t adjustment) {
    if (!target || (!member && !(adjustment & 1))) return {nullptr, 0};
    auto *adjusted = static_cast<unsigned char *>(target) + (adjustment >> 1);
    if (adjustment & 1) {
        const auto *vtable = load<const void *>(adjusted, 0);
        member = load<std::uintptr_t>(vtable, static_cast<std::uint32_t>(member));
    }
    return {adjusted, member};
}

inline void dispatchTimer(void *timer, float dt, bool freeze,
                          std::uintptr_t hunt, std::uintptr_t arena, TimerFunction original) {
    if (freeze) {
        const auto call = decodeMember(load<void *>(timer, sample::timerTarget),
                                       load<std::uintptr_t>(timer, sample::timerMember),
                                       load<std::intptr_t>(timer, sample::timerAdjustment));
        if (call.function && (call.function == hunt || call.function == arena)) {
            reinterpret_cast<TimerFunction>(call.function)(call.target, 0.0f);
            return;
        }
    }
    original(timer, dt);
}

inline void dispatchCollision(void *callback, bool ignore, VoidFunction original,
                              VoidFunction retain, VoidFunction release) {
    void *stage = ignore ? load<void *>(callback, sample::callbackStage) : nullptr;
    void *object = stage && load<std::int32_t>(stage, sample::stageState) != 4
        ? load<void *>(stage, sample::stageObject) : nullptr;
    const auto type = object ? load<std::int32_t>(object, sample::objectType) : 0;
    if (type != 2 && type != 4) { original(callback); return; }

    retain(object);
    struct Restore {
        void *object;
        std::int32_t type;
        VoidFunction release;
        ~Restore() {
            store(object, sample::objectType, type);
            release(object);
        }
    } restore{object, type, release};
    store<std::int32_t>(object, sample::objectType, 0);
    original(callback);
}

enum class InstallResult { installed, changedSlot, writeFailed, rollbackFailed };


template<class Writer>
InstallResult installPair(std::uintptr_t *first, std::uintptr_t expectedFirst, std::uintptr_t replacementFirst,
                          std::uintptr_t *second, std::uintptr_t expectedSecond, std::uintptr_t replacementSecond,
                          Writer write) {
    if (*first != expectedFirst || *second != expectedSecond) return InstallResult::changedSlot;
    if (!write(first, expectedFirst, replacementFirst)) return InstallResult::writeFailed;
    if (write(second, expectedSecond, replacementSecond)) return InstallResult::installed;
    if (!write(first, replacementFirst, expectedFirst)) return InstallResult::rollbackFailed;
    return InstallResult::writeFailed;
}
}
