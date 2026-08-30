import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../api/api_client.dart';
import '../models/models.dart';
import 'events.dart';

/// Koneksi Socket.io untuk App Pasien & App Sopir.
///
/// Room-nya TIDAK ditentukan di sini — server yang memutuskan berdasarkan
/// identitas di dalam token. Client hanya menyatakan siapa dirinya lalu
/// menerima apa yang memang boleh diterimanya. Itu yang mencegah satu pasien
/// mendengarkan panggilan pasien lain hanya dengan menebak id.
class SocketService {
  SocketService({String? baseUrl}) : _baseUrl = baseUrl ?? kApiUrl;

  final String _baseUrl;
  io.Socket? _socket;

  final _connection = StreamController<bool>.broadcast();
  final _callUpdates = StreamController<EmergencyCall>.broadcast();
  final _driverLocations = StreamController<DriverLocationEvent>.broadcast();
  final _assignments = StreamController<EmergencyCall>.broadcast();
  final _assignmentCancelled = StreamController<String>.broadcast();

  /// True selama socket tersambung.
  Stream<bool> get connection => _connection.stream;

  /// Perubahan status pada panggilan yang sedang dipantau.
  Stream<EmergencyCall> get callUpdates => _callUpdates.stream;

  /// Posisi sopir bergerak — inti dari live tracking.
  Stream<DriverLocationEvent> get driverLocations => _driverLocations.stream;

  /// Tugas baru untuk sopir ini.
  Stream<EmergencyCall> get assignments => _assignments.stream;

  /// Tugas sopir dibatalkan / dialihkan ke sopir lain.
  Stream<String> get assignmentCancelled => _assignmentCancelled.stream;

  bool get isConnected => _socket?.connected ?? false;

  /// Sambungkan dengan access token (pengguna login) ATAU call token (tamu).
  void connect({String? accessToken, String? callToken}) {
    if (accessToken == null && callToken == null) return;

    disconnect();

    final socket = io.io(
      _baseUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({
            'token': ?accessToken,
            'callToken': ?callToken,
          })
          .enableReconnection()
          .setReconnectionDelay(1000)
          .setReconnectionDelayMax(5000)
          .build(),
    );

    socket.onConnect((_) => _connection.add(true));
    socket.onDisconnect((_) => _connection.add(false));
    socket.onConnectError((e) {
      debugPrint('[socket] connect error: $e');
      _connection.add(false);
    });

    socket.on(SocketEvents.callStatus, (data) {
      if (data is Map) {
        _callUpdates.add(
          EmergencyCall.fromJson(Map<String, dynamic>.from(data)),
        );
      }
    });

    socket.on(SocketEvents.sosUpdated, (data) {
      if (data is Map) {
        _callUpdates.add(
          EmergencyCall.fromJson(Map<String, dynamic>.from(data)),
        );
      }
    });

    socket.on(SocketEvents.driverLocation, (data) {
      if (data is Map) {
        _driverLocations.add(
          DriverLocationEvent.fromJson(Map<String, dynamic>.from(data)),
        );
      }
    });

    socket.on(SocketEvents.assignmentNew, (data) {
      if (data is Map) {
        _assignments.add(
          EmergencyCall.fromJson(Map<String, dynamic>.from(data)),
        );
      }
    });

    socket.on(SocketEvents.assignmentCancelled, (data) {
      if (data is Map && data['callId'] is String) {
        _assignmentCancelled.add(data['callId'] as String);
      }
    });

    _socket = socket;
    socket.connect();
  }

  /// Minta ikut memantau satu panggilan.
  ///
  /// Server tetap memverifikasi kepemilikan ke database sebelum mengizinkan —
  /// permintaan ini bukan jaminan diterima.
  void watchCall(String callId) {
    _socket?.emitWithAck(
      SocketEvents.callWatch,
      {'callId': callId},
      ack: (res) => debugPrint('[socket] call:watch -> $res'),
    );
  }

  /// Sopir mengirim posisinya. Ini jalur UTAMA live tracking — dipilih daripada
  /// REST karena posisi dikirim tiap beberapa detik, dan socket jauh lebih
  /// murah daripada membuka koneksi HTTP baru berulang kali.
  void pushLocation(LatLngPoint point) {
    _socket?.emit(SocketEvents.driverLocationPush, {
      'lat': point.lat,
      'lng': point.lng,
    });
  }

  void disconnect() {
    _socket?.dispose();
    _socket = null;
    _connection.add(false);
  }

  void dispose() {
    disconnect();
    _connection.close();
    _callUpdates.close();
    _driverLocations.close();
    _assignments.close();
    _assignmentCancelled.close();
  }
}
