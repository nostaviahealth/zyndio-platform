
class HealthProtocol {
  final String id;
  final String title;
  final String type; // e.g., 'Sleep', 'Training', 'Nutrition'
  final String summary;
  
  // The 4 Strict Pillars (v2)
  final ProtocolSection lifestyle;
  final ProtocolSection diet;
  final ProtocolSection fitness;
  final ProtocolSection supplements;
  final DateTime createdAt;
  final List<String> citations;

  HealthProtocol({
    required this.id,
    required this.title,
    required this.type,
    required this.summary,
    required this.lifestyle,
    required this.diet,
    required this.fitness,
    required this.supplements,
    required this.createdAt,
    this.citations = const [],
  });

  factory HealthProtocol.fromJson(Map<String, dynamic> json) {
    return HealthProtocol(
      id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: json['title'] ?? 'Zyndio Protocol',
      type: json['type'] ?? 'General',
      summary: json['summary'] ?? '',
      lifestyle: ProtocolSection.fromJson(json['lifestyle'] ?? {'title': 'Lifestyle'}),
      diet: ProtocolSection.fromJson(json['diet'] ?? {'title': 'Diet'}),
      fitness: ProtocolSection.fromJson(json['fitness'] ?? {'title': 'Fitness'}),
      supplements: ProtocolSection.fromJson(json['supplements'] ?? {'title': 'Supplements'}),
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : DateTime.now(),
      citations: (json['citations'] as List?)?.map((e) => e.toString()).toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'type': type,
      'summary': summary,
      'lifestyle': lifestyle.toJson(),
      'diet': diet.toJson(),
      'fitness': fitness.toJson(),
      'supplements': supplements.toJson(),
      'created_at': createdAt.toIso8601String(),
      'citations': citations,
    };
  }

  String toMarkdown() {
    final buffer = StringBuffer();
    buffer.writeln('# $title');
    buffer.writeln('_$type Protocol_\\n');
    if (summary.isNotEmpty) {
      buffer.writeln('$summary\\n');
    }
    
    void addSection(ProtocolSection section) {
      if (section.content.isEmpty && section.actionItems.isEmpty) return;
      buffer.writeln('## ${section.title}');
      if (section.content.isNotEmpty) buffer.writeln('${section.content}\\n');
      for (final item in section.actionItems) {
        buffer.writeln('- $item');
      }
      buffer.writeln('');
    }

    addSection(lifestyle);
    addSection(diet);
    addSection(fitness);
    addSection(supplements);

    return buffer.toString().trim();
  }
}


class ProtocolSection {
  final String title;
  final String content; // Brief overview/philosophy
  final List<String> actionItems; // Specific todo list

  ProtocolSection({
    required this.title, 
    this.content = '', 
    this.actionItems = const []
  });

  factory ProtocolSection.fromJson(Map<String, dynamic> json) {
    return ProtocolSection(
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      actionItems: (json['action_items'] as List?)?.map((e) => e.toString()).toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'content': content,
        'action_items': actionItems,
      };
}
