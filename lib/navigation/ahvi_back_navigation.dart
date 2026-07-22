import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const _navLogPrefix = 'AHVI_WARDROBE_NAV';

class AhviShellBackScope extends StatefulWidget {
  const AhviShellBackScope({
    super.key,
    required this.onBack,
    required this.child,
    this.onExitRequested,
  });

  final bool Function() onBack;
  final Widget child;
  final VoidCallback? onExitRequested;

  @override
  State<AhviShellBackScope> createState() => _AhviShellBackScopeState();
}

class _AhviShellBackScopeState extends State<AhviShellBackScope> {
  bool _backInProgress = false;
  final _transientRegistry = _TransientBackRegistry();

  @override
  void initState() {
    super.initState();
    debugPrint('$_navLogPrefix route_entry scope=main_shell');
  }

  void _onPopInvoked(bool didPop) {
    final navigatorCanPop = Navigator.of(context).canPop();
    final primaryFocus = FocusManager.instance.primaryFocus;
    final focusContext = primaryFocus?.context;
    final keyboardFocused = primaryFocus?.hasFocus == true &&
        focusContext != null &&
        (focusContext.widget is EditableText ||
            focusContext.findAncestorWidgetOfExactType<EditableText>() != null);
    debugPrint(
      '$_navLogPrefix back_received didPop=$didPop '
      'navigatorCanPop=$navigatorCanPop keyboardFocused=$keyboardFocused '
      'inProgress=$_backInProgress',
    );
    if (didPop) {
      debugPrint('$_navLogPrefix pop_completed result=route_popped');
      return;
    }
    if (_backInProgress) {
      if (_transientRegistry.hasActive) {
        _transientRegistry.suppressNextDismissal();
      }
      debugPrint('$_navLogPrefix pop_ignored reason=reentrant');
      return;
    }

    _backInProgress = true;
    debugPrint('$_navLogPrefix pop_started');
    if (keyboardFocused) {
      if (_transientRegistry.hasActive) {
        _transientRegistry.suppressNextDismissal();
      }
      primaryFocus?.unfocus();
      debugPrint('$_navLogPrefix keyboard_dismissal completed=true');
    } else if (_transientRegistry.hasActive) {
      debugPrint('$_navLogPrefix modal_dismissal delegated=true');
    } else {
      final handled = widget.onBack();
      if (!handled) {
        debugPrint('$_navLogPrefix pop_started target=system_exit');
        (widget.onExitRequested ?? SystemNavigator.pop).call();
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _backInProgress = false;
      debugPrint('$_navLogPrefix pop_completed result=handled');
    });
  }

  @override
  void dispose() {
    debugPrint('$_navLogPrefix dispose_started scope=main_shell');
    super.dispose();
    debugPrint('$_navLogPrefix dispose_completed scope=main_shell');
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) => _onPopInvoked(didPop),
      child: _AhviBackRegistry(
        registry: _transientRegistry,
        child: widget.child,
      ),
    );
  }
}

class AhviTransientBackScope extends StatefulWidget {
  const AhviTransientBackScope({
    super.key,
    required this.hasTransientUi,
    required this.onDismissTransientUi,
    required this.child,
  });

  final bool hasTransientUi;
  final VoidCallback onDismissTransientUi;
  final Widget child;

  @override
  State<AhviTransientBackScope> createState() =>
      _AhviTransientBackScopeState();
}

class _AhviTransientBackScopeState extends State<AhviTransientBackScope> {
  final Object _token = Object();
  _TransientBackRegistry? _registry;

  void _syncRegistration() {
    final nextRegistry = _AhviBackRegistry.maybeOf(context);
    if (!identical(_registry, nextRegistry)) {
      _registry?.remove(_token);
      _registry = nextRegistry;
    }
    if (widget.hasTransientUi) {
      _registry?.add(_token);
    } else {
      _registry?.remove(_token);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncRegistration();
  }

  @override
  void didUpdateWidget(covariant AhviTransientBackScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncRegistration();
  }

  @override
  void dispose() {
    _registry?.remove(_token);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !widget.hasTransientUi,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && widget.hasTransientUi) {
          if (_registry?.shouldDismissTransient() ?? true) {
            debugPrint('$_navLogPrefix modal_dismissal source=home_transient');
            widget.onDismissTransientUi();
          } else {
            debugPrint(
              '$_navLogPrefix modal_dismissal suppressed=keyboard_or_reentrant',
            );
          }
        }
      },
      child: widget.child,
    );
  }
}

class _TransientBackRegistry {
  final Set<Object> _active = <Object>{};
  bool _suppressNextDismissal = false;

  bool get hasActive => _active.isNotEmpty;

  void add(Object token) => _active.add(token);

  void remove(Object token) => _active.remove(token);

  void suppressNextDismissal() {
    _suppressNextDismissal = true;
  }

  bool shouldDismissTransient() {
    if (!_suppressNextDismissal) return true;
    _suppressNextDismissal = false;
    return false;
  }
}

class _AhviBackRegistry extends InheritedWidget {
  const _AhviBackRegistry({required this.registry, required super.child});

  final _TransientBackRegistry registry;

  static _TransientBackRegistry? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<_AhviBackRegistry>()
      ?.registry;

  @override
  bool updateShouldNotify(_AhviBackRegistry oldWidget) => false;
}
