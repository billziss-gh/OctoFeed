/**
 * @file OctoGitHubRelease.m
 *
 * @copyright 2018 Bill Zissimopoulos
 */
/*
 * This file is part of OctoFeed.
 *
 * It is licensed under the MIT license. The full license text can be found
 * in the License.txt file at the root of this project.
 */

#import "OctoGitHubRelease.h"
#import "NSObject+OctoExtensions.h"
#import "NSString+Version.h"

@implementation OctoGitHubRelease
+ (void)load
{
    [self registerClass:@"github.com"];
}

- (void)fetch:(void (^)(NSError *))completion
{
    NSArray *parts = [self.repository componentsSeparatedByString:@"/"];
    if (3 != parts.count || ![[parts firstObject] isEqualToString:@"github.com"])
    {
        NSLog(@"OctoFeed: invalid repository; repositories must be of the form: %@",
            @"github.com/:owner/:repo");
        [self octoPerformBlock:^
        {
            NSError *error = [NSError
                errorWithDomain:NSPOSIXErrorDomain
                code:EINVAL
                userInfo:nil];
            completion(error);
        } afterDelay:0];
        return;
    }

    NSURL *releaseURL = [NSURL
        URLWithString:[NSString stringWithFormat:@"https://api.github.com/repos/%@/%@/releases/latest",
            [parts objectAtIndex:1],
            [parts objectAtIndex:2]]];
    [[self.session
        dataTaskWithURL:releaseURL
        completionHandler:^(NSData *data, NSURLResponse *response, NSError *error)
        {
            if (nil != error)
            {
                NSLog(@"OctoFeed: URL session error: %@", error);
                goto fail;
            }

            if ([response respondsToSelector:@selector(statusCode)])
                if (200 != [(id)response statusCode])
                {
                    NSLog(@"OctoFeed: bad HTTP status %d", (int)[(id)response statusCode]);
                    goto corrupt_fail;
                }

            id obj = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
            if (nil != error)
            {
                NSLog(@"OctoFeed: JSON error: %@", error);
                goto fail;
            }
            if (![obj isKindOfClass:[NSDictionary class]])
            {
                NSLog(@"OctoFeed: JSON error: %@", @"invalid top level element; must be object");
                goto corrupt_fail;
            }

            id tag = [obj objectForKey:@"tag_name"];
            id prerelease = [obj objectForKey:@"prerelease"];
            id assets = [obj objectForKey:@"assets"];
            if (nil == tag || ![tag isKindOfClass:[NSString class]])
            {
                NSLog(@"OctoFeed: JSON error: %@", @"missing or invalid \"tag_name\"");
                goto corrupt_fail;
            }
            if (nil != prerelease && ![prerelease isKindOfClass:[NSNumber class]])
            {
                NSLog(@"OctoFeed: JSON error: %@", @"invalid \"prerelease\"");
                goto corrupt_fail;
            }
            if (nil == assets || ![assets isKindOfClass:[NSArray class]])
            {
                NSLog(@"OctoFeed: JSON error: %@", @"missing or invalid \"assets\"");
                goto corrupt_fail;
            }

            if ([tag hasPrefix:@"v"])
                tag = [tag substringFromIndex:1];
            if (![tag versionValidate])
            {
                NSLog(@"OctoFeed: JSON error: %@", @"invalid \"tag_name\"; not a proper semver");
                goto corrupt_fail;
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
                NSLog(@"OctoFeed: JSON error: %@", @"missing or invalid \"assets\"");
                goto corrupt_fail;
            }

            self._releaseVersion = tag;
            self._prerelease = [prerelease boolValue];
            self._releaseAssets = urls;
            self._state = OctoReleaseFetched;

            completion(nil);
            return;

        corrupt_fail:
            error = [NSError
                errorWithDomain:NSCocoaErrorDomain
                code:NSPropertyListReadCorruptError
                userInfo:nil];
        fail:
            completion(error);
            return;
        }]
        resume];
}
@end
