# Release Notes

## [2.0.15] - Unreleased

## [2.0.14] - 2026-03-05
### Changed
- Updated mSignia SDK to the latest version 6.7.63

## [2.0.13] - 2026-01-07
### Changed
- Updated mSignia SDK to the latest version 6.7.56
- Updated Navigation Control for Challenge Flow

## [2.0.12] - 2025-11-25
### Changed
- Minor defect fix

## [2.0.11] - 2025-09-09
### Changed
- Updated mSignia SDK to the latest version 6.6.139

## [2.0.10] - 2025-02-23
### Changed
- Updated mSignia SDK to the latest version 6.6.132

## [2.0.9] - 2025-01-13
### Changed
- Updated mSignia SDK to the latest version 6.6.129
### Added
- Adding Privacy Manifestfile

## [2.0.8] - 2024-02-23

### Added
- Support for arm64 simulator on M1 mac
### Changed
- Updated "cn.gateway.mastercard.com to gateway.sspriceless.cn" to support new china end point
- Updated mSignia SDK to the latest version


## [2.0.7] - 2023-03-14
### Changed
- Support for API 70+. Gateway recommendation changes (see integration guide & sdk documentation)
- Updated AuthenticationError & GatewayError to return correct error description
- 3DS SDK updated to 6.5.62

## [2.0.6] - 2022-12-08
### Changed
- Min Supported API version set to 61+
- Remove support for legacy `paymentOptionsInquiry` API Call
- Updating Gateway SDK pinned certificate. New Expiry December 2030

## [2.0.5] - 2022-08-19
### Changed
- EMV 3DS certificate updates

## [2.0.4] - 2022-05-17
### Changed
- Package name updates
- EMV 3DS update to support certificate changes

## [2.0.3] - 2022-04-12
### Changed
- Minor updates

## [2.0.2] - 2021-11-15
### Changed
- Minor updates & EMV 3DS changes

## [2.0.1] - 2021-11-14
### Changed
- Minor updates

## [2.0.0] - 2021-11-05
### Added
- EMV 3DS support
### Changed
- Refined `GatewayMap` object with more familiar subscripting.
- Total contract refactor, now utilizing sharedInstances and static utility methods

## [1.1.5]
### Added
- Adding the China on-soil region
- Providing a way for integrators to use regions that have not yet been added to the SDK.
### Changed
- Converting all URLs to use the "<region>.gateway.mastercard.com" pattern

## [1.1.4]
### Changed
- Swift.package file version updated to specify swift 5.0
- Syncing Changes.md with releases

## [1.1.3]
### Added
- Added the India regions
### Changed
- Updated Fastlane versions

## [1.1.2]
### Changed
- Updated the project and source code to Swift 5
- Updated podspec file

## [1.1.1]
### Changed
- Updated the update session call to support Gateway API versions 50 and up

## [1.1.0]
### Changed
- Updated the update session call to support Gateway API versions 50 and up

### Added
- Sample app with support for Apple Pay

## [1.0.0]
### ADDED
- Initial Release of the sdk
- Support for updating a session with card information
- 3-D Secure 1.0 support for Gateway API versions 46 and below
