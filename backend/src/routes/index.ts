import { Router } from 'express';
import * as auth from '../controllers/auth.controller.js';
import * as drivers from '../controllers/drivers.controller.js';
import * as emergency from '../controllers/emergency.controller.js';
import * as hospitals from '../controllers/hospitals.controller.js';
import {
  authenticate,
  authenticateAny,
  optionalAuthenticate,
} from '../middleware/auth.js';
import { requireRole } from '../middleware/rbac.js';
import { validate } from '../middleware/validate.js';

export const router = Router();

// ===========================================================================
// AUTH
// ===========================================================================
router.post('/auth/register', validate(auth.registerSchema), auth.register);
router.post('/auth/login', validate(auth.loginSchema), auth.login);
router.post('/auth/refresh', validate(auth.refreshSchema), auth.refresh);
router.post('/auth/logout', optionalAuthenticate, auth.logout);
router.get('/auth/me', authenticate, auth.me);

// ===========================================================================
// PROFIL MEDIS PASIEN
// ===========================================================================
router.get('/patients/me/medical', authenticate, requireRole('patient'), auth.getMedical);
router.put(
  '/patients/me/medical',
  authenticate,
  requireRole('patient'),
  validate(auth.medicalSchema),
  auth.updateMedical,
);

// ===========================================================================
// RUMAH SAKIT
// ===========================================================================

// PUBLIK — dipakai layar Peta App Pasien dan alur SOS mode tamu.
router.get(
  '/hospitals/nearest',
  validate(hospitals.nearestQuerySchema, 'query'),
  hospitals.nearest,
);

// PUBLIK — registrasi mandiri RS (non-blocking).
router.post(
  '/hospitals/register',
  validate(hospitals.registerHospitalSchema),
  hospitals.registerHospital,
);

router.get(
  '/hospitals/:id',
  authenticate,
  requireRole('hospital_staff', 'admin'),
  hospitals.getHospital,
);
router.patch(
  '/hospitals/:id',
  authenticate,
  requireRole('hospital_staff', 'admin'),
  validate(hospitals.updateHospitalSchema),
  hospitals.updateHospital,
);

// ===========================================================================
// ADMIN — verifikasi RS
// ===========================================================================
router.get(
  '/admin/hospitals',
  authenticate,
  requireRole('admin'),
  validate(hospitals.listHospitalsQuerySchema, 'query'),
  hospitals.listHospitals,
);
router.patch(
  '/admin/hospitals/:id/verify',
  authenticate,
  requireRole('admin'),
  validate(hospitals.verifySchema),
  hospitals.verifyHospital,
);

// ===========================================================================
// SOPIR
// ===========================================================================

// Endpoint milik sopir sendiri — didaftarkan SEBELUM '/drivers/:id' supaya
// "me" tidak pernah tertangkap sebagai parameter :id.
router.get('/drivers/me', authenticate, requireRole('driver'), drivers.myDriverProfile);
router.patch(
  '/drivers/me/availability',
  authenticate,
  requireRole('driver'),
  validate(drivers.availabilitySchema),
  drivers.setAvailability,
);
router.patch(
  '/drivers/me/location',
  authenticate,
  requireRole('driver'),
  validate(drivers.locationSchema),
  drivers.pushLocation,
);

// Kelola sopir — staff RS (otomatis dibatasi ke RS-nya) & admin.
router.get(
  '/drivers',
  authenticate,
  requireRole('hospital_staff', 'admin'),
  drivers.listDrivers,
);
router.post(
  '/drivers',
  authenticate,
  requireRole('hospital_staff', 'admin'),
  validate(drivers.createDriverSchema),
  drivers.createDriver,
);
router.patch(
  '/drivers/:id',
  authenticate,
  requireRole('hospital_staff', 'admin'),
  validate(drivers.updateDriverSchema),
  drivers.updateDriver,
);
router.delete(
  '/drivers/:id',
  authenticate,
  requireRole('hospital_staff', 'admin'),
  drivers.deleteDriver,
);

// ===========================================================================
// PANGGILAN DARURAT
// ===========================================================================

// Auth OPSIONAL — inilah yang membuat mode tamu mungkin.
router.post(
  '/emergency-calls',
  optionalAuthenticate,
  validate(emergency.createCallSchema),
  emergency.createCall,
);

router.get('/emergency-calls', authenticate, emergency.listMyCalls);

// Menerima access token ATAU call token (tamu).
router.get('/emergency-calls/:id', authenticateAny, emergency.getCall);
router.patch(
  '/emergency-calls/:id/status',
  authenticateAny,
  validate(emergency.statusSchema),
  emergency.changeStatus,
);

router.get(
  '/emergency-calls/:id/suggested-drivers',
  authenticate,
  requireRole('hospital_staff', 'admin'),
  emergency.suggestedDrivers,
);
router.post(
  '/emergency-calls/:id/assign',
  authenticate,
  requireRole('hospital_staff', 'admin'),
  validate(emergency.assignSchema),
  emergency.assign,
);
router.post(
  '/emergency-calls/:id/reject',
  authenticate,
  requireRole('driver'),
  emergency.reject,
);
