//
//  XToDo.m
//  XToDo
//
//  Created by Travis on 13-11-28.
//    Copyright (c) 2013 fir.im  All rights reserved.
//

#import "XToDo.h"
#import "XToDoModel.h"
#import "XToDoWindowController.h"

XToDo* sharedPlugin = nil;

@interface XToDo ()
@property (nonatomic, strong) XToDoWindowController* windowController;

- (void)applicationDidFinishLaunching:(NSNotification *)notification;
- (void)addMenuItems;

@end

@implementation XToDo

+ (void)pluginDidLoad:(NSBundle*)plugin
{
    static dispatch_once_t onceToken;

    NSString* currentApplicationName = [[NSBundle mainBundle] infoDictionary][@"CFBundleName"];
    if (sharedPlugin == nil && [currentApplicationName isEqual:@"Xcode"]) {
        dispatch_once(&onceToken, ^{
            sharedPlugin=[[self alloc] initWithBundle:plugin];
        });
    }
}

- (id)initWithBundle:(NSBundle*)plugin
{
    self = [super init];
    if (self) {
        self.bundle = plugin;
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationDidFinishLaunching:)
                                                     name:NSApplicationDidFinishLaunchingNotification
                                                   object:nil];
    }
    return self;
}


- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    [self addMenuItems];
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:NSApplicationDidFinishLaunchingNotification
                                                  object:nil];
}

- (void)addMenuItems {
    // insert a menuItem to MainMenu "Window"
    NSMenuItem* menuItem = [[NSApp mainMenu] itemWithTitle:@"View"];
    if (!menuItem) {
        return;
    }
    
    [[menuItem submenu] addItem:[NSMenuItem separatorItem]];
    
    NSMenuItem* actionMenuItem = [[NSMenuItem alloc] initWithTitle:@"ToDo List"
                                                            action:@selector(toggleList)
                                                     keyEquivalent:@"t"];
    
    [actionMenuItem setKeyEquivalentModifierMask:NSControlKeyMask];
    
    [actionMenuItem setTarget:self];
    [[menuItem submenu] addItem:actionMenuItem];
    
    //add Snippet Group
    NSMenu* submenu = [[NSMenu alloc] init];
    
    NSMenuItem* mainItem = [[NSMenuItem alloc] init];
    [mainItem setTitle:@"Snippets"];
    
    [mainItem setSubmenu:submenu];
    [[menuItem submenu] addItem:mainItem];
    
    //support snippets to add TODO
    actionMenuItem = [[NSMenuItem alloc] initWithTitle:@"TODO"
                                                action:@selector(insertToDo)
                                         keyEquivalent:@"t"];
    
    [actionMenuItem setKeyEquivalentModifierMask:NSControlKeyMask | NSShiftKeyMask];
    
    [actionMenuItem setTarget:self];
    [submenu addItem:actionMenuItem];
    
    //support snippets to add FIXME
    actionMenuItem = [[NSMenuItem alloc] initWithTitle:@"FIXME"
                                                action:@selector(insertFixMe)
                                         keyEquivalent:@"x"];
    
    [actionMenuItem setKeyEquivalentModifierMask:NSControlKeyMask | NSShiftKeyMask];
    
    [actionMenuItem setTarget:self];
    [submenu addItem:actionMenuItem];
    
    //support snippets to add !!!
    actionMenuItem = [[NSMenuItem alloc] initWithTitle:@"!!!"
                                                action:@selector(insertWarn)
                                         keyEquivalent:@"1"];
    
    [actionMenuItem setKeyEquivalentModifierMask:NSControlKeyMask | NSShiftKeyMask];
    
    [actionMenuItem setTarget:self];
    [submenu addItem:actionMenuItem];
    
    //support snippets to add ???
    actionMenuItem = [[NSMenuItem alloc] initWithTitle:@"???"
                                                action:@selector(insertAsk)
                                         keyEquivalent:@"q"];
    
    [actionMenuItem setKeyEquivalentModifierMask:NSControlKeyMask | NSShiftKeyMask];
    
    [actionMenuItem setTarget:self];
    [submenu addItem:actionMenuItem];
}

- (BOOL)validateMenuItem:(NSMenuItem*)menuItem
{
    return [XToDoModel currentWorkspaceDocument].workspace != nil;
}

#pragma mark - ment actions
- (void)toggleList
{
    //toggle the todo list window
    if (self.windowController.window.isVisible) {
        [self.windowController.window close];
    } else {
        if (self.windowController == nil) {
            XToDoWindowController* wc = [[XToDoWindowController alloc] initWithWindowNibName:@"XToDoWindowController"];
            self.windowController = wc;
        }

        NSString* filePath = [[XToDoModel currentWorkspaceDocument].workspace.representingFilePath.fileURL path];
        NSString* projectDir = [filePath stringByDeletingLastPathComponent];
        NSString* projectName = [filePath lastPathComponent];
        {
            // register them as soon as possible
            NSUserDefaults* prefs = [NSUserDefaults standardUserDefaults];
            [prefs registerDefaults:@{
                kXToDoTextSizePrefsKey : @(0),
                kXToDoTagsKey : @[ @"TODO", @"FIXME", @"???", @"!!!" ],
            }];
        }
        [XToDoModel cleanAllTempFiles];

        self.windowController.window.title = [[XToDoModel currentWorkspaceDocument].displayName stringByDeletingLastPathComponent];
        //!!!: how about the path is nil?
        [self.windowController setSearchRootDir:projectDir projectName:projectName];
        [self.windowController.window makeKeyAndOrderFront:nil];
        [self.windowController refresh:nil];
    }
}

- (void)insertToDo
{
    NSString* cmt = [NSString stringWithFormat:@"//%@:", @"TODO"];
    [self insertComment:cmt];
}
- (void)insertFixMe
{
    NSString* cmt = [NSString stringWithFormat:@"//%@:", @"FIXME"];
    [self insertComment:cmt];
}

- (void)insertWarn
{
    NSString* cmt = [NSString stringWithFormat:@"//%@:", @"!!!"];
    [self insertComment:cmt];
}
- (void)insertAsk
{
    NSString* cmt = [NSString stringWithFormat:@"//%@:", @"???"];
    [self insertComment:cmt];
}
- (void)insertComment:(NSString*)cmt
{
    NSString * comment = [NSString stringWithFormat:@"%@ (%@) %@", cmt, [self _formattedUserName], [self _formattedDate]];
    IDESourceCodeEditor* editor = [XToDoModel currentEditor];
    NSTextView* textView = editor.textView;
    if (textView) {
        [textView insertText:comment];
        [textView insertText:@" "];
    }
}

#pragma mark - Private

- (NSString *)_formattedDate {
    NSDateFormatter * dateFormatter = [[NSDateFormatter alloc] init];
    dateFormatter.dateFormat = @"dd/MM/yyyy";
    return [dateFormatter stringFromDate:[NSDate date]];
}

- (NSString *)_formattedUserName {
    return [[self _runCommand:@"git config user.name"] stringByReplacingOccurrencesOfString:@"\n" withString:@""];
}

- (NSString *)_runCommand:(NSString *)command {
    NSTask * task = [[NSTask alloc] init];
    [task setLaunchPath:@"/bin/sh"];

    NSArray * arguments = @[ @"-c", command ];
    [task setArguments:arguments];

    NSPipe * pipe = [NSPipe pipe];
    [task setStandardOutput:pipe];

    NSFileHandle * file = [pipe fileHandleForReading];

    [task launch];

    NSData * data = [file readDataToEndOfFile];
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}


@end
