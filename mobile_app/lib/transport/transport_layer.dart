// Abstract interface for the Flutter transport layer
abstract class ITransportLayer {
  // Initialize transport layer
  Future<bool> initialize();
  
  // Send data
  Future<bool> sendData(String data);
  
  // Send binary data
  Future<bool> sendBinaryData(List<int> data);
  
  // Set data receive callback
  void setDataReceivedCallback(Function(String) callback);
  
  // Check connection
  bool get isConnected;
  
  // Get statistics
  Map<String, int> getStats();
  
  // Clean up resources
  void dispose();
}

// Concrete implementation for BLE with Binary Protocol
class BLEBinaryTransport implements ITransportLayer {
  late Function(String) _dataCallback;
  final bool _isConnected = false;
  
  // Statistics
  int _packetsSent = 0;
  int _packetsReceived = 0;
  int _errors = 0;
  
  // Buffers for data assembly
  final Map<int, ChunkBuffer> _chunkBuffers = {};
  
  // Packet structure
  static const int PACKET_HEADER_SIZE = 7; // Updated: dataLen is now 2 bytes
  static const int MAX_DATA_SIZE = 500; // Updated for Bluetooth 5.0
  
  @override
  Future<bool> initialize() async {
    print('Initializing BLE Binary Transport');
    // BLE initialization goes here
    return true;
  }
  
  @override
  Future<bool> sendData(String data) async {
    if (!_isConnected) {
      print('Not connected, cannot send data');
      return false;
    }
    
    print('Sending data: ${data.length} bytes');
    
    // Split data into small packets
    int totalChunks = (data.length + MAX_DATA_SIZE - 1) ~/ MAX_DATA_SIZE;
    int chunkId = DateTime.now().millisecondsSinceEpoch & 0xFF;
    
    for (int i = 0; i < totalChunks; i++) {
      int chunkNum = i + 1;
      
      // Create packet
      List<int> packet = _createPacket(
        type: 0x01, // data
        chunkId: chunkId,
        chunkNum: chunkNum,
        totalChunks: totalChunks,
        data: data.substring(i * MAX_DATA_SIZE, 
              (i + 1) * MAX_DATA_SIZE > data.length ? data.length : (i + 1) * MAX_DATA_SIZE),
      );
      
      // Send packet
      if (!await _sendPacket(packet)) {
        print('Failed to send packet $chunkNum');
        _errors++;
        return false;
      }
      
      // Wait for acknowledgment
      if (!await _waitForACK(chunkId, chunkNum, 1000)) {
        print('No ACK for packet $chunkNum, retrying');
        // Retry sending
        if (!await _sendPacket(packet)) {
          print('Retry failed for packet $chunkNum');
          _errors++;
          return false;
        }
      }
      
      _packetsSent++;
      
      // Short pause
      await Future.delayed(const Duration(milliseconds: 5));
    }
    
    print('Data sent successfully: $totalChunks chunks');
    return true;
  }
  
  @override
  Future<bool> sendBinaryData(List<int> data) async {
    // Convert to String for unification
    String dataStr = String.fromCharCodes(data);
    return await sendData(dataStr);
  }
  
  @override
  void setDataReceivedCallback(Function(String) callback) {
    _dataCallback = callback;
  }
  
  @override
  bool get isConnected => _isConnected;
  
  @override
  Map<String, int> getStats() {
    return {
      'packetsSent': _packetsSent,
      'packetsReceived': _packetsReceived,
      'errors': _errors,
    };
  }
  
  @override
  void dispose() {
    _chunkBuffers.clear();
  }
  
  // Create packet
  List<int> _createPacket({
    required int type,
    required int chunkId,
    required int chunkNum,
    required int totalChunks,
    required String data,
  }) {
    List<int> packet = List.filled(PACKET_HEADER_SIZE + data.length, 0);
    
    packet[0] = 0xAA; // magic
    packet[1] = type;
    packet[2] = chunkId;
    packet[3] = chunkNum;
    packet[4] = totalChunks;
    packet[5] = data.length & 0xFF;        // Data length (low byte)
    packet[6] = (data.length >> 8) & 0xFF; // Data length (high byte)
    
    // Copy data
    for (int i = 0; i < data.length; i++) {
      packet[7 + i] = data.codeUnitAt(i);  // Data starts at offset 7
    }
    
    // Calculate checksum
    packet[7 + data.length] = _calculateChecksum(packet, data.length);
    
    return packet;
  }
  
