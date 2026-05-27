#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class TCPListener;
@class CommandProcessor;
@class Logger;

@interface ClientHandler : NSObject

@property (nonatomic, copy, readonly) NSDictionary<NSString *, id> *clientInfo;
@property (nonatomic, assign, readonly, getter=isConnected) BOOL connected;

- (instancetype)initWithClientInfo:(NSDictionary<NSString *, id> *)clientInfo
                          listener:(TCPListener *)listener
                  commandProcessor:(CommandProcessor *)commandProcessor
                            logger:(Logger *)logger NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

- (void)run;
- (nullable NSString *)executeOperatorCommand:(NSString *)command;
- (NSString *)displayName;

@end

NS_ASSUME_NONNULL_END
