import 'package:flutter/cupertino.dart';
import '../models/activity_model.dart';
import '../services/storage_service.dart';
import '../services/share_service.dart';
import '../utils/formatters.dart';
import '../widgets/route_map_widget.dart';
import '../widgets/shareable_card_widget.dart';
import '../widgets/sticker_overlay_widget.dart';
import 'camera_overlay_screen.dart';
import 'animated_route_screen.dart';

// ── Hardcoded community feed data ─────────────────────────────────────────────

class _FeedPost {
  final String username;
  final String avatarEmoji;
  final String location;
  final double distanceMeters;
  final int durationSeconds;
  final double pace;
  final DateTime date;
  final List<Map<String, double>> coords;
  final int likes;
  final List<String> comments;

  const _FeedPost({
    required this.username,
    required this.avatarEmoji,
    required this.location,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.pace,
    required this.date,
    required this.coords,
    required this.likes,
    required this.comments,
  });
}

final List<_FeedPost> _communityFeed = [
  _FeedPost(
    username: 'Maria Santos',
    avatarEmoji: '🏃‍♀️',
    location: 'Barcelona, Spain',
    distanceMeters: 10200,
    durationSeconds: 3480,
    pace: 5.69,
    date: DateTime.now().subtract(const Duration(minutes: 45)),
    likes: 24,
    comments: ['Great pace! 🔥', 'Killed it!', 'Congrats 🎉'],
    coords: [
      {'lat': 41.3900, 'lng': 2.1540},
      {'lat': 41.3912, 'lng': 2.1565},
      {'lat': 41.3925, 'lng': 2.1590},
      {'lat': 41.3938, 'lng': 2.1612},
      {'lat': 41.3950, 'lng': 2.1635},
      {'lat': 41.3962, 'lng': 2.1660},
      {'lat': 41.3970, 'lng': 2.1685},
      {'lat': 41.3975, 'lng': 2.1710},
      {'lat': 41.3978, 'lng': 2.1735},
      {'lat': 41.3975, 'lng': 2.1760},
      {'lat': 41.3968, 'lng': 2.1785},
      {'lat': 41.3958, 'lng': 2.1808},
      {'lat': 41.3945, 'lng': 2.1825},
      {'lat': 41.3930, 'lng': 2.1837},
      {'lat': 41.3915, 'lng': 2.1842},
      {'lat': 41.3900, 'lng': 2.1540},
    ],
  ),
  _FeedPost(
    username: 'Jake Chen',
    avatarEmoji: '⚡',
    location: 'Makati, Philippines',
    distanceMeters: 5400,
    durationSeconds: 1620,
    pace: 5.0,
    date: DateTime.now().subtract(const Duration(hours: 3)),
    likes: 17,
    comments: ['Sub-5 pace 😤', 'Beast mode!'],
    coords: [
      {'lat': 14.5535, 'lng': 121.0170},
      {'lat': 14.5545, 'lng': 121.0182},
      {'lat': 14.5558, 'lng': 121.0196},
      {'lat': 14.5570, 'lng': 121.0210},
      {'lat': 14.5582, 'lng': 121.0222},
      {'lat': 14.5590, 'lng': 121.0235},
      {'lat': 14.5595, 'lng': 121.0248},
      {'lat': 14.5592, 'lng': 121.0261},
      {'lat': 14.5585, 'lng': 121.0272},
      {'lat': 14.5575, 'lng': 121.0280},
      {'lat': 14.5562, 'lng': 121.0284},
      {'lat': 14.5549, 'lng': 121.0282},
      {'lat': 14.5538, 'lng': 121.0275},
      {'lat': 14.5535, 'lng': 121.0170},
    ],
  ),
  _FeedPost(
    username: 'Lena Müller',
    avatarEmoji: '🌸',
    location: 'Vienna, Austria',
    distanceMeters: 8100,
    durationSeconds: 2916,
    pace: 6.0,
    date: DateTime.now().subtract(const Duration(hours: 6)),
    likes: 31,
    comments: ['Morning run vibes ☀️', 'Love Vienna routes!', '👏👏'],
    coords: [
      {'lat': 48.2082, 'lng': 16.3738},
      {'lat': 48.2095, 'lng': 16.3755},
      {'lat': 48.2110, 'lng': 16.3768},
      {'lat': 48.2125, 'lng': 16.3780},
      {'lat': 48.2140, 'lng': 16.3790},
      {'lat': 48.2152, 'lng': 16.3802},
      {'lat': 48.2160, 'lng': 16.3818},
      {'lat': 48.2162, 'lng': 16.3834},
      {'lat': 48.2158, 'lng': 16.3850},
      {'lat': 48.2148, 'lng': 16.3862},
      {'lat': 48.2135, 'lng': 16.3870},
      {'lat': 48.2120, 'lng': 16.3872},
      {'lat': 48.2105, 'lng': 16.3868},
      {'lat': 48.2093, 'lng': 16.3858},
      {'lat': 48.2082, 'lng': 16.3738},
    ],
  ),
];

