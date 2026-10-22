# Implementation Plan: Gym Workout App

## Overview

Este plano converte o design em uma série de tarefas de codificação incrementais em **Flutter/Dart**. Cada tarefa constrói sobre as anteriores e termina com a integração dos componentes, sem código órfão. A ordem segue a arquitetura em camadas: primeiro a estrutura e as entidades de domínio, depois a camada de dados (cliente HTTP, cache, conectividade), em seguida os repositórios com suas regras de cache/retry, os Cubits de apresentação e, por fim, as páginas e o wiring final.

Os testes de propriedade (PBT) usam o pacote `glados`, cada propriedade implementada por um único teste rodando no mínimo 100 iterações, com a tag de comentário no formato: `Feature: gym-workout-app, Property {N}: {texto}`. Tarefas marcadas com `*` são opcionais (testes) e podem ser puladas para um MVP mais rápido.

## Tasks

- [x] 1. Configurar estrutura do projeto Flutter e dependências
  - Inicializar/estruturar o projeto Flutter com pastas `lib/presentation`, `lib/domain`, `lib/data` e `test/`
  - Adicionar dependências ao `pubspec.yaml`: `dio`, `cached_network_image`, `sqflite`, `sqflite_common_ffi` (testes), `flutter_bloc`, `connectivity_plus`, `diacritic`; e `glados` em dev_dependencies
  - Configurar leitura da chave/host da RapidAPI via `--dart-define` (sem segredos versionados)
  - _Requirements: 7.1_

- [x] 2. Implementar entidades de domínio e erros
  - [x] 2.1 Criar entidades de domínio e modelos
    - Implementar `Exercise`, `Workout`, `ExercisePage`, `CachedExercise` conforme o design (campos e tipos)
    - Implementar a hierarquia `sealed class AppFailure` com `TimeoutError`, `AuthConfigurationError`, `AuthError`, `RateLimitError`, `NetworkError`, `OfflineUnavailableError`, `PersistenceError`
    - _Requirements: 2.1, 4.1, 4.2, 4.3, 4.4_

  - [x] 2.2 Implementar função de normalização de busca
    - Implementar `normalize(String)` aplicando `toLowerCase`, `trim` e remoção de diacríticos (`diacritic`)
    - _Requirements: 3.1_

  - [ ]* 2.3 Escrever teste de propriedade para a view-model de detalhes do exercício
    - **Property 5: Detalhes do exercício contêm todos os campos exigidos**
    - **Validates: Requirements 2.1**

- [x] 3. Implementar paginação do catálogo (função pura de domínio)
  - [x] 3.1 Implementar função de paginação que divide uma lista em `ExercisePage` de no máximo 20 itens com cálculo de `hasMore`
    - _Requirements: 1.3, 1.4, 1.5_

  - [ ]* 3.2 Escrever teste de propriedade para a paginação
    - **Property 1: Paginação produz páginas de no máximo 20 itens cobrindo toda a lista**
    - **Validates: Requirements 1.3, 1.4, 1.5**

- [x] 4. Implementar busca e filtros (matchers de domínio)
  - [x] 4.1 Implementar matcher de busca por nome (parcial, usando `normalize`) e filtros por `bodyPart` e `equipment`
    - _Requirements: 3.1, 3.2, 3.3_

  - [ ]* 4.2 Escrever teste de propriedade para a busca por nome
    - **Property 2: Busca por nome é parcial, insensível a maiúsculas e a acentos**
    - **Validates: Requirements 3.1**

  - [ ]* 4.3 Escrever teste de propriedade para os filtros por campo
    - **Property 3: Filtro por campo retorna o subconjunto correto e completo**
    - **Validates: Requirements 3.2, 3.3**

- [x] 5. Checkpoint - Garantir que os testes passam
  - Garanta que todos os testes passam; pergunte ao usuário caso surjam dúvidas.

- [x] 6. Implementar o ConnectivityService
  - [x] 6.1 Implementar `ConnectivityService` (interface + implementação com `connectivity_plus`) expondo `isOnline()` e `onConnectivityChanged()`
    - _Requirements: 6.4, 6.5_

