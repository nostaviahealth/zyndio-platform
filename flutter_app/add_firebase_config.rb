require 'xcodeproj'

project_path = 'ios/Runner.xcodeproj'
unless File.exist?(project_path)
  puts "Xcode project not found at #{project_path}"
  exit 1
end

project = Xcodeproj::Project.open(project_path)
main_target = project.targets.first

# Find the Runner group
group = project.main_group.find_subpath('Runner', true)

# The file we want to add
filename = 'GoogleService-Info.plist'
file_path = "ios/Runner/#{filename}"

unless File.exist?(file_path)
  puts "❌ Error: #{file_path} does not exist in the filesystem. Cannot add to project."
  exit 1
end

# Check if file already in group
file_ref = group.files.find { |f| f.path == filename }

unless file_ref
  puts "Adding #{filename} to Xcode project group..."
  file_ref = group.new_reference(filename)
end

# Check if file is in the Build Phases -> Copy Bundle Resources
unless main_target.resources_build_phase.files_references.include?(file_ref)
  puts "Adding #{filename} to Copy Bundle Resources..."
  main_target.add_resources([file_ref])
end

project.save
puts "✅ GoogleService-Info.plist has been successfully linked in Xcode."
