class MedicineModel {
  final String? id; // Firestore document ID
  final String uid;
  final String medicineName;
  final String dose;
  final List<String> times;
  final String? description;
  final String? startDate;
  final String? endDate;

  MedicineModel({
    this.id,
    required this.uid,
    required this.medicineName,
    required this.dose,
    required this.times,
    this.description,
    this.startDate,
    this.endDate,
  });

  Map<String, dynamic> toMap() {
    return {
      "uid": uid,
      "medicineName": medicineName,
      "dose": dose,
      "times": times,
      "description": description,
      "startDate": startDate,
      "endDate": endDate,
    };
  }

  factory MedicineModel.fromMap(Map<String, dynamic> map, String documentId) {
    return MedicineModel(
      id: documentId,
      uid: map["uid"],
      medicineName: map["medicineName"],
      dose: map["dose"],
      times: List<String>.from(map["times"]),
      description: map["description"],
      startDate: map["startDate"],
      endDate: map["endDate"],
    );
  }
}
