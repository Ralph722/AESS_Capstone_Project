class EventAgendaItem {
  const EventAgendaItem({required this.time, required this.title});

  final String time;
  final String title;

  factory EventAgendaItem.fromJson(Map<String, dynamic> json) {
    return EventAgendaItem(
      time: (json['time'] as String?)?.trim() ?? '',
      title: (json['title'] as String?)?.trim() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {'time': time, 'title': title};

  static List<EventAgendaItem> listFromJson(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => EventAgendaItem.fromJson(Map<String, dynamic>.from(e)))
        .where((e) => e.title.isNotEmpty)
        .toList();
  }
}
