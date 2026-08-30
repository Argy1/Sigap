import '../models/models.dart';

/// Nama event Socket.io. Harus persis sama dengan `backend/src/sockets/rooms.ts`
/// — dikumpulkan di satu tempat supaya salah ketik langsung ketahuan, bukan
/// jadi bug diam yang bikin live tracking "kadang tidak jalan".
class SocketEvents {
  const SocketEvents._();

  // Server -> client
  static const sosNew = 'sos:new';
  static const sosUpdated = 'sos:updated';
  static const callStatus = 'call:status';
  static const driverLocation = 'driver:location';
  static const assignmentNew = 'assignment:new';
  static const assignmentCancelled = 'assignment:cancelled';

  // Client -> server
  static const driverLocationPush = 'driver:location:push';
  static const callWatch = 'call:watch';
}

/// Satu pembaruan posisi sopir.
class DriverLocationEvent {
  const DriverLocationEvent({
    required this.callId,
    required this.driverId,
    required this.position,
    required this.at,
  });

  final String callId;
  final String driverId;
  final LatLngPoint position;
  final DateTime at;

  factory DriverLocationEvent.fromJson(Map<String, dynamic> j) =>
      DriverLocationEvent(
        callId: j['callId'] as String? ?? '',
        driverId: j['driverId'] as String? ?? '',
        position: LatLngPoint(
          (j['lat'] as num).toDouble(),
          (j['lng'] as num).toDouble(),
        ),
        at: j['at'] == null
            ? DateTime.now()
            : DateTime.parse(j['at'] as String).toLocal(),
      );
}
