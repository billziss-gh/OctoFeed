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
    OctoReleaseReadyToInstall           = OctoReleaseExtracted,
    OctoReleaseInstalled                = 'I',
};

typedef void (^OctoReleaseCompletion)(
    NSDictionary<NSURL *, NSURL *> *, NSDictionary<NSURL *, NSError *> *);

@interface OctoRelease : NSObject
+ (void)registerClass:(NSString *)service;
+ (void)requireCodeSignature:(BOOL)require matchesTarget:(BOOL)matches;
+ (OctoRelease *)releaseWithRepository:(NSString *)repository
    targetBundles:(NSArray<NSBundle *> *)bundles session:(NSURLSession *)session;
- (id)initWithRepository:(NSString *)repository
    targetBundles:(NSArray<NSBundle *> *)bundles session:(NSURLSession *)session;
- (void)fetch:(void (^)(NSError *))completion;
- (BOOL)fetchSynchronouslyIfAble:(NSError **)errorp;
- (void)downloadAssets:(OctoReleaseCompletion)completion;
- (void)extractAssets:(OctoReleaseCompletion)completion;
- (void)installAssets:(OctoReleaseCompletion)completion;
- (NSError *)clear;
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
- (OctoReleaseState)state;
@end

@interface OctoRelease (Extensions)
@property (copy) NSString *_releaseVersion;
@property (assign) BOOL _prerelease;
@property (copy) NSArray<NSURL *> *_releaseAssets;
@property (copy) NSArray<NSURL *> *_downloadedAssets;
@property (copy) NSArray<NSURL *> *_extractedAssets;
@property (assign) OctoReleaseState _state;
- (void)_setState:(OctoReleaseState)state persistent:(BOOL)persistent;
@end
