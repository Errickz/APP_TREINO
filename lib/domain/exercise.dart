/// Entidade de domínio que representa um exercício da ExerciseDB_API.
///
/// Contém os campos exibidos no catálogo, na tela de detalhes e durante a
/// execução de um treino (Requirements 1.1, 2.1).
///
/// A classe é imutável e define igualdade estrutural por todos os seus campos.
class Exercise {
  const Exercise({
    required this.id,
    required this.name,
    required this.bodyPart,
    required this.target,
    required this.equipment,
    required this.gifUrl,
  });

  /// Identificador único do exercício.
  final String id;

  /// Nome do exercício.
  final String name;

  /// Grupo muscular / região corporal.
  final String bodyPart;

  /// Músculo alvo.
  final String target;

  /// Equipamento necessário.
  final String equipment;

  /// URL do GIF animado de demonstração.
  final String gifUrl;

  /// Retorna uma cópia deste exercício com os campos informados substituídos.
  Exercise copyWith({
    String? id,
    String? name,
    String? bodyPart,
    String? target,
    String? equipment,
    String? gifUrl,
  }) {
    return Exercise(
      id: id ?? this.id,
      name: name ?? this.name,
      bodyPart: bodyPart ?? this.bodyPart,
      target: target ?? this.target,
      equipment: equipment ?? this.equipment,
      gifUrl: gifUrl ?? this.gifUrl,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Exercise &&
        other.id == id &&
        other.name == name &&
        other.bodyPart == bodyPart &&
        other.target == target &&
        other.equipment == equipment &&
        other.gifUrl == gifUrl;
  }

  @override
  int get hashCode =>
      Object.hash(id, name, bodyPart, target, equipment, gifUrl);

  @override
  String toString() =>
      'Exercise(id: $id, name: $name, bodyPart: $bodyPart, '
      'target: $target, equipment: $equipment, gifUrl: $gifUrl)';
}
