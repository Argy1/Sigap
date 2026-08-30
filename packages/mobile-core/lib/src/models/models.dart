import 'package:flutter/foundation.dart';

/// Model data bersama App Pasien & App Sopir.
///
/// Ditulis manual (tanpa freezed/build_runner) supaya tidak ada langkah
/// codegen yang harus dijalankan sebelum `flutter run` bekerja — proyek ini
/// harus bisa langsung dijalankan setelah clone.

// ---------------------------------------------------------------------------
// Enum
// ---------------------------------------------------------------------------

enum Role { patient, hospitalStaff, driver, admin }

Role roleFromJson(String v) => switch (v) {
      'patient' => Role.patient,
      'hospital_staff' => Role.hospitalStaff,
      'driver' => Role.driver,
      'admin' => Role.admin,
      _ => Role.patient,
    };

/// Status panggilan darurat. Urutan enum = urutan alur golden path.
enum CallStatus { pending, confirmed, enRoute, arrived, completed, cancelled }

CallStatus callStatusFromJson(String v) => switch (v) {
      'pending' => CallStatus.pending,
      'confirmed' => CallStatus.confirmed,
      'en_route' => CallStatus.enRoute,
      'arrived' => CallStatus.arrived,
      'completed' => CallStatus.completed,
      'cancelled' => CallStatus.cancelled,
      _ => CallStatus.pending,
    };

String callStatusToJson(CallStatus s) => switch (s) {
      CallStatus.pending => 'pending',
      CallStatus.confirmed => 'confirmed',
      CallStatus.enRoute => 'en_route',
      CallStatus.arrived => 'arrived',
      CallStatus.completed => 'completed',
      CallStatus.cancelled => 'cancelled',
    };

/// Label bahasa Indonesia — teks UI selalu Bahasa Indonesia (konvensi proyek).
extension CallStatusLabel on CallStatus {
  String get label => switch (this) {
        CallStatus.pending => 'Menunggu Konfirmasi',
        CallStatus.confirmed => 'Sopir Ditugaskan',
        CallStatus.enRoute => 'Sopir Menuju Lokasi',
        CallStatus.arrived => 'Tiba di Lokasi',
        CallStatus.completed => 'Selesai',
        CallStatus.cancelled => 'Dibatalkan',
      };

  /// Label pendek untuk chip.
  String get shortLabel => switch (this) {
        CallStatus.pending => 'Menunggu',
        CallStatus.confirmed => 'Dikonfirmasi',
        CallStatus.enRoute => 'Menuju',
        CallStatus.arrived => 'Tiba',
        CallStatus.completed => 'Selesai',
        CallStatus.cancelled => 'Batal',
      };

  /// Panggilan yang masih berjalan dan perlu dipantau.
  bool get isActive => switch (this) {
        CallStatus.pending ||
        CallStatus.confirmed ||
        CallStatus.enRoute ||
        CallStatus.arrived =>
          true,
        _ => false,
      };
}

enum AvailabilityStatus { available, busy, offline }

AvailabilityStatus availabilityFromJson(String v) => switch (v) {
      'available' => AvailabilityStatus.available,
      'busy' => AvailabilityStatus.busy,
      _ => AvailabilityStatus.offline,
    };

String availabilityToJson(AvailabilityStatus s) => switch (s) {
      AvailabilityStatus.available => 'available',
      AvailabilityStatus.busy => 'busy',
      AvailabilityStatus.offline => 'offline',
    };

extension AvailabilityLabel on AvailabilityStatus {
  String get label => switch (this) {
        AvailabilityStatus.available => 'Tersedia',
        AvailabilityStatus.busy => 'Bertugas',
        AvailabilityStatus.offline => 'Tidak Aktif',
      };
}

// ---------------------------------------------------------------------------
// Nilai sederhana
// ---------------------------------------------------------------------------

@immutable
class LatLngPoint {
  const LatLngPoint(this.lat, this.lng);

  final double lat;
  final double lng;

