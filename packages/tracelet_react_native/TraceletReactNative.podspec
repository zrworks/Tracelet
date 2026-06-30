require "json"

package = JSON.parse(File.read(File.join(__dir__, "package.json")))

Pod::Spec.new do |s|
  s.name         = "TraceletReactNative"
  s.version      = package["version"]
  s.summary      = package["description"]
  s.homepage     = package["homepage"]
  s.license      = package["license"]
  s.authors      = package["author"]

  s.platforms    = { :ios => "14.0" }
  s.source       = { :git => "https://github.com/Ikolvi/Tracelet.git", :tag => "react-native-v#{s.version}" }

  s.source_files = "ios/**/*.{h,m,mm,swift}"

  # Framework-agnostic native SDK (bundles the shared Rust core).
  s.dependency "TraceletSDK", "~> 3.5.1"

  # React Native core (handles old + new architecture via install_modules_dependencies
  # when available, falling back to the classic React dependency otherwise).
  if respond_to?(:install_modules_dependencies, true)
    install_modules_dependencies(s)
  else
    s.dependency "React-Core"
  end
end
