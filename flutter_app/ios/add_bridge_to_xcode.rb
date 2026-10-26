require 'xcodeproj'
project_path = 'Runner.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.find { |t| t.name == 'Runner' }

runner_group = project.main_group.find_subpath('Runner', true)
file_path = 'Runner/WatchBridge.swift'

unless runner_group.files.any? { |f| f.path == 'WatchBridge.swift' }
    file_ref = runner_group.new_file('WatchBridge.swift')
    target.source_build_phase.add_file_reference(file_ref)
    project.save
    puts "Added WatchBridge.swift to Xcode Target"
else
    puts "WatchBridge.swift is already in the Xcode Target"
end
