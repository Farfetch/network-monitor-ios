Pod::Spec.new do |spec|
  spec.name = 'FNMNetworkMonitor'
  spec.module_name = 'FNMNetworkMonitor'
  spec.version = '11.5.1'
  spec.summary = 'A network monitor'
  spec.homepage = 'https://github.com/Farfetch/network-monitor-ios'
  spec.license = 'MIT'
  spec.author = 'Farfetch'
  spec.source = { :git => 'https://github.com/Farfetch/network-monitor-ios.git', :tag => spec.version.to_s }

  spec.ios.deployment_target = '10.0'
  spec.requires_arc = true

  spec.cocoapods_version = '>= 1.7'
  spec.swift_versions = ['5.0', '5.1', '5.2', '5.3']

  spec.source_files = 'NetworkMonitor/Classes/**/*.{h,m,swift}'
end
