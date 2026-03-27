import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../providers/theme_provider.dart';
import '../../services/security_service.dart';
import '../../widgets/widgets.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool isPremium = false;
  String remainingTime = '';
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _loadPremiumStatus();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadPremiumStatus() async {
    isPremium = await SecurityService.isPremiumUnlocked();
    DateTime? expiry = await SecurityService.getPremiumExpiryDate();

    _timer?.cancel(); // Cancel any existing timer before starting a new one

    if (isPremium && expiry != null) {
      _updateTimer(expiry);
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        _updateTimer(expiry);
      });
    }
    setState(() {});
  }

  void _updateTimer(DateTime expiry) {
    final now = DateTime.now();
    if (now.isAfter(expiry)) {
      _timer?.cancel();
      if (mounted) {
        setState(() {
          isPremium = false;
          remainingTime = 'Expired';
        });
      }
    } else {
      final diff = expiry.difference(now);
      final hours = diff.inHours.toString().padLeft(2, '0');
      final minutes = (diff.inMinutes % 60).toString().padLeft(2, '0');
      final seconds = (diff.inSeconds % 60).toString().padLeft(2, '0');
      if (mounted) {
        setState(() {
          remainingTime = '$hours:$minutes:$seconds remaining';
        });
      }
    }
  }

  Future<void> _unlockPremium() async {
    // Launch Monetag Direct Link Ad in External Browser
    final adUrl = Uri.parse('https://omg10.com/4/10731338');
    try {
      await launchUrl(adUrl, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Could not launch ad: $e');
    }

    // Unlock Premium instantly after clicking the ad
    await SecurityService.unlockPremium();
    _loadPremiumStatus(); // Re-fetch status and restart timer
  }

  Future<void> _launchTelegram() async {
    final url = Uri.parse('https://t.me/+XqQDaUKfZDhjOTc1');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open Telegram')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        iconTheme: IconThemeData(color: textColor),
        title: Text('Settings',
            style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Theme Toggle
          Card(
            color: Theme.of(context).cardColor,
            elevation: 0,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: SwitchListTile(
              activeThumbColor: const Color(0xFF2563EB),
              title: Text('Dark Mode',
                  style:
                      TextStyle(color: textColor, fontWeight: FontWeight.bold)),
              subtitle: Text('Toggle light and dark theme',
                  style: TextStyle(
                      color: isDark ? Colors.grey : Colors.grey[700],
                      fontSize: 12)),
              value: isDark,
              onChanged: (value) {
                themeProvider.toggleTheme(value);
              },
            ),
          ),
          const SizedBox(height: 16),

          // Clear Cache
          Card(
            color: Theme.of(context).cardColor,
            elevation: 0,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              onTap: () async {
                await WebViewController().clearCache();
                await WebViewController().clearLocalStorage();
                PaintingBinding.instance.imageCache.clear();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('App cache cleared successfully!')),
                  );
                }
              },
              leading:
                  const Icon(Icons.cleaning_services, color: Color(0xFF2563EB)),
              title: Text('Clear Cache',
                  style:
                      TextStyle(color: textColor, fontWeight: FontWeight.bold)),
              subtitle: Text('Free up storage and fix loading issues',
                  style: TextStyle(
                      color: isDark ? Colors.grey : Colors.grey[700],
                      fontSize: 12)),
            ),
          ),
          const SizedBox(height: 16),

          // Premium Status
          Card(
            color: Theme.of(context).cardColor,
            elevation: 0,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              onTap: isPremium ? null : _unlockPremium,
              leading: const Icon(Icons.star, color: Color(0xFF2563EB)),
              title: Text('Premium Status',
                  style:
                      TextStyle(color: textColor, fontWeight: FontWeight.bold)),
              subtitle: Text(
                isPremium
                    ? 'Active ($remainingTime)'
                    : 'Inactive - Tap to watch an ad and unlock',
                style: TextStyle(
                  color: isPremium
                      ? const Color(0xFF2563EB)
                      : (isDark ? Colors.grey : Colors.grey[700]),
                  fontWeight: isPremium ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              trailing: isPremium
                  ? null
                  : Icon(Icons.play_circle_outline,
                      color: isDark ? Colors.grey : Colors.grey[700]),
            ),
          ),
          const SizedBox(height: 16),

          // Telegram
          Card(
            color: Theme.of(context).cardColor,
            elevation: 0,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              onTap: _launchTelegram,
              leading: const Icon(Icons.telegram, color: Color(0xFF2563EB)),
              title: Text('Telegram Updates',
                  style:
                      TextStyle(color: textColor, fontWeight: FontWeight.bold)),
              subtitle: Text('Join our channel for updates',
                  style: TextStyle(
                      color: isDark ? Colors.grey : Colors.grey[700],
                      fontSize: 12)),
              trailing: Icon(Icons.open_in_new,
                  color: isDark ? Colors.grey : Colors.grey[700], size: 16),
            ),
          ),
          const SizedBox(height: 16),

          // About
          Card(
            color: Theme.of(context).cardColor,
            elevation: 0,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('About',
                      style: TextStyle(
                          color: textColor,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const HelyLogo(fontSize: 24),
                  const SizedBox(height: 4),
                  Text('Football and Cricket Streaming',
                      style: TextStyle(
                          color: isDark ? Colors.grey : Colors.grey[700])),
                  const SizedBox(height: 16),
                  Text('Version 1.0.0',
                      style: TextStyle(
                          color: isDark ? Colors.white54 : Colors.black54,
                          fontSize: 12)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
