# Requirements Document

## Introduction

O Gym Workout App é um aplicativo mobile que permite aos usuários visualizar e executar treinos de academia com apoio visual. Cada exercício é acompanhado de imagens/GIFs animados que demonstram a execução correta do movimento. O aplicativo integra-se com a API ExerciseDB (via RapidAPI), que fornece mais de 1.500 exercícios com GIFs animados e suporte a busca por grupo muscular, equipamento e nome do exercício.

O objetivo é oferecer uma experiência mobile fluida para que praticantes de musculação possam descobrir exercícios, montar e seguir treinos, e aprender a forma correta de execução por meio de demonstrações visuais.

## Glossary

- **App**: O aplicativo mobile Gym Workout App executado em dispositivos Android e iOS.
- **ExerciseDB_Client**: O componente do App responsável por consumir a API ExerciseDB via RapidAPI.
- **ExerciseDB_API**: A API externa ExerciseDB hospedada na RapidAPI que fornece dados de exercícios, GIFs animados e capacidades de busca.
- **Exercise**: Um registro de exercício contendo identificador, nome, grupo muscular alvo, equipamento necessário e GIF de demonstração.
- **Workout**: Uma coleção ordenada de exercícios montada pelo usuário.
- **Exercise_Catalog**: A tela/funcionalidade que lista e permite navegar pelos exercícios disponíveis.
- **Search_Component**: O componente do App responsável por processar buscas por músculo, equipamento e nome.
- **Cache_Store**: O armazenamento local do App que guarda dados de exercícios previamente carregados.
- **User**: A pessoa que utiliza o App para visualizar e executar treinos.

## Requirements

### Requirement 1: Navegação pelo catálogo de exercícios

**User Story:** Como usuário, quero navegar por uma lista de exercícios disponíveis, para que eu possa descobrir exercícios para o meu treino.

#### Acceptance Criteria

1. WHEN o usuário abre a tela de catálogo, THE App SHALL solicitar a lista de exercícios ao ExerciseDB_Client e exibir o nome e o GIF de demonstração de cada Exercise retornado.
2. WHILE a requisição da lista de exercícios ao ExerciseDB_Client está pendente, THE App SHALL exibir um indicador de carregamento.
3. WHEN a lista de exercícios é recebida da ExerciseDB_API, THE App SHALL exibir os exercícios em páginas de no máximo 20 itens por página.
4. WHEN o usuário rola até o final da lista exibida e existe ao menos uma página adicional disponível, THE App SHALL carregar e exibir a próxima página de no máximo 20 exercícios.
5. IF o usuário rola até o final da lista exibida e não existe nenhuma página adicional disponível, THEN THE App SHALL manter a lista atual sem solicitar novos dados à ExerciseDB_API.
6. IF a ExerciseDB_API não retornar dados dentro de 10 segundos, THEN THE App SHALL interromper o carregamento, exibir uma mensagem de erro indicando falha no carregamento dos exercícios e exibir uma opção de tentar novamente.
7. WHEN o usuário aciona a opção de tentar novamente após uma falha de carregamento, THE App SHALL reenviar a solicitação da lista de exercícios ao ExerciseDB_Client.

### Requirement 2: Visualização de detalhes e GIF do exercício

**User Story:** Como usuário, quero ver os detalhes de um exercício com o GIF animado da execução, para que eu aprenda a forma correta de realizá-lo.

#### Acceptance Criteria

1. WHEN o usuário seleciona um Exercise no catálogo, THE App SHALL exibir, em até 2 segundos, a tela de detalhes contendo o nome, o grupo muscular alvo, o equipamento necessário e a área de demonstração do GIF animado do Exercise selecionado.
2. WHEN a tela de detalhes é exibida, THE App SHALL iniciar a reprodução do GIF animado do Exercise em até 10 segundos após a abertura da tela.
3. WHILE a tela de detalhes está exibida e o GIF animado foi carregado, THE App SHALL reproduzir o GIF animado do Exercise em loop contínuo e ininterrupto.
4. IF o GIF do Exercise não for carregado dentro de 10 segundos após a abertura da tela de detalhes, THEN THE App SHALL exibir uma imagem substituta (placeholder), exibir uma mensagem indicando a indisponibilidade da demonstração e oferecer a opção de tentar carregar novamente, mantendo visíveis o nome, o grupo muscular alvo e o equipamento necessário do Exercise.

