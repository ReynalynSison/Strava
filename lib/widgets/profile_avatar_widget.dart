import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image_picker/image_picker.dart';

/// A circular avatar that:
///  - Shows the saved profile picture if one has been set.
///  - Falls back to the username initial on a Strava-orange gradient.
///  - If [editable] is true, tapping it opens a camera/gallery action sheet
///    and persists the chosen image path to Hive under "profileImagePath".
class ProfileAvatarWidget extends StatefulWidget {
  final double size;
  final bool editable;

  const ProfileAvatarWidget({
    super.key,
    this.size = 64,
    this.editable = false,
  });

  @override
  State<ProfileAvatarWidget> createState() => _ProfileAvatarWidgetState();
}

class _ProfileAvatarWidgetState extends State<ProfileAvatarWidget> {
  final _box = Hive.box("database");
  final _picker = ImagePicker();

  String? get _savedImagePath => _box.get("profileImagePath") as String?;

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 512,
        maxHeight: 512,
      );
      if (picked == null) return;
      await _box.put("profileImagePath", picked.path);
      if (mounted) setState(() {});
    } catch (_) {}
  }

  void _showPicker() {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (_) => CupertinoActionSheet(
        title: const Text('Profile Photo'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _pickImage(ImageSource.camera);
            },
            child: const Text('Take Photo'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _pickImage(ImageSource.gallery);
            },
            child: const Text('Choose from Library'),
          ),
          if (_savedImagePath != null)
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              onPressed: () async {
                Navigator.pop(context);
                await _box.delete("profileImagePath");
                if (mounted) setState(() {});
              },
              child: const Text('Remove Photo'),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ValueListenableBuilder ensures the avatar rebuilds on ANY Hive write
    // (profile image path, username) across every screen that uses this widget.
    return ValueListenableBuilder(
      valueListenable: _box.listenable(keys: const ['profileImagePath', 'username']),
      builder: (context, Box db, _) {
        final path = db.get("profileImagePath") as String?;
        final username = db.get("username", defaultValue: 'Runner') as String;
        final size = widget.size;

        Widget avatar;

        if (path != null && File(path).existsSync()) {
          // Real profile photo
          avatar = Container(
            width: size,
            height: size,
            decoration: const BoxDecoration(shape: BoxShape.circle),
            clipBehavior: Clip.antiAlias,
            child: Image.file(
              File(path),
              fit: BoxFit.cover,
              width: size,
              height: size,
            ),
          );
        } else {
          // Fallback: initial letter on gradient
          avatar = Container(
            width: size,
            height: size,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Color(0xFFFC4C02), Color(0xFFFF8C42)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Center(
              child: Text(
                username.isNotEmpty ? username[0].toUpperCase() : '?',
                style: TextStyle(
                  fontSize: size * 0.44,
                  fontWeight: FontWeight.bold,
                  color: CupertinoColors.white,
                ),
              ),
            ),
          );
        }

        if (!widget.editable) return avatar;

        // Editable: wrap with tap + camera badge
        return GestureDetector(
          onTap: _showPicker,
          child: Stack(
            children: [
              avatar,
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: size * 0.34,
                  height: size * 0.34,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFC4C02),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: CupertinoTheme.of(context).scaffoldBackgroundColor,
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    CupertinoIcons.camera_fill,
                    color: CupertinoColors.white,
                    size: size * 0.18,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

