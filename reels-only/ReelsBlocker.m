// SPDX-License-Identifier: GPL-3.0-only
// Private Instagram selectors originally identified by SoCuul/SCInsta.
// Local UI restrictions and preferences only; no networking or account access.
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <objc/message.h>
#if !RB_TESTING
#import <UIKit/UIKit.h>
#endif

static IMP originalLayout, originalButton, originalSurfaces, originalFeed;
static IMP originalMove, originalScroll, originalAutoScroll;
static IMP originalStoryTray;
static IMP originalScrollStatus, originalAutoStatus;

static NSString *const RBScrollKey = @"local.reelsblocker.blockScroll";
static NSString *const RBFeedKey = @"local.reelsblocker.hideHomeFeed";
static NSString *const RBStoriesKey = @"local.reelsblocker.hideHomeStories";
static NSUserDefaults *RBPreferenceStore;

static NSUserDefaults *RBDefaults(void) {
    return RBPreferenceStore ?: NSUserDefaults.standardUserDefaults;
}

static void RBRegisterDefaults(void) {
    [RBDefaults() registerDefaults:@{RBScrollKey:@YES, RBFeedKey:@NO, RBStoriesKey:@NO}];
}

static BOOL RBEnabled(NSString *key) { return [RBDefaults() boolForKey:key]; }

static Class RBClass(const char *name) {
    Class cls = objc_getClass(name);
    if (cls) return cls;
    // Names and signatures confirmed in the 451.0.0 Objective-C metadata.
    if (!strcmp(name, "IGMainStoryTrayDataSource")) return objc_getClass("_TtC25IGMainStoryTrayDataSource25IGMainStoryTrayDataSource");
    if (!strcmp(name, "IGSundialFeedDataSource")) return objc_getClass("_TtC23IGSundialFeedDataSource23IGSundialFeedDataSource");
    if (!strcmp(name, "IGInFeedStoriesTrayModel")) return objc_getClass("_TtC15IGInFeedStories24IGInFeedStoriesTrayModel");
    return Nil;
}

static BOOL RBIsKind(id object, const char *name) {
    Class cls = RBClass(name);
    return cls && [object isKindOfClass:cls];
}

static BOOL RBIsReelsSurface(id surface) {
    SEL selector = sel_registerName("tabStringFromSurfaceIntent");
    if (![surface respondsToSelector:selector]) return NO;
    id value = ((id (*)(id, SEL))objc_msgSend)(surface, selector);
    return [value isKindOfClass:NSString.class] && [value isEqualToString:@"CLIPS"];
}

static id RBFilterSurfaces(id value) {
    if (!RBEnabled(RBScrollKey)) return value;
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
    if (RBEnabled(RBScrollKey) && RBIsReelsSurface(surface)) return nil;
    return ((id (*)(id, SEL, id))originalButton)(self, command, surface);
}

static id RBFeed(id self, SEL command, id adapter) {
    id value = ((id (*)(id, SEL, id))originalFeed)(self, command, adapter);
    // Never remove the selected Reel or reorder its playback data source.
    if (RBIsKind(self, "IGSundialFeedDataSource") || ![value isKindOfClass:NSArray.class]) return value;
    NSMutableArray *result = [NSMutableArray array];
    for (id item in value) {
        BOOL stories = RBIsKind(item, "IGStoryDataController") || RBIsKind(item, "IGInFeedStoriesTrayModel");
        if (RBEnabled(RBStoriesKey) && stories) continue;
        if (RBEnabled(RBFeedKey) && !stories && !RBIsKind(item, "IGPostCreationManager")) continue;
        if (RBEnabled(RBScrollKey) && RBIsKind(item, "IGFeedScrollableClipsModel")) continue;
        [result addObject:item];
    }
    return [result copy];
}

typedef id (*RBStoryInitFunction)(__attribute__((ns_consumed)) id, SEL, id)
    __attribute__((ns_returns_retained));
