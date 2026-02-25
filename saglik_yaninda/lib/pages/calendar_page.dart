import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  CalendarFormat _calendarFormat = CalendarFormat.week;
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  final User? user = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('tr_TR', null);
  }

  // --- YARDIMCI FONKSİYONLAR ---
  DateTime? _parseDate(String dateStr) {
    try {
      List<String> parts = dateStr.split('.');
      if (parts.length != 3) return null;
      return DateTime(
        int.parse(parts[2]),
        int.parse(parts[1]),
        int.parse(parts[0]),
      );
    } catch (e) {
      return null;
    }
  }

  String _getShortDayName(DateTime date) {
    List<String> weekDays = ["Pzt", "Sal", "Çar", "Per", "Cum", "Cmt", "Paz"];
    return weekDays[date.weekday - 1];
  }

  bool _hasMedicineOnDay(
    DateTime day,
    List<QueryDocumentSnapshot> allMedicines,
  ) {
    final normalizedDay = DateTime(day.year, day.month, day.day);
    final shortDayName = _getShortDayName(normalizedDay);
    for (var doc in allMedicines) {
      var data = doc.data() as Map<String, dynamic>;
      DateTime? startDate = _parseDate(data['startDate'] ?? '');
      DateTime? endDate = _parseDate(data['endDate'] ?? '');
      if (startDate != null &&
          endDate != null &&
          (normalizedDay.isBefore(startDate) || normalizedDay.isAfter(endDate)))
        continue;
      String repeatType = data['repeatType'] ?? 'daily';
      List<dynamic> days = data['days'] ?? [];
      if (repeatType == 'daily' ||
          repeatType == 'Her Gün' ||
          days.contains(shortDayName))
        return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    String selectedDayShortName = _getShortDayName(_selectedDay);
    DateTime normalizedSelectedDay = DateTime(
      _selectedDay.year,
      _selectedDay.month,
      _selectedDay.day,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFECEFF1),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(user!.uid)
              .collection('medicines')
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(color: Color(0xFF4DB6AC)),
              );
            }

            var allMedicines = snapshot.data?.docs ?? [];
            var filteredMedicines = allMedicines.where((doc) {
              var data = doc.data() as Map<String, dynamic>;
              DateTime? start = _parseDate(data['startDate'] ?? '');
              DateTime? end = _parseDate(data['endDate'] ?? '');
              if (start != null &&
                  end != null &&
                  (normalizedSelectedDay.isBefore(start) ||
                      normalizedSelectedDay.isAfter(end)))
                return false;
              String repeat = data['repeatType'] ?? 'daily';
              return (repeat == 'daily' ||
                  repeat == 'Her Gün' ||
                  (data['days'] as List).contains(selectedDayShortName));
            }).toList();

            // 🔥 SAATE GÖRE SIRALAMA EKLENDİ
            filteredMedicines.sort((a, b) {
              var dataA = a.data() as Map<String, dynamic>;
              var dataB = b.data() as Map<String, dynamic>;
              int timeA = (dataA['hour'] ?? 0) * 60 + (dataA['minute'] ?? 0);
              int timeB = (dataB['hour'] ?? 0) * 60 + (dataB['minute'] ?? 0);
              return timeA.compareTo(timeB);
            });

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  const SizedBox(height: 12), // TOPBAR ALTI SABİT BOŞLUK
                  // 1. HEADER (TEMA RENKLİ)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.02),
                          blurRadius: 10,
                        ),
                      ],
                      border: const Border(
                        left: BorderSide(color: Color(0xFF4DB6AC), width: 4),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "İlaç Takvimi",
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF263238),
                          ),
                        ),
                        const Icon(
                          Icons.calendar_month_rounded,
                          color: Color(0xFF4DB6AC),
                          size: 22,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(
                    height: 12,
                  ), // KARTLAR ARASI EŞİT BOŞLUK (12px)
                  // 2. TAKVİM KUTUSU
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.02),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: TableCalendar(
                      locale: 'tr_TR',
                      firstDay: DateTime.utc(2024, 1, 1),
                      lastDay: DateTime.utc(2030, 12, 31),
                      focusedDay: _focusedDay,
                      calendarFormat: _calendarFormat,
                      selectedDayPredicate: (day) =>
                          isSameDay(_selectedDay, day),
                      availableCalendarFormats: const {
                        CalendarFormat.week: 'Hafta',
                        CalendarFormat.twoWeeks: '2 Hafta',
                        CalendarFormat.month: 'Ay',
                      },
                      calendarBuilders: CalendarBuilders(
                        markerBuilder: (context, date, events) {
                          if (_hasMedicineOnDay(date, allMedicines)) {
                            return Positioned(
                              right: 6,
                              top: 6,
                              child: const Icon(
                                Icons.star_rounded,
                                color: Colors.amber,
                                size: 12,
                              ),
                            );
                          }
                          return null;
                        },
                      ),
                      onDaySelected: (selectedDay, focusedDay) {
                        setState(() {
                          _selectedDay = selectedDay;
                          _focusedDay = focusedDay;
                        });
                      },
                      onFormatChanged: (format) {
                        if (_calendarFormat != format)
                          setState(() {
                            _calendarFormat = format;
                          });
                      },
                      onPageChanged: (focusedDay) {
                        _focusedDay = focusedDay;
                      },
                      headerStyle: HeaderStyle(
                        formatButtonVisible: true,
                        titleCentered: true,
                        formatButtonShowsNext: false,
                        formatButtonDecoration: BoxDecoration(
                          color: const Color(0xFFEAF5F4),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        formatButtonTextStyle: const TextStyle(
                          color: Color(0xFF4DB6AC),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        titleTextStyle: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      calendarStyle: const CalendarStyle(
                        selectedDecoration: BoxDecoration(
                          color: Color(0xFF4DB6AC),
                          shape: BoxShape.circle,
                        ),
                        todayDecoration: BoxDecoration(
                          color: Color(0xFFB2DFDB),
                          shape: BoxShape.circle,
                        ),
                        todayTextStyle: TextStyle(
                          color: Color(0xFF00695C),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(
                    height: 12,
                  ), // KARTLAR ARASI EŞİT BOŞLUK (12px)
                  // 3. İLAÇ LİSTESİ PANELİ (SOFT MINT TEMA)
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF4DB6AC),
                            Color(0xFF43A047),
                          ], // Soft Mint -> Koyu Mint
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF1B5E20).withOpacity(0.15),
                            blurRadius: 15,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "${_selectedDay.day}.${_selectedDay.month}.${_selectedDay.year} Planı",
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    "${filteredMedicines.length} İlaç",
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFFF5F9F8,
                                ), // Çok hafif nane beyazı
                                borderRadius: BorderRadius.circular(26),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(26),
                                child: filteredMedicines.isEmpty
                                    ? Center(
                                        child: Text(
                                          "Bugün için kayıtlı ilaç yok. 🍃",
                                          style: TextStyle(
                                            color: Colors.grey[400],
                                            fontSize: 13,
                                          ),
                                        ),
                                      )
                                    : ListView.builder(
                                        padding: const EdgeInsets.all(12),
                                        itemCount: filteredMedicines.length,
                                        itemBuilder: (context, index) {
                                          var data =
                                              filteredMedicines[index].data()
                                                  as Map<String, dynamic>;
                                          bool isCritical =
                                              data['isCritical'] ?? false;
                                          String time =
                                              "${(data['hour'] ?? 0).toString().padLeft(2, '0')}:${(data['minute'] ?? 0).toString().padLeft(2, '0')}";

                                          return Container(
                                            margin: const EdgeInsets.only(
                                              bottom: 12,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black
                                                      .withOpacity(0.04),
                                                  blurRadius: 10,
                                                  offset: const Offset(0, 4),
                                                ),
                                              ],
                                            ),
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 16,
                                                    vertical: 14,
                                                  ),
                                              child: Row(
                                                children: [
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 10,
                                                          vertical: 6,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: const Color(
                                                        0xFFE0F2F1,
                                                      ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            10,
                                                          ),
                                                    ),
                                                    child: Text(
                                                      time,
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 14,
                                                        color: Color(
                                                          0xFF00695C,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 15),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Row(
                                                          children: [
                                                            if (isCritical)
                                                              const Icon(
                                                                Icons
                                                                    .warning_amber_rounded,
                                                                size: 16,
                                                                color:
                                                                    Colors.red,
                                                              ),
                                                            const SizedBox(
                                                              width: 4,
                                                            ),
                                                            Expanded(
                                                              child: Text(
                                                                data['name'] ??
                                                                    '',
                                                                style: GoogleFonts.poppins(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  fontSize: 16,
                                                                  color:
                                                                      isCritical
                                                                      ? Colors
                                                                            .red[700]
                                                                      : Colors
                                                                            .black87,
                                                                ),
                                                                overflow:
                                                                    TextOverflow
                                                                        .ellipsis,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                        Text(
                                                          "${data['dose'] ?? ''} • ${data['hungerStatus'] ?? ''}",
                                                          style: TextStyle(
                                                            color: Colors
                                                                .grey[500],
                                                            fontSize: 12,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  const Icon(
                                                    Icons.info_outline_rounded,
                                                    color: Color(0xFF3949AB),
                                                    size: 22,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
