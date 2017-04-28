Pod::Spec.new do |s|
  s.name             = "HDAugmentedReality"
  s.version          = "2.0.0"
  s.summary          = "Augmented Reality component for iOS, written in Swift 2.0"
  s.description      = <<-DESC
                        ...
                       DESC
  s.homepage         = "https://github.com/DanijelHuis/HDAugmentedReality.git"
  s.license          = 'MIT'
  s.author           = { "Danijel Huis" => "danijel.huis@gmail.com" }
  s.source           = { :git => "https://github.com/DanijelHuis/HDAugmentedReality.git", :tag => s.version.to_s }

  s.platform     = :ios, '8.0'
  s.requires_arc = true

  s.source_files = 'HDAugmentedReality/Classes/**/*'
  #s.resource_bundles = {'Resources' => ['HDAugmentedReality/Resources/**/*.{xib,png}']}
  s.resources = 'HDAugmentedReality/Resources/**/*.{xib,png}'
end