static id RBStoryTray(__attribute__((ns_consumed)) id self, SEL command, id session)
    __attribute__((ns_returns_retained));
static id RBStoryTray(__attribute__((ns_consumed)) id self, SEL command, id session) {
    if (RBEnabled(RBStoriesKey)) return nil;
    return ((RBStoryInitFunction)originalStoryTray)(self, command, session);
}

static void RBScroll(id self, SEL command, BOOL enabled) {
    ((void (*)(id, SEL, BOOL))originalScroll)(self, command, RBEnabled(RBScrollKey) ? NO : enabled);
}

static void RBMove(id self, SEL command) {
    ((void (*)(id, SEL))originalMove)(self, command);
    SEL setter = sel_registerName("setScrollEnabled:");
    if (RBEnabled(RBScrollKey) && [self respondsToSelector:setter]) {
        ((void (*)(id, SEL, BOOL))objc_msgSend)(self, setter, NO);
    }
}

static void RBAutoScroll(id self, SEL command, BOOL enabled) {
    ((void (*)(id, SEL, BOOL))originalAutoScroll)(self, command, RBEnabled(RBScrollKey) ? NO : enabled);
}

static BOOL RBScrollStatus(id self, SEL command) {
    return RBEnabled(RBScrollKey) ? NO : ((BOOL (*)(id, SEL))originalScrollStatus)(self, command);
}

static BOOL RBAutoStatus(id self, SEL command) {
    return RBEnabled(RBScrollKey) ? NO : ((BOOL (*)(id, SEL))originalAutoStatus)(self, command);
}

static BOOL RBTypeMatches(char *actual, const char *expected) {
    BOOL matches = actual && strcmp(actual, expected) == 0;
    free(actual);
    return matches;
}

static void RBHook(const char *className, const char *selectorName, IMP replacement,
                   IMP *original, const char *result, NSArray<NSString *> *arguments) {
    if (*original) return; // A launch notification can retry missing classes safely.
    Class cls = RBClass(className);
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
    RBHook("IGMainStoryTrayDataSource", "initWithUserSession:", (IMP)RBStoryTray, &originalStoryTray, "@", @[@"@"]);
    RBHook("IGUnifiedVideoCollectionView", "didMoveToWindow", (IMP)RBMove, &originalMove, "v", @[]);
    RBHook("IGUnifiedVideoCollectionView", "setScrollEnabled:", (IMP)RBScroll, &originalScroll, "v", @[@(@encode(BOOL))]);
    RBHook("IGUnifiedVideoCollectionView", "isScrollEnabled", (IMP)RBScrollStatus, &originalScrollStatus, @encode(BOOL), @[]);
    RBHook("_TtC19IGSundialAutoScroll19IGSundialAutoScroll", "setIsEnabled:",
           (IMP)RBAutoScroll, &originalAutoScroll, "v", @[@(@encode(BOOL))]);
    RBHook("_TtC19IGSundialAutoScroll19IGSundialAutoScroll", "setUserEnabled:",
           (IMP)RBAutoScroll, &originalAutoScroll, "v", @[@(@encode(BOOL))]);
    RBHook("_TtC19IGSundialAutoScroll19IGSundialAutoScroll", "isEnabled",
           (IMP)RBAutoStatus, &originalAutoStatus, @encode(BOOL), @[]);
}

#if !RB_TESTING
#import "BlockerSettings.m"
__attribute__((constructor)) static void RBStart(void) {
    @autoreleasepool {
        if (![NSBundle.mainBundle.bundleIdentifier hasPrefix:@"com.burbn.instagram"]) return;
        RBRegisterDefaults();
        RBInstall();
        RBInstallSettings();
        [NSNotificationCenter.defaultCenter addObserverForName:UIApplicationDidFinishLaunchingNotification
            object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note) {
                RBInstall();
            }];
    }
}
#endif
