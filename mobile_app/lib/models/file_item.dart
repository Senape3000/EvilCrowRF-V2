class FileItem {
  final String name;
  final String type; // 'file' or 'directory'
  final int size;
  final String? path;
  final DateTime? dateCreated;

  FileItem({
    required this.name,
    required this.type,
    required this.size,
    this.path,
    this.dateCreated,
  });

  bool get isDirectory => type == 'directory';
  bool get isFile => type == 'file';

  String get sizeFormatted {
    if (isDirectory) return '';
    
    if (size < 1024) {
      return '$size B';
    } else if (size < 1024 * 1024) {
      return '${(size / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }

  factory FileItem.fromJson(Map<String, dynamic> json) {
    DateTime? dateCreated;
    
    // Try 'date' field first (from binary protocol), then 'dateCreated' (legacy)
    final dateValue = json['date'] ?? json['dateCreated'];
    if (dateValue != null) {
      try {
        if (dateValue is String) {
          // Try parsing as Unix timestamp string first (from binary protocol)
          final timestamp = int.tryParse(dateValue);
          if (timestamp != null && timestamp > 0) {
            dateCreated = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
          } else {
            // Try parsing as ISO date string
            dateCreated = DateTime.tryParse(dateValue);
          }
        } else if (dateValue is int) {
          // Unix timestamp in seconds
          dateCreated = DateTime.fromMillisecondsSinceEpoch(dateValue * 1000);
        }
      } catch (e) {
        dateCreated = null;
      }
    }
    
    return FileItem(
      name: json['name'] ?? '',
      type: json['type'] ?? 'file',
      size: json['size'] ?? 0,
      path: json['path'],
      dateCreated: dateCreated,
    );
  }


  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'type': type,
      'size': size,
      'path': path,
      'dateCreated': dateCreated?.toIso8601String(),
    };
  }
}
