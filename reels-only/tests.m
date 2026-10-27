#import <Foundation/Foundation.h>
#define RB_TESTING 1
#import "ReelsBlocker.m"

@interface Surface : NSObject
@property NSString *name;
- (id)tabStringFromSurfaceIntent;
@end
@implementation Surface
- (id)tabStringFromSurfaceIntent { return self.name; }
@end

@interface IGTabBarController : NSObject {
@public NSArray *_tabBarSurfaces;
}
@property NSUInteger layouts;
- (void)_layoutTabBar;
- (id)_buttonForTabBarSurface:(id)surface;
@end
@implementation IGTabBarController
- (void)_layoutTabBar { self.layouts++; }
- (id)_buttonForTabBarSurface:(id)surface { return surface; }
@end

@interface IGTabBarControllerSwipeCoordinator : NSObject
@property NSArray *surfaces;
- (id)initWithSurfaces:(id)surfaces parentViewController:(id)controller
        enableHaptics:(BOOL)haptics launcherSet:(id)set;
@end
@implementation IGTabBarControllerSwipeCoordinator
- (id)initWithSurfaces:(id)surfaces parentViewController:(id)controller
        enableHaptics:(BOOL)haptics launcherSet:(id)set {
    if ((self = [super init])) self.surfaces = surfaces;
    return self;
}
@end

@interface IGFeedScrollableClipsModel : NSObject @end
@implementation IGFeedScrollableClipsModel @end
@interface IGMainFeedListAdapterDataSource : NSObject
- (NSArray *)objectsForListAdapter:(id)adapter;
@end
@implementation IGMainFeedListAdapterDataSource
- (NSArray *)objectsForListAdapter:(id)adapter { return adapter; }
@end
@interface IGSundialFeedDataSource : IGMainFeedListAdapterDataSource @end
@implementation IGSundialFeedDataSource @end

@interface NormalScrollView : NSObject
@property BOOL scrollEnabled;
@property NSUInteger moves;
- (void)didMoveToWindow;
@end
@implementation NormalScrollView
- (void)didMoveToWindow { self.moves++; }
@end
@interface IGUnifiedVideoCollectionView : NormalScrollView @end
@implementation IGUnifiedVideoCollectionView @end
@interface _TtC19IGSundialAutoScroll19IGSundialAutoScroll : NSObject
@property BOOL isEnabled;
@end
@implementation _TtC19IGSundialAutoScroll19IGSundialAutoScroll @end

@interface IGSundialFeedViewController : NSObject {
@public id _refreshControl;
}
@property NSUInteger requests;
@property id finished;
- (void)_refreshReelsWithParamsForNetworkRequest:(NSInteger)reason userDidPullToRefresh:(BOOL)pulled;
- (void)refreshControlDidEndFinishLoadingAnimation:(id)control;
@end
@implementation IGSundialFeedViewController
- (void)_refreshReelsWithParamsForNetworkRequest:(NSInteger)reason userDidPullToRefresh:(BOOL)pulled { self.requests++; }
- (void)refreshControlDidEndFinishLoadingAnimation:(id)control { self.finished = control; }
@end

int main(void) {
    @autoreleasepool {
        // Missing methods and mismatched signatures are left untouched.
        IMP missing = NULL, mismatch = NULL;
        RBHook("DoesNotExist", "missing", (IMP)RBLayout, &missing, "v", @[]);
        RBHook("NormalScrollView", "setScrollEnabled:", (IMP)RBScroll, &mismatch, "@", @[@(@encode(BOOL))]);
        NSCAssert(!missing && !mismatch, @"Invalid hooks must be skipped");
        RBInstall();
        IMP previous = originalScroll;
        RBInstall();
        NSCAssert(originalScroll == previous, @"Hooks must be idempotent");
        NSCAssert(originalLayout && originalSurfaces && originalButton && originalFeed &&
                  originalReels && originalMove && originalScroll && originalAutoScroll && originalRefresh,
                  @"Every expected hook must install");

        Surface *feed = [Surface new]; feed.name = @"FEED";
        Surface *reels = [Surface new]; reels.name = @"CLIPS";
        Surface *messages = [Surface new]; messages.name = @"DIRECT";
        Surface *profile = [Surface new]; profile.name = @"PROFILE";
        NSObject *unknown = [NSObject new];
        NSArray *surfaces = @[feed, reels, messages, unknown, profile];
        NSArray *expected = @[feed, messages, unknown, profile];
        NSCAssert([RBFilterSurfaces(surfaces) isEqual:expected], @"Only Reels tab is removed");
        NSCAssert(!RBFilterSurfaces(nil) && [RBFilterSurfaces(@"unexpected") isEqual:@"unexpected"], @"Nonarrays pass through");
        IGTabBarController *tabs = [IGTabBarController new];
        tabs->_tabBarSurfaces = surfaces;
        [tabs _layoutTabBar]; [tabs _layoutTabBar];
        NSCAssert([tabs->_tabBarSurfaces isEqual:expected] && tabs.layouts == 2, @"Tab layout preserves other entries");
        NSCAssert(![tabs _buttonForTabBarSurface:reels] && [tabs _buttonForTabBarSurface:messages] == messages, @"Only Reels button is hidden");
        IGTabBarControllerSwipeCoordinator *coordinator = [[IGTabBarControllerSwipeCoordinator alloc]
            initWithSurfaces:surfaces parentViewController:nil enableHaptics:YES launcherSet:nil];
        NSCAssert([coordinator.surfaces isEqual:expected], @"Swipe list must match tab list");

        NSObject *story = [NSObject new], *post = [NSObject new];
        NSArray *items = @[story, [IGFeedScrollableClipsModel new], post];
        NSCAssert(([[[IGMainFeedListAdapterDataSource new] objectsForListAdapter:items] isEqual:@[story,post]]), @"Stories and posts survive");
        NSCAssert([[[IGSundialFeedDataSource new] objectsForListAdapter:items] count] == 0, @"Reels list is empty");
        IGUnifiedVideoCollectionView *viewer = [IGUnifiedVideoCollectionView new];
        viewer.scrollEnabled = YES;
        [viewer didMoveToWindow];
        viewer.scrollEnabled = YES; // Scrubbing must not re-enable vertical scrolling.
        NSCAssert(!viewer.scrollEnabled && viewer.moves == 1, @"Reels cannot resume scrolling");
        NormalScrollView *normal = [NormalScrollView new]; normal.scrollEnabled = YES;
        NSCAssert(normal.scrollEnabled, @"Other scroll views must remain untouched");
        _TtC19IGSundialAutoScroll19IGSundialAutoScroll *autoScroll = [_TtC19IGSundialAutoScroll19IGSundialAutoScroll new];
        autoScroll.isEnabled = YES;
        NSCAssert(!autoScroll.isEnabled, @"No Reels auto-scroll");
        IGSundialFeedViewController *controller = [IGSundialFeedViewController new];
        controller->_refreshControl = [NSObject new];
        [controller _refreshReelsWithParamsForNetworkRequest:1 userDidPullToRefresh:YES];
        NSCAssert(!controller.requests && controller.finished == controller->_refreshControl, @"Do not refresh Reels; finish indicator");
        puts("PASS: nine hooks; tab/swipe filtering, non-Reels preservation, empty Reels, scrolling, refresh, signature guards and idempotence");
    }
    return 0;
}
