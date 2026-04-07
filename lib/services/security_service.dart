import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:installed_apps/installed_apps.dart';

class SecurityService {
  static const String _premiumExpiryKey = 'premium_expiry';

  // ==========================================
  // Premium Status Logic
  // ==========================================

  static Future<bool> isPremiumUnlocked() async {
    final prefs = await SharedPreferences.getInstance();
    final expiryString = prefs.getString(_premiumExpiryKey);
    if (expiryString == null) return false;

    final expiryDate = DateTime.parse(expiryString);
    return DateTime.now().isBefore(expiryDate);
  }

  static Future<void> unlockPremium(
      {Duration duration = const Duration(hours: 4)}) async {
    final prefs = await SharedPreferences.getInstance();
    final expiryDate = DateTime.now().add(duration);
    await prefs.setString(_premiumExpiryKey, expiryDate.toIso8601String());
  }

  static Future<DateTime?> getPremiumExpiryDate() async {
    final prefs = await SharedPreferences.getInstance();
    final expiryString = prefs.getString(_premiumExpiryKey);
    if (expiryString == null) return null;
    return DateTime.parse(expiryString);
  }

  // ==========================================
  // HARDENED VPN, Proxy, and Sniffer Detection
  // ==========================================

  // Expanded list including common "modded" versions and specific tools
  static const List<String> _blacklistedApps = [
    'com.guoshi.httpcanary',
    'com.guoshi.httpcanary.premium',
    'app.greyshirts.sslcapture',
    'com.minhui.networkcapture',
    'com.minhui.networkcapture.pro',
    'com.emanuelef.remote_capture',
    'com.hsc.http.injector',
    'com.evilsocket.zanti',
    'com.sniff.pcap',
    'com.pk.packetsniffer',
    'org.sandrob.vpnhotspot',
    'com.wireguard.android',
    'com.adguard.android', // Often used for DNS filtering/sniffing
    'it.evilsocket.dsploit',
  ];

  /// Checks if malicious sniffer apps are installed
  static Future<bool> hasSnifferAppsInstalled() async {
    if (!Platform.isAndroid) return false;

    try {
      // 1. Check by Package Name
      for (String packageName in _blacklistedApps) {
        bool isInstalled =
            await InstalledApps.isAppInstalled(packageName) ?? false;
        if (isInstalled) return true;
      }

      // 2. Check by Name Keywords (Brute force for renamed apps)
      final allApps = await InstalledApps.getInstalledApps();
      for (var app in allApps) {
        String name = (app.name ?? "").toLowerCase();
        if (name.contains("canary") ||
            name.contains("packet capture") ||
            name.contains("sniffer") ||
            name.contains("http capture")) {
          return true;
        }
      }
    } catch (e) {
      debugPrint("App scan error: $e");
    }
    return false;
  }

  /// Checks for active VPN via network interface scanning
  static Future<bool> isVpnActive() async {
    try {
      List<NetworkInterface> interfaces = await NetworkInterface.list(
          includeLoopback: false, type: InternetAddressType.any);

      for (NetworkInterface interface in interfaces) {
        String name = interface.name.toLowerCase();
        // Modern Android VPNs often use 'tun', 'arc', or 'p2p'
        if (name.contains("tun") ||
            name.contains("tap") ||
            name.contains("ppp") ||
            name.contains("ipsec") ||
            name.contains("arc0")) {
          return true;
        }
      }
    } on SocketException catch (_) {}
    return false;
  }

  /// ADVANCED: Detects Private DNS, Proxy, and SSL Interception
  static Future<bool> isNetworkCompromised() async {
    // 1. Check for basic Proxy Env
    final env = Platform.environment;
    if (env.containsKey('http_proxy') || env.containsKey('https_proxy')) {
      return true;
    }

    // 2. Detect Private DNS / SSL Sniffing via actual request
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 3);
      final request = await client
          .getUrl(Uri.parse('https://dns.google/resolve?name=google.com'));
      final response = await request.close();

      // Check if we are being redirected to a capture portal
      if (response.statusCode != 200) return true;
    } on HandshakeException catch (e) {
      // This is the #1 trigger for HttpCanary/Charles/Fiddler
      debugPrint("SSL Handshake Failed: Likely Sniffer/MITM detected: $e");
      return true;
    } on SocketException catch (e) {
      // If DNS is blocked or redirected incorrectly
      if (e.message.contains("Failed host lookup")) {
        debugPrint("DNS Lookup failure: Potential DNS filter active");
        return true;
      }
    } catch (e) {
      // Generic catch for weird network behaviors
    }

    return false;
  }

  /// Runs the full security suite
  static Future<String?> checkNetworkSecurity() async {
    // 1. Check for basic Internet Connection first
    try {
      final result = await InternetAddress.lookup('google.com');
      if (result.isEmpty || result.first.rawAddress.isEmpty) {
        return "NO_INTERNET";
      }
    } on SocketException catch (_) {
      return "NO_INTERNET"; // Device is fully offline
    }

    // 2. Detect Private DNS / Adblockers (AdGuard, NextDNS, etc.)
    try {
      // If google.com resolved but an ad domain fails, a Private DNS filter is blocking it.
      final adResult =
          await InternetAddress.lookup('googleads.g.doubleclick.net');
      if (adResult.isEmpty || adResult.first.rawAddress.isEmpty) {
        return "Ad-blocking Private DNS detected. Please switch to 'Automatic' DNS in your device settings.";
      }

      // Some Adblock DNS providers resolve blocked domains to local loopbacks instead of failing
      for (var address in adResult) {
        if (address.address == '0.0.0.0' ||
            address.address == '127.0.0.1' ||
            address.address == '::1') {
          return "Ad-blocking Private DNS detected. Please switch to 'Automatic' DNS in your device settings.";
        }
      }
    } on SocketException catch (_) {
      return "Ad-blocking Private DNS detected. Please switch to 'Automatic' DNS in your device settings.";
    }

    // 3. Check for sniffer apps
    if (await hasSnifferAppsInstalled()) {
      return "Security Alert: Packet capturing software detected. Please uninstall sniffers to continue.";
    }

    // 4. Check for VPN
    if (await isVpnActive()) {
      return "Security Alert: VPN detected. Please turn off VPN to use Hely TV.";
    }

    // 5. Check for Proxy/Private DNS/MITM
    if (await isNetworkCompromised()) {
      return "Security Alert: Modified DNS or Proxy detected. Please reset your Network Settings.";
    }

    return null;
  }

  static Future<String?> getSecurityWarning() async {
    return await checkNetworkSecurity();
  }
}
