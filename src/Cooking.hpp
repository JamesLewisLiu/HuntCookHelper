#pragma once
#include <cstddef>
#include <cstring>

namespace hc {

struct alignas(8) CookingEventName {
    unsigned char bytes[24]{};
    template<std::size_t N> explicit CookingEventName(const char (&name)[N]) {
        static_assert(N <= 23, "Game short string capacity exceeded");
        std::memcpy(bytes, name, N);
        bytes[23] = N - 1;
    }
};
void initializeCooking();
bool cookingSupported();
bool luckyCooking();
void setLuckyCooking(bool enabled);



template<class Backend>
void collectWithLuck(Backend &backend) {
    backend.releaseButton();
    backend.playSound();
    if (!backend.collectNative()) backend.addBonus();
    backend.completeItem();
    backend.notifyLucky();
    backend.notifyCollected();

}
template<class Backend>
void dispatchCooking(Backend &backend, bool enabled) {
    if (!enabled || !backend.prepare()) { backend.original(); return; }
    collectWithLuck(backend);
}
}
