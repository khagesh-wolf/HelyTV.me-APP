import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import '../../models/models.dart';
import '../../providers/app_provider.dart';
import '../../services/security_service.dart';
import 'package:simple_pip_mode/simple_pip.dart';

class PlayerScreen extends StatefulWidget {
  final MatchModel match;
  const PlayerScreen({super.key, required this.match});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen>
    with WidgetsBindingObserver {
  final SimplePip _pip = SimplePip();
  bool isUnlocked = false;
  bool isChecking = true;
  String? securityError;
  int selectedStreamIndex = 0;
  WebViewController? _webViewController;
  List<StreamModel> streams = [];
  Timer? _premiumTimer;
  Timer? _uiRefreshTimer;
  Timer? _hideUiTimer;
  bool _showControls = true;
  String _premiumRemainingText = '';

  // Tracks orientation to handle status bar visibility efficiently
  bool _wasLandscape = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    WakelockPlus.enable();

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    streams = Provider.of<AppProvider>(context, listen: false)
        .getStreamsForMatch(widget.match.matchId);

    _checkAccessAndSecurity();

    // Auto-refresh UI every 15 seconds to unlock buttons automatically
    // when the countdown crosses the 30-minute mark.
    _uiRefreshTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.paused) {
      try {
        await _pip.enterPipMode();
      } catch (e) {
        debugPrint("PIP failed: $e");
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    _premiumTimer?.cancel();
    _uiRefreshTimer?.cancel();
    _hideUiTimer?.cancel();

    if (_webViewController != null) {
      _webViewController!.loadRequest(Uri.parse('about:blank'));
    }

    WakelockPlus.disable();

    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

    super.dispose();
  }

  // Reload handler triggered by the Reload button
  void _retryNetworkCheck() {
    setState(() {
      isChecking = true;
      securityError = null;
    });
    _checkAccessAndSecurity();
  }

  Future<void> _checkAccessAndSecurity() async {
    String? warning = await SecurityService.getSecurityWarning();
    if (warning != null) {
      setState(() {
        securityError = warning;
        isChecking = false;
      });
      return;
    }

    bool unlocked = await SecurityService.isPremiumUnlocked();
    DateTime? expiry = await SecurityService.getPremiumExpiryDate();

    setState(() {
      isUnlocked = unlocked;
      isChecking = false;
      if (unlocked && streams.isNotEmpty) {
        _initPlayer(streams[selectedStreamIndex].id);
        if (expiry != null) {
          _startPremiumTimer(expiry);
        }
      }
    });
  }

  void _startPremiumTimer(DateTime expiry) {
    _updatePremiumText(expiry);
    _premiumTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updatePremiumText(expiry);
    });
  }

  void _updatePremiumText(DateTime expiry) {
    final now = DateTime.now();
    if (now.isAfter(expiry)) {
      _premiumTimer?.cancel();
      setState(() {
        isUnlocked = false;
        _premiumRemainingText = 'Expired';
      });
    } else {
      final diff = expiry.difference(now);
      final hours = diff.inHours.toString().padLeft(2, '0');
      final minutes = (diff.inMinutes % 60).toString().padLeft(2, '0');
      final seconds = (diff.inSeconds % 60).toString().padLeft(2, '0');
      setState(() {
        _premiumRemainingText = '$hours:$minutes:$seconds remaining';
      });
    }
  }

  /// Determines which URL to load based on the match start and end times.
  String _getCurrentStatusUrl(String streamId) {
    try {
      final startTime = widget.match.startTime;
      final endTime = widget.match.endTime;
      final now = DateTime.now();

      final soonThreshold = startTime.subtract(const Duration(minutes: 30));

      if (now.isBefore(soonThreshold)) {
        return 'https://hely.pages.dev/soon';
      } else if (now.isAfter(endTime)) {
        return 'https://hely.pages.dev/ended';
      }
    } catch (e) {
      debugPrint("Error calculating match status: $e");
    }

    // Default active player URL
    return 'https://hely.pages.dev/player?id=$streamId';
  }

  void _initPlayer(String streamId) {
    final url = _getCurrentStatusUrl(streamId);

    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..addJavaScriptChannel(
        'FullscreenChannel',
        onMessageReceived: (JavaScriptMessage message) {
          if (message.message == 'enter') {
            _enterFullscreen();
          } else if (message.message == 'exit') {
            _exitFullscreen();
          }
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            // If the URL is restricted, remove scrolling via JavaScript
            if (url.contains('helytv.pages.dev/soon') ||
                url.contains('helytv.pages.dev/ended')) {
              _webViewController
                  ?.runJavaScript("document.body.style.overflow = 'hidden'; "
                      "document.documentElement.style.overflow = 'hidden';");
            }

            // Inject JavaScript to listen for fullscreen button clicks inside the web player
            _webViewController?.runJavaScript('''
              document.addEventListener('fullscreenchange', function() {
                FullscreenChannel.postMessage(document.fullscreenElement ? 'enter' : 'exit');
              });
              document.addEventListener('webkitfullscreenchange', function() {
                FullscreenChannel.postMessage(document.webkitFullscreenElement ? 'enter' : 'exit');
              });
            ''');
          },
          onNavigationRequest: (NavigationRequest request) {
            if (request.url.startsWith('https://hely.pages.dev') ||
                request.url.startsWith('https://helytv.pages.dev')) {
              return NavigationDecision.navigate;
            }
            return NavigationDecision.prevent;
          },
        ),
      )
      ..loadRequest(Uri.parse(url));
  }

  void _changeStream(int index) {
    setState(() {
      selectedStreamIndex = index;
      if (isUnlocked && _webViewController != null) {
        final newUrl = _getCurrentStatusUrl(streams[index].id);

        // Load blank to kill current stream's audio/video, then load the new server
        _webViewController!.loadRequest(Uri.parse('about:blank')).then((_) {
          _webViewController!.loadRequest(Uri.parse(newUrl));
        });
      }
    });
  }

  // Forces the app to stay in landscape
  void _enterFullscreen() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _startHideUiTimer();
  }

  void _startHideUiTimer() {
    _hideUiTimer?.cancel();
    setState(() => _showControls = true);
    _hideUiTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _showControls = false);
    });
  }

  // Forces portrait, then re-enables sensor rotation after a delay
  void _exitFullscreen() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
      }
    });
  }

  // Widget to display No Internet or Security Alert
  Widget _buildErrorState() {
    final isNoInternet = securityError == "NO_INTERNET";

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isNoInternet ? Icons.wifi_off_rounded : Icons.security,
              color: isNoInternet ? Colors.orange : Colors.redAccent,
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              isNoInternet
                  ? "No Internet Connection.\nPlease check your network and try again."
                  : securityError!,
              style: TextStyle(
                color: isNoInternet ? Colors.orange : Colors.redAccent,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    isNoInternet ? Colors.orange : const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: _retryNetworkCheck,
              icon: const Icon(Icons.refresh),
              label: const Text('Reload',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    // Automatically hide/show the status bar when orientation changes
    if (isLandscape != _wasLandscape) {
      _wasLandscape = isLandscape;
      if (isLandscape) {
        // Hides status bar and navigation bar
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      } else {
        // Restores status bar and navigation bar
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
            overlays: SystemUiOverlay.values);
      }
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final cardColor = Theme.of(context).cardColor;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.grey[400] : Colors.grey[600];

    // Time-based restriction calculation
    final now = DateTime.now();
    final soonThreshold =
        widget.match.startTime.subtract(const Duration(minutes: 30));

    // Restricted if: More than 30 mins before start, OR after end time, OR manually marked Ended.
    // Explicit 'Live' API override prevents restriction even if local time is off.
    final isRestricted =
        (now.isBefore(soonThreshold) && widget.match.status != 'Live') ||
            now.isAfter(widget.match.endTime) ||
            widget.match.status == 'Ended';

    // Wrapping in WillPopScope intercepts the hardware back button.
    // If we are in landscape, the back button exits fullscreen instead of leaving the screen.
    return WillPopScope(
      onWillPop: () async {
        if (isLandscape) {
          _exitFullscreen();
          return false; // Prevents popping the screen
        }
        return true; // Allows normal back navigation
      },
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: isLandscape
            ? null
            : AppBar(
                backgroundColor: cardColor,
                elevation: 0,
                iconTheme: IconThemeData(color: textColor),
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        '${widget.match.team1Name} vs ${widget.match.team2Name}',
                        style: TextStyle(
                            fontSize: 16,
                            color: textColor,
                            fontWeight: FontWeight.bold)),
                    Text(widget.match.tournament,
                        style: TextStyle(fontSize: 12, color: subTextColor)),
                  ],
                ),
              ),
        body: isChecking
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF2563EB)))
            : securityError != null
                ? _buildErrorState() // Refactored to use the new error widget
                : Column(
                    children: [
                      // Video Player Area
                      SizedBox(
                        height: isLandscape
                            ? MediaQuery.of(context).size.height
                            : 230,
                        width: double.infinity,
                        child: !isUnlocked
                            ? _buildLockedState()
                            : SafeArea(
                                top: false,
                                bottom: false,
                                left: isLandscape,
                                right: isLandscape,
                                child: Stack(
                                  children: [
                                    Positioned.fill(
                                      // If restricted, prevent scrolling/gestures on the player entirely
                                      child: isRestricted
                                          ? IgnorePointer(
                                              child: WebViewWidget(
                                                  controller:
                                                      _webViewController!),
                                            )
                                          : GestureDetector(
                                              onTap: isLandscape
                                                  ? _startHideUiTimer
                                                  : null,
                                              child: WebViewWidget(
                                                  controller:
                                                      _webViewController!),
                                            ),
                                    ),

                                    // Floating Exit Button for Landscape UX
                                    if (isLandscape)
                                      Positioned(
                                        top: 16,
                                        left: 16,
                                        child: AnimatedOpacity(
                                          opacity: _showControls ? 1.0 : 0.0,
                                          duration:
                                              const Duration(milliseconds: 300),
                                          child: SafeArea(
                                            child: Container(
                                              decoration: const BoxDecoration(
                                                color: Colors.black54,
                                                shape: BoxShape.circle,
                                              ),
                                              child: IconButton(
                                                icon: const Icon(
                                                    Icons.fullscreen_exit,
                                                    color: Colors.white),
                                                tooltip: 'Exit Fullscreen',
                                                onPressed: _showControls
                                                    ? _exitFullscreen
                                                    : null,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                      ),

                      // Remaining UI only shows in Portrait Mode
                      if (!isLandscape)
                        Expanded(
                          child: SingleChildScrollView(
                            child: Column(
                              children: [
                                // Premium Status & Refresh Strip
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 4, horizontal: 16),
                                  color: bgColor,
                                  child: Row(
                                    children: [
                                      Icon(
                                          isUnlocked
                                              ? Icons.verified
                                              : Icons.lock_outline,
                                          color: const Color(0xFF2563EB),
                                          size: 16),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          isUnlocked
                                              ? 'Premium Active - $_premiumRemainingText'
                                              : 'Premium Locked — Tap player to unlock',
                                          style: const TextStyle(
                                              color: Color(0xFF2563EB),
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      IconButton(
                                        icon: Icon(Icons.refresh,
                                            color: textColor, size: 24),
                                        tooltip: 'Refresh Stream',
                                        onPressed: () {
                                          if (isUnlocked &&
                                              _webViewController != null) {
                                            _webViewController!.reload();
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                ),

                                // Match Info Box
                                Container(
                                  margin: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 20),
                                  decoration: BoxDecoration(
                                    color: cardColor,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceEvenly,
                                    children: [
                                      _buildTeam(
                                          widget.match.team1Name,
                                          widget.match.team1Logo,
                                          'logo1_${widget.match.matchId}',
                                          textColor),
                                      const Text('VS',
                                          style: TextStyle(
                                              color: Colors.grey,
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold)),
                                      _buildTeam(
                                          widget.match.team2Name,
                                          widget.match.team2Logo,
                                          'logo2_${widget.match.matchId}',
                                          textColor),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 20),

                                // Stream Servers Section
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                  child: Column(
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(Icons.storage,
                                                  color: textColor, size: 18),
                                              const SizedBox(width: 8),
                                              Text('Stream Servers',
                                                  style: TextStyle(
                                                      color: textColor,
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.bold)),
                                            ],
                                          ),
                                          Text('${streams.length} available',
                                              style: TextStyle(
                                                  color: subTextColor,
                                                  fontSize: 12)),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      streams.isEmpty
                                          ? const Center(
                                              child: Text(
                                                  "No streams available",
                                                  style: TextStyle(
                                                      color: Colors.grey)))
                                          : SizedBox(
                                              width: double.infinity,
                                              child: Wrap(
                                                spacing: 12.0,
                                                runSpacing: 12.0,
                                                alignment: WrapAlignment
                                                    .center, // Centers the grid items
                                                children: List.generate(
                                                    streams.length, (index) {
                                                  final isSelected =
                                                      selectedStreamIndex ==
                                                          index;

                                                  return SizedBox(
                                                    // Calculates width to perfectly fit 2 buttons per row (accounting for padding & spacing)
                                                    width:
                                                        (MediaQuery.of(context)
                                                                    .size
                                                                    .width -
                                                                44) /
                                                            2,
                                                    child: ElevatedButton(
                                                      style: ElevatedButton
                                                          .styleFrom(
                                                        backgroundColor:
                                                            isRestricted
                                                                ? (isDark
                                                                    ? Colors
                                                                        .white10
                                                                    : Colors
                                                                        .black12)
                                                                : isSelected
                                                                    ? const Color(
                                                                        0xFF2563EB)
                                                                    : (isDark
                                                                        ? const Color(
                                                                            0xFF1A1A1A)
                                                                        : Colors
                                                                            .grey[300]),
                                                        foregroundColor:
                                                            isRestricted
                                                                ? Colors.grey
                                                                : isSelected
                                                                    ? Colors
                                                                        .white
                                                                    : subTextColor,
                                                        elevation: isRestricted
                                                            ? 0
                                                            : isSelected
                                                                ? 2
                                                                : 0,
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                                vertical: 14),
                                                        shape:
                                                            RoundedRectangleBorder(
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(10),
                                                          side: BorderSide(
                                                            color: !isRestricted &&
                                                                    isSelected
                                                                ? const Color(
                                                                    0xFF2563EB)
                                                                : Colors
                                                                    .transparent,
                                                            width: 1.5,
                                                          ),
                                                        ),
                                                      ),
                                                      onPressed: isRestricted
                                                          ? null
                                                          : () {
                                                              setState(() {
                                                                if (isUnlocked) {
                                                                  _changeStream(
                                                                      index);
                                                                }
                                                              });
                                                            },
                                                      child: Row(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .center,
                                                        children: [
                                                          Icon(
                                                              Icons
                                                                  .play_circle_outline,
                                                              color: isRestricted
                                                                  ? Colors.grey
                                                                  : isSelected
                                                                      ? Colors.white
                                                                      : const Color(0xFF2563EB),
                                                              size: 16),
                                                          const SizedBox(
                                                              width: 8),
                                                          Flexible(
                                                            child: Text(
                                                              'Server ${index + 1}',
                                                              maxLines: 1,
                                                              overflow:
                                                                  TextOverflow
                                                                      .ellipsis,
                                                              style: TextStyle(
                                                                fontSize: 14,
                                                                fontWeight: isSelected
                                                                    ? FontWeight
                                                                        .bold
                                                                    : FontWeight
                                                                        .w500,
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  );
                                                }),
                                              ),
                                            ),
                                      const SizedBox(
                                          height: 30), // Bottom padding
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
      ),
    );
  }

  Widget _buildTeam(String name, String logo, String heroTag, Color textColor) {
    return Column(
      children: [
        Hero(
          // UX: Hero animation connecting Home to Player
          tag: heroTag,
          child: Container(
            height: 60,
            width: 60,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              image: DecorationImage(
                  image: CachedNetworkImageProvider(logo.isNotEmpty
                      ? logo
                      : 'https://via.placeholder.com/150'),
                  fit: BoxFit.contain),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(name,
            style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildLockedState() {
    return Container(
      color: Colors.black,
      child: Center(
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2563EB),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          onPressed: () async {
            // 1. Launch Monetag Direct Link Ad in External Browser (Chrome)
            // Replace this URL with your actual Monetag Direct Link
            final adUrl = Uri.parse('https://omg10.com/4/10731338');
            try {
              await launchUrl(adUrl, mode: LaunchMode.externalApplication);
            } catch (e) {
              debugPrint('Could not launch ad: $e');
            }

            // 2. Unlock Premium instantly after clicking the ad
            await SecurityService.unlockPremium();
            DateTime? expiry = await SecurityService.getPremiumExpiryDate();
            if (mounted) {
              setState(() {
                isUnlocked = true;
                if (expiry != null) _startPremiumTimer(expiry);
                if (streams.isNotEmpty) {
                  _initPlayer(streams[selectedStreamIndex].id);
                }
              });
            }
          },
          icon: const Icon(Icons.lock_open, color: Colors.white),
          label: const Text('Watch Ad to Unlock',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}
