import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:solar_sales/features/auth/presentation/providers/auth_provider.dart';
import 'package:solar_sales/features/invoices/presentation/providers/invoice_providers.dart';
import 'package:solar_sales/features/module/presentation/providers/module_provider.dart';
import 'package:solar_sales/features/notifications/presentation/providers/notification_providers.dart';
import 'package:solar_sales/features/quotations/presentation/providers/quotation_providers.dart';
import 'package:solar_sales/features/shell/presentation/nav_destinations.dart';
import 'package:solar_sales/features/shell/presentation/shell_scope.dart';
import 'package:solar_sales/features/shell/presentation/widgets/app_drawer.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  int _index = 0;
  String? _lastModule;
  String? _activePushedRoute;
  bool _didPrecacheHeaders = false;

  static const _headerAssets = [
    'assets/images/solar_header.png',
    'assets/images/billbook_header.png',
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didPrecacheHeaders) return;
    _didPrecacheHeaders = true;
    for (final asset in _headerAssets) {
      precacheImage(AssetImage(asset), context);
    }
  }

  void _selectTab(int index, List<AppDestination> tabs) {
    if (index == _index || index < 0 || index >= tabs.length) return;
    setState(() {
      _index = index;
      _activePushedRoute = null;
    });
    final id = tabs[index].id;
    if (id == 'bb_quotes') {
      ref.read(quotationListProvider.notifier).refresh();
    } else if (id == 'bb_invoices') {
      ref.read(invoiceListProvider.notifier).refresh();
    }
  }

  Future<void> _onModuleChanged(String moduleId) async {
    await ref.read(moduleProvider.notifier).setActiveModule(moduleId);
    if (!mounted) return;
    setState(() {
      _index = 0;
      _activePushedRoute = null;
    });
  }

  void _onDestinationSelected(
    AppDestination dest,
    List<AppDestination> tabs,
  ) {
    if (dest.kind == NavKind.shellTab) {
      final i = tabs.indexWhere((t) => t.id == dest.id);
      if (i >= 0) _selectTab(i, tabs);
      return;
    }
    if (dest.route != null) {
      setState(() => _activePushedRoute = dest.route);
      Navigator.pushNamed(context, dest.route!).then((_) {
        if (!mounted) return;
        setState(() => _activePushedRoute = null);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final module = ref.watch(moduleProvider);
    final auth = ref.watch(authProvider);

    if (_lastModule != null && _lastModule != module.activeModule) {
      _index = 0;
    }
    _lastModule = module.activeModule;

    final tabs = NavDestinations.shellTabs(
      module.activeModule,
      auth.hasPermission,
    );
    if (_index >= tabs.length) _index = 0;
    final scheme = Theme.of(context).colorScheme;

    return ShellScope(
      scaffoldKey: _scaffoldKey,
      selectTab: (i) => _selectTab(i, tabs),
      selectedTabIndex: _index,
      child: Scaffold(
        key: _scaffoldKey,
        onDrawerChanged: (isOpen) {
          if (isOpen) {
            ref.invalidate(unreadNotificationCountProvider);
          }
        },
        drawer: AppDrawer(
          activeModule: module.activeModule,
          showModuleToggle: module.showToggle,
          onModuleChanged: _onModuleChanged,
          tabs: tabs,
          selectedTabIndex: _index,
          activeRoute: _activePushedRoute,
          onSelectDestination: (dest) => _onDestinationSelected(dest, tabs),
        ),
        body: IndexedStack(
          index: _index,
          children: [
            for (final tab in tabs) tab.screen ?? const SizedBox.shrink(),
          ],
        ),
        // Bottom nav removed — drawer + home quick actions are the nav surface.
        backgroundColor: scheme.surfaceContainerLowest,
      ),
    );
  }
}
