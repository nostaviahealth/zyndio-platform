require 'xcodeproj'
project_path = 'Runner.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.find { |t| t.name == 'BrandWatch' }

# Create a group for the Watch app files if it doesn't exist
watch_group = project.main_group.find_subpath('BrandWatch', true)

# Add files to the group
files_to_add = [
    'BrandWatch/BrandWatchApp.swift',
    'BrandWatch/WatchConnector.swift',
    'BrandWatch/WatchContentView.swift',
    'BrandWatch/Info.plist',
    'BrandWatch/Assets.xcassets'
]

# Ensure we're adding files to the compile sources phase
sources_build_phase = target.source_build_phase
resources_build_phase = target.resources_build_phase

files_to_add.each do |file_path|
    unless watch_group.files.any? { |f| f.path == file_path.split('/').last }
        file_ref = watch_group.new_file(file_path.split('/').last)
        if file_path.end_with?('.swift')
            sources_build_phase.add_file_reference(file_ref)
        elsif file_path.end_with?('.plist') || file_path.end_with?('.xcassets')
             resources_build_phase.add_file_reference(file_ref)
        end
    end
end

project.save
puts "Added Swift and Asset files to Xcode Target"
