Pod::Spec.new do |s| 
  s.name = 'NERtcCallKit' 
  s.version = '1.0.1' 
  s.summary = 'Netease NERtcCallKit' 
  s.homepage = 'http://netease.im' 
  s.license = { :'type' => 'Copyright', :'text' => ' Copyright 2020 Netease '} 
  s.authors = 'Netease IM Team'  
  s.source  = { :git => 'https://github.com/netease-im/NERtcCallKit-iOS.git', :tag => '1.0.1'}  
  s.platform = :ios, '9.0' 
  s.source_files = 'NERtcCallKit/NERtcCallKit/Classes/**/*.{h,m}'
  s.dependency 'NIMSDK_LITE', '8.1.0'
  s.dependency 'NERtcSDK', '3.7.3.1'
end 
