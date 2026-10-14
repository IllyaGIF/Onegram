#ifndef OG_DIALOG_LIST_DIFF_H
#define OG_DIALOG_LIST_DIFF_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>

static inline bool OGDialogListStableSubsequence(const size_t *positions, size_t count, bool *keep)
{
    if (count == 0)
        return true;
    if (positions == NULL || keep == NULL || count > SIZE_MAX / sizeof(size_t))
        return false;
    size_t *tails = (size_t *)malloc(count * sizeof(size_t));
    size_t *previous = (size_t *)malloc(count * sizeof(size_t));
    if (tails == NULL || previous == NULL)
    {
        free(tails);
        free(previous);
        return false;
    }
    size_t length = 0;
    for (size_t i = 0; i < count; i++)
    {
        keep[i] = false;
        size_t low = 0;
        size_t high = length;
        while (low < high)
        {
            size_t middle = low + (high - low) / 2;
            if (positions[tails[middle]] < positions[i])
                low = middle + 1;
            else
                high = middle;
        }
        previous[i] = low == 0 ? SIZE_MAX : tails[low - 1];
        tails[low] = i;
        if (low == length)
            length++;
    }
    for (size_t i = tails[length - 1]; i != SIZE_MAX; i = previous[i])
        keep[i] = true;
    free(previous);
    free(tails);
    return true;
}

#endif
