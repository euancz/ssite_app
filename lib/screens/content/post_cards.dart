part of '../main_screen.dart';

class _NewsCard extends StatelessWidget {
  const _NewsCard({
    required this.post,
    this.imageFirst = false,
    this.excerpt = false,
  });
  final CmsPost post;
  final bool imageFirst, excerpt;
  @override
  Widget build(BuildContext context) {
    final photo = SizedBox(
      height: 200,
      width: double.infinity,
      child: _PostImage(post: post),
    );
    final date = formatCmsDate(post.date ?? post.createdAt);
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (imageFirst && post.imageUrl != null) photo,
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  post.moduleLabel.toUpperCase(),
                  style: const TextStyle(
                    color: muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(post.title, style: Theme.of(context).textTheme.titleLarge),
                if (excerpt && post.description.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    post.description,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  [
                    'By ${post.author}',
                    if (date.isNotEmpty) date,
                  ].join(' \u00b7 '),
                  style: const TextStyle(color: muted, fontSize: 12),
                ),
                TextButton.icon(
                  style: TextButton.styleFrom(padding: EdgeInsets.zero),
                  onPressed: () => _openPost(context, post),
                  iconAlignment: IconAlignment.end,
                  icon: const Icon(Icons.chevron_right, size: 18),
                  label: const Text('Read more'),
                ),
              ],
            ),
          ),
          if (!imageFirst && post.imageUrl != null) photo,
        ],
      ),
    );
  }
}

class CmsPostCard extends StatelessWidget {
  const CmsPostCard({super.key, required this.post, this.full = false});
  final CmsPost post;
  final bool full;

  @override
  Widget build(BuildContext context) {
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
                  style: const TextStyle(
                    color: ink,
                    fontWeight: FontWeight.w700,
                  ),
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
            _Meta(
              icon: Icons.school_outlined,
              text: 'A.Y. ${post.academicYear}',
            ),
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
          if (full && CmsApi.instance.bearer != null)
            _PostEngagement(post: post)
          else if (post.viewCount != null || post.likeCount != null) ...[
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
                if (post.likeCount case final count?)
                  _Meta(
                    icon: Icons.favorite_border,
                    text: '$count ${count == 1 ? 'like' : 'likes'}',
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
              Builder(
                builder: (shareContext) => TextButton.icon(
                  onPressed: () async {
                    final box = shareContext.findRenderObject() as RenderBox?;
                    try {
                      await SharePlus.instance.share(
                        ShareParams(
                          text: [
                            post.title,
                            if (post.url != null) post.url!,
                          ].join('\n'),
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
                              'Sharing is unavailable on this device.',
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

class _PostEngagement extends StatefulWidget {
  const _PostEngagement({required this.post});
  final CmsPost post;

  @override
  State<_PostEngagement> createState() => _PostEngagementState();
}

class _PostEngagementState extends State<_PostEngagement> {
  late int? views = widget.post.viewCount, likes = widget.post.likeCount;
  late bool liked = widget.post.likedByViewer == true;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    if (views != null) unawaited(update('view'));
  }

  Future<void> update(String action) async {
    if (action == 'like') setState(() => saving = true);
    try {
      final post = widget.post;
      final result = await CmsApi.instance.sendAction(
        'engagement/${post.module}/${post.id}/$action',
        {},
      );
      if (!mounted) return;
      setState(() {
        if (views != null) views = result['view_count'] as int?;
        if (action == 'like') {
          likes = result['like_count'] as int?;
          liked = result['liked_by_viewer'] == true;
        }
      });
    } catch (_) {
      if (action == 'like' && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not update your like. Try again.'),
          ),
        );
      }
    } finally {
      if (action == 'like' && mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Wrap(
    crossAxisAlignment: WrapCrossAlignment.center,
    spacing: 16,
    children: [
      if (views != null)
        _Meta(icon: Icons.visibility_outlined, text: '$views views'),
      if (likes != null)
        TextButton.icon(
          onPressed: saving ? null : () => update('like'),
          icon: Icon(liked ? Icons.favorite : Icons.favorite_border),
          label: Text('$likes likes'),
        ),
    ],
  );
}

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
