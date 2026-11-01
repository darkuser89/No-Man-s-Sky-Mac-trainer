// SPDX-License-Identifier: GPL-3.0-only
#import <AppKit/AppKit.h>
#import "GameProfile.h"
#import "GameAdapter.h"
#import "OverlaySettings.h"
#import "SelectionSettings.h"
#import "DemoHost.h"
#import "TrainerMaterial.h"
#import <mach/machine.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

static NSColor *MTLauncherOrange(void){return [NSColor colorWithSRGBRed:1 green:0.43 blue:0.14 alpha:1];}
static NSColor *MTLauncherCyan(void){return [NSColor colorWithSRGBRed:0.35 green:0.84 blue:0.93 alpha:1];}
static NSTextField *MTLauncherLabel(NSString *text,CGFloat size,NSFontWeight weight,NSColor *color){
    NSTextField *label=[NSTextField labelWithString:text];label.font=[NSFont systemFontOfSize:size weight:weight];
    label.textColor=color;label.translatesAutoresizingMaskIntoConstraints=NO;return label;
}
@interface MTLauncherBackground : NSView
@end
@implementation MTLauncherBackground
- (BOOL)isOpaque{return YES;}
- (void)drawRect:(NSRect)dirtyRect {
    (void)dirtyRect;NSRect bounds=self.bounds;
    NSColor *bottom=[NSColor colorWithSRGBRed:0.035 green:0.055 blue:0.08 alpha:1];
    NSColor *top=[NSColor colorWithSRGBRed:0.065 green:0.13 blue:0.17 alpha:1];
    [[[NSGradient alloc]initWithStartingColor:bottom endingColor:top] drawInRect:bounds angle:90];
    NSGradient *glow=[[NSGradient alloc]initWithStartingColor:[MTLauncherCyan() colorWithAlphaComponent:0.08]
        endingColor:[MTLauncherCyan() colorWithAlphaComponent:0]];
    NSPoint center=NSMakePoint(NSMaxX(bounds)*0.85,NSMaxY(bounds)*0.88);
    [glow drawFromCenter:center radius:0 toCenter:center radius:400 options:0];
    NSBezierPath *orbit=[NSBezierPath bezierPath];
    [orbit moveToPoint:NSMakePoint(-30,18)];
    [orbit curveToPoint:NSMakePoint(NSMaxX(bounds)+30,42)
        controlPoint1:NSMakePoint(NSMaxX(bounds)*0.3,90) controlPoint2:NSMakePoint(NSMaxX(bounds)*0.7,80)];
    [[MTLauncherCyan() colorWithAlphaComponent:0.09] setStroke];orbit.lineWidth=1;[orbit stroke];
}
@end

// Match the material's top-down content coordinates, as the overlay already does.
@interface MTLauncherContent : NSView
@end
@implementation MTLauncherContent
- (BOOL)isFlipped{return YES;}
@end

