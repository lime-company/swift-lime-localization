Pod::Spec.new do |s|
  s.name = 'LimeLocalization'
  s.version = '%DEPLOY_VERSION%'
  # Metadata
  s.license = { :type => 'Apache License, Version 2.0', :file => 'LICENSE' }
  s.summary = 'Yet another localization framework written in swift'
  s.homepage = 'https://github.com/lime-company/swift-lime-localization'
  s.social_media_url = 'https://twitter.com/lime_company'
  s.author = { 'Lime - HighTech Solution s.r.o.' => 'support@lime-company.eu' }
  s.source = { :git => 'https://github.com/lime-company/swift-lime-localization.git', :tag => s.version }
  # Deployment targets
  s.swift_version = '4.0'
  s.ios.deployment_target = '8.0'
  s.watchos.deployment_target = '2.0'
  # Sources
  s.source_files = 'Source/*.swift'
  s.dependency 'LimeCore'
  s.dependency 'LimeConfig'
end
