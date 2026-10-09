#import <UIKit/UIKit.h>
#include "Localization.hpp"
#include "Runtime.hpp"
#include "Editor.hpp"
#include "EditorUI.hpp"
#include "Cooking.hpp"
#include "HuntRecipe.hpp"
#include "HuntPoints.hpp"

static NSString *const HCIgnoreKey = @"HCHelper.IgnoreTraps";
static NSString *const HCFreezeKey = @"HCHelper.FreezeTimer";
static NSString *const HCLuckyKey = @"HCHelper.LuckyCooking";
static NSString *const HCHuntRecipeKey = @"HCHelper.GuaranteedHuntRecipe";
static NSString *const HCLargeKey = @"HCHelper.LargeHunt";
static NSString *const HCFreezePointsKey = @"HCHelper.FreezeHuntPoints";

@interface HCPassthroughWindow : UIWindow
@end
@implementation HCPassthroughWindow
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    if (self.rootViewController.presentedViewController) return [super hitTest:point withEvent:event];
    UIView *root = self.rootViewController.view;
    UIView *hit = [root hitTest:[root convertPoint:point fromView:self] withEvent:event];
    return hit == root ? nil : hit;
}
@end

@interface HCOverlayController : UIViewController
@property(nonatomic, strong) UIButton *bubble;
@property(nonatomic, strong) UIScrollView *panel;
@property(nonatomic, strong) UISwitch *ignoreSwitch;
@property(nonatomic, strong) UISwitch *freezeSwitch;
@property(nonatomic, strong) UISwitch *luckySwitch;
@property(nonatomic, strong) UISwitch *huntRecipeSwitch;
@property(nonatomic, strong) UISwitch *largeSwitch;
@property(nonatomic, strong) UISwitch *pointsSwitch;
@property(nonatomic, strong) UILabel *statusLabel;
@property(nonatomic, strong) UIButton *editorButton;
@property(nonatomic) CGPoint relativeCenter;
@end

