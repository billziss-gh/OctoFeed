/**
 * @file OctoFeed.h
 *
 * @copyright 2018 Bill Zissimopoulos
 */
/*
 * This file is part of OctoFeed.
 *
 * It is licensed under the MIT license. The full license text can be found
 * in the License.txt file at the root of this project.
 */

#import <Foundation/Foundation.h>
#import <OctoFeed/NSString+Version.h>
#import <OctoFeed/NSTask+Relaunch.h>
#import <OctoFeed/OctoExtractor.h>
#import <OctoFeed/OctoRelease.h>
#import <OctoFeed/OctoVerifier.h>

typedef NS_ENUM(NSUInteger, OctoFeedInstallPolicy)
{
    OctoFeedInstallNone                 = 0,
    OctoFeedInstallAtLaunch             = 'L',
    OctoFeedInstallAtQuit               = 'Q',
    OctoFeedInstallWhenReady            = 'R',
};

@interface OctoFeed : NSObject
+ (OctoFeed *)mainBundleFeed;
- (id)initWithBundle:(NSBundle *)bundle;
- (BOOL)activateWithInstallPolicy:(OctoFeedInstallPolicy)policy;
- (void)deactivate;
- (OctoRelease *)currentRelease;
- (NSError *)clearThisAndPriorReleases:(OctoRelease *)release;
@property (copy) NSString *repository;
@property (assign) NSTimeInterval checkPeriod;
@property (copy) NSArray<NSBundle *> *targetBundles;
@property (retain) NSURLSession *session;
@property (copy) NSURL *cacheBaseURL;
@end

extern NSString *OctoNotification;
extern NSString *OctoNotificationReleaseKey;
extern NSString *OctoNotificationReleaseStateKey;

extern NSString *OctoRepositoryKey;
extern NSString *OctoCheckPeriodKey;
extern NSString *OctoLastCheckTimeKey;
