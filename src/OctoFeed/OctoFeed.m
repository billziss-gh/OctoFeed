/**
 * @file OctoFeed/OctoFeed.m
 *
 * @copyright 2018 Bill Zissimopoulos
 */
/*
 * This file is part of OctoFeed.
 *
 * It is licensed under the MIT license. The full license text can be found
 * in the License.txt file at the root of this project.
 */

#import "OctoFeed.h"

@interface OctoFeed ()
@property (assign) int _dirfd;
@property (assign) BOOL _activated;
@property (assign) OctoFeedInstallPolicy _installPolicy;
@property (retain) NSTimer *_timer;
@property (retain) OctoRelease *_currentRelease;
@end

@implementation OctoFeed
+ (OctoFeed *)mainBundleFeed
{
    static OctoFeed *instance = 0;

    if (nil == instance)
        instance = [[OctoFeed alloc] initWithBundle:[NSBundle mainBundle]];

    return instance;
}

- (id)initWithBundle:(NSBundle *)bundle
{
    self = [super init];
    if (nil == self)
        return nil;

    if (nil != bundle)
    {
        self.repository = [bundle objectForInfoDictionaryKey:OctoRepositoryKey];
        self.checkPeriod = [[bundle objectForInfoDictionaryKey:OctoCheckPeriodKey] doubleValue];
        self.targetBundles = [NSArray arrayWithObject:bundle];
    }

    self.session = [NSURLSession
        sessionWithConfiguration:[NSURLSessionConfiguration ephemeralSessionConfiguration]
        delegate:nil
        delegateQueue:[NSOperationQueue mainQueue]];
    self.cacheBaseURL = [OctoRelease defaultCacheBaseURL];

    self._dirfd = -1;

    return self;
}

- (void)dealloc
{
    [self deactivate];
    [self.session invalidateAndCancel];

    self.repository = nil;
    self.checkPeriod = 0;
    self.targetBundles = nil;
    self.session = nil;
    self.cacheBaseURL = nil;

    [super dealloc];
}

- (BOOL)activateWithInstallPolicy:(OctoFeedInstallPolicy)policy
{
    if (0 == [self.repository length])
        [NSException raise:NSInvalidArgumentException format:@"%s empty repository", __FUNCTION__];

    if (self._activated)
        return NO;

    switch (policy)
    {
    case OctoFeedInstallNone:
        if (![self _lockCache])
            return NO;
        [self _activateWithInstallPolicy:policy];
        return YES;

    case OctoFeedInstallAtActivation:
        if (![self _lockCache])
            return NO;
        {
            OctoRelease *cachedRelease = [self _cachedReleaseFetchSynchronously];
            if (OctoReleaseReadyToInstall == cachedRelease.state)
            {
                [cachedRelease installAssetsSynchronously:^(
                    NSDictionary<NSURL *, NSURL *> *assets, NSDictionary<NSURL *, NSError *> *errors)
                {
                    [self clearThisAndPriorReleases:cachedRelease];
                    if (0 < assets.count)
                        /* +[NSTask relaunch] does not return! */
                        [NSTask relaunchWithURL:[[assets allValues] firstObject]];
                }];
            }
        }
        [self _activateWithInstallPolicy:policy];
        return YES;

    case OctoFeedInstallAtQuit:
        if (![self _lockCache])
            return NO;
        [[NSNotificationCenter defaultCenter]
            addObserver:self
            selector:@selector(_willTerminate:)
            name:@"NSApplicationWillTerminateNotification"
            object:nil];
        [self _activateWithInstallPolicy:policy];
        return YES;

    case OctoFeedInstallWhenReady:
        if (![self _lockCache])
            return NO;
        [self _activateWithInstallPolicy:policy];
        return YES;

    default:
        return NO;
    }
}

- (void)deactivate
{
    [self._timer invalidate];
    [[NSNotificationCenter defaultCenter]
        removeObserver:self
        name:@"NSApplicationWillTerminateNotification"
        object:nil];
    [self _unlockCache];

    self._activated = NO;
    self._installPolicy = OctoFeedInstallNone;
    self._timer = nil;
    self._currentRelease = nil;
}

