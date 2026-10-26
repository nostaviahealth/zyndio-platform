import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/appointment_model.dart';

const String _kAppointmentsStorageKey = 'zyndio_user_appointments_v2';

/// Custom Exception types for robust error handling in real integrations
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  ApiException(this.message, [this.statusCode]);

  @override
  String toString() => 'ApiException ($statusCode): $message';
}

class SlotUnavailableException implements Exception {
  final String message;
  SlotUnavailableException([this.message = 'Selected time slot is no longer available.']);
}

/// Abstract contract interface for appointment operations.
/// Implementing this interface allows swapping local mock, Firebase, or real REST APIs with zero UI changes.
abstract class IAppointmentRepository {
  Future<List<DoctorProfile>> fetchDoctors({String? specialty, String? hospitalName, String? query});
  Future<List<HospitalClinic>> fetchHospitals();
  Future<List<AppointmentBooking>> fetchUserAppointments();
  Future<AppointmentBooking> bookAppointment({
    required DoctorProfile doctor,
    required ConsultationType type,
    required DateTime date,
    required String timeSlot,
    required String reasonNotes,
    required String patientName,
    required String patientPhone,
    String? insuranceId,
  });
  Future<void> cancelAppointment(String appointmentId, {String? reason});
  Future<void> rescheduleAppointment(String appointmentId, DateTime newDate, String newTimeSlot);
}

/// Production Mock Repository with realistic network delay and local storage persistence
class MockAppointmentRepository implements IAppointmentRepository {
  final List<DoctorProfile> _doctors;
  final List<HospitalClinic> _hospitals;

  MockAppointmentRepository({
    List<DoctorProfile>? doctors,
    List<HospitalClinic>? hospitals,
  })  : _doctors = doctors ?? _defaultMockDoctors,
        _hospitals = hospitals ?? _defaultMockHospitals;

  @override
  Future<List<DoctorProfile>> fetchDoctors({String? specialty, String? hospitalName, String? query}) async {
    // Simulate real network request latency
    await Future.delayed(const Duration(milliseconds: 350));
    final q = query?.toLowerCase().trim() ?? '';

    return _doctors.where((doc) {
      final matchesSpecialty = specialty == null || specialty == 'All' || doc.specialty == specialty;
      final matchesHospital = hospitalName == null || hospitalName == 'All' || doc.hospitalName == hospitalName;
      final matchesQuery = q.isEmpty ||
          doc.name.toLowerCase().contains(q) ||
          doc.specialty.toLowerCase().contains(q) ||
          doc.hospitalName.toLowerCase().contains(q) ||
          doc.bio.toLowerCase().contains(q);

      return matchesSpecialty && matchesHospital && matchesQuery;
    }).toList();
  }

  @override
  Future<List<HospitalClinic>> fetchHospitals() async {
    await Future.delayed(const Duration(milliseconds: 200));
    return _hospitals;
  }

