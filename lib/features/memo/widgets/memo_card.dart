import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/memo_model.dart';

class MemoCard extends StatelessWidget {
  final MemoModel memo;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const MemoCard({
    super.key,
    required this.memo,
    required this.onTap,
    this.onLongPress,
  });

  String get _thumbnail {
    if (memo.drawingPath != null) return memo.drawingPath!;
    if (memo.imagePaths.isNotEmpty) return memo.imagePaths.first;
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_thumbnail.isNotEmpty) _ThumbnailImage(path: _thumbnail),
              Text(
                memo.title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (memo.body != null && memo.body!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  memo.body!,
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 8),
              Text(
                DateFormat('yyyy.MM.dd').format(memo.updatedAt),
                style: TextStyle(fontSize: 11, color: Colors.grey[400]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThumbnailImage extends StatelessWidget {
  final String path;
  const _ThumbnailImage({required this.path});

  @override
  Widget build(BuildContext context) {
    final file = File(path);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: file.existsSync()
            ? Image.file(file, height: 100, width: double.infinity, fit: BoxFit.cover)
            : Container(
                height: 100,
                color: Colors.grey[100],
                child: const Icon(Icons.broken_image_outlined, color: Colors.grey),
              ),
      ),
    );
  }
}
