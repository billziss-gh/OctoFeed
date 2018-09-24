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
@property (assign) OctoFeedInstallPolicy installPolicy;
@property (retain) NSTimer *timer;
@property (assign) BOOL activated;
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

    return self;
}

- (void)dealloc
{
    [self deactivate];
    [self.session invalidateAndCancel];

    self.cacheBaseURL = nil;
    self.session = nil;

    self.repository = nil;
    self.checkPeriod = 0;
    self.targetBundles = nil;

    [super dealloc];
}

- (OctoRelease *)cachedRelease
{
    return [OctoRelease
        releaseWithRepository:nil
        targetBundles:self.targetBundles
        session:self.session
        cacheBaseURL:self.cacheBaseURL];
}

- (OctoRelease *)cachedReleaseFetchSynchronously
{
    OctoRelease *cachedRelease = [self cachedRelease];
    NSError *error = nil;
    return [cachedRelease fetchSynchronouslyIfAble:&error] && nil == error ? cachedRelease : nil;
}

- (OctoRelease *)latestRelease
{
    return [OctoRelease
        releaseWithRepository:self.repository
        targetBundles:self.targetBundles
        session:self.session
        cacheBaseURL:self.cacheBaseURL];
}

- (BOOL)activateWithInstallPolicy:(OctoFeedInstallPolicy)policy
{
    if (self.activated || 0 == [self.repository length])
        return NO;

    switch (policy)
    {
    case OctoFeedInstallNone:
        [self _activateWithInstallPolicy:policy];
        self.activated = YES;
        return YES;

    case OctoFeedInstallAtLaunch:
        if (![self _installCachedRelease:OctoFeedInstallAtLaunch])
            [self _activateWithInstallPolicy:policy];
        self.activated = YES;
        return YES;

    case OctoFeedInstallAtQuit:
        [[NSNotificationCenter defaultCenter]
            addObserver:self
            selector:@selector(_willTerminate:)
            name:@"NSApplicationWillTerminateNotification"
            object:nil];
        [self _activateWithInstallPolicy:policy];
        self.activated = YES;
        return YES;

    case OctoFeedInstallWhenReady:
        [self _activateWithInstallPolicy:policy];
        self.activated = YES;
        return YES;

    default:
        return NO;
    }
}

- (void)_activateWithInstallPolicy:(OctoFeedInstallPolicy)policy
{
    self.installPolicy = policy;

    /* schedule a timer that fires every hour */
    self.timer = [NSTimer
        scheduledTimerWithTimeInterval:60.0 * 60.0
        target:self
        selector:@selector(_tick:)
        userInfo:nil
        repeats:YES];

    /* perform a check now */
    [self performSelector:@selector(_tick:) withObject:nil afterDelay:0];
}

- (void)deactivate
{
    [self.timer invalidate];
    [[NSNotificationCenter defaultCenter] removeObserver:self];

    self.timer = nil;
    self.installPolicy = OctoFeedInstallNone;
    self.activated = NO;
}

- (BOOL)_installCachedRelease:(OctoFeedInstallPolicy)policy
{
    OctoRelease *cachedRelease = [self cachedReleaseFetchSynchronously];
    if (OctoReleaseReadyToInstall != cachedRelease.state)
        return NO;

    [cachedRelease installAssets:^(
        NSDictionary<NSURL *, NSURL *> *assets, NSDictionary<NSURL *, NSError *> *errors)
    {
        [cachedRelease clear];

        if (OctoFeedInstallAtLaunch == policy)
        {
            /*
             * If policy is InstallAtLaunch then during launch we delay full activation and
             * we first try to install any cached release instead. If this succeeds we relaunch
             * our app. If it fails we go ahead and fully activate ourselves.
             */

            if (0 < assets.count)
                /* +[NSTask relaunch] does not return! */
                [NSTask relaunchWithURL:[[assets allValues] firstObject]];

            [self _activateWithInstallPolicy:policy];
        }
        /* if unable to install anything fully activate ourselves */
    }];

    return YES;
}

- (void)_willTerminate:(NSNotification *)notification
{
    [self _installCachedRelease:OctoFeedInstallAtQuit];
}

- (void)_tick:(NSTimer *)sender
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

    OctoRelease *latestRelease = [self latestRelease];
    [latestRelease fetch:^(NSError *error)
    {
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
        OctoRelease *release = latestRelease;
        OctoRelease *cachedRelease = [self cachedReleaseFetchSynchronously];
        switch ([cachedRelease.releaseVersion versionCompare:latestReleaseVersion])
        {
        case NSOrderedSame:
            release = cachedRelease;
            break;
        default:
            [cachedRelease clear];
            break;
        }

        [self _postNotificationWithRelease:release];

        /* should we download and prepare this release? */
        if (OctoFeedInstallNone != self.installPolicy)
        {
            switch (release.state)
            {
            case OctoReleaseFetched:
                [release downloadAssets:^(
                    NSDictionary<NSURL *, NSURL *> *assets, NSDictionary<NSURL *, NSError *> *errors)
                {
                    if (0 < errors.count)
                        return;

                    [self _postNotificationWithRelease:release];

                    [release extractAssets:^(
                        NSDictionary<NSURL *, NSURL *> *assets, NSDictionary<NSURL *, NSError *> *errors)
                    {
                        if (0 < errors.count)
                            return;

                        [self _postNotificationWithRelease:release];
                    }];
                }];
                break;

            case OctoReleaseDownloaded:
                [release extractAssets:^(
                    NSDictionary<NSURL *, NSURL *> *assets, NSDictionary<NSURL *, NSError *> *errors)
                {
                    if (0 < errors.count)
                        return;

                    [self _postNotificationWithRelease:release];
                }];
                break;

            default:
                break;
            }
        }
    }];
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
@end

NSString *OctoNotification = @"OctoNotification";
NSString *OctoNotificationReleaseKey = @"OctoNotificationRelease";
NSString *OctoNotificationReleaseStateKey = @"OctoNotificationReleaseState";

NSString *OctoRepositoryKey = @"OctoRepository";
NSString *OctoCheckPeriodKey = @"OctoCheckPeriod";
NSString *OctoLastCheckTimeKey = @"OctoLastCheckTime";