  @override
  Future<List<AppointmentBooking>> fetchUserAppointments() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_kAppointmentsStorageKey);
      if (jsonString != null && jsonString.isNotEmpty) {
        final List<dynamic> list = jsonDecode(jsonString);
        return list.map((e) => AppointmentBooking.fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      debugPrint('⚠️ Error reading appointment cache: $e');
    }

    // Default sample appointment if empty
    final initialBooking = AppointmentBooking(
      id: 'apt_demo_01',
      doctorId: 'doc_101',
      doctorName: 'Dr. Evelyn Vance',
      doctorTitle: 'MD, PhD',
      doctorAvatarUrl: 'https://images.unsplash.com/photo-1559839734-2b71ea197ec2?w=400',
      specialty: 'Longevity & Anti-Aging',
      hospitalName: 'Zyndio Longevity Institute',
      type: ConsultationType.inPerson,
      appointmentDate: DateTime.now().add(const Duration(days: 1)),
      timeSlot: '02:30 PM',
      reasonNotes: 'Biomarker review & NAD+ cellular protocol consultation.',
      feePaid: 220.0,
      status: AppointmentStatus.confirmed,
      locationAddress: 'Zyndio Longevity Wing, Suite 501, 100 Health Plaza',
      createdAt: DateTime.now().subtract(const Duration(hours: 4)),
      patientName: 'Alexander Wright',
      patientPhone: '+1 (555) 234-5678',
      qrPassCode: 'PASS-8849-NX',
    );

    final defaultList = [initialBooking];
    _saveAppointmentsToStorage(defaultList);
    return defaultList;
  }

  @override
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
    // Simulate backend server latency
    await Future.delayed(const Duration(milliseconds: 600));

    final newId = 'apt_${DateTime.now().millisecondsSinceEpoch}';
    final booking = AppointmentBooking(
      id: newId,
      doctorId: doctor.id,
      doctorName: doctor.name,
      doctorTitle: doctor.title,
      doctorAvatarUrl: doctor.avatarUrl,
      specialty: doctor.specialty,
      hospitalName: doctor.hospitalName,
      type: type,
      appointmentDate: date,
      timeSlot: timeSlot,
      reasonNotes: reasonNotes.isEmpty ? 'General Longevity & Health Review' : reasonNotes,
      feePaid: doctor.consultationFee,
      status: AppointmentStatus.confirmed,
      videoCallUrl: type == ConsultationType.telehealth ? 'https://meet.zyndio.health/room/$newId' : null,
      locationAddress: type == ConsultationType.inPerson
          ? doctor.locationAddress
          : (type == ConsultationType.telehealth ? 'Virtual Telehealth Room' : 'Registered Home Address'),
      createdAt: DateTime.now(),
      patientName: patientName.isEmpty ? 'Alexander Wright' : patientName,
      patientPhone: patientPhone.isEmpty ? '+1 (555) 234-5678' : patientPhone,
      insuranceId: insuranceId,
      qrPassCode: 'PASS-${newId.substring(newId.length - 6)}',
    );

    final current = await fetchUserAppointments();
    final updated = [booking, ...current];
    await _saveAppointmentsToStorage(updated);
    return booking;
  }

  @override
  Future<void> cancelAppointment(String appointmentId, {String? reason}) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final current = await fetchUserAppointments();
    final updated = current.map((apt) {
      if (apt.id == appointmentId) {
        return apt.copyWith(
          status: AppointmentStatus.cancelled,
          cancellationReason: reason ?? 'User requested cancellation',
        );
      }
      return apt;
    }).toList();

    await _saveAppointmentsToStorage(updated);
  }

  @override
  Future<void> rescheduleAppointment(String appointmentId, DateTime newDate, String newTimeSlot) async {
    await Future.delayed(const Duration(milliseconds: 400));
    final current = await fetchUserAppointments();
    final updated = current.map((apt) {
      if (apt.id == appointmentId) {
        return apt.copyWith(
          appointmentDate: newDate,
          timeSlot: newTimeSlot,
          status: AppointmentStatus.rescheduled,
        );
      }
      return apt;
    }).toList();

    await _saveAppointmentsToStorage(updated);
  }

  Future<void> _saveAppointmentsToStorage(List<AppointmentBooking> list) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final listJson = list.map((e) => e.toJson()).toList();
      await prefs.setString(_kAppointmentsStorageKey, jsonEncode(listJson));
    } catch (e) {
      debugPrint('⚠️ Error persisting appointments: $e');
    }
  }
}

/// Default Mock Doctors List
final List<DoctorProfile> _defaultMockDoctors = const [
  DoctorProfile(
    id: 'doc_101',
    name: 'Dr. Evelyn Vance',
    title: 'MD, PhD',
    specialty: 'Longevity & Anti-Aging',
    hospitalName: 'Zyndio Longevity Institute',
    rating: 4.98,
    reviewCount: 342,
    experienceYears: 16,
    consultationFee: 220.0,
    avatarUrl: 'https://images.unsplash.com/photo-1559839734-2b71ea197ec2?w=400',
    bio: 'Leading researcher in cellular senescence, NAD+ metabolic therapy, and personalized lifespan extension protocols.',
    nextAvailableSlot: 'Today, 2:30 PM',
    supportedTypes: [ConsultationType.inPerson, ConsultationType.telehealth, ConsultationType.atHome],
    availableTimeSlots: ['09:00 AM', '11:15 AM', '02:30 PM', '04:00 PM'],
    locationAddress: 'Zyndio Longevity Wing, Suite 501',
  ),
  DoctorProfile(
    id: 'doc_102',
    name: 'Dr. Marcus Thorne',
    title: 'MD, FACC',
    specialty: 'Preventive Cardiology',
    hospitalName: 'Mayo Clinic Partner Hub',
    rating: 4.92,
    reviewCount: 218,
    experienceYears: 18,
    consultationFee: 250.0,
    avatarUrl: 'https://images.unsplash.com/photo-1622253692010-333f2da6031d?w=400',
    bio: 'Specialist in advanced lipidomics, coronary calcium scoring, and VO2 max endurance training.',
    nextAvailableSlot: 'Tomorrow, 10:00 AM',
    supportedTypes: [ConsultationType.inPerson, ConsultationType.telehealth],
    availableTimeSlots: ['10:00 AM', '01:30 PM', '03:15 PM'],
    locationAddress: 'Cardiovascular Pavilion, Suite 302',
  ),
  DoctorProfile(
    id: 'doc_103',
    name: 'Dr. Sophia Chen',
    title: 'MD, ND',
    specialty: 'Metabolic & Functional Medicine',
    hospitalName: 'Johns Hopkins Longevity Center',
    rating: 4.96,
    reviewCount: 189,
    experienceYears: 12,
    consultationFee: 195.0,
    avatarUrl: 'https://images.unsplash.com/photo-1594824813566-88855ce78964?w=400',
    bio: 'Focuses on insulin sensitivity restoration, continuous glucose monitoring (CGM), and microbiome rejuvenation.',
    nextAvailableSlot: 'Today, 4:30 PM',
    supportedTypes: [ConsultationType.inPerson, ConsultationType.telehealth, ConsultationType.atHome],
    availableTimeSlots: ['09:30 AM', '12:00 PM', '02:00 PM', '04:30 PM'],
    locationAddress: 'Metabolic Health Center, Tower B',
  ),
  DoctorProfile(
    id: 'doc_104',
    name: 'Dr. Alexander Hayes',
    title: 'MD, PhD',
    specialty: 'Neurology & Cognitive Longevity',
    hospitalName: 'Cleveland Clinic Executive Health',
    rating: 4.95,
    reviewCount: 275,
    experienceYears: 20,
    consultationFee: 280.0,
    avatarUrl: 'https://images.unsplash.com/photo-1537368910025-700350fe46c7?w=400',
    bio: 'Expert in neuro-regenerative medicine, sleep architecture optimization, and dementia risk prevention.',
    nextAvailableSlot: 'Tomorrow, 11:30 AM',
    supportedTypes: [ConsultationType.inPerson, ConsultationType.telehealth],
    availableTimeSlots: ['08:30 AM', '11:30 AM', '03:00 PM'],
    locationAddress: 'Neuro-Science Center, Level 4',
  ),
  DoctorProfile(
    id: 'doc_105',
    name: 'Dr. Elena Rostova',
    title: 'MD, FACN',
    specialty: 'Genomics & Peptide Therapy',
    hospitalName: 'Zyndio Longevity Institute',
    rating: 4.99,
    reviewCount: 410,
    experienceYears: 14,
    consultationFee: 235.0,
    avatarUrl: 'https://images.unsplash.com/photo-1559839734-2b71ea197ec2?w=400',
    bio: 'Pioneer in clinical epigenetics, telomere length preservation, and peptide protocols.',
    nextAvailableSlot: 'Today, 1:00 PM',
    supportedTypes: [ConsultationType.inPerson, ConsultationType.telehealth, ConsultationType.atHome],
    availableTimeSlots: ['10:00 AM', '01:00 PM', '03:30 PM', '05:00 PM'],
    locationAddress: 'Zyndio Genomics Lab, Suite 104',
  ),
];

