#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <time.h>

@interface SBFLockScreenDateView : UIView
@end

@interface SBFLockScreenDateViewController : UIViewController
- (void)setScreenOff:(BOOL)screenOff;
@end

@interface CSCoverSheetViewController : UIViewController
- (void)yk_refreshCustomClockIfInstalled;
@end

static void *kYKClockContainerKey = &kYKClockContainerKey;
static void *kYKDateLabelKey      = &kYKDateLabelKey;
static void *kYKTimeLabelKey      = &kYKTimeLabelKey;

static __weak CSCoverSheetViewController *ykActiveCoverSheetController = nil;

static inline id YKGetAssoc(id obj, const void *key) {
    return objc_getAssociatedObject(obj, key);
}

static inline void YKSetAssoc(id obj, const void *key, id value) {
    objc_setAssociatedObject(obj, key, value, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static NSString *YKDateStringNow(void) {
    time_t now;
    time(&now);

    struct tm localTm;
    localtime_r(&now, &localTm);

    char buf[128];
    return strftime(buf, sizeof(buf), "%B %e, %Y", &localTm)
        ? ([NSString stringWithUTF8String:buf] ?: @"")
        : @"";
}

static NSString *YKTimeStringNow(void) {
    time_t now;
    time(&now);

    struct tm localTm;
    localtime_r(&now, &localTm);

    char buf[32];
    return strftime(buf, sizeof(buf), "%H:%M", &localTm)
        ? ([NSString stringWithUTF8String:buf] ?: @"")
        : @"";
}

static UIView *YKCreateClockIfNeeded(UIViewController *vc) {
    UIView *container = YKGetAssoc(vc, kYKClockContainerKey);
    if (container) return container;

    container = [[UIView alloc] init];
    container.translatesAutoresizingMaskIntoConstraints = NO;
    container.userInteractionEnabled = NO;
    container.backgroundColor = UIColor.clearColor;

    UILabel *dateLabel = [[UILabel alloc] init];
    dateLabel.translatesAutoresizingMaskIntoConstraints = NO;
    dateLabel.textColor = UIColor.whiteColor;
    dateLabel.textAlignment = NSTextAlignmentRight;
    dateLabel.font = [UIFont systemFontOfSize:29.0 weight:UIFontWeightBold];
    dateLabel.numberOfLines = 1;

    UILabel *timeLabel = [[UILabel alloc] init];
    timeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    timeLabel.textColor = UIColor.whiteColor;
    timeLabel.textAlignment = NSTextAlignmentRight;
    timeLabel.font = [UIFont systemFontOfSize:60.0 weight:UIFontWeightHeavy];
    timeLabel.numberOfLines = 1;

    [container addSubview:dateLabel];
    [container addSubview:timeLabel];

    [NSLayoutConstraint activateConstraints:@[
        [dateLabel.topAnchor constraintEqualToAnchor:container.topAnchor],
        [dateLabel.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [dateLabel.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
        [dateLabel.heightAnchor constraintEqualToConstant:34.0],

        [timeLabel.topAnchor constraintEqualToAnchor:dateLabel.bottomAnchor],
        [timeLabel.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [timeLabel.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
        [timeLabel.heightAnchor constraintEqualToConstant:74.0]
    ]];

    YKSetAssoc(vc, kYKClockContainerKey, container);
    YKSetAssoc(vc, kYKDateLabelKey, dateLabel);
    YKSetAssoc(vc, kYKTimeLabelKey, timeLabel);

    return container;
}

static void YKInstallClockIfNeeded(UIViewController *vc) {
    if (!vc || !vc.view) return;

    UIView *hostView = vc.view;
    UIView *container = YKCreateClockIfNeeded(vc);

    if (container.superview == hostView) return;

    [container removeFromSuperview];
    [hostView addSubview:container];

    [NSLayoutConstraint activateConstraints:@[
        [container.topAnchor constraintEqualToAnchor:hostView.topAnchor constant:72.0],
        [container.trailingAnchor constraintEqualToAnchor:hostView.trailingAnchor constant:-18.0],
        [container.widthAnchor constraintEqualToConstant:320.0],
        [container.heightAnchor constraintEqualToConstant:108.0]
    ]];
}

static void YKRemoveClock(UIViewController *vc) {
    if (!vc) return;

    UIView *container = YKGetAssoc(vc, kYKClockContainerKey);
    if (!container) return;

    [container removeFromSuperview];
}

static void YKRefreshClock(UIViewController *vc) {
    UILabel *dateLabel = YKGetAssoc(vc, kYKDateLabelKey);
    UILabel *timeLabel = YKGetAssoc(vc, kYKTimeLabelKey);
    if (!dateLabel || !timeLabel) return;

    NSString *date = YKDateStringNow();
    NSString *time = YKTimeStringNow();

    if (![dateLabel.text isEqualToString:date]) {
        dateLabel.text = date;
    }

    if (![timeLabel.text isEqualToString:time]) {
        timeLabel.text = time;
    }
}

%hook SBFLockScreenDateView

- (void)didMoveToWindow {
    %orig;

    if (self.window && !self.hidden) {
        self.hidden = YES;
    }
}

%end

%hook CSCoverSheetViewController

- (void)viewDidLoad {
    %orig;
    ykActiveCoverSheetController = self;
}

- (void)viewWillAppear:(BOOL)animated {
    %orig(animated);

    ykActiveCoverSheetController = self;
    YKInstallClockIfNeeded(self);
    YKRefreshClock(self);
}

- (void)viewWillDisappear:(BOOL)animated {
    YKRemoveClock(self);

    if (ykActiveCoverSheetController == self) {
        ykActiveCoverSheetController = nil;
    }

    %orig(animated);
}

%new
- (void)yk_refreshCustomClockIfInstalled {
    UIView *container = YKGetAssoc(self, kYKClockContainerKey);
    if (!container || !container.superview) return;

    YKRefreshClock(self);
}

%end

%hook SBFLockScreenDateViewController

- (void)setScreenOff:(BOOL)screenOff {
    %orig(screenOff);

    CSCoverSheetViewController *cover = ykActiveCoverSheetController;
    if (!cover) return;

    if (screenOff) {
        YKRemoveClock(cover);
        return;
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        CSCoverSheetViewController *strongCover = ykActiveCoverSheetController;
        if (!strongCover || !strongCover.view.window) return;

        YKInstallClockIfNeeded(strongCover);
        [strongCover yk_refreshCustomClockIfInstalled];
    });
}

%end

%ctor {
    @autoreleasepool {
    }
}
