require 'xcodeproj'

project_path = 'ios/Runner.xcodeproj'
unless File.exist?(project_path)
  puts "Xcode project not found at #{project_path}"
  exit 1
end

project = Xcodeproj::Project.open(project_path)
main_target = project.targets.first

group = project.main_group.find_subpath('Runner', true)

# Define the exact files we expect
expected_files = [
  'PlusIcon-60x60@2x.png',
  'PlusIcon-60x60@3x.png',
  'PlusIcon-76x76@2x~ipad.png',
  'PlusIcon-83.5x83.5@2x~ipad.png',
  'Plus.png'
]

# Add these specific files
expected_files.each do |filename|
  file_path = "ios/Runner/#{filename}"
  if File.exist?(file_path)
    # Check if file already in group
    file_ref = group.files.find { |f| f.path == filename }
    
    unless file_ref
      puts "Adding #{filename} to Xcode project..."
      file_ref = group.new_reference(filename)
    end

    # Check if file is in the Build Phases -> Copy Bundle Resources
    unless main_target.resources_build_phase.files_references.include?(file_ref)
      puts "Adding #{filename} to Copy Bundle Resources..."
      main_target.add_resources([file_ref])
    end
  else
    puts "⚠️ Warning: #{file_path} not found. Skipping."
  end
end

project.save
puts "✅ Xcode project updated with exact alternate icons."
