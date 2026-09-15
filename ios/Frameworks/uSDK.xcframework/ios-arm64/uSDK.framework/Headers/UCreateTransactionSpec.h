//
//  UCreateTransactionSpec.h
//  uSDK
//
//  Created by Drew Pitchford on 4/22/20.
//  Copyright © 2020 mSignia. All rights reserved.
//

#import <Foundation/Foundation.h>

#if BUILD_FOR_MC == 0
@interface UCreateTransactionSpec: NSObject

- (nonnull UCreateTransactionSpec *)initWithDirectoryServerID:(nonnull NSString *)directoryServerID
                                               messageVersion:(nonnull NSString *)messageVersion;
- (void)setDirectoryServerID:(nonnull NSString *)directoryServerID;
- (nonnull NSString *)getDirectoryServerID;
- (void)setMessageVersion:(nonnull NSString *)messageVersion;
- (nonnull NSString *)getMessageVersion;

@end
#endif
