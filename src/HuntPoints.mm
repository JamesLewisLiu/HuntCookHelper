#import <Foundation/Foundation.h>
#include <mach-o/dyld.h>
#include <mach/mach.h>
#include <mach/vm_map.h>
#include <atomic>
#include "Core.hpp"
#include "Runtime.hpp"
#include "Profiles.hpp"
#include "HuntPoints.hpp"
#include "HuntPointsSample.hpp"

namespace hc {
namespace {
using Getter = std::int64_t (*)(void *);
using Setter = std::int64_t (*)(void *, std::int64_t);
std::atomic<bool> enabled{true}, installed{false};
bool installing = false;
Setter originalSetter = nullptr;
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
void *mainUser() {
    const auto slot = base() + activeProfile().editor.userSlot;
    if (!mapped(slot, 8)) return nullptr;
    auto *user = load<void *>(reinterpret_cast<void *>(slot), 0);
    if (!mapped(reinterpret_cast<std::uintptr_t>(user), huntPointsSample::userSize, VM_PROT_READ | VM_PROT_WRITE) ||
        load<std::uintptr_t>(user, 0) != base() + activeProfile().editor.userVtable ||
        load<std::int32_t>(user, huntPointsSample::initialized) != 1) return nullptr;
    return user;
}
std::int64_t setterHook(void *object, std::int64_t requested) {
    struct HookBackend {
        void *object;
        bool eligible() { return object && [NSThread isMainThread] && object == mainUser(); }
        std::int64_t read() {

            return reinterpret_cast<Getter>(base() + activeProfile().huntPoints.getter)(object);
        }
        std::int64_t original(std::int64_t value) { return originalSetter(object, value); }
    } backend{object};
    return dispatchHuntPointsWrite(backend, enabled.load(), requested);
}
struct Backend {
    void *object;
    std::int32_t read(Resource) {
        return static_cast<std::int32_t>(reinterpret_cast<Getter>(base() + activeProfile().huntPoints.getter)(object));
    }
    void write(Resource, std::int32_t value) {

        originalSetter(object, value);
    }
};
}
bool huntPointsSupported() {
    if (status() != Status::ready || !installed.load()) return false;
    Access access;
    return huntPointsSample::validate(access, reinterpret_cast<std::uintptr_t>(setterHook), activeProfile().huntPoints);
}
bool freezeHuntPoints() { return enabled.load(); }
void setFreezeHuntPoints(bool value) { enabled.store(value); }
void initializeHuntPoints() {
    NSCAssert([NSThread isMainThread], @"HCHelper installs hunt points on the main thread");
    if (installing || status() != Status::ready) return;
    installing = true;
    Access access;
    if (!huntPointsSample::validate(access, access.address(activeProfile().huntPoints.setter), activeProfile().huntPoints)) return;
    originalSetter = reinterpret_cast<Setter>(access.address(activeProfile().huntPoints.setter));
    auto expected = reinterpret_cast<std::uintptr_t>(originalSetter);
    const bool ok = __atomic_compare_exchange_n(reinterpret_cast<std::uintptr_t *>(access.address(activeProfile().huntPoints.setterSlot)),
        &expected, reinterpret_cast<std::uintptr_t>(setterHook), false, __ATOMIC_SEQ_CST, __ATOMIC_SEQ_CST);
    installed.store(ok);
    NSLog(@"[HCHelper] Hunt points setter installed: %d", ok);
}
EditResult readHuntPoints(std::int32_t &value) {
    if (![NSThread isMainThread]) return EditResult::unavailable;
    if (!huntPointsSupported()) return EditResult::unsupported;
    auto *object = mainUser();
    if (!object) return EditResult::unavailable;
    try {
        value = Backend{object}.read(Resource::huntPoints);
        return value >= 0 && value <= huntPointsMaximum ? EditResult::ok : EditResult::unsupported;
    } catch (...) { return EditResult::writeFailed; }
}
EditResult editHuntPoints(std::int32_t value, std::int32_t expected) {
    if (value < 0 || value > huntPointsMaximum) return EditResult::invalidInput;
    if (![NSThread isMainThread]) return EditResult::unavailable;
    if (!huntPointsSupported()) return EditResult::unsupported;
    auto *object = mainUser();
    if (!object) return EditResult::unavailable;
    Backend backend{object};
    try { return writeResource(backend, Resource::huntPoints, value, expected); }
    catch (...) { return EditResult::writeFailed; }
}
}
