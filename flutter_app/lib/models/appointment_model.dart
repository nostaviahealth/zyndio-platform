/// Type of consultation session
enum ConsultationType {
  inPerson,
  telehealth,
  atHome,
}

extension ConsultationTypeX on ConsultationType {
  String get displayName {
    switch (this) {
      case ConsultationType.inPerson:
        return 'Hospital Visit';
      case ConsultationType.telehealth:
        return 'Video Call';
      case ConsultationType.atHome:
        return 'Home Lab Visit';
    }
  }

  String get iconName {
    switch (this) {
      case ConsultationType.inPerson:
        return 'building';
      case ConsultationType.telehealth:
        return 'video';
      case ConsultationType.atHome:
        return 'home';
    }
  }
}

/// Status of the appointment
enum AppointmentStatus {
  confirmed,
  completed,
  cancelled,
  rescheduled,
}

extension AppointmentStatusX on AppointmentStatus {
  String get label {
    switch (this) {
      case AppointmentStatus.confirmed:
        return 'Confirmed';
      case AppointmentStatus.completed:
        return 'Completed';
      case AppointmentStatus.cancelled:
        return 'Cancelled';
      case AppointmentStatus.rescheduled:
        return 'Rescheduled';
    }
  }
}

/// Model representing a Doctor Profile
class DoctorProfile {
  final String id;
  final String name;
  final String title;
  final String specialty;
  final String hospitalName;
  final double rating;
  final int reviewCount;
  final int experienceYears;
  final double consultationFee;
  final String avatarUrl;
  final String bio;
  final String nextAvailableSlot;
  final List<ConsultationType> supportedTypes;
  final List<String> availableTimeSlots;
  final String locationAddress;

  const DoctorProfile({
    required this.id,
    required this.name,
    required this.title,
    required this.specialty,
    required this.hospitalName,
    required this.rating,
    required this.reviewCount,
    required this.experienceYears,
    required this.consultationFee,
    required this.avatarUrl,
    required this.bio,
    required this.nextAvailableSlot,
    required this.supportedTypes,
    required this.availableTimeSlots,
    required this.locationAddress,
  });

