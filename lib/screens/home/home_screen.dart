import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import '../../providers/app_provider.dart';
import '../../widgets/widgets.dart';
import '../settings/settings_screen.dart';
import '../player/player_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String searchQuery = '';
  String selectedCategory = 'All';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final appProvider = Provider.of<AppProvider>(context, listen: false);
      await appProvider.fetchData();
      _checkForUpdates(appProvider);
    });
  }

  Future<void> _refreshData() async {
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    await appProvider.fetchData();
  }

  Widget _buildShimmerLoading() {
    return ListView.builder(
      itemCount: 5,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          height: 140,
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor.withOpacity(0.5),
            borderRadius: BorderRadius.circular(16),
          ),
        );
      },
    );
  }

  Future<void> _checkForUpdates(AppProvider provider) async {
    try {
      if (provider.appConfig == null) {
        return;
      }

      final config = provider.appConfig!;
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      if (_isNewerVersion(currentVersion, config.latestVersion)) {
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: !config.forceUpdate,
            builder: (context) => UpdateDialog(
              latestVersion: config.latestVersion,
              forceUpdate: config.forceUpdate,
              updateUrl: config.updateUrl,
            ),
          );
        }
      }
    } catch (e) {
      // Silently ignore or handle update check errors
    }
  }

  bool _isNewerVersion(String current, String latest) {
    final currParts =
        current.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final latestParts =
        latest.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    for (var i = 0; i < 3; i++) {
      final curr = i < currParts.length ? currParts[i] : 0;
      final lat = i < latestParts.length ? latestParts[i] : 0;
      if (lat > curr) return true;
      if (lat < curr) return false;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final cardColor = Theme.of(context).cardColor;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.white54 : Colors.black54;

    final categories = [
      'All',
      ...appProvider.matches
          .map((m) => m.category)
          .toSet()
          .where((c) => c.isNotEmpty)
    ];

    // 1. Filter matches based on Search & Category only
    var filteredMatches = appProvider.matches.where((match) {
      final matchesSearch = match.team1Name
              .toLowerCase()
              .contains(searchQuery.toLowerCase()) ||
          match.team2Name.toLowerCase().contains(searchQuery.toLowerCase()) ||
          match.tournament.toLowerCase().contains(searchQuery.toLowerCase());
      final matchesCategory =
          selectedCategory == 'All' || match.category == selectedCategory;

      return matchesSearch && matchesCategory;
    }).toList();

    // 2. Sort matches: Live first, Upcoming second, Ended last
    filteredMatches.sort((a, b) {
      int getStatusWeight(String status) {
        final lowerStatus = status.toLowerCase();
        if (lowerStatus == 'live') return 0;
        if (lowerStatus == 'upcoming') return 1;
        return 2; // Ended or any other status
      }

      int weightA = getStatusWeight(a.status);
      int weightB = getStatusWeight(b.status);

      if (weightA != weightB) {
        return weightA.compareTo(weightB);
      }

      // If statuses are the same (e.g., both Live or both Upcoming), sort by Start Time
      return a.startTime.compareTo(b.startTime);
    });

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        title: const HelyLogo(fontSize: 24),
        actions: [
          IconButton(
            icon: Icon(Icons.settings, color: textColor),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => appProvider.fetchData(),
        color: const Color(0xFF2563EB),
        backgroundColor: cardColor,
        child: Column(
          children: [
            // Search Bar
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Container(
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    if (!isDark)
                      BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4)),
                  ],
                ),
                child: TextField(
                  style: TextStyle(color: textColor),
                  decoration: InputDecoration(
                    hintText: 'Search matches, teams...',
                    hintStyle: TextStyle(color: subTextColor),
                    prefixIcon: Icon(Icons.search, color: subTextColor),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                  ),
                  onChanged: (val) => setState(() => searchQuery = val),
                ),
              ),
            ),

            const SizedBox(height: 8),

            // Category Filter (Football, Cricket, etc.)
            if (categories.length > 1)
              Container(
                height: 50,
                margin: const EdgeInsets.only(bottom: 8.0),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final cat = categories[index];
                    final isSelected = selectedCategory == cat;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ChoiceChip(
                        label: Text(
                          cat,
                          style: TextStyle(
                            color: isSelected ? Colors.white : textColor,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        selected: isSelected,
                        selectedColor: const Color(0xFF2563EB),
                        backgroundColor: cardColor,
                        side: BorderSide(
                            color: isDark ? Colors.white12 : Colors.black12),
                        onSelected: (selected) {
                          if (selected) setState(() => selectedCategory = cat);
                        },
                      ),
                    );
                  },
                ),
              ),

            // Match List
            Expanded(
              child: appProvider.isLoading
                  ? const Center(
                      child:
                          CircularProgressIndicator(color: Color(0xFF2563EB)))
                  : filteredMatches.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.event_busy,
                                  color: subTextColor, size: 48),
                              const SizedBox(height: 16),
                              Text(
                                'No matches found',
                                style: TextStyle(
                                    color: subTextColor, fontSize: 16),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.only(bottom: 20),
                          itemCount: filteredMatches.length,
                          itemBuilder: (context, index) {
                            final match = filteredMatches[index];
                            return MatchCard(
                              match: match,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        PlayerScreen(match: match),
                                  ),
                                );
                              },
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class UpdateDialog extends StatefulWidget {
  final String latestVersion;
  final bool forceUpdate;
  final String updateUrl;

  const UpdateDialog({
    super.key,
    required this.latestVersion,
    required this.forceUpdate,
    required this.updateUrl,
  });

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  bool _isDownloading = false;
  double _progress = 0.0;
  String _statusText = '';

  Future<void> _downloadAndInstall() async {
    setState(() {
      _isDownloading = true;
      _progress = 0.0;
      _statusText = 'Preparing to download...';
    });

    try {
      final dir =
          await getExternalStorageDirectory() ?? await getTemporaryDirectory();
      final filePath = '${dir.path}/app_update.apk';
      final file = File(filePath);

      final request = http.Request('GET', Uri.parse(widget.updateUrl));
      final http.StreamedResponse response = await http.Client().send(request);
      final contentLength = response.contentLength ?? 0;

      final sink = file.openWrite();
      int downloadedBytes = 0;

      await response.stream.forEach((chunk) {
        sink.add(chunk);
        downloadedBytes += chunk.length;
        if (contentLength > 0 && mounted) {
          setState(() {
            _progress = downloadedBytes / contentLength;
            _statusText =
                'Downloading... ${(_progress * 100).toStringAsFixed(0)}%';
          });
        }
      });
      await sink.close();

      setState(() => _statusText = 'Installing...');
      final result = await OpenFilex.open(filePath);

      if (result.type != ResultType.done && mounted) {
        setState(() => _statusText = 'Failed to open file: ${result.message}');
      }
    } catch (e) {
      if (mounted) {
        setState(() =>
            _statusText = 'Download failed. Please check your connection.');
      }
    } finally {
      if (mounted && _statusText != 'Installing...') {
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) setState(() => _isDownloading = false);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !widget.forceUpdate && !_isDownloading,
      child: AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.system_update, color: Color(0xFF2563EB)),
            const SizedBox(width: 10),
            Text('Update Available',
                style: TextStyle(
                    color: Theme.of(context).textTheme.bodyLarge?.color)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'A new version of the app (${widget.latestVersion}) is available.\n\n'
              '${widget.forceUpdate ? 'You must update to continue using the app.' : 'Would you like to update now?'}',
              style: TextStyle(
                  color: Theme.of(context).textTheme.bodyMedium?.color),
            ),
            if (_isDownloading) ...[
              const SizedBox(height: 20),
              LinearProgressIndicator(
                value: _progress > 0 ? _progress : null,
                backgroundColor: Colors.grey.withOpacity(0.2),
                valueColor:
                    const AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  _statusText,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2563EB)),
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (!widget.forceUpdate && !_isDownloading)
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Later', style: TextStyle(color: Colors.grey)),
            ),
          if (!_isDownloading)
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: _downloadAndInstall,
              child: const Text('Update Now',
                  style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
    );
  }
}
