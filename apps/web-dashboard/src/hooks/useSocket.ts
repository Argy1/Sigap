'use client';

import { useEffect, useRef, useState } from 'react';
import { io, type Socket } from 'socket.io-client';
import { tokenStore } from '@/lib/api';
import { API_URL } from '@/lib/config';

/**
 * Koneksi Socket.io tunggal untuk seluruh dashboard.
 *
 * Room-nya TIDAK dipilih di sini — server yang menentukan berdasarkan identitas
 * di dalam token. Dashboard hanya menyatakan "ini siapa saya", lalu menerima
 * apa yang memang boleh diterimanya. Itulah yang mencegah RS satu mendengarkan
 * lalu lintas RS lain.
 */
export function useSocket(enabled: boolean) {
  const [socket, setSocket] = useState<Socket | null>(null);
  const [connected, setConnected] = useState(false);
  const ref = useRef<Socket | null>(null);

  useEffect(() => {
    if (!enabled) return;
    const token = tokenStore.access;
    if (!token) return;

    const s = io(API_URL, {
      auth: { token },
      transports: ['websocket', 'polling'],
      reconnectionDelay: 1_000,
      reconnectionDelayMax: 5_000,
    });

    ref.current = s;
    setSocket(s);

    s.on('connect', () => setConnected(true));
    s.on('disconnect', () => setConnected(false));
    s.on('connect_error', () => setConnected(false));

    return () => {
      s.removeAllListeners();
      s.disconnect();
      ref.current = null;
      setSocket(null);
      setConnected(false);
    };
  }, [enabled]);

  return { socket, connected };
}

/**
 * Berlangganan satu event socket.
 *
 * Handler disimpan di ref supaya callback yang berubah tiap render tidak terus
 * memasang & melepas listener — bug klasik yang bikin event terlewat.
 */
export function useSocketEvent<T = unknown>(
  socket: Socket | null,
  event: string,
  handler: (payload: T) => void,
): void {
  const saved = useRef(handler);
  saved.current = handler;

  useEffect(() => {
    if (!socket) return;
    const fn = (payload: T) => saved.current(payload);
    socket.on(event, fn);
    return () => {
      socket.off(event, fn);
    };
  }, [socket, event]);
}
