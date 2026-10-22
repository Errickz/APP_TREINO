import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Widget reutilizável responsável por renderizar a área de demonstração em GIF
/// de um exercício.
///
/// Usa [CachedNetworkImage] para carregar e cachear o GIF animado. Os GIFs
/// animados são reproduzidos em loop contínuo e ininterrupto por natureza — o
/// decodificador de imagem do Flutter repete automaticamente todos os frames do
/// GIF indefinidamente enquanto o widget estiver montado (Requirement 2.3). Não
/// é necessária nenhuma configuração adicional para habilitar o loop.
///
/// Enquanto o GIF é carregado, exibe um indicador de carregamento
/// (Requirement 2.2). Caso o GIF não possa ser carregado, exibe uma imagem
/// substituta (placeholder) acompanhada de uma mensagem de indisponibilidade e,
/// opcionalmente, uma ação de "Tentar novamente" (Requirements 2.4, 5.6).
///
/// Este widget renderiza **apenas** a área do GIF (placeholder/erro inclusos).
/// Os demais textos do exercício — nome, grupo muscular alvo e equipamento —
/// permanecem sob responsabilidade das páginas que o utilizam, de modo que
/// continuam visíveis mesmo quando a demonstração está indisponível
/// (Requirements 2.4, 5.6).
class GifView extends StatelessWidget {
  const GifView({
    super.key,
    required this.gifUrl,
    this.unavailableMessage = _defaultUnavailableMessage,
    this.retryLabel = _defaultRetryLabel,
    this.semanticLabel,
    this.onRetry,
    this.fit = BoxFit.contain,
  });

  /// Mensagem padrão (PT-BR) exibida quando a demonstração está indisponível.
  static const String _defaultUnavailableMessage = 'Demonstração indisponível';

  /// Rótulo padrão (PT-BR) para a ação de tentar novamente.
  static const String _defaultRetryLabel = 'Tentar novamente';

  /// URL do GIF animado de demonstração do exercício.
  final String gifUrl;

  /// Mensagem exibida no estado de indisponibilidade (Requirements 2.4, 5.6).
  final String unavailableMessage;

  /// Rótulo do botão de nova tentativa, exibido quando [onRetry] é fornecido.
  final String retryLabel;

  /// Rótulo semântico para acessibilidade da área do GIF. Quando nulo, nenhum
  /// rótulo adicional é aplicado e os textos do contexto (fornecidos pela
  /// página) permanecem como a descrição acessível.
  final String? semanticLabel;

  /// Callback opcional acionado quando o usuário solicita nova tentativa de
  /// carregamento. Quando fornecido, um botão de "Tentar novamente" é
  /// renderizado no estado de erro.
  final VoidCallback? onRetry;

  /// Como o GIF deve ser ajustado ao espaço disponível.
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final Widget image = CachedNetworkImage(
      imageUrl: gifUrl,
      fit: fit,
      // GIFs animados reproduzem em loop contínuo automaticamente (Req 2.3).
      placeholder: (context, url) => const _GifPlaceholder(),
      errorWidget: (context, url, error) => _GifUnavailable(
        message: unavailableMessage,
        retryLabel: retryLabel,
        onRetry: onRetry,
      ),
    );

    if (semanticLabel == null) {
      return image;
    }

    return Semantics(
      label: semanticLabel,
      image: true,
      child: image,
    );
  }
}

/// Indicador de carregamento exibido enquanto o GIF está sendo baixado
/// (Requirement 2.2).
class _GifPlaceholder extends StatelessWidget {
  const _GifPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator.adaptive(),
    );
  }
}

/// Estado de indisponibilidade da demonstração: imagem substituta, mensagem e,
/// opcionalmente, ação de nova tentativa (Requirements 2.4, 5.6).
class _GifUnavailable extends StatelessWidget {
  const _GifUnavailable({
    required this.message,
    required this.retryLabel,
    this.onRetry,
  });

  final String message;
  final String retryLabel;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.broken_image_outlined,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            if (onRetry != null) ...<Widget>[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: Text(retryLabel),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
