import type { Server as HttpServer } from 'node:http';
import { Server as IOServer, type Socket } from 'socket.io';
import { env } from '../config/env.js';
import { query } from '../db/pool.js';
import { verifyAccessToken, verifyCallToken } from '../services/token.service.js';
import type { AuthContext } from '../types/index.js';
import {
  ADMIN_ROOM,
  callRoom,
  driverRoom,
  EVENTS,
  hospitalRoom,
} from './rooms.js';

interface SocketState {
  auth?: AuthContext;
  callId?: string;
}

const state = new WeakMap<Socket, SocketState>();

let io: IOServer | null = null;

/** Akses instance io dari service mana pun. Null sebelum server dijalankan. */
export const getIO = (): IOServer | null => io;

export function initSockets(httpServer: HttpServer): IOServer {
  io = new IOServer(httpServer, {
    cors: { origin: env.CORS_ORIGINS, credentials: true },
  });

  /**
   * Handshake auth. Dua jenis kredensial diterima:
   *
   *  - `auth.token`     -> access token biasa (pasien login, sopir, staff, admin)
   *  - `auth.callToken` -> call token MODE TAMU
   *
   * Room yang di-join ditentukan SEPENUHNYA di sini oleh server berdasarkan
   * identitas — client tidak pernah boleh memilih room-nya sendiri. Ini yang
   * mencegah RS A mendengarkan panggilan RS B hanya dengan menebak id.
   */
  io.use((socket, next) => {
    const token = socket.handshake.auth?.token as string | undefined;
    const callToken = socket.handshake.auth?.callToken as string | undefined;

    try {
      if (token) {
        const payload = verifyAccessToken(token);
        state.set(socket, {
          auth: {
            profileId: payload.sub,
            role: payload.role,
            hospitalId: payload.hospitalId ?? null,
            driverId: payload.driverId ?? null,
          },
        });
        return next();
      }

      if (callToken) {
        const payload = verifyCallToken(callToken);
        state.set(socket, { callId: payload.callId });
        return next();
      }

      next(new Error('Kredensial socket tidak ada'));
    } catch {
      next(new Error('Kredensial socket tidak valid'));
    }
  });

  io.on('connection', (socket) => {
    void onConnection(socket);
  });

  return io;
}

async function onConnection(socket: Socket): Promise<void> {
  const s = state.get(socket);
  if (!s) return void socket.disconnect(true);

  // ---- Mode tamu: hanya boleh satu room, panggilannya sendiri ---------------
  if (s.callId) {
    await socket.join(callRoom(s.callId));
    socket.emit('ready', { scope: 'call', callId: s.callId });
    return;
  }

  const auth = s.auth!;

  switch (auth.role) {
    case 'hospital_staff': {
      if (auth.hospitalId) await socket.join(hospitalRoom(auth.hospitalId));
      break;
    }
    case 'driver': {
      if (!auth.driverId) break;
      await socket.join(driverRoom(auth.driverId));

      // PENTING: sopir TIDAK boleh join room rumah sakit.
      //
      // Room RS menyiarkan setiap SOS milik RS itu — lengkap dengan nama,
      // nomor HP, alamat, dan data medis pasien. Sopir hanya berhak atas
      // panggilan yang ditugaskan kepadanya, jadi dia hanya join room
      // panggilan-panggilan itu saja.
      const assigned = await query<{ id: string }>(
        `SELECT id FROM emergency_calls
         WHERE driver_id = $1
           AND status IN ('pending','confirmed','en_route','arrived')`,
        [auth.driverId],
      );
      for (const row of assigned.rows) await socket.join(callRoom(row.id));
      break;
    }
    case 'admin': {
      await socket.join(ADMIN_ROOM);
      break;
    }
    case 'patient': {
      // Pasien join room untuk setiap panggilannya yang masih aktif.
      const res = await query<{ id: string }>(
        `SELECT id FROM emergency_calls
         WHERE patient_id = $1
           AND status IN ('pending','confirmed','en_route','arrived')`,
        [auth.profileId],
      );
      for (const row of res.rows) await socket.join(callRoom(row.id));
      break;
    }
  }

  socket.emit('ready', { scope: auth.role, profileId: auth.profileId });

  /**
   * Pasien boleh minta ikut memantau satu panggilan — tapi hanya kalau
   * panggilan itu memang miliknya. Dicek ke database, bukan dipercaya
   * begitu saja dari client.
   */
  socket.on('call:watch', async (payload: { callId?: string }, ack?: (r: unknown) => void) => {
    const callId = payload?.callId;
    if (!callId) return ack?.({ ok: false, error: 'callId wajib diisi' });

    const allowed = await canWatchCall(auth, callId);
    if (!allowed) return ack?.({ ok: false, error: 'Bukan panggilan Anda' });

    await socket.join(callRoom(callId));
    ack?.({ ok: true });
  });

  /**
   * Sopir mengirim posisi. Ditulis ke database (supaya query "sopir terdekat"
   * tetap akurat) lalu di-broadcast ke pasien & RS terkait.
   */
  socket.on(
    EVENTS.DRIVER_LOCATION_PUSH,
    async (payload: { lat?: number; lng?: number }) => {
      if (auth.role !== 'driver' || !auth.driverId) return;
      const { lat, lng } = payload ?? {};
      if (typeof lat !== 'number' || typeof lng !== 'number') return;
      if (lat < -90 || lat > 90 || lng < -180 || lng > 180) return;

      await query(
        `UPDATE drivers
         SET current_location = ST_SetSRID(ST_MakePoint($1, $2), 4326)::geography,
             location_updated_at = now()
         WHERE id = $3`,
        [lng, lat, auth.driverId],
      );

      // Broadcast hanya ke panggilan yang sedang ditangani sopir ini.
      const active = await query<{ id: string; hospital_id: string | null }>(
        `SELECT id, hospital_id FROM emergency_calls
         WHERE driver_id = $1 AND status IN ('confirmed','en_route','arrived')`,
        [auth.driverId],
      );

      const body = { driverId: auth.driverId, lat, lng, at: new Date().toISOString() };
      for (const call of active.rows) {
        io?.to(callRoom(call.id)).emit(EVENTS.DRIVER_LOCATION, { ...body, callId: call.id });
        if (call.hospital_id) {
          io?.to(hospitalRoom(call.hospital_id)).emit(EVENTS.DRIVER_LOCATION, {
            ...body,
            callId: call.id,
          });
        }
      }
    },
  );
}

/** Cek kepemilikan panggilan di database — jangan pernah percaya client. */
async function canWatchCall(auth: AuthContext, callId: string): Promise<boolean> {
  if (auth.role === 'admin') return true;

  const res = await query<{
    patient_id: string | null;
    hospital_id: string | null;
    driver_id: string | null;
  }>(
    'SELECT patient_id, hospital_id, driver_id FROM emergency_calls WHERE id = $1',
    [callId],
  );
  const call = res.rows[0];
  if (!call) return false;

  if (auth.role === 'patient') return call.patient_id === auth.profileId;
  if (auth.role === 'hospital_staff') return call.hospital_id === auth.hospitalId;
  if (auth.role === 'driver') return call.driver_id === auth.driverId;
  return false;
}
