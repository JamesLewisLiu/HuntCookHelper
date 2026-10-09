#import <Foundation/Foundation.h>
#include <mach-o/dyld.h>
#include <mach/mach.h>
#include <mach/vm_map.h>
#include "Core.hpp"
#include "EditorSample.hpp"
#include "Runtime.hpp"
#include "Profiles.hpp"
#include "Localization.hpp"
#include "Achievement.hpp"
#include "AchievementSample.hpp"
#include "HuntPoints.hpp"

namespace hc {
namespace {
using Getter = std::int32_t (*)(void *);
using Setter = void (*)(void *, std::int64_t);
using FoodSetter = void (*)(void *, std::int32_t);

bool readable(std::uintptr_t address, std::size_t length, vm_prot_t protection = VM_PROT_READ) {
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
        if (result != KERN_SUCCESS || region > address || size > UINTPTR_MAX - region ||
            region + size <= address || (info.protection & protection) != protection) return false;
        address = region + size;
    }
    return true;
}
std::uintptr_t base() { return reinterpret_cast<std::uintptr_t>(_dyld_get_image_header(0)); }
struct EditorAccess {
    std::uintptr_t address(std::uintptr_t offset) const { return base() + offset; }
    bool accessible(std::uintptr_t offset, std::size_t size, std::uint32_t protection) const {
        return offset <= UINTPTR_MAX - base() && readable(address(offset), size, protection);
    }
    bool equalBytes(std::uintptr_t offset, const void *bytes, std::size_t size) const {
        return std::memcmp(reinterpret_cast<void *>(address(offset)), bytes, size) == 0;
    }
    std::uintptr_t pointer(std::uintptr_t offset) const {
        return load<std::uintptr_t>(reinterpret_cast<void *>(address(offset)), 0);
    }
};
const editorSample::Field *fieldFor(Resource resource) {
    for (const auto &field : activeProfile().editor.fields) if (field.resource == resource) return &field;
    return nullptr;
}
std::uintptr_t singleton(std::uintptr_t offset, std::size_t size) {
    const auto slot = base() + offset;
    if (!readable(slot, 8)) return 0;
    const auto pointer = load<std::uintptr_t>(reinterpret_cast<void *>(slot), 0);
    return readable(pointer, size, VM_PROT_READ | VM_PROT_WRITE) ? pointer : 0;
}
EditResult user(void *&object) {
    if (![NSThread isMainThread]) return EditResult::unavailable;
    if (!editorSupported()) return EditResult::unsupported;
    const auto pointer = singleton(activeProfile().editor.userSlot, 328);
    if (!pointer) return EditResult::unavailable;
    object = reinterpret_cast<void *>(pointer);
    return load<std::uintptr_t>(object, 0) == base() + activeProfile().editor.userVtable
        ? EditResult::ok : EditResult::unsupported;
}
struct UserBackend {
    void *object;
    std::int32_t read(Resource resource) {
        const auto native = reinterpret_cast<Getter>(base() + fieldFor(resource)->getter)(object);
        if (resource != Resource::storehouseCapacity) return native;
        std::int32_t capacity = -1;
        return storehouseLevelToCapacity(native, capacity) ? capacity : -1;
    }
    void write(Resource resource, std::int32_t value) {
        auto native = value;
        if (resource == Resource::storehouseCapacity && !storehouseCapacityToLevel(value, native)) return;
        reinterpret_cast<Setter>(base() + fieldFor(resource)->setter)(object, native);
    }
};
EditResult foodObjects(std::vector<void *> &out, InventoryKind kind) {
    if (kind != InventoryKind::ingredients && kind != InventoryKind::dishes) return EditResult::invalidInput;
    void *userObject = nullptr;
    const auto ready = user(userObject);
    if (ready != EditResult::ok) return ready;
    const auto manager = singleton(activeProfile().editor.foodsSlot, 96);
    if (!manager) return EditResult::unavailable;
    const auto *object = reinterpret_cast<void *>(manager);
    const auto start = load<std::uintptr_t>(object, 48), end = load<std::uintptr_t>(object, 56);
    const auto capacity = load<std::uintptr_t>(object, 64);
    if (end < start || capacity < end || (end - start) % 8 || (end - start) / 8 > 1024)
        return EditResult::unsupported;
    if (end == start) return EditResult::unavailable;
    if (!readable(start, end - start)) return EditResult::unsupported;
    for (auto address = start; address < end; address += 8) {
        const auto pointer = load<std::uintptr_t>(reinterpret_cast<void *>(address), 0);
        if (!readable(pointer, activeProfile().editor.foodSize, VM_PROT_READ | VM_PROT_WRITE)) return EditResult::unsupported;
        auto *food = reinterpret_cast<void *>(pointer);
        if (load<std::uintptr_t>(food, 0) != base() + activeProfile().editor.foodVtable) return EditResult::unsupported;
        const auto id = load<std::int32_t>(food, 56);
        if (inventoryContains(kind, id)) out.push_back(food);
    }
    return EditResult::ok;
}
void *foodFor(const std::vector<void *> &objects, std::int32_t id) {
    for (auto *object : objects) if (load<std::int32_t>(object, 56) == id) return object;
    return nullptr;
}
std::string foodName(void *object) {


    const auto *storage = static_cast<unsigned char *>(object) + catalogNameOffset();
    const auto tag = load<std::uint8_t>(storage, 23);
    const auto length = (tag & 0x80) ? load<std::uint64_t>(storage, 8) : tag;
    const auto address = (tag & 0x80) ? load<std::uintptr_t>(storage, 0) : reinterpret_cast<std::uintptr_t>(storage);
    if (!length || length > 512 || (!(tag & 0x80) && length > 22) || !readable(address, length)) return {};
    std::string name(reinterpret_cast<const char *>(address), static_cast<std::size_t>(length));

    for (const unsigned char character : name)
        if (character < 0x20 || character == 0x7f || (menuLanguage() == MenuLanguage::english && character >= 0x80)) return {};
    if (![[NSString alloc] initWithBytes:name.data() length:name.size() encoding:NSUTF8StringEncoding]) return {};
    return name;
}
struct FoodBackend {
    void *object;
    std::int32_t read() {

        store<std::int32_t>(object, activeProfile().editor.foodCache, -9999);
        return reinterpret_cast<Getter>(base() + activeProfile().editor.foodGet)(object);
    }
    void write(std::int32_t value) {
        reinterpret_cast<FoodSetter>(base() + activeProfile().editor.foodSet)(object, value);
    }
};

struct AchievementBackend {
    void *object;
    std::int32_t read() {
        store<std::int32_t>(object, activeProfile().achievement.progressCache, -1);
        return reinterpret_cast<Getter>(base() + activeProfile().achievement.get)(object);
    }
    void write(std::int32_t value) {

        reinterpret_cast<void (*)(void *, void *, std::int32_t)>(base() + activeProfile().achievement.set)(
            object, static_cast<unsigned char *>(object) + activeProfile().achievement.keyOffset, value);
    }
};
bool achievementKey(void *object, std::string &key) {
    const auto *storage = static_cast<unsigned char *>(object) + activeProfile().achievement.keyOffset;
    const auto tag = load<std::uint8_t>(storage, 23);
    const auto length = (tag & 0x80) ? load<std::uint64_t>(storage, 8) : tag;
    const auto pointer = (tag & 0x80) ? load<std::uintptr_t>(storage, 0) : reinterpret_cast<std::uintptr_t>(storage);
    if (!length || length > 64 || (!(tag & 0x80) && length > 22) || !readable(pointer, length)) return false;
    key.assign(reinterpret_cast<const char *>(pointer), length);

    for (const unsigned char c : key)
        if (!((c >= 'a' && c <= 'z') || (c >= '0' && c <= '9') || c == '_')) return false;
    return true;
}
bool achievementTargets(void *object, std::vector<std::int32_t> &targets) {
    const auto offset = activeProfile().achievement.targetsOffset;
    const auto start = load<std::uintptr_t>(object, offset), end = load<std::uintptr_t>(object, offset + 8);
    const auto capacity = load<std::uintptr_t>(object, offset + 16);
    if (end <= start || capacity < end || (end - start) % 16 || (end - start) / 16 > 128 ||
        !readable(start, end - start)) return false;
    for (auto address = start; address < end; address += 16) {
        const auto target = load<std::int32_t>(reinterpret_cast<void *>(address), 0);
        if (target <= 0 || target > achievementMaximum) return false;
        targets.push_back(target);
    }
    return true;
}
EditResult achievementObjects(std::vector<void *> &out, void *&managerObject) {
    void *userObject = nullptr;
    const auto ready = user(userObject);
    if (ready != EditResult::ok) return ready;
    EditorAccess access;
    if (!achievementSample::validate(access, activeProfile().achievement)) return EditResult::unsupported;
    const auto manager = singleton(activeProfile().achievement.managerSlot, 80);
    if (!manager) return EditResult::unavailable;
    managerObject = reinterpret_cast<void *>(manager);
    if (load<std::uintptr_t>(managerObject, 0) != base() + activeProfile().achievement.managerVtable)
        return EditResult::unsupported;
    const auto start = load<std::uintptr_t>(managerObject, 56), end = load<std::uintptr_t>(managerObject, 64);
    const auto capacity = load<std::uintptr_t>(managerObject, 72);
    if (end < start || capacity < end || (end - start) % 8 || (end - start) / 8 > 1024)
        return EditResult::unsupported;
    if (end == start) return EditResult::unavailable;
    if (!readable(start, end - start)) return EditResult::unsupported;
    std::vector<std::int32_t> ids;
    std::vector<std::string> keys;
    for (auto address = start; address < end; address += 8) {
        const auto pointer = load<std::uintptr_t>(reinterpret_cast<void *>(address), 0);
        if (!readable(pointer, activeProfile().achievement.dataSize, VM_PROT_READ | VM_PROT_WRITE)) return EditResult::unsupported;
        auto *object = reinterpret_cast<void *>(pointer);
        if (load<std::uintptr_t>(object, 0) != base() + activeProfile().achievement.dataVtable) return EditResult::unsupported;
        const auto id = load<std::int32_t>(object, 56);
        std::string key;
        std::vector<std::int32_t> targets;
        if (id < 0 || !achievementKey(object, key) || !achievementTargets(object, targets) ||
            std::find(ids.begin(), ids.end(), id) != ids.end() || std::find(keys.begin(), keys.end(), key) != keys.end())
            return EditResult::unsupported;
        ids.push_back(id); keys.push_back(key); out.push_back(object);
    }
    return EditResult::ok;
}
EditResult achievementEntry(void *object, AchievementEntry &entry) {
    AchievementEntry value;
    value.id = load<std::int32_t>(object, 56);
    value.name = foodName(object);
    if (!achievementKey(object, value.key) || !achievementTargets(object, value.targets)) return EditResult::unsupported;
    value.current = AchievementBackend{object}.read();
    store<std::int32_t>(object, activeProfile().achievement.claimedCache, -1);
    value.claimed = reinterpret_cast<Getter>(base() + activeProfile().achievement.claimedGet)(object);
    const auto last = reinterpret_cast<Getter>(base() + activeProfile().achievement.lastClaimedGet)(object);
    if (value.current < 0 || value.current > achievementMaximum || value.claimed < 0 ||
        value.claimed > static_cast<std::int32_t>(value.targets.size()) ||
        !achievementStage(last, value.targets.size(), value.targetIndex)) return EditResult::unsupported;
    entry = std::move(value);
    return EditResult::ok;
}
}

