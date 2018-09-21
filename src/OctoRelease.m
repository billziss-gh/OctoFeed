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
@property (copy) NSString *repository;
@property (copy) NSArray<NSBundle *> *targetBundles;
@property (retain) NSURLSession *session;
@property (copy) NSURL *cacheBaseURL;
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

+ (OctoRelease *)releaseWithRepository:(NSString *)repository
    targetBundles:(NSArray<NSBundle *> *)bundles session:(NSURLSession *)session
{
    NSString *service = 0 != [repository length] ? [[repository pathComponents] firstObject] : @"";
    Class cls = [classDictionary objectForKey:service];
    return [[[cls alloc]
        initWithRepository:repository targetBundles:bundles session:session] autorelease];
}

- (id)initWithRepository:(NSString *)repository
    targetBundles:(NSArray<NSBundle *> *)bundles session:(NSURLSession *)session;
{
    self = [super init];
    if (nil == self)
        return nil;

    NSString *mainIdentifier = [[NSBundle mainBundle] bundleIdentifier];
    NSString *octoIdentifier = [[NSBundle bundleForClass:[self class]] bundleIdentifier];
    if (nil == mainIdentifier) /* happens during XCTest! */
        mainIdentifier = octoIdentifier;

    self.repository = repository;
    self.targetBundles = bundles;
    self.session = session;
    self.cacheBaseURL = [[[[[NSFileManager defaultManager]
        URLsForDirectory:NSCachesDirectory inDomains:NSUserDomainMask] firstObject]
        URLByAppendingPathComponent:mainIdentifier]
        URLByAppendingPathComponent:octoIdentifier];

    return self;
}

- (void)dealloc
{
    self.repository = nil;
    self.targetBundles = nil;
    self.session = nil;
    self.cacheBaseURL = nil;
    self.downloadedAssets = nil;
    self.extractedAssets = nil;
    self.verifiedAssets = nil;

    [super dealloc];
}

- (void)fetch:(void (^)(NSError *))completion
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

- (NSURL *)cacheURL
{
    if (0 == [self.releaseVersion length])
        [NSException raise:NSInvalidArgumentException format:@"%s empty releaseVersion", __FUNCTION__];

    return [self.cacheBaseURL URLByAppendingPathComponent:self.releaseVersion];
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
        [NSException raise:NSInvalidArgumentException format:@"%s empty releaseVersion", __FUNCTION__];

    NSMutableString *str = [NSMutableString stringWithFormat:@"%@\n%d\n%c\n",
        self.releaseVersion, self.prerelease, (char)state];
    for (id asset in self.releaseAssets)
        [str appendFormat:@"%@\n", [asset absoluteString]];

    NSURL *cacheURL = self.cacheURL;
    BOOL res = [[NSFileManager defaultManager]
        createDirectoryAtURL:cacheURL
        withIntermediateDirectories:YES
        attributes:nil
        error:0];
    res = res && [str
        writeToURL:[cacheURL URLByAppendingPathComponent:@"state"]
        atomically:YES
        encoding:NSUTF8StringEncoding
        error:0];
    if (!res)
        return;

    self.state = state;
}
@end
