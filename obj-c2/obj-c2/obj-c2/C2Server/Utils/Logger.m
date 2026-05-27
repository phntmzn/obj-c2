#import "Logger.h"

@interface Logger ()
@property (nonatomic, strong) NSString *logFilePath;
@property (nonatomic, strong) NSFileHandle *fileHandle;
@property (nonatomic, strong) NSDateFormatter *dateFormatter;
@end

@implementation Logger

- (instancetype)initWithLogFile:(NSString *)logFilePath {
    self = [super init];
    if (self) {
        _logFilePath = logFilePath;
        _dateFormatter = [[NSDateFormatter alloc] init];
        [_dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
        
        // Create log directory if needed
        NSString *logDir = [logFilePath stringByDeletingLastPathComponent];
        [[NSFileManager defaultManager] createDirectoryAtPath:logDir
                                  withIntermediateDirectories:YES
                                                   attributes:nil
                                                        error:nil];
        
        // Create or open log file
        if (![[NSFileManager defaultManager] fileExistsAtPath:logFilePath]) {
            [[NSFileManager defaultManager] createFileAtPath:logFilePath contents:nil attributes:nil];
        }
        
        _fileHandle = [NSFileHandle fileHandleForWritingAtPath:logFilePath];
        [_fileHandle seekToEndOfFile];
    }
    return self;
}

- (void)logMessage:(NSString *)level message:(NSString *)message {
    NSString *timestamp = [self.dateFormatter stringFromDate:[NSDate date]];
    NSString *logLine = [NSString stringWithFormat:@"[%@] [%@] %@\n", timestamp, level, message];
    
    NSLog(@"%@", logLine);
    
    [self.fileHandle writeData:[logLine dataUsingEncoding:NSUTF8StringEncoding]];
    [self.fileHandle synchronizeFile];
}

- (void)logInfo:(NSString *)message {
    [self logMessage:@"INFO" message:message];
}

- (void)logError:(NSString *)message {
    [self logMessage:@"ERROR" message:message];
}

- (void)logDebug:(NSString *)message {
    [self logMessage:@"DEBUG" message:message];
}

- (void)logWarning:(NSString *)message {
    [self logMessage:@"WARNING" message:message];
}

- (void)dealloc {
    [self.fileHandle closeFile];
}
@end
