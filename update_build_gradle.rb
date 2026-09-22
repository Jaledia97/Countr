content = File.read('android/app/build.gradle.kts')
new_content = content.sub(
  /release \{[\s\S]*?\}/,
  <<~KOTLIN
  release {
            signingConfig = signingConfigs.getByName("debug")
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
  KOTLIN
)
File.write('android/app/build.gradle.kts', new_content)
