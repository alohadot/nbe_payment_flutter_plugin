//
//  UInitSpec.h
//  uSDK
//
//  Created by Drew Pitchford on 6/2/20.
//  Copyright © 2020 mSignia. All rights reserved.
//

#import <Foundation/Foundation.h>

#if BUILD_FOR_MC == 0
@class UConfigParameters, UUiCustomization;

@interface UInitSpec : NSObject

/**
 Init method for UInitSpec that takes both required params
 @param configParameters config parameters for the 3DS SDK as defined in the EMVCo 3DS Spec
 */
- (nonnull UInitSpec *)initWithConfigParameters:(nonnull UConfigParameters *)configParameters;

/**
Init method for UInitSpec that takes both required params and optional UICustomization
@param uiCustomizationMap UI configuration information that is used to specify the UI layout and theme for a UUiCustomizationType. For example, font style and font size for DEFAULT or DARK mode.
@param configParameters config parameters for the 3DS SDK as defined in the EMVCo 3DS Spec
*/
- (nonnull UInitSpec *)initWithUiCustomizationMap:(nullable NSDictionary <NSNumber *, UUiCustomization *> *)uiCustomizationMap
                         configParameters:(nonnull UConfigParameters *)configParameters;

/**
Init method for UInitSpec that takes both required params and optional locale
@param locale the locale of your app
@param configParameters config parameters for the 3DS SDK as defined in the EMVCo 3DS Spec
*/
- (nonnull UInitSpec *)initWithLocale:(nullable NSString *)locale
                         configParameters:(nonnull UConfigParameters *)configParameters;

/**
Init method for UInitSpec that takes all params
 @param locale the locale of your app
 @param uiCustomizationMap UI configuration information that is used to specify the UI layout and theme for a UUiCustomizationType. For example, font style and font size for DEFAULT or DARK mode.
@param configParameters config parameters for the 3DS SDK as defined in the EMVCo 3DS Spec
*/
- (nonnull UInitSpec *)initWithLocale:(nullable NSString *)locale
                       uiCustomizationMap:(nullable NSDictionary <NSNumber *, UUiCustomization *> *)uiCustomizationMap
                         configParameters:(nonnull UConfigParameters *)configParameters;

#pragma mark Setters
- (void)setLocale:(nullable NSString *)locale;
- (void)setUICustomizationMap:(nonnull NSDictionary <NSNumber *, UUiCustomization *> *)uiCustomizationMap;
- (void)setConfigParameters:(nonnull UConfigParameters *)configParameters;

#pragma mark Getters
- (nullable NSString *)getLocale;
- (nullable NSDictionary <NSNumber *, UUiCustomization *> *)getUICustomizationMap;
- (nonnull UConfigParameters *)getConfigParameters;

@end
#endif
