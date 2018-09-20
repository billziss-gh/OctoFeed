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

#import <Cocoa/Cocoa.h>

typedef NS_ENUM(NSUInteger, OctoReleaseState)
{
    OctoReleaseReady                    = 0,
    OctoReleaseDownloaded               = 'D',
    OctoReleaseExtracted                = 'X',
    OctoReleaseVerified                 = 'V',
    OctoReleaseInstalled                = 'I',
    OctoReleaseLaunched                 = 'L',
};

typedef void (^OctoReleaseCompletion)(NSArray<NSURL *> *assets, NSError *error);

@interface OctoRelease : NSObject
- (void)downloadAssets:(OctoReleaseCompletion)completion;
- (void)extractAssets:(OctoReleaseCompletion)completion;
- (void)verifyAssets:(OctoReleaseCompletion)completion;
- (void)installAssets:(OctoReleaseCompletion)completion;
- (void)launchAssets:(OctoReleaseCompletion)completion;
- (void)clearAssets:(OctoReleaseCompletion)completion;
@property (readonly) NSString *releaseVersion;
@property (readonly) BOOL prerelease;
@property (readonly) NSArray<NSURL *> *releaseAssets;
@property (readonly) NSArray<NSURL *> *downloadedAssets;
@property (readonly) NSArray<NSURL *> *extractedAssets;
@property (readonly) NSString *currentVersion;
@property (readonly) NSURL *currentSignature;
@property (readonly) OctoReleaseState state;
@end

@interface OctoFeed : NSObject
+ (NSURL *)releaseURLFromRepository:(NSString *)repository;
+ (OctoFeed *)mainBundleFeed;
- (id)initWithBundle:(NSBundle *)bundle;
- (BOOL)activate;
- (void)deactivate;
@property (copy) NSString *repository;
@property (assign) NSTimeInterval checkPeriod;
@property (copy) NSString *currentVersion;
@property (copy) NSURL *currentSignature;
@property (copy) NSURL *releaseCacheURL;
@property (readonly) OctoRelease *latestRelease;
@end

extern NSString *OctoFeedNotification;

extern NSString *OctoFeedRepositoryKey;
extern NSString *OctoFeedCheckPeriodKey;
extern NSString *OctoFeedLastCheckTimeKey;
