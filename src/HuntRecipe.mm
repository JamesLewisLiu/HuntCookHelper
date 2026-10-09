#import <Foundation/Foundation.h>
#include <mach-o/dyld.h>
#include <mach/mach.h>
#include <mach/vm_map.h>
#include <atomic>
#include <stdexcept>
#include <vector>
#include "Core.hpp"
#include "Runtime.hpp"
#include "Profiles.hpp"
#include "HuntRecipe.hpp"
#include "HuntRecipeSample.hpp"

namespace hc {
namespace {
std::atomic<bool> enabled{true}, installed{false};
std::atomic<bool> largeEnabled{true}, largeCompatible{false};
using Callback = void (*)(void *, void *);
Callback originalCallback = nullptr;
bool installing = false;
thread_local bool starting = false;
std::uintptr_t base() { return reinterpret_cast<std::uintptr_t>(_dyld_get_image_header(0)); }
bool mapped(std::uintptr_t address, std::size_t length, vm_prot_t protection = VM_PROT_READ) {
    if (!address || !length || length > UINTPTR_MAX - address) return false;
    const auto end = address + length;
    while (address < end) {
        vm_address_t region = address;
        vm_size_t size = 0;
        vm_region_basic_info_data_64_t info{};
        mach_msg_type_number_t count = VM_REGION_BASIC_INFO_COUNT_64;
        mach_port_t object = MACH_PORT_NULL;
        const auto result = vm_region_64(mach_task_self(), &region, &size, VM_REGION_BASIC_INFO_64,
            reinterpret_cast<vm_region_info_t>(&info), &count, &object);
        if (object != MACH_PORT_NULL) mach_port_deallocate(mach_task_self(), object);
        if (result != KERN_SUCCESS || region > address || size > UINTPTR_MAX - region || region + size <= address ||
            (info.protection & protection) != protection) return false;
        address = region + size;
    }
    return true;
}
struct Access {
    std::uintptr_t address(std::uintptr_t offset) const { return base() + offset; }
    bool accessible(std::uintptr_t offset, std::size_t size, std::uint32_t protection) const {
        return offset <= UINTPTR_MAX - base() && mapped(address(offset), size, protection);
    }
    bool equalBytes(std::uintptr_t offset, const void *bytes, std::size_t size) const {
        return std::memcmp(reinterpret_cast<void *>(address(offset)), bytes, size) == 0;
    }
    std::uintptr_t pointer(std::uintptr_t offset) const { return load<std::uintptr_t>(reinterpret_cast<void *>(address(offset)), 0); }
};
bool objectIs(void *object, std::size_t size, std::uintptr_t vtable) {
    return mapped(reinterpret_cast<std::uintptr_t>(object), size, VM_PROT_READ | VM_PROT_WRITE) &&
        load<std::uintptr_t>(object, 0) == base() + vtable;
}
void *singleton(std::uintptr_t slot, std::size_t size, std::uintptr_t vtable) {
    if (!mapped(base() + slot, 8)) return nullptr;
    auto *object = load<void *>(reinterpret_cast<void *>(base() + slot), 0);
    return objectIs(object, size, vtable) ? object : nullptr;
}
bool vectorRange(void *object, std::size_t offset, std::size_t stride, std::uintptr_t &start, std::uintptr_t &end) {
    start = load<std::uintptr_t>(object, offset);
    end = load<std::uintptr_t>(object, offset + 8);
    const auto capacity = load<std::uintptr_t>(object, offset + 16);
    return end >= start && capacity >= end && (end - start) % stride == 0 && (end - start) / stride <= 4096 &&
        (start == end || mapped(start, end - start));
}
bool modelVector(void *manager, std::size_t offset, std::size_t size, std::uintptr_t vtable, std::vector<void *> &out) {
    std::uintptr_t start = 0, end = 0;
    if (!vectorRange(manager, offset, 8, start, end) || start == end) return false;
    for (auto address = start; address < end; address += 8) {
        auto *model = load<void *>(reinterpret_cast<void *>(address), 0);
        if (!objectIs(model, size, vtable)) return false;
        out.push_back(model);
    }
    return true;
}
void *findID(const std::vector<void *> &objects, std::size_t offset, std::int32_t id) {
    void *found = nullptr;
    for (auto *object : objects) if (load<std::int32_t>(object, offset) == id) {
        if (found) return nullptr;
        found = object;
    }
    return found;
}
struct Backend {
    void *callback, *argument;
    void *user = nullptr, *spots = nullptr, *recipeStore = nullptr, *director = nullptr;
    void *events = nullptr, *spot = nullptr;
    std::int32_t spotID = 0, recipeID = 0;
    bool prepare() {
        const auto &p = activeProfile().hunt;
        if (![NSThread isMainThread] || starting || status() != Status::ready ||
            !objectIs(callback, 16, p.callbackVtable)) return false;
        auto *popup = load<void *>(callback, 8);
        if (!objectIs(popup, 1384, p.popupVtable)) return false;
        spotID = load<std::int32_t>(popup, 1312);
        user = singleton(p.userSlot, 328, p.userVtable);
        spots = singleton(p.spotsSlot, 712, p.spotsVtable);
        events = singleton(p.eventsSlot, 808, p.eventsVtable);
        director = singleton(p.directorSlot, 512, p.directorVtable);
        if (spotID <= 0 || !user || !spots || !events || !director || load<std::int32_t>(user, 152) <= 0) return false;

        if (!reinterpret_cast<bool (*)()>(base() + p.tutorialReady)() ||
            reinterpret_cast<bool (*)(int)>(base() + p.tutorialPending)(13) ||
            reinterpret_cast<bool (*)(int)>(base() + p.tutorialPending)(14)) return false;
        std::vector<void *> spotModels;
        if (!modelVector(spots, 688, p.spotSize, p.spotVtable, spotModels)) return false;
        spot = findID(spotModels, 8, spotID);
        return spot != nullptr;
    }
    bool prepareRecipe() {
        const auto &p = activeProfile().hunt;
        auto *recipes = singleton(p.recipesSlot, 64, p.recipesVtable);
        std::vector<void *> eventModels, recipeModels;
        if (!recipes || !modelVector(events, 760, 32, p.eventVtable, eventModels) ||
            !modelVector(recipes, 32, p.recipeSize, p.recipeVtable, recipeModels)) return false;
        auto *event = findID(eventModels, 8, load<std::int32_t>(spot, p.rareEventOffset));
        if (!event) return false;
        recipeID = load<std::int32_t>(event, 12);
        if (recipeID <= 0 || !findID(recipeModels, 8, recipeID)) return false;
        recipeStore = load<void *>(recipes, 56);
        if (!objectIs(recipeStore, 80, p.storeVtable)) return false;
        std::uintptr_t start = 0, end = 0;
        return vectorRange(recipeStore, 56, 4, start, end);
    }
    bool largeEligible() {
        const auto &p = activeProfile().hunt;
        if (!largeHuntSupported()) return false;
        std::vector<void *> normalModels, largeModels;
        if (!modelVector(events, 688, 32, p.normalVtable, normalModels) ||
            !modelVector(events, 712, 32, p.largeVtable, largeModels)) return false;
        const auto eventID = load<std::int32_t>(spot, p.huntingEventOffset);
        auto *normal = findID(normalModels, 8, eventID);
        auto *large = findID(largeModels, 8, eventID);
        if (!normal || !large) return false;
        const auto target = load<std::int32_t>(normal, 16);
        const auto success = load<std::int32_t>(large, 20), ordinary = load<std::int32_t>(large, 24);
        const auto bonus = load<std::int32_t>(large, 28);
        return target > 0 && load<std::int32_t>(large, 16) == target && load<std::int32_t>(large, 12) > 0 &&
            success >= 0 && ordinary >= 0 && bonus >= 0 &&
            std::int64_t(success) + bonus <= INT32_MAX && std::int64_t(ordinary) + bonus <= INT32_MAX;
    }
    bool recipeUnlocked() { return reinterpret_cast<bool (*)(void *, int)>(base() + activeProfile().hunt.recipeUnlocked)(recipeStore, recipeID); }
    void original() { originalCallback(callback, argument); }
    void consumeEnergy() { reinterpret_cast<VoidFunction>(base() + activeProfile().hunt.consumeEnergy)(user); }
    void *createScene(int type) {
        auto *scene = reinterpret_cast<void *(*)(int, int)>(base() + activeProfile().hunt.createScene)(spotID, type);
        if (!scene) throw std::runtime_error("hunt scene creation failed");
        return scene;
    }
    void *createTransition(void *scene) {
        auto *transition = reinterpret_cast<void *(*)(void *, float)>(base() + activeProfile().hunt.createTransition)(scene, 2.5f);
        if (!transition) throw std::runtime_error("hunt transition creation failed");
        return transition;
    }
    void replaceScene(void *transition) { reinterpret_cast<void (*)(void *, void *)>(base() + activeProfile().hunt.replaceScene)(director, transition); }
    void recordSpot() { reinterpret_cast<void (*)(void *, int)>(base() + activeProfile().hunt.recordSpot)(user, spotID); }
    void recordMapPage() { reinterpret_cast<void (*)(void *, int)>(base() + activeProfile().hunt.recordMapPage)(spots, spotID); }
};
void callbackHook(void *callback, void *argument) {
    Backend backend{callback, argument};
    if (starting) { backend.original(); return; }
    const auto event = selectHuntEvent(backend, guaranteedHuntRecipe(), largeHunt());
    if (event < 0) {
        if (largeHunt()) NSLog(@"[HCHelper] Large hunt request used native fallback for map %d (tutorial, unavailable data, or incompatible mapping).", backend.spotID);
        backend.original();
        return;
    }
    NSLog(@"[HCHelper] Starting native hunt event %d for map %d", event, backend.spotID);
    starting = true;
    struct Guard { ~Guard() { starting = false; } } guard;
    try { startWithHuntEvent(backend, event); }
    catch (...) {
        enabled.store(false);
        largeEnabled.store(false);

        NSLog(@"[HCHelper] Forced hunt event %d failed; event switches disabled. Check the current scene and energy.", event);
    }
}
}
bool huntRecipeSupported() { return installed.load(); }
bool guaranteedHuntRecipe() { return enabled.load(); }
void setGuaranteedHuntRecipe(bool value) { enabled.store(value); }
bool largeHuntSupported() { return installed.load() && largeCompatible.load(); }
bool largeHunt() { return largeEnabled.load(); }
void setLargeHunt(bool value) { largeEnabled.store(value); }
void initializeHuntRecipe() {
    NSCAssert([NSThread isMainThread], @"HCHelper installs hunt recipe on the main thread");
    if (installing || status() != Status::ready) return;
    installing = true;
    Access access;
    if (!huntRecipeSample::validate(access, activeProfile().hunt)) return;
    largeCompatible.store(huntRecipeSample::validateLarge(access, activeProfile().hunt));
    originalCallback = reinterpret_cast<Callback>(access.address(activeProfile().hunt.callback));
    auto expected = reinterpret_cast<std::uintptr_t>(originalCallback);
    const bool ok = __atomic_compare_exchange_n(reinterpret_cast<std::uintptr_t *>(access.address(activeProfile().hunt.callbackSlot)),
        &expected, reinterpret_cast<std::uintptr_t>(callbackHook), false, __ATOMIC_SEQ_CST, __ATOMIC_SEQ_CST);
    installed.store(ok);
    NSLog(@"[HCHelper] Hunt event callback installed: %d, large event compatible: %d", ok, largeCompatible.load());
}
}