  factory DoctorProfile.fromJson(Map<String, dynamic> json) {
    return DoctorProfile(
      id: json['id'] as String,
      name: json['name'] as String,
      title: json['title'] as String? ?? 'MD',
      specialty: json['specialty'] as String,
      hospitalName: json['hospital_name'] as String,
      rating: (json['rating'] as num?)?.toDouble() ?? 4.9,
      reviewCount: (json['review_count'] as num?)?.toInt() ?? 120,
      experienceYears: (json['experience_years'] as num?)?.toInt() ?? 10,
      consultationFee: (json['consultation_fee'] as num?)?.toDouble() ?? 150.0,
      avatarUrl: json['avatar_url'] as String? ?? '',
      bio: json['bio'] as String? ?? '',
      nextAvailableSlot: json['next_available_slot'] as String? ?? 'Today, 3:00 PM',
      supportedTypes: (json['supported_types'] as List<dynamic>?)
              ?.map((e) => ConsultationType.values.firstWhere(
                    (type) => type.name == e,
                    orElse: () => ConsultationType.inPerson,
                  ))
              .toList() ??
          [ConsultationType.inPerson, ConsultationType.telehealth],
      availableTimeSlots: (json['available_time_slots'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          ['09:00 AM', '10:30 AM', '02:00 PM', '04:30 PM'],
      locationAddress: json['location_address'] as String? ?? 'Building A, Suite 402',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'title': title,
      'specialty': specialty,
      'hospital_name': hospitalName,
      'rating': rating,
      'review_count': reviewCount,
      'experience_years': experienceYears,
      'consultation_fee': consultationFee,
      'avatar_url': avatarUrl,
      'bio': bio,
      'next_available_slot': nextAvailableSlot,
      'supported_types': supportedTypes.map((e) => e.name).toList(),
      'available_time_slots': availableTimeSlots,
      'location_address': locationAddress,
    };
  }
}

/// Model representing a Hospital or Clinic Partner
class HospitalClinic {
  final String id;
  final String name;
  final String city;
  final double distanceKm;
  final String logoUrl;
  final List<String> specialties;

  const HospitalClinic({
    required this.id,
    required this.name,
    required this.city,
    required this.distanceKm,
    required this.logoUrl,
    required this.specialties,
  });
}

/// Model representing a Booked Appointment with EMR & White-Label Fields
class AppointmentBooking {
  final String id;
  final String doctorId;
  final String doctorName;
  final String doctorTitle;
  final String doctorAvatarUrl;
  final String specialty;
  final String hospitalName;
  final ConsultationType type;
  final DateTime appointmentDate;
  final String timeSlot;
  final String reasonNotes;
  final double feePaid;
  final AppointmentStatus status;
  final String? videoCallUrl;
  final String locationAddress;
  final DateTime createdAt;
  // White-label & Patient EMR fields
  final String patientName;
  final String patientPhone;
  final String? insuranceId;
  final String? cancellationReason;
  final String qrPassCode;

  AppointmentBooking({
    required this.id,
    required this.doctorId,
    required this.doctorName,
    required this.doctorTitle,
    required this.doctorAvatarUrl,
    required this.specialty,
    required this.hospitalName,
    required this.type,
    required this.appointmentDate,
    required this.timeSlot,
    required this.reasonNotes,
    required this.feePaid,
    required this.status,
    this.videoCallUrl,
    required this.locationAddress,
    required this.createdAt,
    this.patientName = 'Alexander Wright',
    this.patientPhone = '+1 (555) 234-5678',
    this.insuranceId,
    this.cancellationReason,
    String? qrPassCode,
  }) : qrPassCode = qrPassCode ?? 'PASS-${id.length > 8 ? id.substring(id.length - 6) : id}';

  AppointmentBooking copyWith({
    String? id,
    String? doctorId,
    String? doctorName,
    String? doctorTitle,
    String? doctorAvatarUrl,
    String? specialty,
    String? hospitalName,
    ConsultationType? type,
    DateTime? appointmentDate,
    String? timeSlot,
    String? reasonNotes,
    double? feePaid,
    AppointmentStatus? status,
    String? videoCallUrl,
    String? locationAddress,
    DateTime? createdAt,
    String? patientName,
    String? patientPhone,
    String? insuranceId,
    String? cancellationReason,
    String? qrPassCode,
  }) {
    return AppointmentBooking(
      id: id ?? this.id,
      doctorId: doctorId ?? this.doctorId,
      doctorName: doctorName ?? this.doctorName,
      doctorTitle: doctorTitle ?? this.doctorTitle,
      doctorAvatarUrl: doctorAvatarUrl ?? this.doctorAvatarUrl,
      specialty: specialty ?? this.specialty,
      hospitalName: hospitalName ?? this.hospitalName,
      type: type ?? this.type,
      appointmentDate: appointmentDate ?? this.appointmentDate,
      timeSlot: timeSlot ?? this.timeSlot,
      reasonNotes: reasonNotes ?? this.reasonNotes,
      feePaid: feePaid ?? this.feePaid,
      status: status ?? this.status,
      videoCallUrl: videoCallUrl ?? this.videoCallUrl,
      locationAddress: locationAddress ?? this.locationAddress,
      createdAt: createdAt ?? this.createdAt,
      patientName: patientName ?? this.patientName,
      patientPhone: patientPhone ?? this.patientPhone,
      insuranceId: insuranceId ?? this.insuranceId,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      qrPassCode: qrPassCode ?? this.qrPassCode,
    );
  }

  factory AppointmentBooking.fromJson(Map<String, dynamic> json) {
    return AppointmentBooking(
      id: json['id'] as String,
      doctorId: json['doctor_id'] as String,
      doctorName: json['doctor_name'] as String,
      doctorTitle: json['doctor_title'] as String? ?? 'MD',
      doctorAvatarUrl: json['doctor_avatar_url'] as String? ?? '',
      specialty: json['specialty'] as String,
      hospitalName: json['hospital_name'] as String,
      type: ConsultationType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => ConsultationType.inPerson,
      ),
      appointmentDate: DateTime.parse(json['appointment_date'] as String),
      timeSlot: json['time_slot'] as String,
      reasonNotes: json['reason_notes'] as String? ?? '',
      feePaid: (json['fee_paid'] as num?)?.toDouble() ?? 0.0,
      status: AppointmentStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => AppointmentStatus.confirmed,
      ),
      videoCallUrl: json['video_call_url'] as String?,
      locationAddress: json['location_address'] as String? ?? '',
      createdAt: DateTime.parse(json['created_at'] as String),
      patientName: json['patient_name'] as String? ?? 'Alexander Wright',
      patientPhone: json['patient_phone'] as String? ?? '+1 (555) 234-5678',
      insuranceId: json['insurance_id'] as String?,
      cancellationReason: json['cancellation_reason'] as String?,
      qrPassCode: json['qr_pass_code'] as String? ?? 'PASS-8849-NX',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'doctor_id': doctorId,
      'doctor_name': doctorName,
      'doctor_title': doctorTitle,
      'doctor_avatar_url': doctorAvatarUrl,
      'specialty': specialty,
      'hospital_name': hospitalName,
      'type': type.name,
      'appointment_date': appointmentDate.toIso8601String(),
      'time_slot': timeSlot,
      'reason_notes': reasonNotes,
      'fee_paid': feePaid,
      'status': status.name,
      'video_call_url': videoCallUrl,
      'location_address': locationAddress,
      'created_at': createdAt.toIso8601String(),
      'patient_name': patientName,
      'patient_phone': patientPhone,
      'insurance_id': insuranceId,
      'cancellation_reason': cancellationReason,
      'qr_pass_code': qrPassCode,
    };
  }
}
