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
@property (assign) IBOutlet NSTextField *label;
@end

@implementation AppController
- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    self.label.stringValue = [NSString stringWithFormat:@"PID %d", (int)getpid()];

    OctoFeedInstallPolicy policy = [[NSUserDefaults standardUserDefaults]
        integerForKey:@"TestAppInstallPolicy"];
    [[OctoFeed mainBundleFeed] activateWithInstallPolicy:policy];
}

- (IBAction)relaunchAction:(id)sender
{
    [NSTask relaunch];
}
@end
