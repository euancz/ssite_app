part of '../main_screen.dart';

class _NewsCard extends StatelessWidget {
  const _NewsCard({required this.post});
  final CmsPost post;
  @override
  Widget build(BuildContext context) => _Surface(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          post.moduleLabel.toUpperCase(),
          style: const TextStyle(
            color: muted,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          post.title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'By ${post.author} · ${formatCmsDate(post.date)}',
          style: const TextStyle(color: muted, fontSize: 11),
        ),
        TextButton(
          onPressed: () => _openPost(context, post),
          child: const Text('Read More →'),
        ),
        if (post.imageUrl != null) _PostImage(post: post),
      ],
    ),
  );
}

class CmsPostCard extends StatefulWidget {
  const CmsPostCard({super.key, required this.post, this.full = false});
  final CmsPost post;
  final bool full;
  @override
  State<CmsPostCard> createState() => _CmsPostCardState();
}

class _CmsPostCardState extends State<CmsPostCard> {
  late bool _liked = widget.post.likedByViewer ?? false;
  late int _likeCount = widget.post.likeCount ?? 0;
  bool _updatingLike = false;

  Future<void> _toggleLike() async {
    if (_updatingLike) return;
    setState(() => _updatingLike = true);
    try {
      final result = await CmsApi.instance.toggleLike(
        widget.post.module,
        widget.post.id,
        !_liked,
      );
      if (!mounted) return;
      setState(() {
        _liked = result['liked'] == true;
        _likeCount = (result['like_count'] as num?)?.toInt() ?? _likeCount;
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not update the like. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _updatingLike = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final full = widget.full;
    return _Surface(
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: const Color(0xFFC7ECF9),
              child: Text(
                post.author.isEmpty ? 'FM' : post.author.substring(0, 1),
                style: const TextStyle(color: ink, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post.author.isEmpty ? 'Former member' : post.author,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  if (post.authorRole?.isNotEmpty == true)
                    Text(
                      post.authorRole!,
                      style: const TextStyle(color: muted, fontSize: 12),
                    ),
                  Text(
                    '${formatCmsDate(post.createdAt ?? post.date)} · ${post.moduleLabel}',
                    style: const TextStyle(color: muted, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (post.category?.isNotEmpty == true)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFEAF3FC),
              border: Border.all(color: line),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              post.category!,
              semanticsLabel: 'Category: ${post.category}',
              style: const TextStyle(
                color: ink,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        const SizedBox(height: 4),
        Text(
          post.title,
          style: const TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w700,
            height: 1.35,
          ),
        ),
        if (full && post.contentHtml?.isNotEmpty == true)
          Html(
            data: post.contentHtml!,
            onLinkTap: (url, attributes, element) async {
              final uri = Uri.tryParse(url ?? '');
              if (uri != null &&
                  ['https', 'http', 'mailto'].contains(uri.scheme)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
          )
        else if (post.description.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            post.description,
            maxLines: full ? null : 3,
            overflow: full ? null : TextOverflow.ellipsis,
            style: const TextStyle(color: muted, fontSize: 14, height: 1.65),
          ),
        ],
        if (post.imageUrl != null) ...[
          const SizedBox(height: 14),
          _PostImage(post: post),
        ],
        if (post.location?.isNotEmpty == true)
          _Meta(icon: Icons.location_on_outlined, text: post.location!),
        if (post.awardee?.isNotEmpty == true)
          _Meta(icon: Icons.emoji_events_outlined, text: post.awardee!),
        if (post.amount != null)
          _Meta(icon: Icons.payments_outlined, text: 'PHP ${post.amount}'),
        if (post.academicYear?.isNotEmpty == true)
          _Meta(icon: Icons.school_outlined, text: 'A.Y. ${post.academicYear}'),
        if (post.semester?.isNotEmpty == true)
          _Meta(
            icon: Icons.calendar_month_outlined,
            text: 'Semester ${post.semester}',
          ),
        if (post.fileUrl != null) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            label: const Text('View PDF'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => Scaffold(
                  appBar: AppBar(title: Text(post.title)),
                  body: PdfViewer.uri(
                    Uri.parse(post.fileUrl!),
                    headers: CmsApi.instance.headersForUrl(post.fileUrl!),
                  ),
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 8),
        const Divider(color: line),
        if (post.viewCount != null || post.likeCount != null) ...[
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              if (post.viewCount != null)
                _Meta(
                  icon: Icons.visibility_outlined,
                  text:
                      '${post.viewCount} ${post.viewCount == 1 ? 'view' : 'views'}',
                ),
              if (post.likeCount != null)
                TextButton.icon(
                  onPressed: _updatingLike ? null : _toggleLike,
                  icon: Icon(
                    _liked
                        ? Icons.favorite
                        : Icons.favorite_border,
                    size: 18,
                  ),
                  label: Text(
                    _updatingLike
                        ? 'Updating…'
                        : '$_likeCount ${_likeCount == 1 ? 'like' : 'likes'}',
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: _liked ? Colors.red : muted,
                  ),
                ),
            ],
          ),
        ],
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: 12,
          children: [
            if (!full)
              TextButton(
                onPressed: () => _openPost(context, post),
                child: const Text('Read full post'),
              ),
            if (post.url != null)
              Builder(
                builder: (shareContext) => TextButton.icon(
                  onPressed: () async {
                    final box = shareContext.findRenderObject() as RenderBox?;
                    try {
                      await SharePlus.instance.share(
                        ShareParams(
                          text: '${post.title}\n${post.url}',
                          title: post.title,
                          sharePositionOrigin: box == null
                              ? null
                              : box.localToGlobal(Offset.zero) & box.size,
                        ),
                      );
                    } catch (_) {
                      if (shareContext.mounted) {
                        ScaffoldMessenger.of(shareContext).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Sharing is unavailable. Use Copy link instead.',
                            ),
                          ),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.share_outlined, size: 18),
                  label: const Text('Share'),
                ),
              ),
            if (post.url != null)
              TextButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: post.url!));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Link copied')),
                    );
                  }
                },
                icon: const Icon(Icons.link, size: 18),
                label: const Text('Copy link'),
              ),
          ],
        ),
      ],
      ),
    );
  }
}

void _openPost(BuildContext context, CmsPost post) =>
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text(post.moduleLabel)),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 864),
                child: CmsPostCard(post: post, full: true),
              ),
            ),
          ),
        ),
      ),
    );

class _PostImage extends StatelessWidget {
  const _PostImage({required this.post});
  final CmsPost post;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: () => showDialog<void>(
      context: context,
      builder: (context) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                maxScale: 5,
                child: _image(BoxFit.contain),
              ),
            ),
            Positioned(
              top: MediaQuery.paddingOf(context).top + 8,
              right: 8,
              child: IconButton.filledTonal(
                tooltip: 'Close image',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ),
          ],
        ),
      ),
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: AspectRatio(aspectRatio: 16 / 9, child: _image(BoxFit.cover)),
    ),
  );
  Widget _image(BoxFit fit) => Image.network(
    post.imageUrl!,
    width: double.infinity,
    fit: fit,
    headers: CmsApi.instance.headersForUrl(post.imageUrl!),
    loadingBuilder: (_, child, progress) => progress == null
        ? child
        : const Center(child: CircularProgressIndicator()),
    errorBuilder: (_, _, _) => const ColoredBox(
      color: Color(0xFFE5EFF4),
      child: Center(child: Icon(Icons.broken_image_outlined, color: muted)),
    ),
  );
}
