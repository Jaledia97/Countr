podfile_content = File.read('macos/Podfile')
new_content = podfile_content.sub(
  /platform :osx, '10.15'/,
  "platform :osx, '12.0'"
).sub(
  /post_install do \|installer\|.*?end/m,
  <<~RUBY
  post_install do |installer|
    installer.pods_project.targets.each do |target|
      flutter_additional_macos_build_settings(target)
      target.build_configurations.each do |config|
        config.build_settings['MACOSX_DEPLOYMENT_TARGET'] = '12.0'
      end
    end
  end
  RUBY
)
File.write('macos/Podfile', new_content)
