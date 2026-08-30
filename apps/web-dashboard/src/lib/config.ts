export const API_URL =
  process.env.NEXT_PUBLIC_API_URL?.replace(/\/$/, '') ?? 'http://localhost:4000';

export const GOOGLE_MAPS_KEY = process.env.NEXT_PUBLIC_GOOGLE_MAPS_API_KEY ?? '';

/**
 * Satu-satunya tempat yang menentukan peta mana yang dipakai.
 *
 * Tanpa key, dashboard memakai ConsoleMap — bukan penurunan kualitas: mockup
 * memang menggambarkan peta bergaya konsol abstrak, bukan Google Maps.
 */
export const hasGoogleMaps = GOOGLE_MAPS_KEY.trim().length > 0;