- [x] 7. Implementar o CacheStore (SQLite)
  - [x] 7.1 Criar o esquema SQLite e a implementação do `CacheStore`
    - Criar tabelas `exercises`, `workouts`, `workout_exercises` e índice `idx_exercises_accessed_at`
    - Implementar operações de exercícios: `getExercise`, `getAllExercises`, `upsertExercise`, `touchExercise`, `countExercises`, `evictLeastRecentlyAccessed`
    - Implementar operações de treino: `saveWorkout`, `getWorkouts`, `getWorkout` preservando a ordem por `position`
    - _Requirements: 6.1, 6.2, 6.3, 4.3_

  - [ ]* 7.2 Escrever teste de propriedade para o limite LRU do cache
    - **Property 14: O cache respeita o limite de 1500 com remoção LRU**
    - **Validates: Requirements 6.1**

  - [ ]* 7.3 Escrever teste de propriedade para o round-trip de persistência de treino
    - **Property 8: Persistência de treino é um round-trip fiel**
    - **Validates: Requirements 4.3**
    - Usar SQLite em memória (`sqflite_common_ffi`)

- [x] 8. Implementar o ExerciseDbClient (dio) com interceptors
  - [x] 8.1 Implementar `ExerciseDbClient` com `dio`, timeout de 10s e os métodos `fetchExercises`, `fetchByName`, `fetchByBodyPart`, `fetchByEquipment`, incluindo o DTO `ExerciseDto` e mapeamento para `Exercise`
    - _Requirements: 1.1, 1.3, 3.1, 3.2, 3.3_

  - [x] 8.2 Implementar o `AuthInterceptor`
    - Verificar presença da chave; se ausente, abortar com `AuthConfigurationError`; caso contrário injetar `X-RapidAPI-Key` e `X-RapidAPI-Host`
    - _Requirements: 7.1, 7.2_

  - [x] 8.3 Implementar o `RetryInterceptor` e o mapeamento de status HTTP
    - Até 2 novas tentativas em erro de rede com intervalo ≤ 3s, propagando `NetworkError`; mapear 401/403 → `AuthError`, 429 → `RateLimitError` (sem retry)
    - _Requirements: 7.3, 7.4, 7.5, 7.6_

  - [ ]* 8.4 Escrever teste de propriedade para os cabeçalhos de autenticação
    - **Property 17: Toda requisição à API inclui os cabeçalhos de autenticação da RapidAPI**
    - **Validates: Requirements 7.1**

  - [ ]* 8.5 Escrever teste de propriedade para a ausência de chave
    - **Property 18: Ausência de chave aborta a requisição com falha de configuração**
    - **Validates: Requirements 7.2**

  - [ ]* 8.6 Escrever teste de propriedade para a política de retry de rede
    - **Property 19: Falha de rede dispara no máximo 2 novas tentativas e propaga erro de comunicação**
    - **Validates: Requirements 7.5, 7.6**
    - Usar transporte HTTP mockado e relógio/temporizador falso

  - [ ]* 8.7 Escrever testes de exemplo para o mapeamento de status HTTP
    - Respostas 401/403 → `AuthError`; 429 → `RateLimitError`
    - _Requirements: 7.3, 7.4_

- [x] 9. Checkpoint - Garantir que os testes passam
  - Garanta que todos os testes passam; pergunte ao usuário caso surjam dúvidas.

- [x] 10. Implementar o ExerciseRepository (cache + rede + offline)
  - [x] 10.1 Implementar `ExerciseRepositoryImpl` orquestrando `ExerciseDbClient`, `CacheStore` e `ConnectivityService`
    - `getCatalogPage` (paginação), `getExercise` (política de origem cache/rede/offline), buscas (`searchByName`, `searchByBodyPart`, `searchByEquipment`)
    - Aplicar upsert com limite LRU (1500) e expiração de 24h; atualizar `accessedAt`
    - _Requirements: 1.1, 3.1, 3.2, 3.3, 6.1, 6.2, 6.3, 6.4, 6.5_

  - [ ]* 10.2 Escrever teste de propriedade para a resolução de origem dos dados
    - **Property 15: A resolução da origem dos dados respeita expiração e conectividade**
    - **Validates: Requirements 6.2, 6.3, 6.4**
    - Usar fakes de store/conectividade e idades de cache em torno de 24h

  - [ ]* 10.3 Escrever teste de propriedade para offline sem cache
    - **Property 16: Offline sem cache sinaliza indisponibilidade preservando o cache**
    - **Validates: Requirements 6.5**

