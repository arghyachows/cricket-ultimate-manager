import 'package:flutter/material.dart';
import '../core/node_backend_service.dart';

class BackendTestScreen extends StatefulWidget {
  const BackendTestScreen({super.key});

  @override
  State<BackendTestScreen> createState() => _BackendTestScreenState();
}

class _BackendTestScreenState extends State<BackendTestScreen> {
  String _status = 'Not tested';
  bool _isHealthy = false;
  bool _isSocketConnected = false;

  @override
  void initState() {
    super.initState();
    _testBackend();
  }

  Future<void> _testBackend() async {
    setState(() {
      _status = 'Testing...';
    });

    // Test health check
    final healthy = await NodeBackendService.checkHealth();
    setState(() {
      _isHealthy = healthy;
      _status = healthy ? 'Backend is healthy ✅' : 'Backend health check failed ❌';
    });

    if (healthy) {
      // Test Socket.IO connection
      NodeBackendService.initSocket();
      await Future.delayed(const Duration(seconds: 2));
      setState(() {
        _status = 'Backend healthy ✅\nSocket.IO initialized';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Backend Test'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _isHealthy ? Icons.check_circle : Icons.error,
                size: 64,
                color: _isHealthy ? Colors.green : Colors.red,
              ),
              const SizedBox(height: 24),
              Text(
                _status,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _testBackend,
                child: const Text('Test Again'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    NodeBackendService.dispose();
    super.dispose();
  }
}
