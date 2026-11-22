part of '../main_screen.dart';

class _DocumentTile extends StatelessWidget {
  const _DocumentTile({required this.post});
  final CmsPost post;
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 16),
    clipBehavior: Clip.antiAlias,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                post.category?.isNotEmpty == true
                    ? post.category!
                    : 'Uncategorized',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.description_outlined,
                    color: Color(0xff155571),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      post.title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (post.academicYear?.isNotEmpty == true)
                Text('Academic year: ${post.academicYear}'),
              if (post.semester?.isNotEmpty == true)
                Text('Semester ${post.semester}'),
              if (post.createdAt != null) Text(formatCmsDate(post.createdAt)),
              Wrap(
                spacing: 8,
                children: [
                  TextButton(
                    onPressed: () => _openPost(context, post),
                    child: const Text('View details'),
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
        ),
      ],
    ),
  );
}

class _TransactionTable extends StatelessWidget {
  const _TransactionTable({required this.posts, this.filtered = false});
  final List<CmsPost> posts;
  final bool filtered;
  @override
  Widget build(BuildContext context) {
    Widget cell(String text, {bool heading = false}) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: heading ? FontWeight.w700 : FontWeight.w400,
        ),
      ),
    );
    return _Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _Heading('Transactions'),
          Table(
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            columnWidths: const {
              0: FlexColumnWidth(44),
              1: FlexColumnWidth(28),
              2: FlexColumnWidth(28),
            },
            border: const TableBorder(
              horizontalInside: BorderSide(color: line),
            ),
            children: [
              TableRow(
                decoration: const BoxDecoration(color: Color(0xffc7ecf9)),
                children: [
                  for (final title in ['Event title', 'Date', 'Amount'])
                    cell(title, heading: true),
                ],
              ),
              for (final post in posts)
                TableRow(
                  children: [
                    TextButton(
                      style: TextButton.styleFrom(
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        minimumSize: const Size(0, 44),
                      ),
                      onPressed: () => _openPost(context, post),
                      child: Text(post.title),
                    ),
                    cell(
                      post.date == null
                          ? 'Date unavailable'
                          : formatCmsDate(post.date),
                    ),
                    cell('PHP ${post.amount ?? '\u2014'}'),
                  ],
                ),
            ],
          ),
          if (posts.isEmpty)
            _Empty(
              filtered
                  ? 'No matching transactions. Try another search or report year.'
                  : 'No published transactions yet. Check back soon for the latest records.',
            ),
        ],
      ),
    );
  }
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
