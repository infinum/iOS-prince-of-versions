Pod::Spec.new do |s|
  s.name = "PrinceOfVersions"
  s.version = "4.0.1"
  s.summary = "Library checks for updates using configuration from some resource."
  s.homepage = "https://github.com/infinum/iOS-prince-of-versions"
  s.license = { :type => "MIT", :file => "LICENSE" }
  s.author = { "Jasmin Abou Aldan" => "jasmin.aboualdan@infinum.hr" }
  s.platform = :ios, :osx
  s.ios.deployment_target = '8.0'
  s.osx.deployment_target = '10.10'
  s.source = { :git => "https://github.com/infinum/iOS-prince-of-versions.git", :tag => "#{s.version}" }
  s.source_files  = "Sources/**/*.{h,m,swift}"
  s.ios.framework  = 'UIKit'
  s.osx.framework  = 'AppKit'
  s.swift_version = "5.1"
end
