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

#if 0
@implementation OctoRelease
- (void)downloadAssets:(OctoReleaseCompletion)completion
{
    dispatch_group_t group = dispatch_group_create();
    __block NSMutableArray *assets = [NSMutableArray array];
    __block NSMutableArray *errors = [NSMutableArray array];

    for (NSURL *asset in self.releaseAssets)
    {
        dispatch_group_enter(group);

        [self.session
            downloadTaskWithURL:asset
            completionHandler:^(NSURL *url, NSURLResponse *response, NSError *error)
            {
                if (nil != url)
                {
                    NSURL *newurl = [[self.releaseFileURL
                        URLByAppendingPathComponent:@"downloadedAssets"]
                        URLByAppendingPathComponent:[url lastPathComponent]];
                    BOOL res = [[NSFileManager defaultManager]
                        moveItemAtURL:url
                        toURL:newurl
                        error:&error];
                    if (res)
                        [assets addObject:newurl];
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
            BOOL res = [[NSString stringWithFormat:@"%c", (char)OctoReleaseDownloaded]
                writeToURL:[self.releaseFileURL URLByAppendingPathComponent:@"release.state"]
                atomically:YES
                encoding:NSUTF8StringEncoding
                error:&error];
            if (res)
            {
                self.downloadedAssets = assets;
                completion(self.downloadedAssets, nil);
                self.state = OctoReleaseDownloaded;
            }
        }

        if (nil != error)
            completion(nil, error);

        dispatch_release(group);
    });
}

- (void)extractAssets:(OctoReleaseCompletion)completion
{
    dispatch_group_t group = dispatch_group_create();
    __block NSMutableArray *assets = [NSMutableArray array];
    __block NSMutableArray *errors = [NSMutableArray array];

    for (NSURL *asset in self.downloadedAssets)
    {
        dispatch_group_enter(group);

        NSURL *newurl = [[self.releaseFileURL
            URLByAppendingPathComponent:@"extractedAssets"]
            URLByAppendingPathComponent:[asset lastPathComponent]];
        [OctoUnarchiver unarchiveURL:asset toURL:newurl completion:^(NSError *error)
        {
            if (nil == error)
                [assets addObject:newurl];
            else
                [errors addObject:error];

            dispatch_group_leave(group);
        }];
    }

    dispatch_group_notify(group, dispatch_get_main_queue(), ^
    {
        NSError *error = [errors firstObject];
        if (nil == error)
        {
            BOOL res = [[NSString stringWithFormat:@"%c", (char)OctoReleaseExtracted]
                writeToURL:[self.releaseFileURL URLByAppendingPathComponent:@"release.state"]
                atomically:YES
                encoding:NSUTF8StringEncoding
                error:&error];
            if (res)
            {
                self.extractedAssets = assets;
                completion(self.extractedAssets, nil);
                self.state = OctoReleaseExtracted;
            }
        }

        if (nil != error)
            completion(nil, error);

        dispatch_release(group);
    });
}

- (void)verifyAssets:(OctoReleaseCompletion)completion
{
}

- (void)installAssets:(OctoReleaseCompletion)completion
{
}

- (void)launchAssets:(OctoReleaseCompletion)completion
{
}

- (void)clearAssets:(OctoReleaseCompletion)completion
{
}
@end
#endif
