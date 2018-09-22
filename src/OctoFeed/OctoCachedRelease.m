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
#import "NSString+Version.h"

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
                NSArray<NSURL *> *downloadedAssets = nil;
                NSArray<NSURL *> *extractedAssets = nil;
                unichar c = [state characterAtIndex:0];
                switch (c)
                {
                case OctoReleaseInstalled:
                case OctoReleaseExtracted:
                    extractedAssets = [[NSFileManager defaultManager]
                        contentsOfDirectoryAtURL:[[self.cacheBaseURL
                            URLByAppendingPathComponent:releaseVersion]
                            URLByAppendingPathComponent:@"extractedAssets"]
                        includingPropertiesForKeys:nil
                        options:0
                        error:0];
                    /* fall through */
                case OctoReleaseDownloaded:
                    downloadedAssets = [[NSFileManager defaultManager]
                        contentsOfDirectoryAtURL:[[self.cacheBaseURL
                            URLByAppendingPathComponent:releaseVersion]
                            URLByAppendingPathComponent:@"downloadedAssets"]
                        includingPropertiesForKeys:nil
                        options:0
                        error:0];
                    /* fall through */
                case OctoReleaseFetched:
                    self._releaseVersion = releaseVersion;
                    self._prerelease = !!prerelease;
                    self._releaseAssets = releaseAssets;
                    self._downloadedAssets = downloadedAssets;
                    self._extractedAssets = extractedAssets;
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

    if (0 != errorp)
        *errorp = error;

    return YES;
}
@end
