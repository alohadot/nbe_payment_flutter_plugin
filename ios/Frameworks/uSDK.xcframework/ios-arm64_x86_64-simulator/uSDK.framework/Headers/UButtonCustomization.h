//
//  UButtonCustomization.h
//  ThreeDSSDK
//
//  Created by Drew Pitchford on 1/30/20.
//  Copyright © 2020 mSignia. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "UCustomization.h"

/*
 * A class for specifying the customization of buttons displayed by the SDK
 */
@interface UButtonCustomization: UCustomization

/**
 * Custom initializer
 */
- (nonnull UButtonCustomization *)init;

/**
 The setBackgroundColor method shall set the background color for the button.
 
 @param hexColorCode String Color code in Hex format. For example, the color code can be "#999999".
 */
- (BOOL)setBackgroundColor:(nonnull NSString *)hexColorCode
                      error:(NSError *_Nullable *_Nullable)error;

/**
 The setCornerRadius method shall set the radius for the button corners.
 
 @param cornerRadius Int Radius (integer value) for the button corners.
 */
- (BOOL)setCornerRadius:(NSInteger)cornerRadius
                    error:(NSError *_Nullable *_Nullable)error;

/**
 The getBackgroundColor method shall return the background color for the button.
 */
- (nonnull NSString *)getBackgroundColor;

/**
 The getCornerRadius method shall return the radius for the button corners.
 */
- (NSInteger)getCornerRadius;

@end