  factory LatLngPoint.fromJson(Map<String, dynamic> j) =>
      LatLngPoint((j['lat'] as num).toDouble(), (j['lng'] as num).toDouble());

  Map<String, dynamic> toJson() => {'lat': lat, 'lng': lng};

  @override
  bool operator ==(Object other) =>
      other is LatLngPoint && other.lat == lat && other.lng == lng;

  @override
  int get hashCode => Object.hash(lat, lng);

  @override
  String toString() => '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';
}

// ---------------------------------------------------------------------------
// Profil
// ---------------------------------------------------------------------------

@immutable
class AuthUser {
  const AuthUser({
    required this.id,
    required this.role,
    required this.fullName,
    this.phone,
    this.email,
    this.hospitalId,
    this.hospitalName,
    this.driverId,
    this.vehiclePlate,
    this.availabilityStatus,
  });

  final String id;
  final Role role;
  final String fullName;
  final String? phone;
  final String? email;
  final String? hospitalId;
  final String? hospitalName;

  /// Terisi hanya untuk role driver.
  final String? driverId;
  final String? vehiclePlate;
  final AvailabilityStatus? availabilityStatus;

  factory AuthUser.fromJson(Map<String, dynamic> j) => AuthUser(
        id: j['id'] as String,
        role: roleFromJson(j['role'] as String),
        fullName: j['fullName'] as String,
        phone: j['phone'] as String?,
        email: j['email'] as String?,
        hospitalId: j['hospitalId'] as String?,
        hospitalName: j['hospitalName'] as String?,
        driverId: j['driverId'] as String?,
        vehiclePlate: j['vehiclePlate'] as String?,
        availabilityStatus: j['availabilityStatus'] == null
            ? null
            : availabilityFromJson(j['availabilityStatus'] as String),
      );

  AuthUser copyWith({AvailabilityStatus? availabilityStatus}) => AuthUser(
        id: id,
        role: role,
        fullName: fullName,
        phone: phone,
        email: email,
        hospitalId: hospitalId,
        hospitalName: hospitalName,
        driverId: driverId,
        vehiclePlate: vehiclePlate,
        availabilityStatus: availabilityStatus ?? this.availabilityStatus,
      );
}

/// Profil medis pasien — data yang dilihat responder saat darurat.
@immutable
class MedicalProfile {
  const MedicalProfile({
    this.bloodType,
    this.allergies = const [],
    this.medicalHistory,
    this.emergencyContactName,
    this.emergencyContactPhone,
  });

  final String? bloodType;
  final List<String> allergies;
  final String? medicalHistory;
  final String? emergencyContactName;
  final String? emergencyContactPhone;

  factory MedicalProfile.fromJson(Map<String, dynamic> j) => MedicalProfile(
        bloodType: j['bloodType'] as String?,
        allergies:
            ((j['allergies'] as List?) ?? const []).map((e) => e as String).toList(),
        medicalHistory: j['medicalHistory'] as String?,
        emergencyContactName: j['emergencyContactName'] as String?,
        emergencyContactPhone: j['emergencyContactPhone'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'bloodType': bloodType,
        'allergies': allergies,
        'medicalHistory': medicalHistory,
        'emergencyContactName': emergencyContactName,
        'emergencyContactPhone': emergencyContactPhone,
      };

  MedicalProfile copyWith({
    String? bloodType,
    List<String>? allergies,
    String? medicalHistory,
    String? emergencyContactName,
    String? emergencyContactPhone,
  }) =>
      MedicalProfile(
        bloodType: bloodType ?? this.bloodType,
        allergies: allergies ?? this.allergies,
        medicalHistory: medicalHistory ?? this.medicalHistory,
        emergencyContactName: emergencyContactName ?? this.emergencyContactName,
        emergencyContactPhone:
            emergencyContactPhone ?? this.emergencyContactPhone,
      );
}

// ---------------------------------------------------------------------------
// Rumah sakit
// ---------------------------------------------------------------------------

@immutable
class NearbyHospital {
  const NearbyHospital({
    required this.id,
    required this.name,
    required this.address,
    required this.position,
    required this.straightMeters,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.source,
    this.phone,
  });

