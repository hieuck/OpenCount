#!/usr/bin/env python3
"""
Script tự động thêm các file mới vào Xcode project.pbxproj
"""
import re

def add_files_to_project():
    project_file = "OpenCount_iOS/OpenCount.xcodeproj/project.pbxproj"

    with open(project_file, 'r') as f:
        content = f.read()

    # Backup
    with open(project_file + '.backup', 'w') as f:
        f.write(content)

    # Thêm file references
    file_refs = """
		CA001040 /* ExportService.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = ExportService.swift; sourceTree = "<group>"; };
		CA001041 /* StatisticsService.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = StatisticsService.swift; sourceTree = "<group>"; };
		CA001042 /* StatisticsView.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = StatisticsView.swift; sourceTree = "<group>"; };"""

    pattern = r'(CA001021 /\* Info\.plist \*/ = {isa = PBXFileReference;[^}]+};)'
    content = re.sub(pattern, r'\1' + file_refs, content)

    # Thêm build files
    build_files = """
		CA001043 /* ExportService.swift in Sources */ = {isa = PBXBuildFile; fileRef = CA001040 /* ExportService.swift */; };
		CA001044 /* StatisticsService.swift in Sources */ = {isa = PBXBuildFile; fileRef = CA001041 /* StatisticsService.swift */; };
		CA001045 /* StatisticsView.swift in Sources */ = {isa = PBXBuildFile; fileRef = CA001042 /* StatisticsView.swift */; };"""

    pattern = r'(CA00101C /\* DetectionOverlay\.swift in Sources \*/ = {isa = PBXBuildFile;[^}]+};)'
    content = re.sub(pattern, r'\1' + build_files, content)

    # Thêm vào Services group
    pattern = r'(CA001011 /\* DetectionService\.swift \*/,)'
    content = re.sub(pattern, r'\1\n\t\t\t\tCA001040 /* ExportService.swift */,\n\t\t\t\tCA001041 /* StatisticsService.swift */,', content)

    # Thêm vào Views group
    pattern = r'(CA00101B /\* DetectionOverlay\.swift \*/,)'
    content = re.sub(pattern, r'\1\n\t\t\t\tCA001042 /* StatisticsView.swift */,', content)

    # Thêm vào PBXSourcesBuildPhase
    pattern = r'(CA00101C /\* DetectionOverlay\.swift in Sources \*/,)'
    content = re.sub(pattern, r'\1\n\t\t\t\tCA001043 /* ExportService.swift in Sources */,\n\t\t\t\tCA001044 /* StatisticsService.swift in Sources */,\n\t\t\t\tCA001045 /* StatisticsView.swift in Sources */,', content)

    with open(project_file, 'w') as f:
        f.write(content)

    print("[OK] Da them cac file vao Xcode project")

if __name__ == '__main__':
    add_files_to_project()
