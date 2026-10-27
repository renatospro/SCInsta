// SPDX-License-Identifier: GPL-3.0-only
// Instagram 418.2.0 selectors identified by SoCuul/SCInsta.
// Only local Reels UI/data restrictions; no settings, networking or file access.
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <objc/message.h>
#if !RB_TESTING
#import <UIKit/UIKit.h>
#endif

static IMP originalLayout, originalButton, originalSurfaces, originalFeed;
static IMP originalMove, originalScroll, originalAutoScroll;
static IMP originalReels, originalRefresh;

static BOOL RBIsReelsSurface(id surface) {
    SEL selector = sel_registerName("tabStringFromSurfaceIntent");
    if (![surface respondsToSelector:selector]) return NO;
    id value = ((id (*)(id, SEL))objc_msgSend)(surface, selector);
    return [value isKindOfClass:NSString.class] && [value isEqualToString:@"CLIPS"];
}

static id RBFilterSurfaces(id value) {
    if (![value isKindOfClass:NSArray.class]) return value;
    NSMutableArray *result = [NSMutableArray array];
    for (id surface in value) {
        if (!RBIsReelsSurface(surface)) [result addObject:surface];
    }
    return [result copy];
}

// Preserve init-family ARC ownership when forwarding to Instagram's initializer.
typedef id (*RBInitFunction)(__attribute__((ns_consumed)) id, SEL, id, id, BOOL, id)
    __attribute__((ns_returns_retained));
static id RBSurfaces(__attribute__((ns_consumed)) id self, SEL command,
                    id surfaces, id controller, BOOL haptics, id launcher)
    __attribute__((ns_returns_retained));
static id RBSurfaces(__attribute__((ns_consumed)) id self, SEL command,
                    id surfaces, id controller, BOOL haptics, id launcher) {
    return ((RBInitFunction)originalSurfaces)(self, command, RBFilterSurfaces(surfaces),
                                             controller, haptics, launcher);
}

static void RBLayout(id self, SEL command) {
    Ivar ivar = class_getInstanceVariable(object_getClass(self), "_tabBarSurfaces");
    const char *type = ivar ? ivar_getTypeEncoding(ivar) : NULL;
    if (type && type[0] == '@') {
        id before = object_getIvar(self, ivar);
        id after = RBFilterSurfaces(before);
        if (after != before) object_setIvar(self, ivar, after);
    }
    ((void (*)(id, SEL))originalLayout)(self, command);
}

static id RBButton(id self, SEL command, id surface) {
    if (RBIsReelsSurface(surface)) return nil;
    return ((id (*)(id, SEL, id))originalButton)(self, command, surface);
}

static id RBFeed(id self, SEL command, id adapter) {
    id value = ((id (*)(id, SEL, id))originalFeed)(self, command, adapter);
    Class carousel = objc_getClass("IGFeedScrollableClipsModel");
    if (!carousel || ![value isKindOfClass:NSArray.class]) return value;
    NSMutableArray *result = [NSMutableArray array];
    for (id item in value) {
        if (![item isKindOfClass:carousel]) [result addObject:item];
    }
    return [result copy];
}

static id RBReels(id self, SEL command, id adapter) {
    // Empty only the Reels data source, including Reels opened from a DM.
    return @[];
}

static void RBScroll(id self, SEL command, BOOL enabled) {
    ((void (*)(id, SEL, BOOL))originalScroll)(self, command, NO);
}

static void RBMove(id self, SEL command) {
    ((void (*)(id, SEL))originalMove)(self, command);
    SEL setter = sel_registerName("setScrollEnabled:");
    if ([self respondsToSelector:setter]) {
        ((void (*)(id, SEL, BOOL))objc_msgSend)(self, setter, NO);
    }
}

static void RBAutoScroll(id self, SEL command, BOOL enabled) {
    ((void (*)(id, SEL, BOOL))originalAutoScroll)(self, command, NO);
}

