//
//  UTransaction.h
//  ThreeDSSDK
//
//  Created by Drew Pitchford on 1/31/20.
//  Copyright © 2020 mSignia. All rights reserved.
//

#import "UChallengeStatusReceiver.h"


@class UChallengeParameters, UAuthenticationRequestParameters, UIViewController, UIView, UProgressDialog;

/**
 Represents a Transaction
 */
@protocol UTransaction <NSObject>


/**
 When the 3DS Requestor App calls the getAuthenticationRequestParameters method, the 3DS SDK shall encrypt the device information that it collects during initialization and send this information along with the SDK information to the 3DS Requestor App. The app includes this information in its message to the 3DS Server. This getAuthenticationRequestParameters method shall be called for every transaction.
 
 @return AuthenticationRequestParameters object
 */
- (nullable UAuthenticationRequestParameters *)getAuthenticationRequestParameters:(NSError *_Nullable *_Nullable)error;

/**
 If the ARes that is returned indicates that the Challenge Flow must be applied, the 3DS Requestor App calls the doChallenge method with the required input parameters. The doChallenge method initiates the challenge process.
 
 Note: The doChallenge method shall be called only when the Challenge Flow is to be applied.
 
 The 3DS SDK shall display the challenge to the Cardholder.
 The 3DS SDK shall exchange two or more CReq and CRes messages with the ACS.
 The challenge status shall be communicated back to the Merchant App by the 3DS SDK by using the ChallengeStatusReceiver callback functions.
 
 @param currentNavController The UINavigationController inside which the SDK UI will be presented.
 @param challengeParameters ACS details required by the 3DS SDK to conduct the challenge process during the transaction. The following details are mandatory: MI transaction ID, ACS account ID, ACS certificate, ACS signature, ACS rendering type, Protocol, ACS reference number, JWS signed ACS data.
 @param challengeStatusReceiver Callback object for notifying the 3DS Requestor App about the challenge status.
 @param timeOut interval within which the challenge process must be completed.
 */
- (BOOL)doChallenge:(nonnull UINavigationController *)currentNavController
  challengeParameters:(nonnull UChallengeParameters *)challengeParameters
challengeStatusReceiver:(nonnull id<UChallengeStatusReceiver>)challengeStatusReceiver
              timeOut:(int)timeOut
                error:(NSError *_Nullable *_Nullable)error;

/**
 The getProgressView method shall return an instance of Progress View (processing screen) that the 3DS Requestor App uses. The processing screen displays the Directory Server logo, and a graphical element to indicate that an activity is being processed. The ProgressView object is created by the 3DS SDK.
 
 @return ProgressDialog
 */
- (nullable UProgressDialog *)getProgressView:(NSError *__autoreleasing  _Nullable *_Nullable)error;

/**
 The close method is called to clean up resources that are held by the Transaction object. It shall be called when the transaction is completed. The following are some examples of transaction completion events:
 
 - The Cardholder completes the challenge.
 - An error occurs
 - The Cardholder chooses to cancel the transaction.
 - The ACS recommends a challenge, but the Merchant overrides the recommendation and chooses to complete the transaction without a challenge
 */
- (BOOL)close;

@end

