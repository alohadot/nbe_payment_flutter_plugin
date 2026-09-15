#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint nbe_payment_flutter_plugin.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'nbe_payment_flutter_plugin'
  s.version          = '0.0.1'
  s.summary          = 'Flutter plugin for the NBE payment gateway (Mastercard Gateway SDK).'
  s.description      = <<-DESC
Flutter plugin wrapping the Mastercard Gateway iOS SDK: session update, 3-D Secure payer
authentication and Apple Pay.
                       DESC
  s.homepage         = 'https://alohadot.net'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Aloha Dot' => 'abdulrhman.nabil@alohadot.net' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '13.0'

  # Mastercard Gateway iOS SDK 2.0.14 and its 3DS SDK (mSignia uSDK 6.7.63). Both frameworks
  # ship their own privacy manifests.
  s.vendored_frameworks = 'Frameworks/Gateway.xcframework', 'Frameworks/uSDK.xcframework'
  s.frameworks = 'PassKit', 'UIKit'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end
