// SPDX-License-Identifier: GPL-3.0-only
// Included by ReelsBlocker.m. Apple UIKit only; preferences stay on this device.

@interface RBSettingsController : UITableViewController
@end

@implementation RBSettingsController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Bloqueos de Instagram";
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
        initWithTitle:@"Listo" style:UIBarButtonItemStyleDone target:self action:@selector(closeSettings)];
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 100;
}
- (void)closeSettings { [self dismissViewControllerAnimated:YES completion:nil]; }
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 3; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return 1; }
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return @[@"Reels", @"Inicio", @"Historias"][section];
}
- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == 0) return @"Puedes reproducir un Reel abierto desde un mensaje o perfil, incluidos tus propios videos. Se oculta la pestaña Reels y se bloquean el desplazamiento y el avance automático.";
    if (section == 1) return @"Oculta las publicaciones y recomendaciones del inicio. Puedes seguir entrando a perfiles y creando contenido.";
    return @"Oculta las bandejas de historias del inicio; no bloquea las historias abiertas desde un perfil. Para aplicar todos los cambios, cierra Instagram por completo y vuelve a abrirlo.\n\nAbre este menú manteniendo tres dedos sobre la pantalla durante un segundo.";
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    NSInteger section = indexPath.section;
    cell.textLabel.text = @[@"Bloquear scroll de Reels", @"Ocultar feed del inicio", @"Ocultar historias del inicio"][section];
    cell.textLabel.numberOfLines = 0;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    UISwitch *toggle = [UISwitch new];
    toggle.tag = section;
    toggle.on = RBEnabled(@[RBScrollKey, RBFeedKey, RBStoriesKey][section]);
    toggle.accessibilityLabel = cell.textLabel.text;
    [toggle addTarget:self action:@selector(optionChanged:) forControlEvents:UIControlEventValueChanged];
    cell.accessoryView = toggle;
    return cell;
}
- (void)optionChanged:(UISwitch *)toggle {
    [RBDefaults() setBool:toggle.on forKey:@[RBScrollKey, RBFeedKey, RBStoriesKey][toggle.tag]];
}
@end

@interface RBSettingsLauncher : NSObject <UIGestureRecognizerDelegate>
+ (instancetype)shared;
- (void)attachToWindow:(UIWindow *)window;
- (void)attachToActiveWindows;
@end

@implementation RBSettingsLauncher
+ (instancetype)shared {
    static RBSettingsLauncher *launcher;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ launcher = [RBSettingsLauncher new]; });
    return launcher;
}
- (void)attachToWindow:(UIWindow *)window {
    if (!window.isKeyWindow || !window.rootViewController || window.windowLevel != UIWindowLevelNormal) return;
    for (UIGestureRecognizer *gesture in window.gestureRecognizers) {
        if ([gesture.name isEqualToString:@"local.reelsblocker.settings"]) return;
    }
    UILongPressGestureRecognizer *gesture = [[UILongPressGestureRecognizer alloc]
        initWithTarget:self action:@selector(openSettings:)];
    gesture.name = @"local.reelsblocker.settings";
    gesture.numberOfTouchesRequired = 3;
    gesture.minimumPressDuration = 1.0;
    gesture.cancelsTouchesInView = NO;
    gesture.delegate = self;
    [window addGestureRecognizer:gesture];
}
- (void)attachToActiveWindows {
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:UIWindowScene.class]) continue;
        for (UIWindow *window in ((UIWindowScene *)scene).windows) [self attachToWindow:window];
    }
}
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer
    shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer { return YES; }
- (void)openSettings:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateBegan) return;
    UIViewController *controller = gesture.view.window.rootViewController;
    if ([gesture.view isKindOfClass:UIWindow.class]) controller = ((UIWindow *)gesture.view).rootViewController;
    while (controller) {
        if ([controller isKindOfClass:RBSettingsController.class]) return;
        if (controller.presentedViewController) { controller = controller.presentedViewController; continue; }
        if ([controller isKindOfClass:UINavigationController.class]) { controller = ((UINavigationController *)controller).visibleViewController; continue; }
        if ([controller isKindOfClass:UITabBarController.class]) { controller = ((UITabBarController *)controller).selectedViewController; continue; }
        break;
    }
    if (!controller.view.window || controller.isBeingDismissed || [controller isKindOfClass:UIAlertController.class]) return;
    RBSettingsController *settings = [[RBSettingsController alloc] initWithStyle:UITableViewStyleInsetGrouped];
    UINavigationController *navigation = [[UINavigationController alloc] initWithRootViewController:settings];
    [controller presentViewController:navigation animated:YES completion:nil];
}
@end

static void RBInstallSettings(void) {
    NSNotificationCenter *center = NSNotificationCenter.defaultCenter;
    [center addObserverForName:UIWindowDidBecomeKeyNotification object:nil queue:NSOperationQueue.mainQueue
        usingBlock:^(NSNotification *note) {
            if ([note.object isKindOfClass:UIWindow.class]) [[RBSettingsLauncher shared] attachToWindow:note.object];
        }];
    [center addObserverForName:UIApplicationDidBecomeActiveNotification object:nil queue:NSOperationQueue.mainQueue
        usingBlock:^(NSNotification *note) { [[RBSettingsLauncher shared] attachToActiveWindows]; }];
    dispatch_async(dispatch_get_main_queue(), ^{ [[RBSettingsLauncher shared] attachToActiveWindows]; });
}
