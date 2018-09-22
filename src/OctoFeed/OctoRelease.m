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
#import "NSString+Version.h"
#import "OctoExtractor.h"
#import "OctoVerifier.h"

static NSMutableDictionary *classDictionary;
static BOOL requireCodeSignature = YES;
static BOOL requireCodeSignatureMatchesTarget = YES;

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

+ (void)requireCodeSignature:(BOOL)require matchesTarget:(BOOL)matches
{
    requireCodeSignature = require;
    requireCodeSignatureMatchesTarget = require && matches;
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

- (BOOL)fetchSynchronouslyIfAble:(NSError **)errorp
{
    return NO;
}

- (void)downloadAssets:(OctoReleaseCompletion)completion
{
    dispatch_group_t group = dispatch_group_create();
    NSMutableDictionary *downloadedAssets = [NSMutableDictionary dictionary];
    NSMutableDictionary *errors = [NSMutableDictionary dictionary];

    NSMutableArray *releaseAssets = [NSMutableArray array];
    for (NSURL *releaseAsset in self._releaseAssets)
    {
        if ([OctoExtractor canExtractURL:releaseAsset])
            [releaseAssets addObject:releaseAsset];
    }

    NSMutableArray *newReleaseAssets = [NSMutableArray array];
    for (NSURL *releaseAsset in releaseAssets)
    {
        NSString *lastPathComponent = [releaseAsset lastPathComponent];
        NSString *name = [lastPathComponent stringByDeletingPathExtension];
        if ([lastPathComponent hasSuffix:@".dmg"] ||
            [name hasSuffix:@"-mac"] || [name containsString:@"-mac-"] ||
            [name hasSuffix:@"-osx"] || [name containsString:@"-osx-"] ||
            [name hasSuffix:@"-macosx"] || [name containsString:@"-macosx-"])
            [newReleaseAssets addObject:releaseAsset];
    }
    if (0 < newReleaseAssets.count)
        releaseAssets = newReleaseAssets;

    for (NSURL *releaseAsset in releaseAssets)
    {
        dispatch_group_enter(group);

        [[self._session
            downloadTaskWithURL:releaseAsset
            completionHandler:^(NSURL *url, NSURLResponse *response, NSError *error)
            {
                if (nil != url)
                {
                    NSURL *downloadedAssetDir = [[self cacheURL]
                        URLByAppendingPathComponent:@"downloadedAssets"];
                    NSURL *downloadedAsset = [downloadedAssetDir
                        URLByAppendingPathComponent:[releaseAsset lastPathComponent]];
                    NSURL *replaceDirURL = nil;
                    BOOL res = [[NSFileManager defaultManager]
                        createDirectoryAtURL:downloadedAssetDir
                        withIntermediateDirectories:YES
                        attributes:0
                        error:&error];
                    id ident[2];
                    if (res &&
                        [url getResourceValue:&ident[0] forKey:NSURLVolumeIdentifierKey error:0] &&
                        [downloadedAssetDir
                            getResourceValue:&ident[1] forKey:NSURLVolumeIdentifierKey error:0] &&
                        ![ident[0] isEqual:ident[1]])
                    {
                            replaceDirURL = [[NSFileManager defaultManager]
                                URLForDirectory:NSItemReplacementDirectory
                                inDomain:NSUserDomainMask
                                appropriateForURL:url
                                create:YES
                                error:&error];
                            NSURL *replaceFileURL = [replaceDirURL
                                URLByAppendingPathComponent:[url lastPathComponent]];
                            res = res && nil != replaceFileURL;
                            res = res && [[NSFileManager defaultManager]
                                moveItemAtURL:url
                                toURL:replaceFileURL
                                error:&error];
                            if (res)
                                url = replaceFileURL;
                    }
                    res = res && [[NSFileManager defaultManager]
                        replaceItemAtURL:downloadedAsset
                        withItemAtURL:url
                        backupItemName:nil
                        options:0
                        resultingItemURL:0
                        error:&error];
                    if (nil != replaceDirURL)
                        [[NSFileManager defaultManager]
                            removeItemAtURL:replaceDirURL error:0];
                    if (res)
                        [downloadedAssets setObject:downloadedAsset forKey:releaseAsset];
                }
                if (nil != error)
                    [errors setObject:error forKey:releaseAsset];

                dispatch_group_leave(group);
            }] resume];
    }

    dispatch_group_notify(group, dispatch_get_main_queue(), ^
    {
        if (0 < downloadedAssets.count && 0 == errors.count)
        {
            self._downloadedAssets = [downloadedAssets allValues];
            [self _setState:OctoReleaseDownloaded persistent:YES];
        }

        completion(
            0 < downloadedAssets.count ? downloadedAssets : nil,
            0 < errors.count ? errors : nil);

        dispatch_release(group);
    });
}

- (void)extractAssets:(OctoReleaseCompletion)completion
{
    dispatch_group_t group = dispatch_group_create();
    NSMutableDictionary *extractedAssets = [NSMutableDictionary dictionary];
    NSMutableDictionary *errors = [NSMutableDictionary dictionary];

    for (NSURL *downloadedAsset in self._downloadedAssets)
    {
        NSURL *extractedAsset = [[[self cacheURL]
            URLByAppendingPathComponent:@"extractedAssets"]
            URLByAppendingPathComponent:[downloadedAsset lastPathComponent] isDirectory:YES];
        NSError *error = nil;
        [[NSFileManager defaultManager]
            removeItemAtURL:extractedAsset
            error:0];
        BOOL res = [[NSFileManager defaultManager]
            createDirectoryAtURL:extractedAsset
            withIntermediateDirectories:YES
            attributes:0
            error:&error];
        if (res)
        {
            dispatch_group_enter(group);

            [OctoExtractor extractURL:downloadedAsset toURL:extractedAsset completion:^(NSError *error)
            {
                if (nil == error)
                    [extractedAssets setObject:extractedAsset forKey:downloadedAsset];
                else
                    [errors setObject:error forKey:downloadedAsset];

                dispatch_group_leave(group);
            }];
        }
        else
            [errors setObject:error forKey:downloadedAsset];
    }

    dispatch_group_notify(group, dispatch_get_main_queue(), ^
    {
        if (0 < extractedAssets.count && 0 == errors.count)
        {
            self._extractedAssets = [extractedAssets allValues];
            [self _setState:OctoReleaseExtracted persistent:YES];
        }

        completion(
            0 < extractedAssets.count ? extractedAssets : nil,
            0 < errors.count ? errors : nil);

        dispatch_release(group);
    });
}

- (void)installAssets:(OctoReleaseCompletion)completion
{
    dispatch_group_t group = dispatch_group_create();
    NSMutableDictionary *installedAssets = [NSMutableDictionary dictionary];
    NSMutableDictionary *errors = [NSMutableDictionary dictionary];

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
                    NSBundle *bundle = [NSBundle bundleWithURL:url];
                    NSString *bundleIdentifier = [bundle bundleIdentifier];
                    NSURL *bundleURL = bundle.bundleURL;
                    if (nil == bundleIdentifier || nil == bundleURL)
                        continue;

                    for (NSBundle *targetBundle in self._targetBundles)
                        if ([targetBundle.bundleIdentifier isEqualToString:bundleIdentifier])
                        {
                            NSString *version = [bundle
                                objectForInfoDictionaryKey:(NSString *)kCFBundleVersionKey];
                            NSString *targetVersion = [targetBundle
                                objectForInfoDictionaryKey:(NSString *)kCFBundleVersionKey];
                            if (nil == version ||
                                NSOrderedAscending != [targetVersion versionCompare:version])
                                continue;
                            NSURL *targetBundleURL = targetBundle.bundleURL;
                            if (nil == targetBundleURL)
                                continue;

                            error = nil;
                            if (requireCodeSignature)
                                error = [OctoVerifier
                                    verifyCodeSignatureAtURL:bundleURL
                                    matchesCodesSignatureAtURL:requireCodeSignatureMatchesTarget ?
                                        targetBundleURL : nil];
                            if (nil != error)
                            {
                                [errors setObject:error forKey:bundleURL];
                                continue;
                            }

                            NSURL *replaceDirURL = [[NSFileManager defaultManager]
                                URLForDirectory:NSItemReplacementDirectory
                                inDomain:NSUserDomainMask
                                appropriateForURL:targetBundleURL
                                create:YES
                                error:&error];
                            NSURL *replaceFileURL = [replaceDirURL
                                URLByAppendingPathComponent:[bundleURL lastPathComponent]];
                            BOOL res = nil != replaceFileURL;
                            res = res && [[NSFileManager defaultManager]
                                copyItemAtURL:bundleURL
                                toURL:replaceFileURL
                                error:&error];
                            res = res && [[NSFileManager defaultManager]
                                replaceItemAtURL:targetBundleURL
                                withItemAtURL:replaceFileURL
                                backupItemName:nil
                                options:0
                                resultingItemURL:0
                                error:&error];
                            if (![[bundleURL lastPathComponent]
                                isEqualToString:[targetBundleURL lastPathComponent]])
                            {
                                NSURL *newTargetBundleURL =
                                    [[targetBundleURL URLByDeletingLastPathComponent]
                                        URLByAppendingPathComponent:[bundleURL lastPathComponent]];
                                res = res && [[NSFileManager defaultManager]
                                    moveItemAtURL:targetBundleURL
                                    toURL:newTargetBundleURL
                                    error:&error];
                                if (res)
                                    targetBundleURL = newTargetBundleURL;
                            }
                            [[NSFileManager defaultManager]
                                removeItemAtURL:replaceDirURL
                                error:0];
                            if (res)
                                [installedAssets setObject:targetBundleURL forKey:bundleURL];
                            else
                                [errors setObject:error forKey:bundleURL];
                        }
                }
            }
        }
        else
            [errors setObject:error forKey:extractedAsset];
    }

    dispatch_group_notify(group, dispatch_get_main_queue(), ^
    {
        if (0 < installedAssets.count && 0 == errors.count)
            [self _setState:OctoReleaseInstalled persistent:YES];

        completion(
            0 < installedAssets.count ? installedAssets : nil,
            0 < errors.count ? errors : nil);

        dispatch_release(group);
    });
}

- (NSError *)clear
{
    if (0 != [self._releaseVersion length])
    {
        NSURL *cacheURL = [self cacheURL];
        if ([[NSFileManager defaultManager] fileExistsAtPath:[cacheURL path]])
        {
            NSError *error = nil;
            if (![[NSFileManager defaultManager] removeItemAtURL:cacheURL error:&error])
                return error;
        }
    }

    self._releaseVersion = nil;
    self._prerelease = NO;
    self._releaseAssets = nil;
    self._downloadedAssets = nil;
    self._extractedAssets = nil;
    self._state = OctoReleaseEmpty;

    return nil;
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
