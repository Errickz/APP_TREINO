import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sqflite/sqflite.dart';

import 'data/cache/cache_store.dart';
import 'data/config/api_config.dart';
import 'data/connectivity/connectivity_service.dart';
import 'data/exercise_repository_impl.dart';
import 'data/remote/exercise_db_client.dart';
import 'data/workout_repository_impl.dart';
import 'domain/exercise_repository.dart';
import 'domain/workout_repository.dart';
import 'presentation/catalog/catalog_cubit.dart';
import 'presentation/catalog/catalog_page.dart';
import 'presentation/search/search_cubit.dart';
import 'presentation/search/search_page.dart';
import 'presentation/workout_builder/workout_builder_cubit.dart';
import 'presentation/workout_builder/workout_builder_page.dart';

/// Ponto de entrada do Gym Workout App.
///
/// Realiza o wiring final da injeção de dependências (tarefa 18.1):
/// 1. Lê a configuração da RapidAPI via `--dart-define` ([ApiConfig]).
/// 2. Constrói os singletons da camada de dados: [DioExerciseDbClient]
///    (rede, com `AuthInterceptor` + `RetryInterceptor` já registrados),
///    [SqfliteCacheStore] (persistência SQLite no dispositivo) e
///    [ConnectivityServiceImpl] (estado de conexão).
/// 3. Constrói os repositórios de domínio ([ExerciseRepositoryImpl],
///    [WorkoutRepositoryImpl]) que orquestram a camada de dados.
/// 4. Disponibiliza os repositórios à árvore de widgets via
///    [MultiRepositoryProvider] e roteia para as telas de Catálogo, Busca e
///    Montagem de treino, cada uma com seu próprio `BlocProvider`.
void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // 1) Configuração (segredos injetados via --dart-define).
  final config = ApiConfig.fromEnvironment();

  // 2) Camada de dados (singletons).
  final ExerciseDbClient exerciseDbClient =
      DioExerciseDbClient(config: config);

  final CacheStore cacheStore = SqfliteCacheStore(
    opener: _openCacheDatabase,
    path: 'gym_workout_cache.db',
  );

  final ConnectivityService connectivity = ConnectivityServiceImpl();

  // 3) Repositórios de domínio.
  final ExerciseRepository exerciseRepository = ExerciseRepositoryImpl(
    client: exerciseDbClient,
    cache: cacheStore,
    connectivity: connectivity,
  );

  final WorkoutRepository workoutRepository = WorkoutRepositoryImpl(
    cacheStore: cacheStore,
  );

  runApp(
    GymWorkoutApp(
      config: config,
      exerciseRepository: exerciseRepository,
      workoutRepository: workoutRepository,
    ),
  );
}

/// Abre (ou cria) o banco SQLite de cache no dispositivo usando o `sqflite`
/// padrão.
///
/// O caminho de armazenamento é resolvido a partir de [getDatabasesPath] (o
/// diretório de bancos padrão da plataforma) combinado ao nome do arquivo de
/// cache. As callbacks de configuração/criação do esquema são encaminhadas a
/// partir das [OpenDatabaseOptions] fornecidas pelo [SqfliteCacheStore].
Future<Database> _openCacheDatabase(OpenDatabaseOptions options) async {
  const dbFileName = 'gym_workout_cache.db';
  final databasesPath = await getDatabasesPath();
  final path = '$databasesPath/$dbFileName';
  return openDatabase(
    path,
    version: options.version,
    onConfigure: options.onConfigure,
    onCreate: options.onCreate,
    onUpgrade: options.onUpgrade,
    onDowngrade: options.onDowngrade,
    onOpen: options.onOpen,
  );
}

/// Raiz da aplicação. Disponibiliza os repositórios via
/// [MultiRepositoryProvider] e configura o tema e a tela inicial.
class GymWorkoutApp extends StatelessWidget {
  const GymWorkoutApp({
    super.key,
    required this.config,
    required this.exerciseRepository,
    required this.workoutRepository,
  });

  final ApiConfig config;
  final ExerciseRepository exerciseRepository;
  final WorkoutRepository workoutRepository;

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: <RepositoryProvider>[
        RepositoryProvider<ExerciseRepository>.value(value: exerciseRepository),
        RepositoryProvider<WorkoutRepository>.value(value: workoutRepository),
      ],
      child: MaterialApp(
        title: 'Gym Workout App',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
          useMaterial3: true,
        ),
        home: HomeShell(isApiConfigured: config.isConfigured),
      ),
    );
  }
}

/// Tela inicial com navegação por abas inferiores (Catálogo, Busca, Treino).
///
/// Cada aba injeta seu próprio Cubit via [BlocProvider], lendo os repositórios
/// de domínio do contexto (fornecidos pelo [MultiRepositoryProvider] na raiz).
/// Quando a chave da RapidAPI não está configurada, uma faixa de aviso é
/// exibida no topo; as chamadas de rede ainda assim surgem como
/// `AuthConfigurationError` nos respectivos Cubits (comportamento aceitável).
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, this.isApiConfigured = true});

  /// Indica se a chave da RapidAPI está presente (ver [ApiConfig.isConfigured]).
  final bool isApiConfigured;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    // Constrói as abas sob demanda; cada uma provê seu Cubit com o repositório
    // obtido do contexto. `IndexedStack` preserva o estado entre as trocas.
    final tabs = <Widget>[
      BlocProvider<CatalogCubit>(
        create: (context) =>
            CatalogCubit(context.read<ExerciseRepository>())..loadFirstPage(),
        child: const CatalogPage(),
      ),
      BlocProvider<SearchCubit>(
        create: (context) => SearchCubit(context.read<ExerciseRepository>()),
        child: const SearchPage(),
      ),
      BlocProvider<WorkoutBuilderCubit>(
        create: (context) => WorkoutBuilderCubit(
          repository: context.read<WorkoutRepository>(),
        ),
        // onAddExercise fica `null` por ora: o seletor de exercícios (abrir a
        // busca para escolher um exercício) será conectado em um passo futuro.
        // Com `null`, a página mantém o fluxo mínimo (nomear/remover/salvar).
        child: const WorkoutBuilderPage(),
      ),
    ];

    return Scaffold(
      body: Column(
        children: <Widget>[
          if (!widget.isApiConfigured)
            const _ApiNotConfiguredBanner(),
          Expanded(
            child: IndexedStack(
              index: _index,
              children: tabs,
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.fitness_center),
            label: 'Catálogo',
          ),
          NavigationDestination(
            icon: Icon(Icons.search),
            label: 'Buscar',
          ),
          NavigationDestination(
            icon: Icon(Icons.list_alt),
            label: 'Treino',
          ),
        ],
      ),
    );
  }
}

/// Faixa de aviso exibida quando a chave da RapidAPI não foi configurada.
class _ApiNotConfiguredBanner extends StatelessWidget {
  const _ApiNotConfiguredBanner();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.errorContainer,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: <Widget>[
              Icon(
                Icons.warning_amber_rounded,
                color: theme.colorScheme.onErrorContainer,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Chave da RapidAPI não configurada. Use --dart-define para '
                  'habilitar o catálogo e a busca online.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onErrorContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