- [x] 11. Implementar o WorkoutRepository e o validador de treino
  - [x] 11.1 Implementar `WorkoutRepositoryImpl` (`save`, `getAll`, `getById`) sobre o `CacheStore` e o validador de salvamento (nome 1..60 após trim, 1..50 exercícios), mapeando falha de persistência para `PersistenceError`
    - _Requirements: 4.3, 4.4, 4.5, 4.6, 4.7_

  - [ ]* 11.2 Escrever teste de propriedade para a validação de salvamento
    - **Property 9: Validação de salvamento aceita somente nome e quantidade válidos**
    - **Validates: Requirements 4.4, 4.5, 4.6**

  - [ ]* 11.3 Escrever teste de exemplo para falha de persistência
    - Store que lança exceção; treino em edição preservado e `PersistenceError` sinalizado
    - _Requirements: 4.7_

- [x] 12. Checkpoint - Garantir que os testes passam
  - Garanta que todos os testes passam; pergunte ao usuário caso surjam dúvidas.

- [x] 13. Implementar o CatalogCubit e o SearchCubit
  - [x] 13.1 Implementar `CatalogCubit` com estados `CatalogLoading`/`CatalogLoaded`/`CatalogError`, scroll infinito, timeout e retry
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7_

  - [x] 13.2 Implementar `SearchCubit` com debounce, critérios de busca, resultado vazio, limpeza de filtros e erro preservando critérios
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6_

  - [ ]* 13.3 Escrever teste de propriedade para limpar busca/filtros
    - **Property 4: Limpar busca e filtros restaura o catálogo completo**
    - **Validates: Requirements 3.5**

  - [ ]* 13.4 Escrever testes de exemplo para estados de UI do catálogo e busca
    - Loading durante requisição pendente; mensagem "nenhum exercício encontrado"; timeout/retry preservando critérios
    - _Requirements: 1.2, 1.6, 1.7, 3.4, 3.6_

- [x] 14. Implementar o WorkoutBuilderCubit
  - [x] 14.1 Implementar `WorkoutBuilderCubit` com adicionar (ao final), remover (reordenação contígua), validar e salvar
    - _Requirements: 4.1, 4.2, 4.3, 4.5, 4.6, 4.7_

  - [ ]* 14.2 Escrever teste de propriedade para adicionar exercício
    - **Property 6: Adicionar exercício insere ao final preservando a ordem existente**
    - **Validates: Requirements 4.1**

  - [ ]* 14.3 Escrever teste de propriedade para remover exercício
    - **Property 7: Remover exercício mantém ordem contígua sem lacunas**
    - **Validates: Requirements 4.2**

- [x] 15. Implementar o WorkoutRunnerCubit
  - [x] 15.1 Implementar `WorkoutRunnerCubit` com índice atual, navegação anterior/próximo, desabilitar voltar no índice 0, posição "k de N" e estado de conclusão
    - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5_

  - [ ]* 15.2 Escrever teste de propriedade para o estado inicial da execução
    - **Property 10: Estado inicial da execução aponta para o primeiro exercício**
    - **Validates: Requirements 5.1**

  - [ ]* 15.3 Escrever teste de propriedade para a navegação avançar/voltar
    - **Property 11: Navegação avançar/voltar é consistente e é round-trip na posição**
    - **Validates: Requirements 5.2, 5.4**

  - [ ]* 15.4 Escrever teste de propriedade para a ação de voltar desabilitada
    - **Property 12: Ação de voltar é desabilitada apenas no primeiro exercício**
    - **Validates: Requirements 5.3**

  - [ ]* 15.5 Escrever teste de propriedade para a conclusão do treino
    - **Property 13: Avançar a partir do último exercício conclui o treino**
    - **Validates: Requirements 5.5**

