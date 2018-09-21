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
#import <OctoFeed/OctoRelease.h>

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

- (void)testGitHubRelease
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
}

- (void)testCachedRelease
{
    [self testGitHubRelease];

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
}
@end
