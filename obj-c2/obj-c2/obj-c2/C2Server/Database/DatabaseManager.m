#import "DatabaseManager.h"

@interface DatabaseManager ()
@property (nonatomic, copy) NSString *databasePath;
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *clientRecords;
@end

@implementation DatabaseManager

- (instancetype)init {
    self = [super init];
    if (self) {
        _clientRecords = [NSMutableArray array];
    }
    return self;
}

- (BOOL)initializeWithPath:(NSString *)path {
    if (path.length == 0) {
        return NO;
    }

    self.databasePath = [path stringByStandardizingPath];

    NSString *directory = [self.databasePath stringByDeletingLastPathComponent];
    NSError *directoryError = nil;
    BOOL createdDirectory = [[NSFileManager defaultManager] createDirectoryAtPath:directory
                                                      withIntermediateDirectories:YES
                                                                       attributes:nil
                                                                            error:&directoryError];
    if (!createdDirectory) {
        NSLog(@"Failed to create database directory %@: %@", directory, directoryError.localizedDescription);
        return NO;
    }

    NSArray *storedClients = [NSArray arrayWithContentsOfFile:self.databasePath];
    if ([storedClients isKindOfClass:[NSArray class]]) {
        self.clientRecords = [storedClients mutableCopy];
    }

    return [self persist];
}

- (BOOL)addClient:(NSDictionary *)clientInfo {
    if (![clientInfo isKindOfClass:[NSDictionary class]]) {
        return NO;
    }

    NSMutableDictionary *record = [clientInfo mutableCopy];
    if (record[@"connected_at"] == nil) {
        record[@"connected_at"] = [NSDate date];
    }

    [self.clientRecords addObject:[record copy]];
    return [self persist];
}

- (NSArray<NSDictionary *> *)allClients {
    return [self.clientRecords copy];
}

- (BOOL)persist {
    if (self.databasePath.length == 0) {
        return NO;
    }

    return [self.clientRecords writeToFile:self.databasePath atomically:YES];
}

@end
