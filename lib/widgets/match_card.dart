import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
// Ensure this points to your Match model

class MatchCard extends StatefulWidget {
  final dynamic match; // Using dynamic or Match based on your model
  final VoidCallback onTap;

  const MatchCard({
    super.key,
    required this.match,
    required this.onTap,
  });

  @override
  State<MatchCard> createState() => _MatchCardState();
}

class _MatchCardState extends State<MatchCard> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Update the countdown timer every second to show seconds changing
    if (widget.match.status.toLowerCase() == 'upcoming') {
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _getTimeRemaining() {
    final status = widget.match.status.toLowerCase();
    if (status == 'ended') return 'Ended';
    if (status == 'live') return 'Live Now';

    final now = DateTime.now();
    final diff = widget.match.startTime.difference(now);

    if (diff.isNegative) return 'Starting Soon';

    final days = diff.inDays;
    final hours = (diff.inHours % 24).toString().padLeft(2, '0');
    final minutes = (diff.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (diff.inSeconds % 60).toString().padLeft(2, '0');

    if (days > 0) {
      return 'Starts in ${days}d ${hours}h ${minutes}m ${seconds}s';
    }

    return 'Starts in ${hours}h ${minutes}m ${seconds}s';
  }

  Color _getStatusColor() {
    final status = widget.match.status.toLowerCase();
    if (status == 'live') return Colors.red;
    if (status == 'ended') return Colors.grey;
    return const Color(0xFF3B82F6); // Blue matching the design
  }

  @override
  Widget build(BuildContext context) {
    // Safely get bgImage in case it's not present in the dynamic model
    final String bgImage = (widget.match.bgImage != null &&
            widget.match.bgImage.toString().isNotEmpty)
        ? widget.match.bgImage
        : 'https://via.placeholder.com/600x300';

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        // Reduced vertical margin
        margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14), // Slightly smaller radius
            color: Colors.black87,
            image: DecorationImage(
              image: CachedNetworkImageProvider(bgImage),
              fit: BoxFit.cover,
              colorFilter: ColorFilter.mode(
                  Colors.black.withOpacity(0.4), BlendMode.darken),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              )
            ]),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: LinearGradient(
              colors: [
                Colors.black.withOpacity(0.4),
                Colors.black.withOpacity(0.85)
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          // Reduced internal padding
          padding: const EdgeInsets.all(12.0),
          child: Column(
            children: [
              // Top Row: Tournament & Status Badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(Icons.emoji_events,
                            color: Colors.white70, size: 14), // Smaller icon
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            widget.match.tournament,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11, // Smaller text
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 3), // Smaller padding
                    decoration: BoxDecoration(
                      color: _getStatusColor(),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      widget.match.status.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9, // Smaller text
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                ],
              ),

              const SizedBox(height: 12), // Reduced vertical spacing

              // Middle Row: Teams & VS
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Team 1
                  Expanded(
                    child: Column(
                      children: [
                        Container(
                          width: 45, // Smaller logo box
                          height: 45, // Smaller logo box
                          padding: const EdgeInsets.all(3), // Reduced padding
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white38, width: 2),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: CachedNetworkImage(
                              imageUrl: widget.match.team1Logo,
                              fit: BoxFit.contain,
                              errorWidget: (context, url, error) =>
                                  const Icon(Icons.broken_image, size: 24),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6), // Reduced spacing
                        Text(
                          widget.match.team1Name,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12, // Smaller text
                          ),
                        )
                      ],
                    ),
                  ),

                  // VS Text
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12.0),
                    child: Text(
                      'VS',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15, // Smaller text
                        fontWeight: FontWeight.w900,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),

                  // Team 2
                  Expanded(
                    child: Column(
                      children: [
                        Container(
                          width: 45, // Smaller logo box
                          height: 45, // Smaller logo box
                          padding: const EdgeInsets.all(3), // Reduced padding
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white38, width: 2),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: CachedNetworkImage(
                              imageUrl: widget.match.team2Logo,
                              fit: BoxFit.contain,
                              errorWidget: (context, url, error) =>
                                  const Icon(Icons.broken_image, size: 24),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6), // Reduced spacing
                        Text(
                          widget.match.team2Name,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12, // Smaller text
                          ),
                        )
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12), // Reduced vertical spacing

              // Bottom Row: Date/Time & Watch Button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.calendar_today,
                              color: Colors.white70, size: 12), // Smaller icon
                          const SizedBox(width: 4),
                          Text(
                            DateFormat('MMM dd - hh:mm a')
                                .format(widget.match.startTime),
                            style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 11), // Smaller text
                          ),
                        ],
                      ),
                      const SizedBox(height: 4), // Reduced spacing
                      Row(
                        children: [
                          Icon(Icons.schedule,
                              color: _getStatusColor(),
                              size: 12), // Smaller icon
                          const SizedBox(width: 4),
                          Text(
                            _getTimeRemaining(),
                            style: TextStyle(
                              color: _getStatusColor(),
                              fontSize: 12, // Slightly smaller text
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      )
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6), // Smaller padding
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: const Color(0xFF3B82F6), width: 1.5),
                      borderRadius: BorderRadius.circular(16),
                      color: Colors.black.withOpacity(0.3),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.play_circle_outline,
                            color: Color(0xFF3B82F6), size: 14), // Smaller icon
                        SizedBox(width: 4),
                        Text(
                          'Watch',
                          style: TextStyle(
                            color: Color(0xFF3B82F6),
                            fontWeight: FontWeight.bold,
                            fontSize: 12, // Smaller text
                          ),
                        ),
                      ],
                    ),
                  )
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}
