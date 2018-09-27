/**
 * @file OctoFeed/OctoGitHubRelease.h
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

@interface OctoGitHubRelease : OctoRelease
- (void)fetch:(void (^)(NSError *))completion;
@end
