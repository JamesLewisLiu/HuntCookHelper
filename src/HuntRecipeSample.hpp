#pragma once
#include "Sample.hpp"
namespace hc::huntRecipeSample {
inline constexpr std::uintptr_t callbackSlot = 0x1162d50, callbackVtable = 0x1162d20;
inline constexpr std::uintptr_t callback = 0x3c07c, popupVtable = 0x1162620;
inline constexpr std::uintptr_t userSlot = 0x155d4e8, userVtable = 0x116c7a8;
inline constexpr std::uintptr_t spotsSlot = 0x155dee8, spotsVtable = 0x1171df8, spotVtable = 0x11a1970;
inline constexpr std::uintptr_t eventsSlot = 0x155e730, eventsVtable = 0x117a040, eventVtable = 0x11eac28;
inline constexpr std::uintptr_t recipesSlot = 0x155ee08, recipesVtable = 0x117fe60;
inline constexpr std::uintptr_t recipeVtable = 0x11c8bf8, storeVtable = 0x11b0808;
inline constexpr std::uintptr_t directorSlot = 0x156d710, directorVtable = 0x123f8d8;
inline constexpr std::uintptr_t consumeEnergy = 0x63c30, createScene = 0x14c608, createTransition = 0x25388;
inline constexpr std::uintptr_t replaceScene = 0xcbbfc4, recordSpot = 0x65110, recordMapPage = 0x7c268;
inline constexpr std::uintptr_t recipeUnlocked = 0x14fcd8, tutorialReady = 0xfbe90, tutorialPending = 0xfbeb8;
inline constexpr std::uintptr_t largeVtable = 0x11a3ce0, normalVtable = 0x11b10f8;
inline constexpr sample::Entry largeEntries[] = {
    {0x93240, {0xf8,0x5f,0xbc,0xa9,0xf6,0x57,0x01,0xa9,0xf4,0x4f,0x02,0xa9,0xfd,0x7b,0x03,0xa9}},
    {0x11f7dc, {0xff,0x43,0x01,0xd1,0xf4,0x4f,0x03,0xa9,0xfd,0x7b,0x04,0xa9,0xfd,0x03,0x01,0x91}},
    {0x1517ec, {0xff,0x43,0x01,0xd1,0xf4,0x4f,0x03,0xa9,0xfd,0x7b,0x04,0xa9,0xfd,0x03,0x01,0x91}},
};
inline constexpr std::uintptr_t largeSlots[][2] = {
    {largeVtable, 0x1b61c}, {largeVtable + 16, 0x1b62c}, {largeVtable + 40, 0x106780},
    {normalVtable, 0x1b61c}, {normalVtable + 16, 0x1b62c}, {spotVtable + 40, 0x7a034},
};
inline constexpr sample::Entry entries[] = {
    {callback, {0x00,0x04,0x40,0xf9,0x17,0xff,0xff,0x17,0xf4,0x4f,0xbe,0xa9,0xfd,0x7b,0x01,0xa9}},
    {0x3bcdc, {0xf4,0x4f,0xbe,0xa9,0xfd,0x7b,0x01,0xa9,0xfd,0x43,0x00,0x91,0xf3,0x03,0x00,0xaa}},
    {consumeEnergy, {0xf4,0x4f,0xbe,0xa9,0xfd,0x7b,0x01,0xa9,0xfd,0x43,0x00,0x91,0xf3,0x03,0x00,0xaa}},
    {createScene, {0xf6,0x57,0xbd,0xa9,0xf4,0x4f,0x01,0xa9,0xfd,0x7b,0x02,0xa9,0xfd,0x83,0x00,0x91}},
    {createTransition, {0xe9,0x23,0xbd,0x6d,0xf4,0x4f,0x01,0xa9,0xfd,0x7b,0x02,0xa9,0xfd,0x83,0x00,0x91}},
    {replaceScene, {0xf6,0x57,0xbd,0xa9,0xf4,0x4f,0x01,0xa9,0xfd,0x7b,0x02,0xa9,0xfd,0x83,0x00,0x91}},
    {recordSpot, {0xf4,0x4f,0xbe,0xa9,0xfd,0x7b,0x01,0xa9,0xfd,0x43,0x00,0x91,0xf3,0x03,0x01,0xaa}},
    {recordMapPage, {0xff,0x83,0x01,0xd1,0xf8,0x5f,0x02,0xa9,0xf6,0x57,0x03,0xa9,0xf4,0x4f,0x04,0xa9}},
    {recipeUnlocked, {0x09,0xa0,0x43,0xa9,0x3f,0x01,0x08,0xeb,0xa0,0x01,0x00,0x54,0x2a,0x01,0x40,0xb9}},
    {tutorialReady, {0xfd,0x7b,0xbf,0xa9,0xfd,0x03,0x00,0x91,0x44,0x9a,0xfd,0x97,0x08,0x00,0x40,0xf9}},
    {tutorialPending, {0xf4,0x4f,0xbe,0xa9,0xfd,0x7b,0x01,0xa9,0xfd,0x43,0x00,0x91,0xf3,0x03,0x00,0xaa}},
};
inline constexpr std::uintptr_t slots[][2] = {
    {popupVtable + 1352, 0x397c8}, {spotVtable + 80, 0x117850},
    {userVtable + 392, 0x65c88}, {userVtable + 448, 0x65df8},
    {userVtable + 456, 0x65e28}, {userVtable + 528, 0x66000},
};

struct Profile {
    std::uintptr_t callbackSlot = huntRecipeSample::callbackSlot;
    std::uintptr_t callbackVtable = huntRecipeSample::callbackVtable;
    std::uintptr_t callback = huntRecipeSample::callback;
    std::uintptr_t popupVtable = huntRecipeSample::popupVtable;
    std::uintptr_t userSlot = huntRecipeSample::userSlot;
    std::uintptr_t userVtable = huntRecipeSample::userVtable;
    std::uintptr_t spotsSlot = huntRecipeSample::spotsSlot;
    std::uintptr_t spotsVtable = huntRecipeSample::spotsVtable;
    std::uintptr_t spotVtable = huntRecipeSample::spotVtable;
    std::uintptr_t eventsSlot = huntRecipeSample::eventsSlot;
    std::uintptr_t eventsVtable = huntRecipeSample::eventsVtable;
    std::uintptr_t eventVtable = huntRecipeSample::eventVtable;
    std::uintptr_t recipesSlot = huntRecipeSample::recipesSlot;
    std::uintptr_t recipesVtable = huntRecipeSample::recipesVtable;
    std::uintptr_t recipeVtable = huntRecipeSample::recipeVtable;
    std::uintptr_t storeVtable = huntRecipeSample::storeVtable;
    std::uintptr_t directorSlot = huntRecipeSample::directorSlot;
    std::uintptr_t directorVtable = huntRecipeSample::directorVtable;
    std::uintptr_t consumeEnergy = huntRecipeSample::consumeEnergy;
    std::uintptr_t createScene = huntRecipeSample::createScene;
    std::uintptr_t createTransition = huntRecipeSample::createTransition;
    std::uintptr_t replaceScene = huntRecipeSample::replaceScene;
    std::uintptr_t recordSpot = huntRecipeSample::recordSpot;
    std::uintptr_t recordMapPage = huntRecipeSample::recordMapPage;
    std::uintptr_t recipeUnlocked = huntRecipeSample::recipeUnlocked;
    std::uintptr_t tutorialReady = huntRecipeSample::tutorialReady;
    std::uintptr_t tutorialPending = huntRecipeSample::tutorialPending;
    std::uintptr_t largeVtable = huntRecipeSample::largeVtable;
    std::uintptr_t normalVtable = huntRecipeSample::normalVtable;
    std::size_t spotSize = 232;
    std::size_t rareEventOffset = 140;
    std::size_t huntingEventOffset = 120;
    std::size_t recipeSize = 224;
    std::array<sample::Entry, 3> largeEntries = {{
        huntRecipeSample::largeEntries[0],
        huntRecipeSample::largeEntries[1],
        huntRecipeSample::largeEntries[2],
    }};
    std::array<std::array<std::uintptr_t, 2>, 6> largeSlots = {{
        {huntRecipeSample::largeSlots[0][0],huntRecipeSample::largeSlots[0][1]},
        {huntRecipeSample::largeSlots[1][0],huntRecipeSample::largeSlots[1][1]},
        {huntRecipeSample::largeSlots[2][0],huntRecipeSample::largeSlots[2][1]},
        {huntRecipeSample::largeSlots[3][0],huntRecipeSample::largeSlots[3][1]},
        {huntRecipeSample::largeSlots[4][0],huntRecipeSample::largeSlots[4][1]},
        {huntRecipeSample::largeSlots[5][0],huntRecipeSample::largeSlots[5][1]},
    }};
    std::array<sample::Entry, 11> entries = {{
        huntRecipeSample::entries[0],
        huntRecipeSample::entries[1],
        huntRecipeSample::entries[2],
        huntRecipeSample::entries[3],
        huntRecipeSample::entries[4],
        huntRecipeSample::entries[5],
        huntRecipeSample::entries[6],
        huntRecipeSample::entries[7],
        huntRecipeSample::entries[8],
        huntRecipeSample::entries[9],
        huntRecipeSample::entries[10],
    }};
    std::array<std::array<std::uintptr_t, 2>, 6> slots = {{
        {huntRecipeSample::slots[0][0],huntRecipeSample::slots[0][1]},
        {huntRecipeSample::slots[1][0],huntRecipeSample::slots[1][1]},
        {huntRecipeSample::slots[2][0],huntRecipeSample::slots[2][1]},
        {huntRecipeSample::slots[3][0],huntRecipeSample::slots[3][1]},
        {huntRecipeSample::slots[4][0],huntRecipeSample::slots[4][1]},
        {huntRecipeSample::slots[5][0],huntRecipeSample::slots[5][1]},
    }};
};
inline constexpr Profile original{};
inline constexpr Profile japanese = [] {
    Profile p = original;
    p.callbackSlot = 0x12e9220;
    p.callbackVtable = 0x12e91f0;
    p.callback = 0x374d0;
    p.popupVtable = 0x12e8af0;
    p.userSlot = 0x1786c58;
    p.userVtable = 0x12f1c70;
    p.spotsSlot = 0x1787738;
    p.spotsVtable = 0x12f8af0;
    p.spotVtable = 0x1329cb8;
    p.eventsSlot = 0x1787db0;
    p.eventsVtable = 0x1300c40;
    p.eventVtable = 0x1372a70;
    p.recipesSlot = 0x1788530;
    p.recipesVtable = 0x1308098;
    p.recipeVtable = 0x134f488;
    p.storeVtable = 0x1338b98;
    p.directorSlot = 0x1797870;
    p.directorVtable = 0x13cc488;
    p.consumeEnergy = 0x5f638;
    p.createScene = 0x14ce6c;
    p.createTransition = 0x22db0;
    p.replaceScene = 0xe11fc4;
    p.recordSpot = 0x60b18;
    p.recordMapPage = 0x7bd80;
    p.recipeUnlocked = 0x14f274;
    p.tutorialReady = 0x102bd0;
    p.tutorialPending = 0x102bf8;
    p.largeVtable = 0x132cf90;
    p.normalVtable = 0x1339488;
    p.spotSize = 160;
    p.rareEventOffset = 68;
    p.huntingEventOffset = 48;
    p.recipeSize = 80;
    p.largeEntries[0] = {0x91d3c, {0xf8,0x5f,0xbc,0xa9,0xf6,0x57,0x01,0xa9,0xf4,0x4f,0x02,0xa9,0xfd,0x7b,0x03,0xa9}};
    p.largeEntries[1] = {0x12549c, {0xff,0x43,0x01,0xd1,0xf4,0x4f,0x03,0xa9,0xfd,0x7b,0x04,0xa9,0xfd,0x03,0x01,0x91}};
    p.largeEntries[2] = {0x150d88, {0xff,0x43,0x01,0xd1,0xf4,0x4f,0x03,0xa9,0xfd,0x7b,0x04,0xa9,0xfd,0x03,0x01,0x91}};
    p.largeSlots[0] = {0x132cf90, 0x1a1c8};
    p.largeSlots[1] = {0x132cfa0, 0x1a1d8};
    p.largeSlots[2] = {0x132cfb8, 0x10892c};
    p.largeSlots[3] = {0x1339488, 0x1a1c8};
    p.largeSlots[4] = {0x1339498, 0x1a1d8};
    p.largeSlots[5] = {0x1329ce0, 0x3d21c};
    p.entries[0] = {0x374d0, {0x00,0x04,0x40,0xf9,0x17,0xff,0xff,0x17,0xf4,0x4f,0xbe,0xa9,0xfd,0x7b,0x01,0xa9}};
    p.entries[1] = {0x37130, {0xf4,0x4f,0xbe,0xa9,0xfd,0x7b,0x01,0xa9,0xfd,0x43,0x00,0x91,0xf3,0x03,0x00,0xaa}};
    p.entries[2] = {0x5f638, {0xf4,0x4f,0xbe,0xa9,0xfd,0x7b,0x01,0xa9,0xfd,0x43,0x00,0x91,0xf3,0x03,0x00,0xaa}};
    p.entries[3] = {0x14ce6c, {0xf6,0x57,0xbd,0xa9,0xf4,0x4f,0x01,0xa9,0xfd,0x7b,0x02,0xa9,0xfd,0x83,0x00,0x91}};
    p.entries[4] = {0x22db0, {0xe9,0x23,0xbd,0x6d,0xf4,0x4f,0x01,0xa9,0xfd,0x7b,0x02,0xa9,0xfd,0x83,0x00,0x91}};
    p.entries[5] = {0xe11fc4, {0xf6,0x57,0xbd,0xa9,0xf4,0x4f,0x01,0xa9,0xfd,0x7b,0x02,0xa9,0xfd,0x83,0x00,0x91}};
    p.entries[6] = {0x60b18, {0xf4,0x4f,0xbe,0xa9,0xfd,0x7b,0x01,0xa9,0xfd,0x43,0x00,0x91,0xf3,0x03,0x01,0xaa}};
    p.entries[7] = {0x7bd80, {0xff,0x83,0x01,0xd1,0xf8,0x5f,0x02,0xa9,0xf6,0x57,0x03,0xa9,0xf4,0x4f,0x04,0xa9}};
    p.entries[8] = {0x14f274, {0x09,0xa0,0x43,0xa9,0x3f,0x01,0x08,0xeb,0xa0,0x01,0x00,0x54,0x2a,0x01,0x40,0xb9}};
    p.entries[9] = {0x102bd0, {0xfd,0x7b,0xbf,0xa9,0xfd,0x03,0x00,0x91,0x76,0x6d,0xfd,0x97,0x08,0x00,0x40,0xf9}};
    p.entries[10] = {0x102bf8, {0xf4,0x4f,0xbe,0xa9,0xfd,0x7b,0x01,0xa9,0xfd,0x43,0x00,0x91,0xf3,0x03,0x00,0xaa}};
    p.slots[0] = {0x12e9038, 0x34c1c};
    p.slots[1] = {0x1329d08, 0x108934};
    p.slots[2] = {0x12f1df8, 0x61690};
    p.slots[3] = {0x12f1e30, 0x61800};
    p.slots[4] = {0x12f1e38, 0x61830};
    p.slots[5] = {0x12f1e80, 0x61a08};
    return p;
}();

template<class Access> bool validate(Access &access, const Profile &p = original) {
    for (const auto &entry : p.entries)
        if (!access.accessible(entry.offset, entry.bytes.size(), 5) ||
            !access.equalBytes(entry.offset, entry.bytes.data(), entry.bytes.size())) return false;
    for (const auto &slot : p.slots)
        if (!access.accessible(slot[0], 8, 1) || access.pointer(slot[0]) != access.address(slot[1])) return false;
    return access.accessible(p.callbackSlot, 8, 3) && access.pointer(p.callbackSlot) == access.address(p.callback);
}
template<class Access> bool validateLarge(Access &access, const Profile &p = original) {
    for (const auto &entry : p.largeEntries)
        if (!access.accessible(entry.offset, entry.bytes.size(), 5) ||
            !access.equalBytes(entry.offset, entry.bytes.data(), entry.bytes.size())) return false;
    for (const auto &slot : p.largeSlots)
        if (!access.accessible(slot[0], 8, 1) || access.pointer(slot[0]) != access.address(slot[1])) return false;
    return true;
}
}
