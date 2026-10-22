import 'package:diacritic/diacritic.dart';

/// Normaliza uma string para comparação de busca por nome.
///
/// Aplica, nesta ordem:
/// 1. `toLowerCase()` — torna a comparação insensível a maiúsculas/minúsculas;
/// 2. `trim()` — remove espaços em branco no início e no fim;
/// 3. `removeDiacritics` (pacote `diacritic`) — remove acentos/diacríticos,
///    tornando a comparação insensível a caracteres acentuados.
///
/// Com isso, termos como `"Supino Inclinado"`, `"supino inclinado"` e
/// `"SÚPINO"` tornam-se diretamente comparáveis.
///
/// Atende ao Requirement 3.1 (busca parcial, case-insensitive e
/// accent-insensitive).
///
/// Exemplos:
/// ```dart
/// normalize('  SÚPINO  '); // 'supino'
/// normalize('Rosca Direta'); // 'rosca direta'
/// ```
String normalize(String s) => removeDiacritics(s.toLowerCase().trim());
