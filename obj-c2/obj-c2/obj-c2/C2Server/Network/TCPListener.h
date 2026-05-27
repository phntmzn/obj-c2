#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^ClientConnectionHandler)(id _Nullable clientSocket, NSError * _Nullable error);

@interface TCPListener : NSObject

- (instancetype)initWithPort:(NSInteger)port
                  sslEnabled:(BOOL)sslEnabled
                    certPath:(NSString *)certPath
                     keyPath:(NSString *)keyPath;

- (BOOL)startListening:(ClientConnectionHandler)handler;
- (void)stopListening;
- (nullable NSString *)receiveFromClient:(id)client;
- (BOOL)sendToClient:(id)client data:(NSString *)data;

@end

NS_ASSUME_NONNULL_END
