/**
 * @file NSString+Version-Test.m
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
#import "NSString+Version.h"

@interface NSStringVersionTest : XCTestCase
@end

@implementation NSStringVersionTest
- (void)testVersionValidate
{
    XCTAssertFalse([@"" versionValidate]);
    XCTAssertFalse([@"B" versionValidate]);
    XCTAssertFalse([@"99" versionValidate]);
    XCTAssertFalse([@"99B" versionValidate]);
    XCTAssertFalse([@"99." versionValidate]);
    XCTAssertFalse([@"99.B" versionValidate]);
    XCTAssertTrue([@"99.1" versionValidate]);
    XCTAssertTrue([@"99.1B" versionValidate]);
    XCTAssertTrue([@"99.1.1" versionValidate]);
    XCTAssertTrue([@"99.1.1B" versionValidate]);
    XCTAssertFalse([@" 99.1.1" versionValidate]);
    XCTAssertFalse([@"99. 1.1" versionValidate]);
    XCTAssertTrue([@"99.1 B" versionValidate]);
}

- (void)testVersionCompare
{
    XCTAssertEqual(NSOrderedSame, [@"1.1" versionCompare:@"1.1"]);

    XCTAssertEqual(NSOrderedAscending, [@"1.1" versionCompare:@"1.2"]);
    XCTAssertEqual(NSOrderedAscending, [@"2.1" versionCompare:@"10.1"]);
    XCTAssertEqual(NSOrderedAscending, [@"1.1B" versionCompare:@"1.1"]);
    XCTAssertEqual(NSOrderedAscending, [@"1.1.1.1B" versionCompare:@"1.1.1.1"]);
    XCTAssertEqual(NSOrderedDescending, [@"1.2B" versionCompare:@"1.1"]);
    XCTAssertEqual(NSOrderedDescending, [@"1.1.1.2B" versionCompare:@"1.1.1.1"]);
    XCTAssertEqual(NSOrderedAscending, [@"1.1B2" versionCompare:@"1.1B10"]);

    XCTAssertEqual(NSOrderedDescending, [@"1.2" versionCompare:@"1.1"]);
    XCTAssertEqual(NSOrderedDescending, [@"10.1" versionCompare:@"2.1"]);
    XCTAssertEqual(NSOrderedDescending, [@"1.1" versionCompare:@"1.1B"]);
    XCTAssertEqual(NSOrderedDescending, [@"1.1.1.1" versionCompare:@"1.1.1.1B"]);
    XCTAssertEqual(NSOrderedAscending, [@"1.1" versionCompare:@"1.2B"]);
    XCTAssertEqual(NSOrderedAscending, [@"1.1.1.1" versionCompare:@"1.1.1.2B"]);
    XCTAssertEqual(NSOrderedDescending, [@"1.1B10" versionCompare:@"1.1B2"]);
}
@end
