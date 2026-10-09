#pragma once
#include "Sample.hpp"
#include "Editor.hpp"

namespace hc::editorSample {
inline constexpr std::uintptr_t userSlot = 0x155d4e8;
inline constexpr std::uintptr_t userVtable = 0x116c7a8;
inline constexpr std::uintptr_t foodsSlot = 0x1567458;
inline constexpr std::uintptr_t foodVtable = 0x11668d0;
inline constexpr std::uintptr_t foodGet = 0x4720c;
inline constexpr std::uintptr_t foodSet = 0x47440;
inline constexpr std::uintptr_t languageGet = 0x91e5c;
struct Field { Resource resource; std::size_t setterSlot, getterSlot; std::uintptr_t setter, getter; };
inline constexpr Field fields[] = {
    {Resource::experience, 80, 88, 0x654a0, 0x654d8},
    {Resource::coin, 0, 8, 0x65298, 0x652d0},
    {Resource::diamond, 32, 40, 0x65368, 0x653a0},
    {Resource::redCow, 608, 616, 0x66208, 0x66240},
    {Resource::trainingTicket, 128, 136, 0x655d8, 0x65610},
    {Resource::storehouseCapacity, 408, 400, 0x65cf0, 0x65cc0},
};
inline constexpr std::array<std::uint8_t,16> setterBytes = {
    0xf4,0x4f,0xbe,0xa9,0xfd,0x7b,0x01,0xa9,0xfd,0x43,0x00,0x91,0xf3,0x03,0x01,0xaa};
inline constexpr std::array<std::uint8_t,16> getterBytes = {
    0xf4,0x4f,0xbe,0xa9,0xfd,0x7b,0x01,0xa9,0xfd,0x43,0x00,0x91,0xf3,0x03,0x00,0xaa};
inline constexpr sample::Entry extraEntries[] = {
    {foodGet, {0xff,0x43,0x01,0xd1,0xf4,0x4f,0x03,0xa9,0xfd,0x7b,0x04,0xa9,0xfd,0x03,0x01,0x91}},
    {foodSet, {0xff,0x03,0x02,0xd1,0xf6,0x57,0x05,0xa9,0xf4,0x4f,0x06,0xa9,0xfd,0x7b,0x07,0xa9}},
    {languageGet, {0xfd,0x7b,0xbf,0xa9,0xfd,0x03,0x00,0x91,0x03,0xb8,0x31,0x94,0x08,0x00,0x40,0xf9}},
};

struct Profile {
    std::uintptr_t userSlot = editorSample::userSlot;
    std::uintptr_t userVtable = editorSample::userVtable;
    std::uintptr_t foodsSlot = editorSample::foodsSlot;
    std::uintptr_t foodVtable = editorSample::foodVtable;
    std::uintptr_t foodGet = editorSample::foodGet;
    std::uintptr_t foodSet = editorSample::foodSet;
    std::uintptr_t languageGet = editorSample::languageGet;
    std::size_t foodSize = 536;
    std::size_t foodCache = 524;
    std::array<Field, 6> fields = {{
        editorSample::fields[0],
        editorSample::fields[1],
        editorSample::fields[2],
        editorSample::fields[3],
        editorSample::fields[4],
        editorSample::fields[5],
    }};
    std::array<sample::Entry, 3> extraEntries = {{
        editorSample::extraEntries[0],
        editorSample::extraEntries[1],
        editorSample::extraEntries[2],
    }};
};
inline constexpr Profile original{};
inline constexpr Profile japanese = [] {
    Profile p = original;
    p.userSlot = 0x1786c58;
    p.userVtable = 0x12f1c70;
    p.foodsSlot = 0x1790a00;
    p.foodVtable = 0x12ec7f8;
    p.foodGet = 0x421c8;
    p.foodSet = 0x423fc;
    p.languageGet = 0x0;
    p.foodSize = 248;
    p.foodCache = 236;
    p.fields[0] = {Resource::experience, 80, 88, 0x60ea8, 0x60ee0};
    p.fields[1] = {Resource::coin, 0, 8, 0x60ca0, 0x60cd8};
    p.fields[2] = {Resource::diamond, 32, 40, 0x60d70, 0x60da8};
    p.fields[3] = {Resource::redCow, 608, 616, 0x61c10, 0x61c48};
    p.fields[4] = {Resource::trainingTicket, 128, 136, 0x60fe0, 0x61018};
    p.fields[5] = {Resource::storehouseCapacity, 408, 400, 0x616f8, 0x616c8};
    p.extraEntries[0] = {0x421c8, {0xff,0x43,0x01,0xd1,0xf4,0x4f,0x03,0xa9,0xfd,0x7b,0x04,0xa9,0xfd,0x03,0x01,0x91}};
    p.extraEntries[1] = {0x423fc, {0xff,0x03,0x02,0xd1,0xf6,0x57,0x05,0xa9,0xf4,0x4f,0x06,0xa9,0xfd,0x7b,0x07,0xa9}};
    p.extraEntries[2] = {0x0, {0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00}};
    return p;
}();

template<class Access>
bool validate(Access &access, const Profile &p = original) {
    const auto entry = [&](std::uintptr_t offset, const auto &bytes) {
        return access.accessible(offset, bytes.size(), 5) && access.equalBytes(offset, bytes.data(), bytes.size());
    };
    const auto slot = [&](std::size_t position, std::uintptr_t function) {
        return access.accessible(p.userVtable + position, 8, 1) &&
            access.pointer(p.userVtable + position) == access.address(function);
    };
    for (const auto &field : p.fields) {
        if (!entry(field.setter, setterBytes) || !entry(field.getter, getterBytes) ||
            !slot(field.setterSlot, field.setter) || !slot(field.getterSlot, field.getter)) return false;
    }
    for (const auto &item : p.extraEntries) if (item.offset && !entry(item.offset, item.bytes)) return false;
    return true;
}
}
