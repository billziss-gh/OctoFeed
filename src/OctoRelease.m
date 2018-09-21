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
#import "OctoUnarchiver.h"

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
    dispatch_group_t group = dispatch_group_create();
    __block NSMutableArray *downloadedAssets = [NSMutableArray array];
    __block NSMutableArray *errors = [NSMutableArray array];

    NSMutableArray *releaseAssets = nil;
    if (1 < self.releaseAssets.count)
    {
        releaseAssets = [NSMutableArray array];
        for (NSURL *releaseAsset in self.releaseAssets)
        {
            NSString *name = [[releaseAsset lastPathComponent] stringByDeletingPathExtension];
            if ([name hasSuffix:@"-mac"] || [name containsString:@"-mac-"] ||
                [name hasSuffix:@"-osx"] || [name containsString:@"-osx-"])
                [releaseAssets addObject:releaseAsset];
        }
    }
    if (0 == releaseAssets.count)
        releaseAssets = [NSMutableArray arrayWithArray:self.releaseAssets];

    for (NSURL *releaseAsset in releaseAssets)
    {
        dispatch_group_enter(group);

        [self.session
            downloadTaskWithURL:releaseAsset
            completionHandler:^(NSURL *url, NSURLResponse *response, NSError *error)
            {
                if (nil != url)
                {
                    NSURL *downloadedAsset = [[self.cacheURL
                        URLByAppendingPathComponent:@"downloadedAssets"]
                        URLByAppendingPathComponent:[url lastPathComponent]];
                    BOOL res = [[NSFileManager defaultManager]
                        moveItemAtURL:url
                        toURL:downloadedAsset
                        error:&error];
                    if (res)
                        [downloadedAssets addObject:downloadedAsset];
                }
                if (nil != error)
                    [errors addObject:error];

                dispatch_group_leave(group);
            }];
    }

    dispatch_group_notify(group, dispatch_get_main_queue(), ^
    {
        NSError *error = [errors firstObject];
        if (nil == error)
        {
            self.downloadedAssets = downloadedAssets;
            [self _setState:OctoReleaseDownloaded persistent:YES];
        }

        completion(error);

        dispatch_release(group);
    });
}

- (void)extractAssets:(void (^)(NSError *))completion
{
    dispatch_group_t group = dispatch_group_create();
    __block NSMutableArray *extractedAssets = [NSMutableArray array];
    __block NSMutableArray *errors = [NSMutableArray array];

    for (NSURL *downloadedAsset in self.downloadedAssets)
    {
        NSURL *extractedAsset = [[self.cacheURL
            URLByAppendingPathComponent:@"extractedAssets"]
            URLByAppendingPathComponent:[downloadedAsset lastPathComponent]];
        NSError *error = nil;
        BOOL res = [[NSFileManager defaultManager]
            createDirectoryAtURL:extractedAsset
            withIntermediateDirectories:YES
            attributes:0
            error:&error];
        if (res)
        {
            dispatch_group_enter(group);

            [OctoUnarchiver unarchiveURL:downloadedAsset toURL:extractedAsset completion:^(NSError *error)
            {
                if (nil == error)
                    [extractedAssets addObject:extractedAsset];
                else
                    [errors addObject:error];

                dispatch_group_leave(group);
            }];
        }
        else
            [errors addObject:error];
    }

    dispatch_group_notify(group, dispatch_get_main_queue(), ^
    {
        NSError *error = [errors firstObject];
        if (nil == error)
        {
            self.extractedAssets = extractedAssets;
            [self _setState:OctoReleaseExtracted persistent:YES];
        }

        completion(error);

        dispatch_release(group);
    });
}

- (void)verifyAssets:(void (^)(NSError *))completion
{
    dispatch_group_t group = dispatch_group_create();
    __block NSMutableArray *verifiedAssets = [NSMutableArray array];
    __block NSMutableArray *errors = [NSMutableArray array];

    for (NSURL *extractedAsset in self.extractedAssets)
    {
        NSError *error = nil;
        NSArray<NSURL *> *urls = [[NSFileManager defaultManager]
            contentsOfDirectoryAtURL:extractedAsset
            includingPropertiesForKeys:[NSArray arrayWithObject:NSURLIsPackageKey]
            options:0
            error:&error];
        if (nil == error)
        {
            for (NSURL *url in urls)
            {
                NSNumber *value;
                BOOL isPkg = [url getResourceValue:&value forKey:NSURLIsPackageKey error:0] &&
                    [value boolValue];
                if (isPkg)
                {
                    NSString *bundleIdentifier = [[NSBundle bundleWithURL:url] bundleIdentifier];
                    if (nil == bundleIdentifier)
                        continue;

                    for (NSBundle *b in self.targetBundles)
                        if ([b.bundleIdentifier isEqualToString:bundleIdentifier])
                        {
                            // !!!: missing signature verification
                            [verifiedAssets addObject:url];
                        }
                }
            }
        }
        else
            [errors addObject:error];
    }

    dispatch_group_notify(group, dispatch_get_main_queue(), ^
    {
        NSError *error = [errors firstObject];
        if (nil == error)
        {
            self.verifiedAssets = verifiedAssets;
            [self _setState:OctoReleaseVerified persistent:YES];
        }

        completion(error);

        dispatch_release(group);
    });
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
