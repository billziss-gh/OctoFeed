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

#if 0
    OctoFeed *feed = [OctoFeed mainBundleFeed];
    OctoRelease *release = [OctoRelease
        releaseWithRepository:nil
        targetBundles:feed.targetBundles
        session:feed.session];
    if (OctoReleaseExtracted == release.state)
    {
        [release installAssets:^(
            NSDictionary<NSURL *, NSURL *> *assets, NSDictionary<NSURL *, NSError *> *errors)
        {
            if (0 < assets.count)
                [NSTask relaunchWithURL:[[assets allValues] firstObject]];
            else
                [feed activate];
        }];
    }
    else
        [feed activate];
#endif
}

- (IBAction)relaunchAction:(id)sender
{
    [NSTask relaunch];
}
@end
