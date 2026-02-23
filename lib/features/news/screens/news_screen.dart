import 'package:flutter/material.dart';
import '../../../core/config/supabase_config.dart';
import '../../../core/theme/app_theme.dart';

/// أنواع الأخبار
const Map<String, _NewsTypeInfo> _newsTypeInfo = {
  'general': _NewsTypeInfo('أخبار عامة', Icons.newspaper, Color(0xFF2196F3)),
  'events': _NewsTypeInfo('مناسبات', Icons.celebration, Color(0xFF4CAF50)),
  'births': _NewsTypeInfo('ولادات', Icons.child_care, Color(0xFFE91E63)),
  'deaths': _NewsTypeInfo('وفيات', Icons.local_florist, Color(0xFF757575)),
};

class _NewsTypeInfo {
  final String label;
  final IconData icon;
  final Color color;
  const _NewsTypeInfo(this.label, this.icon, this.color);
}

class NewsItem {
  final String id;
  final String newsType;
  final String title;
  final String content;
  final String? imageUrl;
  final String? authorName;
  final String? authorId;
  final bool isApproved;
  final DateTime? createdAt;

  NewsItem({
    required this.id,
    required this.newsType,
    required this.title,
    required this.content,
    this.imageUrl,
    this.authorName,
    this.authorId,
    required this.isApproved,
    this.createdAt,
  });

  factory NewsItem.fromJson(Map<String, dynamic> json) {
    return NewsItem(
      id: json['id'] as String? ?? '',
      newsType: (json['news_type'] as String? ?? 'general').toLowerCase(),
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
      imageUrl: json['image_url'] as String?,
      authorName: json['author_name'] as String?,
      authorId: json['author_id'] as String?,
      isApproved: json['is_approved'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
    );
  }

  String get typeLabel => _newsTypeInfo[newsType]?.label ?? newsType;
  IconData get typeIcon => _newsTypeInfo[newsType]?.icon ?? Icons.article;
  Color get typeColor => _newsTypeInfo[newsType]?.color ?? AppColors.primaryGreen;
}

class NewsScreen extends StatefulWidget {
  const NewsScreen({super.key});

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> {
  List<NewsItem> _allNews = [];
  List<NewsItem> _filteredNews = [];
  bool _isLoading = true;
  String? _error;
  String _selectedFilter = 'all';

  static const List<_FilterTab> _filters = [
    _FilterTab('all', 'الكل'),
    _FilterTab('general', 'أخبار عامة'),
    _FilterTab('events', 'مناسبات'),
    _FilterTab('births', 'ولادات'),
    _FilterTab('deaths', 'وفيات'),
  ];

  @override
  void initState() {
    super.initState();
    _loadNews();
  }

  Future<void> _loadNews() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final response = await SupabaseConfig.client
          .from('news')
          .select()
          .eq('is_approved', true)
          .order('created_at', ascending: false);

      final list = (response as List)
          .map((e) => NewsItem.fromJson(e as Map<String, dynamic>))
          .toList();

      setState(() {
        _allNews = list;
        _applyFilter();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _allNews = [];
        _filteredNews = [];
        _isLoading = false;
      });
    }
  }

