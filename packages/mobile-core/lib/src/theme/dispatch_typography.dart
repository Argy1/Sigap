
import 'package:flutter/material.dart';

/// Tipografi sistem desain "Dispatch Console".
///
/// Tiga peran yang tidak boleh tertukar:
///
/// * **Unbounded** — judul, tombol besar, angka hero. Memberi karakter.
/// * **Inter** — body text. Netral, mudah dibaca.
/// * **JetBrainsMono** — SEMUA angka & data: ETA, jarak, koordinat, timestamp,
///   label huruf kapital kecil. Inilah yang memberi kesan "readout konsol".
///   Kalau angka ditulis dengan Inter, seluruh identitas visualnya hilang.
///
/// CATATAN TEKNIS PENTING — ketiga font ini VARIABLE (satu berkas, sumbu
/// `wght` kontinu). Menyetel `fontWeight` saja pada font variable akan membuat
/// Flutter melakukan penebalan SINTETIS (mengoles glyph), bukan memakai sumbu
/// asli — hasilnya terlihat kotor dan berbeda dari mockup. Karena itu setiap
/// gaya di bawah menyetel `fontVariations` bersama `fontWeight`.
class DispatchType {
  const DispatchType._();

  static const String display = 'Unbounded';
  static const String body = 'Inter';
  static const String mono = 'JetBrainsMono';

  /// Font di-bundel di dalam package `mobile_core`, jadi harus dirujuk dengan
  /// awalan `packages/<nama_package>/`.
  static const String _pkg = 'mobile_core';

  static List<FontVariation> _wght(double w) => [FontVariation('wght', w)];

  /// Judul & angka hero — Unbounded.
  static TextStyle displayStyle({
    required double size,
    double weight = 800,
    Color? color,
    double letterSpacing = -0.01,
    double? height,
  }) {
    return TextStyle(
      fontFamily: display,
      package: _pkg,
      fontSize: size,
      fontWeight: FontWeight.values[(weight ~/ 100) - 1],
      fontVariations: _wght(weight),
      letterSpacing: letterSpacing * size,
      color: color,
      height: height,
    );
  }

  /// Body text — Inter.
  static TextStyle bodyStyle({
    required double size,
    double weight = 500,
    Color? color,
    double? height,
    double letterSpacing = 0,
  }) {
    return TextStyle(
      fontFamily: body,
      package: _pkg,
      fontSize: size,
      fontWeight: FontWeight.values[(weight ~/ 100) - 1],
      fontVariations: _wght(weight),
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  /// Angka & label konsol — JetBrains Mono.
  ///
  /// [tracking] dinyatakan dalam em (seperti CSS `letter-spacing: 0.08em`)
  /// lalu dikalikan ukuran font, supaya nilainya bisa disalin langsung dari
  /// mockup tanpa dihitung ulang.
  static TextStyle monoStyle({
    required double size,
    double weight = 700,
    Color? color,
    double tracking = 0.04,
    double? height,
  }) {
    return TextStyle(
      fontFamily: mono,
      package: _pkg,
      fontSize: size,
      fontWeight: FontWeight.values[(weight ~/ 100) - 1],
      fontVariations: _wght(weight),
      letterSpacing: tracking * size,
      color: color,
      height: height,
    );
  }
}
