/**
 * @file OctoFeed.m
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
@property (assign) OctoFeedInstallPolicy _installPolicy;
@property (retain) NSTimer *_timer;
@property (assign) BOOL _activated;
@property (retain) OctoRelease *_currentRelease;
@end

@implementation OctoFeed
+ (OctoFeed *)mainBundleFeed
{
    static OctoFeed *instance = 0;

    if (0 == instance)
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
        self._activated = YES;
        return YES;

    case OctoFeedInstallAtLaunch:
        if (![self _lockCache])
            return NO;
        {
            OctoRelease *cachedRelease = [self _cachedReleaseFetchSynchronously];
            if (OctoReleaseReadyToInstall == cachedRelease.state)
            {
                [cachedRelease installAssets:^(
                    NSDictionary<NSURL *, NSURL *> *assets, NSDictionary<NSURL *, NSError *> *errors)
                {
                    /*
                     * If policy is InstallAtLaunch then during launch we delay full activation
                     * and we first try to install any cached release instead. If this succeeds
                     * we relaunch our app. If it fails we go ahead and fully activate ourselves.
                     */
                    [cachedRelease clear];
                    if (0 < assets.count)
                        /* +[NSTask relaunch] does not return! */
                        [NSTask relaunchWithURL:[[assets allValues] firstObject]];
                    [self _activateWithInstallPolicy:policy];
                }];
            }
            else
                [self _activateWithInstallPolicy:policy];
        }
        self._activated = YES;
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
        self._activated = YES;
        return YES;

    case OctoFeedInstallWhenReady:
        if (![self _lockCache])
            return NO;
        [self _activateWithInstallPolicy:policy];
        self._activated = YES;
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

    self._installPolicy = OctoFeedInstallNone;
    self._timer = nil;
    self._activated = NO;
    self._currentRelease = nil;
}

- (OctoRelease *)currentRelease
{
    return self._currentRelease;
}

- (BOOL)_lockCache
{
    const char *dir = [self.cacheBaseURL.path cStringUsingEncoding:NSUTF8StringEncoding];

    int dirfd = open(dir, O_RDONLY);
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
    [self.currentRelease installAssets:^(
        NSDictionary<NSURL *, NSURL *> *assets, NSDictionary<NSURL *, NSError *> *errors)
    {
        [self.currentRelease clear];
    }];
}

- (void)_tick:(NSTimer *)sender
{
    if (!self._activated || nil != self._currentRelease)
        return;

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
        OctoRelease *cachedRelease = [self _cachedReleaseFetchSynchronously];
        switch ([cachedRelease.releaseVersion versionCompare:latestReleaseVersion])
        {
        case NSOrderedSame:
            release = cachedRelease;
            break;
        default:
            [cachedRelease clear];
            [latestRelease commit];
            release = latestRelease;
            break;
        }

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
        [release clear];
        self._currentRelease = nil;
        return;
    }

    [self _postNotificationWithRelease:release];

    switch (release.state)
    {
    case OctoReleaseFetched:
        [release downloadAssets:^(
            NSDictionary<NSURL *, NSURL *> *assets, NSDictionary<NSURL *, NSError *> *errors)
        {
            [self _advanceReleaseState:release assets:assets errors:errors];
        }];
        break;

    case OctoReleaseDownloaded:
        [release extractAssets:^(
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
@end


NSString *OctoNotification = @"OctoNotification";
NSString *OctoNotificationReleaseKey = @"OctoNotificationRelease";
NSString *OctoNotificationReleaseStateKey = @"OctoNotificationReleaseState";

NSString *OctoRepositoryKey = @"OctoRepository";
NSString *OctoCheckPeriodKey = @"OctoCheckPeriod";
NSString *OctoLastCheckTimeKey = @"OctoLastCheckTime";
