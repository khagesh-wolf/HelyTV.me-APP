
class MatchModel {
  final String matchId;
  final String tournament;
  final String team1Name;
  final String team1Logo;
  final String team2Name;
  final String team2Logo;
  final DateTime startTime;
  final DateTime endTime;
  final String bgImage;
  final String category;

  MatchModel({
    required this.matchId,
    required this.tournament,
    required this.team1Name,
    required this.team1Logo,
    required this.team2Name,
    required this.team2Logo,
    required this.startTime,
    required this.endTime,
    required this.bgImage,
    required this.category,
  });

  factory MatchModel.fromJson(Map<String, dynamic> json) {
    String getVal(List<String> keys) {
      for (var key in keys) {
        if (json.containsKey(key) &&
            json[key] != null &&
            json[key].toString().trim().isNotEmpty) {
          return json[key].toString().trim();
        }
      }
      for (var k in json.keys) {
        String normalizedK =
            k.toLowerCase().replaceAll('_', '').replaceAll(' ', '');
        for (var key in keys) {
          String normalizedKey =
              key.toLowerCase().replaceAll('_', '').replaceAll(' ', '');
          if (normalizedK == normalizedKey && json[k] != null) {
            return json[k].toString().trim();
          }
        }
      }
      return '';
    }

    // Advanced fixDate function to prevent Ended matches showing as Upcoming
    // Google Sheets often outputs DD/MM/YYYY which flutter misreads.
    // This strictly maps DD/MM/YYYY to YYYY-MM-DD for accurate parsing.
    String fixDate(String date) {
      if (date.isEmpty) return '';
      String cleaned = date.replaceAll('/', '-').replaceFirst(' ', 'T');

      RegExp regExp = RegExp(r'^(\d{2})-(\d{2})-(\d{4})');
      if (regExp.hasMatch(cleaned)) {
        cleaned = cleaned.replaceAllMapped(regExp,
            (match) => '${match.group(3)}-${match.group(2)}-${match.group(1)}');
      }
      return cleaned;
    }

    String rawStart = getVal(['Start_Time', 'starttime']);
    String rawEnd = getVal(['End_Time', 'endtime']);

    String parsedMatchId = getVal(['Match_ID', 'match_id', 'matchid']);

    return MatchModel(
      matchId: parsedMatchId,
      tournament: getVal(['Tournament', 'tournament']),
      team1Name: getVal(['Team1_Name', 'team1name']),
      team1Logo: getVal(['Team1_Logo', 'team1logo']),
      team2Name: getVal(['Team2_Name', 'team2name']),
      team2Logo: getVal(['Team2_Logo', 'team2logo']),
      startTime:
          (DateTime.tryParse(fixDate(rawStart)) ?? DateTime.now()).toLocal(),
      endTime: (DateTime.tryParse(fixDate(rawEnd)) ??
              DateTime.now().add(const Duration(hours: 2)))
          .toLocal(),
      bgImage: getVal(['BG_Image', 'bgimage']),
      category: getVal(['Category', 'category']),
    );
  }

  // Refined Status Getter
  String get status {
    final now = DateTime.now();
    if (now.isAfter(endTime)) return 'Ended';
    if (now.isAfter(startTime) && now.isBefore(endTime)) return 'Live';
    return 'Upcoming';
  }
}

class StreamModel {
  final String id;
  final String matchId;
  final String url;
  final String type;
  final String kid;
  final String key;

  StreamModel({
    required this.id,
    required this.matchId,
    required this.url,
    required this.type,
    required this.kid,
    required this.key,
  });

  factory StreamModel.fromJson(Map<String, dynamic> json) {
    String getVal(List<String> keys) {
      for (var key in keys) {
        if (json.containsKey(key) &&
            json[key] != null &&
            json[key].toString().trim().isNotEmpty) {
          return json[key].toString().trim();
        }
      }
      for (var k in json.keys) {
        String normalizedK =
            k.toLowerCase().replaceAll('_', '').replaceAll(' ', '');
        for (var key in keys) {
          String normalizedKey =
              key.toLowerCase().replaceAll('_', '').replaceAll(' ', '');
          if (normalizedK == normalizedKey && json[k] != null) {
            return json[k].toString().trim();
          }
        }
      }
      return '';
    }

    return StreamModel(
      id: getVal(['id', 'ID', 'Id']),
      matchId: getVal(['Match_ID', 'match_id', 'matchid']),
      url: getVal(['url', 'link']),
      type: getVal(['type']),
      kid: getVal(['kid']),
      key: getVal(['key']),
    );
  }
}

class AppConfigModel {
  final String latestVersion;
  final bool forceUpdate;
  final String updateUrl;

  AppConfigModel({
    required this.latestVersion,
    required this.forceUpdate,
    required this.updateUrl,
  });

  factory AppConfigModel.fromJson(Map<String, dynamic> json) {
    return AppConfigModel(
      latestVersion: json['latest_version']?.toString() ?? '1.0.0',
      forceUpdate: json['force_update']?.toString().toLowerCase() == 'true',
      updateUrl: json['update_url']?.toString() ?? '',
    );
  }
}
