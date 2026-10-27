#import <Foundation/Foundation.h>
#define RB_TESTING 1
#import "ReelsBlocker.m"

#if RB_NEW_API
#define IGMainStoryTrayDataSource _TtC25IGMainStoryTrayDataSource25IGMainStoryTrayDataSource
#define IGSundialFeedDataSource _TtC23IGSundialFeedDataSource23IGSundialFeedDataSource
#define IGInFeedStoriesTrayModel _TtC15IGInFeedStories24IGInFeedStoriesTrayModel
#endif

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
@interface IGStoryDataController : NSObject @end
@implementation IGStoryDataController @end
@interface IGInFeedStoriesTrayModel : NSObject @end
@implementation IGInFeedStoriesTrayModel @end
@interface IGMedia : NSObject @end
@implementation IGMedia @end
@interface IGPostCreationManager : NSObject @end
@implementation IGPostCreationManager @end
@interface IGMainStoryTrayDataSource : NSObject
- (instancetype)initWithUserSession:(id)session;
@end
@implementation IGMainStoryTrayDataSource
- (instancetype)initWithUserSession:(id)session { return [super init]; }
@end
@interface IGMainFeedListAdapterDataSource : NSObject
- (NSArray *)objectsForListAdapter:(id)adapter;
@end
@implementation IGMainFeedListAdapterDataSource
- (NSArray *)objectsForListAdapter:(id)adapter { return adapter; }
@end
@interface IGSundialFeedDataSource : IGMainFeedListAdapterDataSource @end
@implementation IGSundialFeedDataSource @end

@interface NormalScrollView : NSObject
@property (getter=isScrollEnabled) BOOL scrollEnabled;
@property NSUInteger moves;
- (void)didMoveToWindow;
@end
@implementation NormalScrollView
- (void)didMoveToWindow { self.moves++; }
@end
@interface IGUnifiedVideoCollectionView : NormalScrollView @end
@implementation IGUnifiedVideoCollectionView @end
@interface _TtC19IGSundialAutoScroll19IGSundialAutoScroll : NSObject
#if RB_NEW_API
@property (setter=setUserEnabled:) BOOL isEnabled;
#else
@property BOOL isEnabled;
#endif
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
        NSString *suite = [@"local.reelsblocker.tests." stringByAppendingString:NSUUID.UUID.UUIDString];
        RBPreferenceStore = [[NSUserDefaults alloc] initWithSuiteName:suite];
        RBRegisterDefaults();
        NSCAssert(RBEnabled(RBScrollKey) && !RBEnabled(RBFeedKey) && !RBEnabled(RBStoriesKey), @"Defaults preserve feed and stories");
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
                  originalStoryTray && originalMove && originalScroll && originalAutoScroll &&
                  originalScrollStatus && originalAutoStatus,
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

        NSObject *story = [IGStoryDataController new], *post = [IGMedia new];
        NSArray *items = @[story, [IGFeedScrollableClipsModel new], post];
        NSCAssert(([[[IGMainFeedListAdapterDataSource new] objectsForListAdapter:items] isEqual:@[story,post]]), @"Stories and posts survive");
        NSArray *selectedReels = @[[NSObject new], [NSObject new], [NSObject new]];
        IGSundialFeedDataSource *reelData = [IGSundialFeedDataSource new];
        NSCAssert([reelData objectsForListAdapter:selectedReels] == selectedReels, @"Preserve selected Reel, its ordering and native playback data");
        NSObject *creation = [IGPostCreationManager new], *suggestedStory = [IGInFeedStoriesTrayModel new];
        NSArray *homeItems = @[story, post, suggestedStory, creation, [NSObject new]];
        IGMainFeedListAdapterDataSource *home = [IGMainFeedListAdapterDataSource new];
        [RBDefaults() setBool:YES forKey:RBFeedKey];
        NSCAssert(([[home objectsForListAdapter:homeItems] isEqual:@[story,suggestedStory,creation]]), @"Hide home feed but preserve stories and creation entry");
        [RBDefaults() setBool:YES forKey:RBStoriesKey];
        NSCAssert(([[home objectsForListAdapter:homeItems] isEqual:@[creation]]), @"Both home restrictions are independent of creation");
        NSCAssert(![[IGMainStoryTrayDataSource alloc] initWithUserSession:nil], @"Hidden story tray is not created");
        NSCAssert([reelData objectsForListAdapter:selectedReels] == selectedReels, @"Home restrictions never delete the chosen Reel");
        [RBDefaults() setBool:NO forKey:RBFeedKey];
        NSCAssert([[home objectsForListAdapter:homeItems] count] == 3, @"Stories can be hidden while posts remain");
        [RBDefaults() setBool:NO forKey:RBStoriesKey];
        NSCAssert([[IGMainStoryTrayDataSource alloc] initWithUserSession:nil] != nil, @"Story tray returns when enabled");
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
        NSCAssert(controller.requests == 1 && !controller.finished, @"Native Reel loading and refresh remain untouched");
        [RBDefaults() setBool:NO forKey:RBScrollKey];
        NSCAssert(RBFilterSurfaces(surfaces) == surfaces, @"Disabling Reels restriction preserves tab surfaces");
        NSCAssert([tabs _buttonForTabBarSurface:reels] == reels, @"Reels button returns when unlocked");
        viewer.scrollEnabled = YES; [viewer didMoveToWindow]; autoScroll.isEnabled = YES;
        NSCAssert(viewer.scrollEnabled && autoScroll.isEnabled, @"Unlock restores Instagram's scrolling decisions");
        viewer.scrollEnabled = NO;
        NSCAssert(!viewer.scrollEnabled, @"Unlock must not force scrolling on when Instagram disables it");
        NSCAssert([[home objectsForListAdapter:items] isEqual:items], @"All home items remain when restrictions are off");
        [RBPreferenceStore removePersistentDomainForName:suite];
        puts("PASS: ten hooks; direct Reel data preserved, scroll locking and unlocking, independent feed/story options, creation preservation, native refresh, signature guards and idempotence");
    }
    return 0;
}
