/**
 * @file NSObject+OctoExtensions.m
 *
 * @copyright 2018 Bill Zissimopoulos
 */
/*
 * This file is part of OctoFeed.
 *
 * It is licensed under the MIT license. The full license text can be found
 * in the License.txt file at the root of this project.
 */

#import "NSObject+OctoExtensions.h"

@implementation NSObject (OctoExtensions)
- (void)octoPerformBlock:(void (^)(void))block afterDelay:(NSTimeInterval)delay
{
    [self
        performSelector:@selector(_octoDelayedPerformBlock:)
        withObject:[[block copy] autorelease]
        afterDelay:delay];
}

- (void)_octoDelayedPerformBlock:(void (^)(void))block
{
    block();
}
@end