@interface MTLauncher : NSObject <NSApplicationDelegate>
@property(nonatomic) NSWindow *window;
@property(nonatomic) NSDictionary *configuration;
@property(nonatomic) NSPopUpButton *profiles;
@property(nonatomic) NSTextField *status;
@property(nonatomic) NSButton *start;
@property(nonatomic) NSButton *restoreCheats;
@property(nonatomic) id statusObserver;
@property(nonatomic) NSTextField *restoreHint;
@property(nonatomic) NSRunningApplication *game;
@property(nonatomic,copy) NSString *session;
@property(nonatomic,copy) NSString *launchedProfileID;
@property(nonatomic) id settingsObserver;
@property(nonatomic) id selectionObserver;
@end
@implementation MTLauncher
- (NSDictionary *)profile {return self.configuration[@"profiles"][self.profiles.indexOfSelectedItem];}
- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    (void)notification;
    NSMenu *menu=[NSMenu new];NSMenuItem *item=[NSMenuItem new];[menu addItem:item];
    NSMenu *applicationMenu=[NSMenu new];[applicationMenu addItemWithTitle:@"No Mans Sky Trainer beenden" action:@selector(terminate:) keyEquivalent:@"q"];item.submenu=applicationMenu;NSApp.mainMenu=menu;
    NSError *error=nil;self.configuration=MTLoadConfiguration([NSBundle.mainBundle pathForResource:@"TrainerConfig" ofType:@"json"],&error);
    if(!self.configuration){NSAlert *a=[NSAlert new];a.messageText=error.localizedDescription;[a runModal];[NSApp terminate:nil];return;}
    self.window=[[NSWindow alloc]initWithContentRect:NSMakeRect(0,0,700,536) styleMask:NSWindowStyleMaskTitled|NSWindowStyleMaskClosable|NSWindowStyleMaskMiniaturizable backing:NSBackingStoreBuffered defer:NO];self.window.releasedWhenClosed=NO;self.window.title=@"No Man’s Sky Trainer";
    self.window.titlebarAppearsTransparent=NO;self.window.titleVisibility=NSWindowTitleVisible;
    self.window.appearance=[NSAppearance appearanceNamed:NSAppearanceNameDarkAqua];
    self.window.opaque=YES;self.window.backgroundColor=NSColor.windowBackgroundColor;
    MTLauncherBackground *background=[[MTLauncherBackground alloc]initWithFrame:self.window.contentView.bounds];
    background.autoresizingMask=NSViewWidthSizable|NSViewHeightSizable;self.window.contentView=background;
    NSImageView *icon=[NSImageView new];icon.translatesAutoresizingMaskIntoConstraints=NO;
    icon.image=[[NSImage alloc]initWithContentsOfFile:[NSBundle.mainBundle pathForResource:@"AppIcon" ofType:@"icns"]] ?: NSApp.applicationIconImage;
    icon.imageScaling=NSImageScaleProportionallyUpOrDown;icon.accessibilityLabel=@"No Man’s Sky Trainer – Atlas-Kristall";
    NSTextField *title=MTLauncherLabel(@"NO MAN’S SKY",30,NSFontWeightBold,MTLauncherOrange());
    NSTextField *kind=MTLauncherLabel(@"TRAINER",12,NSFontWeightSemibold,MTLauncherCyan());
    kind.attributedStringValue=[[NSAttributedString alloc]initWithString:kind.stringValue attributes:@{NSFontAttributeName:kind.font,NSForegroundColorAttributeName:kind.textColor,NSKernAttributeName:@3}];
    NSTextField *count=MTLauncherLabel(@"27 Funktionen · 3 Extras",13,NSFontWeightRegular,NSColor.secondaryLabelColor);
    NSStackView *heading=[NSStackView stackViewWithViews:@[kind,title,count]];
    heading.orientation=NSUserInterfaceLayoutOrientationVertical;heading.alignment=NSLayoutAttributeLeading;heading.spacing=5;
    NSStackView *hero=[NSStackView stackViewWithViews:@[icon,heading]];
    hero.alignment=NSLayoutAttributeCenterY;hero.spacing=18;hero.translatesAutoresizingMaskIntoConstraints=NO;
    [background addSubview:hero];
    self.profiles=[[NSPopUpButton alloc]initWithFrame:NSZeroRect pullsDown:NO];for(NSDictionary *p in self.configuration[@"profiles"])[self.profiles addItemWithTitle:p[@"name"]];self.profiles.target=self;self.profiles.action=@selector(refresh:);
    NSView *profileContent=[MTLauncherContent new];
    MTTrainerMaterial *profileSurface=[[MTTrainerMaterial alloc]initWithContentView:profileContent cornerRadius:20];
    profileSurface.translatesAutoresizingMaskIntoConstraints=NO;[background addSubview:profileSurface];
    NSTextField *profileTitle=MTLauncherLabel(@"SPIELPROFIL",11,NSFontWeightSemibold,NSColor.secondaryLabelColor);
    self.profiles.font=[NSFont systemFontOfSize:13];self.profiles.controlSize=NSControlSizeLarge;
    NSButton *choose=[NSButton buttonWithTitle:@"Spiele-App wählen …" target:self action:@selector(choose:)];
    choose.controlSize=NSControlSizeSmall;choose.font=[NSFont systemFontOfSize:12];
    choose.image=[NSImage imageWithSystemSymbolName:@"folder" accessibilityDescription:nil];choose.imagePosition=NSImageLeft;
    self.start=[NSButton buttonWithTitle:@"Spiel mit Trainer starten" target:self action:@selector(startGame:)];
    self.start.bezelStyle=NSBezelStyleRounded;self.start.controlSize=NSControlSizeLarge;
    self.start.bezelColor=MTLauncherOrange();self.start.contentTintColor=NSColor.whiteColor;
    self.start.keyEquivalent=@"\r";
    self.start.font=[NSFont systemFontOfSize:15 weight:NSFontWeightSemibold];
    self.start.image=[NSImage imageWithSystemSymbolName:@"play.fill" accessibilityDescription:nil];self.start.imagePosition=NSImageLeft;
    self.restoreCheats=[NSButton checkboxWithTitle:@"Cheat-Auswahl beim nächsten Start laden" target:self action:@selector(restoreChanged:)];
    self.restoreCheats.font=[NSFont systemFontOfSize:13];self.restoreCheats.contentTintColor=MTLauncherCyan();
    id savedRestore=[NSUserDefaults.standardUserDefaults objectForKey:MTSelectionRestorePreferencesKey];
    self.restoreCheats.state=(savedRestore!=nil && [savedRestore boolValue]) ? NSControlStateValueOn : NSControlStateValueOff;
    self.restoreCheats.toolTip=@"Schalter und Zahlenwerte werden je Spielprofil gespeichert. Einmalaktionen laufen nie automatisch.";
    self.restoreHint=[NSTextField wrappingLabelWithString:@""];self.restoreHint.textColor=NSColor.secondaryLabelColor;self.restoreHint.font=[NSFont systemFontOfSize:12];
    for(NSView *view in @[profileTitle,self.profiles,choose,self.restoreCheats,self.restoreHint,self.start]){
        view.translatesAutoresizingMaskIntoConstraints=NO;[profileContent addSubview:view];
    }
    NSTextField *statusTitle=MTLauncherLabel(@"STATUS",10,NSFontWeightSemibold,NSColor.secondaryLabelColor);
    self.status=[NSTextField wrappingLabelWithString:@""];self.status.textColor=NSColor.secondaryLabelColor;
    self.status.font=[NSFont systemFontOfSize:12];self.status.selectable=YES;self.status.maximumNumberOfLines=3;self.status.translatesAutoresizingMaskIntoConstraints=NO;
    NSTextField *overlayHint=MTLauncherLabel(@"⌘ ^  Overlay + Maus",12,NSFontWeightMedium,MTLauncherCyan());
    NSTextField *stopHint=MTLauncherLabel(@"⇧ F9  Alles aus",12,NSFontWeightMedium,NSColor.secondaryLabelColor);
    for(NSView *view in @[statusTitle,self.status,overlayHint,stopHint])[background addSubview:view];
    [NSLayoutConstraint activateConstraints:@[
        [icon.widthAnchor constraintEqualToConstant:112],[icon.heightAnchor constraintEqualToConstant:112],
        [hero.leadingAnchor constraintEqualToAnchor:background.leadingAnchor constant:24],
        [hero.topAnchor constraintEqualToAnchor:background.topAnchor constant:24],
        [hero.trailingAnchor constraintLessThanOrEqualToAnchor:background.trailingAnchor constant:-28],
        [profileSurface.leadingAnchor constraintEqualToAnchor:background.leadingAnchor constant:28],
        [profileSurface.trailingAnchor constraintEqualToAnchor:background.trailingAnchor constant:-28],
        [profileSurface.topAnchor constraintEqualToAnchor:hero.bottomAnchor constant:20],
        [profileSurface.heightAnchor constraintEqualToConstant:232],
        [profileTitle.leadingAnchor constraintEqualToAnchor:profileContent.leadingAnchor constant:20],
        [profileTitle.centerYAnchor constraintEqualToAnchor:choose.centerYAnchor],
        [choose.trailingAnchor constraintEqualToAnchor:profileContent.trailingAnchor constant:-20],
        [choose.topAnchor constraintEqualToAnchor:profileContent.topAnchor constant:16],
        [self.profiles.leadingAnchor constraintEqualToAnchor:profileContent.leadingAnchor constant:20],
        [self.profiles.trailingAnchor constraintEqualToAnchor:profileContent.trailingAnchor constant:-20],
        [self.profiles.topAnchor constraintEqualToAnchor:choose.bottomAnchor constant:8],
        [self.profiles.heightAnchor constraintEqualToConstant:30],
        [self.restoreCheats.leadingAnchor constraintEqualToAnchor:self.profiles.leadingAnchor],
        [self.restoreCheats.topAnchor constraintEqualToAnchor:self.profiles.bottomAnchor constant:17],
        [self.restoreCheats.trailingAnchor constraintLessThanOrEqualToAnchor:self.profiles.trailingAnchor],
        [self.restoreHint.leadingAnchor constraintEqualToAnchor:self.restoreCheats.leadingAnchor constant:20],
        [self.restoreHint.trailingAnchor constraintEqualToAnchor:self.profiles.trailingAnchor],
        [self.restoreHint.topAnchor constraintEqualToAnchor:self.restoreCheats.bottomAnchor constant:4],
        [self.restoreHint.heightAnchor constraintEqualToConstant:20],
        [self.start.leadingAnchor constraintEqualToAnchor:self.profiles.leadingAnchor],
        [self.start.trailingAnchor constraintEqualToAnchor:self.profiles.trailingAnchor],
        [self.start.topAnchor constraintGreaterThanOrEqualToAnchor:self.restoreHint.bottomAnchor constant:18],
        [self.start.heightAnchor constraintEqualToConstant:44],
        [self.start.bottomAnchor constraintEqualToAnchor:profileContent.bottomAnchor constant:-20],
        [statusTitle.leadingAnchor constraintEqualToAnchor:profileSurface.leadingAnchor constant:2],
        [statusTitle.topAnchor constraintEqualToAnchor:profileSurface.bottomAnchor constant:18],
        [self.status.leadingAnchor constraintEqualToAnchor:statusTitle.leadingAnchor],
        [self.status.trailingAnchor constraintEqualToAnchor:profileSurface.trailingAnchor constant:-2],
        [self.status.topAnchor constraintEqualToAnchor:statusTitle.bottomAnchor constant:5],
        [self.status.heightAnchor constraintEqualToConstant:44],
        [overlayHint.leadingAnchor constraintEqualToAnchor:statusTitle.leadingAnchor],
        [overlayHint.bottomAnchor constraintEqualToAnchor:background.bottomAnchor constant:-24],
        [stopHint.trailingAnchor constraintEqualToAnchor:profileSurface.trailingAnchor constant:-2],
        [stopHint.centerYAnchor constraintEqualToAnchor:overlayHint.centerYAnchor]
    ]];
    __weak MTLauncher *weakSelf=self;
    self.settingsObserver=[NSDistributedNotificationCenter.defaultCenter addObserverForName:MTOverlayChangedNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *event){
        MTLauncher *owner=weakSelf;if(!owner.game || owner.game.terminated)return;
        NSDictionary *options=MTOverlayMessageOptions(event.object,owner.session,owner.game.processIdentifier);
        if(options)[NSUserDefaults.standardUserDefaults setObject:options forKey:MTOverlayPreferencesKey];
    }];
    self.statusObserver=[NSDistributedNotificationCenter.defaultCenter addObserverForName:@"local.mactrainer.nomanssky.status" object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *event){
        MTLauncher *owner=weakSelf;if(!owner.game || owner.game.terminated || ![event.object isKindOfClass:NSString.class] || [event.object length]>4096)return;
        NSData *data=[event.object dataUsingEncoding:NSUTF8StringEncoding];id d=data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL] : nil;
        if(![d isKindOfClass:NSDictionary.class] || ![d[@"session"] isEqual:owner.session] || ![d[@"profile"] isEqual:owner.launchedProfileID] || ![d[@"pid"] isEqual:@(owner.game.processIdentifier)])return;
        if([d[@"status"] isKindOfClass:NSString.class] && [d[@"message"] isKindOfClass:NSString.class])owner.status.stringValue=[NSString stringWithFormat:@"%@ · %@",d[@"status"],d[@"message"]];
    }];
    self.selectionObserver=[NSDistributedNotificationCenter.defaultCenter addObserverForName:MTSelectionChangedNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *event){
        MTLauncher *owner=weakSelf;if(!owner.game || owner.game.terminated)return;
        NSDictionary *selection=MTSelectionMessageSelection(event.object,owner.session,owner.launchedProfileID,owner.game.processIdentifier);
        if(selection)[NSUserDefaults.standardUserDefaults setObject:selection forKey:MTSelectionPreferencesKey(owner.launchedProfileID)];
    }];
    NSString *stored=[NSUserDefaults.standardUserDefaults stringForKey:self.pathKey];
    NSURL *installed=[NSWorkspace.sharedWorkspace URLForApplicationWithBundleIdentifier:self.profile[@"bundleIdentifier"]];
    if(!stored.length && installed)[NSUserDefaults.standardUserDefaults setObject:installed.path forKey:self.pathKey];
    [self refresh:nil];[self.window center];[self.window makeKeyAndOrderFront:nil];[NSApp activateIgnoringOtherApps:YES];
}
- (NSString *)pathKey {return [@"GamePath." stringByAppendingString:self.profile[@"id"]];}
- (void)restoreChanged:(id)sender {(void)sender;
    BOOL enabled=self.restoreCheats.state==NSControlStateValueOn;
    [NSUserDefaults.standardUserDefaults setBool:enabled forKey:MTSelectionRestorePreferencesKey];
    self.restoreHint.stringValue=enabled ? @"Gespeicherte Auswahl wird nach dem Laden aktiviert." : @"Cheats starten ohne gespeicherte Auswahl.";
}
- (void)refresh:(id)sender {(void)sender;self.start.enabled=NO;
    [self restoreChanged:nil];
    if(![self.profile[@"enabled"] boolValue]){self.status.stringValue=@"Profil noch nicht eingerichtet. Zuerst Demo testen; dann SKILL.md und docs/ADAPTER.md lesen.";return;}
    if([MTCreateGameAdapter() isMemberOfClass:MTUnsupportedAdapter.class]){self.status.stringValue=@"Spieladapter fehlt. MTCreateGameAdapter muss eine geprüfte Anbindung liefern.";return;}
    NSString *path=[NSUserDefaults.standardUserDefaults stringForKey:self.pathKey];NSError *error=nil;
    if(!path.length){self.status.stringValue=@"Bitte passende Spiele-App auswählen.";return;}
    self.start.enabled=MTInspectGame(path,self.profile,&error)!=nil;self.status.stringValue=self.start.enabled ? path : error.localizedDescription;
}
- (void)choose:(id)sender {(void)sender;NSOpenPanel *panel=[NSOpenPanel openPanel];panel.canChooseFiles=YES;panel.canChooseDirectories=NO;panel.allowsMultipleSelection=NO;panel.allowedContentTypes=@[UTTypeApplicationBundle];
    if([panel runModal]==NSModalResponseOK){[NSUserDefaults.standardUserDefaults setObject:panel.URL.path forKey:self.pathKey];[self refresh:nil];}}
