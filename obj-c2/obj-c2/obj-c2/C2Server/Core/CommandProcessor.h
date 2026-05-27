#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class C2Server;

@interface CommandProcessor : NSObject

- (instancetype)initWithServer:(C2Server *)server NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
- (NSString *)processCommand:(NSString *)command fromClient:(id)clientSocket;

@end

NS_ASSUME_NONNULL_END
