require 'xcodeproj'
require 'fileutils'

puts "Reading Config..."
project_path = 'Runner.xcodeproj'
project = Xcodeproj::Project.open(project_path)
puts "Project opened."

target_name = 'BrandWatch'
bundle_id = 'com.zyndio.patient.watchkitapp'
platform = :watchos
deployment_target = '10.0'

# Check if target already exists
if project.targets.any? { |t| t.name == target_name }
  puts "Target #{target_name} already exists."
  exit 0
end

puts "Creating watchOS target..."
watch_target = project.new_target(:application, target_name, platform, deployment_target)

# Configure build settings
watch_target.build_configurations.each do |config|
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = bundle_id
  config.build_settings['INFOPLIST_FILE'] = "#{target_name}/Info.plist"
  config.build_settings['ASSETCATALOG_COMPILER_APPICON_NAME'] = 'AppIcon'
  config.build_settings['ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME'] = 'AccentColor'
  config.build_settings['SWIFT_VERSION'] = '5.0'
  config.build_settings['TARGETED_DEVICE_FAMILY'] = '4' # watchOS
  config.build_settings['WATCHOS_DEPLOYMENT_TARGET'] = deployment_target
  config.build_settings['DEVELOPMENT_TEAM'] = '3QW98F397X' # Zyndio health team ID (just placeholder for now, usually managed via fastlane/manual)
  config.build_settings['CODE_SIGN_STYLE'] = 'Automatic'
  config.build_settings['ENABLE_PREVIEWS'] = 'YES'
  config.build_settings['CURRENT_PROJECT_VERSION'] = '236'
  config.build_settings['MARKETING_VERSION'] = '2.1.0'
end

# Find the iOS target to embed the watch app
ios_target = project.targets.find { |t| t.name == 'Runner' }
if ios_target.nil?
  puts "Could not find 'Runner' iOS target!"
  exit 1
end

# Embed watch app within iOS app
puts "Embedding watch app..."
embed_phase = ios_target.new_copy_files_build_phase("Embed Watch Content")
embed_phase.dst_subfolder_spec = '16' # Products Directory
embed_phase.run_only_for_deployment_postprocessing = '0'

file_reference = project.products_group.files.find { |f| f.path == "#{target_name}.app" }
unless file_reference
    file_reference = project.products_group.new_product_ref_for_target(watch_target.name, watch_target.product_type)
end

build_file = embed_phase.add_file_reference(file_reference)
build_file.settings = { "ATTRIBUTES" => ["RemoveHeadersOnCopy"] }

project.save
puts "Successfully added #{target_name} to #{project_path}"
