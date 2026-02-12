import 'dart:typed_data';

/// Binary file list parser for ESP32 device
/// 
/// Parses binary packets containing file lists sent by the device
/// using the new binary protocol (command 0x0E)
class BinaryFileParser {
  
  /// Parse a binary file list packet
  static BinaryFileListPacket? parsePacket(Uint8List data) {
    if (data.length < 8) {
      print('BinaryFileParser: Packet too small (${data.length} bytes)');
      return null;
    }
    
    int offset = 0;
    
    // Parse header
    final packetType = data[offset++];
    final packetSize = data[offset] | (data[offset + 1] << 8);
    offset += 2;
    final fileCount = data[offset] | (data[offset + 1] << 8);
    offset += 2;
    offset += 3; // Skip reserved bytes
    
    if (data.length < packetSize) {
      print('BinaryFileParser: Packet size mismatch (expected: $packetSize, got: ${data.length})');
      return null;
    }
    
    // Parse file entries
    final List<BinaryFileEntry> files = [];
    
    for (int i = 0; i < fileCount; i++) {
      if (offset >= data.length) {
        print('BinaryFileParser: Unexpected end of data while parsing file $i');
        break;
      }
      
      final nameLength = data[offset++];
      
      if (offset + nameLength > data.length) {
        print('BinaryFileParser: Name length exceeds packet bounds');
        break;
      }
      
      final name = String.fromCharCodes(data.sublist(offset, offset + nameLength));
      offset += nameLength;
      
      if (offset + 9 > data.length) {
        print('BinaryFileParser: Not enough data for file entry');
        break;
      }
      
      // Parse file size (little-endian)
      final size = data[offset] |
                   (data[offset + 1] << 8) |
                   (data[offset + 2] << 16) |
                   (data[offset + 3] << 24);
      offset += 4;
      
      // Parse file date (little-endian)
      final date = data[offset] |
                   (data[offset + 1] << 8) |
                   (data[offset + 2] << 16) |
                   (data[offset + 3] << 24);
      offset += 4;
      
      // Parse file type
      final type = data[offset++];
      
      files.add(BinaryFileEntry(
        name: name,
        size: size,
        date: date,
        type: type,
      ));
    }
    
    return BinaryFileListPacket(
      packetType: packetType,
      packetSize: packetSize,
      fileCount: fileCount,
      files: files,
    );
  }
  
  /// Parse multiple packets and combine into a single file list
  static List<BinaryFileEntry> parseMultiplePackets(List<Uint8List> packets) {
    final List<BinaryFileEntry> allFiles = [];
    
    for (final packet in packets) {
      final parsed = parsePacket(packet);
      if (parsed != null) {
        allFiles.addAll(parsed.files);
      }
    }
    
    return allFiles;
  }
}

/// Represents a single binary file list packet
class BinaryFileListPacket {
  final int packetType; // 0x01=Start, 0x02=Continue, 0x03=End
  final int packetSize;
  final int fileCount;
  final List<BinaryFileEntry> files;
  
  const BinaryFileListPacket({
    required this.packetType,
    required this.packetSize,
    required this.fileCount,
    required this.files,
  });
  
  bool get isStart => packetType == 0x01;
  bool get isContinue => packetType == 0x02;
  bool get isEnd => packetType == 0x03;
  
  @override
  String toString() {
    return 'BinaryFileListPacket(type: $packetType, size: $packetSize, files: $fileCount)';
  }
}

/// Represents a single file entry in binary format
class BinaryFileEntry {
  final String name;
  final int size;
  final int date; // Unix timestamp
  final int type; // 0x01=File, 0x02=Directory
  
  const BinaryFileEntry({
    required this.name,
    required this.size,
    required this.date,
    required this.type,
  });
  
  bool get isFile => type == 0x01;
  bool get isDirectory => type == 0x02;
  
  /// Convert to format compatible with existing file list UI
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'size': size,
      'date': date.toString(),
      'type': isDirectory ? 'directory' : 'file',
    };
  }
  
  @override
  String toString() {
    return 'BinaryFileEntry(name: $name, size: $size, date: $date, type: $type)';
  }
}




