- (void)startGame:(id)sender {(void)sender;[self refresh:nil];if(!self.start.enabled)return;
    if([NSRunningApplication runningApplicationsWithBundleIdentifier:self.profile[@"bundleIdentifier"]].count){self.status.stringValue=@"Die laufende Spielinstanz bitte regulär beenden.";return;}
    NSString *path=[NSUserDefaults.standardUserDefaults stringForKey:self.pathKey];NSError *error=nil;NSDictionary *game=MTInspectGame(path,self.profile,&error);if(!game){self.status.stringValue=error.localizedDescription;return;}
    NSString *module=[NSBundle.mainBundle pathForResource:@"TrainerOverlay" ofType:@"dylib"];
    NSWorkspaceOpenConfiguration *c=[NSWorkspaceOpenConfiguration configuration];c.createsNewApplicationInstance=YES;c.activates=YES;c.architecture=CPU_TYPE_ARM64;
    self.session=NSUUID.UUID.UUIDString;
    self.launchedProfileID=self.profile[@"id"];
    id savedSelection=self.restoreCheats.state==NSControlStateValueOn
        ? [NSUserDefaults.standardUserDefaults objectForKey:MTSelectionPreferencesKey(self.launchedProfileID)] : nil;
    c.environment=@{@"SteamAppId":@"275850",@"SteamGameId":@"275850",@"NMS_TRAINER_READ_ONLY":@"0",@"DYLD_INSERT_LIBRARIES":module,@"MT_TRAINER_TARGET":game[@"executable"],@"MT_TRAINER_CONFIG":[NSBundle.mainBundle pathForResource:@"TrainerConfig" ofType:@"json"],@"MT_TRAINER_PROFILE":self.launchedProfileID,@"MT_TRAINER_SESSION":self.session,@"MT_TRAINER_OVERLAY_OPTIONS":MTEncodeOverlayOptions(MTOverlayOptionsForLaunch([NSUserDefaults.standardUserDefaults objectForKey:MTOverlayPreferencesKey])),@"MT_TRAINER_CHEAT_SELECTION":MTEncodeCheatSelection(savedSelection)};
    __weak MTLauncher *weakSelf=self;
    [NSWorkspace.sharedWorkspace openApplicationAtURL:[NSURL fileURLWithPath:game[@"path"]] configuration:c completionHandler:^(NSRunningApplication *app,NSError *failure){dispatch_async(dispatch_get_main_queue(),^{weakSelf.game=app;weakSelf.status.stringValue=failure ? failure.localizedDescription : app ? @"Spielstart angefordert. Overlay mit ⌘ ^ öffnen. Nur der native Adapter bestätigt die Anbindung." : @"Kein Spielprozess gestartet.";});}];
}
- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)application {(void)application;return !self.game || self.game.terminated;}
- (BOOL)applicationShouldHandleReopen:(NSApplication *)application hasVisibleWindows:(BOOL)visible {(void)application;if(!visible)[self.window makeKeyAndOrderFront:nil];return YES;}
- (void)applicationWillTerminate:(NSNotification *)notification {(void)notification;if(self.statusObserver)[NSDistributedNotificationCenter.defaultCenter removeObserver:self.statusObserver];if(self.settingsObserver)[NSDistributedNotificationCenter.defaultCenter removeObserver:self.settingsObserver];if(self.selectionObserver)[NSDistributedNotificationCenter.defaultCenter removeObserver:self.selectionObserver];}
@end
int main(int argc,const char *argv[]){@autoreleasepool{[NSApplication sharedApplication];[NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];if(argc==2 && !strcmp(argv[1],"--demo")){MTStartDemo();return 0;}MTLauncher *delegate=[MTLauncher new];NSApp.delegate=delegate;[NSApp run];}return 0;}
