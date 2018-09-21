/**
 * @file OctoRelease+Extensions.h
 *
 * @copyright 2018 Bill Zissimopoulos
 */
/*
 * This file is part of OctoFeed.
 *
 * It is licensed under the MIT license. The full license text can be found
 * in the License.txt file at the root of this project.
 */

#import "OctoRelease.h"

@interface OctoRelease (Extensions)
@property (copy) NSString *_releaseVersion;
@property (assign) BOOL _prerelease;
@property (copy) NSArray<NSURL *> *_releaseAssets;
@property (copy) NSArray<NSURL *> *_downloadedAssets;
@property (copy) NSArray<NSURL *> *_extractedAssets;
@property (assign) OctoReleaseState _state;
- (void)_setState:(OctoReleaseState)state persistent:(BOOL)persistent;
@end
