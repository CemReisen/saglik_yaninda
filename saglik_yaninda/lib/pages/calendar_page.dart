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

  String _getShortDayName(DateTime date) {
    List<String> weekDays = ["Pzt", "Sal", "Çar", "Per", "Cum", "Cmt", "Paz"];
    return weekDays[date.weekday - 1];
  }

  @override
  Widget build(BuildContext context) {
    String selectedDayShortName = _getShortDayName(_selectedDay);

    return Scaffold(
      backgroundColor: const Color(0xFFECEFF1),

      appBar: AppBar(
        toolbarHeight: 40,
        title: Text(
          "İlaç Takvimi",
          style: GoogleFonts.poppins(
            color: const Color(0xFF263238),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),

      body: Column(
        children: [
          // 🗓️ TAKVİM KUTUSU
          Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TableCalendar(
              locale: 'tr_TR',
              firstDay: DateTime.utc(2020, 10, 16),
              lastDay: DateTime.utc(2030, 3, 14),
              focusedDay: _focusedDay,
              calendarFormat: _calendarFormat,

              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
              },
              onFormatChanged: (format) {
                setState(() {
                  _calendarFormat = format;
                });
              },

              // HEADER AYARLARI
              headerStyle: HeaderStyle(
                formatButtonVisible: true,
                titleCentered: true,
                formatButtonShowsNext: false,
                headerPadding: EdgeInsets.zero,
                formatButtonDecoration: BoxDecoration(
                  color: const Color(0xFFE0F2F1),
                  borderRadius: BorderRadius.circular(12),
                ),
                formatButtonTextStyle: const TextStyle(
                  color: Color(0xFF009688),
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

          // Seçilen Gün Başlığı
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 5),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "${_selectedDay.day}.${_selectedDay.month}.${_selectedDay.year} Tarihli İlaçlar",
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600],
                ),
              ),
            ),
          ),

          // LİSTELEME
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(user!.uid)
                  .collection('medicines')
                  .orderBy('hour')
                  .orderBy('minute')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _buildEmptyState("Kayıtlı ilaç yok.");
                }

                var allMedicines = snapshot.data!.docs;
                var filteredMedicines = allMedicines.where((doc) {
                  var data = doc.data() as Map<String, dynamic>;
                  String repeatType = data['repeatType'] ?? 'daily';
                  List<dynamic> days = data['days'] ?? [];

                  if (repeatType == 'daily' || repeatType == 'Her Gün')
                    return true;
                  if (days.contains(selectedDayShortName)) return true;

                  return false;
                }).toList();

                if (filteredMedicines.isEmpty) {
                  return _buildEmptyState("Bu tarihte ilaç planı yok. 🍃");
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filteredMedicines.length,
                  itemBuilder: (context, index) {
                    var data =
                        filteredMedicines[index].data() as Map<String, dynamic>;

                    String name = data['name'] ?? '';
                    String dose = data['dose'] ?? '';
                    int hour = data['hour'] ?? 0;
                    int minute = data['minute'] ?? 0;
                    String formattedTime =
                        "${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}";
                    String hungerStatus = data['hungerStatus'] ?? '';
                    bool isCritical = data['isCritical'] ?? false;

                    return Card(
                      elevation: 2,
                      // 🔥 MORUMSU RENGİ YOK EDEN SİHİRLİ KODLAR 🔥
                      surfaceTintColor: Colors.transparent, // Mor gölgeyi siler
                      color: Colors.white, // Bembeyaz yapar
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),

                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            // Kritikse Kırmızı, Değilse Bizim Yeşilimiz
                            color: isCritical
                                ? Colors.red[50]
                                : const Color(0xFFE0F2F1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isCritical
                                  ? Colors.red.withOpacity(0.3)
                                  : const Color(0xFFB2DFDB),
                            ),
                          ),
                          child: Text(
                            formattedTime,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isCritical
                                  ? Colors.red
                                  : const Color(0xFF00695C), // Koyu Yeşil Yazı
                            ),
                          ),
                        ),
                        title: Row(
                          children: [
                            Text(
                              name,
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.black87,
                              ),
                            ),
                            if (isCritical) ...[
                              const SizedBox(width: 6),
                              const Icon(
                                Icons.warning_amber_rounded,
                                size: 18,
                                color: Colors.red,
                              ),
                            ],
                          ],
                        ),
                        subtitle: Text(
                          "$dose • $hungerStatus",
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 13,
                          ),
                        ),
                        trailing: Icon(
                          Icons.chevron_right,
                          color: Colors.grey[400],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String msg) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.calendar_today_outlined,
            size: 50,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 10),
          Text(msg, style: TextStyle(color: Colors.grey[600])),
        ],
      ),
    );
  }
}
