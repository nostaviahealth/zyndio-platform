require 'xcodeproj'

project_path = 'ios/Runner.xcodeproj'
unless File.exist?(project_path)
  puts "Xcode project not found at #{project_path}"
  exit 1
end

project = Xcodeproj::Project.open(project_path)
main_target = project.targets.first

# Check if the PlusIcons group exists, create if not
group = project.main_group.find_subpath('Runner', true)

# Find all Plus*.png files in ios/Runner
icon_files = Dir.glob('ios/Runner/Plus*.png')

icon_files.each do |file_path|
  filename = File.basename(file_path)
  
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
end

project.save
puts "✅ Xcode project updated with alternate icons."
