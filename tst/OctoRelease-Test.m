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
- (void)testGitHubRelease
{
#if 0
    NSArray *bundles = [NSArray arrayWithObject:[NSBundle mainBundle]];
    NSURLSession *session = [NSURLSession
        sessionWithConfiguration:[NSURLSessionConfiguration ephemeralSessionConfiguration]
        delegate:nil
        delegateQueue:[NSOperationQueue mainQueue]];
    OctoRelease *release = [OctoRelease
        releaseWithRepository:@"github.com/billziss-gh/EnergyBar"
        targetBundles:bundles
        session:session];
    [release fetchFromRepository:@"github.com/billziss-gh/EnergyBar" completion:^(NSError *error)
    {
    }];
#endif
}
@end
