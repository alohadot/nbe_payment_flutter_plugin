# Release Notes
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.17] -  2026-01-07
### Changed
- Targeting latest 3DS SDK: 6.7.60

## [2.0.16] - 2026-01-07
### Changed
- Targeting latest 3DS SDK: 6.7.52
- Migrated SDK initialization callback handling from LocalBroadcastManager (deprecated) to a system BroadcastReceiver.
- Set UI customization to DEFAULT.

## [2.0.15] - 2025-09-25
### Changed
- Targeting latest 3DS SDK: 6.6.81

## [2.0.14] - 2025-2-23
### Changed
- Updating Gateway SDK pinned certificate. New Expiry Jan 2038

## [2.0.13] - 2025-01-13
### Changed
- Targeting latest 3DS SDK: 6.6.71

## [2.0.12] - 2024-04-25
### Changed
- Targeting latest 3DS SDK: 6.6.69

## [2.0.11] - 2024-02-23
### Changed
- Targeting latest 3DS SDK: 6.6.68
### Added
- Updated "cn.gateway.mastercard.com to gateway.sspriceless.cn" to support new china end point
### Fixed
- Android 14 compatibility

## [2.0.10] - 2023-03-27
### Changed
- Updated recommendations
- Updated Gateway SDK api response parsing logic to make it inline with iOS
- Fixed/Updated Unit Tests
- Targeting latest 3DS SDK: 6.5.52


## [2.0.9] - 2022-12-22
### Changed
- Min Supported API version set to 61+
- Remove support for legacy paymentOptionsInquiry API Call
- Updating Gateway SDK pinned certificate. New Expiry December 2030

## [2.0.8] - 2022-10-27
### Changed
- Targeting latest 3DS SDK: 6.5.49

## [2.0.7] - 2022-08-18
### Changed
- Targeting latest 3DS SDK: 6.5.47

## [2.0.6] - 2022-05-17
### Changed
- Targeting latest 3DS SDK: 6.5.42

## [2.0.5] - 2022-04-13
### Changed
- Minor updates

## [2.0.4] - 2021-11-23
### Changed
- Targeting latest 3DS SDK: 6.5.40

## [2.0.3] - 2021-10-04
### Changed
- Target to nexus repo

## [2.0.2] - 2021-10-08
### Changed
- Targeting latest 3DS SDK: 6.5.34

## [2.0.1] - 2021-05-27
### Changed
- Targeting latest 3DS SDK: 6.5.25

## [2.0.0] - 2021-05-20
### Changed
- Total contract refactor, now utilizing Kotlin objects and static utility methods
### Added
- EMV 3DS support
- Kotlin coroutine support

## [1.1.4] - 2020-03-26
### Fixed
- Issue where WebView was not displaying the 3DS HTML on apps targeting API >=29
### Changed
- SDK and sample app now targeting API 29
- Migrated from legacy Android support libraries to Jetpack

## [1.1.3] - 2020-02-14
### Added
- China region (CN) URL
### Changed
- Enabled TLSv1.2 support for API <21

## [1.1.2] - 2020-02-04
### Added
- India region (IN) URL