/**
 * @file NSString+Version.h
 *
 * @copyright 2018 Bill Zissimopoulos
 */
/*
 * This file is part of OctoFeed.
 *
 * It is licensed under the MIT license. The full license text can be found
 * in the License.txt file at the root of this project.
 */

#import <Foundation/Foundation.h>

@interface NSString (Version)

/**
 * Checks whether a version string is a valid version.
 */
- (BOOL)versionValidate;

/**
 * Compares two version strings.
 */
- (NSComparisonResult)versionCompare:(NSString *)other;
@end
