import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/appointment_model.dart';
import '../services/appointment_repository.dart';

/// Provider for the Appointment Repository interface.
/// Switch this single provider line to `HttpAppointmentRepository` when connecting to a live backend API!
final appointmentRepositoryProvider = Provider<IAppointmentRepository>((ref) {
  return MockAppointmentRepository();
});

/// List of default hospital & clinic partners
final hospitalPartnersProvider = FutureProvider<List<HospitalClinic>>((ref) async {
  final repository = ref.watch(appointmentRepositoryProvider);
  return repository.fetchHospitals();
});

/// List of all doctors from repository
final doctorsListProvider = FutureProvider<List<DoctorProfile>>((ref) async {
  final repository = ref.watch(appointmentRepositoryProvider);
  return repository.fetchDoctors();
});

/// Selected specialty filter notifier
class SpecialtyFilterNotifier extends Notifier<String> {
  @override
  String build() => 'All';

  void setFilter(String specialty) => state = specialty;
}

final selectedSpecialtyFilterProvider = NotifierProvider<SpecialtyFilterNotifier, String>(() {
  return SpecialtyFilterNotifier();
});

/// Selected hospital filter notifier
class HospitalFilterNotifier extends Notifier<String> {
  @override
  String build() => 'All';

  void setFilter(String hospital) => state = hospital;
}

final selectedHospitalFilterProvider = NotifierProvider<HospitalFilterNotifier, String>(() {
  return HospitalFilterNotifier();
});

/// Search query notifier
class DoctorSearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String query) => state = query;
}

final doctorSearchQueryProvider = NotifierProvider<DoctorSearchQueryNotifier, String>(() {
  return DoctorSearchQueryNotifier();
});

/// Filtered list of doctors based on repository queries
final filteredDoctorsProvider = FutureProvider<List<DoctorProfile>>((ref) async {
  final repository = ref.watch(appointmentRepositoryProvider);
  final selectedSpecialty = ref.watch(selectedSpecialtyFilterProvider);
  final selectedHospital = ref.watch(selectedHospitalFilterProvider);
  final query = ref.watch(doctorSearchQueryProvider);

  return repository.fetchDoctors(
    specialty: selectedSpecialty,
    hospitalName: selectedHospital,
    query: query,
  );
});

/// Appointments Notifier managing user's booked appointments via repository
class AppointmentsNotifier extends AsyncNotifier<List<AppointmentBooking>> {
  @override
  Future<List<AppointmentBooking>> build() async {
    final repository = ref.watch(appointmentRepositoryProvider);
    return repository.fetchUserAppointments();
  }

  /// Book a new appointment
  Future<AppointmentBooking> bookAppointment({
    required DoctorProfile doctor,
    required ConsultationType type,
    required DateTime date,
    required String timeSlot,
    required String reasonNotes,
    required String patientName,
    required String patientPhone,
    String? insuranceId,
  }) async {
    final repository = ref.read(appointmentRepositoryProvider);
    state = const AsyncValue.loading();
    try {
      final booking = await repository.bookAppointment(
        doctor: doctor,
        type: type,
        date: date,
        timeSlot: timeSlot,
        reasonNotes: reasonNotes,
        patientName: patientName,
        patientPhone: patientPhone,
        insuranceId: insuranceId,
      );

      final updatedList = await repository.fetchUserAppointments();
      state = AsyncValue.data(updatedList);
      return booking;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Cancel an appointment
  Future<void> cancelAppointment(String appointmentId, {String? reason}) async {
    final repository = ref.read(appointmentRepositoryProvider);
    try {
      await repository.cancelAppointment(appointmentId, reason: reason);
      final updatedList = await repository.fetchUserAppointments();
      state = AsyncValue.data(updatedList);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Reschedule an appointment
  Future<void> rescheduleAppointment(String appointmentId, DateTime newDate, String newTimeSlot) async {
    final repository = ref.read(appointmentRepositoryProvider);
    try {
      await repository.rescheduleAppointment(appointmentId, newDate, newTimeSlot);
      final updatedList = await repository.fetchUserAppointments();
      state = AsyncValue.data(updatedList);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

final userAppointmentsProvider = AsyncNotifierProvider<AppointmentsNotifier, List<AppointmentBooking>>(() {
  return AppointmentsNotifier();
});
