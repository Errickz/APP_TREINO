import '../../domain/exercise.dart';

/// Data Transfer Object (DTO) que representa um exercício como retornado pela
/// ExerciseDB_API (RapidAPI).
///
/// Os campos refletem o formato da resposta JSON da API
/// (`id, name, bodyPart, target, equipment, gifUrl`). A conversão para a
/// entidade de domínio [Exercise] é feita por [toDomain].
///
/// Requirements 1.1, 3.1, 3.2, 3.3: fornecer os dados de exercícios obtidos da
/// ExerciseDB_API para as camadas superiores.
class ExerciseDto {
  const ExerciseDto({
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

  /// Cria um [ExerciseDto] a partir do mapa JSON retornado pela API.
  ///
  /// Campos ausentes ou nulos são tratados como string vazia para manter o
  /// mapeamento tolerante a variações da resposta.
  factory ExerciseDto.fromJson(Map<String, dynamic> json) {
    return ExerciseDto(
      id: _asString(json['id']),
      name: _asString(json['name']),
      bodyPart: _asString(json['bodyPart']),
      target: _asString(json['target']),
      equipment: _asString(json['equipment']),
      gifUrl: _asString(json['gifUrl']),
    );
  }

  /// Converte o DTO na entidade de domínio [Exercise].
  Exercise toDomain() {
    return Exercise(
      id: id,
      name: name,
      bodyPart: bodyPart,
      target: target,
      equipment: equipment,
      gifUrl: gifUrl,
    );
  }

  /// Converte um valor dinâmico do JSON em [String], tolerando `null` e tipos
  /// não textuais (ex.: identificadores numéricos).
  static String _asString(dynamic value) {
    if (value == null) return '';
    if (value is String) return value;
    return value.toString();
  }

  @override
  String toString() =>
      'ExerciseDto(id: $id, name: $name, bodyPart: $bodyPart, '
      'target: $target, equipment: $equipment, gifUrl: $gifUrl)';
}
