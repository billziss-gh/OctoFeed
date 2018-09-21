/**
 * @file OctoRelease.h
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

typedef NS_ENUM(NSUInteger, OctoReleaseState)
{
    OctoReleaseEmpty                    = 0,
    OctoReleaseFetched                  = 'F',
    OctoReleaseDownloaded               = 'D',
    OctoReleaseExtracted                = 'X',
    OctoReleaseVerified                 = 'V',
    OctoReleaseInstalled                = 'I',
    OctoReleaseLaunched                 = 'L',
};

@interface OctoRelease : NSObject
+ (void)registerClass:(NSString *)service;
+ (OctoRelease *)releaseWithRepository:(NSString *)repository
    targetBundles:(NSArray<NSBundle *> *)bundles session:(NSURLSession *)session;
- (id)initWithRepository:(NSString *)repository
    targetBundles:(NSArray<NSBundle *> *)bundles session:(NSURLSession *)session;
- (void)fetch:(void (^)(NSError *))completion;
- (void)downloadAssets:(void (^)(NSError *))completion;
- (void)extractAssets:(void (^)(NSError *))completion;
- (void)verifyAssets:(void (^)(NSError *))completion;
- (void)installAssets:(void (^)(NSError *))completion;
- (NSString *)repository;
- (NSArray<NSBundle *> *)targetBundles;
- (NSURL *)cacheBaseURL;
- (NSURL *)cacheURL;
- (NSURLSession *)session;
- (NSString *)releaseVersion;
- (BOOL)prerelease;
- (NSArray<NSURL *> *)releaseAssets;
- (NSArray<NSURL *> *)downloadedAssets;
- (NSArray<NSURL *> *)extractedAssets;
- (NSArray<NSURL *> *)verifiedAssets;
- (OctoReleaseState)state;
@end
