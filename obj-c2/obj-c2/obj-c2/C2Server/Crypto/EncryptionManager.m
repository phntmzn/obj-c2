#import "EncryptionManager.h"
#import <CommonCrypto/CommonCryptor.h>
#import <CommonCrypto/CommonDigest.h>
#import <stdlib.h>

static NSString * const EncryptionManagerErrorDomain = @"com.c2server.EncryptionManager";

@interface EncryptionManager ()
- (nullable NSData *)cryptData:(NSData *)inputData
                withPassphrase:(NSString *)passphrase
                     operation:(CCOperation)operation
                         error:(NSError * _Nullable * _Nullable)error;
@end

@implementation EncryptionManager

- (nullable NSString *)encryptString:(NSString *)plainText
                      withPassphrase:(NSString *)passphrase
                               error:(NSError * _Nullable __autoreleasing * _Nullable)error {
    NSData *inputData = [plainText dataUsingEncoding:NSUTF8StringEncoding];
    NSData *encryptedData = [self cryptData:inputData withPassphrase:passphrase operation:kCCEncrypt error:error];
    return [encryptedData base64EncodedStringWithOptions:0];
}

- (nullable NSString *)decryptString:(NSString *)base64CipherText
                      withPassphrase:(NSString *)passphrase
                               error:(NSError * _Nullable __autoreleasing * _Nullable)error {
    NSData *cipherData = [[NSData alloc] initWithBase64EncodedString:base64CipherText options:0];
    if (cipherData.length == 0) {
        if (error) {
            *error = [NSError errorWithDomain:EncryptionManagerErrorDomain
                                         code:2001
                                     userInfo:@{NSLocalizedDescriptionKey: @"Ciphertext is not valid base64"}];
        }
        return nil;
    }

    NSData *plainData = [self cryptData:cipherData withPassphrase:passphrase operation:kCCDecrypt error:error];
    if (plainData.length == 0) {
        return nil;
    }

    return [[NSString alloc] initWithData:plainData encoding:NSUTF8StringEncoding];
}

- (nullable NSData *)cryptData:(NSData *)inputData
                withPassphrase:(NSString *)passphrase
                     operation:(CCOperation)operation
                         error:(NSError * _Nullable __autoreleasing * _Nullable)error {
    if (passphrase.length == 0) {
        if (error) {
            *error = [NSError errorWithDomain:EncryptionManagerErrorDomain
                                         code:2002
                                     userInfo:@{NSLocalizedDescriptionKey: @"Passphrase cannot be empty"}];
        }
        return nil;
    }

    NSData *passphraseData = [passphrase dataUsingEncoding:NSUTF8StringEncoding];
    unsigned char digest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(passphraseData.bytes, (CC_LONG)passphraseData.length, digest);
    NSData *keyData = [NSData dataWithBytes:digest length:sizeof(digest)];

    NSData *ivData = nil;
    NSData *payloadData = nil;

    if (operation == kCCEncrypt) {
        NSMutableData *generatedIV = [NSMutableData dataWithLength:kCCBlockSizeAES128];
        arc4random_buf(generatedIV.mutableBytes, generatedIV.length);
        ivData = generatedIV;
        payloadData = inputData;
    } else {
        if (inputData.length <= kCCBlockSizeAES128) {
            if (error) {
                *error = [NSError errorWithDomain:EncryptionManagerErrorDomain
                                             code:2003
                                         userInfo:@{NSLocalizedDescriptionKey: @"Ciphertext is too short"}];
            }
            return nil;
        }

        ivData = [inputData subdataWithRange:NSMakeRange(0, kCCBlockSizeAES128)];
        payloadData = [inputData subdataWithRange:NSMakeRange(kCCBlockSizeAES128, inputData.length - kCCBlockSizeAES128)];
    }

    size_t outputCapacity = payloadData.length + kCCBlockSizeAES128;
    NSMutableData *outputData = [NSMutableData dataWithLength:outputCapacity];
    size_t bytesProcessed = 0;

    CCCryptorStatus status = CCCrypt(operation,
                                     kCCAlgorithmAES,
                                     kCCOptionPKCS7Padding,
                                     keyData.bytes,
                                     keyData.length,
                                     ivData.bytes,
                                     payloadData.bytes,
                                     payloadData.length,
                                     outputData.mutableBytes,
                                     outputData.length,
                                     &bytesProcessed);
    if (status != kCCSuccess) {
        if (error) {
            *error = [NSError errorWithDomain:EncryptionManagerErrorDomain
                                         code:status
                                     userInfo:@{NSLocalizedDescriptionKey: @"Encryption operation failed"}];
        }
        return nil;
    }

    [outputData setLength:bytesProcessed];
    if (operation == kCCEncrypt) {
        NSMutableData *finalData = [ivData mutableCopy];
        [finalData appendData:outputData];
        return finalData;
    }

    return outputData;
}

@end
