import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/repositories/medication_repository.dart';
import '../data/local/database.dart';

class DashboardState {
  final List<Medication> medications;
  final List<DoseEvent> todaysDoses;
  final bool isLoading;
  final String? error;

  const DashboardState({
    this.medications = const [],
    this.todaysDoses = const [],
    this.isLoading = true,
    this.error,
  });

  DashboardState copyWith({
    List<Medication>? medications,
    List<DoseEvent>? todaysDoses,
    bool? isLoading,
    String? error,
  }) {
    return DashboardState(
      medications: medications ?? this.medications,
      todaysDoses: todaysDoses ?? this.todaysDoses,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  int get takenCount => todaysDoses.where((d) => d.status == 'taken').length;
  int get totalCount => todaysDoses.length;
  int get remainingCount => totalCount - takenCount;
}

class DashboardNotifier extends StateNotifier<DashboardState> {
  final MedicationRepository _repo;

  DashboardNotifier(this._repo) : super(const DashboardState()) {
    refresh();
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final patientId = await _repo.ensureDefaultUserAndPatient();
      final medications = await _repo.getMedications(patientId);
      final todaysDoses = await _repo.getTodaysDoses(patientId);
      state = state.copyWith(
        medications: medications,
        todaysDoses: todaysDoses,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> confirmDose(int doseId, int medicationId) async {
    await _repo.confirmDose(doseId, medicationId);
    await refresh();
  }

  Future<void> snoozeDose(int doseId) async {
    await _repo.snoozeDose(doseId);
    await refresh();
  }

  Future<void> deleteMedication(int medicationId) async {
    await _repo.deleteMedication(medicationId);
    await refresh();
  }
}

final dashboardProvider =
    StateNotifierProvider<DashboardNotifier, DashboardState>((ref) {
  final repo = ref.read(medicationRepositoryProvider);
  return DashboardNotifier(repo);
});
