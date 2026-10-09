#import <Foundation/Foundation.h>
#include <mach-o/dyld.h>
#include <mach/mach.h>
#include <mach/vm_map.h>
#include <atomic>
#include <limits>
#include "Core.hpp"
#include "Cooking.hpp"
#include "CookingSample.hpp"
#include "Runtime.hpp"
#include "Profiles.hpp"

namespace hc {
namespace {
std::atomic<bool> enabled{true}, installed{false};
VoidFunction originalCollect;
bool installing = false;
thread_local bool collecting = false;
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
        const auto kr = vm_region_64(mach_task_self(), &region, &size, VM_REGION_BASIC_INFO_64,
            reinterpret_cast<vm_region_info_t>(&info), &count, &object);
        if (object != MACH_PORT_NULL) mach_port_deallocate(mach_task_self(), object);
        if (kr != KERN_SUCCESS || region > address || size > UINTPTR_MAX - region ||
            region + size <= address || (info.protection & protection) != protection) return false;
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
struct Backend {
    void *button, *item = nullptr, *model = nullptr, *food = nullptr;
    bool prepare() {
        const auto &p = activeProfile().cooking;
        if (![NSThread isMainThread] || collecting || !objectIs(button, 1440, p.buttonVtable) ||
            !load<std::uint8_t>(button, 1416)) return false;
        auto *stove = load<void *>(button, 400);
        if (!objectIs(stove, 1440, p.stoveVtable)) return false;
        item = load<void *>(stove, 1432);
        if (!objectIs(item, 80, p.itemVtable) || load<std::uint8_t>(item, 60)) return false;
        model = load<void *>(item, 72);
        if (model != load<void *>(button, 1432) || !objectIs(model, 88, p.modelVtable)) return false;
        food = load<void *>(model, 64);
        if (!objectIs(food, activeProfile().editor.foodSize, p.foodVtable)) return false;
        const auto quantity = reinterpret_cast<std::int32_t (*)(void *)>(base() + p.foodGet)(food);
        if (quantity < 0 || quantity > std::numeric_limits<std::int32_t>::max() - 2) return false;
        const auto director = load<std::uintptr_t>(reinterpret_cast<void *>(base() + p.directorSlot), 0);
        if (!mapped(director, 208) || !mapped(load<std::uintptr_t>(reinterpret_cast<void *>(director), 200), 16)) return false;
        return reinterpret_cast<bool (*)(void *)>(base() + p.modelReady)(model);
    }
    void original() { originalCollect(button); }
    void releaseButton() { reinterpret_cast<VoidFunction>(base() + activeProfile().cooking.buttonRelease)(button); }
    void playSound() { reinterpret_cast<void (*)(int)>(base() + activeProfile().cooking.playSound)(0); }
    bool collectNative() {
        return (reinterpret_cast<std::uintptr_t (*)(void *)>(base() + activeProfile().cooking.modelCollect)(model) & 1) != 0;
    }
    void addBonus() { reinterpret_cast<VoidFunction>(base() + activeProfile().cooking.foodIncrement)(food); }
    void completeItem() {
        store<void *>(item, 72, nullptr);
        store<std::uint8_t>(item, 60, 1);
    }
    void notify(const CookingEventName &name) {
        const auto director = load<void *>(reinterpret_cast<void *>(base() + activeProfile().cooking.directorSlot), 0);
        auto *dispatcher = load<void *>(director, 200);
        reinterpret_cast<void (*)(void *, const void *, void *)>(base() + activeProfile().cooking.dispatchEvent)(dispatcher, &name, item);
    }
    void notifyLucky() { notify(CookingEventName{"NotifSatisfyingCooking"}); }
    void notifyCollected() { notify(CookingEventName{"NotifGetCooking"}); }
};
void collectHook(void *button) {
    Backend backend{button};


    struct Guard { ~Guard() { collecting = false; } };
    if (collecting || !luckyCooking()) { backend.original(); return; }
    try {
        if (!backend.prepare()) { backend.original(); return; }
        collecting = true;
        Guard guard;
        collectWithLuck(backend);
    } catch (...) {

        enabled.store(false);
        NSLog(@"[HCHelper] Cooking collection threw; luck disabled. Check the current inventory.");
    }
}
}
bool cookingSupported() { return installed.load(); }
bool luckyCooking() { return enabled.load(); }
void setLuckyCooking(bool value) { enabled.store(value); }
void initializeCooking() {
    NSCAssert([NSThread isMainThread], @"HCHelper installs cooking on the main thread");
    if (installing || status() != Status::ready) return;
    installing = true;
    Access access;
    if (!cookingSample::validate(access, activeProfile().cooking)) return;
    originalCollect = reinterpret_cast<VoidFunction>(access.address(activeProfile().cooking.buttonCollect));
    auto expected = reinterpret_cast<std::uintptr_t>(originalCollect);
    const bool ok = __atomic_compare_exchange_n(reinterpret_cast<std::uintptr_t *>(access.address(activeProfile().cooking.buttonSlot)),
        &expected, reinterpret_cast<std::uintptr_t>(collectHook), false, __ATOMIC_SEQ_CST, __ATOMIC_SEQ_CST);
    installed.store(ok);
    NSLog(@"[HCHelper] Cooking callback installed: %d", ok);
}
}
