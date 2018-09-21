/**
 * @file OctoCachedRelease.m
 *
 * @copyright 2018 Bill Zissimopoulos
 */
/*
 * This file is part of OctoFeed.
 *
 * It is licensed under the MIT license. The full license text can be found
 * in the License.txt file at the root of this project.
 */

#import "OctoCachedRelease.h"
#import "NSObject+OctoExtensions.h"
#import "NSString+OctoVersion.h"

@interface OctoCachedRelease ()
@property (copy) NSString *releaseVersion;
@property (assign) BOOL prerelease;
@property (copy) NSArray<NSURL *> *releaseAssets;
@end

@implementation OctoCachedRelease
+ (void)load
{
    [self registerClass:@""];
}

- (void)dealloc
{
    self.releaseVersion = nil;
    self.prerelease = NO;
    self.releaseAssets = nil;

    [super dealloc];
}

- (void)fetchFromRepository:(NSString *)repository completion:(void (^)(NSError *))completion
{
    NSError *error = nil;
    NSArray<NSURL *> *urls = [[NSFileManager defaultManager]
        contentsOfDirectoryAtURL:self.cacheURL
        includingPropertiesForKeys:nil
        options:0
        error:&error];
    urls = [urls sortedArrayUsingComparator:^NSComparisonResult(id url1, id url2)
    {
        return [[url1 lastPathComponent] octoVersionCompare:[url2 lastPathComponent]];
    }];

    NSURL *url = [urls lastObject];
    if (nil != url)
    {
        NSString *str = [NSString
            stringWithContentsOfURL:[url URLByAppendingPathComponent:@"state"]
            encoding:NSUTF8StringEncoding
            error:&error];
        if (nil != str)
        {
            NSScanner *scanner = [NSScanner scannerWithString:str];
            NSString *releaseVersion = nil;
            unsigned long long prerelease = 0;
            NSString *state = nil;
            BOOL res = YES;

            res = res && [scanner scanUpToString:@"\n" intoString:&releaseVersion];
            res = res && [scanner scanString:@"\n" intoString:0];
            res = res && [scanner scanUnsignedLongLong:&prerelease];
            res = res && [scanner scanString:@"\n" intoString:0];
            res = res && [scanner scanUpToString:@"\n" intoString:&state];
            res = res && [scanner scanString:@"\n" intoString:0];
            res = res && 1 == [state length];
            if (res)
            {
                unichar c = [state characterAtIndex:0];
                switch (c)
                {
                case OctoReleaseFetched:
                case OctoReleaseDownloaded:
                case OctoReleaseExtracted:
                case OctoReleaseVerified:
                case OctoReleaseInstalled:
                case OctoReleaseLaunched:
                    self.releaseVersion = releaseVersion;
                    self.prerelease = !!prerelease;
                    [self _setState:c persistent:NO];
                    break;
                default:
                    res = NO;
                    break;
                }
            }
            if (!res)
                error = [NSError errorWithDomain:NSPOSIXErrorDomain code:EINVAL userInfo:nil];
        }
    }

    [self octoPerformBlock:^
    {
        completion(error);
    } afterDelay:0];
}
@end
