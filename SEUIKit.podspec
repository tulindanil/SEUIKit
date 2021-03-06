#
# Be sure to run `pod lib lint SEUIKit.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = "SEUIKit"
  s.version          = "0.2.0.2"
  s.summary          = "User interface kit for Smart Engines"

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!  
  s.description      =  <<-DESC
                        SECameraViewController for a lot of Smart Engines projects"
                        DESC

  s.homepage         = "https://github.com/tulindanil/SEUIKit"
  s.license          = 'MIT'
  s.author           = { "tulindanil" => "tulindanil@gmail.com" }
  s.source           = { :git => "https://github.com/tulindanil/SEUIKit.git", :tag => "0.2.0.2" }
  # s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'

  s.platform     = :ios, '7.0'
  s.requires_arc = true

  s.source_files = 'Pod/Classes/**/*'
  s.resource_bundles = {
    'SEUIKit' => ['Pod/Assets/*.png']
  }

  # s.public_header_files = 'Pod/Classes/**/*.h'
  # s.frameworks = 'UIKit', 'MapKit'
  s.prefix_header_contents = '#import "Masonry.h"', '#import "Constants.h"', '#import "MPColorTools.h"', '#define LOG_LEVEL_DEF ddLogLevel', '#import <CocoaLumberjack/CocoaLumberjack.h>',
  'static const DDLogLevel ddLogLevel = DDLogLevelDebug;'
  s.dependency 'MPColorTools'
  s.dependency 'Masonry'
  s.dependency 'CocoaLumberjack' 
end
