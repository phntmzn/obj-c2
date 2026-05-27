#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface C2Server : NSObject

@property (nonatomic, assign) NSInteger port;
@property (nonatomic, assign) BOOL sslEnabled;
@property (nonatomic, strong) NSString *certPath;
@property (nonatomic, strong) NSString *keyPath;
@property (nonatomic, strong) NSMutableArray *connectedClients;
@property (nonatomic, strong) dispatch_queue_t clientQueue;

- (BOOL)initializeWithConfigPath:(NSString *)configPath;
- (BOOL)start;
- (void)stop;
- (void)interactiveMode;

@end

NS_ASSUME_NONNULL_END
