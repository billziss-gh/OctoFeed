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

/**
 * OctoFeed installation policy.
 */
typedef NS_ENUM(NSUInteger, OctoFeedInstallPolicy)
{
    /**
     * Releases will be checked, but no installation will be performed.
     */
    OctoFeedInstallNone                 = 0,

    /**
     * Releases will be downloaded and prepared for installation.
     * During activation a release will be installed if it is ready to install.
     */
    OctoFeedInstallAtActivation         = 'A',

    /**
     * Releases will be downloaded and prepared for installation.
     * During app termination a release will be installed if it is ready to install.
     */
    OctoFeedInstallAtQuit               = 'Q',

    /**
     * Releases will be downloaded and prepared for installation.
     * Releases will not be installed automatically, but a notification will be posted to allow
     * the application to initiate an install if it so chooses.
     */
    OctoFeedInstallWhenReady            = 'R',
};

/**
 * OctoFeed manages the overall update process. It checks for new updates, downloads them,
 * extracts them and installs them according to the specified policy.
 */
@interface OctoFeed : NSObject

/**
 * Returns the default OctoFeed instance, which manages updates for the main bundle.
 *
 * The bundle must contain an "OctoRepository" key that points to a repository that contains new
 * releases. For example, this project's own repository would be specified as
 * "github.com/billziss-gh/OctoFeed."
 */
+ (OctoFeed *)mainBundleFeed;

/**
 * Initializes an OctoFeed instance to manage updates for the specified bundle.
 *
 * The bundle must contain an "OctoRepository" key that points to a repository that contains new
 * releases. For example, this project's own repository would be specified as
 * "github.com/billziss-gh/OctoFeed."
 */
- (id)initWithBundle:(NSBundle *)bundle;

/**
 * Activates the OctoFeed instance with the specified install policy.
 * Depending on the policy the instance will check for new releases, download them,
 * extract them and install them.
 */
- (BOOL)activateWithInstallPolicy:(OctoFeedInstallPolicy)policy;

/**
 * Deactivates the OctoFeed object.
 */
- (void)deactivate;

/**
 * Check for new releases now.
 */
- (void)check;

/**
 * Returns the current release, if any.
 *
 * When OctoFeed finds a new release, this method returns non-nil.
 */
- (OctoRelease *)currentRelease;

/**
 * Clears any cached information (downloaded files, etc.) for the specified release and
 * any releases with earlier versions.
 */
- (NSError *)clearThisAndPriorReleases:(OctoRelease *)release;

/**
 * The repository to check for new releases.
 *
 * For example, this project's own repository would be specified as
 * "github.com/billziss-gh/OctoFeed."
 */
@property (copy) NSString *repository;

/**
 * The check period: how often to perform a new release check.
 */
@property (assign) NSTimeInterval checkPeriod;

/**
 * The bundles that can be updated by a new release.
 *
 * Normally this array contains only the main bundle.
 */
@property (copy) NSArray<NSBundle *> *targetBundles;

/**
 * A URL sesssion to use for downloading releases.
 *
 * If a custom session is assigned, it MUST use [NSOperationQueue mainQueue] as its delegateQueue.
 */
@property (retain) NSURLSession *session;

/**
 * The base directory where cached information for all releases is stored.
 *
 * The default value is a location under ~/Library/Caches.
 */
@property (copy) NSURL *cacheBaseURL;
@end

/**
 * Posted whenever the state of a release changes.
 *
 * The notification object is the OctoFeed instance posting the notification.
 * The userInfo dictionary contains the release under the OctoNotificationReleaseKey and
 * the release state at the time of posting under the OctoNotificationReleaseStateKey.
 */
extern NSString *OctoNotification;
extern NSString *OctoNotificationReleaseKey;
extern NSString *OctoNotificationReleaseStateKey;

/**
 * Bundle key that points to a repository that contains new releases.
 * For example, this project's own repository would be specified as
 * "github.com/billziss-gh/OctoFeed."
 */
extern NSString *OctoRepositoryKey;
extern NSString *OctoCheckPeriodKey;
extern NSString *OctoLastCheckTimeKey;
