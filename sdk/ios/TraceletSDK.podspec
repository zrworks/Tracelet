Pod::Spec.new do |s|
  s.name             = 'TraceletSDK'
  s.version          = '3.1.4'
  s.summary          = 'Production-grade background geolocation SDK for iOS.'
  s.homepage         = 'https://github.com/Ikolvi/Tracelet/tree/main/sdk/ios'
  s.license          = { :type => 'Apache-2.0', :file => '../../LICENSE' }
  s.author           = { 'Ikolvi' => 'contact@ikolvi.com' }
  s.source           = { :path => '.' }
  s.ios.deployment_target = '14.0'
  s.swift_version    = '5.9'
  s.source_files     = 'Sources/TraceletSDK/**/*.swift', 'Sources/TraceletSDK/*.swift', 'Sources/TraceletSDK/**/*.h', 'Sources/TraceletSDK/*.h'
  s.public_header_files = 'Sources/TraceletSDK/**/*.h', 'Sources/TraceletSDK/*.h'
  s.frameworks       = 'CoreLocation', 'CoreMotion', 'UIKit', 'BackgroundTasks', 'AVFoundation', 'AudioToolbox', 'Network', 'DeviceCheck'
  s.vendored_frameworks = '../rust-core/out/TraceletCore.xcframework'
  s.libraries        = 'sqlite3'
end