@implementation HCOverlayController
- (void)loadView {
    self.view = [[UIView alloc] init];
    self.view.backgroundColor = UIColor.clearColor;
    self.view.opaque = NO;
    self.relativeCenter = CGPointMake(0.05, 0.16);
    self.bubble = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.bubble setTitle:@"HC" forState:UIControlStateNormal];
    [self.bubble setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    self.bubble.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    self.bubble.backgroundColor = [UIColor colorWithRed:0.18 green:0.40 blue:0.26 alpha:0.94];
    self.bubble.layer.cornerRadius = 23;
    self.bubble.accessibilityLabel = HCText(@"HCHelper Settings", @"HCHelper 設定");
    [self.bubble addTarget:self action:@selector(togglePanel) forControlEvents:UIControlEventTouchUpInside];
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(drag:)];
    [self.bubble addGestureRecognizer:pan];
    [self.view addSubview:self.bubble];

    self.panel = [[UIScrollView alloc] init];
    self.panel.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    self.panel.clipsToBounds = YES;
    self.panel.backgroundColor = [UIColor colorWithWhite:0.10 alpha:0.96];
    self.panel.layer.cornerRadius = 14;
    self.panel.hidden = YES;
    [self.view addSubview:self.panel];
    UILabel *title = [self label:@"HCHelper" frame:CGRectMake(16, 10, 200, 25)];
    title.font = [UIFont boldSystemFontOfSize:17];
    [self label:HCText(@"Ignore Traps", @"罠を無効化") frame:CGRectMake(16, 45, 140, 32)];
    [self label:HCText(@"Freeze Timer", @"残り時間を固定") frame:CGRectMake(16, 88, 140, 32)];
    [self label:HCText(@"Lucky Cooking", @"料理で必ずラッキー") frame:CGRectMake(16, 131, 170, 32)];
    [self label:HCText(@"Guaranteed Recipe", @"未解禁レシピを優先") frame:CGRectMake(16, 174, 170, 32)];
    [self label:HCText(@"Large Hunt Event", @"大型の獲物を出現") frame:CGRectMake(16, 217, 170, 32)];
    [self label:HCText(@"Freeze Hunt Points", @"狩猟ポイントを固定") frame:CGRectMake(16, 260, 170, 32)];
    self.ignoreSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(192, 46, 51, 31)];
    self.freezeSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(192, 89, 51, 31)];
    self.luckySwitch = [[UISwitch alloc] initWithFrame:CGRectMake(192, 132, 51, 31)];
    self.huntRecipeSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(192, 175, 51, 31)];
    self.largeSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(192, 218, 51, 31)];
    self.pointsSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(192, 261, 51, 31)];
    self.ignoreSwitch.accessibilityLabel = HCText(@"Ignore Traps", @"罠を無効化");
    self.freezeSwitch.accessibilityLabel = HCText(@"Freeze Timer", @"残り時間を固定");
    self.luckySwitch.accessibilityLabel = HCText(@"Lucky Cooking", @"料理で必ずラッキー");
    self.huntRecipeSwitch.accessibilityLabel = HCText(@"Guarantee the locked special recipe for the selected hunt map", @"選択した狩猟マップの未解禁の特別レシピを必ず出現させる");
    self.largeSwitch.accessibilityLabel = HCText(@"Guarantee a large prey event when starting a hunt", @"狩猟開始時に大型の獲物のイベントを必ず出現させる");
    self.pointsSwitch.accessibilityLabel = HCText(@"Freeze the current hunt point balance", @"現在の狩猟ポイントを固定する");
    [self.ignoreSwitch addTarget:self action:@selector(ignoreChanged:) forControlEvents:UIControlEventValueChanged];
    [self.freezeSwitch addTarget:self action:@selector(freezeChanged:) forControlEvents:UIControlEventValueChanged];
    [self.luckySwitch addTarget:self action:@selector(luckyChanged:) forControlEvents:UIControlEventValueChanged];
    [self.huntRecipeSwitch addTarget:self action:@selector(huntRecipeChanged:) forControlEvents:UIControlEventValueChanged];
    [self.largeSwitch addTarget:self action:@selector(largeChanged:) forControlEvents:UIControlEventValueChanged];
    [self.pointsSwitch addTarget:self action:@selector(pointsChanged:) forControlEvents:UIControlEventValueChanged];
    [self.panel addSubview:self.ignoreSwitch];
    [self.panel addSubview:self.freezeSwitch];
    [self.panel addSubview:self.luckySwitch];
    [self.panel addSubview:self.huntRecipeSwitch];
    [self.panel addSubview:self.largeSwitch];
    [self.panel addSubview:self.pointsSwitch];
    self.statusLabel = [self label:@"" frame:CGRectMake(16, 303, 228, 28)];
    self.statusLabel.font = [UIFont systemFontOfSize:12];
    self.statusLabel.numberOfLines = 2;
    self.editorButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.editorButton.frame = CGRectMake(16, 338, 228, 32);
    [self.editorButton setTitle:HCText(@"Open Editor", @"編集画面を開く") forState:UIControlStateNormal];
    [self.editorButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    [self.editorButton addTarget:self action:@selector(openEditor) forControlEvents:UIControlEventTouchUpInside];
    [self.panel addSubview:self.editorButton];
    [self refresh];
}
- (UILabel *)label:(NSString *)text frame:(CGRect)frame {
    UILabel *label = [[UILabel alloc] initWithFrame:frame];
    label.text = text;
    label.textColor = UIColor.whiteColor;
    label.font = [UIFont systemFontOfSize:15];
    label.adjustsFontSizeToFitWidth = YES;
    label.minimumScaleFactor = 0.8;
    [self.panel addSubview:label];
    return label;
}
- (BOOL)shouldAutorotate { return YES; }
- (UIInterfaceOrientationMask)supportedInterfaceOrientations { return UIInterfaceOrientationMaskAll; }
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGRect safe = UIEdgeInsetsInsetRect(self.view.bounds, self.view.safeAreaInsets);
    CGFloat minX = CGRectGetMinX(safe) + 23, minY = CGRectGetMinY(safe) + 23;
    CGFloat width = MAX(0, CGRectGetWidth(safe) - 46), height = MAX(0, CGRectGetHeight(safe) - 46);
    self.bubble.bounds = CGRectMake(0, 0, 46, 46);
    self.bubble.center = CGPointMake(minX + width * self.relativeCenter.x, minY + height * self.relativeCenter.y);
    CGFloat panelWidth = MIN(320, CGRectGetWidth(safe));
    CGFloat panelHeight = MIN(382, CGRectGetHeight(safe));
    CGFloat x = MIN(MAX(CGRectGetMinX(self.bubble.frame), CGRectGetMinX(safe)), CGRectGetMaxX(safe) - panelWidth);
    CGFloat y = CGRectGetMaxY(self.bubble.frame) + 8;
    if (y + panelHeight > CGRectGetMaxY(safe)) y = CGRectGetMinY(self.bubble.frame) - panelHeight - 8;
    y = MAX(CGRectGetMinY(safe), MIN(y, CGRectGetMaxY(safe) - panelHeight));
    self.panel.frame = CGRectMake(x, y, panelWidth, panelHeight);
    self.panel.contentSize = CGSizeMake(panelWidth, 382);
    CGFloat switchX = MAX(0, panelWidth - 67);
    for (UISwitch *control in @[self.ignoreSwitch, self.freezeSwitch, self.luckySwitch,
                               self.huntRecipeSwitch, self.largeSwitch, self.pointsSwitch]) {
        CGRect frame = control.frame;
        frame.origin.x = switchX;
        control.frame = frame;
    }
    for (UIView *view in self.panel.subviews) {
        if (![view isKindOfClass:UILabel.class]) continue;
        CGRect frame = view.frame;
        frame.size.width = MAX(0, (frame.origin.y >= 45 && frame.origin.y < 303) ? switchX - 24 : panelWidth - 32);
        view.frame = frame;
    }
    self.editorButton.frame = CGRectMake(16, 338, MAX(0, panelWidth - 32), 32);
}
- (void)drag:(UIPanGestureRecognizer *)gesture {
    CGPoint delta = [gesture translationInView:self.view];
    CGPoint center = CGPointMake(self.bubble.center.x + delta.x, self.bubble.center.y + delta.y);
    CGRect safe = UIEdgeInsetsInsetRect(self.view.bounds, self.view.safeAreaInsets);
    self.relativeCenter = CGPointMake(
        MIN(1, MAX(0, (center.x - CGRectGetMinX(safe) - 23) / MAX(1, CGRectGetWidth(safe) - 46))),
        MIN(1, MAX(0, (center.y - CGRectGetMinY(safe) - 23) / MAX(1, CGRectGetHeight(safe) - 46))));
    [gesture setTranslation:CGPointZero inView:self.view];
    [self.view setNeedsLayout];
    [self.view layoutIfNeeded];
}
- (void)togglePanel { self.panel.hidden = !self.panel.hidden; [self refresh]; }
- (void)openEditor { if (hc::editorSupported()) HCPresentEditor(self); }
- (void)refresh {
    hc::refreshMenuLanguage();
    self.bubble.accessibilityLabel = HCText(@"HCHelper Settings", @"HCHelper 設定");
    NSArray<NSString *> *labels = @[
        HCText(@"Ignore Traps", @"罠を無効化"), HCText(@"Freeze Timer", @"残り時間を固定"),
        HCText(@"Lucky Cooking", @"料理で必ずラッキー"), HCText(@"Guaranteed Recipe", @"未解禁レシピを優先"),
        HCText(@"Large Hunt Event", @"大型の獲物を出現"), HCText(@"Freeze Hunt Points", @"狩猟ポイントを固定")];
    for (UIView *view in self.panel.subviews) {
        if (![view isKindOfClass:UILabel.class] || view == self.statusLabel) continue;
        const auto row = static_cast<NSInteger>((view.frame.origin.y - 45) / 43);
        if (view.frame.origin.y >= 45 && row >= 0 && row < static_cast<NSInteger>(labels.count))
            ((UILabel *)view).text = labels[row];
    }
    self.ignoreSwitch.accessibilityLabel = labels[0];
    self.freezeSwitch.accessibilityLabel = labels[1];
    self.luckySwitch.accessibilityLabel = labels[2];
    self.huntRecipeSwitch.accessibilityLabel = HCText(@"Guarantee the locked special recipe for the selected hunt map", @"選択した狩猟マップの未解禁の特別レシピを必ず出現させる");
    self.largeSwitch.accessibilityLabel = HCText(@"Guarantee a large prey event when starting a hunt", @"狩猟開始時に大型の獲物のイベントを必ず出現させる");
    self.pointsSwitch.accessibilityLabel = HCText(@"Freeze the current hunt point balance", @"現在の狩猟ポイントを固定する");
    const auto state = hc::status();
    const BOOL ready = state == hc::Status::ready;
    self.ignoreSwitch.enabled = ready;
    self.freezeSwitch.enabled = ready;
    self.ignoreSwitch.on = ready && hc::ignoreTraps();
    self.freezeSwitch.on = ready && hc::freezeTimer();
    self.luckySwitch.enabled = ready && hc::cookingSupported();
    self.luckySwitch.on = self.luckySwitch.enabled && hc::luckyCooking();
    self.huntRecipeSwitch.enabled = ready && hc::huntRecipeSupported();
    self.huntRecipeSwitch.on = self.huntRecipeSwitch.enabled && hc::guaranteedHuntRecipe();
    self.largeSwitch.enabled = ready && hc::largeHuntSupported();
    self.largeSwitch.on = self.largeSwitch.enabled && hc::largeHunt();
    self.pointsSwitch.enabled = ready && hc::huntPointsSupported();
    self.pointsSwitch.on = self.pointsSwitch.enabled && hc::freezeHuntPoints();
    const BOOL editable = hc::editorSupported();
    self.editorButton.enabled = editable;
    self.editorButton.alpha = editable ? 1.0 : 0.4;
    [self.editorButton setTitle:ready && !editable ? HCText(@"Editor Unavailable", @"編集機能は利用不可") : HCText(@"Open Editor", @"編集画面を開く") forState:UIControlStateNormal];
    switch (state) {
        case hc::Status::ready:
            {
                NSMutableArray<NSString *> *unavailable = [NSMutableArray array];
                if (!hc::cookingSupported()) [unavailable addObject:HCText(@"Lucky Cooking", @"料理で必ずラッキー")];
                if (!hc::huntRecipeSupported()) [unavailable addObject:HCText(@"Recipes", @"レシピ")];
                if (!hc::largeHuntSupported()) [unavailable addObject:HCText(@"Large Hunt Events", @"大型の獲物")];
                if (!hc::huntPointsSupported()) [unavailable addObject:HCText(@"Hunt Points", @"狩猟ポイント")];
                self.statusLabel.text = unavailable.count ? [NSString stringWithFormat:HCText(@"Loaded - Unsupported: %@", @"読み込み済み・非対応：%@"), [unavailable componentsJoinedByString:@" / "]] : HCText(@"Loaded - All features available", @"読み込み済み・すべて利用可能");
            }
            break;
        case hc::Status::unsupported: self.statusLabel.text = HCText(@"Unsupported Game Version", @"このゲームバージョンには非対応"); break;
        case hc::Status::installFailed: self.statusLabel.text = HCText(@"Installation Failed - Restart the Game", @"導入失敗・ゲームを再起動してください"); break;
        case hc::Status::waiting: self.statusLabel.text = HCText(@"Waiting to Load", @"読み込み待ち"); break;
    }
}
- (void)ignoreChanged:(UISwitch *)sender {
    if (hc::status() != hc::Status::ready) return;
    hc::setIgnoreTraps(sender.on);
    [NSUserDefaults.standardUserDefaults setBool:sender.on forKey:HCIgnoreKey];
}
- (void)freezeChanged:(UISwitch *)sender {
    if (hc::status() != hc::Status::ready) return;
    hc::setFreezeTimer(sender.on);
    [NSUserDefaults.standardUserDefaults setBool:sender.on forKey:HCFreezeKey];
}
- (void)luckyChanged:(UISwitch *)sender {
    if (!hc::cookingSupported()) return;
    hc::setLuckyCooking(sender.on);
    [NSUserDefaults.standardUserDefaults setBool:sender.on forKey:HCLuckyKey];
}
- (void)huntRecipeChanged:(UISwitch *)sender {
    if (!hc::huntRecipeSupported()) return;
    hc::setGuaranteedHuntRecipe(sender.on);
    [NSUserDefaults.standardUserDefaults setBool:sender.on forKey:HCHuntRecipeKey];
}
- (void)largeChanged:(UISwitch *)sender {
    if (!hc::largeHuntSupported()) return;
    hc::setLargeHunt(sender.on);
    [NSUserDefaults.standardUserDefaults setBool:sender.on forKey:HCLargeKey];
}
- (void)pointsChanged:(UISwitch *)sender {
    if (!hc::huntPointsSupported()) return;
    hc::setFreezeHuntPoints(sender.on);
    [NSUserDefaults.standardUserDefaults setBool:sender.on forKey:HCFreezePointsKey];
}
@end

