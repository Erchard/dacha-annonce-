import 'package:flutter/material.dart';

class StatusScreen extends StatelessWidget {
  const StatusScreen({
    super.key,
    required this.title,
    required this.message,
    this.loading = false,
    this.action,
  });
  final String title, message;
  final bool loading;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Row(
        children: [
          Image.asset(
            'assets/brand/logo_mark.png',
            height: 32,
            width: 32,
            filterQuality: FilterQuality.high,
            semanticLabel: 'Дача',
          ),
          const SizedBox(width: 10),
          const Text('Дача'),
        ],
      ),
    ),
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/brand/logo_mark.png',
                height: 96,
                width: 96,
                filterQuality: FilterQuality.high,
                semanticLabel: 'Дача',
              ),
              const SizedBox(height: 20),
              if (loading)
                const Padding(
                  padding: EdgeInsets.only(bottom: 24),
                  child: CircularProgressIndicator(
                    semanticsLabel: 'Завантаження',
                  ),
                ),
              Text(
                title,
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(message, textAlign: TextAlign.center),
              if (action != null)
                Padding(padding: const EdgeInsets.only(top: 24), child: action),
            ],
          ),
        ),
      ),
    ),
  );
}
