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
@property (retain) NSTimer *timer;
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

    return self;
}

- (void)dealloc
{
    [self deactivate];
    [self.session invalidateAndCancel];

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
        session:self.session];
}

- (OctoRelease *)latestRelease
{
    return [OctoRelease
        releaseWithRepository:self.repository
        targetBundles:self.targetBundles
        session:self.session];
}

- (BOOL)activate
{
    if (nil != self.timer)
        return YES;

    if (0 == [self.repository length])
        return NO;

    /* schedule a timer that fires every hour */
    self.timer = [NSTimer
        scheduledTimerWithTimeInterval:60.0 * 60.0
        target:self
        selector:@selector(tick:)
        userInfo:nil
        repeats:YES];

    /* perform a check now */
    [self performSelector:@selector(tick:) withObject:nil afterDelay:0];

    return YES;
}

- (void)deactivate
{
    [self.timer invalidate];
    self.timer = nil;
}

- (void)tick:(NSTimer *)sender
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

    OctoRelease *release = [self latestRelease];
    [release fetch:^(NSError *error)
    {
        if (nil != error)
            return;

        /* remember last check time */
        [[NSUserDefaults standardUserDefaults]
            setObject:[NSDate date]
            forKey:OctoLastCheckTimeKey];

        /* tell everyone who cares */
        [[NSNotificationCenter defaultCenter]
            postNotificationName:OctoNotification
            object:self
            userInfo:[NSDictionary
                dictionaryWithObject:release
                forKey:OctoNotificationReleaseKey]];
    }];
}
@end

NSString *OctoNotification = @"OctoNotification";
NSString *OctoNotificationReleaseKey = @"OctoNotificationRelease";

NSString *OctoRepositoryKey = @"OctoRepository";
NSString *OctoCheckPeriodKey = @"OctoCheckPeriod";
NSString *OctoLastCheckTimeKey = @"OctoLastCheckTime";
