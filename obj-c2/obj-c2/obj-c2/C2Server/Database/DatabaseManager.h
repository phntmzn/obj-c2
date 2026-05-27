#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface DatabaseManager : NSObject

- (BOOL)initializeWithPath:(NSString *)path;
- (BOOL)addClient:(NSDictionary *)clientInfo;
- (NSArray<NSDictionary *> *)allClients;

@end

NS_ASSUME_NONNULL_END
