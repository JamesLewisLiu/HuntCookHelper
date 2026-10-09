#pragma once
#include "EditorSample.hpp"

namespace hc::huntPointsSample {
inline constexpr std::uintptr_t getter = 0x65c58;
inline constexpr std::uintptr_t setter = 0x65c88;
inline constexpr std::uintptr_t getterSlot = editorSample::userVtable + 384;
inline constexpr std::uintptr_t setterSlot = editorSample::userVtable + 392;
inline constexpr std::size_t cache = 152, initialized = 164, userSize = 328;


struct Profile {
    std::uintptr_t getter = huntPointsSample::getter;
    std::uintptr_t setter = huntPointsSample::setter;
    std::uintptr_t getterSlot = huntPointsSample::getterSlot;
    std::uintptr_t setterSlot = huntPointsSample::setterSlot;
};
inline constexpr Profile original{};
inline constexpr Profile japanese = [] {
    Profile p = original;
    p.getter = 0x61660;
    p.setter = 0x61690;
    p.getterSlot = 0x12f1df0;
    p.setterSlot = 0x12f1df8;
    return p;
}();

template<class Access>
bool validate(Access &access, std::uintptr_t expectedSetter, const Profile &p = original) {
    return access.accessible(p.getter, 16, 5) && access.accessible(p.setter, 16, 5) &&
        access.equalBytes(p.getter, editorSample::getterBytes.data(), 16) &&
        access.equalBytes(p.setter, editorSample::setterBytes.data(), 16) &&
        access.accessible(p.getterSlot, 8, 1) && access.accessible(p.setterSlot, 8, 3) &&
        access.pointer(p.getterSlot) == access.address(p.getter) &&
        access.pointer(p.setterSlot) == expectedSetter;
}
}