static void RBRefresh(id self, SEL command, NSInteger reason, BOOL pulled) {
    // Do not request another page of Reels. End the existing refresh indicator.
    SEL finish = sel_registerName("refreshControlDidEndFinishLoadingAnimation:");
    Ivar ivar = class_getInstanceVariable(object_getClass(self), "_refreshControl");
    const char *type = ivar ? ivar_getTypeEncoding(ivar) : NULL;
    if ([self respondsToSelector:finish] && type && type[0] == '@') {
        ((void (*)(id, SEL, id))objc_msgSend)(self, finish, object_getIvar(self, ivar));
    }
}

static BOOL RBTypeMatches(char *actual, const char *expected) {
    BOOL matches = actual && strcmp(actual, expected) == 0;
    free(actual);
    return matches;
}

static void RBHook(const char *className, const char *selectorName, IMP replacement,
                   IMP *original, const char *result, NSArray<NSString *> *arguments) {
    if (*original) return; // A launch notification can retry missing classes safely.
    Class cls = objc_getClass(className);
    SEL selector = sel_registerName(selectorName);
    Method method = cls ? class_getInstanceMethod(cls, selector) : NULL;
    if (!method || method_getNumberOfArguments(method) != arguments.count + 2) return;
    if (!RBTypeMatches(method_copyReturnType(method), result)) return;
    for (NSUInteger i = 0; i < arguments.count; i++) {
        if (!RBTypeMatches(method_copyArgumentType(method, (unsigned)i + 2),
                           arguments[i].UTF8String)) return;
    }
    *original = method_getImplementation(method);
    // Add an override for inherited methods; never replace a superclass's method.
    if (!class_addMethod(cls, selector, replacement, method_getTypeEncoding(method))) {
        method_setImplementation(method, replacement);
    }
}

static void RBInstall(void) {
    RBHook("IGTabBarController", "_layoutTabBar", (IMP)RBLayout, &originalLayout, "v", @[]);
    RBHook("IGTabBarController", "_buttonForTabBarSurface:", (IMP)RBButton, &originalButton, "@", @[@"@"]);
    RBHook("IGTabBarControllerSwipeCoordinator", "initWithSurfaces:parentViewController:enableHaptics:launcherSet:",
           (IMP)RBSurfaces, &originalSurfaces, "@", @[@"@", @"@", @(@encode(BOOL)), @"@"]);
    RBHook("IGMainFeedListAdapterDataSource", "objectsForListAdapter:", (IMP)RBFeed, &originalFeed, "@", @[@"@"]);
    RBHook("IGSundialFeedDataSource", "objectsForListAdapter:", (IMP)RBReels, &originalReels, "@", @[@"@"]);
    RBHook("IGUnifiedVideoCollectionView", "didMoveToWindow", (IMP)RBMove, &originalMove, "v", @[]);
    RBHook("IGUnifiedVideoCollectionView", "setScrollEnabled:", (IMP)RBScroll, &originalScroll, "v", @[@(@encode(BOOL))]);
    RBHook("_TtC19IGSundialAutoScroll19IGSundialAutoScroll", "setIsEnabled:",
           (IMP)RBAutoScroll, &originalAutoScroll, "v", @[@(@encode(BOOL))]);
    RBHook("IGSundialFeedViewController", "_refreshReelsWithParamsForNetworkRequest:userDidPullToRefresh:",
           (IMP)RBRefresh, &originalRefresh, "v", @[@(@encode(NSInteger)), @(@encode(BOOL))]);
}

#if !RB_TESTING
__attribute__((constructor)) static void RBStart(void) {
    @autoreleasepool {
        if (![NSBundle.mainBundle.bundleIdentifier hasPrefix:@"com.burbn.instagram"]) return;
        RBInstall();
        [NSNotificationCenter.defaultCenter addObserverForName:UIApplicationDidFinishLaunchingNotification
            object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note) {
                RBInstall();
            }];
    }
}
#endif
