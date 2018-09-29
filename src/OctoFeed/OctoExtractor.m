/**
 * @file OctoFeed/OctoExtractor.m
 *
 * @copyright 2018 Bill Zissimopoulos
 */
/*
 * This file is part of OctoFeed.
 *
 * It is licensed under the MIT license. The full license text can be found
 * in the License.txt file at the root of this project.
 */

#import "OctoExtractor.h"
#import "NSObject+OctoExtensions.h"
#import "OctoError.h"

@interface OctoExtractor ()
@property (copy) NSURL *url;
@end

@implementation OctoExtractor
+ (BOOL)canExtractURL:(NSURL *)url
{
    NSString *lastPathComponent = [url lastPathComponent];

    if ([lastPathComponent hasSuffix:@".zip"])
        return YES;
    else
    if ([lastPathComponent hasSuffix:@".tar.gz"] || [lastPathComponent hasSuffix:@".tgz"] ||
        [lastPathComponent hasSuffix:@".tar.bz2"] || [lastPathComponent hasSuffix:@".tbz"] ||
        [lastPathComponent hasSuffix:@".tar.xz"] || [lastPathComponent hasSuffix:@".txz"])
        return YES;
    else
        return NO;
}

+ (void)extractURL:(NSURL *)src
    toURL:(NSURL *)dst
    completion:(void (^)(NSError *error))completion
{
    OctoExtractor *extractor = [[[[self class] alloc] initWithURL:src] autorelease];
    [extractor extractToURL:dst completion:completion];
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

- (void)extractToURL:(NSURL *)dst
    completion:(void (^)(NSError *error))completion
{
    NSString *lastPathComponent = [self.url lastPathComponent];

    NSString *exec = nil;
    NSArray *args = nil;
    if ([lastPathComponent hasSuffix:@".zip"])
    {
        exec = @"/usr/bin/ditto";
        args = [NSArray arrayWithObjects:@"-xk", [self.url path], @".", nil];
    }
    else
    if ([lastPathComponent hasSuffix:@".tar.gz"] || [lastPathComponent hasSuffix:@".tgz"] ||
        [lastPathComponent hasSuffix:@".tar.bz2"] || [lastPathComponent hasSuffix:@".tbz"] ||
        [lastPathComponent hasSuffix:@".tar.xz"] || [lastPathComponent hasSuffix:@".txz"])
    {
        exec = @"/usr/bin/tar";
        args = [NSArray arrayWithObjects:@"xf", [self.url path], nil];
    }
    else
    {
        [self extractToURLErrorCompletion:completion];
        return;
    }

    NSTask *task = [[[NSTask alloc] init] autorelease];
    task.launchPath = exec;
    task.arguments = args;
    task.currentDirectoryPath = [dst path];
    task.terminationHandler = ^(NSTask *task)
    {
        NSError *error = nil;

        NSTaskTerminationReason reason = task.terminationReason;
        int status = task.terminationStatus;
        if (NSTaskTerminationReasonExit != reason || 0 != status)
            error = [NSError
                errorWithDomain:OctoErrorDomain
                code:OctoErrorExtractorTaskExit
                userInfo:nil];
        completion(error);
    };

    @try
    {
        [task launch];
    }
    @catch (NSException *ex)
    {
        [self extractToURLErrorCompletion:completion];
    }
}

- (void)extractToURLErrorCompletion:(void (^)(NSError *))completion
{
    [self octoPerformBlock:^
    {
        NSError *error = [NSError
            errorWithDomain:OctoErrorDomain
            code:OctoErrorExtractorTaskLaunch
            userInfo:nil];
        completion(error);
    } afterDelay:0];
}
@end
