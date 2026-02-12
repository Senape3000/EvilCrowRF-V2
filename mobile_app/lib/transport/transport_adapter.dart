import 'transport_layer.dart';

// Adapter for integrating the transport layer with existing Flutter code
class TransportAdapter {
  ITransportLayer? _transport;
  Function(String)? _dataCallback;
  
  // Statistics
  int _totalCommands = 0;
  int _successfulCommands = 0;
  int _failedCommands = 0;
  
  // Initialization
  Future<bool> initialize(int transportType) async {
    print('Initializing transport adapter with type: $transportType');
    
    try {
      // Create transport layer
      _transport = TransportFactory.createTransport(transportType);
      
      // Initialize transport
      if (!await _transport!.initialize()) {
        print('Failed to initialize transport layer');
        _transport = null;
        return false;
      }
      
      // Set data receive callback
      _transport!.setDataReceivedCallback((String data) {
        _onDataReceived(data);
      });
      
      print('Transport adapter initialized successfully');
      return true;
      
    } catch (e) {
      print('Error initializing transport adapter: $e');
      _transport = null;
      return false;
    }
  }
  
  // Process commands
  Future<void> handleCommand(String command) async {
    if (_transport == null) {
      print('Transport not initialized');
      return;
    }
    
    _totalCommands++;
    print('Handling command: $command');
    
    try {
      // Send command
      bool success = await _transport!.sendData(command);
      
      if (success) {
        _successfulCommands++;
        print('Command sent successfully');
      } else {
        _failedCommands++;
        print('Failed to send command');
      }
      
    } catch (e) {
      _failedCommands++;
      print('Command processing failed: $e');
    }
  }
  
  // Get statistics
  Map<String, int> getStats() {
    Map<String, int> stats = {
      'totalCommands': _totalCommands,
      'successfulCommands': _successfulCommands,
      'failedCommands': _failedCommands,
    };
    
    // Add transport layer statistics
    if (_transport != null) {
      Map<String, int> transportStats = _transport!.getStats();
      stats.addAll(transportStats);
    }
    
    return stats;
  }
  
  // Check connection
  bool get isConnected => _transport?.isConnected ?? false;
  
  // Switch protocol
  Future<bool> switchProtocol(int newType) async {
    print('Switching protocol to type: $newType');
    
    if (_transport == null) {
      print('No transport to switch');
      return false;
    }
    
    try {
      // Save current state
      bool wasConnected = _transport!.isConnected;
      
      // Clean up old transport
      _transport!.dispose();
      _transport = null;
      
      // Create new transport
      _transport = TransportFactory.createTransport(newType);
      
      // Initialize new transport
      if (!await _transport!.initialize()) {
        print('Failed to initialize new transport');
        _transport = null;
        return false;
      }
      
      // Restore callback
      _transport!.setDataReceivedCallback((String data) {
        _onDataReceived(data);
      });
      
      print('Protocol switched successfully');
      return true;
      
    } catch (e) {
      print('Error switching protocol: $e');
      _transport = null;
      return false;
    }
  }
  
  // Process received data
  void _onDataReceived(String data) {
    print('Data received: ${data.length} bytes');
    print('Data content: $data');
    
    // Call callback if set
    if (_dataCallback != null) {
      _dataCallback!(data);
    }
  }
  
  // Set data receive callback
  void setDataReceivedCallback(Function(String) callback) {
    _dataCallback = callback;
  }
  
  // Clean up resources
  void dispose() {
    if (_transport != null) {
      _transport!.dispose();
      _transport = null;
    }
  }
}

// Global adapter instance
TransportAdapter? gTransportAdapter;
