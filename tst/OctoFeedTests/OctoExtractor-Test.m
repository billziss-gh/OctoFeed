/**
 * @file OctoExtractor-Test.m
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
#import "OctoExtractor.h"

static const NSString *sig = @"83e6184da5ce2eb8c4e710b383f149c6";

@interface OctoExtractorTest : XCTestCase
@end

@implementation OctoExtractorTest
- (void)_testExtract:(NSString *)name
{
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSString *path = [bundle pathForResource:name ofType:nil];

    NSString *tmpdir = [NSTemporaryDirectory()
        stringByAppendingPathComponent:[bundle bundleIdentifier]];
    [[NSFileManager defaultManager]
        createDirectoryAtPath:tmpdir withIntermediateDirectories:YES attributes:nil error:0];

    XCTestExpectation *exp = [self expectationWithDescription:@"extractURL:toURL:completion:"];

    [OctoExtractor
        extractURL:[NSURL fileURLWithPath:nil != path ?
            path : [bundle.bundlePath stringByAppendingPathComponent:name]]
        toURL:[NSURL fileURLWithPath:tmpdir]
        completion:^(NSError *error)
    {
        if (nil != path)
        {
            XCTAssertNil(error);

            NSString *string = [NSString
                stringWithContentsOfFile:[tmpdir stringByAppendingPathComponent:@"test.txt"]
                encoding:NSUTF8StringEncoding
                error:0];
            NSString *expected = [NSString stringWithFormat:@"%@ %@\n", name, sig];
            XCTAssertEqualObjects(expected, string);
        }
        else
            XCTAssertNotNil(error);

        [exp fulfill];
    }];

    [self waitForExpectations:[NSArray arrayWithObject:exp] timeout:10];

    [[NSFileManager defaultManager] removeItemAtPath:tmpdir error:0];
}

- (void)testExtractUnknown
{
    [self _testExtract:@"test.unknownext"];
}

- (void)testExtractZip
{
    [self _testExtract:@"test.zip"];
    [self _testExtract:@"test-nonexistent.zip"];
}

- (void)testExtractTarGz
{
    [self _testExtract:@"test.tar.gz"];
    [self _testExtract:@"test-nonexistent.tar.gz"];
}

- (void)testExtractTarBz2
{
    [self _testExtract:@"test.tar.bz2"];
    [self _testExtract:@"test-nonexistent.tar.bz2"];
}
@end
