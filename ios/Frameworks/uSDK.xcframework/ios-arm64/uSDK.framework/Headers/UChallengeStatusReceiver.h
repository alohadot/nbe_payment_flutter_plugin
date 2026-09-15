//
//  UChallengeStatusReceiver.h
//  ThreeDSSDK
//
//  Created by Drew Pitchford on 1/31/20.
//  Copyright © 2020 mSignia. All rights reserved.
//

#import <UIKit/UIKit.h>

@class UCompletionEvent, UProtocolErrorEvent, URuntimeErrorEvent, UIViewController;

/**
 A callback object that implements the ChallengeStatusReceiver interface shall receive challenge status notification from the 3DS SDK at the end of the challenge process. This receiver object may be notified by calling various methods.
 
 Depending on the result of the challenge process, the Merchant App may display a message or redirect the Cardholder to the appropriate screen in the app.
 
 This can be more appropriately understood as `ChallengeStatusDelegate`
 */
@protocol UChallengeStatusReceiver <NSObject>

@optional
/**
 The completed method shall be called when the challenge process is completed. When a transaction is completed, the transaction status shall be available.

 @param completionEvent Information about completion of the challenge process.
 */
- (void)completed:(nonnull UCompletionEvent *)completionEvent;


/**
 The cancelled method shall be called when the Cardholder selects the option to cancel payment on the challenge screen. Before sending notification about the cancelled event to the Merchant App, the 3DS SDK shall end the challenge flow. The app displays subsequent screens after it receives notification about this event.
 */
- (void)cancelled;

/**
 The timedout method shall be called when the challenge process reaches or exceeds the timeout specified during the doChallenge call on the 3DS SDK. On timeout, the SDK shall make a best effort to stop the challenge flow as soon as possible. Before sending notification about the Timed Out event to the Merchant App, the 3DS SDK shall end the challenge flow. The app displays subsequent screens after it receives notification about this event.
 */
- (void)timedout;

/**
 In the 3DS SDK context, a protocol error is any error message that is returned by the ACS. The protocolError method shall be called when the 3DS SDK receives such an error message. The 3DS SDK sends the error code and details from this error message as part of the notification to the 3DS Requestor App.

 @param protocolErrorEvent Error code and details.
 */
- (void)protocolError:(nonnull UProtocolErrorEvent *)protocolErrorEvent;

/**
 The runtimeError method shall be called when the 3DS SDK encounters errors during the challenge process.
 
 @param runtimeErrorEvent Error code and details.
 */
- (void)runtimeError:(nonnull URuntimeErrorEvent *)runtimeErrorEvent;

@end
