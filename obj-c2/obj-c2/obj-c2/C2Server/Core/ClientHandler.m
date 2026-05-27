#import "ClientHandler.h"
#import "TCPListener.h"
#import "CommandProcessor.h"
#import "Logger.h"

@interface ClientHandler ()
@property (nonatomic, copy) NSDictionary<NSString *, id> *clientInfo;
@property (nonatomic, weak) TCPListener *listener;
@property (nonatomic, weak) CommandProcessor *commandProcessor;
@property (nonatomic, weak) Logger *logger;
@property (nonatomic, assign, readwrite, getter=isConnected) BOOL connected;
@end

@implementation ClientHandler

- (instancetype)initWithClientInfo:(NSDictionary<NSString *,id> *)clientInfo
                          listener:(TCPListener *)listener
                  commandProcessor:(CommandProcessor *)commandProcessor
                            logger:(Logger *)logger {
    self = [super init];
    if (self) {
        _clientInfo = [clientInfo copy];
        _listener = listener;
        _commandProcessor = commandProcessor;
        _logger = logger;
        _connected = YES;
    }
    return self;
}

- (void)run {
    while (self.connected) {
        NSString *command = [self.listener receiveFromClient:self.clientInfo];
        if (command.length == 0) {
            break;
        }

        [self.logger logInfo:[NSString stringWithFormat:@"Received from %@: %@",
                              [self displayName],
                              [command stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]]];

        NSString *response = [self.commandProcessor processCommand:command fromClient:self.clientInfo];
        if (response.length > 0 && ![self.listener sendToClient:self.clientInfo data:response]) {
            break;
        }
    }

    self.connected = NO;
}

- (nullable NSString *)executeOperatorCommand:(NSString *)command {
    if (!self.connected) {
        return @"Client disconnected";
    }

    if (![self.listener sendToClient:self.clientInfo data:command]) {
        self.connected = NO;
        return nil;
    }

    NSString *response = [self.listener receiveFromClient:self.clientInfo];
    if (response.length == 0) {
        self.connected = NO;
    }

    return response;
}

- (NSString *)displayName {
    NSString *address = self.clientInfo[@"address"] ?: @"unknown";
    NSNumber *port = self.clientInfo[@"port"] ?: @0;
    return [NSString stringWithFormat:@"%@:%@", address, port];
}

@end