  // Calculate checksum
  int _calculateChecksum(List<int> packet, int dataLength) {
    int checksum = packet[0] ^ packet[1] ^ packet[2] ^ packet[3] ^ packet[4] ^ packet[5] ^ packet[6];
    
    for (int i = 0; i < dataLength; i++) {
      checksum ^= packet[7 + i];
    }
    
    return checksum;
  }
  
  // Send packet
  Future<bool> _sendPacket(List<int> packet) async {
    // Actual BLE send will go here
    print('Sending packet: ${packet.length} bytes');
    return true;
  }
  
  // Wait for acknowledgment
  Future<bool> _waitForACK(int chunkId, int chunkNum, int timeoutMs) async {
    // Simplified implementation - always returns true
    // Full implementation will check received ACKs here
    await Future.delayed(Duration(milliseconds: timeoutMs));
    return true;
  }
  
  // Process received packet
  void _processReceivedPacket(List<int> packet) {
    if (packet.length < PACKET_HEADER_SIZE) {
      print('Invalid packet size: ${packet.length}');
      _errors++;
      return;
    }
    
    if (packet[0] != 0xAA) {
      print('Invalid packet magic: 0x${packet[0].toRadixString(16)}');
      _errors++;
      return;
    }
    
    int type = packet[1];
    int chunkId = packet[2];
    int chunkNum = packet[3];
    int totalChunks = packet[4];
    int dataLength = packet[5] | (packet[6] << 8);  // Little-endian: 2 bytes
    
    // Verify checksum
    int calculatedChecksum = _calculateChecksum(packet, dataLength);
    if (packet[7 + dataLength] != calculatedChecksum) {
      print('Checksum mismatch for packet $chunkNum');
      _errors++;
      return;
    }
    
    _packetsReceived++;
    
    if (type == 0x01) { // data packet
      // Process data
      if (!_chunkBuffers.containsKey(chunkId)) {
        _chunkBuffers[chunkId] = ChunkBuffer(
          totalChunks: totalChunks,
          receivedChunks: 0,
          timestamp: DateTime.now(),
        );
      }
      
      ChunkBuffer buffer = _chunkBuffers[chunkId]!;
      
      // Add data
      String chunkData = String.fromCharCodes(packet.sublist(7, 7 + dataLength));
      buffer.data += chunkData;
      buffer.receivedChunks++;
      
      // Check if all chunks received
      if (buffer.receivedChunks >= buffer.totalChunks) {
        // Call callback with complete data
        _dataCallback(buffer.data);
              
        // Remove buffer
        _chunkBuffers.remove(chunkId);
      }
      
      // Send ACK
      _sendACK(chunkId, chunkNum);
      
    } else if (type == 0x02) { // ACK
      print('Received ACK for chunk $chunkNum');
    } else if (type == 0x03) { // NAK
      print('Received NAK for chunk $chunkNum');
    }
    
    // Clear old buffers
    _cleanupOldChunks();
  }
  
  // Send ACK
  Future<void> _sendACK(int chunkId, int chunkNum) async {
    List<int> ackPacket = _createPacket(
      type: 0x02, // ACK
      chunkId: chunkId,
      chunkNum: chunkNum,
      totalChunks: 0,
      data: '',
    );
    
    await _sendPacket(ackPacket);
  }
  
  // Clear old buffers
  void _cleanupOldChunks() {
    DateTime now = DateTime.now();
    _chunkBuffers.removeWhere((key, buffer) {
      return now.difference(buffer.timestamp).inSeconds > 30;
    });
  }
}

// Buffer for chunk assembly
class ChunkBuffer {
  String data = '';
  int totalChunks;
  int receivedChunks;
  DateTime timestamp;
  
  ChunkBuffer({
    required this.totalChunks,
    required this.receivedChunks,
    required this.timestamp,
  });
}

// Factory for creating transport layers
class TransportFactory {
  static const int BLE_JSON = 0;
  static const int BLE_BINARY = 1;
  static const int BLE_FAST = 2;
  
  static ITransportLayer createTransport(int type) {
    switch (type) {
      case BLE_BINARY:
        return BLEBinaryTransport();
      case BLE_JSON:
        // TODO: Implement JSON transport
        throw UnimplementedError('JSON transport not implemented');
      case BLE_FAST:
        // TODO: Implement fast transport
        throw UnimplementedError('Fast transport not implemented');
      default:
        throw ArgumentError('Unknown transport type: $type');
    }
  }
}
