Pod::Spec.new do |s|
  s.name             = 'TraceletSDK'
  s.version          = '3.0.1'
  s.summary          = 'Production-grade background geolocation SDK for iOS.'
  s.description      = <<-DESC
    TraceletSDK provides battery-conscious background geolocation with motion detection,
    geofencing, SQLite persistence, HTTP sync, and headless execution for iOS.
    Framework-agnostic — usable from Flutter, React Native, Capacitor, or native iOS apps.
  DESC
  s.homepage         = 'https://github.com/Ikolvi/Tracelet/tree/main/sdk/ios'
  s.license          = { :type => 'Apache-2.0', :file => 'LICENSE' }
  s.author           = { 'Ikolvi' => 'contact@ikolvi.com' }
  s.source           = { :git => 'https://github.com/Ikolvi/Tracelet.git', :tag => "sdk-ios-v#{s.version}" }

  s.ios.deployment_target = '14.0'
  s.swift_version = '5.9'

  s.source_files = 'sdk/ios/Sources/TraceletSDK/**/*.swift', 'sdk/ios/Sources/TraceletSDK/*.swift', 'sdk/ios/Sources/TraceletSDK/**/*.h', 'sdk/ios/Sources/TraceletSDK/*.h'
  s.public_header_files = 'sdk/ios/Sources/TraceletSDK/**/*.h', 'sdk/ios/Sources/TraceletSDK/*.h'

  # Apple frameworks
  s.frameworks = 'CoreLocation', 'CoreMotion', 'UIKit', 'BackgroundTasks',
                 'AVFoundation', 'AudioToolbox', 'Network', 'DeviceCheck'

  # System libraries
  s.libraries = 'sqlite3'
  
  # Rust Core
  s.vendored_frameworks = 'sdk/rust-core/out/TraceletCore.xcframework'
  
  s.prepare_command = <<-CMD
    if [ ! -d "sdk/rust-core/out/TraceletCore.xcframework" ]; then
      echo "Downloading precompiled TraceletCore.xcframework..."
      mkdir -p sdk/rust-core/out
      curl -fL "https://github.com/Ikolvi/Tracelet/releases/download/sdk-ios-v#{s.version}/TraceletCore.xcframework.zip" -o TraceletCore.xcframework.zip || true
      if [ -f TraceletCore.xcframework.zip ]; then
        unzip -o TraceletCore.xcframework.zip -d sdk/rust-core/out/ || true
        rm TraceletCore.xcframework.zip
      fi
    else
      echo "Local TraceletCore.xcframework found. Skipping download."
    fi
  CMD

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386'
  }
end
