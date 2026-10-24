import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../web/share_actions.dart';

bool _wantsNewTab(PointerDownEvent event) =>
    event.buttons == kMiddleMouseButton ||
    HardwareKeyboard.instance.isControlPressed ||
    HardwareKeyboard.instance.isMetaPressed;

void navigateApp(BuildContext context, String to, {bool newTab = false}) {
  final path = to.startsWith('/') ? to : '/$to';
  if (newTab && kIsWeb) {
    openExternalUrl('${Uri.base.origin}$path');
    return;
  }
  context.go(path);
}

/// Navigation control: normal click same tab; Ctrl/⌘/middle-click opens a new tab on web.
class AppLink extends StatefulWidget {
  const AppLink({
    super.key,
    required this.to,
    required this.child,
    this.outlined = false,
    this.filled = false,
    this.icon,
    this.style,
  });

  final String to;
  final Widget child;
  final bool outlined;
  final bool filled;
  final Widget? icon;
  final ButtonStyle? style;

  @override
  State<AppLink> createState() => _AppLinkState();
}

class _AppLinkState extends State<AppLink> {
  bool _openedNewTab = false;

  void _onPressed() {
    if (_openedNewTab) {
      _openedNewTab = false;
      return;
    }
    navigateApp(context, widget.to);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (event) {
        if (_wantsNewTab(event)) {
          _openedNewTab = true;
          navigateApp(context, widget.to, newTab: true);
        }
      },
      child: Builder(
        builder: (context) {
          if (widget.icon != null) {
            if (widget.filled) {
              return FilledButton.icon(
                onPressed: _onPressed,
                style: widget.style,
                icon: widget.icon!,
                label: widget.child,
              );
            }
            if (widget.outlined) {
              return OutlinedButton.icon(
                onPressed: _onPressed,
                style: widget.style,
                icon: widget.icon!,
                label: widget.child,
              );
            }
            return TextButton.icon(
              onPressed: _onPressed,
              style: widget.style,
              icon: widget.icon!,
              label: widget.child,
            );
          }
          if (widget.filled) {
            return FilledButton(
              onPressed: _onPressed,
              style: widget.style,
              child: widget.child,
            );
          }
          if (widget.outlined) {
            return OutlinedButton(
              onPressed: _onPressed,
              style: widget.style,
              child: widget.child,
            );
          }
          return TextButton(
            onPressed: _onPressed,
            style: widget.style,
            child: widget.child,
          );
        },
      ),
    );
  }
}

/// Wraps any tappable child so Ctrl/⌘/middle-click open a new tab on web.
class AppLinkTap extends StatefulWidget {
  const AppLinkTap({
    super.key,
    required this.to,
    required this.builder,
  });

  final String to;
  final Widget Function(BuildContext context, VoidCallback? onTap) builder;

  @override
  State<AppLinkTap> createState() => _AppLinkTapState();
}

class _AppLinkTapState extends State<AppLinkTap> {
  bool _openedNewTab = false;

  void _onTap() {
    if (_openedNewTab) {
      _openedNewTab = false;
      return;
    }
    navigateApp(context, widget.to);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (event) {
        if (_wantsNewTab(event)) {
          _openedNewTab = true;
          navigateApp(context, widget.to, newTab: true);
        }
      },
      child: widget.builder(context, _onTap),
    );
  }
}
