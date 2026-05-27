#import <Foundation/Foundation.h>
#import <signal.h>
#import "C2Server.h"

static NSString *ResolveConfigPath(void) {
    NSArray<NSString *> *candidates = @[
        @"Config/server.plist",
        [[NSBundle mainBundle] pathForResource:@"server" ofType:@"plist"] ?: @"",
        [[NSBundle mainBundle] pathForResource:@"server" ofType:@"plist" inDirectory:@"Config"] ?: @""
    ];

    NSFileManager *fileManager = [NSFileManager defaultManager];
    for (NSString *candidate in candidates) {
        if (candidate.length > 0 && [fileManager fileExistsAtPath:candidate]) {
            return candidate;
        }
    }

    return nil;
}

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        signal(SIGINT, SIG_IGN);

        NSString *configPath = ResolveConfigPath();
        if (configPath.length == 0) {
            NSLog(@"Failed to locate Config/server.plist");
            return 1;
        }

        C2Server *server = [[C2Server alloc] init];

        if (![server initializeWithConfigPath:configPath]) {
            NSLog(@"Failed to initialize server");
            return 1;
        }

        if (![server start]) {
            NSLog(@"Failed to start server");
            return 1;
        }
        [server interactiveMode];

        return 0;
    }
}
