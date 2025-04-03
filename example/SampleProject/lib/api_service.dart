import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ApiService {
  static const String _baseUrl = 'http://52.66.105.166:8000';
  static const String _antMediaPlayUrl = 'https://ams-14471.antmedia.cloud:5443/live/play.html?id=';

  static Future<Map<String, dynamic>> startStreaming(String matchId) async {
    try {
      final uri = Uri.parse('$_baseUrl/start_ant_streaming?match_id=$matchId');
      final request = http.Request('POST', uri);

      final response = await request.send().timeout(const Duration(seconds: 30));
      final responseBody = await response.stream.bytesToString();

      final jsonResponse = json.decode(responseBody);

      if (response.statusCode == 200) {
        final streamId = jsonResponse['dataId'] ?? jsonResponse['streamId'];
        print("streamId xxxxxxxxxxxxx- = $streamId");
        final liveStreamUrl = '$_antMediaPlayUrl$streamId';

        if (jsonResponse['status'] == 'already_monitoring') {
          return {'success': true, 'data': jsonResponse, 'streamId': streamId, 'liveStreamUrl': liveStreamUrl, 'message': 'Stream is already running'};
        }
        return {'success': true, 'data': jsonResponse, 'streamId': streamId, 'liveStreamUrl': liveStreamUrl, 'message': 'Stream started successfully'};
      } else {
        return {'success': false, 'message': 'Failed to start stream: ${response.reasonPhrase}'};
      }
    } on TimeoutException {
      return {'success': false, 'message': 'Request timed out. Please try again.'};
    } catch (e) {
      return {'success': false, 'message': 'An error occurred: ${e.toString()}'};
    }
  }

  static Future<Map<String, dynamic>> stopStreaming(String streamId) async {
    try {
      final uri = Uri.parse('$_baseUrl/stop_ant_streaming/$streamId');
      final request = http.Request('POST', uri);
      request.headers['Content-Type'] = 'application/json';

      final response = await request.send().timeout(const Duration(seconds: 30));
      final responseBody = await response.stream.bytesToString();
      final jsonResponse = json.decode(responseBody);

      if (response.statusCode == 200) {
        if (jsonResponse['detail'] == 'Match monitoring not found') {
          return {'success': true, 'message': 'Stream was already stopped'};
        }
        return {'success': true, 'message': 'Stream stopped successfully', 'data': jsonResponse};
      } else {
        return {'success': false, 'message': 'Failed to stop stream: ${response.reasonPhrase}'};
      }
    } on TimeoutException {
      return {'success': false, 'message': 'Request timed out. Please try again.'};
    } catch (e) {
      return {'success': false, 'message': 'An error occurred: ${e.toString()}'};
    }
  }

  static Future<void> updateMatchVideo(BuildContext context, String matchId, String liveStreamUrl) async {
    print("matchId = $matchId");
    print("liveStreamUrl = $liveStreamUrl");
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return WillPopScope(
            onWillPop: () async => false,
            child: const Center(
              child: CircularProgressIndicator(
                color: Colors.red,
              ),
            ),
          );
        },
      );

      var headers = {'Content-Type': 'application/json'};

      var request = http.Request('PATCH', Uri.parse('https://api.gullyball.com/api/v0/cricket/update/match/liveurl/$matchId'));

      request.body = json.encode({"liveUrl": liveStreamUrl});

      request.headers.addAll(headers);

      http.StreamedResponse response = await request.send();

      print("Live Stream Url update status code = ${response.statusCode}");
      if (response.statusCode == 200) {
        final responseBody = await response.stream.bytesToString();
        print('API call successful');
        print(responseBody);
        Navigator.pop(context);
        _showCustomSnackbar(context, 'LIVE STREAM URL UPDATED', Colors.green);
      } else {
        final responseBody = await response.stream.bytesToString();
        print(responseBody);
        Navigator.pop(context);
        final data = jsonDecode(responseBody);
        _showCustomSnackbar(context, "${data["error"] ?? response.reasonPhrase}".toUpperCase(), Colors.red);
        print('API call failed with status: ${response.statusCode}');
      }
    } catch (e) {
      Navigator.pop(context);
      print('API call failed: $e');
      _showCustomSnackbar(context, 'Failed to update stream URL', Colors.red);
    }
  }

  static void _showCustomSnackbar(BuildContext context, String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
      ),
    );
  }
}
