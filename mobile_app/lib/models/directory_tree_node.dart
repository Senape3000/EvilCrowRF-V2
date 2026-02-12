class DirectoryTreeNode {
  final String name;
  final String path;
  final List<DirectoryTreeNode> directories;

  DirectoryTreeNode({
    required this.name,
    required this.path,
    required this.directories,
  });

  factory DirectoryTreeNode.fromJson(Map<String, dynamic> json) {
    List<DirectoryTreeNode> dirs = [];
    if (json['directories'] is List) {
      for (var dir in json['directories']) {
        if (dir is Map<String, dynamic>) {
          dirs.add(DirectoryTreeNode.fromJson(dir));
        }
      }
    }
    
    return DirectoryTreeNode(
      name: json['name'] ?? '',
      path: json['path'] ?? '',
      directories: dirs,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'path': path,
      'directories': directories.map((d) => d.toJson()).toList(),
    };
  }
}

