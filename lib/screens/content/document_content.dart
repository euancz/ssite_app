part of '../main_screen.dart';

class _DocumentTile extends StatelessWidget {
  const _DocumentTile({required this.post});
  final CmsPost post;
  @override
  Widget build(BuildContext context) => _Surface(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFEAF5FA),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.description_outlined,
                color: Color(0xFF155571),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (post.category?.isNotEmpty == true) ...[
                    Text(
                      post.category!,
                      style: const TextStyle(fontSize: 12, color: muted),
                    ),
                    const SizedBox(height: 4),
                  ],
                  Text(
                    post.title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 16,
          runSpacing: 6,
          children: [
            if (post.academicYear?.isNotEmpty == true)
              Text(
                'A.Y. ${post.academicYear}',
                style: const TextStyle(fontSize: 12, color: muted),
              ),
            if (post.semester?.isNotEmpty == true)
              Text(
                'Semester ${post.semester}',
                style: const TextStyle(fontSize: 12, color: muted),
              ),
            if (post.createdAt?.isNotEmpty == true)
              Text(
                formatCmsDate(post.createdAt),
                style: const TextStyle(fontSize: 12, color: muted),
              ),
          ],
        ),
        if (post.description.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            post.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, color: muted),
          ),
        ],
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: [
            TextButton(
              onPressed: () => _openPost(context, post),
              child: Text(
                post.fileUrl == null ? 'View document' : 'View details',
              ),
            ),
            if (post.fileUrl != null)
              TextButton.icon(
                onPressed: () => _openPdf(context, post),
                icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                label: const Text('View PDF'),
              ),
          ],
        ),
      ],
    ),
  );
}

class _TransactionCard extends StatelessWidget {
  const _TransactionCard({required this.post});
  final CmsPost post;
  @override
  Widget build(BuildContext context) => _Surface(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(post.title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        Wrap(
          spacing: 20,
          runSpacing: 8,
          children: [
            if (post.date?.isNotEmpty == true)
              Text(
                formatCmsDate(post.date),
                style: const TextStyle(fontSize: 12, color: muted),
              ),
            Text(
              'PHP ${post.amount ?? '—'}',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: () => _openPost(context, post),
          icon: const Icon(Icons.receipt_long_outlined, size: 18),
          label: const Text('View report'),
        ),
      ],
    ),
  );
}

class _TransactionTable extends StatelessWidget {
  const _TransactionTable({required this.posts});
  final List<CmsPost> posts;
  @override
  Widget build(BuildContext context) => MediaQuery.sizeOf(context).width < 600
      ? Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [for (final post in posts) _TransactionCard(post: post)],
        )
      : _Surface(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                child: DataTable(
                  columnSpacing: 24,
                  horizontalMargin: 0,
                  headingRowColor: const WidgetStatePropertyAll(
                    Color(0xFFC7ECF9),
                  ),
                  columns: const [
                    DataColumn(label: Text('Event title')),
                    DataColumn(label: Text('Date')),
                    DataColumn(label: Text('Amount')),
                  ],
                  rows: [
                    for (final post in posts)
                      DataRow(
                        cells: [
                          DataCell(
                            SizedBox(
                              width: 180,
                              child: TextButton.icon(
                                style: TextButton.styleFrom(
                                  alignment: Alignment.centerLeft,
                                ),
                                onPressed: () => _openPost(context, post),
                                icon: const Icon(
                                  Icons.description_outlined,
                                  size: 16,
                                ),
                                label: Text(
                                  post.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ),
                          DataCell(
                            Text(
                              formatCmsDate(post.date),
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          DataCell(
                            Text(
                              'PHP ${post.amount ?? '—'}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
}

void _openPdf(BuildContext context, CmsPost post) {
  if (post.fileUrl == null) return;
  if (CmsApi.instance.bearer != null && post.viewCount != null) {
    unawaited(
      CmsApi.instance
          .sendAction('engagement/${post.module}/${post.id}/view', {})
          .then<void>((_) {}, onError: (Object _) {}),
    );
  }
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => Scaffold(
        appBar: AppBar(title: Text(post.title)),
        body: PdfViewer.uri(
          Uri.parse(post.fileUrl!),
          headers: CmsApi.instance.headersForUrl(post.fileUrl!),
        ),
      ),
    ),
  );
}