- (void)check
{
    [[NSUserDefaults standardUserDefaults]
        removeObjectForKey:OctoLastCheckTimeKey];

    [self performSelector:@selector(_tick:) withObject:nil afterDelay:0];
}

- (OctoRelease *)currentRelease
{
    return self._currentRelease;
}

- (NSError *)clearThisAndPriorReleases:(OctoRelease *)release
{
    NSError *error = nil;

    NSString *releaseVersion = release.releaseVersion;
    if (0 != [releaseVersion length])
    {
        NSArray *urls = [[NSFileManager defaultManager]
            contentsOfDirectoryAtURL:release.cacheBaseURL
            includingPropertiesForKeys:[NSArray arrayWithObject:NSURLIsDirectoryKey]
            options:0
            error:&error];
        urls = [urls sortedArrayUsingComparator:^NSComparisonResult(id url1, id url2)
        {
            return [[url1 lastPathComponent] versionCompare:[url2 lastPathComponent]];
        }];

        for (NSURL *url in [urls reverseObjectEnumerator])
        {
            NSNumber *value;
            BOOL isDir = [url
                getResourceValue:&value
                forKey:NSURLIsDirectoryKey
                error:nil == error ? &error : 0] &&
                [value boolValue];
            if (isDir &&
                NSOrderedDescending != [[url lastPathComponent] versionCompare:releaseVersion])
                [[NSFileManager defaultManager] removeItemAtURL:url error:nil == error ? &error : 0];
        }
    }

    return error;
}

- (BOOL)_lockCache
{
    NSURL *cacheBaseURL = self.cacheBaseURL;
    [[NSFileManager defaultManager]
        createDirectoryAtURL:cacheBaseURL
        withIntermediateDirectories:YES
        attributes:nil
        error:0];

    const char *dir = [cacheBaseURL.path cStringUsingEncoding:NSUTF8StringEncoding];
    int dirfd = open(dir, O_RDONLY | O_CLOEXEC);
    if (-1 == dirfd)
        return NO;

    if (-1 == flock(dirfd, LOCK_EX | LOCK_NB))
    {
        close(dirfd);
        return NO;
    }

    self._dirfd = dirfd;

    return YES;
}

- (void)_unlockCache
{
    close(self._dirfd);
    self._dirfd = -1;
}

- (void)_activateWithInstallPolicy:(OctoFeedInstallPolicy)policy
{
    self._activated = YES;
    self._installPolicy = policy;

    /* schedule a timer that fires every hour */
    self._timer = [NSTimer
        scheduledTimerWithTimeInterval:60.0 * 60.0
        target:self
        selector:@selector(_tick:)
        userInfo:nil
        repeats:YES];

    /* perform a check now */
    [self performSelector:@selector(_tick:) withObject:nil afterDelay:0];
}

- (void)_willTerminate:(NSNotification *)notification
{
    OctoRelease *currentRelease = self._currentRelease;
    if (OctoReleaseReadyToInstall == currentRelease.state)
    {
        [currentRelease installAssetsSynchronously:^(
            NSDictionary<NSURL *, NSURL *> *assets, NSDictionary<NSURL *, NSError *> *errors)
        {
            [self clearThisAndPriorReleases:currentRelease];
            self._currentRelease = nil;
        }];
    }
}

