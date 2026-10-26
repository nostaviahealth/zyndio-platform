require 'xcodeproj'

project_path = 'ios/Runner.xcodeproj'
unless File.exist?(project_path)
  puts "Xcode project not found at #{project_path}"
  exit 1
end

project = Xcodeproj::Project.open(project_path)
main_target = project.targets.first

# 1. Disable PNG Compression for the whole target to prevent 'grid' issues with alternate icons
main_target.build_configurations.each do |config|
  config.build_settings['COMPRESS_PNG_FILES'] = 'NO'
  config.build_settings['STRIP_PNG_TEXT'] = 'NO'
end
puts "✅ Build Settings: COMPRESS_PNG_FILES and STRIP_PNG_TEXT set to NO."

group = project.main_group.find_subpath('Runner', true)

# 2. Define the exact files we expect (PremiumBrand naming convention)
expected_files = [
  'PremiumBrand@2x.png',
  'PremiumBrand@3x.png',
  'PremiumBrand~ipad.png',
  'PremiumBrand@2x~ipad.png',
  'PremiumBrand.png'
]

# Cleanup loop: Remove any files starting with 'Plus' or 'PremiumBrand' that aren't in our exact set
group.files.each do |file_ref|
  is_old_plus = file_ref.path.start_with?('Plus')
  is_old_premium = file_ref.path.start_with?('PremiumBrand') && !expected_files.include?(file_ref.path)
  
  if is_old_plus || is_old_premium
    puts "Cleaning up obsolete reference: #{file_ref.path}"
    main_target.resources_build_phase.remove_file_reference(file_ref)
    file_ref.remove_from_project
  end
end

# 3. Add specific files to the project and bundle
expected_files.each do |filename|
  file_path = "ios/Runner/#{filename}"
  if File.exist?(file_path)
    # Check if file already in group
    file_ref = group.files.find { |f| f.path == filename }
    
    unless file_ref
      puts "Linking #{filename} to project..."
      file_ref = group.new_reference(filename)
    end

    # Check if file is in the Build Phases -> Copy Bundle Resources
    unless main_target.resources_build_phase.files_references.include?(file_ref)
      puts "Adding #{filename} to bundle resources..."
      main_target.add_resources([file_ref])
    end
  else
    puts "⚠️ Warning: #{file_path} not found. Skipping."
  end
end

project.save
puts "✅ Xcode project synchronized with PremiumBrand icons."
