import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/stats/site_stats_repository.dart';
import '../providers.dart';
import 'shared.dart';

class AdminStatisticsPage extends ConsumerStatefulWidget {
  const AdminStatisticsPage({super.key});
  @override
  ConsumerState<AdminStatisticsPage> createState() =>
      _AdminStatisticsPageState();
}

class _AdminStatisticsPageState extends ConsumerState<AdminStatisticsPage> {
  bool busy = true;
  Object? error;
  SiteStatsSummary? summary;

  @override
  void initState() {
    super.initState();
    Future.microtask(load);
  }

  Future<void> load() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final data = await ref.read(siteStatsRepositoryProvider).readSummary();
      if (!mounted) return;
      setState(() => summary = data);
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AppFrame(
    title: 'Статистика',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Відвідувачі та перегляди сторінок сайту. '
          'Це окремо від розділу «Аналітика», де звіти за опублікованими подіями. '
          'Відвідувач рахується один раз на браузер; перегляд — один раз на адресу за сесію вкладки.',
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: busy ? null : load,
            child: const Text('Оновити'),
          ),
        ),
        if (busy) const LinearProgressIndicator(),
        if (error != null) Problem(error!, retry: load),
        if (!busy && error == null && summary == null)
          const Text(
            'Ще немає даних. Лічильники з’являться після перших відвідувань сайту.',
          ),
        if (summary != null) ...[
          const SizedBox(height: 12),
          Text(
            'Відвідувачі: ${summary!.visitors}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Перегляди: ${summary!.pageViews}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ],
      ],
    ),
  );
}
