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

    OctoRelease *release = [[OctoFeed mainBundleFeed] cachedReleaseFetchSynchronously];
    if (OctoReleaseReadyToInstall == release.state)
        [release installAssets:^(
            NSDictionary<NSURL *, NSURL *> *assets, NSDictionary<NSURL *, NSError *> *errors)
        {
            [release clear];

            if (0 < assets.count)
                /* +[NSTask relaunch] does not return! */
                [NSTask relaunchWithURL:[[assets allValues] firstObject]];

            [[OctoFeed mainBundleFeed] activate];
        }];
    else
        [[OctoFeed mainBundleFeed] activate];
}

- (IBAction)relaunchAction:(id)sender
{
    [NSTask relaunch];
}
@end
