//
//  TileMillAppDelegate.m
//  TileMill
//
//  Created by Dane Springmeyer on 7/28/11.
//  Copyright 2011 Development Seed. All rights reserved.
//

#import "TileMillAppDelegate.h"
#import "TileMillBrowserWindowController.h"
#import "TileMillPrefsWindowController.h"

#import "Sparkle.h"

#import "PFMoveApplication.h"

@interface TileMillAppDelegate ()

@property (nonatomic, retain) TileMillChildProcess *searchTask;
@property (nonatomic, retain) TileMillBrowserWindowController *browserController;
@property (nonatomic, retain) TileMillPrefsWindowController *prefsController;
@property (nonatomic, retain) NSString *logPath;
@property (nonatomic, assign) BOOL shouldAttemptRestart;
@property (nonatomic, assign) BOOL fatalErrorCaught;

- (void)startTileMill;
- (void)stopTileMill;
- (void)writeToLog:(NSString *)message;
- (void)presentFatalError;

@end
   
#pragma mark -

@implementation TileMillAppDelegate

@synthesize searchTask;
@synthesize browserController;
@synthesize prefsController;
@synthesize logPath;
@synthesize shouldAttemptRestart;
@synthesize fatalErrorCaught;

- (void)dealloc
{
    [searchTask release];
    [browserController release];
    [prefsController release];
    [logPath release];

    [super dealloc];
}

#pragma mark -
#pragma mark NSApplicationDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
    // offer to move app to Applications folder
    //
    PFMoveToApplicationsFolderIfNecessary();

    // definitively set Sparkle updater delegate in code
    //
    NSAssert( ! [[SUUpdater sharedUpdater] delegate], @"Sparkle updater delegate should only be set in code since in multiple XIBs");
    
    [[SUUpdater sharedUpdater] setDelegate:self];
    
    // setup logging & fire up main functionality
    //
    self.logPath = [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Logs/TileMill.log"];

    [self showBrowserWindow:self];
    [self startTileMill];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)tilemillAppDelegate
{
    return NO;
}

