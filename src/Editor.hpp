#pragma once
#include <cstdint>
#include <string>
#include <vector>

namespace hc {
enum class Resource { experience, coin, diamond, redCow, trainingTicket, huntPoints, storehouseCapacity };
enum class EditResult { ok, unavailable, unsupported, invalidInput, changed, writeFailed, rollbackFailed };
inline constexpr std::int32_t resourceMaximum = 999999999;
inline constexpr std::int32_t foodMaximum = 999999;
inline constexpr std::int32_t huntPointsMaximum = 3;
inline constexpr std::int32_t storehousePageSize = 12;
inline constexpr std::int32_t storehouseCapacityMaximum = 1200;
inline constexpr std::int32_t resourceLimit(Resource resource) {
    return resource == Resource::huntPoints ? huntPointsMaximum :
        resource == Resource::storehouseCapacity ? storehouseCapacityMaximum : resourceMaximum;
}
inline constexpr std::int32_t resourceMinimum(Resource resource) {
    return resource == Resource::storehouseCapacity ? storehousePageSize : 0;
}
inline constexpr std::int32_t resourceStep(Resource resource) {
    return resource == Resource::storehouseCapacity ? storehousePageSize : 1;
}
inline bool validResourceQuantity(Resource resource, std::int32_t value) {
    return value >= resourceMinimum(resource) && value <= resourceLimit(resource) && value % resourceStep(resource) == 0;
}
inline bool storehouseLevelToCapacity(std::int32_t level, std::int32_t &capacity) {
    if (level < 0 || level >= storehouseCapacityMaximum / storehousePageSize) return false;
    capacity = (level + 1) * storehousePageSize;
    return true;
}
inline bool storehouseCapacityToLevel(std::int32_t capacity, std::int32_t &level) {
    if (!validResourceQuantity(Resource::storehouseCapacity, capacity)) return false;
    level = capacity / storehousePageSize - 1;
    return true;
}

inline bool parseQuantity(const char *text, std::int32_t maximum, std::int32_t &out) {
    if (!text || !*text || maximum < 0) return false;
    std::int32_t value = 0;
    for (const unsigned char *p = reinterpret_cast<const unsigned char *>(text); *p; ++p) {
        if (*p < '0' || *p > '9') return false;
        const int digit = *p - '0';
        if (value > maximum / 10 || (value == maximum / 10 && digit > maximum % 10)) return false;
        value = value * 10 + digit;
    }
    out = value;
    return true;
}


template<class Backend>
EditResult writeResource(Backend &backend, Resource resource, std::int32_t value, std::int32_t expected) {
    if (!validResourceQuantity(resource, value)) return EditResult::invalidInput;
    const auto old = backend.read(resource);
    if (old != expected) return EditResult::changed;

    if (value == old) return EditResult::ok;
    try {
        backend.write(resource, value);
        if (backend.read(resource) == value) return EditResult::ok;
    } catch (...) {                                                              }
    try {
        backend.write(resource, old);
        return backend.read(resource) == old ? EditResult::writeFailed : EditResult::rollbackFailed;
    } catch (...) { return EditResult::rollbackFailed; }
}

template<class Backend>
EditResult writeFood(Backend &backend, std::int32_t value, std::int32_t expected) {
    if (value < 0 || value > foodMaximum) return EditResult::invalidInput;
    if (backend.read() != expected) return EditResult::changed;
    if (value == expected) return EditResult::ok;
    try {
        backend.write(value);
        if (backend.read() == value) return EditResult::ok;
    } catch (...) {                                                           }
    try {
        backend.write(expected);
        return backend.read() == expected ? EditResult::writeFailed : EditResult::rollbackFailed;
    } catch (...) { return EditResult::rollbackFailed; }
}

struct FoodEntry { std::int32_t id, quantity; std::string name; };
enum class InventoryKind { ingredients, dishes };
inline bool inventoryContains(InventoryKind kind, std::int32_t id) {

    if (id <= 0) return false;
    switch (kind) {
        case InventoryKind::ingredients: return id < 1000;
        case InventoryKind::dishes: return id >= 1000;
    }
    return false;
}
enum class FoodBatchOperation { setOwned99, setAll99, setOwned198, setAll198 };
struct FoodBatchResult {
    EditResult result = EditResult::ok;
    std::size_t updated = 0, unchanged = 0, remaining = 0;
};



template<class Backend>
FoodBatchResult writeFoodBatch(Backend &backend, const std::vector<FoodEntry> &foods, FoodBatchOperation operation) {
    FoodBatchResult result;
    struct Change { std::int32_t id, quantity, expected; };
    std::vector<Change> changes;
    for (const auto &food : foods) {
        if (food.quantity < 0 || food.quantity > foodMaximum) {
            result.result = EditResult::invalidInput;
            return result;
        }
        std::int32_t target = food.quantity;
        switch (operation) {
            case FoodBatchOperation::setOwned99:
                if (food.quantity > 0) target = 99;
                break;
            case FoodBatchOperation::setAll99: target = 99; break;
            case FoodBatchOperation::setOwned198:
                if (food.quantity > 0) target = 198;
                break;
            case FoodBatchOperation::setAll198: target = 198; break;
            default: result.result = EditResult::invalidInput; return result;
        }
        if (target == food.quantity) ++result.unchanged;
        else changes.push_back({food.id, target, food.quantity});
    }
    result.remaining = changes.size();
    for (const auto &change : changes) {
        try { result.result = backend.edit(change.id, change.quantity, change.expected); }
        catch (...) { result.result = EditResult::writeFailed; }
        if (result.result != EditResult::ok) return result;
        ++result.updated;
        --result.remaining;
    }
    return result;
}

bool editorSupported();
EditResult readResource(Resource resource, std::int32_t &value);
EditResult editResource(Resource resource, std::int32_t value, std::int32_t expected);
EditResult listFoods(std::vector<FoodEntry> &out, InventoryKind kind = InventoryKind::ingredients);
EditResult readFood(std::int32_t id, std::int32_t &value, InventoryKind kind = InventoryKind::ingredients);
EditResult editFood(std::int32_t id, std::int32_t value, std::int32_t expected, InventoryKind kind = InventoryKind::ingredients);
FoodBatchResult editFoods(FoodBatchOperation operation, InventoryKind kind = InventoryKind::ingredients);
}
