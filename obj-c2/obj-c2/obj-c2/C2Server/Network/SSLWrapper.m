#import "SSLWrapper.h"

static NSString * const SSLWrapperErrorDomain = @"com.c2server.SSLWrapper";

@implementation SSLWrapper

- (instancetype)initWithCertificatePath:(NSString *)certificatePath
                                keyPath:(NSString *)keyPath
                                enabled:(BOOL)enabled {
    self = [super init];
    if (self) {
        _certificatePath = [certificatePath copy] ?: @"";
        _keyPath = [keyPath copy] ?: @"";
        _enabled = enabled;
    }
    return self;
}

- (BOOL)validateConfiguration:(NSError * _Nullable __autoreleasing * _Nullable)error {
    if (!self.enabled) {
        return YES;
    }

    if (self.certificatePath.length == 0 || self.keyPath.length == 0) {
        if (error) {
            *error = [NSError errorWithDomain:SSLWrapperErrorDomain
                                         code:3001
                                     userInfo:@{NSLocalizedDescriptionKey: @"SSL is enabled but certificate or key path is missing"}];
        }
        return NO;
    }

    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSArray<NSString *> *requiredPaths = @[self.certificatePath, self.keyPath];
    for (NSString *path in requiredPaths) {
        BOOL isDirectory = NO;
        BOOL exists = [fileManager fileExistsAtPath:path isDirectory:&isDirectory];
        if (!exists || isDirectory) {
            if (error) {
                *error = [NSError errorWithDomain:SSLWrapperErrorDomain
                                             code:3002
                                         userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"SSL file is missing: %@", path]}];
            }
            return NO;
        }

        NSDictionary<NSFileAttributeKey, id> *attributes = [fileManager attributesOfItemAtPath:path error:nil];
        NSNumber *fileSize = attributes[NSFileSize];
        if (fileSize.unsignedLongLongValue == 0) {
            if (error) {
                *error = [NSError errorWithDomain:SSLWrapperErrorDomain
                                             code:3003
                                         userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"SSL file is empty: %@", path]}];
            }
            return NO;
        }
    }

    return YES;
}

- (NSDictionary<NSString *,NSString *> *)connectionMetadata {
    if (!self.enabled) {
        return @{@"mode": @"plain"};
    }

    return @{
        @"mode": @"ssl",
        @"certificatePath": self.certificatePath,
        @"keyPath": self.keyPath
    };
}

@end
