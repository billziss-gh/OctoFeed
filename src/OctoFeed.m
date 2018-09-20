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
#import "NSString+SemVer.h"
#import "OctoUnarchiver.h"

#define LOG(format, ...)                NSLog(@ "OctoFeed: " format, __VA_ARGS__)

@interface OctoRelease ()
@property (retain) NSURLSession *session;
@property (copy) NSURL *releaseFileURL;
@property (copy) NSString *releaseVersion;
@property (assign) BOOL prerelease;
@property (copy) NSArray<NSURL *> *releaseAssets;
@property (copy) NSArray<NSURL *> *downloadedAssets;
@property (copy) NSArray<NSURL *> *extractedAssets;
@property (copy) NSString *currentVersion;
@property (copy) NSURL *currentSignature;
@property (assign) OctoReleaseState state;
@end

@implementation OctoRelease
- (void)dealloc
{
    self.session = nil;
    self.releaseFileURL = nil;
    self.releaseVersion = nil;
    self.prerelease = NO;
    self.releaseAssets = nil;
    self.downloadedAssets = nil;
    self.extractedAssets = nil;
    self.currentVersion = nil;
    self.currentSignature = nil;
    self.state = OctoReleaseReady;

    [super dealloc];
}

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

@interface OctoFeed ()
@property (retain) NSURL *releaseURL;
@property (retain) NSURLSession *session;
@property (retain) NSTimer *timer;
@end

@implementation OctoFeed
+ (NSURL *)releaseURLFromRepository:(NSString *)repository
{
    NSArray *parts = [repository componentsSeparatedByString:@"/"];

    if (3 != parts.count || ![[parts firstObject] isEqualToString:@"github.com"])
        goto fail;

    return [NSURL
        URLWithString:[NSString stringWithFormat:@"https://api.github.com/repos/%@/%@/releases",
            [parts objectAtIndex:1],
            [parts objectAtIndex:2]]];

fail:
    LOG("invalid repository; repositories must be of the form: %@", @"github.com/:owner/:repo");

    return nil;
}

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
        self.currentVersion = [bundle objectForInfoDictionaryKey:(NSString *)kCFBundleVersionKey];
        self.currentSignature = [bundle bundleURL];
        self.releaseCacheURL = [
            [[[NSFileManager defaultManager]
                URLsForDirectory:NSCachesDirectory inDomains:NSUserDomainMask] firstObject]
            URLByAppendingPathComponent:[bundle bundleIdentifier]];
    }

    return self;
}

- (void)dealloc
{
    [self deactivate];

    self.repository = nil;
    self.checkPeriod = 0;
    self.currentVersion = nil;
    self.currentSignature = nil;
    self.releaseCacheURL = nil;

    [super dealloc];
}

- (BOOL)activate
{
    if (nil != self.releaseURL)
        return YES;

    /* create the release URL from the repository */
    NSURL *releaseURL = [OctoFeed releaseURLFromRepository:self.repository];
    if (nil == releaseURL)
        return NO;
    self.releaseURL = releaseURL;

    /* get a pending release if any */
    NSArray<NSURL *> *urls = [[NSFileManager defaultManager]
        contentsOfDirectoryAtURL:self.releaseCacheURL
        includingPropertiesForKeys:nil
        options:0
        error:0];
    urls = [urls sortedArrayUsingComparator:^NSComparisonResult(id url1, id url2)
    {
        return [[url1 lastPathComponent] semverCompare:[url2 lastPathComponent]];
    }];
    NSURL *url = [urls lastObject];
    if (nil != url)
    {
        NSData *data = [NSData
            dataWithContentsOfURL:[url URLByAppendingPathComponent:@"release.json"]];
        if (nil != data)
        {
            OctoRelease *release = [self releaseFromJSON:data];
            if (nil != release)
                self.latestRelease = release;
        }
    }

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
    self.releaseURL = nil;
    self.latestRelease = nil;
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

    [[self.session
        dataTaskWithURL:self.releaseURL
        completionHandler:^(NSData *data, NSURLResponse *response, NSError *error)
        {
            if (nil != error)
            {
                LOG(@"URL session error: %@", error);
                return;
            }

            OctoRelease *release = [self releaseFromJSON:data];
            if (nil == release)
                return;

            BOOL res = [[NSFileManager defaultManager]
                createDirectoryAtURL:release.releaseFileURL
                withIntermediateDirectories:YES
                attributes:nil
                error:0];
            if (!res)
                return;
            res = [data
                writeToURL:[release.releaseFileURL URLByAppendingPathComponent:@"release.json"]
                atomically:YES];
            if (!res)
                return;

            self.latestRelease = release;

            [[NSUserDefaults standardUserDefaults]
                setObject:[NSDate date]
                forKey:OctoFeedLastCheckTimeKey];
        }]
        resume];
}

