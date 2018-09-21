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

- (void)testVersionSort
{
    NSArray *array = [NSArray arrayWithObjects:
        @"99.99.99", @"99.99.99B", @"99.99.99A", @"99.99.99A2", @"99.99.99A10", nil];
    array = [array sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2)
    {
        return [obj1 versionCompare:obj2];
    }];

    XCTAssertEqualObjects(@"99.99.99A", [array objectAtIndex:0]);
    XCTAssertEqualObjects(@"99.99.99A2", [array objectAtIndex:1]);
    XCTAssertEqualObjects(@"99.99.99A10", [array objectAtIndex:2]);
    XCTAssertEqualObjects(@"99.99.99B", [array objectAtIndex:3]);
    XCTAssertEqualObjects(@"99.99.99", [array objectAtIndex:4]);
}
@end