// ── Screen ────────────────────────────────────────────────────────────────────

class SocialScreen extends StatefulWidget {
  const SocialScreen({super.key});

  @override
  State<SocialScreen> createState() => _SocialScreenState();
}

class _SocialScreenState extends State<SocialScreen> {
  final StorageService _storage = StorageService();
  final ShareService _shareService = ShareService();

  List<ActivityModel> _myActivities = [];
  bool _isLoading = true;

  // GlobalKeys for RepaintBoundary capture — one per activity
  final Map<String, GlobalKey> _shareKeys = {};
  final Map<String, GlobalKey> _stickerKeys = {};
  String? _sharingId;
  String? _sharingStickerId;

  // Liked state for community posts (by index)
  final Map<int, bool> _liked = {};

  @override
  void initState() {
    super.initState();
    _loadMyActivities();
  }

  Future<void> _loadMyActivities() async {
    final activities = await _storage.loadAllActivities();
    if (!mounted) return;
    for (final a in activities) {
      _shareKeys.putIfAbsent(a.id, () => GlobalKey());
      _stickerKeys.putIfAbsent(a.id, () => GlobalKey());
    }
    setState(() {
      _myActivities = activities;
      _isLoading = false;
    });
  }

  // ─── Share helpers ────────────────────────────────────────────────────────

  Future<void> _shareCard(ActivityModel activity) async {
    final key = _shareKeys[activity.id];
    if (key == null) return;
    setState(() => _sharingId = activity.id);
    try {
      await _shareService.shareActivityImage(
        key,
        text:
            'Just ran ${formatDistance(activity.distance)} in ${formatDuration(activity.durationSeconds)} 🏃 #RunTracker',
      );
    } catch (e) {
      if (!mounted) return;
      _showError('Share Failed', e.toString());
    } finally {
      if (mounted) setState(() => _sharingId = null);
    }
  }

  Future<void> _shareSticker(ActivityModel activity) async {
    final key = _stickerKeys[activity.id];
    if (key == null) return;
    setState(() => _sharingStickerId = activity.id);
    try {
      await _shareService.exportTransparentSticker(
        key,
        text:
            'Just ran ${formatDistance(activity.distance)} in ${formatDuration(activity.durationSeconds)} 🏃 #RunTracker',
      );
    } catch (e) {
      if (!mounted) return;
      _showError('Export Failed', e.toString());
    } finally {
      if (mounted) setState(() => _sharingStickerId = null);
    }
  }

