require "json"

package = JSON.parse(File.read(File.join(__dir__, "package.json")))

Pod::Spec.new do |s|
  s.name         = "ScreenRecord"
  s.version      = package["version"]
  s.summary      = package["description"]
  s.homepage     = package["homepage"]
  s.license      = package["license"]
  s.authors      = package["author"]

  s.platforms    = { :ios => min_ios_version_supported }
  s.source       = { :git => "https://github.com/alexeevayaan/react-native-screen-record.git", :tag => "#{s.version}" }

  s.source_files = "ios/**/*.{h,m,mm,swift,cpp}"
  # The Swift package that tests the core on its own isn't part of the pod.
  s.exclude_files = "ios/Package.swift", "ios/Tests/**/*"
  s.private_header_files = "ios/**/*.h"
  s.frameworks = "AVFoundation", "CoreMedia", "CoreVideo", "QuartzCore", "UIKit"

  install_modules_dependencies(s)
end
