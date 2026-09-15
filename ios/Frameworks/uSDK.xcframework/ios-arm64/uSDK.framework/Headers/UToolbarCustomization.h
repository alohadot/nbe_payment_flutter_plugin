//
//  UToolbarCustomization.h
//  ThreeDSSDK
//
//  Created by Drew Pitchford on 1/30/20.
//  Copyright © 2020 mSignia. All rights reserved.
//

#import "UCustomization.h"

/**
 * A class for specifying the customization of navigation bars displayed by the SDK
 */
@interface UToolbarCustomization: UCustomization

/**
 * Custom Initializer
 */
- (nonnull UToolbarCustomization *)init;

/**
 The setBackgroundColor method shall set the background color for the navigation bar.
 
 @param hexColorCode Color code in Hex format. For example, the color code can be "#999999".
 */
- (BOOL)setBackgroundColor:(nonnull NSString *)hexColorCode
                       error:(NSError *_Nullable *_Nullable)error;

/**
 The setHeaderText method shall set the title of the navigation bar.
 
 @param headerText Text for the title
 
 */
- (BOOL)setHeaderText:(nonnull NSString *)headerText
                  error:(NSError *_Nullable *_Nullable)error;

/**
 The setButtonText method shall set the button text for the cancel button
 
 @param buttonText Text for the button
 
 */
- (BOOL)setButtonText:(nonnull NSString *)buttonText
                  error:(NSError *_Nullable *_Nullable)error;

/**
 The getBackgroundColor method shall return the background color for the navigation bar.

 @return the hex color code for the navigation bar
 */
- (nonnull NSString *)getBackgroundColor;

/**
 The getHeaderText method shall return the title for the navigation bar.

 @return the text for the navigation bar's title
 */
- (nullable NSString *)getHeaderText;

/**
 The getButtonText method shall return the button text of the toolbar.
 
  @return the text for the cancel button
 */
- (nullable NSString *)getButtonText;

@end

