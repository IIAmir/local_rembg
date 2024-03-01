#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint local_rembg.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'local_rembg'
  s.version          = '0.0.5'
  s.summary          = 'A flutter plugin for remove background from image'
  s.description      = <<-DESC
A flutter plugin for remove background from image
                       DESC
  s.homepage         = 'https://github.com/IIAmir/local_rembg'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Amirreza Alizadeh' => 'developer.iiamir@gmail.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '15.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end