bool editorSupported() {
    if (status() != Status::ready) return false;
    EditorAccess access;
    return editorSample::validate(access, activeProfile().editor);
}
EditResult readResource(Resource resource, std::int32_t &value) {
    if (resource == Resource::huntPoints) return readHuntPoints(value);
    if (!fieldFor(resource)) return EditResult::invalidInput;
    void *object = nullptr;
    const auto ready = user(object);
    if (ready != EditResult::ok) return ready;
    try {
        value = UserBackend{object}.read(resource);
        return resource == Resource::storehouseCapacity && value < 0 ? EditResult::unsupported : EditResult::ok;
    }
    catch (...) { return EditResult::writeFailed; }
}
EditResult editResource(Resource resource, std::int32_t value, std::int32_t expected) {
    if (resource == Resource::huntPoints) return editHuntPoints(value, expected);
    if (!fieldFor(resource) || !validResourceQuantity(resource, value)) return EditResult::invalidInput;
    void *object = nullptr;
    const auto ready = user(object);
    if (ready != EditResult::ok) return ready;
    UserBackend backend{object};
    try { return writeResource(backend, resource, value, expected); }
    catch (...) { return EditResult::writeFailed; }
}
EditResult listFoods(std::vector<FoodEntry> &out, InventoryKind kind) {
    out.clear();
    std::vector<void *> objects;
    const auto ready = foodObjects(objects, kind);
    if (ready != EditResult::ok) return ready;
    try {
        for (auto *object : objects) {
            const auto quantity = FoodBackend{object}.read();
            out.push_back({load<std::int32_t>(object, 56), quantity, foodName(object)});
        }
        return EditResult::ok;
    } catch (...) { out.clear(); return EditResult::writeFailed; }
}
EditResult readFood(std::int32_t id, std::int32_t &value, InventoryKind kind) {
    if (!inventoryContains(kind, id)) return EditResult::invalidInput;
    std::vector<void *> objects;
    const auto ready = foodObjects(objects, kind);
    if (ready != EditResult::ok) return ready;
    auto *object = foodFor(objects, id);
    if (!object) return EditResult::unavailable;
    try { value = FoodBackend{object}.read(); return EditResult::ok; }
    catch (...) { return EditResult::writeFailed; }
}
EditResult editFood(std::int32_t id, std::int32_t value, std::int32_t expected, InventoryKind kind) {
    if (!inventoryContains(kind, id) || value < 0 || value > foodMaximum) return EditResult::invalidInput;
    std::vector<void *> objects;
    const auto ready = foodObjects(objects, kind);
    if (ready != EditResult::ok) return ready;
    auto *object = foodFor(objects, id);
    if (!object) return EditResult::unavailable;
    FoodBackend backend{object};
    try { return writeFood(backend, value, expected); }
    catch (...) { return EditResult::writeFailed; }
}
FoodBatchResult editFoods(FoodBatchOperation operation, InventoryKind kind) {
    std::vector<void *> objects;
    const auto ready = foodObjects(objects, kind);
    if (ready != EditResult::ok) return {ready, 0, 0, 0};
    std::vector<FoodEntry> foods;
    try {
        for (auto *object : objects)
            foods.push_back({load<std::int32_t>(object, 56), FoodBackend{object}.read(), {}});
    } catch (...) { return {EditResult::writeFailed, 0, 0, 0}; }
    struct Backend {
        const std::vector<void *> &objects;
        EditResult edit(std::int32_t id, std::int32_t value, std::int32_t expected) {
            auto *object = foodFor(objects, id);
            if (!object || !readable(reinterpret_cast<std::uintptr_t>(object), activeProfile().editor.foodSize, VM_PROT_READ | VM_PROT_WRITE))
                return EditResult::unavailable;
            if (load<std::uintptr_t>(object, 0) != base() + activeProfile().editor.foodVtable) return EditResult::unsupported;
            FoodBackend backend{object};
            return writeFood(backend, value, expected);
        }
    } backend{objects};
    return writeFoodBatch(backend, foods, operation);
}

