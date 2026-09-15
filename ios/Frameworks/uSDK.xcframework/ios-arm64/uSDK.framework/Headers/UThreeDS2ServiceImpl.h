//
//  UThreeDS2ServiceImpl.h
//  ThreeDSSDK
//
//  Created by Drew Pitchford on 2/5/20.
//  Copyright © 2020 mSignia. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "UThreeDS2Service.h"

/**
 A service that implements the UThreeDS2Service protocol. Use this to initialize the sdk, create transactions, etc.
 */
@interface UThreeDS2ServiceImpl: NSObject<UThreeDS2Service>

/**
 Singleton object that allows interaction with the UThreeDS2Service compliant object. Because this is implemented as a singleton, the same object
 will always be returned, no matter how many times the integrating app destroys its reference to the SDK and re-creates it. As such, it's best for the integrating
 app to hold a single, global reference to the SDK and never destroy it.

 @return a UThreeDSv2Service object
 */
+ (nonnull UThreeDS2ServiceImpl *)shared;

@end
