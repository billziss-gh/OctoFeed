/**
 * @file OctoVerifier.m
 *
 * @copyright 2018 Bill Zissimopoulos
 */
/*
 * This file is part of OctoFeed.
 *
 * It is licensed under the MIT license. The full license text can be found
 * in the License.txt file at the root of this project.
 */

#import "OctoVerifier.h"
#import "NSObject+OctoExtensions.h"

@interface OctoVerifier ()
@property (copy) NSURL *url;
@end

@implementation OctoVerifier
+ (NSError *)verifyCodeSignatureAtURL:(NSURL *)src matchesCodesSignatureAtURL:(NSURL *)dst
{
    OctoVerifier *verifier = [[[[self class] alloc] initWithURL:src] autorelease];
    return [verifier verifyCodeSignatureMatchesCodeSignatureAtURL:dst];
}

- (id)initWithURL:(NSURL *)url
{
    self = [super init];
    if (nil == self)
        return nil;

    self.url = url;

    return self;
}

- (void)dealloc
{
    self.url = nil;

    [super dealloc];
}

- (NSError *)verifyCodeSignatureMatchesCodeSignatureAtURL:(NSURL *)url
{
    OSStatus status;
    SecStaticCodeRef code = 0;
    SecStaticCodeRef matchCode = 0;
    SecRequirementRef matchReq = 0;
    CFErrorRef error = nil;

    if (nil != url)
    {
        status = SecStaticCodeCreateWithPath((CFURLRef)url, kSecCSDefaultFlags, &matchCode);
        if (errSecSuccess != status)
            goto exit;

        status = SecCodeCopyDesignatedRequirement(matchCode, kSecCSDefaultFlags, &matchReq);
        if (errSecSuccess != status)
            goto exit;
    }

    status = SecStaticCodeCreateWithPath((CFURLRef)self.url, kSecCSDefaultFlags, &code);
    if (errSecSuccess != status)
        goto exit;

    status = SecStaticCodeCreateWithPath((CFURLRef)self.url, kSecCSDefaultFlags, &code);
    if (errSecSuccess != status)
        goto exit;

    status = SecStaticCodeCheckValidityWithErrors(code, kSecCSDefaultFlags, matchReq, &error);
    if (errSecSuccess != status)
        goto exit;

exit:
    if (0 != code)
        CFRelease(code);

    if (0 != matchReq)
        CFRelease(matchReq);

    if (0 != matchCode)
        CFRelease(matchCode);

    if (errSecSuccess != status && nil == error)
        error = (CFErrorRef)[NSError errorWithDomain:NSOSStatusErrorDomain code:status userInfo:nil];

    return (NSError *)error;
}
@end
