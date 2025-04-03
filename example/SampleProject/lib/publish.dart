import 'dart:core';
import 'package:ant_media_flutter/ant_media_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'api_service.dart';

class Publish extends StatefulWidget {
  static String tag = 'call';

  final String ip;
  final String id;
  final String streamId;
  final String liveStreamUrl;
  final bool userscreen;
  final List<Map<String, String>> iceServers = [
    {'url': 'stun:stun.l.google.com:19302'},
  ];

  Publish({
    Key? key,
    required this.ip,
    required this.id,
    required this.streamId,
    required this.liveStreamUrl,
    required this.userscreen,
  }) : super(key: key);

  @override
  _PublishState createState() => _PublishState();
}

class _PublishState extends State<Publish> {
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  bool _inCalling = false;
  bool _micOn = true;
  double _zoomLevel = 1.0;
  double _minZoomLevel = 1.0;
  double _maxZoomLevel = 10.0;
  double _zoomStep = 0.5;
  bool _zoomSupported = true;
  bool _isLoading = true;
  bool _isStopping = false;
  String? _streamId;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await initRenderers();
      await _connect();
      await Future.delayed(const Duration(seconds: 2));
      await publish();
      setState(() => _isLoading = false);
    } catch (e) {
      _showErrorSnackbar("Initialization failed: ${e.toString()}");
      Navigator.of(context).pop();
    }
  }

  Future<void> publish() async {
    try {
      // Here you would typically get the stream ID from the publish response
      // For now, we're simulating it with the match ID
      _streamId = "vaSNaAN8NNkm${DateTime.now().millisecondsSinceEpoch}";
      AntMediaFlutter.anthelper?.publish(widget.id, "", "", "", widget.id, "", "");
    } catch (e) {
      _showErrorSnackbar("Publish failed: ${e.toString()}");
      throw e;
    }
  }

  Future<void> initRenderers() async {
    try {
      await _localRenderer.initialize();
      await _remoteRenderer.initialize();
    } catch (e) {
      _showErrorSnackbar("Renderer initialization failed: ${e.toString()}");
      throw e;
    }
  }

  @override
  void deactivate() {
    if (AntMediaFlutter.anthelper != null) {
      AntMediaFlutter.anthelper?.close();
    }
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    super.deactivate();
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    // Then call the API to stop the stream using the streamId from widget
    ApiService.stopStreaming(widget.id);
    super.dispose();
  }

  Future<void> _connect() async {
    try {
      AntMediaFlutter.prepare(
        widget.ip,
        widget.id,
        '',
        '',
        AntMediaType.Publish,
        widget.userscreen,
        (HelperState state) {
          switch (state) {
            case HelperState.CallStateNew:
              setState(() => _inCalling = true);
              break;
            case HelperState.CallStateBye:
              setState(() {
                _localRenderer.srcObject = null;
                _remoteRenderer.srcObject = null;
                _inCalling = false;
              });
              break;
            default:
              break;
          }
        },
        (stream) => setState(() => _remoteRenderer.srcObject = stream),
        (stream) => setState(() => _remoteRenderer.srcObject = stream),
        (datachannel) {},
        (channel, message, isReceived) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
              (isReceived ? "Received:" : "Sent:") + " " + message.text,
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.blue,
          ));
        },
        (streams) {},
        (stream) => setState(() => _remoteRenderer.srcObject = null),
        widget.iceServers,
        (command, mapData) {},
      );

      // Ensure back camera is used initially
      if (!widget.userscreen) {
        await Future.delayed(Duration(milliseconds: 500));
        await AntMediaFlutter.anthelper?.switchCamera();
      }
    } catch (e) {
      _showErrorSnackbar("Connection failed: ${e.toString()}");
      throw e;
    }
  }

  Future<void> _stopStreaming() async {
    setState(() => _isStopping = true);

    try {
      // First stop the Ant Media client
      await _hangUp();

      // Then call the API to stop the stream using the streamId from widget
      final response = await ApiService.stopStreaming(widget.id);

      if (response['success'] == true) {
        _showSuccessSnackbar(response['message']);
        if (mounted) {
          Navigator.of(context).pop();
        }
      } else {
        _showErrorSnackbar(response['message']);
      }
    } catch (e) {
      _showErrorSnackbar("Failed to stop streaming: ${e.toString()}");
    } finally {
      if (mounted) {
        setState(() => _isStopping = false);
      }
    }
  }

  Future<void> _hangUp() async {
    try {
      AntMediaFlutter.anthelper?.bye();
    } catch (e) {
      _showErrorSnackbar("Hangup failed: ${e.toString()}");
      throw e;
    }
  }

  Future<void> _switchCamera() async {
    try {
      await AntMediaFlutter.anthelper?.switchCamera();
      setState(() => _zoomLevel = 1.0);
      await _zoomCamera(1.0);
    } catch (e) {
      _showErrorSnackbar("Camera switch failed: ${e.toString()}");
    }
  }

  Future<void> _zoomCamera(double zoomLevel) async {
    try {
      await AntMediaFlutter.anthelper?.zoomCamera(zoomLevel);
    } catch (e) {
      _showErrorSnackbar("Zoom operation failed: ${e.toString()}");
    }
  }

  Future<void> _increaseZoom() async {
    if (!_zoomSupported) return;

    final newZoom = (_zoomLevel + _zoomStep).clamp(_minZoomLevel, _maxZoomLevel);
    if (newZoom != _zoomLevel) {
      await _zoomCamera(newZoom);
      setState(() => _zoomLevel = newZoom);
    }
  }

  Future<void> _decreaseZoom() async {
    if (!_zoomSupported) return;

    final newZoom = (_zoomLevel - _zoomStep).clamp(_minZoomLevel, _maxZoomLevel);
    if (newZoom != _zoomLevel) {
      await _zoomCamera(newZoom);
      setState(() => _zoomLevel = newZoom);
    }
  }

  void _muteMic(bool state) {
    try {
      AntMediaFlutter.anthelper?.muteMic(!_micOn);
      setState(() => _micOn = !_micOn);
    } catch (e) {
      _showErrorSnackbar("Mic toggle failed: ${e.toString()}");
    }
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

  Widget _buildActionButton(IconData icon, VoidCallback onPressed, {Color? color, String? tooltip}) {
    return FloatingActionButton(
      heroTag: icon.codePoint.toString(),
      tooltip: tooltip,
      backgroundColor: color,
      onPressed: onPressed,
      child: Icon(icon),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Force landscape orientation
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Streaming'),
        actions: [
          if (_isStopping)
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.onPrimary),
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _inCalling && !_isStopping
          ? SizedBox(
              width: MediaQuery.of(context).size.width * 0.95,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  if (!widget.userscreen)
                    _buildActionButton(
                      Icons.switch_camera,
                      _switchCamera,
                      tooltip: 'Switch Camera',
                    ),
                  if (_zoomSupported)
                    _buildActionButton(
                      Icons.zoom_in,
                      _increaseZoom,
                      tooltip: 'Zoom In',
                    ),
                  if (_zoomSupported)
                    _buildActionButton(
                      Icons.zoom_out,
                      _decreaseZoom,
                      tooltip: 'Zoom Out',
                    ),
                  _buildActionButton(
                    Icons.stop,
                    _stopStreaming,
                    color: Colors.red,
                    tooltip: 'Stop Streaming',
                  ),
                  if (!widget.userscreen)
                    _buildActionButton(
                      _micOn ? Icons.mic : Icons.mic_off,
                      () => _muteMic(_micOn),
                      tooltip: _micOn ? 'Mute Mic' : 'Unmute Mic',
                    ),
                ],
              ),
            )
          : null,
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              color: Colors.black,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : widget.userscreen
                      ? const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 16),
                              Text(
                                'Screen is sharing',
                                style: TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        )
                      : RTCVideoView(
                          _remoteRenderer,
                          objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                        ),
            ),
          ),
          if (_inCalling && _zoomSupported && !widget.userscreen)
            Positioned(
              bottom: 100,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Zoom: ${_zoomLevel.toStringAsFixed(1)}x',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
