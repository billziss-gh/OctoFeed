/**
 * @file OctoFeed/OctoCachedRelease.m
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
#import "NSString+Version.h"
#import "OctoError.h"

@implementation OctoCachedRelease
+ (void)load
{
    [self registerClass:@""];
}

- (void)fetch:(void (^)(NSError *))completion
{
    NSError *error = nil;

    [self fetchSynchronouslyIfAble:&error];

    [self octoPerformBlock:^
    {
        completion(error);
    } afterDelay:0];
}

- (BOOL)fetchSynchronouslyIfAble:(NSError **)errorp
{
    int64_t pendingUnitCount = 0;
    NSError *error = nil;
    NSArray<NSURL *> *urls = [[NSFileManager defaultManager]
        contentsOfDirectoryAtURL:self.cacheBaseURL
        includingPropertiesForKeys:nil
        options:0
        error:&error];
    urls = [urls sortedArrayUsingComparator:^NSComparisonResult(id url1, id url2)
    {
        return [[url1 lastPathComponent] versionCompare:[url2 lastPathComponent]];
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
            NSString *releaseVersion = nil;
            unsigned long long prerelease = 0;
            NSString *state = nil;
            NSMutableArray<NSURL *> *releaseAssets = [NSMutableArray array];
            BOOL res = YES;

            NSScanner *scanner = [NSScanner scannerWithString:str];
            scanner.charactersToBeSkipped = nil;
            res = res && [scanner scanUpToString:@"\n" intoString:&releaseVersion];
            res = res && [scanner scanString:@"\n" intoString:0];
            res = res && [scanner scanUnsignedLongLong:&prerelease];
            res = res && [scanner scanString:@"\n" intoString:0];
            res = res && [scanner scanUpToString:@"\n" intoString:&state];
            res = res && [scanner scanString:@"\n" intoString:0];
            res = res && 1 == [state length];
            while (res && ![scanner isAtEnd])
            {
                NSString *str = nil;
                res = res && [scanner scanUpToString:@"\n" intoString:&str];
                res = res && [scanner scanString:@"\n" intoString:0];
                if (res)
                {
                    NSURL *url = [NSURL URLWithString:str];
                    res = res && nil != url;
                    if (res)
                        [releaseAssets addObject:url];
                }
            }
            if (res)
            {
                NSArray<NSURL *> *preparedAssets = nil;
                unichar c = [state characterAtIndex:0];
                switch (c)
                {
                case OctoReleaseInstalled:
                case OctoReleaseReadyToInstall:
                    pendingUnitCount = 100;
                    preparedAssets = [[NSFileManager defaultManager]
                        contentsOfDirectoryAtURL:[[self.cacheBaseURL
                            URLByAppendingPathComponent:releaseVersion]
                            URLByAppendingPathComponent:@"preparedAssets"]
                        includingPropertiesForKeys:nil
                        options:0
                        error:0];
                    self._releaseVersion = releaseVersion;
                    self._prerelease = !!prerelease;
                    self._releaseAssets = releaseAssets;
                    self._preparedAssets = preparedAssets;
                    self._state = c;
                    break;
                case OctoReleaseFetched:
                    pendingUnitCount = 1;
                    self._releaseVersion = releaseVersion;
                    self._prerelease = !!prerelease;
                    self._releaseAssets = releaseAssets;
                    self._preparedAssets = preparedAssets;
                    self._state = c;
                    break;
                default:
                    res = NO;
                    break;
                }
            }

            if (!res)
                error = [NSError
                    errorWithDomain:OctoErrorDomain
                    code:OctoErrorReleaseStateCorrupted
                    userInfo:nil];
        }
    }

    if (0 != errorp)
        *errorp = error;

    if (nil == error && 0 < pendingUnitCount)
    {
        NSProgress *fetchProgress = [NSProgress
            progressWithTotalUnitCount:1 parent:self._progress pendingUnitCount:pendingUnitCount];
        fetchProgress.completedUnitCount = 1;
    }

    return YES;
}
@end
