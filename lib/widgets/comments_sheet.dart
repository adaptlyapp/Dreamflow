import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wellspring/models/comment.dart';
import 'package:wellspring/models/post.dart';
import 'package:wellspring/providers/user_provider.dart';
import 'package:wellspring/services/post_service.dart';
import 'package:wellspring/theme.dart';
import 'package:wellspring/widgets/skeletons.dart';
import 'package:uuid/uuid.dart';

class CommentsSheet extends StatefulWidget {
  final Post post;
  final PostService? service;
  const CommentsSheet({super.key, required this.post, this.service});

  @override
  State<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  late final PostService _service;
  final _controller = TextEditingController();
  List<Comment> _comments = [];
  bool _loading = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? PostService();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final items = await _service.getComments(widget.post.id);
      setState(() {
        _comments = items;
      });
    } catch (e) {
      debugPrint('CommentsSheet.load error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load comments')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    final user = context.read<UserProvider>().currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to comment')),
      );
      return;
    }
    setState(() => _sending = true);
    try {
      final c = Comment(
        id: const Uuid().v4(),
        postId: widget.post.id,
        authorId: user.id,
        authorName: user.name,
        content: text,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await _service.addComment(c);
      _controller.clear();
      await _load();
    } catch (e) {
      debugPrint('CommentsSheet.send error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send comment')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (ctx, scrollController) {
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text('Comments', style: context.textStyles.titleLarge?.semiBold),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: AppSpacing.md),
                if (_loading)
                  Padding(
                    padding: EdgeInsets.all(AppSpacing.lg),
                    child: const Center(child: CenteredLoadingSkeleton()),
                  )
                else
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                      itemCount: _comments.length,
                      itemBuilder: (context, i) {
                        final c = _comments[i];
                        return Padding(
                          padding: EdgeInsets.only(bottom: AppSpacing.md),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                                child: Text(
                                  c.authorName.isNotEmpty ? c.authorName[0].toUpperCase() : '?',
                                  style: context.textStyles.labelLarge?.withColor(
                                    Theme.of(context).colorScheme.onPrimaryContainer,
                                  ),
                                ),
                              ),
                              SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Container(
                                  padding: AppSpacing.paddingMd,
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(AppRadius.md),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(c.authorName, style: context.textStyles.labelLarge?.semiBold),
                                      const SizedBox(height: 4),
                                      Text(c.content, style: context.textStyles.bodyMedium),
                                    ],
                                  ),
                                ),
                              )
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                Padding(
                  padding: EdgeInsets.all(AppSpacing.lg),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          decoration: InputDecoration(
                            hintText: 'Add a comment…',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(999),
                            ),
                            filled: true,
                            fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                            contentPadding: EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 12),
                          ),
                          minLines: 1,
                          maxLines: 4,
                        ),
                      ),
                      SizedBox(width: AppSpacing.sm),
                      FilledButton.icon(
                        onPressed: _sending ? null : _send,
                        icon: const Icon(Icons.send, color: Colors.white),
                        label: Text(_sending ? 'Sending…' : 'Send'),
                      )
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
