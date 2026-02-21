#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint floating_palette.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'floating_palette'
  s.version          = '0.1.0'
  s.summary          = 'Native floating windows for Flutter desktop apps.'
  s.description      = <<-DESC
Build Notion-style menus, Spotlight-style search, tooltips, and more — each palette runs in its own native window with code generation for type-safe controllers.
                       DESC
  s.homepage         = 'https://github.com/PrimeCodeSolution/floating_palette'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'PrimeCodeSolution' => 'khalilamor95@gmail.com' }

  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'

  # If your plugin requires a privacy manifest, for example if it collects user
  # data, update the PrivacyInfo.xcprivacy file to describe your plugin's
  # privacy impact, and then uncomment this line. For more information,
  # see https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
  # s.resource_bundles = {'floating_palette_privacy' => ['Resources/PrivacyInfo.xcprivacy']}

  s.dependency 'FlutterMacOS'

  s.platform = :osx, '10.11'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.0'
end
