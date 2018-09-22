/**
 * @file NSTask+Relaunch.m
 *
 * @copyright 2018 Bill Zissimopoulos
 */
/*
 * This file is part of OctoFeed.
 *
 * It is licensed under the MIT license. The full license text can be found
 * in the License.txt file at the root of this project.
 */

#import "NSTask+Relaunch.h"

@implementation NSTask (Relaunch)
+ (void)relaunch
{
    const char *path = [[[NSBundle mainBundle] bundlePath]
        cStringUsingEncoding:NSUTF8StringEncoding];

    pid_t ppid = getpid();
    pid_t pid = fork();
    if (0 != pid)
    {
        /* parent; exit now */
        exit(0);
    }

    /* child; wait until parent is gone */
    struct timespec tm = { 0, 100000000 }; /* 100ms */
    while (getppid() == ppid)
        nanosleep(&tm, 0);

    /* use /usr/bin/open to relaunch */
    char *null = 0;
    execle("/usr/bin/open", "/usr/bin/open", path, 0, &null);
    exit(1);
}
@end
