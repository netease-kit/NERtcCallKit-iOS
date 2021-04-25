Pod::Spec.new do |s| 
  s.name = 'NERtcCallKit' 
  s.version = '1.1.0' 
  s.summary = 'Netease NERtcCallKit' 
  s.homepage = 'http://netease.im' 
  s.license = { :'type' => 'Copyright', :'text' => ' Copyright 2020 Netease '} 
  s.authors = 'Netease IM Team'  
  s.source  = { :git => 'https://github.com/netease-im/NERtcCallKit-iOS.git', :tag => '1.1.0'}  
  s.platform = :ios, '9.0' 
  s.source_files = 'NERtcCallKit/NERtcCallKit/**/*.{h,m}'
  s.dependency 'NIMSDK_LITE', '8.3.1'
  s.dependency 'NERtcSDK', '4.0.3'
end 
