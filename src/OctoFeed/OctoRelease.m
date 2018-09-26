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
static int progressKey;

@interface OctoRelease ()
@property (copy) NSString *_repository;
@property (copy) NSArray<NSBundle *> *_targetBundles;
@property (retain) NSURLSession *_session;
@property (copy) NSURL *_cacheBaseURL;
@property (copy) NSString *_releaseVersion;
@property (assign) BOOL _prerelease;
@property (copy) NSArray<NSURL *> *_releaseAssets;
@property (copy) NSArray<NSURL *> *_preparedAssets;
@property (assign) OctoReleaseState _state;
@property (retain) NSProgress *_progress;
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

+ (NSURL *)defaultCacheBaseURL
{
    NSString *mainIdentifier = [[NSBundle mainBundle] bundleIdentifier];
    NSString *octoIdentifier = [[NSBundle bundleForClass:[self class]] bundleIdentifier];
    if (nil == mainIdentifier) /* happens during XCTest! */
        mainIdentifier = octoIdentifier;
    return [[[[[NSFileManager defaultManager]
        URLsForDirectory:NSCachesDirectory inDomains:NSUserDomainMask] firstObject]
        URLByAppendingPathComponent:mainIdentifier]
        URLByAppendingPathComponent:octoIdentifier];
}

+ (OctoRelease *)releaseWithRepository:(NSString *)repository
{
    return [[self class] releaseWithRepository:repository
        targetBundles:nil
        session:nil
        cacheBaseURL:nil];
}

+ (OctoRelease *)releaseWithRepository:(NSString *)repository
    targetBundles:(NSArray<NSBundle *> *)bundles
    session:(NSURLSession *)session
    cacheBaseURL:(NSURL *)cacheBaseURL
{
    NSString *service = 0 != [repository length] ? [[repository pathComponents] firstObject] : @"";
    Class cls = [classDictionary objectForKey:service];
    return [[[cls alloc]
        initWithRepository:repository
        targetBundles:bundles
        session:session
        cacheBaseURL:cacheBaseURL] autorelease];
}

- (id)initWithRepository:(NSString *)repository
{
    return [self initWithRepository:repository
        targetBundles:nil
        session:nil
        cacheBaseURL:nil];
}

- (id)initWithRepository:(NSString *)repository
    targetBundles:(NSArray<NSBundle *> *)bundles
    session:(NSURLSession *)session
    cacheBaseURL:(NSURL *)cacheBaseURL;
{
    self = [super init];
    if (nil == self)
        return nil;

    self._repository = repository;
    self._targetBundles = nil != bundles ?
        bundles :
        [NSArray arrayWithObject:[NSBundle mainBundle]];
    self._session = nil != session ?
        session :
        [NSURLSession
            sessionWithConfiguration:[NSURLSessionConfiguration ephemeralSessionConfiguration]
            delegate:nil
            delegateQueue:[NSOperationQueue mainQueue]];
    self._cacheBaseURL = nil != cacheBaseURL ?
        cacheBaseURL :
        [[self class] defaultCacheBaseURL];

    self._progress = [NSProgress discreteProgressWithTotalUnitCount:100];
    [self._progress
        addObserver:self
        forKeyPath:@"fractionCompleted"
        options:0
        context:&progressKey];

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
    self._preparedAssets = nil;

    [self._progress
        removeObserver:self
        forKeyPath:@"fractionCompleted"
        context:&progressKey];
    self._progress = nil;

    [super dealloc];
}

- (void)cancel
{
    [self._progress cancel];
}

- (void)fetch:(void (^)(NSError *))completion
{
}

- (BOOL)fetchSynchronouslyIfAble:(NSError **)errorp
{
    return NO;
}

