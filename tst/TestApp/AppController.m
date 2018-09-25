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

    [OctoRelease requireCodeSignature:NO matchesTarget:NO];
    OctoFeedInstallPolicy policy = [[NSUserDefaults standardUserDefaults]
        integerForKey:@"TestAppInstallPolicy"];
    BOOL res = [[OctoFeed mainBundleFeed] activateWithInstallPolicy:policy];

    self.octoLabel.stringValue = res ? @"OctoFeed activated" : @"";
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
}

- (IBAction)relaunchAction:(id)sender
{
    [NSTask relaunch];
}
@end