- [x] 16. Checkpoint - Garantir que os testes passam
  - Garanta que todos os testes passam; pergunte ao usuário caso surjam dúvidas.

- [x] 17. Implementar as páginas de UI e o componente de GIF
  - [x] 17.1 Implementar `GifView` com `cached_network_image` (loop contínuo, placeholder e mensagem de indisponibilidade, textos preservados)
    - _Requirements: 2.2, 2.3, 2.4, 5.6_

  - [x] 17.2 Implementar `CatalogPage` (lista paginada, loading, erro/retry) e `ExerciseDetailPage` (nome, grupo muscular, equipamento, área do GIF)
    - _Requirements: 1.1, 1.2, 1.3, 1.6, 1.7, 2.1, 2.2, 2.3, 2.4_

  - [x] 17.3 Implementar `SearchPage` (campo de busca, filtros de músculo/equipamento, resultado vazio, limpeza)
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6_

  - [x] 17.4 Implementar `WorkoutBuilderPage` (adicionar/remover/nomear/salvar com confirmação) e `WorkoutRunnerPage` (navegação guiada, posição, conclusão, placeholder de GIF)
    - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 4.6, 5.1, 5.2, 5.3, 5.4, 5.5, 5.6_

  - [ ]* 17.5 Escrever testes de widget para GIF e estados de carregamento
    - Início de carregamento ao montar, configuração de loop e placeholder com textos preservados em caso de falha
    - _Requirements: 2.2, 2.3, 2.4, 5.6_

- [x] 18. Wiring final e injeção de dependências
  - [x] 18.1 Configurar injeção de dependências e roteamento, conectando `ExerciseDbClient`, `CacheStore`, `ConnectivityService`, repositórios, Cubits e páginas no `main.dart`
    - _Requirements: 1.1, 2.1, 3.1, 4.1, 5.1, 6.1, 7.1_

  - [ ]* 18.2 Escrever teste de integração do fluxo cache→rede→offline
    - `ExerciseRepository` com `ConnectivityService` e `CacheStore` reais (SQLite em memória) e `ExerciseDbClient` mockado
    - _Requirements: 6.2, 6.3, 6.4, 6.5_

- [x] 19. Checkpoint final - Garantir que os testes passam
  - Garanta que todos os testes passam; pergunte ao usuário caso surjam dúvidas.

## Notes

- Tarefas marcadas com `*` são opcionais e podem ser puladas para um MVP mais rápido.
- Cada tarefa referencia requisitos específicos para rastreabilidade.
- Os checkpoints garantem validação incremental.
- Os testes de propriedade validam as 19 propriedades universais de correção (pacote `glados`, ≥ 100 iterações, tag `Feature: gym-workout-app, Property N`).
- Os testes unitários/de exemplo validam exemplos concretos e casos de borda.
- Limites temporais (detalhes ≤ 2s — Req 2.1; início de GIF ≤ 10s — Req 2.2) são verificados por medição instrumentada, não por PBT.

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["2.1", "2.2"] },
    { "id": 1, "tasks": ["2.3", "3.1", "4.1", "6.1"] },
    { "id": 2, "tasks": ["3.2", "4.2", "4.3", "7.1", "8.1"] },
    { "id": 3, "tasks": ["7.2", "7.3", "8.2", "8.3"] },
    { "id": 4, "tasks": ["8.4", "8.5", "8.6", "8.7", "10.1", "11.1"] },
    { "id": 5, "tasks": ["10.2", "10.3", "11.2", "11.3", "13.1", "13.2", "14.1", "15.1"] },
    { "id": 6, "tasks": ["13.3", "13.4", "14.2", "14.3", "15.2", "15.3", "15.4", "15.5", "17.1"] },
    { "id": 7, "tasks": ["17.2", "17.3", "17.4"] },
    { "id": 8, "tasks": ["17.5", "18.1"] },
    { "id": 9, "tasks": ["18.2"] }
  ]
}
```
