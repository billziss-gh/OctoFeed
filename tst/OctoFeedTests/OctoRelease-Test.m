/**
 * @file OctoRelease-Test.m
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
#import "OctoRelease.h"

@interface OctoReleaseTest : XCTestCase
@end

@implementation OctoReleaseTest
- (void)testGitHubFetchInvalid
{
    OctoRelease *release = [OctoRelease releaseWithRepository:@"github.com/billziss-gh"];

    XCTestExpectation *exp = [self expectationWithDescription:@"fetch:"];

    [release fetch:^(NSError *error)
    {
        XCTAssertNotNil(error);

        [exp fulfill];
    }];

    [self waitForExpectations:[NSArray arrayWithObject:exp] timeout:10];
}

- (void)testGitHubFetchUnknown
{
    OctoRelease *release = [OctoRelease
        releaseWithRepository:@"github.com/billziss-gh/NONEXISTENT-4dca3ed744f421f3187e54dc10e7e6b8"];

    XCTestExpectation *exp = [self expectationWithDescription:@"fetch:"];

    [release fetch:^(NSError *error)
    {
        XCTAssertNotNil(error);

        [exp fulfill];
    }];

    [self waitForExpectations:[NSArray arrayWithObject:exp] timeout:10];
}

- (OctoRelease *)_githubRelease
{
    OctoRelease *release = [OctoRelease releaseWithRepository:@"github.com/billziss-gh/EnergyBar"];

    BOOL res = [release fetchSynchronouslyIfAble:0];
    XCTAssertFalse(res);

    XCTestExpectation *exp = [self expectationWithDescription:@"fetch:"];

    [release fetch:^(NSError *error)
    {
        XCTAssertNil(error);

        XCTAssertNotNil(release.releaseVersion);
        XCTAssertNotNil(release.releaseAssets);

        NSLog(@"%@%@%@",
            release.releaseVersion,
            release.prerelease ? @" pre " : @" ",
            release.releaseAssets);

        [release commit];

        [exp fulfill];
    }];

    [self waitForExpectations:[NSArray arrayWithObject:exp] timeout:10];

    return release;
}

- (void)_clearRelease:(OctoRelease *)release
{
    NSError *error = [release clear];
    XCTAssertNil(error);

    XCTAssertEqual(OctoReleaseEmpty, release.state);
}

- (void)testGitHubFetch
{
    OctoRelease *release = [self _githubRelease];
    [self _clearRelease:release];
}

- (void)testGitHubDownload
{
    OctoRelease *release = [self _githubRelease];

    XCTestExpectation *exp = [self expectationWithDescription:@"downloadAssets:"];

    [release downloadAssets:^(
        NSDictionary<NSURL *, NSURL *> *assets, NSDictionary<NSURL *, NSError *> *errors)
    {
        XCTAssertEqual(1, assets.count);
        XCTAssertNil(errors);

        XCTAssertEqual(OctoReleaseDownloaded, release.state);

        NSSet *set0 = [NSSet setWithArray:release.downloadedAssets];
        NSSet *set1 = [NSSet setWithArray:[assets allValues]];
        XCTAssertEqualObjects(set0, set1);

        NSLog(@"%@", assets);

        [exp fulfill];
    }];

    [self waitForExpectations:[NSArray arrayWithObject:exp] timeout:10];

    [self _clearRelease:release];
}

- (void)testGitHubDownloadAndExtract
{
    OctoRelease *release = [self _githubRelease];

    XCTestExpectation *exp = [self expectationWithDescription:@"downloadAssets:"];

    [release downloadAssets:^(
        NSDictionary<NSURL *, NSURL *> *assets, NSDictionary<NSURL *, NSError *> *errors)
    {
        XCTAssertEqual(1, assets.count);
        XCTAssertNil(errors);

        XCTAssertEqual(OctoReleaseDownloaded, release.state);

        NSSet *set0 = [NSSet setWithArray:release.downloadedAssets];
        NSSet *set1 = [NSSet setWithArray:[assets allValues]];
        XCTAssertEqualObjects(set0, set1);

        [release extractAssets:^(
            NSDictionary<NSURL *, NSURL *> *assets, NSDictionary<NSURL *, NSError *> *errors)
        {
            XCTAssertEqual(1, assets.count);
            XCTAssertNil(errors);

            XCTAssertEqual(OctoReleaseExtracted, release.state);

            NSSet *set0 = [NSSet setWithArray:release.extractedAssets];
            NSSet *set1 = [NSSet setWithArray:[assets allValues]];
            XCTAssertEqualObjects(set0, set1);

            NSLog(@"%@", assets);

            [exp fulfill];
        }];
    }];

    [self waitForExpectations:[NSArray arrayWithObject:exp] timeout:10];

    [self _clearRelease:release];
}

- (void)testCachedFetch
{
    OctoRelease *release = [self _githubRelease];
    OctoRelease *cachedRelease = [OctoRelease releaseWithRepository:nil];

    XCTestExpectation *exp = [self expectationWithDescription:@"fetch:"];

    [cachedRelease fetch:^(NSError *error)
    {
        XCTAssertNil(error);

        XCTAssertNotNil(cachedRelease.releaseVersion);
        XCTAssertNotNil(cachedRelease.releaseAssets);

        NSLog(@"%@%@%@",
            cachedRelease.releaseVersion,
            cachedRelease.prerelease ? @" pre " : @" ",
            cachedRelease.releaseAssets);

        [exp fulfill];
    }];

    [self waitForExpectations:[NSArray arrayWithObject:exp] timeout:10];

    XCTAssertEqualObjects(release.releaseVersion, cachedRelease.releaseVersion);
    XCTAssertEqual(release.prerelease, cachedRelease.prerelease);
    XCTAssertEqualObjects(release.releaseAssets, cachedRelease.releaseAssets);
    XCTAssertEqual(release.state, cachedRelease.state);

    [self _clearRelease:cachedRelease];
}

- (void)testCachedFetchSynchronously
{
    OctoRelease *release = [self _githubRelease];
    OctoRelease *cachedRelease = [OctoRelease releaseWithRepository:nil];

    NSError *error = nil;
    BOOL res = [cachedRelease fetchSynchronouslyIfAble:&error];
    XCTAssertTrue(res);
    XCTAssertNil(error);

    XCTAssertNotNil(cachedRelease.releaseVersion);
    XCTAssertNotNil(cachedRelease.releaseAssets);

    NSLog(@"%@%@%@",
        cachedRelease.releaseVersion,
        cachedRelease.prerelease ? @" pre " : @" ",
        cachedRelease.releaseAssets);

    XCTAssertEqualObjects(release.releaseVersion, cachedRelease.releaseVersion);
    XCTAssertEqual(release.prerelease, cachedRelease.prerelease);
    XCTAssertEqualObjects(release.releaseAssets, cachedRelease.releaseAssets);
    XCTAssertEqual(release.state, cachedRelease.state);

    [self _clearRelease:cachedRelease];
}

- (void)testGitHubDownloadAndExtractCachedFetch
{
    OctoRelease *release = [self _githubRelease];

    XCTestExpectation *exp = [self expectationWithDescription:@"downloadAssets:"];

    [release downloadAssets:^(
        NSDictionary<NSURL *, NSURL *> *assets, NSDictionary<NSURL *, NSError *> *errors)
    {
        XCTAssertEqual(1, assets.count);
        XCTAssertNil(errors);

        XCTAssertEqual(OctoReleaseDownloaded, release.state);

        NSSet *set0 = [NSSet setWithArray:release.downloadedAssets];
        NSSet *set1 = [NSSet setWithArray:[assets allValues]];
        XCTAssertEqualObjects(set0, set1);

        [release extractAssets:^(
            NSDictionary<NSURL *, NSURL *> *assets, NSDictionary<NSURL *, NSError *> *errors)
        {
            XCTAssertEqual(1, assets.count);
            XCTAssertNil(errors);

            XCTAssertEqual(OctoReleaseExtracted, release.state);

            NSSet *set0 = [NSSet setWithArray:release.extractedAssets];
            NSSet *set1 = [NSSet setWithArray:[assets allValues]];
            XCTAssertEqualObjects(set0, set1);

            NSLog(@"%@", assets);

            [exp fulfill];
        }];
    }];

    [self waitForExpectations:[NSArray arrayWithObject:exp] timeout:10];

    OctoRelease *cachedRelease = [OctoRelease releaseWithRepository:nil];

    XCTestExpectation *exp1 = [self expectationWithDescription:@"fetch:"];

    [cachedRelease fetch:^(NSError *error)
    {
        XCTAssertNil(error);

        XCTAssertNotNil(cachedRelease.releaseVersion);
        XCTAssertNotNil(cachedRelease.releaseAssets);

        NSLog(@"%@%@%@",
            cachedRelease.releaseVersion,
            cachedRelease.prerelease ? @" pre " : @" ",
            cachedRelease.releaseAssets);

        [exp1 fulfill];
    }];

    [self waitForExpectations:[NSArray arrayWithObject:exp1] timeout:10];

    XCTAssertEqualObjects(release.releaseVersion, cachedRelease.releaseVersion);
    XCTAssertEqual(release.prerelease, cachedRelease.prerelease);
    XCTAssertEqualObjects(release.releaseAssets, cachedRelease.releaseAssets);
    XCTAssertEqualObjects(release.downloadedAssets, cachedRelease.downloadedAssets);
    XCTAssertEqualObjects(release.extractedAssets, cachedRelease.extractedAssets);
    XCTAssertEqual(release.state, cachedRelease.state);

    [self _clearRelease:cachedRelease];
}
@end
