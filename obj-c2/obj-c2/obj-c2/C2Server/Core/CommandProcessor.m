#import "CommandProcessor.h"
#import "C2Server.h"
#import "EncryptionManager.h"
#import "HTTPListener.h"

@interface CommandProcessor ()
@property (nonatomic, weak) C2Server *server;
@property (nonatomic, strong) EncryptionManager *encryptionManager;
@property (nonatomic, strong) HTTPListener *httpListener;
@end

@implementation CommandProcessor

- (instancetype)initWithServer:(C2Server *)server {
    self = [super init];
    if (self) {
        _server = server;
        _encryptionManager = [[EncryptionManager alloc] init];
        _httpListener = [[HTTPListener alloc] init];
    }
    return self;
}

- (NSString *)processCommand:(NSString *)command fromClient:(id)clientSocket {
    if ([self.httpListener isHTTPRequestString:command]) {
        return [self processHTTPRequest:command fromClient:clientSocket];
    }

    NSString *trimmedCommand = [command stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (trimmedCommand.length == 0) {
        return @"ERR empty command";
    }

    NSDictionary *clientInfo = [clientSocket isKindOfClass:[NSDictionary class]] ? (NSDictionary *)clientSocket : nil;
    NSString *address = clientInfo[@"address"] ?: @"unknown";

    if ([trimmedCommand isEqualToString:@"ping"]) {
        return @"pong";
    }

    if ([trimmedCommand isEqualToString:@"status"]) {
        return [NSString stringWithFormat:@"server=online port=%ld clients=%lu",
                (long)self.server.port,
                (unsigned long)self.server.connectedClients.count];
    }

    if ([trimmedCommand isEqualToString:@"help"]) {
        return @"commands: ping, status, echo <text>, encrypt <passphrase> <text>, decrypt <passphrase> <base64>, help";
    }

    if ([trimmedCommand hasPrefix:@"echo "]) {
        return [trimmedCommand substringFromIndex:5];
    }

    if ([trimmedCommand hasPrefix:@"encrypt "]) {
        NSArray<NSString *> *parts = [self argumentPairForCommand:trimmedCommand prefix:@"encrypt "];
        if (parts.count != 2) {
            return @"ERR usage: encrypt <passphrase> <text>";
        }

        NSError *error = nil;
        NSString *cipherText = [self.encryptionManager encryptString:parts[1] withPassphrase:parts[0] error:&error];
        return cipherText ?: [NSString stringWithFormat:@"ERR %@", error.localizedDescription];
    }

    if ([trimmedCommand hasPrefix:@"decrypt "]) {
        NSArray<NSString *> *parts = [self argumentPairForCommand:trimmedCommand prefix:@"decrypt "];
        if (parts.count != 2) {
            return @"ERR usage: decrypt <passphrase> <base64>";
        }

        NSError *error = nil;
        NSString *plainText = [self.encryptionManager decryptString:parts[1] withPassphrase:parts[0] error:&error];
        return plainText ?: [NSString stringWithFormat:@"ERR %@", error.localizedDescription];
    }

    return [NSString stringWithFormat:@"ack %@: %@", address, trimmedCommand];
}

- (NSArray<NSString *> *)argumentPairForCommand:(NSString *)command prefix:(NSString *)prefix {
    NSString *payload = [command substringFromIndex:prefix.length];
    NSRange separator = [payload rangeOfString:@" "];
    if (separator.location == NSNotFound) {
        return @[];
    }

    NSString *first = [payload substringToIndex:separator.location];
    NSString *second = [payload substringFromIndex:separator.location + 1];
    if (first.length == 0 || second.length == 0) {
        return @[];
    }

    return @[first, second];
}

- (NSString *)processHTTPRequest:(NSString *)request fromClient:(id)clientSocket {
    NSDictionary<NSString *, id> *parsedRequest = [self.httpListener parseRequestString:request];
    if (!parsedRequest) {
        return [self.httpListener responseWithStatusCode:400 body:@"bad request" contentType:@"text/plain"];
    }

    NSString *method = parsedRequest[@"method"] ?: @"GET";
    NSString *path = parsedRequest[@"path"] ?: @"/";
    NSString *body = parsedRequest[@"body"] ?: @"";

    if ([method isEqualToString:@"GET"] && [path isEqualToString:@"/health"]) {
        return [self.httpListener responseWithStatusCode:200 body:@"ok" contentType:@"text/plain"];
    }

    if ([method isEqualToString:@"GET"] && [path isEqualToString:@"/status"]) {
        NSDictionary *clientInfo = [clientSocket isKindOfClass:[NSDictionary class]] ? (NSDictionary *)clientSocket : nil;
        NSDictionary *payload = @{
            @"status": @"online",
            @"port": @(self.server.port),
            @"clients": @(self.server.connectedClients.count),
            @"remote_address": clientInfo[@"address"] ?: @"unknown"
        };
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:payload options:NSJSONWritingPrettyPrinted error:nil];
        NSString *jsonBody = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding] ?: @"{}";
        return [self.httpListener responseWithStatusCode:200 body:jsonBody contentType:@"application/json"];
    }

    if ([method isEqualToString:@"POST"] && [path isEqualToString:@"/echo"]) {
        return [self.httpListener responseWithStatusCode:200 body:body contentType:@"text/plain"];
    }

    return [self.httpListener responseWithStatusCode:404 body:@"not found" contentType:@"text/plain"];
}

@end
