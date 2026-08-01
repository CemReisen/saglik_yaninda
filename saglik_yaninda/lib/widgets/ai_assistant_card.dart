import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AiAssistantCard extends StatefulWidget {
  final String userName;
  final double complianceRate; // İlaç uyum yüzdesi (Örn: 0.80 veya 1.0)
  final String bloodType;

  const AiAssistantCard({
    super.key,
    required this.userName,
    required this.complianceRate,
    required this.bloodType,
  });

  @override
  State<AiAssistantCard> createState() => _AiAssistantCardState();
}

class _AiAssistantCardState extends State<AiAssistantCard> {
  bool _isLoading = false;
  String _aiMessage =
      "Merhaba! Ben senin akıllı sağlık asistanınım. Günlük sağlık özetin için bana dokun.";

  // API Anahtarın
  final String _apiKey = "AIzaSyAvx2gpBHDO3zl6XJb8yYBIWMA82zs4c5c";

  String _buildDynamicPrompt() {
    int percentage = (widget.complianceRate * 100).toInt();

    return """
    Sen yaşlı bireyler için tasarlanmış şefkatli, saygılı, profesyonel ve motive edici bir akıllı sağlık asistanısın.
    Kullanıcının Adı: ${widget.userName}
    Kan Grubu: ${widget.bloodType}
    Bugünkü İlaç İçme Uyumu: %$percentage
    
    Lütfen ${widget.userName} için maksimum 3 cümlelik, moral verici ve sağlık durumunu destekleyen bir mesaj yaz. 
    Eğer ilaç uyumu %100 ise onu tebrik et. Eğer %100'ün altındaysa, ilaçlarını zamanında almasının önemini nazikçe ve şefkatle hatırlat. Çıktıda sadece mesajın kendisi olsun, ekstra "Merhaba" gibi girişler dışında açıklama yapma.
    """;
  }

  Future<void> _fetchAiResponse() async {
    if (_apiKey.isEmpty || _apiKey.contains("BURAYA")) {
      setState(() {
        _aiMessage = "Lütfen önce API Anahtarını koda ekleyin.";
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _aiMessage = "Sağlık verilerin analiz ediliyor...";
    });

    try {
      print("🔍 Sana özel açık modeller aranıyor...");
      final listUrl = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models?key=$_apiKey',
      );
      final listResponse = await http.get(listUrl);

      if (listResponse.statusCode == 200) {
        var data = jsonDecode(listResponse.body);
        List models = data['models'];
        String? targetModel;

        for (var m in models) {
          List supportedMethods = m['supportedGenerationMethods'] ?? [];
          String name = m['name'];
          if (name.contains("gemini") &&
              supportedMethods.contains("generateContent")) {
            targetModel = name;
            break;
          }
        }

        if (targetModel == null) {
          setState(() {
            _aiMessage =
                "API anahtarınız için metin üretebilen model bulunamadı.";
            _isLoading = false;
          });
          return;
        }

        print("🎯 HEDEF KİLİTLENDİ: '$targetModel'");

        String prompt = _buildDynamicPrompt();
        final url = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/$targetModel:generateContent?key=$_apiKey',
        );

        // 🔥 RETRY LOGIC (OTOMATİK TEKRAR DENEME ALGORİTMASI)
        int maxRetries = 3;
        bool success = false;

        for (int i = 0; i < maxRetries; i++) {
          final response = await http.post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              "contents": [
                {
                  "parts": [
                    {"text": prompt},
                  ],
                },
              ],
              "generationConfig": {"temperature": 0.7},
            }),
          );

          if (response.statusCode == 200) {
            var resultData = jsonDecode(response.body);
            String aiText =
                resultData['candidates'][0]['content']['parts'][0]['text'];

            setState(() {
              _aiMessage = aiText.trim();
              _isLoading = false;
            });
            print("✅ YZ Cevabı Başarıyla Geldi!");
            success = true;
            break; // Başarılı olunca döngüden çık
          } else if (response.statusCode == 503) {
            print(
              "⚠️ Sunucu yoğun (503). ${i + 1}. tekrar deneme yapılıyor...",
            );
            if (i == maxRetries - 1) {
              setState(() {
                _aiMessage =
                    "Şu an sunucular çok yoğun. Lütfen birkaç dakika sonra tekrar dene.";
                _isLoading = false;
              });
            } else {
              // 2 saniye bekleyip tekrar dene
              await Future.delayed(const Duration(seconds: 2));
            }
          } else {
            print("❌ Üretim Hatası: ${response.body}");
            setState(() {
              _aiMessage = "API bir hata döndürdü. Konsola bak.";
              _isLoading = false;
            });
            break; // 503 harici bir hataysa direkt çık
          }
        }
      } else {
        print("❌ Model Listesi Çekilemedi: ${listResponse.body}");
        setState(() {
          _aiMessage = "Google'ın model listesine ulaşılamadı.";
          _isLoading = false;
        });
      }
    } catch (e) {
      print("🔌 Bağlantı Hatası: $e");
      setState(() {
        _aiMessage = "Bağlantı kurulamadı. İnternetini kontrol et.";
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: _isLoading ? null : _fetchAiResponse,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF00B4DB), Color(0xFF0083B0)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0083B0).withOpacity(0.4),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.auto_awesome, // Yapay zeka ışıltı ikonu
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  "Akıllı Asistan",
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _isLoading
                ? const Row(
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "Sağlık verilerin analiz ediliyor...",
                          style: TextStyle(
                            color: Colors.white70,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  )
                : Text(
                    _aiMessage,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
            if (!_isLoading && _aiMessage.startsWith("Merhaba! Ben"))
              Padding(
                padding: const EdgeInsets.only(top: 12.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      "Analiz için tıkla 👉",
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
