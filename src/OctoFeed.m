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

#import <OctoFeed/OctoFeed.h>

@interface OctoFeed ()
@property (retain) NSURLSession *session;
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
        self.repository = [bundle objectForInfoDictionaryKey:OctoFeedRepositoryKey];
        self.checkPeriod = [[bundle objectForInfoDictionaryKey:OctoFeedCheckPeriodKey] doubleValue];
        self.targetBundles = [NSArray arrayWithObject:bundle];
    }

    return self;
}

- (void)dealloc
{
    [self deactivate];

    self.repository = nil;
    self.checkPeriod = 0;
    self.targetBundles = nil;

    [super dealloc];
}

- (BOOL)activate
{
    if (nil != self.session)
        return YES;

    /* create our URL session */
    self.session = [NSURLSession
        sessionWithConfiguration:[NSURLSessionConfiguration ephemeralSessionConfiguration]
        delegate:nil
        delegateQueue:[NSOperationQueue mainQueue]];

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
    [self.session invalidateAndCancel];
    [self.timer invalidate];

    self.session = nil;
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
        objectForKey:OctoFeedLastCheckTimeKey];
    if (nil != checkTime)
        checkTime = [checkTime dateByAddingTimeInterval:checkPeriod];
    else
        checkTime = now;

    /* if the check time is in the future there is nothing to do */
    if (NSOrderedAscending == [now compare:checkTime])
        return;

    OctoRelease *release = [OctoRelease
        releaseWithRepository:self.repository
        targetBundles:self.targetBundles
        session:self.session];
    [release fetch:^(NSError *error)
    {
        if (nil != error)
            return;

        /* remember last check time */
        [[NSUserDefaults standardUserDefaults]
            setObject:[NSDate date]
            forKey:OctoFeedLastCheckTimeKey];

        /* tell everyone who cares */
        [[NSNotificationCenter defaultCenter]
            postNotificationName:OctoFeedNotification
            object:self];
    }];
}
@end

NSString *OctoFeedNotification = @"OctoFeedNotification";

NSString *OctoFeedRepositoryKey = @"OctoFeedRepository";
NSString *OctoFeedCheckPeriodKey = @"OctoFeedCheckPeriod";
NSString *OctoFeedLastCheckTimeKey = @"OctoFeedLastCheckTime";