### Requirement 3: Busca por músculo, equipamento e nome

**User Story:** Como usuário, quero buscar exercícios por grupo muscular, equipamento ou nome, para que eu encontre rapidamente exercícios específicos.

#### Acceptance Criteria

1. WHEN o usuário informa um termo de busca com ao menos 2 caracteres por nome de exercício, THE Search_Component SHALL solicitar à ExerciseDB_API os exercícios cujo nome contém o termo informado de forma parcial, sem diferenciação entre maiúsculas e minúsculas nem entre caracteres acentuados e não acentuados, e exibir os resultados em até 10 segundos.
2. WHEN o usuário seleciona um grupo muscular como filtro, THE Search_Component SHALL solicitar à ExerciseDB_API os exercícios associados ao grupo muscular selecionado e exibir os resultados em até 10 segundos.
3. WHEN o usuário seleciona um tipo de equipamento como filtro, THE Search_Component SHALL solicitar à ExerciseDB_API os exercícios associados ao equipamento selecionado e exibir os resultados em até 10 segundos.
4. IF a busca por nome, por grupo muscular ou por equipamento não retornar nenhum Exercise, THEN THE App SHALL exibir uma mensagem informando que nenhum exercício foi encontrado para os critérios aplicados.
5. WHEN o usuário limpa o termo de busca e os filtros, THE App SHALL exibir novamente o catálogo completo de exercícios.
6. IF uma requisição de busca à ExerciseDB_API falhar ou não retornar dados dentro de 10 segundos, THEN THE App SHALL preservar os critérios de busca informados e exibir uma mensagem de erro informando falha na busca e oferecer a opção de tentar novamente.

### Requirement 4: Montagem de treinos

**User Story:** Como usuário, quero montar um treino adicionando exercícios selecionados, para que eu possa organizar minha sessão de academia.

#### Acceptance Criteria

1. WHEN o usuário adiciona um Exercise a um Workout, THE App SHALL inserir o Exercise ao final da lista ordenada do Workout, preservando a ordem dos exercícios já existentes.
2. WHEN o usuário remove um Exercise de um Workout, THE App SHALL excluir o Exercise da lista do Workout e reordenar os exercícios restantes mantendo suas posições relativas originais sem lacunas na ordem.
3. WHEN o usuário salva um Workout que contém entre 1 e 50 exercícios e um nome válido, THE App SHALL persistir o Workout no armazenamento local do dispositivo e exibir uma confirmação de que o treino foi salvo.
4. WHERE o usuário atribui um nome ao Workout, THE App SHALL aceitar um nome com 1 a 60 caracteres, desconsiderando espaços em branco no início e no fim, e associar o nome informado ao Workout salvo.
5. IF o usuário tenta salvar um Workout sem nenhum Exercise, THEN THE App SHALL impedir o salvamento, preservar o estado atual do Workout em edição sem persisti-lo e exibir uma mensagem solicitando a adição de ao menos um exercício.
6. IF o usuário tenta salvar um Workout sem nome ou com nome contendo apenas espaços em branco, THEN THE App SHALL impedir o salvamento, preservar o estado atual do Workout em edição sem persisti-lo e exibir uma mensagem solicitando a informação de um nome válido.
7. IF a persistência de um Workout no armazenamento local falhar, THEN THE App SHALL manter o Workout em edição sem perda de dados e exibir uma mensagem informando que não foi possível salvar o treino.

### Requirement 5: Execução de treino

**User Story:** Como usuário, quero seguir um treino salvo exercício por exercício, para que eu possa executar minha sessão de forma guiada.

#### Acceptance Criteria

