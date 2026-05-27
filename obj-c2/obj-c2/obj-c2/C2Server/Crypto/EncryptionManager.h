#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface EncryptionManager : NSObject

- (nullable NSString *)encryptString:(NSString *)plainText
                      withPassphrase:(NSString *)passphrase
                               error:(NSError * _Nullable * _Nullable)error;

- (nullable NSString *)decryptString:(NSString *)base64CipherText
                      withPassphrase:(NSString *)passphrase
                               error:(NSError * _Nullable * _Nullable)error;

@end

NS_ASSUME_NONNULL_END
