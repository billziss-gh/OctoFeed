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
- (void)testGitHubReleaseInvalid
{
    NSArray *bundles = [NSArray arrayWithObject:[NSBundle mainBundle]];
    NSURLSession *session = [NSURLSession
        sessionWithConfiguration:[NSURLSessionConfiguration ephemeralSessionConfiguration]
        delegate:nil
        delegateQueue:[NSOperationQueue mainQueue]];
    OctoRelease *release = [OctoRelease
        releaseWithRepository:@"github.com/billziss-gh"
        targetBundles:bundles
        session:session];

    XCTestExpectation *exp = [self expectationWithDescription:@"fetch:"];

    [release fetch:^(NSError *error)
    {
        XCTAssertNotNil(error);

        [exp fulfill];
    }];

    [self waitForExpectations:[NSArray arrayWithObject:exp] timeout:10];
}

- (void)testGitHubReleaseUnknown
{
    NSArray *bundles = [NSArray arrayWithObject:[NSBundle mainBundle]];
    NSURLSession *session = [NSURLSession
        sessionWithConfiguration:[NSURLSessionConfiguration ephemeralSessionConfiguration]
        delegate:nil
        delegateQueue:[NSOperationQueue mainQueue]];
    OctoRelease *release = [OctoRelease
        releaseWithRepository:@"github.com/billziss-gh/NONEXISTENT-4dca3ed744f421f3187e54dc10e7e6b8"
        targetBundles:bundles
        session:session];

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
    NSArray *bundles = [NSArray arrayWithObject:[NSBundle mainBundle]];
    NSURLSession *session = [NSURLSession
        sessionWithConfiguration:[NSURLSessionConfiguration ephemeralSessionConfiguration]
        delegate:nil
        delegateQueue:[NSOperationQueue mainQueue]];
    OctoRelease *release = [OctoRelease
        releaseWithRepository:@"github.com/billziss-gh/EnergyBar"
        targetBundles:bundles
        session:session];

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

        [exp fulfill];
    }];

    [self waitForExpectations:[NSArray arrayWithObject:exp] timeout:10];

    return release;
}

- (void)testGitHubRelease
{
    [self _githubRelease];
}

- (void)testCachedRelease
{
    OctoRelease *githubRelease = [self _githubRelease];

    NSArray *bundles = [NSArray arrayWithObject:[NSBundle mainBundle]];
    NSURLSession *session = [NSURLSession
        sessionWithConfiguration:[NSURLSessionConfiguration ephemeralSessionConfiguration]
        delegate:nil
        delegateQueue:[NSOperationQueue mainQueue]];
    OctoRelease *release = [OctoRelease
        releaseWithRepository:nil
        targetBundles:bundles
        session:session];

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

        [exp fulfill];
    }];

    [self waitForExpectations:[NSArray arrayWithObject:exp] timeout:10];

    XCTAssertEqualObjects(githubRelease.releaseVersion, release.releaseVersion);
    XCTAssertEqual(githubRelease.prerelease, release.prerelease);
    XCTAssertEqual(githubRelease.releaseAssets.count, release.releaseAssets.count);
    for (NSUInteger index = 0, count = githubRelease.releaseAssets.count; count > index; index++)
        XCTAssertEqualObjects(
            [githubRelease.releaseAssets objectAtIndex:index],
            [release.releaseAssets objectAtIndex:index]);
}

- (void)testDownload
{
    OctoRelease *release = [self _githubRelease];

    XCTestExpectation *exp = [self expectationWithDescription:@"downloadAssets:"];
    [release downloadAssets:^(
        NSDictionary<NSURL *,NSURL *> *assets, NSDictionary<NSURL *,NSError *> *errors)
    {
        XCTAssertEqual(1, assets.count);
        XCTAssertNil(errors);

        NSLog(@"%@", assets);

        [exp fulfill];
    }];

    [self waitForExpectations:[NSArray arrayWithObject:exp] timeout:10];

    XCTAssertEqual(1, release.downloadedAssets.count);
}
@end
