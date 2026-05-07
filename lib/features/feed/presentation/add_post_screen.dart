import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_dimens.dart';
import '../../../core/design/app_text_styles.dart';
import '../../../core/network/api_client.dart';
import '../data/posts_repository.dart';
import 'feed_providers.dart';

class AddPostScreen extends ConsumerStatefulWidget {
  const AddPostScreen({super.key});

  static const path = '/add';
  static const name = 'add';

  @override
  ConsumerState<AddPostScreen> createState() => _AddPostScreenState();
}

class _AddPostScreenState extends ConsumerState<AddPostScreen> {
  final _name = TextEditingController();
  final _caption = TextEditingController();
  final _location = TextEditingController();
  final _country = TextEditingController();
  final _date = TextEditingController();
  final _ticket = TextEditingController();
  bool _private = false;
  String? _imagePath;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _caption.dispose();
    _location.dispose();
    _country.dispose();
    _date.dispose();
    _ticket.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (!mounted) return;
    if (file != null) {
      setState(() => _imagePath = file.path);
    }
  }

  String? _normalizeTicketUrl() {
    final raw = _ticket.text.trim();
    if (raw.isEmpty) return null;
    final withScheme = raw.startsWith('http://') || raw.startsWith('https://') ? raw : 'https://$raw';
    final uri = Uri.tryParse(withScheme);
    if (uri == null || !uri.hasAuthority) return null;
    return withScheme;
  }

  Future<void> _post() async {
    if (_busy) return;
    if (_imagePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add a photo')));
      return;
    }
    final ticketUrl = _normalizeTicketUrl();
    if (_ticket.text.trim().isNotEmpty && ticketUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ticket URL is invalid')));
      return;
    }
    setState(() => _busy = true);
    try {
      final dio = ref.read(apiClientProvider);
      final posts = PostsRepository(dio);
      final url = await posts.uploadImage(_imagePath!);
      final eventDetails = <String, dynamic>{
        'type': 'event',
        if (_date.text.trim().isNotEmpty) 'date': _date.text.trim(),
        if (_location.text.trim().isNotEmpty) 'venue': _location.text.trim(),
      };
      if (ticketUrl != null) {
        eventDetails['ticketUrl'] = ticketUrl;
      }
      await posts.createPost({
        'location': _name.text.trim(),
        'country': _country.text.trim(),
        'status': 'going',
        'imageUrl': url,
        'caption': _caption.text.trim(),
        'isPrivate': _private,
        'eventDetails': eventDetails,
      });
      ref.invalidate(feedProvider);
      if (!mounted) return;
      context.go('/feed');
    } on DioException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? 'Failed')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canPost = _name.text.trim().isNotEmpty &&
        _location.text.trim().isNotEmpty &&
        _country.text.trim().isNotEmpty &&
        _date.text.trim().isNotEmpty &&
        _imagePath != null &&
        !_busy;

    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: 0.8),
      body: Align(
        alignment: Alignment.bottomCenter,
        child: FractionallySizedBox(
          heightFactor: 0.9,
          child: Material(
            color: AppColors.background,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: AppColors.secondary,
                    border: Border(bottom: BorderSide(color: AppColors.border, width: AppDimens.borderThick)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text('NEW POST', style: AppTextStyles.display(28, color: AppColors.primary, letterSpacing: 0.1)),
                      ),
                      IconButton(
                        onPressed: () => context.pop(),
                        icon: const Icon(Icons.close, color: AppColors.background, size: 28),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text('EVENT PHOTO', style: AppTextStyles.display(13, color: AppColors.mutedForeground, letterSpacing: 0.05)),
                      const SizedBox(height: 8),
                      AspectRatio(
                        aspectRatio: 16 / 10,
                        child: InkWell(
                          onTap: _pick,
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppColors.muted,
                              border: Border.all(color: AppColors.border, width: AppDimens.borderThick),
                            ),
                            child: _imagePath == null
                                ? Center(child: Text('TAP TO UPLOAD', style: AppTextStyles.display(16, color: AppColors.mutedForeground)))
                                : Image.file(File(_imagePath!), fit: BoxFit.cover),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text('EVENT NAME *', style: AppTextStyles.display(13, color: AppColors.mutedForeground, letterSpacing: 0.05)),
                      const SizedBox(height: 8),
                      TextField(controller: _name, onChanged: (_) => setState(() {}), decoration: const InputDecoration()),
                      const SizedBox(height: 16),
                      Text('DESCRIPTION', style: AppTextStyles.display(13, color: AppColors.mutedForeground, letterSpacing: 0.05)),
                      const SizedBox(height: 8),
                      TextField(controller: _caption, maxLines: 3, decoration: const InputDecoration()),
                      const SizedBox(height: 16),
                      SwitchListTile(
                        title: Text(_private ? 'Private Event' : 'Public Event', style: AppTextStyles.body(16, weight: FontWeight.w800)),
                        value: _private,
                        onChanged: (v) => setState(() => _private = v),
                      ),
                      const SizedBox(height: 8),
                      Text('VENUE / AREA *', style: AppTextStyles.display(13, color: AppColors.mutedForeground, letterSpacing: 0.05)),
                      const SizedBox(height: 8),
                      TextField(controller: _location, onChanged: (_) => setState(() {}), decoration: const InputDecoration()),
                      const SizedBox(height: 16),
                      Text('COUNTRY *', style: AppTextStyles.display(13, color: AppColors.mutedForeground, letterSpacing: 0.05)),
                      const SizedBox(height: 8),
                      TextField(controller: _country, onChanged: (_) => setState(() {}), decoration: const InputDecoration()),
                      const SizedBox(height: 16),
                      Text('DATE *', style: AppTextStyles.display(13, color: AppColors.mutedForeground, letterSpacing: 0.05)),
                      const SizedBox(height: 8),
                      TextField(controller: _date, onChanged: (_) => setState(() {}), decoration: const InputDecoration(hintText: 'Jul 15-18, 2026')),
                      const SizedBox(height: 16),
                      Text('TICKET URL (optional)', style: AppTextStyles.display(13, color: AppColors.mutedForeground, letterSpacing: 0.05)),
                      const SizedBox(height: 8),
                      TextField(controller: _ticket, decoration: const InputDecoration()),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  color: AppColors.muted,
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: canPost ? AppColors.primary : AppColors.mutedForeground,
                        foregroundColor: AppColors.primaryForeground,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                      ),
                      onPressed: canPost ? _post : null,
                      child: Text('POST EVENT', style: AppTextStyles.display(18, color: AppColors.primaryForeground)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
