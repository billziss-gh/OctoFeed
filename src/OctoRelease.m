/**
 * @file OctoRelease.m
 *
 * @copyright 2018 Bill Zissimopoulos
 */
/*
 * This file is part of OctoFeed.
 *
 * It is licensed under the MIT license. The full license text can be found
 * in the License.txt file at the root of this project.
 */

#import <OctoFeed/OctoRelease.h>

static NSMutableDictionary *classDictionary;

@interface OctoRelease ()
@property (copy) NSArray<NSBundle *> *targetBundles;
@property (retain) NSURLSession *session;
@property (copy) NSURL *cacheURL;
@property (copy) NSArray<NSURL *> *downloadedAssets;
@property (copy) NSArray<NSURL *> *extractedAssets;
@property (copy) NSArray<NSURL *> *verifiedAssets;
@property (assign) OctoReleaseState state;
@end

@implementation OctoRelease
+ (void)load
{
    classDictionary = [[NSMutableDictionary alloc] init];
}

+ (void)registerClass:(NSString *)service
{
    [classDictionary setObject:[self class] forKey:service];
}

+ (OctoRelease *)releaseFromRepository:(NSString *)repository
    targetBundles:(NSArray<NSBundle *> *)bundles session:(NSURLSession *)session
{
    NSString *service = [[repository pathComponents] firstObject];
    Class cls = [classDictionary objectForKey:service];
    return [[[cls alloc] initWithTargetBundles:bundles session:session] autorelease];
}

- (id)initWithTargetBundles:(NSArray<NSBundle *> *)bundles session:(NSURLSession *)session
{
    self = [super init];
    if (nil == self)
        return nil;

    self.targetBundles = bundles;
    self.session = session;
    self.cacheURL = [[[[[NSFileManager defaultManager]
        URLsForDirectory:NSCachesDirectory inDomains:NSUserDomainMask] firstObject]
        URLByAppendingPathComponent:[[NSBundle mainBundle] bundleIdentifier]]
        URLByAppendingPathComponent:[[NSBundle bundleForClass:[self class]] bundleIdentifier]];

    return self;
}

- (void)dealloc
{
    self.targetBundles = nil;
    self.session = nil;
    self.cacheURL = nil;
    self.downloadedAssets = nil;
    self.extractedAssets = nil;
    self.verifiedAssets = nil;

    [super dealloc];
}

- (void)fetchFromRepository:(NSString *)repository completion:(void (^)(NSError *))completion
{
}

- (void)downloadAssets:(void (^)(NSError *))completion
{
}

- (void)extractAssets:(void (^)(NSError *))completion
{
}

- (void)verifyAssets:(void (^)(NSError *))completion
{
}

- (void)installAssets:(void (^)(NSError *))completion
{
}

- (NSString *)releaseVersion
{
    return nil;
}

- (BOOL)prerelease
{
    return NO;
}

- (NSArray<NSURL *> *)releaseAssets
{
    return nil;
}

- (void)_setState:(OctoReleaseState)state persistent:(BOOL)persistent
{
    if (!persistent)
    {
        self.state = state;
        return;
    }

    if (0 == [self.releaseVersion length])
        return;

    NSString *str = [NSString stringWithFormat:@"%@\n%d\n%c\n",
        self.releaseVersion, self.prerelease, (char)self.state];
    BOOL res = [str
        writeToURL:[self.cacheURL URLByAppendingPathComponent:@"state"]
        atomically:YES
        encoding:NSUTF8StringEncoding
        error:0];
    if (!res)
        return;

    self.state = state;
}
@end
