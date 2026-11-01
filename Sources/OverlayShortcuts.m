// SPDX-License-Identifier: GPL-3.0-only
#import "OverlayShortcuts.h"

NSInteger MTShortcutForEvent(NSEvent *event) {
    if (event.type!=NSEventTypeKeyDown) return -1;
    NSEventModifierFlags flags=event.modifierFlags;
    // Only Command+caret opens the overlay and requests its mouse automatically.
    // The German ISO caret is a dead key, so characters are unreliable.
    if (!(flags&NSEventModifierFlagCommand)
        || (flags&(NSEventModifierFlagControl|NSEventModifierFlagOption|NSEventModifierFlagShift))
        || event.keyCode!=10) return -1;
    return MTShortcutPanel;
}
@implementation MTOverlayShortcuts {
    BOOL _registered[MTShortcutCount], _held[MTShortcutCount];
}
- (void)setEnabled:(BOOL)enabled {
    _enabled=enabled;
    if (!enabled) memset(_held,0,sizeof(_held));
}
- (void)setRegistered:(BOOL)registered shortcut:(MTOverlayShortcut)shortcut {
    if (shortcut<0 || shortcut>=MTShortcutCount) return;
    _registered[shortcut]=registered;
    if (!registered) _held[shortcut]=NO;
}
- (BOOL)ownsLocalEvent:(NSEvent *)event {
    NSInteger shortcut=MTShortcutForEvent(event);
    return _enabled && shortcut>=0 && event.keyCode==10 && !(event.modifierFlags&NSEventModifierFlagShift)
        && _registered[shortcut];
}
- (BOOL)nativeShortcut:(MTOverlayShortcut)shortcut pressed:(BOOL)pressed {
    if (shortcut<0 || shortcut>=MTShortcutCount || !_enabled || !_registered[shortcut]) return NO;
    if (!pressed) { _held[shortcut]=NO; return YES; }
    if (_held[shortcut]) return YES;
    _held[shortcut]=YES;
    if (self.handler) self.handler(shortcut);
    return YES;
}
@end
