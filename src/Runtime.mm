#import <Foundation/Foundation.h>
#include <mach-o/dyld.h>
#include <mach/mach.h>
#include <mach/vm_map.h>
#include <atomic>
#include "Image.hpp"
#include "Runtime.hpp"
#include "Profiles.hpp"
#include "Localization.hpp"

namespace hc {
static std::atomic<bool> ignoreFlag{true}, freezeFlag{true};
static std::atomic<Status> currentStatus{Status::waiting};
static TimerFunction originalTimer;
static VoidFunction originalCollision, gameRetain, gameRelease;
static std::uintptr_t huntAddress, arenaAddress;

Status status() { return currentStatus.load(); }
void setIgnoreTraps(bool enabled) { ignoreFlag.store(enabled); }
void setFreezeTimer(bool enabled) { freezeFlag.store(enabled); }
bool ignoreTraps() { return ignoreFlag.load(); }
bool freezeTimer() { return freezeFlag.load(); }

static void timerHook(void *timer, float dt) {
    dispatchTimer(timer, dt, freezeTimer(), huntAddress, arenaAddress, originalTimer);
}
static void collisionHook(void *callback) {
    dispatchCollision(callback, ignoreTraps(), originalCollision, gameRetain, gameRelease);
}

static bool mapped(std::uintptr_t address, std::size_t length, vm_prot_t protection) {
    if (!length || length > UINTPTR_MAX - address) return false;
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
struct LoadedAccess {
    std::uintptr_t base;
    std::uintptr_t address(std::uintptr_t offset) const { return base + offset; }
    bool accessible(std::uintptr_t offset, std::size_t length, std::uint32_t protection) const {
        return offset <= UINTPTR_MAX - base && mapped(address(offset), length, protection);
    }
    bool equalBytes(std::uintptr_t offset, const void *bytes, std::size_t length) const {
        return std::memcmp(reinterpret_cast<const void *>(address(offset)), bytes, length) == 0;
    }
    std::uintptr_t pointer(std::uintptr_t offset) const {
        return load<std::uintptr_t>(reinterpret_cast<const void *>(address(offset)), 0);
    }
};

void refreshMenuLanguage() {
    if (![NSThread isMainThread] || japaneseMenu()) return;
    originalLanguageCode = 0;
    for (NSString *language in NSLocale.preferredLanguages) {
        if ([language hasPrefix:@"zh"]) { originalLanguageCode = [language containsString:@"Hant"] ? 1 : 20; break; }
        if ([language hasPrefix:@"ko"]) { originalLanguageCode = 8; break; }
        if ([language hasPrefix:@"en"]) break;
    }
    if (status() != Status::ready || !activeProfile().editor.languageGet) return;
    const auto *header = _dyld_get_image_header(0);
    LoadedAccess access{reinterpret_cast<std::uintptr_t>(header)};
    for (const auto &entry : activeProfile().editor.extraEntries) {
        if (entry.offset != activeProfile().editor.languageGet) continue;
        if (!access.accessible(entry.offset, entry.bytes.size(), VM_PROT_READ | VM_PROT_EXECUTE) ||
            !access.equalBytes(entry.offset, entry.bytes.data(), entry.bytes.size())) return;
        originalLanguageCode = reinterpret_cast<int (*)()>(access.address(entry.offset))();
        return;
    }
}

void initialize() {
    NSCAssert([NSThread isMainThread], @"HCHelper installs on the main thread");
    if (status() != Status::waiting) return;
    const auto *header = _dyld_get_image_header(0);
    const auto base = reinterpret_cast<std::uintptr_t>(header);
    Image image;
    LoadedAccess access{base};
    bool valid = header && mapped(base, 32, VM_PROT_READ);
    std::size_t commandSize = valid ? load<std::uint32_t>(header, 20) : 0;
    valid = valid && commandSize <= 65536 && mapped(base, 32 + commandSize, VM_PROT_READ) &&
            parseImage(header, 32 + commandSize, image);
    const auto *profile = valid ? findProfile(image.uuid) : nullptr;
    if (profile) loadedProfile = profile;
    valid = profile && validateSample(image, access, profile->core);
    if (!valid) {
        currentStatus.store(Status::unsupported);
        NSLog(@"[HCHelper] Unsupported executable, bytes, pointers, or mapping permissions; no writes made.");
        return;
    }
    NSLog(@"[HCHelper] Selected executable profile: %s", profile->name);
    originalTimer = reinterpret_cast<TimerFunction>(access.address(activeProfile().core.timerTrigger));
    originalCollision = reinterpret_cast<VoidFunction>(access.address(activeProfile().core.collisionInvoke));
    gameRetain = reinterpret_cast<VoidFunction>(access.address(activeProfile().core.retain));
    gameRelease = reinterpret_cast<VoidFunction>(access.address(activeProfile().core.release));
    huntAddress = access.address(activeProfile().core.huntingTick);
    arenaAddress = access.address(activeProfile().core.arenaTick);
    const auto result = installPair(
        reinterpret_cast<std::uintptr_t *>(access.address(activeProfile().core.timerSlot)),
        reinterpret_cast<std::uintptr_t>(originalTimer), reinterpret_cast<std::uintptr_t>(timerHook),
        reinterpret_cast<std::uintptr_t *>(access.address(activeProfile().core.collisionSlot)),
        reinterpret_cast<std::uintptr_t>(originalCollision), reinterpret_cast<std::uintptr_t>(collisionHook),
        [](std::uintptr_t *slot, std::uintptr_t expected, std::uintptr_t replacement) {
            return __atomic_compare_exchange_n(slot, &expected, replacement, false, __ATOMIC_SEQ_CST, __ATOMIC_SEQ_CST);
        });
    currentStatus.store(result == InstallResult::installed ? Status::ready : Status::installFailed);
    if (result != InstallResult::installed) {
        setIgnoreTraps(false);
        setFreezeTimer(false);
    }
    NSLog(@"[HCHelper] Callback installation result: %d", static_cast<int>(result));
}
}
