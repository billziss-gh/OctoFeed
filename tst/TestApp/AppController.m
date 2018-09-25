/**
 * @file AppController.m
 *
 * @copyright 2018 Bill Zissimopoulos
 */
/*
 * This file is part of OctoFeed.
 *
 * It is licensed under the MIT license. The full license text can be found
 * in the License.txt file at the root of this project.
 */

#import "AppController.h"
#import <OctoFeed/OctoFeed.h>

@interface AppController ()
@property (assign) IBOutlet NSWindow *window;
@property (assign) IBOutlet NSTextField *versionLabel;
@property (assign) IBOutlet NSTextField *pidLabel;
@property (assign) IBOutlet NSTextField *octoLabel;
@property (assign) IBOutlet NSButton *installNoneRadio;
@property (assign) IBOutlet NSButton *installAtActivationRadio;
@property (assign) IBOutlet NSButton *installAtQuitRadio;
@property (assign) IBOutlet NSButton *installWhenReadyRadio;
@end

@implementation AppController
- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    [[NSNotificationCenter defaultCenter]
        addObserver:self
        selector:@selector(octoNotification:)
        name:OctoNotification
        object:nil];

    self.versionLabel.stringValue = [[NSBundle mainBundle]
        objectForInfoDictionaryKey:(NSString *)kCFBundleVersionKey];
    self.pidLabel.stringValue = [NSString stringWithFormat:@"PID %d", (int)getpid()];

    OctoFeedInstallPolicy policy = [[NSUserDefaults standardUserDefaults]
        integerForKey:@"TestAppInstallPolicy"];
    switch (policy)
    {
    default:
        policy = OctoFeedInstallNone;
    case OctoFeedInstallNone:
        self.installNoneRadio.state = NSOnState;
        break;
    case OctoFeedInstallAtActivation:
        self.installAtActivationRadio.state = NSOnState;
        break;
    case OctoFeedInstallAtQuit:
        self.installAtQuitRadio.state = NSOnState;
        break;
    case OctoFeedInstallWhenReady:
        self.installWhenReadyRadio.state = NSOnState;
        break;
    }

    [OctoRelease requireCodeSignature:NO matchesTarget:NO];
    BOOL res = [[OctoFeed mainBundleFeed] activateWithInstallPolicy:policy];

    self.octoLabel.stringValue = res ? @"Activated" : @"";
}

- (void)applicationWillTerminate:(NSNotification *)notification
{
    [[NSNotificationCenter defaultCenter]
        removeObserver:self
        name:OctoNotification
        object:nil];
}

- (void)octoNotification:(NSNotification *)notification
{
    NSLog(@"%@", notification);

    OctoReleaseState state = [[notification.userInfo objectForKey:OctoNotificationReleaseStateKey]
        unsignedIntegerValue];
    switch (state)
    {
    case OctoReleaseEmpty:
        self.octoLabel.stringValue = @"OctoReleaseEmpty";
        break;
    case OctoReleaseFetched:
        self.octoLabel.stringValue = @"OctoReleaseFetched";
        break;
    case OctoReleaseDownloaded:
        self.octoLabel.stringValue = @"OctoReleaseDownloaded";
        break;
    case OctoReleaseReadyToInstall:
        if (OctoFeedInstallWhenReady == [[NSUserDefaults standardUserDefaults]
            integerForKey:@"TestAppInstallPolicy"])
        {
            NSAlert *alert = [[[NSAlert alloc] init] autorelease];
            [alert addButtonWithTitle:@"Yes"];
            [alert addButtonWithTitle:@"No"];
            alert.alertStyle = NSAlertStyleInformational;
            alert.messageText = @"Update is ready!";
            alert.informativeText = @"A new update is ready. Do you wish to install it?";
            NSModalResponse resp = [alert runModal];
            if (NSAlertFirstButtonReturn == resp)
            {
                OctoRelease *release = [notification.userInfo objectForKey:OctoNotificationReleaseKey];
                [release installAssetsSynchronously:^(
                    NSDictionary<NSURL *, NSURL *> *assets, NSDictionary<NSURL *, NSError *> *errors)
                {
                    [[OctoFeed mainBundleFeed] clearThisAndPriorReleases:release];
                    if (0 < assets.count)
                        /* +[NSTask relaunch] does not return! */
                        [NSTask relaunchWithURL:[[assets allValues] firstObject]];
                }];
            }
        }
        self.octoLabel.stringValue = @"OctoReleaseReadyToInstall";
        break;
    case OctoReleaseInstalled:
        self.octoLabel.stringValue = @"OctoReleaseInstalled";
        break;
    default:
        self.octoLabel.stringValue = @"UNKNOWN";
        break;
    }
}

- (IBAction)installRadioAction:(id)sender
{
    [[NSUserDefaults standardUserDefaults]
        setInteger:[sender tag] forKey:@"TestAppInstallPolicy"];
}

- (IBAction)clearLastCheckTimeAction:(id)sender
{
    [[NSUserDefaults standardUserDefaults]
        removeObjectForKey:OctoLastCheckTimeKey];
}

- (IBAction)relaunchAction:(id)sender
{
    [NSTask relaunch];
}
@end