1. WHEN o usuário inicia a execução de um Workout salvo, THE App SHALL exibir o primeiro Exercise na ordem do Workout com seu GIF de demonstração e indicar a posição atual (por exemplo, "1 de N") em relação ao total de exercícios do Workout.
2. WHILE o usuário está visualizando um Exercise que não é o último na ordem do Workout, WHEN o usuário avança para o próximo exercício, THE App SHALL exibir o Exercise seguinte na ordem do Workout com seu GIF de demonstração e atualizar a indicação de posição atual.
3. WHILE o usuário está visualizando o primeiro Exercise na ordem do Workout, THE App SHALL desabilitar a ação de retornar ao exercício anterior.
4. WHILE o usuário está visualizando um Exercise que não é o primeiro na ordem do Workout, WHEN o usuário retorna ao exercício anterior, THE App SHALL exibir o Exercise anterior na ordem do Workout com seu GIF de demonstração e atualizar a indicação de posição atual.
5. WHEN o usuário avança a partir do último Exercise na ordem do Workout, THE App SHALL exibir uma tela de conclusão do treino.
6. IF o GIF de demonstração do Exercise em execução não puder ser carregado, THEN THE App SHALL exibir uma imagem substituta (placeholder) e uma mensagem indicando indisponibilidade da demonstração, mantendo a navegação entre exercícios disponível.

### Requirement 6: Armazenamento em cache de exercícios

**User Story:** Como usuário, quero que os exercícios já carregados fiquem disponíveis sem recarregar, para que o aplicativo responda mais rápido e consuma menos dados.

#### Acceptance Criteria

1. WHEN um Exercise é recebido da ExerciseDB_API, THE App SHALL armazenar os dados do Exercise no Cache_Store, mantendo no máximo 1.500 exercícios e, ao exceder esse limite, removendo os exercícios acessados há mais tempo.
2. WHEN o usuário solicita um Exercise presente no Cache_Store e armazenado há 24 horas ou menos, THE App SHALL exibir os dados a partir do Cache_Store sem solicitar à ExerciseDB_API.
3. WHEN o usuário solicita um Exercise presente no Cache_Store e armazenado há mais de 24 horas, THE App SHALL solicitar os dados atualizados à ExerciseDB_API e, após recebê-los, substituir os dados correspondentes no Cache_Store.
4. WHILE o dispositivo está sem conexão de rede e existe ao menos um Exercise no Cache_Store, THE App SHALL exibir os exercícios disponíveis no Cache_Store independentemente do tempo de armazenamento.
5. IF o dispositivo está sem conexão de rede e o Exercise solicitado não está no Cache_Store, THEN THE App SHALL exibir uma mensagem informando a indisponibilidade por falta de conexão e preservar os dados já presentes no Cache_Store.

### Requirement 7: Integração e autenticação com a ExerciseDB_API

**User Story:** Como usuário, quero que o aplicativo acesse os dados de exercícios de forma confiável, para que eu tenha acesso ao catálogo completo da ExerciseDB.

#### Acceptance Criteria

1. WHEN o ExerciseDB_Client realiza uma requisição à ExerciseDB_API, THE ExerciseDB_Client SHALL incluir a chave de autenticação da RapidAPI e o identificador de host da RapidAPI nos cabeçalhos da requisição.
2. IF a chave de autenticação da RapidAPI não estiver configurada no momento da requisição, THEN THE ExerciseDB_Client SHALL abortar a requisição sem enviá-la e reportar ao App uma falha de configuração de autenticação.
3. IF a ExerciseDB_API retornar um erro de autenticação, THEN THE App SHALL exibir uma mensagem informando falha de autenticação com o serviço de exercícios e permanecer na tela atual sem alterar os dados já exibidos.
4. IF a ExerciseDB_API retornar um erro de limite de requisições excedido, THEN THE App SHALL exibir uma mensagem informando que o limite de uso foi atingido e orientar o usuário a tentar novamente mais tarde, preservando os dados já exibidos na tela atual.
5. WHEN uma requisição à ExerciseDB_API falha por erro de rede, THE ExerciseDB_Client SHALL realizar até 2 novas tentativas, aguardando no máximo 3 segundos entre cada tentativa.
6. IF as 2 novas tentativas de requisição por erro de rede também falharem, THEN THE App SHALL exibir uma mensagem informando falha de comunicação com o serviço de exercícios e oferecer a opção de tentar novamente.
