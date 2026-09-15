import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:solar_sales/features/shell/presentation/shell_scope.dart';
import 'package:solar_sales/shared/widgets/app_bar.dart';

void main() {
  testWidgets(
    'hamburger stays visible after switching to dark mode with drawer open',
    (tester) async {
      final scaffoldKey = GlobalKey<ScaffoldState>();
      var brightness = Brightness.light;

      await tester.pumpWidget(
        _ThemeHost(
          brightness: brightness,
          scaffoldKey: scaffoldKey,
        ),
      );

      expect(find.byTooltip('Menu'), findsOneWidget);

      scaffoldKey.currentState!.openDrawer();
      await tester.pumpAndSettle();
      expect(find.text('Drawer'), findsOneWidget);

      brightness = Brightness.dark;
      await tester.pumpWidget(
        _ThemeHost(
          brightness: brightness,
          scaffoldKey: scaffoldKey,
        ),
      );
      await tester.pump();

      Navigator.of(scaffoldKey.currentContext!).pop();
      await tester.pumpAndSettle();

      expect(find.byTooltip('Menu'), findsOneWidget);
      expect(find.text('Billbook'), findsOneWidget);
    },
  );
}

class _ThemeHost extends StatelessWidget {
  const _ThemeHost({
    required this.brightness,
    required this.scaffoldKey,
  });

  final Brightness brightness;
  final GlobalKey<ScaffoldState> scaffoldKey;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(brightness: Brightness.light, useMaterial3: true),
      darkTheme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
      themeMode:
          brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
      home: ShellScope(
        scaffoldKey: scaffoldKey,
        selectedTabIndex: 0,
        child: Scaffold(
          key: scaffoldKey,
          drawer: const Drawer(child: Text('Drawer')),
          appBar: const AppAppBar(title: 'Billbook', largeTitle: true),
          body: const SizedBox.expand(),
        ),
      ),
    );
  }
}