@interface HCOverlayManager : NSObject
@property(nonatomic, strong) HCPassthroughWindow *window;
- (void)start;
@end
@implementation HCOverlayManager
- (void)start {
    NSNotificationCenter *center = NSNotificationCenter.defaultCenter;
    [center addObserver:self selector:@selector(activate:) name:UIApplicationDidBecomeActiveNotification object:nil];
    [center addObserver:self selector:@selector(activate:) name:UISceneDidActivateNotification object:nil];
    [center addObserver:self selector:@selector(disconnect:) name:UISceneDidDisconnectNotification object:nil];
    [self show];
}
- (void)activate:(NSNotification *)notification { (void)notification; [self show]; }
- (void)disconnect:(NSNotification *)notification {
    if (self.window.windowScene == notification.object) {
        self.window.hidden = YES;
        self.window = nil;
        [self show];
    }
}
- (void)show {
    hc::refreshMenuLanguage();
    if (self.window) {
        [(HCOverlayController *)self.window.rootViewController refresh];
        return;
    }
    UIWindowScene *active = nil;
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if ([scene isKindOfClass:UIWindowScene.class] && scene.activationState == UISceneActivationStateForegroundActive) {
            active = (UIWindowScene *)scene;
            break;
        }
    }

    if (active) self.window = [[HCPassthroughWindow alloc] initWithWindowScene:active];
    else if (UIApplication.sharedApplication.applicationState == UIApplicationStateActive) {
        self.window = [[HCPassthroughWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    } else return;
    self.window.windowLevel = UIWindowLevelStatusBar + 1;
    self.window.backgroundColor = UIColor.clearColor;
    self.window.opaque = NO;
    self.window.rootViewController = [[HCOverlayController alloc] init];
    self.window.hidden = NO;
}
@end

__attribute__((constructor)) static void HCLoad() {
    dispatch_async(dispatch_get_main_queue(), ^{
        @autoreleasepool {
            NSNumber *largeDefault = [NSUserDefaults.standardUserDefaults objectForKey:@"HCHelper.HeaviestHunt"] ?: @YES;
            [NSUserDefaults.standardUserDefaults registerDefaults:@{HCIgnoreKey: @YES, HCFreezeKey: @YES, HCLuckyKey: @YES, HCHuntRecipeKey: @YES, HCLargeKey: largeDefault, HCFreezePointsKey: @YES}];
            hc::setIgnoreTraps([NSUserDefaults.standardUserDefaults boolForKey:HCIgnoreKey]);
            hc::setFreezeTimer([NSUserDefaults.standardUserDefaults boolForKey:HCFreezeKey]);
            hc::setLuckyCooking([NSUserDefaults.standardUserDefaults boolForKey:HCLuckyKey]);
            hc::setGuaranteedHuntRecipe([NSUserDefaults.standardUserDefaults boolForKey:HCHuntRecipeKey]);
            hc::setLargeHunt([NSUserDefaults.standardUserDefaults boolForKey:HCLargeKey]);
            hc::setFreezeHuntPoints([NSUserDefaults.standardUserDefaults boolForKey:HCFreezePointsKey]);
            hc::initialize();
            hc::initializeCooking();
            hc::initializeHuntRecipe();

            hc::initializeHuntPoints();
            hc::refreshMenuLanguage();
            static HCOverlayManager *manager;
            manager = [[HCOverlayManager alloc] init];
            [manager start];
        }
    });
}
