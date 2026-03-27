import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';

// Export MatchCard so other files can import it via widgets.dart
export 'match_card.dart';

class HelyLogo extends StatelessWidget {
  final double fontSize;
  const HelyLogo({super.key, this.fontSize = 24});

  @override
  Widget build(BuildContext context) {
    // Check if the current theme is dark mode to adapt the logo text color dynamically
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;

    return RichText(
      text: TextSpan(
        style: GoogleFonts.robotoCondensed(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          fontStyle: FontStyle.italic,
        ),
        children: [
          TextSpan(text: 'HELY ', style: TextStyle(color: textColor)),
          const TextSpan(
              text: 'TV', style: TextStyle(color: Color(0xFF2563EB))),
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Container(
              margin: const EdgeInsets.only(left: 4),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '.me',
                style: GoogleFonts.robotoCondensed(
                  fontSize: fontSize * 0.6,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontStyle: FontStyle.normal,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CustomBannerAd extends StatelessWidget {
  final String imageUrl;
  final String targetUrl;

  const CustomBannerAd({
    super.key,
    required this.imageUrl,
    required this.targetUrl,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final url = Uri.parse(targetUrl);
        try {
          await launchUrl(url, mode: LaunchMode.externalApplication);
        } catch (e) {
          debugPrint('Could not launch ad URL');
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        width: double.infinity,
        height: 250,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          image: DecorationImage(
            image: CachedNetworkImageProvider(imageUrl),
            fit: BoxFit.cover,
          ),
        ),
        alignment: Alignment.topRight,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: const BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(8),
              topRight: Radius.circular(12),
            ),
          ),
          child: const Text(
            'AD',
            style: TextStyle(
                color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}
