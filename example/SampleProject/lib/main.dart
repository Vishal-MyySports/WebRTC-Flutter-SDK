import 'dart:async';
import 'dart:io';
import 'package:ant_media_flutter/ant_media_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'publish.dart';
import 'api_service.dart';

void main() => runApp(const MaterialApp(
      home: MyApp(),
      debugShowCheckedModeBanner: false,
    ));

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final String _server = "wss://ams-14471.antmedia.cloud:5443/live/websocket";
  bool _isConnecting = true;
  bool _isConnected = false;
  String _matchId = "";
  bool _isStartingStream = false;
  String? _streamId;
  String? _liveStreamUrl;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      AntMediaFlutter.requestPermissions();
      if (!kIsWeb && Platform.isAndroid) {
        await AntMediaFlutter.startForegroundService();
      }
      await _connectToServer();
    } catch (e) {
      _showErrorSnackbar("Initialization failed: ${e.toString()}");
      setState(() {
        _isConnecting = false;
        _isConnected = false;
      });
    }
  }

  Future<void> _connectToServer() async {
    setState(() => _isConnecting = true);

    try {
      // Simulating connection (replace with actual connection logic)
      await Future.delayed(const Duration(seconds: 3));
      setState(() {
        _isConnecting = false;
        _isConnected = true;
      });
    } catch (e) {
      setState(() {
        _isConnecting = false;
        _isConnected = false;
      });
      _showErrorSnackbar("Connection failed: ${e.toString()}");
    }
  }

  void _showMatchIdDialog() {
    final TextEditingController matchIdController = TextEditingController();
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Enter Match ID"),
          content: TextField(
            controller: matchIdController,
            decoration: const InputDecoration(
              hintText: "Match ID",
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () async {
                final matchId = matchIdController.text.trim();
                if (matchId.isEmpty) {
                  _showErrorSnackbar("Please enter a valid Match ID");
                  return;
                }

                Navigator.of(context).pop();
                await _startStreamingProcess(matchId);
              },
              child: const Text("Start Streaming"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _startStreamingProcess(String matchId) async {
    setState(() {
      _isStartingStream = true;
      _matchId = matchId;
    });

    try {
      final response = await ApiService.startStreaming(matchId);

      if (response['success'] == true) {
        _streamId = response['streamId'];
        _liveStreamUrl = response['liveStreamUrl'];

         await ApiService.updateMatchVideo(context, matchId, _liveStreamUrl!);

        _showSuccessSnackbar(response['message']);
        _navigateToPublish();
      } else {
        _showErrorSnackbar(response['message']);
      }
    } catch (e) {
      _showErrorSnackbar("Failed to start streaming: ${e.toString()}");
    } finally {
      setState(() => _isStartingStream = false);
    }
  }

  void _navigateToPublish() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (BuildContext context) => Publish(
          ip: _server,
          id: _matchId,
          streamId: _streamId!,
          liveStreamUrl: _liveStreamUrl!,
          userscreen: false,
        ),
      ),
    );
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: Colors.red,
      duration: const Duration(seconds: 3),
    ));
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: Colors.green,
      duration: const Duration(seconds: 3),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gullyball Live Streaming'),
        centerTitle: true,
      ),
      body: Center(
        child: _isStartingStream
            ? _buildLoadingIndicator("Starting stream...")
            : _isConnecting
                ? _buildLoadingIndicator("Connecting to server...")
                : _isConnected
                    ? ElevatedButton(
                        onPressed: _showMatchIdDialog,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 16,
                          ),
                        ),
                        child: const Text(
                          "Start Streaming",
                          style: TextStyle(fontSize: 18),
                        ),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            "Connection Failed",
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.red,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _connectToServer,
                            child: const Text("Retry Connection"),
                          ),
                        ],
                      ),
      ),
    );
  }

  Widget _buildLoadingIndicator(String message) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const CircularProgressIndicator(),
        const SizedBox(height: 16),
        Text(
          message,
          style: const TextStyle(fontSize: 16),
        ),
      ],
    );
  }
}
