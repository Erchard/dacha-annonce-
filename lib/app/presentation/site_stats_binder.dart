import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers.dart';

/// Records siteStats on each GoRouter location change (public traffic).
class SiteStatsBinder extends ConsumerStatefulWidget {
  const SiteStatsBinder({super.key, required this.router, required this.child});
  final GoRouter router;
  final Widget child;

  @override
  ConsumerState<SiteStatsBinder> createState() => _SiteStatsBinderState();
}

class _SiteStatsBinderState extends ConsumerState<SiteStatsBinder> {
  String? _lastPath;

  @override
  void initState() {
    super.initState();
    widget.router.routerDelegate.addListener(_onRoute);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onRoute());
  }

  @override
  void didUpdateWidget(covariant SiteStatsBinder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.router != widget.router) {
      oldWidget.router.routerDelegate.removeListener(_onRoute);
      widget.router.routerDelegate.addListener(_onRoute);
    }
  }

  @override
  void dispose() {
    widget.router.routerDelegate.removeListener(_onRoute);
    super.dispose();
  }

  void _onRoute() {
    final path = widget.router.state.uri.path;
    if (path == _lastPath) return;
    _lastPath = path;
    unawaited(
      ref.read(siteStatsRepositoryProvider).recordNavigation(path).catchError((
        Object _,
      ) {
        // Undercount on write failure; admin UI surfaces read errors honestly.
      }),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
