#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>
#import <UserNotifications/UserNotifications.h>

@interface AppDelegate : NSObject <NSApplicationDelegate, WKScriptMessageHandler>
@property (strong, nonatomic) NSStatusItem *statusItem;
@property (strong, nonatomic) NSPopover *popover;
@property (strong, nonatomic) WKWebView *webView;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // Dock 아이콘 숨기기 (순수 상단 메뉴바 앱)
    [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];

    // 알림 권한 요청
    UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
    [center requestAuthorizationWithOptions:(UNAuthorizationOptionAlert | UNAuthorizationOptionSound)
                          completionHandler:^(BOOL granted, NSError * _Nullable error) {}];

    // Status Item 생성
    self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSSquareStatusItemLength];
    NSStatusBarButton *button = self.statusItem.button;
    if (button) {
        button.target = self;
        button.action = @selector(togglePopover:);
        [self updateMenuBarIconWithProgress:1.0 isTimerActive:NO];
    }

    // WKWebView 구성
    WKUserContentController *userContentController = [[WKUserContentController alloc] init];
    [userContentController addScriptMessageHandler:self name:@"native"];

    WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];
    config.userContentController = userContentController;
    [config.preferences setValue:@YES forKey:@"developerExtrasEnabled"];

    self.webView = [[WKWebView alloc] initWithFrame:NSMakeRect(0, 0, 320, 480) configuration:config];
    [self.webView setValue:@NO forKey:@"drawsBackground"];

    // index.html 로드
    NSString *bundlePath = [[NSBundle mainBundle] resourcePath];
    NSString *htmlPath = [bundlePath stringByAppendingPathComponent:@"web/index.html"];
    if (![[NSFileManager defaultManager] fileExistsAtPath:htmlPath]) {
        // 개발 중 로컬 실행 경로 지원
        htmlPath = [[NSBundle mainBundle] pathForResource:@"index" ofType:@"html" inDirectory:@"web"];
        if (!htmlPath) {
            NSString *cwd = [[NSFileManager defaultManager] currentDirectoryPath];
            htmlPath = [cwd stringByAppendingPathComponent:@"Sources/web/index.html"];
        }
    }
    NSURL *fileURL = [NSURL fileURLWithPath:htmlPath];
    [self.webView loadFileURL:fileURL allowingReadAccessToURL:[fileURL URLByDeletingLastPathComponent]];

    // NSPopover 설정
    self.popover = [[NSPopover alloc] init];
    self.popover.contentSize = NSMakeSize(320, 480);
    self.popover.behavior = NSPopoverBehaviorTransient;
    
    NSViewController *viewController = [[NSViewController alloc] init];
    viewController.view = self.webView;
    self.popover.contentViewController = viewController;
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

// 메뉴바 아이콘 드로잉 (사람 옆모습 실루엣: 1.0=정자세, 0.0=거북목)
- (void)updateMenuBarIconWithProgress:(double)progress isTimerActive:(BOOL)timerActive {
    NSImage *image = [NSImage imageWithSize:NSMakeSize(20, 20) flipped:NO drawingHandler:^BOOL(NSRect dstRect) {
        NSColor *color = [NSColor controlTextColor];
        if (timerActive) {
            if (progress > 0.65) {
                color = [NSColor controlTextColor];
            } else if (progress > 0.3) {
                color = [NSColor orangeColor];
            } else {
                color = [NSColor systemRedColor];
            }
        }

        // 1. 머리 (원)
        CGFloat fwd = (1.0 - progress) * 4.0;
        CGFloat rad = 3.6;
        CGFloat headX = 9.0 + fwd;
        CGFloat headY = 13.5;

        NSBezierPath *head = [NSBezierPath bezierPathWithOvalInRect:NSMakeRect(headX - rad, headY - rad, rad * 2, rad * 2)];
        [color setFill];
        [head fill];

        // 2. 목 & 등 (옆모습 실루엣)
        NSBezierPath *body = [NSBezierPath bezierPath];
        [body moveToPoint:NSMakePoint(headX - 2.5, headY - 2.0)];
        
        // 등 곡선
        CGFloat backBend = (1.0 - progress) * 2.5;
        [body curveToPoint:NSMakePoint(4.5, 2.0)
             controlPoint1:NSMakePoint(6.0 - backBend, 8.5)
             controlPoint2:NSMakePoint(4.5, 5.0)];

        // 바닥
        [body lineToPoint:NSMakePoint(14.0, 2.0)];

        // 가슴 -> 턱 밑
        [body curveToPoint:NSMakePoint(headX + 2.0, headY - 2.0)
             controlPoint1:NSMakePoint(13.0, 6.0)
             controlPoint2:NSMakePoint(headX + 1.5, 9.0)];

        [body closePath];
        [body fill];

        // 타이머 활성화 시 주변 링
        if (timerActive) {
            NSBezierPath *ringBg = [NSBezierPath bezierPathWithOvalInRect:NSMakeRect(0.5, 0.5, 19, 19)];
            [[color colorWithAlphaComponent:0.25] setStroke];
            ringBg.lineWidth = 1.2;
            [ringBg stroke];
        }

        return YES;
    }];

    [image setTemplate:!timerActive]; // 타이머 없을 땐 템플릿(다크모드 자동 대응)
    self.statusItem.button.image = image;
}

#pragma mark - WKScriptMessageHandler
- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message {
    if (![message.body isKindOfClass:[NSDictionary class]]) return;
    NSDictionary *data = message.body;
    NSString *action = data[@"action"];

    if ([action isEqualToString:@"updateIcon"]) {
        double progress = [data[@"progress"] doubleValue];
        BOOL timerActive = [data[@"timerActive"] boolValue];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self updateMenuBarIconWithProgress:progress isTimerActive:timerActive];
        });
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
