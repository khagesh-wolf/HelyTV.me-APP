import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/models.dart';

class AppProvider with ChangeNotifier {
  List<MatchModel> matches = [];
  List<StreamModel> streams = [];
  AppConfigModel? appConfig;
  bool isLoading = true;

  final String _matchesUrl =
      'https://opensheet.elk.sh/1RthMctHFdKX7yEznC25Va8weBKwjchXCvXS4f4QCl6U/Matches';
  final String _streamsUrl =
      'https://opensheet.elk.sh/1RthMctHFdKX7yEznC25Va8weBKwjchXCvXS4f4QCl6U/Streams';
  final String _configUrl =
      'https://opensheet.elk.sh/1RthMctHFdKX7yEznC25Va8weBKwjchXCvXS4f4QCl6U/Config';

  Future<void> fetchData() async {
    isLoading = true;
    notifyListeners();

    try {
      final responses = await Future.wait([
        http.get(Uri.parse(_matchesUrl)),
        http.get(Uri.parse(_streamsUrl)),
        http.get(Uri.parse(_configUrl)),
      ]);

      if (responses[0].statusCode == 200 && responses[1].statusCode == 200) {
        final List matchesJson = json.decode(responses[0].body);
        final List streamsJson = json.decode(responses[1].body);

        matches = matchesJson.map((m) => MatchModel.fromJson(m)).toList();
        streams = streamsJson.map((s) => StreamModel.fromJson(s)).toList();
      }

      // SAFELY PARSE CONFIG
      if (responses[2].statusCode == 200) {
        try {
          final decodedConfig = json.decode(responses[2].body);

          // Check if it's actually a list (OpenSheet returns lists for valid sheets)
          if (decodedConfig is List && decodedConfig.isNotEmpty) {
            appConfig = AppConfigModel.fromJson(decodedConfig.first);
          }
        } catch (e) {
          // Silently handle config parsing errors
        }
      }
    } catch (e) {
      // Silently handle API fetch errors
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  List<StreamModel> getStreamsForMatch(String targetMatchId) {
    // Clean the target ID we are looking for (just in case)
    final cleanTargetId = targetMatchId.toLowerCase().trim();

    final foundStreams = streams.where((s) {
      // 1. Split the Google Sheet 'matchId' cell by commas
      // 2. Trim any extra spaces around the IDs (e.g., "id1, id2" -> "id1", "id2")
      // 3. Convert them all to lowercase to ensure a perfect match
      final assignedMatchIds = s.matchId
          .split(',')
          .map((id) => id.toLowerCase().trim())
          .toList();

      // 4. Return true if this stream's list of IDs contains our target match ID
      return assignedMatchIds.contains(cleanTargetId);
    }).toList();

    return foundStreams;
  }
}