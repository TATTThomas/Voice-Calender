class Date {
  Date({required this.date, required this.title, required this.description});
  final String date;
  final String title;
  final String description;

  factory Date.fromJson(Map<String, dynamic> json){
    return Date(
      date: json['date'],
      title: json['title'],
      description: json['description'],
    );
  }
}