  final String id;
  final String name;
  final String address;
  final String? phone;
  final LatLngPoint position;

  /// Jarak garis lurus dari PostGIS.
  final int straightMeters;

  /// Jarak & waktu tempuh jalan (atau perkiraan kalau tanpa Google Maps).
  final int distanceMeters;
  final int durationSeconds;

  /// 'google' = jarak tempuh asli · 'estimate' = haversine terkoreksi.
  final String source;

  factory NearbyHospital.fromJson(Map<String, dynamic> j) => NearbyHospital(
        id: j['id'] as String,
        name: j['name'] as String,
        address: j['address'] as String,
        phone: j['phone'] as String?,
        position: LatLngPoint(
          (j['lat'] as num).toDouble(),
          (j['lng'] as num).toDouble(),
        ),
        straightMeters: (j['straightMeters'] as num).round(),
        distanceMeters: (j['distanceMeters'] as num).round(),
        durationSeconds: (j['durationSeconds'] as num).round(),
        source: j['source'] as String? ?? 'estimate',
      );
}

// ---------------------------------------------------------------------------
// Panggilan darurat — jantung sistem
// ---------------------------------------------------------------------------

@immutable
class EmergencyCall {
  const EmergencyCall({
    required this.id,
    required this.callCode,
    required this.patientName,
    required this.isGuest,
    required this.location,
    required this.status,
    required this.createdAt,
    this.patientId,
    this.hospitalId,
    this.hospitalName,
    this.driverId,
    this.driverName,
    this.driverPhone,
    this.vehiclePlate,
    this.patientPhone,
    this.patientAddress,
    this.conditionNote,
    this.cancelReason,
    this.medical,
    this.driverLocation,
    this.confirmedAt,
    this.enRouteAt,
    this.arrivedAt,
    this.completedAt,
    this.cancelledAt,
  });

  final String id;

  /// Kode terbaca manusia, mis. "A102" — ditampilkan sebagai "SOS #A102".
  final String callCode;
  final String? patientId;
  final String? hospitalId;
  final String? hospitalName;
  final String? driverId;
  final String? driverName;
  final String? driverPhone;
  final String? vehiclePlate;
  final String patientName;
  final String? patientPhone;

  /// True kalau SOS dikirim tanpa login (mode tamu).
  final bool isGuest;

  /// Snapshot lokasi SAAT kejadian.
  final LatLngPoint location;
  final String? patientAddress;
  final CallStatus status;
  final String? conditionNote;
  final String? cancelReason;
  final MedicalProfile? medical;

  /// Posisi sopir terakhir — diperbarui realtime lewat Socket.io.
  final LatLngPoint? driverLocation;

  final DateTime createdAt;
  final DateTime? confirmedAt;
  final DateTime? enRouteAt;
  final DateTime? arrivedAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;

  static DateTime? _dt(Object? v) =>
      v == null ? null : DateTime.parse(v as String).toLocal();

  factory EmergencyCall.fromJson(Map<String, dynamic> j) => EmergencyCall(
        id: j['id'] as String,
        callCode: j['callCode'] as String,
        patientId: j['patientId'] as String?,
        hospitalId: j['hospitalId'] as String?,
        hospitalName: j['hospitalName'] as String?,
        driverId: j['driverId'] as String?,
        driverName: j['driverName'] as String?,
        driverPhone: j['driverPhone'] as String?,
        vehiclePlate: j['vehiclePlate'] as String?,
        patientName: j['patientName'] as String? ?? 'Pasien',
        patientPhone: j['patientPhone'] as String?,
        isGuest: j['isGuest'] as bool? ?? false,
        location: LatLngPoint.fromJson(j['location'] as Map<String, dynamic>),
        patientAddress: j['patientAddress'] as String?,
        status: callStatusFromJson(j['status'] as String),
        conditionNote: j['conditionNote'] as String?,
        cancelReason: j['cancelReason'] as String?,
        medical: j['medical'] == null
            ? null
            : MedicalProfile.fromJson(j['medical'] as Map<String, dynamic>),
        driverLocation: j['driverLocation'] == null
            ? null
            : LatLngPoint.fromJson(j['driverLocation'] as Map<String, dynamic>),
        createdAt: DateTime.parse(j['createdAt'] as String).toLocal(),
        confirmedAt: _dt(j['confirmedAt']),
        enRouteAt: _dt(j['enRouteAt']),
        arrivedAt: _dt(j['arrivedAt']),
        completedAt: _dt(j['completedAt']),
        cancelledAt: _dt(j['cancelledAt']),
      );

