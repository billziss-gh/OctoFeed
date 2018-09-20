/**
 * @file NSString+SemVer.m
 *
 * @copyright 2018 Bill Zissimopoulos
 */
/*
 * This file is part of OctoFeed.
 *
 * It is licensed under the MIT license. The full license text can be found
 * in the License.txt file at the root of this project.
 */

#import "NSString+SemVer.h"

@implementation NSString (SemVer)
- (BOOL)semverValidate
{
    BOOL valid = YES;

    NSScanner *scanner = [NSScanner scannerWithString:self];
    scanner.charactersToBeSkipped = nil;
    valid = valid && [scanner scanUnsignedLongLong:0];
    valid = valid && [scanner scanString:@"." intoString:0];
    valid = valid && [scanner scanUnsignedLongLong:0];

    return valid;
}

- (NSComparisonResult)semverCompare:(NSString *)other
{
    BOOL valid;

    NSScanner *scanner = [NSScanner scannerWithString:self];
    scanner.charactersToBeSkipped = nil;
    valid = [scanner scanUnsignedLongLong:0];
    while (valid)
    {
        valid = valid && [scanner scanString:@"." intoString:0];
        valid = valid && [scanner scanUnsignedLongLong:0];
    }

    NSScanner *oscanner = [NSScanner scannerWithString:other];
    oscanner.charactersToBeSkipped = nil;
    valid = [oscanner scanUnsignedLongLong:0];
    while (valid)
    {
        valid = valid && [oscanner scanString:@"." intoString:0];
        valid = valid && [oscanner scanUnsignedLongLong:0];
    }

    NSComparisonResult res = [self
        compare:[other substringToIndex:[oscanner scanLocation]]
        options:NSNumericSearch
        range:NSMakeRange(0, [scanner scanLocation])];
    if (NSOrderedSame != res)
        return res;

    BOOL scannerAtEnd = [scanner isAtEnd];
    BOOL oscannerAtEnd = [oscanner isAtEnd];
    if (scannerAtEnd && !oscannerAtEnd)
        return NSOrderedDescending;
    if (!scannerAtEnd && oscannerAtEnd)
        return NSOrderedAscending;

    return [self
        compare:other
        options:NSNumericSearch];
}
@end