/// Default Mock Hospitals List
final List<HospitalClinic> _defaultMockHospitals = const [
  HospitalClinic(
    id: 'hosp_01',
    name: 'Zyndio Longevity Institute',
    city: 'San Francisco, CA',
    distanceKm: 2.4,
    logoUrl: '',
    specialties: ['Longevity & Anti-Aging', 'Metabolic Health', 'Preventive Cardiology'],
  ),
  HospitalClinic(
    id: 'hosp_02',
    name: 'Mayo Clinic Partner Hub',
    city: 'Rochester, MN / Remote',
    distanceKm: 5.1,
    logoUrl: '',
    specialties: ['Internal Medicine', 'Cardiology', 'Neurology'],
  ),
  HospitalClinic(
    id: 'hosp_03',
    name: 'Johns Hopkins Longevity Center',
    city: 'Baltimore, MD / Remote',
    distanceKm: 12.0,
    logoUrl: '',
    specialties: ['Functional Medicine', 'Genomics', 'Biomarker Analysis'],
  ),
  HospitalClinic(
    id: 'hosp_04',
    name: 'Cleveland Clinic Executive Health',
    city: 'Cleveland, OH / Remote',
    distanceKm: 8.7,
    logoUrl: '',
    specialties: ['Executive Physicals', 'Endocrinology', 'Cardiovascular Optimization'],
  ),
];

/// Ready-to-uncomment HTTP / REST API Client Implementation for real Hospital Backend
/*
class HttpAppointmentRepository implements IAppointmentRepository {
  final String apiBaseUrl;
  final String? authToken;

  HttpAppointmentRepository({required this.apiBaseUrl, this.authToken});

  @override
  Future<List<DoctorProfile>> fetchDoctors({String? specialty, String? hospitalName, String? query}) async {
    // Real http.get('$apiBaseUrl/doctors') implementation
    throw UnimplementedError('Wire up your real hospital API endpoint here');
  }

  @override
  Future<List<HospitalClinic>> fetchHospitals() async {
    // Real http.get('$apiBaseUrl/hospitals') implementation
    throw UnimplementedError('Wire up your real hospital API endpoint here');
  }

  @override
  Future<List<AppointmentBooking>> fetchUserAppointments() async {
    // Real http.get('$apiBaseUrl/appointments') implementation
    throw UnimplementedError('Wire up your real hospital API endpoint here');
  }

  @override
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
    // Real http.post('$apiBaseUrl/appointments/book') implementation
    throw UnimplementedError('Wire up your real hospital API endpoint here');
  }

  @override
  Future<void> cancelAppointment(String appointmentId, {String? reason}) async {
    // Real http.post('$apiBaseUrl/appointments/$appointmentId/cancel') implementation
    throw UnimplementedError('Wire up your real hospital API endpoint here');
  }

  @override
  Future<void> rescheduleAppointment(String appointmentId, DateTime newDate, String newTimeSlot) async {
    // Real http.post('$apiBaseUrl/appointments/$appointmentId/reschedule') implementation
    throw UnimplementedError('Wire up your real hospital API endpoint here');
  }
}
*/
