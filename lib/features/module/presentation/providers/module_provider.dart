import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:solar_sales/shared/module/module_access.dart';

class ModuleState {
  final String activeModule;
  final bool canBillbook;
  final bool canSolar;
  final bool companyBillbook;
  final bool companySolar;
  final bool platformAdmin;
  final bool ready;

  const ModuleState({
    this.activeModule = AppModules.billbook,
    this.canBillbook = false,
    this.canSolar = false,
    this.companyBillbook = true,
    this.companySolar = true,
    this.platformAdmin = false,
    this.ready = false,
  });

  bool get isBillbook => activeModule == AppModules.billbook;
  bool get isSolar => activeModule == AppModules.solar;
  bool get showToggle => canBillbook && canSolar;
  String get homeRoute => moduleHomeRoute(activeModule);
  String get label => ModuleLabels.of(activeModule);

  ModuleState copyWith({
    String? activeModule,
    bool? canBillbook,
    bool? canSolar,
    bool? companyBillbook,
    bool? companySolar,
    bool? platformAdmin,
    bool? ready,
  }) {
    return ModuleState(
      activeModule: activeModule ?? this.activeModule,
      canBillbook: canBillbook ?? this.canBillbook,
      canSolar: canSolar ?? this.canSolar,
      companyBillbook: companyBillbook ?? this.companyBillbook,
      companySolar: companySolar ?? this.companySolar,
      platformAdmin: platformAdmin ?? this.platformAdmin,
      ready: ready ?? this.ready,
    );
  }
}

final moduleProvider = NotifierProvider<ModuleNotifier, ModuleState>(
  ModuleNotifier.new,
);

class ModuleNotifier extends Notifier<ModuleState> {
  @override
  ModuleState build() => const ModuleState();

  Future<void> syncFromAuth({
    required List<String> permissions,
    required String role,
    required bool companyBillbook,
    required bool companySolar,
    required bool companyAdmin,
    required bool platformAdmin,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(storageModuleKey);

    final canBillbook = (platformAdmin || companyBillbook) &&
        (companyAdmin ||
            platformAdmin ||
            hasAnyPerm(permissions, billbookPerms));
    final canSolar = companySolar &&
        (companyAdmin || hasAnyPerm(permissions, solarPerms));

    final preferred = resolvePreferredModule(
      permissions: permissions,
      role: role,
      stored: stored,
      companyBillbook: companyBillbook,
      companySolar: companySolar,
      companyAdmin: companyAdmin,
      platformAdmin: platformAdmin,
    );

    var next = preferred;
    if (next == AppModules.solar && !canSolar && canBillbook) {
      next = AppModules.billbook;
    } else if (next == AppModules.billbook && !canBillbook && canSolar) {
      next = AppModules.solar;
    }

    await prefs.setString(storageModuleKey, next);
    state = ModuleState(
      activeModule: next,
      canBillbook: canBillbook,
      canSolar: canSolar,
      companyBillbook: companyBillbook,
      companySolar: companySolar,
      platformAdmin: platformAdmin,
      ready: true,
    );
  }

  Future<void> setActiveModule(
    String moduleId, {
    bool navigateHome = false,
  }) async {
    final next = normalizeProductModule(moduleId) ?? moduleId;
    final allowed = next == AppModules.solar
        ? state.canSolar
        : next == AppModules.billbook
            ? (state.canBillbook || state.platformAdmin)
            : false;
    if (!allowed) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(storageModuleKey, next);
    state = state.copyWith(activeModule: next);
  }
}
