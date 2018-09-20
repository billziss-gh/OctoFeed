/**
 * @file NSString+OctoVersion-Test.m
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
#import "NSString+OctoVersion.h"

@interface NSStringOctoVersionTest : XCTestCase
@end

@implementation NSStringOctoVersionTest
- (void)testOctoVersionValidate
{
    XCTAssertFalse([@"" octoVersionValidate]);
    XCTAssertFalse([@"B" octoVersionValidate]);
    XCTAssertFalse([@"99" octoVersionValidate]);
    XCTAssertFalse([@"99B" octoVersionValidate]);
    XCTAssertFalse([@"99." octoVersionValidate]);
    XCTAssertFalse([@"99.B" octoVersionValidate]);
    XCTAssertTrue([@"99.1" octoVersionValidate]);
    XCTAssertTrue([@"99.1B" octoVersionValidate]);
    XCTAssertTrue([@"99.1.1" octoVersionValidate]);
    XCTAssertTrue([@"99.1.1B" octoVersionValidate]);
    XCTAssertFalse([@" 99.1.1" octoVersionValidate]);
    XCTAssertFalse([@"99. 1.1" octoVersionValidate]);
    XCTAssertTrue([@"99.1 B" octoVersionValidate]);
}

- (void)testOctoVersionCompare
{
    XCTAssertEqual(NSOrderedSame, [@"1.1" octoVersionCompare:@"1.1"]);

    XCTAssertEqual(NSOrderedAscending, [@"1.1" octoVersionCompare:@"1.2"]);
    XCTAssertEqual(NSOrderedAscending, [@"2.1" octoVersionCompare:@"10.1"]);
    XCTAssertEqual(NSOrderedAscending, [@"1.1B" octoVersionCompare:@"1.1"]);
    XCTAssertEqual(NSOrderedAscending, [@"1.1.1.1B" octoVersionCompare:@"1.1.1.1"]);
    XCTAssertEqual(NSOrderedDescending, [@"1.2B" octoVersionCompare:@"1.1"]);
    XCTAssertEqual(NSOrderedDescending, [@"1.1.1.2B" octoVersionCompare:@"1.1.1.1"]);
    XCTAssertEqual(NSOrderedAscending, [@"1.1B2" octoVersionCompare:@"1.1B10"]);

    XCTAssertEqual(NSOrderedDescending, [@"1.2" octoVersionCompare:@"1.1"]);
    XCTAssertEqual(NSOrderedDescending, [@"10.1" octoVersionCompare:@"2.1"]);
    XCTAssertEqual(NSOrderedDescending, [@"1.1" octoVersionCompare:@"1.1B"]);
    XCTAssertEqual(NSOrderedDescending, [@"1.1.1.1" octoVersionCompare:@"1.1.1.1B"]);
    XCTAssertEqual(NSOrderedAscending, [@"1.1" octoVersionCompare:@"1.2B"]);
    XCTAssertEqual(NSOrderedAscending, [@"1.1.1.1" octoVersionCompare:@"1.1.1.2B"]);
    XCTAssertEqual(NSOrderedDescending, [@"1.1B10" octoVersionCompare:@"1.1B2"]);
}
@end