EditResult listAchievements(std::vector<AchievementEntry> &out) {
    out.clear();
    try {
        std::vector<void *> objects;
        void *manager = nullptr;
        const auto ready = achievementObjects(objects, manager);
        if (ready != EditResult::ok) return ready;
        std::vector<AchievementEntry> entries;
        for (auto *object : objects) {
            AchievementEntry entry;
            const auto result = achievementEntry(object, entry);
            if (result != EditResult::ok) return result;
            entries.push_back(std::move(entry));
        }
        out = std::move(entries);
        return EditResult::ok;
    } catch (...) { return EditResult::writeFailed; }
}
EditResult readAchievement(std::int32_t id, AchievementEntry &out) {
    if (id < 0) return EditResult::invalidInput;
    try {
        std::vector<void *> objects;
        void *manager = nullptr;
        const auto ready = achievementObjects(objects, manager);
        if (ready != EditResult::ok) return ready;
        auto *object = foodFor(objects, id);
        return object ? achievementEntry(object, out) : EditResult::unavailable;
    } catch (...) { return EditResult::writeFailed; }
}
EditResult editAchievement(std::int32_t id, const std::string &key, std::int32_t value, std::int32_t expected) {
    if (id < 0 || value < 0 || value > achievementMaximum) return EditResult::invalidInput;
    try {
        std::vector<void *> objects;
        void *manager = nullptr;
        const auto ready = achievementObjects(objects, manager);
        if (ready != EditResult::ok) return ready;
        auto *object = foodFor(objects, id);
        if (!object) return EditResult::unavailable;
        AchievementEntry entry;
        const auto checked = achievementEntry(object, entry);
        if (checked != EditResult::ok) return checked;
        if (entry.key != key) return EditResult::changed;
        AchievementBackend backend{object};
        const auto result = writeAchievement(backend, value, expected);
        if (result == EditResult::changed || result == EditResult::invalidInput) return result;

        store<std::uint8_t>(object, activeProfile().achievement.eligibleOffset,
            reinterpret_cast<bool (*)(void *)>(base() + activeProfile().achievement.eligible)(object));
        reinterpret_cast<void (*)(void *)>(base() + activeProfile().achievement.refresh)(manager);
        return result;
    } catch (...) { return EditResult::writeFailed; }
}
}
