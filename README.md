# Gym Workout App

Aplicativo mobile (Flutter) para navegar por um catálogo de exercícios, visualizar
demonstrações em GIF, buscar por músculo/equipamento/nome, montar e executar treinos,
com cache local e suporte offline. Os dados vêm da **ExerciseDB_API** (RapidAPI).

## Estrutura do projeto

```
lib/
  presentation/   # UI: páginas, widgets e Cubits/BLoCs
  domain/         # Entidades, interfaces de repositório e regras de negócio
  data/           # Cliente HTTP (dio), cache (sqflite), conectividade, config
test/             # Testes unitários, de propriedade (glados) e de widget
```

## Configuração de segredos (RapidAPI)

A chave e o host da RapidAPI **não são versionados**. Eles são lidos em tempo de
compilação via `--dart-define` (ver `lib/data/config/api_config.dart`):

```sh
flutter run \
  --dart-define=RAPIDAPI_KEY=suachaveaqui \
  --dart-define=RAPIDAPI_HOST=exercisedb.p.rapidapi.com
```

Alternativamente, usando um arquivo (não versionado) de defines:

```sh
flutter run --dart-define-from-file=dart_define.json
```

## Pré-requisitos

- Flutter SDK (>= 3.19) e Dart (>= 3.3) instalados e disponíveis no PATH.

## Comandos úteis

```sh
flutter pub get      # resolver dependências
flutter test         # executar testes
flutter analyze      # análise estática
```
