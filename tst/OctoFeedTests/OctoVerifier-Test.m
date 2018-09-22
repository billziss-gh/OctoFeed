/**
 * @file OctoVerifier-Test.m
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
#import "OctoVerifier.h"

@interface OctoVerifierTest : XCTestCase
@end

@implementation OctoVerifierTest
- (void)testVerifyCodeSignature
{
    NSError *error = [OctoVerifier
        verifyCodeSignatureAtURL:[NSURL fileURLWithPath:@"/Applications/Safari.app"]
        matchesCodesSignatureAtURL:nil];
    XCTAssertNil(error);
}
@end
