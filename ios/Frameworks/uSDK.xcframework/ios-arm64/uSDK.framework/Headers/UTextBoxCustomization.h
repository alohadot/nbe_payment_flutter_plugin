//
//  TextBoxCustomization.h
//  ThreeDSSDK
//
//  Created by Drew Pitchford on 1/30/20.
//  Copyright © 2020 mSignia. All rights reserved.
//

#import "UCustomization.h"

/**
 * A class for specifying the customization of text fields displayed by the SDK
 */
@interface UTextBoxCustomization: UCustomization

/**
 * Custom Initializer
 */
- (nonnull UTextBoxCustomization *)init;

/**
 The setBorderWidth method shall set the width of the text box border.

 @param borderWidth Int width (integer value) for the text border width.
 
 */
- (BOOL)setBorderWidth:(NSInteger)borderWidth
                   error:(NSError *_Nullable *_Nullable)error;

/**
 The setBorderColor method shall set the color for the border of the text box.

 @param hexColorCode String Color code in Hex format. For example, the color code can be "#999999".
 
 */
- (BOOL)setBorderColor:(nonnull NSString *)hexColorCode
                   error:(NSError *_Nullable *_Nullable)error;

/**
 The setCornerRadius method shall set the radius for the text box corners.

 @param cornerRadius Int radius (integer value) for the text box corners.
 
 */
- (BOOL)setCornerRadius:(NSInteger)cornerRadius
                    error:(NSError *_Nullable *_Nullable)error;

/**
 The getBorderWidth method shall return the width of the text box border.

 @return border witdh of text field
 
 */
- (NSInteger)getBorderWidth;

/**
 The getBorderColor method shall return the color of the text box border.
 
 @return border color of text field
 
 */
- (nonnull NSString *)getBorderColor;

/**
 The getCornerRadius method shall return the radius for the text box corners.

 @return corner radius of text field
 
 */
- (NSInteger)getCornerRadius;

@end

