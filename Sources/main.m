#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>
#import <UserNotifications/UserNotifications.h>

@interface AppDelegate : NSObject <NSApplicationDelegate, WKScriptMessageHandler>
@property (strong, nonatomic) NSStatusItem *statusItem;
@property (strong, nonatomic) NSPopover *popover;
@property (strong, nonatomic) WKWebView *webView;

// 네이티브 애니메이션 & 타이머 상태
@property (strong, nonatomic) NSTimer *nativeAnimTimer;
@property (assign, nonatomic) double currentProgress; // 1.0 (정자세) ~ 0.0 (거북목)
@property (assign, nonatomic) BOOL isTimerActive;
@property (assign, nonatomic) NSTimeInterval totalTimerSeconds;
@property (assign, nonatomic) NSTimeInterval remainingSeconds;
@property (assign, nonatomic) NSTimeInterval idleElapsed;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];

    self.currentProgress = 1.0;
    self.isTimerActive = NO;
    self.idleElapsed = 0.0;
    self.totalTimerSeconds = 30 * 60;
    self.remainingSeconds = self.totalTimerSeconds;

    // 알림 권한
    UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
    [center requestAuthorizationWithOptions:(UNAuthorizationOptionAlert | UNAuthorizationOptionSound)
                          completionHandler:^(BOOL granted, NSError * _Nullable error) {}];

    // Status Item 설정
    self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSSquareStatusItemLength];
    NSStatusBarButton *button = self.statusItem.button;
    if (button) {
        button.target = self;
        button.action = @selector(togglePopover:);
    }

    // WKWebView 및 Popover
    WKUserContentController *userContentController = [[WKUserContentController alloc] init];
    [userContentController addScriptMessageHandler:self name:@"native"];

    WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];
    config.userContentController = userContentController;

    self.webView = [[WKWebView alloc] initWithFrame:NSMakeRect(0, 0, 320, 480) configuration:config];
    [self.webView setValue:@NO forKey:@"drawsBackground"];

    NSString *bundlePath = [[NSBundle mainBundle] resourcePath];
    NSString *htmlPath = [bundlePath stringByAppendingPathComponent:@"web/index.html"];
    if (![[NSFileManager defaultManager] fileExistsAtPath:htmlPath]) {
        NSString *cwd = [[NSFileManager defaultManager] currentDirectoryPath];
        htmlPath = [cwd stringByAppendingPathComponent:@"Sources/web/index.html"];
    }
    NSURL *fileURL = [NSURL fileURLWithPath:htmlPath];
    [self.webView loadFileURL:fileURL allowingReadAccessToURL:[fileURL URLByDeletingLastPathComponent]];

    self.popover = [[NSPopover alloc] init];
    self.popover.contentSize = NSMakeSize(320, 480);
    self.popover.behavior = NSPopoverBehaviorTransient;
    
    NSViewController *vc = [[NSViewController alloc] init];
    vc.view = self.webView;
    self.popover.contentViewController = vc;

    // 네이티브 상단바 애니메이션 타이머 시작 (초당 25회 갱신: 팝오버 닫혀있어도 항상 동작!)
    [self startNativeAnimationLoop];
}

- (void)startNativeAnimationLoop {
    [self.nativeAnimTimer invalidate];
    // 0.04초(25fps) 주기로 실행하여 부드럽고 전력 효율적인 상단바 애니메이션
    self.nativeAnimTimer = [NSTimer scheduledTimerWithTimeInterval:0.04
                                                            target:self
                                                          selector:@selector(onNativeAnimTick)
                                                          userInfo:nil
                                                           repeats:YES];
    [[NSRunLoop currentRunLoop] addTimer:self.nativeAnimTimer forMode:NSRunLoopCommonModes];
}

- (void)onNativeAnimTick {
    if (self.isTimerActive) {
        // 타이머 동작 중: 시간 경과에 비례하여 거북목으로 서서히 변화
        if (self.totalTimerSeconds > 0) {
            self.currentProgress = MAX(0.0, MIN(1.0, self.remainingSeconds / self.totalTimerSeconds));
        }
    } else {
        // 타이머 꺼짐 (루프 모드): 8초 주기로 정자세(1.0) <-> 거북목(0.0) 오감
        self.idleElapsed += 0.04;
        double angle = (self.idleElapsed / 8.0) * 2.0 * M_PI;
        self.currentProgress = (cos(angle) + 1.0) / 2.0; // 1.0 -> 0.0 -> 1.0
    }

    [self drawMenuBarIcon];
}

