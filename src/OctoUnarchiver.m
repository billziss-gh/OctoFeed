/**
 * @file OctoUnarchiver.m
 *
 * @copyright 2018 Bill Zissimopoulos
 */
/*
 * This file is part of OctoFeed.
 *
 * It is licensed under the MIT license. The full license text can be found
 * in the License.txt file at the root of this project.
 */

#import "OctoUnarchiver.h"

@interface OctoUnarchiver ()
@property (copy) NSURL *url;
@end

@implementation OctoUnarchiver
+ (void)unarchiveURL:(NSURL *)src
    toURL:(NSURL *)dst
    completion:(void (^)(NSError *error))completion
{
    OctoUnarchiver *unarchiver = [[[[self class] alloc] initWithURL:src] autorelease];
    [unarchiver unarchiveToURL:dst completion:completion];
}

- (id)initWithURL:(NSURL *)url
{
    self = [super init];
    if (nil == self)
        return nil;

    self.url = url;

    return self;
}

- (void)dealloc
{
    self.url = nil;

    [super dealloc];
}

- (void)unarchiveToURL:(NSURL *)dst
    completion:(void (^)(NSError *error))completion
{
}
@end