- (void)prepareAssets:(OctoReleaseCompletion)completion
{
    dispatch_group_t group = dispatch_group_create();
    NSMutableDictionary *preparedAssets = [NSMutableDictionary dictionary];
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

    NSProgress *prepareProgress = [NSProgress
        progressWithTotalUnitCount:10 * releaseAssets.count
        parent:self._progress
        pendingUnitCount:99];

    NSURL *preparedAssetsDir = [[self cacheURL] URLByAppendingPathComponent:@"preparedAssets"];
    for (NSURL *releaseAsset in releaseAssets)
    {
        dispatch_group_enter(group);

        NSProgress *extractProgress = [NSProgress discreteProgressWithTotalUnitCount:1];
        NSURLSessionDownloadTask *task = [self._session
            downloadTaskWithURL:releaseAsset
            completionHandler:^(NSURL *url, NSURLResponse *response, NSError *error)
            {
                BOOL leave = YES;

                if (nil != url)
                {
                    NSURL *downloadDirURL = [[NSFileManager defaultManager]
                        URLForDirectory:NSItemReplacementDirectory
                        inDomain:NSUserDomainMask
                        appropriateForURL:url
                        create:YES
                        error:&error];
                    NSURL *downloadFileURL = [downloadDirURL
                        URLByAppendingPathComponent:[releaseAsset lastPathComponent]];
                    if (nil != downloadFileURL)
                    {
                        NSURL *preparedAsset = [preparedAssetsDir
                            URLByAppendingPathComponent:[releaseAsset lastPathComponent]
                            isDirectory:YES];
                        BOOL res = [[NSFileManager defaultManager]
                            moveItemAtURL:url
                            toURL:downloadFileURL
                            error:&error];
                        res && [[NSFileManager defaultManager]
                            removeItemAtURL:preparedAsset
                            error:0];
                        res = res && [[NSFileManager defaultManager]
                            createDirectoryAtURL:preparedAsset
                            withIntermediateDirectories:YES
                            attributes:0
                            error:&error];

                        if (res)
                        {
                            error = nil;
                            leave = NO;
                            [OctoExtractor
                                extractURL:downloadFileURL
                                toURL:preparedAsset
                                completion:^(NSError *error)
                                {
                                    extractProgress.completedUnitCount = 1;

                                    if (nil == error)
                                        [preparedAssets setObject:preparedAsset forKey:releaseAsset];
                                    else
                                        [errors setObject:error forKey:releaseAsset];

                                    [[NSFileManager defaultManager]
                                        removeItemAtURL:downloadDirURL error:0];

                                    dispatch_group_leave(group);
                                }];
                        }
                        else
                            [[NSFileManager defaultManager]
                                removeItemAtURL:downloadDirURL error:0];
                    }
                }

                if (nil != error)
                    [errors setObject:error forKey:releaseAsset];

                if (leave)
                    dispatch_group_leave(group);
            }];

        [prepareProgress addChild:task.progress withPendingUnitCount:9];
        [prepareProgress addChild:extractProgress withPendingUnitCount:1];
        [task resume];
    }

    dispatch_group_notify(group, dispatch_get_main_queue(), ^
    {
        if (0 < preparedAssets.count && 0 == errors.count)
        {
            self._preparedAssets = [preparedAssets allValues];
            self._state = OctoReleaseReadyToInstall;
            [self commit];
        }

        completion(
            0 < preparedAssets.count ? preparedAssets : nil,
            0 < errors.count ? errors : nil);

        dispatch_release(group);
    });
}

- (void)installAssetsSynchronously:(OctoReleaseCompletion)completion
{
    NSMutableDictionary *installedAssets = [NSMutableDictionary dictionary];
    NSMutableDictionary *errors = [NSMutableDictionary dictionary];

    for (NSURL *preparedAsset in self._preparedAssets)
    {
        NSError *error = nil;
        NSArray<NSURL *> *urls = [[NSFileManager defaultManager]
            contentsOfDirectoryAtURL:preparedAsset
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
            [errors setObject:error forKey:preparedAsset];
    }

    if (0 < installedAssets.count && 0 == errors.count)
    {
        self._state = OctoReleaseInstalled;
        [self commit];
    }

    completion(
        0 < installedAssets.count ? installedAssets : nil,
        0 < errors.count ? errors : nil);
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
    self._preparedAssets = nil;
    self._state = OctoReleaseEmpty;

    [self._progress
        removeObserver:self
        forKeyPath:@"fractionCompleted"
        context:&progressKey];
    self._progress = [NSProgress discreteProgressWithTotalUnitCount:100];
    [self._progress
        addObserver:self
        forKeyPath:@"fractionCompleted"
        options:0
        context:&progressKey];
    [self postProgressValueNotification];

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

- (NSArray<NSURL *> *)preparedAssets
{
    return self._preparedAssets;
}

- (OctoReleaseState)state
{
    return self._state;
}

- (NSProgress *)progress
{
    return self._progress;
}

- (double)progressValue
{
    return self._progress.fractionCompleted;
}

- (NSError *)commit
{
    if (0 == [self._releaseVersion length])
        [NSException raise:NSInvalidArgumentException format:@"%s empty releaseVersion", __FUNCTION__];

    NSMutableString *str = [NSMutableString stringWithFormat:@"%@\n%d\n%c\n",
        self._releaseVersion, self._prerelease, (char)self._state];
    for (id asset in self._releaseAssets)
        [str appendFormat:@"%@\n", [asset absoluteString]];

    NSURL *cacheURL = [self cacheURL];
    NSError *error = nil;
    BOOL res = [[NSFileManager defaultManager]
        createDirectoryAtURL:cacheURL
        withIntermediateDirectories:YES
        attributes:nil
        error:&error];
    res = res && [str
        writeToURL:[cacheURL URLByAppendingPathComponent:@"state"]
        atomically:YES
        encoding:NSUTF8StringEncoding
        error:&error];
    return res ? nil : error;
}

- (void)observeValueForKeyPath:(NSString *)keyPath
    ofObject:(id)object
    change:(NSDictionary<NSKeyValueChangeKey,id> *)change
    context:(void *)context
{
    if (&progressKey != context ||
        object != self._progress ||
        ![keyPath isEqualToString:@"fractionCompleted"])
        return;

    [self
        performSelectorOnMainThread:@selector(postProgressValueNotification)
        withObject:nil
        waitUntilDone:NO];
}

- (void)postProgressValueNotification
{
    [self willChangeValueForKey:@"progressValue"];
    [self didChangeValueForKey:@"progressValue"];
}
@end
