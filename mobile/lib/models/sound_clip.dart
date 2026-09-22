class SoundClip {
  final String id;
  final String name;
  final String? assetPath;
  final String? filePath;
  final bool isCustom;

  SoundClip({
    required this.id,
    required this.name,
    this.assetPath,
    this.filePath,
    this.isCustom = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'assetPath': assetPath,
      'filePath': filePath,
      'isCustom': isCustom,
    };
  }

  factory SoundClip.fromJson(Map<String, dynamic> json) {
    return SoundClip(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      assetPath: json['assetPath'],
      filePath: json['filePath'],
      isCustom: json['isCustom'] ?? false,
    );
  }
}
