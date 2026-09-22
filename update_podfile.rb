podfile_content = File.read('ios/Podfile')
new_content = podfile_content.sub(
  /post_install do \|installer\|.*?end/m,
  <<~RUBY
  post_install do |installer|
    installer.pods_project.targets.each do |target|
      flutter_additional_ios_build_settings(target)
      target.build_configurations.each do |config|
        config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.5'
      end
    end
  end
  RUBY
)
File.write('ios/Podfile', new_content)
