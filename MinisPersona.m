#import <UIKit/UIKit.h>

static NSString * const MPDraftKey = @"com.knight914.minispersona.draft";

@interface MPEditor : UIViewController
@property (nonatomic, copy) void (^onClose)(void);
@end

@implementation MPEditor {
    UITextField *_style;
    UITextView *_body;
    UILabel *_status;
}

- (UILabel *)label:(NSString *)text {
    UILabel *label = [UILabel new];
    label.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    label.adjustsFontForContentSizeCategory = YES;
    label.numberOfLines = 0;
    label.text = text;
    return label;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"MinisPersona";
    self.view.backgroundColor = UIColor.systemBackgroundColor;
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc]
        initWithBarButtonSystemItem:UIBarButtonSystemItemClose target:self action:@selector(closeEditor)];

    UIScrollView *scroll = [UIScrollView new];
    scroll.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
    scroll.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:scroll];
    UIStackView *stack = [UIStackView new];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 12;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [scroll addSubview:stack];
    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    UILayoutGuide *content = scroll.contentLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [scroll.topAnchor constraintEqualToAnchor:safe.topAnchor],
        [scroll.bottomAnchor constraintEqualToAnchor:self.view.keyboardLayoutGuide.topAnchor],
        [scroll.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor],
        [scroll.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor],
        [stack.topAnchor constraintEqualToAnchor:content.topAnchor constant:16],
        [stack.bottomAnchor constraintEqualToAnchor:content.bottomAnchor constant:-16],
        [stack.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:16],
        [stack.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-16],
        [stack.widthAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.widthAnchor constant:-32]
    ]];

    NSDictionary *draft = [NSUserDefaults.standardUserDefaults dictionaryForKey:MPDraftKey];
    _style = [UITextField new];
    _style.borderStyle = UITextBorderStyleRoundedRect;
    _style.accessibilityLabel = @"Style";
    _style.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    _style.adjustsFontForContentSizeCategory = YES;
    if ([draft[@"style"] isKindOfClass:NSString.class]) _style.text = draft[@"style"];
    _body = [UITextView new];
    _body.backgroundColor = UIColor.secondarySystemBackgroundColor;
    _body.accessibilityLabel = @"Body";
    _body.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    _body.adjustsFontForContentSizeCategory = YES;
    if ([draft[@"body"] isKindOfClass:NSString.class]) _body.text = draft[@"body"];
    [_body.heightAnchor constraintEqualToConstant:160].active = YES;
    [stack addArrangedSubview:[self label:@"Draft only. Review or copy JSON here; apply separately with the CLI."]];
    [stack addArrangedSubview:[self label:@"Style"]];
    [stack addArrangedSubview:_style];
    [stack addArrangedSubview:[self label:@"Body"]];
    [stack addArrangedSubview:_body];
    NSArray<NSString *> *titles = @[@"Preview JSON", @"Copy JSON", @"Save Local Draft", @"Clear Local Draft"];
    SEL actions[] = {@selector(preview), @selector(copyJSON), @selector(saveDraft), @selector(clearDraft)};
    for (NSUInteger i = 0; i < titles.count; i++) {
        UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
        [button setTitle:titles[i] forState:UIControlStateNormal];
        button.titleLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
        button.titleLabel.adjustsFontForContentSizeCategory = YES;
        [button.heightAnchor constraintGreaterThanOrEqualToConstant:44].active = YES;
        [button addTarget:self action:actions[i] forControlEvents:UIControlEventTouchUpInside];
        [stack addArrangedSubview:button];
    }
    _status = [self label:@"Save explicitly to keep a draft. Closing discards unsaved changes."];
    [stack addArrangedSubview:_status];
}

- (void)setStatus:(NSString *)text {
    _status.text = text;
    UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification, text);
}

- (NSDictionary<NSString *, NSString *> *)validatedDraft {
    NSString *style = _style.text ?: @"";
    NSString *body = _body.text ?: @"";
    NSMutableCharacterSet *controls = [NSMutableCharacterSet characterSetWithRange:NSMakeRange(0, 32)];
    [controls addCharactersInRange:NSMakeRange(127, 33)];
    [controls removeCharactersInString:@"\n\r\t"];
    for (NSString *text in @[style, body]) {
        if (![text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet].length ||
            [text rangeOfCharacterFromSet:controls].location != NSNotFound ||
            ![text canBeConvertedToEncoding:NSUTF8StringEncoding]) {
            [self setStatus:@"Both fields need valid, nonblank text without unsupported control characters."];
            return nil;
        }
    }
    // UTF-32 counts Unicode scalars like Python's len(); the body cap uses UTF-16 units.
    if ([style lengthOfBytesUsingEncoding:NSUTF32LittleEndianStringEncoding] / 4 > 200 || body.length > 3000) {
        [self setStatus:@"Style limit: 200 characters. Body limit: 3,000 UTF-16 units."];
        return nil;
    }
    return @{@"style": style, @"body": body};
}