  void _applyFilter() {
    if (_selectedFilter == 'all') {
      _filteredNews = List.from(_allNews);
    } else {
      _filteredNews =
          _allNews.where((n) => n.newsType == _selectedFilter).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      appBar: AppBar(
        title: const Text('الأخبار'),
        backgroundColor: AppColors.bgDeep,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildFilterTabs(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? _buildError()
                    : _filteredNews.isEmpty
                        ? _buildEmpty()
                        : RefreshIndicator(
                            onRefresh: _loadNews,
                            child: ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _filteredNews.length,
                              itemBuilder: (context, index) =>
                                  _buildNewsCard(_filteredNews[index]),
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTabs() {
    return Container(
      color: AppColors.bgCard,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: _filters.map((f) {
            final isSelected = _selectedFilter == f.value;
            return Padding(
              padding: const EdgeInsets.only(left: 8),
              child: FilterChip(
                label: Text(f.label),
                selected: isSelected,
                onSelected: (_) {
                  setState(() {
                    _selectedFilter = f.value;
                    _applyFilter();
                  });
                },
                selectedColor: AppColors.primaryGreen.withOpacity(0.3),
                checkmarkColor: AppColors.primaryGreen,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildNewsCard(NewsItem news) {
    final lines = news.content.split('\n');
    final preview = lines.take(2).join('\n').trim();
    final previewText =
        preview.length > 120 ? '${preview.substring(0, 120)}...' : preview;
    final hasImage =
        news.imageUrl != null && news.imageUrl!.isNotEmpty;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showNewsDetail(news),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: hasImage
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        news.imageUrl!,
                        width: 100,
                        height: 100,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            const SizedBox(width: 100, height: 100),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: news.typeColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              news.typeLabel,
                              style: TextStyle(
                                color: news.typeColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            news.title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              if (news.authorName != null &&
                                  news.authorName!.isNotEmpty)
                                Text(
                                  news.authorName!,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              if (news.authorName != null &&
                                  news.authorName!.isNotEmpty &&
                                  news.createdAt != null)
                                Text(
                                  ' • ',
                                  style: TextStyle(
                                      color: AppColors.textSecondary),
                                ),
                              if (news.createdAt != null)
                                Text(
                                  _formatDate(news.createdAt!),
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                            ],
                          ),
                          if (previewText.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              previewText,
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.textSecondary,
                                height: 1.5,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: news.typeColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        news.typeLabel,
                        style: TextStyle(
                          color: news.typeColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      news.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (news.authorName != null &&
                            news.authorName!.isNotEmpty)
                          Text(
                            news.authorName!,
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        if (news.authorName != null &&
                            news.authorName!.isNotEmpty &&
                            news.createdAt != null)
                          Text(
                            ' • ',
                            style: TextStyle(
                                color: AppColors.textSecondary),
                          ),
                        if (news.createdAt != null)
                          Text(
                            _formatDate(news.createdAt!),
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                      ],
                    ),
                    if (previewText.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        previewText,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                          height: 1.5,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 60) return 'قبل ${diff.inMinutes} دقيقة';
    if (diff.inHours < 24) return 'قبل ${diff.inHours} ساعة';
    if (diff.inDays == 1) return 'قبل يوم';
    if (diff.inDays < 7) return 'قبل ${diff.inDays} أيام';
    if (diff.inDays < 30) return 'قبل أسبوع';
    if (diff.inDays < 365) return 'قبل شهر';

    return '${date.year}/${date.month}/${date.day}';
  }

  void _showNewsDetail(NewsItem news) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 1,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.neutralGray,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (news.imageUrl != null &&
                          news.imageUrl!.isNotEmpty) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            news.imageUrl!,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                const SizedBox.shrink(),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                      Row(
                        children: [
                          Icon(news.typeIcon, color: news.typeColor, size: 22),
                          const SizedBox(width: 8),
                          Text(
                            news.typeLabel,
                            style: TextStyle(
                              color: news.typeColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        news.title,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          if (news.authorName != null &&
                              news.authorName!.isNotEmpty)
                            Text(
                              news.authorName!,
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 14,
                              ),
                            ),
                          if (news.authorName != null &&
                              news.authorName!.isNotEmpty &&
                              news.createdAt != null)
                            Text(
                              ' • ',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          if (news.createdAt != null)
                            Text(
                              _formatDate(news.createdAt!),
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 14,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text(
                        news.content,
                        style: TextStyle(
                          fontSize: 16,
                          height: 1.7,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.newspaper_outlined, size: 80, color: AppColors.textSecondary),
          const SizedBox(height: 16),
          Text(
            'لا توجد أخبار حالياً',
            style: TextStyle(
              fontSize: 18,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(
              'حدث خطأ في تحميل الأخبار',
              style: TextStyle(fontSize: 18, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _loadNews,
              child: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterTab {
  final String value;
  final String label;
  const _FilterTab(this.value, this.label);
}
