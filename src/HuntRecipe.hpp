#pragma once
namespace hc {
bool huntRecipeSupported();
bool guaranteedHuntRecipe();
void setGuaranteedHuntRecipe(bool value);
void initializeHuntRecipe();
bool largeHuntSupported();
bool largeHunt();
void setLargeHunt(bool value);


template<class Backend> void startWithHuntEvent(Backend &backend, int event) {
    backend.consumeEnergy();
    auto scene = backend.createScene(event);
    auto transition = backend.createTransition(scene);
    backend.replaceScene(transition);
    backend.recordSpot();
    backend.recordMapPage();
}
template<class Backend> int selectHuntEvent(Backend &backend, bool recipe, bool large) {
    if (!recipe && !large) return -1;

    try {
        if (!backend.prepare()) return -1;
        if (recipe) {
            if (!backend.prepareRecipe()) return -1;
            if (!backend.recipeUnlocked()) return 5;
        }
        return large && backend.largeEligible() ? 4 : -1;
    } catch (...) { return -1; }
}
template<class Backend> void dispatchHuntRecipe(Backend &backend, bool enabled) {
    const auto event = selectHuntEvent(backend, enabled, false);
    if (event < 0) {
        backend.original();
        return;
    }
    startWithHuntEvent(backend, event);
}
}