- (BOOL)applicationShouldHandleReopen:(NSApplication *)theApplication hasVisibleWindows:(BOOL)flag
{
    if ( ! flag)
        [self.browserController showWindow:self];
    
    return YES;
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender
{
    return ([self.browserController browserShouldQuit] ? NSTerminateNow : NSTerminateCancel);
}

- (void)applicationWillTerminate:(NSNotification *)notification
{
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    self.shouldAttemptRestart = NO;

    // This doesn't run when app is forced to quit, so the child process is left running.
    // We clean up any orphan processes in [self startTileMill].
    //
    [self stopTileMill];
}

#pragma mark -

- (void)startTileMill
{
    NSURL *nodeExecURL = [[NSBundle mainBundle] URLForResource:@"node" withExtension:@""];

    if ( ! nodeExecURL)
    {
        NSLog(@"node is missing.");

        [self presentFatalError];
    }
    
    // Look for orphan node processes from previous crashes.
    //
    for (NSRunningApplication *app in [[NSWorkspace sharedWorkspace] runningApplications])
        if ([[app executableURL] isEqual:nodeExecURL])
            if ( ! [app forceTerminate])
                [self writeToLog:@"Failed to terminate orphan tilemill process."];
    
    if (self.searchTask)
        self.searchTask = nil;

    self.shouldAttemptRestart = YES;

    NSString *command = [NSString stringWithFormat:@"%@/index.js", [[NSBundle mainBundle] resourcePath]];
    
    self.searchTask = [[TileMillChildProcess alloc] initWithBasePath:[[NSBundle mainBundle] resourcePath] command:command];
    
    [self.searchTask setDelegate:self];
    [self.searchTask startProcess];
}

- (void)stopTileMill
{
    if (self.searchTask)
    {
        if (self.searchTask.launched)
            [self.searchTask stopProcess];
        
        self.searchTask = nil;
    }
}

- (IBAction)showBrowserWindow:(id)sender
{
    if ( ! self.browserController)
        self.browserController = [[[TileMillBrowserWindowController alloc] initWithWindowNibName:@"TileMillBrowserWindow"] autorelease];
    
    [self.browserController showWindow:self];
}

- (void)writeToLog:(NSString *)message
{
    if ( ! [[NSFileManager defaultManager] fileExistsAtPath:self.logPath])
    {
        NSError *error = nil;
        
        if ( ! [@"" writeToFile:self.logPath atomically:YES encoding:NSUTF8StringEncoding error:&error])
            NSLog(@"Error creating log file at %@.", self.logPath);
    }
    
    NSFileHandle *logFile = [NSFileHandle fileHandleForWritingAtPath:logPath];
    
    [logFile seekToEndOfFile];
    [logFile writeData:[message dataUsingEncoding:NSUTF8StringEncoding]];
    [logFile closeFile];
}

- (void)presentFatalError
{
    NSAlert *alert = [NSAlert alertWithMessageText:@"There was a problem trying to start the server process"
                                     defaultButton:@"OK"
                                   alternateButton:@"Contact Support"
                                       otherButton:nil
                         informativeTextWithFormat:@"TileMill experienced a fatal error while trying to start the server process. Please restart the application. If this persists, please contact support."];
    
    NSInteger status = [alert runModal];
    
    if (status == NSAlertAlternateReturn)
        [self openDiscussions:self];
    
    self.shouldAttemptRestart = NO;
    
    [self stopTileMill];
}

#pragma mark -

- (IBAction)openDocumentsFolder:(id)sender
{
    [[NSWorkspace sharedWorkspace] openFile:[[NSUserDefaults standardUserDefaults] stringForKey:@"filesPath"]];
}

- (IBAction)openHelp:(id)sender
{
    [self.browserController loadRequestURL:[NSURL URLWithString:[NSString stringWithFormat:@"http://localhost:%i/#!/manual", self.searchTask.port]]];

    // give page time to load, then be sure browser window is visible
    //
    [self performSelector:@selector(showBrowserWindow:) withObject:self afterDelay:0.25];
}

- (IBAction)openDiscussions:(id)sender
{
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://support.mapbox.com/discussions/tilemill"]];
}

- (IBAction)openOnlineHelp:(id)sender
{
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://mapbox.com/tilemill/docs/"]];
}

- (IBAction)openConsole:(id)sender
{
    // we do this twice to make sure the right window comes forward (see #940)
    //
    [[NSWorkspace sharedWorkspace] openFile:self.logPath withApplication:@"Console"];
    [[NSWorkspace sharedWorkspace] openFile:self.logPath withApplication:@"Console" andDeactivate:YES];
}

- (IBAction)openPreferences:(id)sender
{
    if ( ! self.prefsController)
        self.prefsController = [[[TileMillPrefsWindowController alloc] initWithWindowNibName:@"TileMillPrefsWindow"] autorelease];
    
    [self.prefsController showWindow:self];
}

#pragma mark -
#pragma mark TileMillChildProcessDelegate

- (void)childProcess:(TileMillChildProcess *)process didSendOutput:(NSString *)output
{
    [self writeToLog:output];
    
    if ([[NSPredicate predicateWithFormat:@"SELF contains 'EADDRINUSE'"] evaluateWithObject:output])
    {
        // port in use error
        //
        NSAlert *alert = [NSAlert alertWithMessageText:@"Port already in use"
                                         defaultButton:@"OK"
                                       alternateButton:nil
                                           otherButton:nil
                             informativeTextWithFormat:@"TileMill's port is already in use by another application on the system. Please terminate that application and relaunch TileMill."];
        
        [alert runModal];
    
        self.shouldAttemptRestart = NO;
        
        [self stopTileMill];
    }
    else if (self.fatalErrorCaught)
    {
        // generic fatal error
        //
        [self presentFatalError];
    }
    else if ([[NSPredicate predicateWithFormat:@"SELF contains 'throw e; // process'"] evaluateWithObject:output])
    {
        // We noticed a fatal error, so let's mark it, but not do
        // anything yet. Let's get more output so that we can 
        // further evaluate & act accordingly.

        self.fatalErrorCaught = YES;
    }
}

- (void)childProcessDidFinish:(TileMillChildProcess *)process
{
    NSLog(@"Finished");
    
    if (self.shouldAttemptRestart)
    {
        NSLog(@"Restart");

        [self startTileMill];
    }
}

- (void)childProcessDidSendFirstData:(TileMillChildProcess *)process;
{
    [self.browserController loadInitialRequestWithPort:self.searchTask.port];
}

#pragma mark -
#pragma mark SUUpdaterDelegate

- (void)updater:(SUUpdater *)updater didFinishLoadingAppcast:(SUAppcast *)appcast
{
    // Borrowed a bit from SUUpdater as a way to get this stuff outside of the feed URL.
    // A little hacky with KVC stuff, but it'll do the trick.
    //
    BOOL sendingSystemProfile = [updater sendsSystemProfile];

    NSDate *lastSubmitDate = [[NSUserDefaults standardUserDefaults] objectForKey:@"SULastProfileSubmitDateKey"];
    
    if ( ! lastSubmitDate)
        lastSubmitDate = [NSDate distantPast];
    
    const NSTimeInterval oneWeek = 60 * 60 * 24 * 7;
    
    sendingSystemProfile &= (-[lastSubmitDate timeIntervalSinceNow] >= oneWeek);

    NSArray *parameters = [NSArray array];
    
    if ([self respondsToSelector:@selector(feedParametersForUpdater:sendingSystemProfile:)])
        parameters = [parameters arrayByAddingObjectsFromArray:[self feedParametersForUpdater:updater sendingSystemProfile:sendingSystemProfile]];

    if (sendingSystemProfile)
        parameters = [parameters arrayByAddingObjectsFromArray:[updater valueForKeyPath:@"host.systemProfile"]];

    if ([parameters count])
    {
        NSMutableString *profileURLString = [NSMutableString stringWithString:@"http://mapbox.com/tilemill/platforms/osx/profile.html?"];

        NSMutableArray *fields = [NSMutableArray array];

        for (NSDictionary *item in parameters)
            [fields addObject:[NSString stringWithFormat:@"%@=%@", [item objectForKey:@"displayKey"], [item objectForKey:@"displayValue"]]];
        
        [profileURLString appendString:[fields componentsJoinedByString:@"&"]];
        
        NSWindow *profileWindow = [[NSWindow alloc] initWithContentRect:NSZeroRect 
                                                              styleMask:NSBorderlessWindowMask 
                                                                backing:NSBackingStoreRetained
                                                                  defer:NO];
        
        WebView *profileWebView = [[[WebView alloc] initWithFrame:profileWindow.frame frameName:nil groupName:nil] autorelease];
        
        profileWebView.frameLoadDelegate = self;
        
        [profileWindow.contentView addSubview:profileWebView];
        
        [profileWebView.mainFrame loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:[profileURLString stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]]]];
    }
}

#pragma mark -
#pragma mark WebFrameLoadDelegate

- (void)webView:(WebView *)sender didFailLoadWithError:(NSError *)error forFrame:(WebFrame *)frame
{
    [frame.webView.window close];
}

- (void)webView:(WebView *)sender didFinishLoadForFrame:(WebFrame *)frame
{
    [frame.webView.window close];
}

@end