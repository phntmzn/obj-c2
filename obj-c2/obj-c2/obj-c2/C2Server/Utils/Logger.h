#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface Logger : NSObject

- (instancetype)initWithLogFile:(NSString *)logFilePath;
- (void)logInfo:(NSString *)message;
- (void)logError:(NSString *)message;
- (void)logDebug:(NSString *)message;
- (void)logWarning:(NSString *)message;

@end

NS_ASSUME_NONNULL_END
