//
//  HtmlOobChallengeProtocol.h
//  ThreeDSSDK
//
//  Created by Sergey Klymenko on 14.04.2025.
//  Copyright © 2025 mSignia. All rights reserved.
//

#import <WebKit/WebKit.h>
#import "GenericChallengeProtocol.h"

@protocol HtmlOobChallengeProtocol <GenericChallengeProtocol>

- (nonnull WKWebView *)getWebView;
- (void)clickChallengeAddLabel;
- (void)clickOobContinueLabel;
- (void)clickOobAppLabel;

@end
