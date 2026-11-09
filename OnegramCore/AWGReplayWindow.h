#ifndef AWG_REPLAY_WINDOW_H
#define AWG_REPLAY_WINDOW_H
#include <stdint.h>
#include <string.h>
#define AWG_REPLAY_BITS 8192
#define AWG_REPLAY_WORDS (AWG_REPLAY_BITS / 64 + 1)
#define AWG_REJECT_AFTER_MESSAGES (UINT64_MAX - AWG_REPLAY_BITS - 1)
typedef struct {
    uint64_t highest;
    uint64_t bitmap[AWG_REPLAY_WORDS];
    int initialized;
} AWGReplayWindow;
static inline int AWGReplayAccepts(const AWGReplayWindow *window, uint64_t counter) {
    if (counter >= AWG_REJECT_AFTER_MESSAGES) return 0;
    if (!window->initialized || counter > window->highest) return 1;
    if (window->highest - counter >= AWG_REPLAY_BITS) return 0;
    return !(window->bitmap[(counter / 64) % AWG_REPLAY_WORDS] & (UINT64_C(1) << (counter % 64)));
}
static inline void AWGReplayMark(AWGReplayWindow *window, uint64_t counter) {
    if (!window->initialized || (counter > window->highest && counter - window->highest >= AWG_REPLAY_BITS)) {
        memset(window->bitmap, 0, sizeof(window->bitmap));
    } else if (counter > window->highest) {
        uint64_t first = window->highest / 64 + 1;
        uint64_t last = counter / 64;
        for (uint64_t word = first; word <= last; word++) window->bitmap[word % AWG_REPLAY_WORDS] = 0;
    }
    if (!window->initialized || counter > window->highest) window->highest = counter;
    window->initialized = 1;
    window->bitmap[(counter / 64) % AWG_REPLAY_WORDS] |= UINT64_C(1) << (counter % 64);
}
#endif
