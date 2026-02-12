// Example integration of binary file list protocol in BleProvider
// This is a demonstration of how to integrate the binary protocol

import 'dart:typed_data';
import 'binary_file_parser.dart';

class BinaryFileIntegrationExample {
  
  /// Example method to request binary file list from device
  static void requestBinaryFileList(String path) {
    // Create command payload: [command][pathLength][path]
    final pathBytes = Uint8List.fromList(path.codeUnits);
    final payload = Uint8List(2 + pathBytes.length);
    
    payload[0] = 0x0E; // Command: getFilesListBinary
    payload[1] = pathBytes.length; // Path length
    payload.setRange(2, 2 + pathBytes.length, pathBytes); // Path data
    
    print('BinaryFileIntegration: Requesting file list for path: $path');
    print('BinaryFileIntegration: Payload: ${payload.toList()}');
    
    // Send command to device (this would be integrated with actual BLE communication)
    // bleProvider.sendBinaryCommand(payload);
  }
  
  /// Example method to handle binary file list response
  static void handleBinaryFileListResponse(Uint8List data) {
    print('BinaryFileIntegration: Received binary response (${data.length} bytes)');
    
    // Parse the binary packet
    final packet = BinaryFileParser.parsePacket(data);
    if (packet == null) {
      print('BinaryFileIntegration: Failed to parse packet');
      return;
    }
    
    print('BinaryFileIntegration: Parsed packet: $packet');
    
    // Handle different packet types
    if (packet.isStart) {
      print('BinaryFileIntegration: Starting file list (${packet.fileCount} files in this packet)');
      // Initialize file list UI
      // fileList.clear();
    } else if (packet.isContinue) {
      print('BinaryFileIntegration: Continuing file list (${packet.fileCount} files in this packet)');
      // Continue building file list
    } else if (packet.isEnd) {
      print('BinaryFileIntegration: Ending file list (${packet.fileCount} files in this packet)');
      // Finalize file list and update UI
    }
    
    // Process file entries
    for (final file in packet.files) {
      print('BinaryFileIntegration: File: ${file.name} (${file.size} bytes, ${file.isDirectory ? 'directory' : 'file'})');
      
      // Convert to JSON format for compatibility with existing UI
      final jsonFile = file.toJson();
      print('BinaryFileIntegration: JSON format: $jsonFile');
      
      // Add to file list (this would be integrated with actual UI)
      // fileList.add(jsonFile);
    }
  }
  
  /// Example method to demonstrate the efficiency difference
  static void demonstrateEfficiency() {
    // Simulate JSON format (old way)
    const jsonExample = '''
    {
      "type": "FileSystem",
      "data": {
        "action": "list",
        "files": [
          {
            "name": "m0_43392_AM_270_LBNGKTc9.sub",
            "size": 915,
            "date": "315532854",
            "type": "file"
          }
        ]
      }
    }
    ''';
    
    // Simulate binary format (new way)
    final binaryExample = [
      0x01, 0x1F, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, // Header
      0x1A, // Name length
      // "m0_43392_AM_270_LBNGKTc9.sub" (26 bytes)
      0x6D, 0x30, 0x5F, 0x34, 0x33, 0x33, 0x39, 0x32, 0x5F,
      0x41, 0x4D, 0x5F, 0x32, 0x37, 0x30, 0x5F, 0x4C, 0x42,
      0x4E, 0x47, 0x4B, 0x54, 0x63, 0x39, 0x2E, 0x73, 0x75, 0x62,
      0x93, 0x03, 0x00, 0x00, // File size: 915 (little-endian)
      0xB6, 0x2C, 0x2D, 0x12, // File date: 315532854 (little-endian)
      0x01, // File type: Regular file
    ];
    
    print('Efficiency Demonstration:');
    print('JSON size: ${jsonExample.length} bytes');
    print('Binary size: ${binaryExample.length} bytes');
    print('Efficiency gain: ${((jsonExample.length - binaryExample.length) / jsonExample.length * 100).toStringAsFixed(1)}%');
  }
  
  /// Example method to test packet parsing
  static void testPacketParsing() {
    print('Testing packet parsing...');
    
    // Create a test packet
    final testPacket = Uint8List.fromList([
      0x01, 0x1F, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, // Header: Start, 31 bytes, 1 file
      0x1A, // Name length: 26
      // "m0_43392_AM_270_LBNGKTc9.sub"
      0x6D, 0x30, 0x5F, 0x34, 0x33, 0x33, 0x39, 0x32, 0x5F,
      0x41, 0x4D, 0x5F, 0x32, 0x37, 0x30, 0x5F, 0x4C, 0x42,
      0x4E, 0x47, 0x4B, 0x54, 0x63, 0x39, 0x2E, 0x73, 0x75, 0x62,
      0x93, 0x03, 0x00, 0x00, // File size: 915
      0xB6, 0x2C, 0x2D, 0x12, // File date: 315532854
      0x01, // File type: Regular file
    ]);
    
    final packet = BinaryFileParser.parsePacket(testPacket);
    if (packet != null) {
      print('Test packet parsed successfully:');
      print('  Type: ${packet.packetType} (${packet.isStart ? 'Start' : packet.isContinue ? 'Continue' : packet.isEnd ? 'End' : 'Unknown'})');
      print('  Size: ${packet.packetSize} bytes');
      print('  Files: ${packet.fileCount}');
      print('  File entries:');
      for (final file in packet.files) {
        print('    - ${file.name} (${file.size} bytes, ${file.isDirectory ? 'directory' : 'file'})');
      }
    } else {
      print('Failed to parse test packet');
    }
  }
}

/// Example usage in main function
void main() {
  print('=== Binary File List Integration Example ===');
  
  // Demonstrate efficiency
  BinaryFileIntegrationExample.demonstrateEfficiency();
  print('');
  
  // Test packet parsing
  BinaryFileIntegrationExample.testPacketParsing();
  print('');
  
  // Example request
  BinaryFileIntegrationExample.requestBinaryFileList('/');
  print('');
  
  print('=== End of Example ===');
}




















