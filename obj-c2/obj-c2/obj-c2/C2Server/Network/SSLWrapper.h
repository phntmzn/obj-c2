#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SSLWrapper : NSObject

@property (nonatomic, assign, readonly, getter=isEnabled) BOOL enabled;
@property (nonatomic, copy, readonly) NSString *certificatePath;
@property (nonatomic, copy, readonly) NSString *keyPath;

- (instancetype)initWithCertificatePath:(NSString *)certificatePath
                                keyPath:(NSString *)keyPath
                                enabled:(BOOL)enabled NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

- (BOOL)validateConfiguration:(NSError * _Nullable * _Nullable)error;
- (NSDictionary<NSString *, NSString *> *)connectionMetadata;

@end

NS_ASSUME_NONNULL_END