- (void)_tick:(NSTimer *)sender
{
    if (!self._activated || nil != self._currentRelease)
        return;

    OctoRelease *cachedRelease = [self _cachedReleaseFetchSynchronously];
    if (nil == cachedRelease.releaseVersion)
    {
        /* checkPeriod must be at least 1 hour */
        NSTimeInterval checkPeriod = self.checkPeriod;
        checkPeriod = MAX(checkPeriod, 60.0 * 60.0);

        /* compute check time */
        NSDate *now = [NSDate date];
        NSDate *checkTime = [[NSUserDefaults standardUserDefaults]
            objectForKey:OctoLastCheckTimeKey];
        if (nil != checkTime)
            checkTime = [checkTime dateByAddingTimeInterval:checkPeriod];
        else
            checkTime = now;

        /* if the check time is in the future there is nothing to do */
        if (NSOrderedAscending == [now compare:checkTime])
            return;
    }

    OctoRelease *latestRelease = [self _latestRelease];
    [latestRelease fetch:^(NSError *error)
    {
        if (!self._activated || nil != self._currentRelease)
            return;

        if (nil != error)
            return;

        /* remember last check time */
        [[NSUserDefaults standardUserDefaults]
            setObject:[NSDate date]
            forKey:OctoLastCheckTimeKey];

        /* is the latest-release-version > bundle-version? */
        NSString *latestReleaseVersion = latestRelease.releaseVersion;
        NSString *version = [[self.targetBundles firstObject]
            objectForInfoDictionaryKey:(NSString *)kCFBundleVersionKey];
        if (NSOrderedAscending != [version versionCompare:latestReleaseVersion])
            return;

        /* if latest-release-version matches cached-release-version, use cached release */
        OctoRelease *release;
        if (nil == cachedRelease.releaseVersion ||
            NSOrderedSame != [cachedRelease.releaseVersion versionCompare:latestReleaseVersion])
        {
            [self clearThisAndPriorReleases:cachedRelease];
            [latestRelease commit];
            release = latestRelease;
        }
        else
            release = cachedRelease;

        self._currentRelease = release;

        /* should we download and prepare this release? */
        if (OctoFeedInstallNone != self._installPolicy)
            [self _advanceReleaseState:release assets:nil errors:nil];
        else
            [self _postNotificationWithRelease:release];
    }];
}

- (void)_advanceReleaseState:(OctoRelease *)release
    assets:(NSDictionary<NSURL *, NSURL *> *)assets
    errors:(NSDictionary<NSURL *, NSError *> *)errors
{
    if (!self._activated || release != self._currentRelease)
        return;

    if (0 < errors.count)
    {
        [self clearThisAndPriorReleases:release];
        self._currentRelease = nil;
        return;
    }

    [self _postNotificationWithRelease:release];

    switch (release.state)
    {
    case OctoReleaseFetched:
        [release prepareAssets:^(
            NSDictionary<NSURL *, NSURL *> *assets, NSDictionary<NSURL *, NSError *> *errors)
        {
            [self _advanceReleaseState:release assets:assets errors:errors];
        }];
        break;

    default:
        break;
    }
}

- (void)_postNotificationWithRelease:(OctoRelease *)release
{
    [[NSNotificationCenter defaultCenter]
        postNotificationName:OctoNotification
        object:self
        userInfo:[NSDictionary
            dictionaryWithObjectsAndKeys:
                release, OctoNotificationReleaseKey,
                [NSNumber numberWithUnsignedInteger:release.state], OctoNotificationReleaseStateKey,
                nil]];
}

- (OctoRelease *)_cachedReleaseFetchSynchronously
{
    OctoRelease *cachedRelease = [OctoRelease
        releaseWithRepository:nil
        targetBundles:self.targetBundles
        session:self.session
        cacheBaseURL:self.cacheBaseURL];
    NSError *error = nil;
    return [cachedRelease fetchSynchronouslyIfAble:&error] && nil == error ? cachedRelease : nil;
}

- (OctoRelease *)_latestRelease
{
    return [OctoRelease
        releaseWithRepository:self.repository
        targetBundles:self.targetBundles
        session:self.session
        cacheBaseURL:self.cacheBaseURL];
}

+ (NSSet *)keyPathsForValuesAffectingCurrentRelease
{
    return [NSSet setWithObject:@"_currentRelease"];
}
@end

NSString *OctoNotification = @"OctoNotification";
NSString *OctoNotificationReleaseKey = @"OctoNotificationRelease";
NSString *OctoNotificationReleaseStateKey = @"OctoNotificationReleaseState";

NSString *OctoRepositoryKey = @"OctoRepository";
NSString *OctoCheckPeriodKey = @"OctoCheckPeriod";
NSString *OctoLastCheckTimeKey = @"OctoLastCheckTime";
