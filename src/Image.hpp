#pragma once
#include "Core.hpp"
#include <array>
#include <limits>

namespace hc {

struct Segment {
    std::uint64_t offset = 0, size = 0;
    std::uint32_t protection = 0;
};
struct Image {
    std::array<std::uint8_t, 16> uuid{};
    std::array<Segment, 32> segments{};
    std::size_t count = 0;
    bool contains(std::uint64_t offset, std::size_t length, std::uint32_t protection) const {
        for (std::size_t i = 0; i < count; ++i) {
            const auto &s = segments[i];
            if ((s.protection & protection) == protection && offset >= s.offset &&
                offset - s.offset <= s.size && length <= s.size - (offset - s.offset)) return true;
        }
        return false;
    }
};

inline bool parseImage(const void *header, std::size_t available, Image &out) {
    if (available < 32 || load<std::uint32_t>(header, 0) != 0xfeedfacf ||
        load<std::uint32_t>(header, 4) != 0x0100000c ||
        load<std::uint32_t>(header, 8) != 0 || load<std::uint32_t>(header, 12) != 2) return false;
    const auto commands = load<std::uint32_t>(header, 16);
    const auto bytes = load<std::uint32_t>(header, 20);
    if (bytes > 65536 || bytes > available - 32 || commands > bytes / 8) return false;
    Image parsed;
    bool haveUUID = false, haveText = false;
    std::size_t p = 32;
    const std::size_t end = 32 + bytes;
    for (std::uint32_t i = 0; i < commands; ++i) {
        if (end - p < 8) return false;
        const auto command = load<std::uint32_t>(header, p);
        const auto size = load<std::uint32_t>(header, p + 4);
        if (size < 8 || (size & 7) || size > end - p) return false;
        if (command == 0x1b) {
            if (size != 24 || haveUUID) return false;
            std::memcpy(parsed.uuid.data(), static_cast<const unsigned char *>(header) + p + 8, 16);
            haveUUID = true;
        } else if (command == 0x19) {
            if (size < 72) return false;
            const auto sections = load<std::uint32_t>(header, p + 64);
            if (sections > (size - 72) / 80) return false;
            const auto address = load<std::uint64_t>(header, p + 24);
            const auto length = load<std::uint64_t>(header, p + 32);
            const auto protection = load<std::uint32_t>(header, p + 60);
            const auto *name = static_cast<const unsigned char *>(header) + p + 8;
            if (std::memcmp(name, "__TEXT\0", 7) == 0) {
                if (haveText || address != sample::preferredBase || length < end || (protection & 5) != 5) return false;
                haveText = true;
            }
            if (protection) {
                if (address < sample::preferredBase || parsed.count == parsed.segments.size() ||
                    length > std::numeric_limits<std::uint64_t>::max() - address) return false;
                parsed.segments[parsed.count++] = {address - sample::preferredBase, length, protection};
            }
        }
        p += size;
    }
    if (p != end || !haveUUID || !haveText) return false;
    out = parsed;
    return true;
}



template<class Access>
bool validateSample(const Image &image, Access &access, const sample::Profile &profile = sample::original) {
    if (image.uuid != profile.uuid) return false;
    for (const auto &entry : profile.entries) {
        if (!image.contains(entry.offset, entry.bytes.size(), 5) ||
            !access.accessible(entry.offset, entry.bytes.size(), 5) ||
            !access.equalBytes(entry.offset, entry.bytes.data(), entry.bytes.size())) return false;
    }
    for (const auto slot : {profile.timerSlot, profile.collisionSlot}) {
        if ((slot & 7) || !image.contains(slot, 8, 3) || !access.accessible(slot, 8, 3)) return false;
    }
    return access.pointer(profile.timerSlot) == access.address(profile.timerTrigger) &&
           access.pointer(profile.collisionSlot) == access.address(profile.collisionInvoke);
}
}
