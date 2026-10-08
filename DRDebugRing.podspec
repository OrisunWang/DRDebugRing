Pod::Spec.new do |s|
  s.name = 'DRDebugRing'
  s.version = '0.1.0'
  s.summary = 'A scene-aware floating ring for custom iOS debug actions.'
  s.description = 'A draggable debug ring that presents a host-provided view controller, with touch passthrough, safe-area layout and no third-party dependencies.'
  s.homepage = 'https://github.com/OrisunWang/DRDebugRing'
  s.license = { :type => 'MIT', :file => 'LICENSE' }
  s.author = { 'OrisunWang' => 'https://github.com/OrisunWang' }
  s.source = { :git => 'https://github.com/OrisunWang/DRDebugRing.git', :tag => s.version.to_s }
  s.ios.deployment_target = '13.0'
  s.source_files = 'DebugRing/Classes/*.{h,m}'
  s.public_header_files = 'DebugRing/Classes/DRDebugRing.h'
  s.frameworks = 'UIKit'
  s.requires_arc = true
  # Configuration-qualified settings ensure Release compiles no ring implementation.
  # The host should still restrict its dependency to Debug in its Podfile.
  s.pod_target_xcconfig = { 'GCC_PREPROCESSOR_DEFINITIONS[config=Debug]' => '$(inherited) DEBUG_RING=1' }
end
