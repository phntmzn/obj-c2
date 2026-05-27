#import "TCPListener.h"
#import <sys/socket.h>
#import <netinet/in.h>
#import <arpa/inet.h>
#import <string.h>
#import <unistd.h>

@interface TCPListener ()
@property (nonatomic, assign) NSInteger port;
@property (nonatomic, assign) BOOL sslEnabled;
@property (nonatomic, strong) NSString *certPath;
@property (nonatomic, strong) NSString *keyPath;
@property (nonatomic, assign) int serverSocket;
@property (nonatomic, assign) BOOL isListening;
@property (nonatomic, strong) dispatch_queue_t listenQueue;
@end

@implementation TCPListener

- (instancetype)initWithPort:(NSInteger)port
                  sslEnabled:(BOOL)sslEnabled
                    certPath:(NSString *)certPath
                     keyPath:(NSString *)keyPath {
    self = [super init];
    if (self) {
        _port = port;
        _sslEnabled = sslEnabled;
        _certPath = certPath;
        _keyPath = keyPath;
        _serverSocket = -1;
        _isListening = NO;
        _listenQueue = dispatch_queue_create("com.c2server.listen", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (BOOL)startListening:(ClientConnectionHandler)handler {
    if (!handler) return NO;

    self.serverSocket = socket(AF_INET, SOCK_STREAM, 0);
    if (self.serverSocket < 0) {
        NSError *error = [NSError errorWithDomain:@"C2Server" code:1001 userInfo:@{NSLocalizedDescriptionKey: @"Socket creation failed"}];
        handler(nil, error);
        return NO;
    }

    int opt = 1;
    setsockopt(self.serverSocket, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));

    struct sockaddr_in address;
    memset(&address, 0, sizeof(address));
    address.sin_family = AF_INET;
    address.sin_addr.s_addr = INADDR_ANY;
    address.sin_port = htons((int)self.port);

    if (bind(self.serverSocket, (struct sockaddr *)&address, sizeof(address)) < 0) {
        NSError *error = [NSError errorWithDomain:@"C2Server" code:1002 userInfo:@{NSLocalizedDescriptionKey: @"Bind failed"}];
        handler(nil, error);
        close(self.serverSocket);
        self.serverSocket = -1;
        return NO;
    }

    if (listen(self.serverSocket, 10) < 0) {
        NSError *error = [NSError errorWithDomain:@"C2Server" code:1003 userInfo:@{NSLocalizedDescriptionKey: @"Listen failed"}];
        handler(nil, error);
        close(self.serverSocket);
        self.serverSocket = -1;
        return NO;
    }

    self.isListening = YES;

    __weak typeof(self) weakSelf = self;
    dispatch_async(self.listenQueue, ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;

        while (strongSelf.isListening) {
            struct sockaddr_in client_addr;
            socklen_t addr_len = sizeof(client_addr);
            int clientSocket = accept(strongSelf.serverSocket, (struct sockaddr *)&client_addr, &addr_len);

            if (clientSocket >= 0) {
                NSString *clientAddress = [NSString stringWithUTF8String:inet_ntoa(client_addr.sin_addr)];
                NSDictionary *clientInfo = @{
                    @"socket": @(clientSocket),
                    @"address": clientAddress,
                    @"port": @(ntohs(client_addr.sin_port))
                };
                handler(clientInfo, nil);
            } else if (strongSelf.isListening) {
                NSError *error = [NSError errorWithDomain:@"C2Server" code:1004 userInfo:@{NSLocalizedDescriptionKey: @"Accept failed"}];
                handler(nil, error);
            }
        }
    });

    return YES;
}

- (void)stopListening {
    self.isListening = NO;
    if (self.serverSocket >= 0) {
        close(self.serverSocket);
        self.serverSocket = -1;
    }
}

- (nullable NSString *)receiveFromClient:(id)client {
    NSDictionary *clientInfo = [client isKindOfClass:[NSDictionary class]] ? (NSDictionary *)client : nil;
    NSNumber *socketNum = clientInfo[@"socket"];
    if (!socketNum) return nil;

    int clientSocket = [socketNum intValue];
    char buffer[4096] = {0};

    ssize_t bytesRead = recv(clientSocket, buffer, sizeof(buffer) - 1, 0);
    if (bytesRead <= 0) {
        return nil;
    }

    return [NSString stringWithUTF8String:buffer];
}

- (BOOL)sendToClient:(id)client data:(NSString *)data {
    NSDictionary *clientInfo = [client isKindOfClass:[NSDictionary class]] ? (NSDictionary *)client : nil;
    NSNumber *socketNum = clientInfo[@"socket"];
    if (!socketNum) return NO;

    int clientSocket = [socketNum intValue];
    const char *message = [data UTF8String];

    ssize_t bytesSent = send(clientSocket, message, strlen(message), 0);
    return bytesSent > 0;
}

- (void)dealloc {
    [self stopListening];
}
@end
