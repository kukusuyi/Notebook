import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_environment.dart';
import '../../core/storage/app_settings_controller.dart';
import '../../shared/models/common_models.dart';
import '../../shared/models/dashboard_models.dart';
import '../../shared/models/question_models.dart';
import '../../shared/models/tag_models.dart';
import '../../shared/utils/draft_navigation.dart';
import '../../shared/utils/platform_ui.dart';
import '../question_create/question_draft_controller.dart';
import 'dashboard_repository.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(dashboardSnapshotProvider);
    final draft = ref.watch(questionDraftControllerProvider);
    final environment = ref.watch(appEnvironmentProvider);
    final settings = ref.watch(appSettingsControllerProvider);

    final currentBaseUrl = settings.apiBaseUrlOverride.isNotEmpty
        ? settings.apiBaseUrlOverride
        : environment.defaultApiBaseUrl;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(dashboardSnapshotProvider);
            await ref.read(dashboardSnapshotProvider.future);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            children: [
              Text(
                '错题仪表盘',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                '把录入、复盘和标签热点都放到首页，移动端也能直接进入复习节奏。',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              _QuickActionRow(
                onUpload: () => context.go(
                  hasActiveDraft(draft)
                      ? routeForDraft(draft!)
                      : '/questions/upload',
                ),
                onCreate: () => context.go(
                  hasActiveDraft(draft)
                      ? routeForDraft(draft!)
                      : '/questions/create',
                ),
                onList: () => context.go('/questions'),
              ),
              if (hasActiveDraft(draft)) ...[
                const SizedBox(height: 16),
                _DraftResumeCard(
                  draft: draft!,
                  onContinue: () => context.go(routeForDraft(draft)),
                  onDiscard: () => _discardDraft(context, ref),
                ),
              ],
              const SizedBox(height: 16),
              snapshot.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (error, stackTrace) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '仪表盘数据加载失败',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(height: 12),
                          Text(error.toString()),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: () => ref.invalidate(
                              dashboardSnapshotProvider,
                            ),
                            child: const Text('重试'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                data: (data) => _DashboardContent(
                  snapshot: data,
                  apiBaseUrl: currentBaseUrl,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _discardDraft(BuildContext context, WidgetRef ref) async {
    final confirmed = await showPlatformConfirmDialog(
      context: context,
      title: '丢弃草稿',
      message: '确定要丢弃当前草稿吗？丢弃后无法恢复。',
      confirmLabel: '确定丢弃',
      isDestructive: true,
    );

    if (!confirmed) {
      return;
    }

    ref.read(questionDraftControllerProvider.notifier).clear();
  }
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({
    required this.snapshot,
    required this.apiBaseUrl,
  });

  final DashboardSnapshot snapshot;
  final String apiBaseUrl;

  @override
  Widget build(BuildContext context) {
    final summary = snapshot.summary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StatsGrid(summary: summary),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final stacked = constraints.maxWidth < 760;
            if (stacked) {
              return Column(
                children: [
                  _DistributionCard(
                    title: '掌握状态分布',
                    subtitle: '点击状态可直达对应筛选列表。',
                    items: summary.masteryDistribution,
                    labelBuilder: (item) =>
                        _masteryLabel(item.type, item.count),
                    progressColor: const Color(0xFF0C7A5C),
                    onTap: (item) => context.go(
                      '/questions?mastery_status=${item.type}',
                    ),
                  ),
                  const SizedBox(height: 16),
                  _DistributionCard(
                    title: '来源分布',
                    subtitle: '快速查看手动录入、图片识别和导入题。',
                    items: summary.sourceDistribution,
                    labelBuilder: (item) => _sourceLabel(item.type, item.count),
                    progressColor: const Color(0xFFC5792A),
                    onTap: (item) => context.go(
                      '/questions?source_type=${item.type}',
                    ),
                  ),
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _DistributionCard(
                    title: '掌握状态分布',
                    subtitle: '点击状态可直达对应筛选列表。',
                    items: summary.masteryDistribution,
                    labelBuilder: (item) =>
                        _masteryLabel(item.type, item.count),
                    progressColor: const Color(0xFF0C7A5C),
                    onTap: (item) => context.go(
                      '/questions?mastery_status=${item.type}',
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _DistributionCard(
                    title: '来源分布',
                    subtitle: '快速查看手动录入、图片识别和导入题。',
                    items: summary.sourceDistribution,
                    labelBuilder: (item) => _sourceLabel(item.type, item.count),
                    progressColor: const Color(0xFFC5792A),
                    onTap: (item) => context.go(
                      '/questions?source_type=${item.type}',
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        _QuickLinksCard(
          onFocus: () => context.go('/questions?mastery_status=unmastered'),
          onUpload: () => context.go('/questions/upload'),
          onTags: () => context.go('/tags'),
        ),
        const SizedBox(height: 16),
        _RecentQuestionsCard(items: snapshot.recentQuestions),
        const SizedBox(height: 16),
        _TopTagsCard(tags: snapshot.topTags),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '环境信息',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 12),
                Text('API Base URL: $apiBaseUrl'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _masteryLabel(String value, int count) {
    final label = switch (value) {
      'mastered' => '已掌握',
      'learning' => '学习中',
      _ => '未掌握',
    };
    return '$label · $count';
  }

  String _sourceLabel(String value, int count) {
    final label = switch (value) {
      'image' => '图片识别',
      'import' => '导入',
      _ => '手动录入',
    };
    return '$label · $count';
  }
}

class _QuickActionRow extends StatelessWidget {
  const _QuickActionRow({
    required this.onUpload,
    required this.onCreate,
    required this.onList,
  });

  final VoidCallback onUpload;
  final VoidCallback onCreate;
  final VoidCallback onList;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        FilledButton.icon(
          onPressed: onUpload,
          icon: const Icon(Icons.photo_camera_outlined),
          label: const Text('拍照 / 相册上传'),
        ),
        FilledButton.tonalIcon(
          onPressed: onCreate,
          icon: const Icon(Icons.edit_note_outlined),
          label: const Text('手动录入'),
        ),
        FilledButton.tonalIcon(
          onPressed: onList,
          icon: const Icon(Icons.list_alt_outlined),
          label: const Text('查看题库'),
        ),
      ],
    );
  }
}

class _DraftResumeCard extends StatelessWidget {
  const _DraftResumeCard({
    required this.draft,
    required this.onContinue,
    required this.onDiscard,
  });

  final QuestionDraft draft;
  final VoidCallback onContinue;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) {
    final modeLabel = draft.flowMode == DraftFlowMode.upload ? '图片上传' : '手动录入';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '发现未完成草稿',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Text('模式：$modeLabel · 状态：${draft.status.value}'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: onContinue,
                    child: const Text('继续处理'),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: onDiscard,
                  child: const Text('丢弃草稿'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({
    required this.summary,
  });

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final items = [
      _StatCardData(
        label: '错题总数',
        value: '${summary.totalQuestions}',
        description: '当前库内已沉淀的正式错题数量。',
        badge: '总览',
        onTap: () => context.go('/questions'),
      ),
      _StatCardData(
        label: '今日新增',
        value: '${summary.todayAdded}',
        description: '按服务端当天创建时间实时汇总。',
        badge: 'Today',
      ),
      _StatCardData(
        label: '待掌握',
        value: '${summary.unmasteredCount}',
        description: '建议优先从这里进入复盘节奏。',
        badge: 'Focus',
        onTap: () => context.go('/questions?mastery_status=unmastered'),
      ),
      _StatCardData(
        label: '已绑定图片',
        value: '${summary.imageBoundCount}',
        description: '适合回看纸面上下文。',
        badge: 'Image',
        onTap: () => context.go('/questions?source_type=image'),
      ),
      _StatCardData(
        label: '活跃标签',
        value: '${summary.activeTagCount}',
        description: '当前启用中的标签定义总数。',
        badge: 'Tags',
        onTap: () => context.go('/tags'),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 1120
            ? 5
            : width >= 820
                ? 3
                : 2;
        final itemWidth = (width - (columns - 1) * 12) / columns;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: items
              .map(
                (item) => SizedBox(
                  width: itemWidth,
                  child: _StatCard(item: item),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _StatCardData {
  const _StatCardData({
    required this.label,
    required this.value,
    required this.description,
    required this.badge,
    this.onTap,
  });

  final String label;
  final String value;
  final String description;
  final String badge;
  final VoidCallback? onTap;
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.item,
  });

  final _StatCardData item;

  @override
  Widget build(BuildContext context) {
    final child = Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF5E6A65),
                      ),
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFFE2F3ED),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: Text(
                    item.badge,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: const Color(0xFF0C7A5C),
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            item.value,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0C7A5C),
                ),
          ),
          const SizedBox(height: 10),
          Text(
            item.description,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF5E6A65),
                ),
          ),
        ],
      ),
    );

    return Card(
      child: item.onTap == null
          ? child
          : InkWell(
              onTap: item.onTap,
              borderRadius: BorderRadius.circular(24),
              child: child,
            ),
    );
  }
}

class _DistributionCard extends StatelessWidget {
  const _DistributionCard({
    required this.title,
    required this.subtitle,
    required this.items,
    required this.labelBuilder,
    required this.progressColor,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final List<DashboardDistributionItem> items;
  final String Function(DashboardDistributionItem item) labelBuilder;
  final Color progressColor;
  final ValueChanged<DashboardDistributionItem> onTap;

  @override
  Widget build(BuildContext context) {
    final maxCount = items.fold<int>(
      0,
      (current, item) => item.count > current ? item.count : current,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 6),
            Text(subtitle),
            const SizedBox(height: 16),
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  onTap: () => onTap(item),
                  borderRadius: BorderRadius.circular(18),
                  child: Ink(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFD9E2DC)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(child: Text(labelBuilder(item))),
                            Text(
                              '${item.count}',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            minHeight: 10,
                            value: maxCount <= 0 ? 0 : item.count / maxCount,
                            backgroundColor: const Color(0xFFE9EFEB),
                            color: progressColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickLinksCard extends StatelessWidget {
  const _QuickLinksCard({
    required this.onFocus,
    required this.onUpload,
    required this.onTags,
  });

  final VoidCallback onFocus;
  final VoidCallback onUpload;
  final VoidCallback onTags;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '快捷入口',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 6),
            const Text('把最常用的动作放在首页，减少来回切换。'),
            const SizedBox(height: 16),
            _QuickLinkTile(
              title: '进入待掌握列表',
              subtitle: '优先处理还没吃透的题目',
              highlighted: true,
              onTap: onFocus,
            ),
            const SizedBox(height: 12),
            _QuickLinkTile(
              title: '继续上传识别',
              subtitle: '把纸面错题尽快沉淀进系统',
              onTap: onUpload,
            ),
            const SizedBox(height: 12),
            _QuickLinkTile(
              title: '整理标签体系',
              subtitle: '统一知识点与错因命名口径',
              onTap: onTags,
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickLinkTile extends StatelessWidget {
  const _QuickLinkTile({
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.highlighted = false,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: highlighted
                ? const Color(0xFFB8DCCD)
                : const Color(0xFFD9E2DC),
          ),
          color: highlighted ? const Color(0xFFEAF7F2) : Colors.white,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 4),
            Text(subtitle),
          ],
        ),
      ),
    );
  }
}

class _RecentQuestionsCard extends StatelessWidget {
  const _RecentQuestionsCard({
    required this.items,
  });

  final List<QuestionListItem> items;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '最近错题',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => context.go('/questions'),
                  child: const Text('查看全部'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text('最近录入的 4 道题会出现在这里，方便快速回到刚整理过的内容。'),
            const SizedBox(height: 16),
            if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(child: Text('还没有错题数据，先去录入第一道题吧。')),
              )
            else
              ...items.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    tileColor: const Color(0xFFF8FAF8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    contentPadding: const EdgeInsets.all(16),
                    title: Text(
                      item.questionCore,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        '${item.subject} · ${item.chapter}\n掌握状态：${item.masteryStatus.label}',
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/questions/${item.questionId}'),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TopTagsCard extends StatelessWidget {
  const _TopTagsCard({
    required this.tags,
  });

  final DashboardTopTags tags;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '标签热点',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => context.go('/tags'),
                  child: const Text('管理标签'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text('按知识点和错因拆分，便于识别“考点密度”和“失误模式”。'),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final stacked = constraints.maxWidth < 760;
                if (stacked) {
                  return Column(
                    children: [
                      _TagGroupPanel(
                        title: '高频知识点',
                        items: tags.knowledgePoints,
                        onTap: (item) => context.go(
                          '/questions?tag_ids=${item.tagId}&tag_name=${Uri.encodeComponent(item.tagName)}',
                        ),
                      ),
                      const SizedBox(height: 12),
                      _TagGroupPanel(
                        title: '高频错因',
                        items: tags.mistakeReasons,
                        accent: true,
                        onTap: (item) => context.go(
                          '/questions?tag_ids=${item.tagId}&tag_name=${Uri.encodeComponent(item.tagName)}',
                        ),
                      ),
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _TagGroupPanel(
                        title: '高频知识点',
                        items: tags.knowledgePoints,
                        onTap: (item) => context.go(
                          '/questions?tag_ids=${item.tagId}&tag_name=${Uri.encodeComponent(item.tagName)}',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _TagGroupPanel(
                        title: '高频错因',
                        items: tags.mistakeReasons,
                        accent: true,
                        onTap: (item) => context.go(
                          '/questions?tag_ids=${item.tagId}&tag_name=${Uri.encodeComponent(item.tagName)}',
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _TagGroupPanel extends StatelessWidget {
  const _TagGroupPanel({
    required this.title,
    required this.items,
    required this.onTap,
    this.accent = false,
  });

  final String title;
  final List<TagItem> items;
  final ValueChanged<TagItem> onTap;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final borderColor =
        accent ? const Color(0xFFF0D5BF) : const Color(0xFFD9E9E2);
    final backgroundColor =
        accent ? const Color(0xFFFFF5EB) : const Color(0xFFF0F9F5);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
        color: backgroundColor,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 12),
            if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: Text('暂无标签数据')),
              )
            else
              ...items.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: InkWell(
                    onTap: () => onTap(item),
                    borderRadius: BorderRadius.circular(16),
                    child: Ink(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                      child: Row(
                        children: [
                          Expanded(child: Text(item.tagName)),
                          Text(
                            '${item.usageCount}',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
