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
    OctoFeed *feed = [OctoFeed mainBundleFeed];
    OctoRelease *release = [OctoRelease
        releaseWithRepository:nil
        targetBundles:feed.targetBundles
        session:feed.session];
    if (OctoReleaseExtracted == release.state)
    {
        self.label.stringValue = @"Installing";
        [release installAssets:^(
            NSDictionary<NSURL *, NSURL *> *assets, NSDictionary<NSURL *, NSError *> *errors)
        {
            if (0 == errors.count)
            {
                self.label.stringValue = @"Relaunching";
                [feed relaunch:[assets allValues]];
            }
            else
            {
                self.label.stringValue = @"Running";
                [feed activate];
            }
        }];
    }
    else
    {
        self.label.stringValue = @"Running";
        [feed activate];
    }
}
@end