- (OctoRelease *)releaseFromJSON:(NSData *)data
{
    NSError *error = nil;

    id obj = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
    if (nil != error)
    {
        LOG(@"JSON error: %@", error);
        return nil;
    }
    if (![obj isKindOfClass:[NSDictionary class]])
    {
        LOG(@"JSON error: %@", @"invalid top level element; must be object");
        return nil;
    }

    id tag = [obj objectForKey:@"tag_name"];
    id prerelease = [obj objectForKey:@"prerelease"];
    id assets = [obj objectForKey:@"assets"];

    if (nil == tag || ![tag isKindOfClass:[NSString class]])
    {
        LOG(@"JSON error: %@", @"missing or invalid \"tag_name\"");
        return nil;
    }
    if (nil != prerelease && ![prerelease isKindOfClass:[NSNumber class]])
    {
        LOG(@"JSON error: %@", @"invalid \"prerelease\"");
        return nil;
    }
    if (nil == assets || ![assets isKindOfClass:[NSArray class]])
    {
        LOG(@"JSON error: %@", @"missing or invalid \"assets\"");
        return nil;
    }

    if ([tag hasPrefix:@"v"])
        tag = [tag substringFromIndex:1];
    if (![tag semverValidate])
    {
        LOG(@"JSON error: %@", @"invalid \"tag_name\"; not a proper semver");
        return nil;
    }

    NSMutableArray<NSURL *> *urls = [NSMutableArray array];
    for (id asset in assets)
    {
        if (![asset isKindOfClass:[NSDictionary class]])
            continue;

        id urlstr = [asset objectForKey:@"browser_download_url"];
        if (![urlstr isKindOfClass:[NSString class]])
            continue;

        NSURL *url = [NSURL URLWithString:urlstr];
        if (nil == url || NSOrderedSame != [url.scheme caseInsensitiveCompare:@"https"])
            continue;

        [urls addObject:url];
    }

    if (0 == urls.count)
    {
        LOG(@"JSON error: %@", @"missing or invalid \"assets\"");
        return nil;
    }
    if (1 < urls.count)
        for (NSURL *url in urls)
        {
            NSString *name = [[url lastPathComponent] stringByDeletingPathExtension];
            if ([name hasSuffix:@"-mac"] || [name containsString:@"-mac-"])
            {
                urls = [NSMutableArray arrayWithObject:url];
                break;
            }
        }
    if (1 < urls.count)
        urls = [NSMutableArray arrayWithObject:[urls firstObject]];

    OctoRelease *release = [[[OctoRelease alloc] init] autorelease];
    release.session = self.session;
    release.releaseFileURL = [self.releaseCacheURL URLByAppendingPathComponent:tag];
    release.releaseVersion = tag;
    release.prerelease = [prerelease boolValue];
    release.releaseAssets = urls;
    release.currentVersion = self.currentVersion;
    release.currentSignature = self.currentSignature;

    return nil;
}

- (void)setLatestRelease:(OctoRelease *)value
{
    [_latestRelease release];
    _latestRelease = [value retain];
    if (nil != _latestRelease)
        [[NSNotificationCenter defaultCenter] postNotificationName:OctoFeedNotification object:self];
}
@end

NSString *OctoFeedNotification = @"OctoFeedNotification";

NSString *OctoFeedRepositoryKey = @"OctoFeedRepository";
NSString *OctoFeedCheckPeriodKey = @"OctoFeedCheckPeriod";
NSString *OctoFeedLastCheckTimeKey = @"OctoFeedLastCheckTime";
