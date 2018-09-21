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
#import <OctoFeed/OctoRelease.h>

@interface OctoFeed : NSObject
+ (OctoFeed *)mainBundleFeed;
- (id)initWithBundle:(NSBundle *)bundle;
- (BOOL)activate;
- (void)deactivate;
@property (copy) NSString *repository;
@property (assign) NSTimeInterval checkPeriod;
@property (copy) NSArray<NSBundle *> *targetBundles;
@end

extern NSString *OctoFeedNotification;

extern NSString *OctoFeedRepositoryKey;
extern NSString *OctoFeedCheckPeriodKey;
extern NSString *OctoFeedLastCheckTimeKey;