- (NSString *)json {
    NSDictionary *draft = [self validatedDraft];
    if (!draft) return nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:draft
        options:NSJSONWritingPrettyPrinted | NSJSONWritingSortedKeys error:nil];
    NSString *text = data ? [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] : nil;
    if (!text) [self setStatus:@"Could not encode this draft as JSON."];
    return text;
}

- (void)preview {
    [self.view endEditing:YES];
    NSString *text = [self json];
    if (!text) return;
    UIViewController *page = [UIViewController new];
    page.title = @"Preview JSON";
    UITextView *view = [UITextView new];
    view.editable = NO;
    view.selectable = NO;
    view.accessibilityLabel = @"Persona JSON preview";
    view.text = text;
    view.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    view.adjustsFontForContentSizeCategory = YES;
    view.backgroundColor = UIColor.systemBackgroundColor;
    page.view = view;
    [self.navigationController pushViewController:page animated:YES];
}

- (void)copyJSON {
    [self.view endEditing:YES];
    NSString *text = [self json];
    if (!text) return;
    [UIPasteboard.generalPasteboard setItems:@[@{@"public.utf8-plain-text": text}]
        options:@{UIPasteboardOptionLocalOnly: @YES,
                  UIPasteboardOptionExpirationDate: [NSDate dateWithTimeIntervalSinceNow:600]}];
    [self setStatus:@"Copied on this device for 10 minutes. Nothing applied."];
}

- (void)saveDraft {
    [self.view endEditing:YES];
    NSDictionary *draft = [self validatedDraft];
    if (!draft) return;
    [NSUserDefaults.standardUserDefaults setObject:draft forKey:MPDraftKey];
    [self setStatus:@"Saved locally. Nothing applied."];
}

- (void)clearDraft {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Clear local draft?"
        message:@"This clears the saved draft and both editor fields, not the clipboard or Minis settings."
        preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Clear" style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction *action) {
        [NSUserDefaults.standardUserDefaults removeObjectForKey:MPDraftKey];
        self->_style.text = @"";
        self->_body.text = @"";
        [self setStatus:@"Local draft cleared."];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)closeEditor {
    [self dismissViewControllerAnimated:YES completion:self.onClose];
}
@end

@interface MPEntry : UIButton
@end

@implementation MPEntry
- (void)openEditor {
    UIWindow *window = self.window;
    UIViewController *host = window.rootViewController;
    if (!window.isKeyWindow || !host || host.presentedViewController || host.isBeingDismissed ||
        host.transitionCoordinator || host.viewIfLoaded.window != window || self.hidden) return;
    [window endEditing:YES];
    MPEditor *editor = [MPEditor new];
    __weak MPEntry *entry = self;
    editor.onClose = ^{ entry.hidden = NO; };
    UINavigationController *navigation = [[UINavigationController alloc] initWithRootViewController:editor];
    navigation.modalPresentationStyle = UIModalPresentationFullScreen;
    self.hidden = YES;
    [host presentViewController:navigation animated:YES completion:nil];
    if (!navigation.presentingViewController) self.hidden = NO;
}
@end

static void MPInstallEntry(UIWindow *window) {
    if (!window.isKeyWindow || window.windowLevel != UIWindowLevelNormal || !window.rootViewController ||
        ![window.windowScene.session.role isEqualToString:UIWindowSceneSessionRoleApplication]) return;
    for (UIView *view in window.subviews) if ([view isKindOfClass:MPEntry.class]) return;
    MPEntry *button = [MPEntry buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.backgroundColor = UIColor.secondarySystemBackgroundColor;
    button.layer.cornerRadius = 12;
    [button setTitle:@"Persona" forState:UIControlStateNormal];
    button.accessibilityLabel = @"MinisPersona editor";
    button.accessibilityHint = @"Preview, edit, or copy a local persona draft";
    [button addTarget:button action:@selector(openEditor) forControlEvents:UIControlEventTouchUpInside];
    [window addSubview:button];
    UILayoutGuide *safe = window.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [button.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-8],
        [button.topAnchor constraintEqualToAnchor:safe.topAnchor constant:8],
        [button.widthAnchor constraintEqualToConstant:80],
        [button.heightAnchor constraintEqualToConstant:44]
    ]];
}

__attribute__((constructor)) static void MPStart(void) {
    if (![NSBundle.mainBundle.bundleIdentifier isEqualToString:@"com.openminis.app"]) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        NSNotificationCenter *center = NSNotificationCenter.defaultCenter;
        [center addObserverForName:UIWindowDidBecomeKeyNotification object:nil queue:NSOperationQueue.mainQueue
            usingBlock:^(NSNotification *note) { MPInstallEntry(note.object); }];
        void (^scan)(void) = ^{
            for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
                if (![scene isKindOfClass:UIWindowScene.class]) continue;
                for (UIWindow *window in ((UIWindowScene *)scene).windows) MPInstallEntry(window);
            }
        };
        [center addObserverForName:UISceneDidActivateNotification object:nil queue:NSOperationQueue.mainQueue
            usingBlock:^(__unused NSNotification *note) { scan(); }];
        scan();
    });
}
