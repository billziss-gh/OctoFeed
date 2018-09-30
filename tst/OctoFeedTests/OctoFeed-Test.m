/**
 * @file OctoFeed-Test.m
 *
 * @copyright 2018 Bill Zissimopoulos
 */
/*
 * This file is part of OctoFeed.
 *
 * It is licensed under the MIT license. The full license text can be found
 * in the License.txt file at the root of this project.
 */

#import <XCTest/XCTest.h>
#import "OctoFeed.h"

@interface OctoFeedTest : XCTestCase
@end

@implementation OctoFeedTest
- (void)setUp
{
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:OctoLastCheckTimeKey];
    [[NSFileManager defaultManager] removeItemAtURL:[OctoRelease defaultCacheBaseURL] error:0];
}

- (void)tearDown
{
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:OctoLastCheckTimeKey];
    [[NSFileManager defaultManager] removeItemAtURL:[OctoRelease defaultCacheBaseURL] error:0];
}

- (void)testCheckNonExistent
{
    OctoFeed *feed = [[[OctoFeed alloc] initWithBundle:nil] autorelease];
    feed.repository = @"github.com/billziss-gh/NONEXISTENT-4dca3ed744f421f3187e54dc10e7e6b8";

    XCTestExpectation *exp = [self expectationWithDescription:@"fetch:"];

    [feed check:^(OctoRelease *release, NSError *error)
    {
        XCTAssertNotNil(error);
        XCTAssertNil(release);

        [exp fulfill];
    }];

    [self waitForExpectations:[NSArray arrayWithObject:exp] timeout:10];
}

- (void)testCheck
{
    OctoFeed *feed = [[[OctoFeed alloc] initWithBundle:nil] autorelease];
    feed.repository = @"github.com/billziss-gh/OctoFeed";

    XCTestExpectation *exp = [self expectationWithDescription:@"fetch:"];

    [feed check:^(OctoRelease *release, NSError *error)
    {
        XCTAssertNil(error);
        XCTAssertNotNil(release);

        [feed clearThisAndPriorReleases:release];

        [exp fulfill];
    }];

    [self waitForExpectations:[NSArray arrayWithObject:exp] timeout:10];
}

- (void)testActivateInstallNone
{
    [[NSUserDefaults standardUserDefaults]
        removeObjectForKey:OctoLastCheckTimeKey];

    OctoFeed *feed = [[[OctoFeed alloc] initWithBundle:nil] autorelease];
    feed.repository = @"github.com/billziss-gh/OctoFeed";

    XCTestExpectation *exp = [self
        expectationForNotification:OctoNotification
        object:nil
        handler:^BOOL (NSNotification * _Nonnull notification)
        {
            OctoRelease *release = [notification.userInfo objectForKey:OctoNotificationReleaseKey];
            XCTAssertNotNil(release);

            [[OctoFeed mainBundleFeed] clearThisAndPriorReleases:release];
            return YES;
        }];

    [feed activateWithInstallPolicy:OctoFeedInstallNone];

    [self waitForExpectations:[NSArray arrayWithObject:exp] timeout:10];
}

- (void)testActivateInstallWhenReady
{
    [[NSUserDefaults standardUserDefaults]
        removeObjectForKey:OctoLastCheckTimeKey];

    OctoFeed *feed = [[[OctoFeed alloc] initWithBundle:nil] autorelease];
    feed.repository = @"github.com/billziss-gh/OctoFeed";

    __block int count = 0;
    XCTestExpectation *exp = [self
        expectationForNotification:OctoNotification
        object:nil
        handler:^BOOL (NSNotification * _Nonnull notification)
        {
            OctoRelease *release = [notification.userInfo objectForKey:OctoNotificationReleaseKey];
            XCTAssertNotNil(release);

            NSLog(@"State=%@", [notification.userInfo objectForKey:OctoNotificationReleaseStateKey]);

            count++;
            if (2 <= count)
            {
                [[OctoFeed mainBundleFeed] clearThisAndPriorReleases:release];
                return YES;
            }
            else
                return NO;
        }];

    [feed activateWithInstallPolicy:OctoFeedInstallWhenReady];

    [self waitForExpectations:[NSArray arrayWithObject:exp] timeout:10];
}

- (void)testActivateInstallCheck
{
    [[NSUserDefaults standardUserDefaults]
        removeObjectForKey:OctoLastCheckTimeKey];

    OctoFeed *feed = [[[OctoFeed alloc] initWithBundle:nil] autorelease];
    feed.repository = @"github.com/billziss-gh/OctoFeed";

    XCTestExpectation *exp = [self
        expectationForNotification:OctoNotification
        object:nil
        handler:^BOOL (NSNotification * _Nonnull notification)
        {
            OctoRelease *release = [notification.userInfo objectForKey:OctoNotificationReleaseKey];
            XCTAssertNotNil(release);

            [[OctoFeed mainBundleFeed] clearThisAndPriorReleases:release];
            return YES;
        }];

    [feed activateWithInstallPolicy:OctoFeedInstallNone];

    [self waitForExpectations:[NSArray arrayWithObject:exp] timeout:10];

    XCTestExpectation *exp2 = [self expectationWithDescription:@"fetch:"];

    [feed check:^(OctoRelease *release, NSError *error)
    {
        XCTAssertNil(error);
        XCTAssertNotNil(release);

        [feed clearThisAndPriorReleases:release];

        [exp2 fulfill];
    }];

    [self waitForExpectations:[NSArray arrayWithObject:exp2] timeout:10];
}

@end