- (void)drawMenuBarIcon {
    double p = self.currentProgress; // 1.0 = 바른 자세, 0.0 = 거북목
    BOOL timerActive = self.isTimerActive;

    NSImage *image = [NSImage imageWithSize:NSMakeSize(22, 22) flipped:NO drawingHandler:^BOOL(NSRect dstRect) {
        NSColor *color = [NSColor controlTextColor];
        if (timerActive) {
            if (p > 0.65) {
                color = [NSColor controlTextColor];
            } else if (p > 0.35) {
                color = [NSColor systemOrangeColor];
            } else {
                color = [NSColor systemRedColor];
            }
        }

        // 상단바 작은 22x22 아이콘에서 확실하게 보이도록 머리 오프셋을 5.5pt로 설정
        CGFloat forwardShift = (1.0 - p) * 5.5; 
        CGFloat downShift = (1.0 - p) * 1.5;
        CGFloat headRad = 3.6;
        CGFloat headCenterX = 8.5 + forwardShift;
        CGFloat headCenterY = 14.5 - downShift;

        // 1. 머리 실루엣
        NSBezierPath *head = [NSBezierPath bezierPathWithOvalInRect:NSMakeRect(headCenterX - headRad, headCenterY - headRad, headRad * 2, headRad * 2)];
        [color setFill];
        [head fill];

        // 2. 등 & 목 실루엣 (옆모습)
        NSBezierPath *body = [NSBezierPath bezierPath];
        // 뒤통수 아래 목 뒷선 시작
        [body moveToPoint:NSMakePoint(headCenterX - 2.8, headCenterY - 1.5)];

        // 등 곡선: 거북목일수록 등이 둥글게 굽음
        CGFloat backBend = (1.0 - p) * 3.5;
        [body curveToPoint:NSMakePoint(4.0, 2.5)
             controlPoint1:NSMakePoint(6.0 - backBend, 9.0)
             controlPoint2:NSMakePoint(4.0, 5.5)];

        // 몸통 바닥
        [body lineToPoint:NSMakePoint(15.0, 2.5)];

        // 가슴 -> 목 앞쪽선
        [body curveToPoint:NSMakePoint(headCenterX + 2.2, headCenterY - 2.0)
             controlPoint1:NSMakePoint(14.0, 6.5)
             controlPoint2:NSMakePoint(headCenterX + 2.0, 9.5)];

        [body closePath];
        [body fill];

        // 타이머 동작 시 미니 원형 프로그레스 링
        if (timerActive) {
            NSBezierPath *ringBg = [NSBezierPath bezierPathWithOvalInRect:NSMakeRect(1.0, 1.0, 20, 20)];
            [[color colorWithAlphaComponent:0.25] setStroke];
            ringBg.lineWidth = 1.2;
            [ringBg stroke];
        }

        return YES;
    }];

    [image setTemplate:!timerActive];
    self.statusItem.button.image = image;
}

- (void)togglePopover:(id)sender {
    NSStatusBarButton *button = self.statusItem.button;
    if (!button) return;

    if (self.popover.isShown) {
        [self.popover performClose:sender];
    } else {
        [self.popover showRelativeToRect:button.bounds ofView:button preferredEdge:NSRectEdgeMinY];
        [NSApp activateIgnoringOtherApps:YES];
    }
}

#pragma mark - WKScriptMessageHandler
- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message {
    if (![message.body isKindOfClass:[NSDictionary class]]) return;
    NSDictionary *data = message.body;
    NSString *action = data[@"action"];

    if ([action isEqualToString:@"syncTimerState"]) {
        // 웹 UI에서 타이머 상태 변경 시 네이티브 동기화
        self.isTimerActive = [data[@"timerActive"] boolValue];
        self.totalTimerSeconds = [data[@"totalSeconds"] doubleValue];
        self.remainingSeconds = [data[@"remainingSeconds"] doubleValue];
        if (!self.isTimerActive) {
            self.idleElapsed = 0;
        }
    } else if ([action isEqualToString:@"resetPosture"]) {
        self.idleElapsed = 0;
        self.currentProgress = 1.0;
    } else if ([action isEqualToString:@"sendNotification"]) {
        NSString *title = data[@"title"] ?: @"⚠️ 거북목 주의!";
        NSString *body = data[@"body"] ?: @"턱을 당기고 가슴을 펴주세요.";
        [self sendSystemNotificationWithTitle:title body:body];
    } else if ([action isEqualToString:@"terminateApp"]) {
        [NSApp terminate:nil];
    }
}

- (void)sendSystemNotificationWithTitle:(NSString *)title body:(NSString *)body {
    UNMutableNotificationContent *content = [[UNMutableNotificationContent alloc] init];
    content.title = title;
    content.body = body;
    content.sound = [UNNotificationSound defaultSound];

    UNNotificationRequest *request = [UNNotificationRequest requestWithIdentifier:[[NSUUID UUID] UUIDString]
                                                                        content:content
                                                                        trigger:nil];
    [[UNUserNotificationCenter currentNotificationCenter] addNotificationRequest:request withCompletionHandler:nil];
}

@end

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSApplication *app = [NSApplication sharedApplication];
        AppDelegate *delegate = [[AppDelegate alloc] init];
        app.delegate = delegate;
        [app run];
    }
    return 0;
}