  void _showError(String title, String message) {
    showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('OK'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  /// Bottom action sheet for sharing options — keeps the feed clean
  void _showShareSheet(ActivityModel activity) {
    showCupertinoModalPopup(
      context: context,
      builder: (_) => CupertinoActionSheet(
        title: Text(
          '${formatDistance(activity.distance)} · ${formatDuration(activity.durationSeconds)}',
        ),
        message: const Text('Choose how to share this run'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _shareCard(activity);
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.photo_on_rectangle),
                SizedBox(width: 10),
                Text('Share Activity Card'),
              ],
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _shareSticker(activity);
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.sparkles),
                SizedBox(width: 10),
                Text('Export Transparent Sticker'),
              ],
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                CupertinoPageRoute(
                  builder: (_) => CameraOverlayScreen(activity: activity),
                  fullscreenDialog: true,
                ),
              );
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.camera_fill),
                SizedBox(width: 10),
                Text('Camera Sticker Mode'),
              ],
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                CupertinoPageRoute(
                  builder: (_) => AnimatedRouteScreen(activity: activity),
                  fullscreenDialog: true,
                ),
              );
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.play_circle_fill),
                SizedBox(width: 10),
                Text('Animated Route Replay'),
              ],
            ),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDestructiveAction: false,
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Social'),
      ),
      child: _isLoading
          ? const Center(child: CupertinoActivityIndicator(radius: 16))
          : CustomScrollView(
              slivers: [
                CupertinoSliverRefreshControl(onRefresh: _loadMyActivities),

                // ── COMMUNITY FEED section ───────────────────────
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
                    child: Text(
                      'COMMUNITY',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: CupertinoColors.secondaryLabel,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ),

                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => _buildCommunityPost(i),
                    childCount: _communityFeed.length,
                  ),
                ),

                // ── MY RUNS section ──────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'MY RUNS',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: CupertinoColors.secondaryLabel,
                            letterSpacing: 0.8,
                          ),
                        ),
                        Text(
                          '${_myActivities.length} runs',
                          style: const TextStyle(
                            fontSize: 12,
                            color: CupertinoColors.secondaryLabel,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                if (_myActivities.isEmpty)
                  const SliverToBoxAdapter(child: _EmptyMyRuns())
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) => _buildMyRunTile(_myActivities[i]),
                      childCount: _myActivities.length,
                    ),
                  ),

                const SliverToBoxAdapter(child: SizedBox(height: 32)),
              ],
            ),
    );
  }

  // ─── Community Post Card ──────────────────────────────────────────────────

  Widget _buildCommunityPost(int index) {
    final post = _communityFeed[index];
    final isLiked = _liked[index] ?? false;
    final likeCount = post.likes + (isLiked ? 1 : 0);
    final fakeActivity = ActivityModel(
      distance: post.distanceMeters,
      durationSeconds: post.durationSeconds,
      pace: post.pace,
      date: post.date,
      routeCoordinates: post.coords,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Container(
        decoration: BoxDecoration(
          color: CupertinoTheme.brightnessOf(context) == Brightness.dark
              ? const Color(0xFF1C1C1E)
              : CupertinoColors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header: avatar + name + time ──────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
              child: Row(
                children: [
                  // Avatar circle
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemOrange.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        post.avatarEmoji,
                        style: const TextStyle(fontSize: 22),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          post.username,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          '${post.location} · ${_relativeTime(post.date)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: CupertinoColors.secondaryLabel,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Run type badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemOrange.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      '🏃 Run',
                      style: TextStyle(
                        fontSize: 11,
                        color: CupertinoColors.systemOrange,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Stats row ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Wrap(
                spacing: 16,
                runSpacing: 4,
                children: [
                  _MiniStat(
                    icon: CupertinoIcons.map_pin_ellipse,
                    value: formatDistance(post.distanceMeters),
                    label: '',
                  ),
                  _MiniStat(
                    icon: CupertinoIcons.timer,
                    value: formatDuration(post.durationSeconds),
                    label: '',
                  ),
                  _MiniStat(
                    icon: CupertinoIcons.speedometer,
                    value: formatPace(post.pace),
                    label: '',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // ── Mini route map ────────────────────────────────────
            RouteMapWidget(
              coordinates: post.coords,
              interactive: false,
              height: 130,
            ),

            // ── Like + comment bar ────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
              child: Row(
                children: [
                  // Like button
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () =>
                        setState(() => _liked[index] = !isLiked),
                    child: Row(
                      children: [
                        Icon(
                          isLiked
                              ? CupertinoIcons.heart_fill
                              : CupertinoIcons.heart,
                          size: 20,
                          color: isLiked
                              ? CupertinoColors.systemRed
                              : CupertinoColors.secondaryLabel,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$likeCount',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isLiked
                                ? CupertinoColors.systemRed
                                : CupertinoColors.secondaryLabel,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Comment count
                  Row(
                    children: [
                      const Icon(
                        CupertinoIcons.chat_bubble,
                        size: 18,
                        color: CupertinoColors.secondaryLabel,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${post.comments.length}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: CupertinoColors.secondaryLabel,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  // Quick share
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      showCupertinoModalPopup(
                        context: context,
                        builder: (_) => CupertinoActionSheet(
                          title: Text(
                            '${post.username}\'s ${formatDistance(post.distanceMeters)} run',
                          ),
                          actions: [
                            CupertinoActionSheetAction(
                              onPressed: () {
                                Navigator.pop(context);
                                Navigator.push(
                                  context,
                                  CupertinoPageRoute(
                                    builder: (_) => AnimatedRouteScreen(
                                        activity: fakeActivity),
                                    fullscreenDialog: true,
                                  ),
                                );
                              },
                              child: const Text('View Animated Route'),
                            ),
                          ],
                          cancelButton: CupertinoActionSheetAction(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancel'),
                          ),
                        ),
                      );
                    },
                    child: const Icon(
                      CupertinoIcons.ellipsis_circle,
                      size: 20,
                      color: CupertinoColors.secondaryLabel,
                    ),
                  ),
                ],
              ),
            ),

            // ── Top comment preview ───────────────────────────────
            if (post.comments.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 2, 14, 12),
                child: Text(
                  post.comments.first,
                  style: const TextStyle(
                    fontSize: 13,
                    color: CupertinoColors.secondaryLabel,
                  ),
                ),
              )
            else
              const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  // ─── My Run Tile (compact, share button) ─────────────────────────────────

  Widget _buildMyRunTile(ActivityModel activity) {
    final isSharing = _sharingId == activity.id ||
        _sharingStickerId == activity.id;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Container(
        decoration: BoxDecoration(
          color: CupertinoTheme.brightnessOf(context) == Brightness.dark
              ? const Color(0xFF1C1C1E)
              : CupertinoColors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Mini map
            RouteMapWidget(
              coordinates: activity.routeCoordinates,
              interactive: false,
              height: 110,
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              child: Row(
                children: [
                  // Stats column
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          formatDate(activity.date),
                          style: const TextStyle(
                            fontSize: 12,
                            color: CupertinoColors.secondaryLabel,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            _MiniStat(
                              icon: CupertinoIcons.map_pin_ellipse,
                              value: formatDistance(activity.distance),
                              label: '',
                            ),
                            const SizedBox(width: 16),
                            _MiniStat(
                              icon: CupertinoIcons.timer,
                              value: formatDuration(activity.durationSeconds),
                              label: '',
                            ),
                            const SizedBox(width: 16),
                            _MiniStat(
                              icon: CupertinoIcons.speedometer,
                              value: formatPace(activity.pace),
                              label: '',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Share / loading button
                  isSharing
                      ? const CupertinoActivityIndicator()
                      : CupertinoButton(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          color: CupertinoColors.systemOrange,
                          borderRadius: BorderRadius.circular(20),
                          onPressed: () => _showShareSheet(activity),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(CupertinoIcons.share,
                                  size: 15, color: CupertinoColors.white),
                              SizedBox(width: 6),
                              Text(
                                'Share',
                                style: TextStyle(
                                  color: CupertinoColors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                ],
              ),
            ),

            // Capture widgets rendered off-screen (NOT Offstage — Offstage skips paint!)
            Stack(
              children: [
                Positioned(
                  left: -5000,
                  top: 0,
                  child: RepaintBoundary(
                    key: _shareKeys[activity.id],
                    child: ShareableCardWidget(activity: activity),
                  ),
                ),
                Positioned(
                  left: -5000,
                  top: 0,
                  child: RepaintBoundary(
                    key: _stickerKeys[activity.id],
                    child: StickerOverlayWidget(activity: activity),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _relativeTime(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _MiniStat({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: CupertinoColors.systemOrange),
        const SizedBox(width: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        if (label.isNotEmpty) ...[
          const SizedBox(width: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: CupertinoColors.secondaryLabel,
            ),
          ),
        ],
      ],
    );
  }
}

class _EmptyMyRuns extends StatelessWidget {
  const _EmptyMyRuns();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: CupertinoTheme.brightnessOf(context) == Brightness.dark
              ? const Color(0xFF1C1C1E)
              : CupertinoColors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Column(
          children: [
            Icon(CupertinoIcons.flame,
                size: 40, color: CupertinoColors.systemOrange),
            SizedBox(height: 12),
            Text(
              'No runs yet',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Head to the Record tab to start your first run.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: CupertinoColors.secondaryLabel,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
