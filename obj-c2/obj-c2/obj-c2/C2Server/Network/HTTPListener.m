#import "HTTPListener.h"

@implementation HTTPListener

- (BOOL)isHTTPRequestString:(NSString *)requestString {
    if (requestString.length == 0) {
        return NO;
    }

    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"^(GET|POST|PUT|PATCH|DELETE|HEAD|OPTIONS)\\s+\\S+\\s+HTTP/1\\.[01]"
                                                                           options:0
                                                                             error:nil];
    NSRange range = NSMakeRange(0, requestString.length);
    return [regex firstMatchInString:requestString options:0 range:range] != nil;
}

- (nullable NSDictionary<NSString *,id> *)parseRequestString:(NSString *)requestString {
    if (![self isHTTPRequestString:requestString]) {
        return nil;
    }

    NSString *separator = [requestString containsString:@"\r\n\r\n"] ? @"\r\n\r\n" : @"\n\n";
    NSRange separatorRange = [requestString rangeOfString:separator];

    NSString *headerSection = separatorRange.location == NSNotFound
        ? requestString
        : [requestString substringToIndex:separatorRange.location];
    NSString *bodySection = separatorRange.location == NSNotFound
        ? @""
        : [requestString substringFromIndex:separatorRange.location + separator.length];

    NSArray<NSString *> *rawLines = [headerSection componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    NSMutableArray<NSString *> *lines = [NSMutableArray array];
    for (NSString *line in rawLines) {
        NSString *trimmed = [line stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]];
        if (trimmed.length > 0) {
            [lines addObject:trimmed];
        }
    }

    if (lines.count == 0) {
        return nil;
    }

    NSArray<NSString *> *requestLine = [lines[0] componentsSeparatedByString:@" "];
    if (requestLine.count < 3) {
        return nil;
    }

    NSMutableDictionary<NSString *, NSString *> *headers = [NSMutableDictionary dictionary];
    for (NSUInteger index = 1; index < lines.count; index++) {
        NSString *line = lines[index];
        NSRange colonRange = [line rangeOfString:@":"];
        if (colonRange.location == NSNotFound) {
            continue;
        }

        NSString *key = [[line substringToIndex:colonRange.location] lowercaseString];
        NSString *value = [[line substringFromIndex:colonRange.location + 1]
            stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        headers[key] = value;
    }

    return @{
        @"method": requestLine[0],
        @"path": requestLine[1],
        @"version": requestLine[2],
        @"headers": headers,
        @"body": bodySection ?: @""
    };
}

- (NSString *)responseWithStatusCode:(NSInteger)statusCode
                                body:(NSString *)body
                         contentType:(NSString *)contentType {
    NSData *bodyData = [body dataUsingEncoding:NSUTF8StringEncoding] ?: [NSData data];
    NSString *reasonPhrase = [self reasonPhraseForStatusCode:statusCode];
    return [NSString stringWithFormat:
            @"HTTP/1.1 %ld %@\r\nContent-Type: %@\r\nContent-Length: %lu\r\nConnection: close\r\n\r\n%@",
            (long)statusCode,
            reasonPhrase,
            contentType,
            (unsigned long)bodyData.length,
            body ?: @""];
}

- (NSString *)reasonPhraseForStatusCode:(NSInteger)statusCode {
    switch (statusCode) {
        case 200:
            return @"OK";
        case 400:
            return @"Bad Request";
        case 404:
            return @"Not Found";
        case 500:
            return @"Internal Server Error";
        default:
            return @"OK";
    }
}

@end