  EmergencyCall copyWith({LatLngPoint? driverLocation, CallStatus? status}) =>
      EmergencyCall(
        id: id,
        callCode: callCode,
        patientId: patientId,
        hospitalId: hospitalId,
        hospitalName: hospitalName,
        driverId: driverId,
        driverName: driverName,
        driverPhone: driverPhone,
        vehiclePlate: vehiclePlate,
        patientName: patientName,
        patientPhone: patientPhone,
        isGuest: isGuest,
        location: location,
        patientAddress: patientAddress,
        status: status ?? this.status,
        conditionNote: conditionNote,
        cancelReason: cancelReason,
        medical: medical,
        driverLocation: driverLocation ?? this.driverLocation,
        createdAt: createdAt,
        confirmedAt: confirmedAt,
        enRouteAt: enRouteAt,
        arrivedAt: arrivedAt,
        completedAt: completedAt,
        cancelledAt: cancelledAt,
      );
}

/// Hasil pembuatan SOS. `callToken` hanya terisi untuk mode tamu.
@immutable
class CreateCallResult {
  const CreateCallResult({
    required this.call,
    required this.hospitalCandidates,
    this.callToken,
  });

  final EmergencyCall call;
  final List<NearbyHospital> hospitalCandidates;

  /// Bekal tamu untuk memantau panggilan ini tanpa punya akun.
  final String? callToken;

  factory CreateCallResult.fromJson(Map<String, dynamic> j) => CreateCallResult(
        call: EmergencyCall.fromJson(j['call'] as Map<String, dynamic>),
        hospitalCandidates: ((j['hospitalCandidates'] as List?) ?? const [])
            .map((e) => NearbyHospital.fromJson(e as Map<String, dynamic>))
            .toList(),
        callToken: j['callToken'] as String?,
      );
}

// ---------------------------------------------------------------------------
// Sopir
// ---------------------------------------------------------------------------

@immutable
class DriverProfile {
  const DriverProfile({
    required this.id,
    required this.profileId,
    required this.hospitalId,
    required this.fullName,
    required this.availabilityStatus,
    required this.isActive,
    this.phone,
    this.vehiclePlate,
    this.location,
    this.locationUpdatedAt,
  });

  final String id;
  final String profileId;
  final String hospitalId;
  final String fullName;
  final String? phone;
  final String? vehiclePlate;
  final AvailabilityStatus availabilityStatus;
  final bool isActive;
  final LatLngPoint? location;
  final DateTime? locationUpdatedAt;

  factory DriverProfile.fromJson(Map<String, dynamic> j) => DriverProfile(
        id: j['id'] as String,
        profileId: j['profileId'] as String,
        hospitalId: j['hospitalId'] as String,
        fullName: j['fullName'] as String,
        phone: j['phone'] as String?,
        vehiclePlate: j['vehiclePlate'] as String?,
        availabilityStatus:
            availabilityFromJson(j['availabilityStatus'] as String),
        isActive: j['isActive'] as bool? ?? true,
        location: j['location'] == null
            ? null
            : LatLngPoint.fromJson(j['location'] as Map<String, dynamic>),
        locationUpdatedAt: j['locationUpdatedAt'] == null
            ? null
            : DateTime.parse(j['locationUpdatedAt'] as String).toLocal(),
      );
}
