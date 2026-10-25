Pod::Spec.new do |s|
  s.name             = 'platform_wearables'
  s.version          = '0.1.0'
  s.summary          = 'Zyndio Wearables Flutter plugin.'
  s.description      = 'A Flutter plugin for unified wearable health data.'
  s.homepage         = 'https://zyndio.example'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Zyndio' => 'support@zyndio.example' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.frameworks = 'HealthKit', 'AuthenticationServices'
  s.platform = :ios, '15.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end
