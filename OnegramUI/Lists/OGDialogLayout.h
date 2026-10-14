#ifndef OG_DIALOG_LAYOUT_H
#define OG_DIALOG_LAYOUT_H

#include <math.h>
#include <stdbool.h>

typedef struct
{
    double width;
    double contentInset;
    double dateOrigin;
    double statusWidth;
    double badgeWidth;
    double mentionWidth;
    double verifiedWidth;
    double premiumWidth;
    double previewPadding;
    bool branded;
    bool encrypted;
    bool muted;
    bool unreadBadge;
    bool pinned;
    bool mention;
    bool deliveryError;
    bool deliveryStatus;
} OGDialogLayoutInput;

typedef struct
{
    double titleOrigin;
    double maximumTitleWidth;
    double rightPadding;
    double previewWidth;
    double authorWidth;
} OGDialogHorizontalLayout;

static inline OGDialogHorizontalLayout OGDialogHorizontalLayoutMake(OGDialogLayoutInput input)
{
    OGDialogHorizontalLayout layout;
    layout.rightPadding = input.branded ? input.previewPadding : ((input.unreadBadge || input.pinned) ? input.badgeWidth + 16.0 : 0.0);
    if (!input.branded && input.mention)
        layout.rightPadding += (input.unreadBadge || input.pinned) ? 24.0 : 40.0;
    if (input.deliveryError)
        layout.rightPadding += 36.0;
    layout.titleOrigin = input.contentInset + (input.encrypted ? 15.0 : 0.0);
    double width = input.branded ? input.width - input.contentInset - 8.0 : input.dateOrigin - input.contentInset - 4.0 - (input.deliveryStatus ? 20.0 : 0.0);
    if (input.branded && input.statusWidth > 0.0)
        width = fmax(34.0, width - input.statusWidth - 3.0);
    if (input.encrypted)
        width -= 15.0;
    if (input.muted)
        width -= 12.0;
    if (input.branded && input.unreadBadge)
        width -= input.badgeWidth + 6.0;
    if (input.branded && input.mention)
        width -= input.mentionWidth + 6.0;
    if (input.verifiedWidth > 0.0)
        width -= input.verifiedWidth + 10.0;
    else if (input.premiumWidth > 0.0)
        width -= input.premiumWidth + 10.0;
    layout.maximumTitleWidth = fmax(1.0, fmin(width, input.width - layout.titleOrigin - 75.0));
    layout.previewWidth = fmax(1.0, input.width - input.contentInset - 7.0 - layout.rightPadding);
    layout.authorWidth = fmax(1.0, input.width - input.contentInset - 4.0 - layout.rightPadding);
    return layout;
}

static inline double OGDialogTitleWidth(OGDialogHorizontalLayout layout, double measuredWidth)
{
    return fmax(1.0, fmin(layout.maximumTitleWidth, measuredWidth + 1.0));
}

#endif
