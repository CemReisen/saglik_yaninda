import 'package:flutter/material.dart';

class AppColors {
  // Genel zemin
  static const background = Color(0xFFF8F9FA);
  static const white = Color(0xFFFFFFFF);
  static const border = Color(0xFFE0E0E0);

  // Metinler
  static const textPrimary = Color(0xFF333333);
  static const textSecondary = Color(0xFF757575);
  // Açık gri zeminler (ör. #F5F5F5, grey.shade100) üzerinde de yeterli
  // kontrastı (WCAG AA, ~5:1) koruyan ikincil metin rengi. textSecondary
  // (#757575) beyaz zeminde sınırda kalıyor, açık gri zeminde yetersiz —
  // "gri metin/gri zemin" kartlarda (ör. ilaç alındı durumu, detay
  // kutucukları) bunu kullan.
  static const textSecondaryStrong = Color(0xFF616161);

  // Vurgu / Marka
  static const primary = Color(0xFF4DB6AC); // turkuaz (AppBar, aktif renk)
  static const navbarBg = Color(0xFFF1F3F4); // alt bar zemin
  static const navbarInactive = Color(0xFF9E9E9E);
  static const navbarTopStroke = Color.fromRGBO(77, 182, 172, 0.6); // %60 opak

  // Aksiyon renkleri
  static const positive = Color(0xFF4CAF50); // yeşil: Aldım
  static const negative = Color(0xFFE57373); // kırmızı: Atladım

  // Liste arka planı
  static const listItemBg = Color(0xFFF9FBFB);
}
