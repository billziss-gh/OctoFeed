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

#import "OctoRelease.h"
#import "OctoRelease+Extensions.h"
#import "OctoUnarchiver.h"

static NSMutableDictionary *classDictionary;

@interface OctoRelease ()
@property (copy) NSString *_repository;
@property (copy) NSArray<NSBundle *> *_targetBundles;
@property (retain) NSURLSession *_session;
@property (copy) NSURL *_cacheBaseURL;
@property (copy) NSString *_releaseVersion;
@property (assign) BOOL _prerelease;
@property (copy) NSArray<NSURL *> *_releaseAssets;
@property (copy) NSArray<NSURL *> *_downloadedAssets;
@property (copy) NSArray<NSURL *> *_extractedAssets;
@property (assign) OctoReleaseState _state;
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

    self._repository = repository;
    self._targetBundles = bundles;
    self._session = session;
    self._cacheBaseURL = [[[[[NSFileManager defaultManager]
        URLsForDirectory:NSCachesDirectory inDomains:NSUserDomainMask] firstObject]
        URLByAppendingPathComponent:mainIdentifier]
        URLByAppendingPathComponent:octoIdentifier];

    return self;
}

- (void)dealloc
{
    self._repository = nil;
    self._targetBundles = nil;
    self._session = nil;
    self._cacheBaseURL = nil;
    self._releaseVersion = nil;
    self._releaseAssets = nil;
    self._downloadedAssets = nil;
    self._extractedAssets = nil;

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
    if (1 < self._releaseAssets.count)
    {
        releaseAssets = [NSMutableArray array];
        for (NSURL *releaseAsset in self._releaseAssets)
        {
            NSString *name = [[releaseAsset lastPathComponent] stringByDeletingPathExtension];
            if ([name hasSuffix:@"-mac"] || [name containsString:@"-mac-"] ||
                [name hasSuffix:@"-osx"] || [name containsString:@"-osx-"])
                [releaseAssets addObject:releaseAsset];
        }
    }
    if (0 == releaseAssets.count)
        releaseAssets = [NSMutableArray arrayWithArray:self._releaseAssets];

    for (NSURL *releaseAsset in releaseAssets)
    {
        dispatch_group_enter(group);

        [self._session
            downloadTaskWithURL:releaseAsset
            completionHandler:^(NSURL *url, NSURLResponse *response, NSError *error)
            {
                if (nil != url)
                {
                    NSURL *downloadedAsset = [[[self cacheURL]
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
            self._downloadedAssets = downloadedAssets;
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

    for (NSURL *downloadedAsset in self._downloadedAssets)
    {
        NSURL *extractedAsset = [[[self cacheURL]
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
            self._extractedAssets = extractedAssets;
            [self _setState:OctoReleaseExtracted persistent:YES];
        }

        completion(error);

        dispatch_release(group);
    });
}

- (void)installAssets:(void (^)(NSError *))completion
{
    dispatch_group_t group = dispatch_group_create();
    __block NSMutableArray *errors = [NSMutableArray array];

    for (NSURL *extractedAsset in self._extractedAssets)
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

                    for (NSBundle *b in self._targetBundles)
                        if ([b.bundleIdentifier isEqualToString:bundleIdentifier])
                        {
                            // !!!: check newer version
                            // !!!: verify signature
                            // !!!: install bundle
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
            [self _setState:OctoReleaseInstalled persistent:YES];

        completion(error);

        dispatch_release(group);
    });
}

- (NSString *)repository
{
    return self._repository;
}

- (NSArray<NSBundle *> *)targetBundles
{
    return self._targetBundles;
}

- (NSURL *)cacheBaseURL
{
    return self._cacheBaseURL;
}

- (NSURL *)cacheURL
{
    if (0 == [self._releaseVersion length])
        [NSException raise:NSInvalidArgumentException format:@"%s empty releaseVersion", __FUNCTION__];

    return [self._cacheBaseURL URLByAppendingPathComponent:self._releaseVersion];
}

- (NSURLSession *)session
{
    return self._session;
}

- (NSString *)releaseVersion
{
    return self._releaseVersion;
}

- (BOOL)prerelease
{
    return self._prerelease;
}

- (NSArray<NSURL *> *)releaseAssets
{
    return self._releaseAssets;
}

- (NSArray<NSURL *> *)downloadedAssets
{
    return self._downloadedAssets;
}

- (NSArray<NSURL *> *)extractedAssets
{
    return self._extractedAssets;
}

- (OctoReleaseState)state
{
    return self._state;
}

- (void)_setState:(OctoReleaseState)state persistent:(BOOL)persistent
{
    if (!persistent)
    {
        self._state = state;
        return;
    }

    if (0 == [self._releaseVersion length])
        [NSException raise:NSInvalidArgumentException format:@"%s empty releaseVersion", __FUNCTION__];

    NSMutableString *str = [NSMutableString stringWithFormat:@"%@\n%d\n%c\n",
        self._releaseVersion, self._prerelease, (char)state];
    for (id asset in self._releaseAssets)
        [str appendFormat:@"%@\n", [asset absoluteString]];

    NSURL *cacheURL = [self cacheURL];
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

    self._state = state;
}
@end
