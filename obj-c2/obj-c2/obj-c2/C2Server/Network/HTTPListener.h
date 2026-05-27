#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface HTTPListener : NSObject

- (BOOL)isHTTPRequestString:(NSString *)requestString;
- (nullable NSDictionary<NSString *, id> *)parseRequestString:(NSString *)requestString;
- (NSString *)responseWithStatusCode:(NSInteger)statusCode
                                body:(NSString *)body
                         contentType:(NSString *)contentType;

@end

NS_ASSUME_NONNULL_END
