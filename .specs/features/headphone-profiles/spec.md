# Headphone Profiles & Presets Specification

## Problem Statement

Cada fone de ouvido possui uma assinatura acústica única com imperfeições e desvios em relação a curvas-alvo de referência (como a Harman Target 2019 ou Diffuse Field). Equalizadores gráficos de 10 bandas de frequência fixa são incapazes de corrigir picos ou vales estreitos e específicos (como a agressividade nos 6.5 kHz de fones intra-auriculares em V ou os ressonadores de graves de fones com cancelamento de ruído). Além disso, usuários que possuem múltiplos fones (ex: um over-ear para estúdio/ANC como o Sony WH-1000XM4, um IEM cabeado para monitoramento como o KZ ZSN Pro X, e um TWS para chamadas como o Huawei FreeBuds Pro 5) precisam de uma forma instantânea e padronizada em JSON para alternar, importar e editar esses perfis paramétricos completos sem reconfigurar manualmente slider por slider.

## Goals

- [ ] Implementar o modelo completo `HeadphoneProfile` e `ProfileBand` com suporte a filtros paramétricos (`LOW_SHELF`, `PEAK`, `HIGH_SHELF`) com controle de Frequência livre, Ganho, Q-Factor e Bandwidth.
- [ ] Fornecer perfis pré-configurados e otimizados prontos para uso embutidos no app (`sony_wh1000xm4.json`, `kz_zsn_pro_x.json`, `huawei_freebuds_pro5.json`), acompanhados de um JSON Schema de validação (`_schema.json`).
- [ ] Criar o importador `ProfileImporter` capaz de ler arquivos texto nativos do AutoEQ (`ParametricEQ.txt`) e converte-los instantaneamente para o formato JSON do app.
- [ ] Implementar a interface de listagem (`ProfileListView`), detalhes com tabela de bandas (`ProfileDetailView`) e editor paramétrico inline (`ProfileEditorView`).

## Out of Scope

- Scraping ou download em segundo plano e em tempo real do repositório do AutoEQ via GitHub API na v1 (o usuário importa o arquivo `.txt/.json` local ou usa os embutidos).
- Compartilhamento social em nuvem de perfis entre contas de usuário na v1.

---

## User Stories

### P1: Perfis Embutidos (Sony WH-1000XM4, KZ ZSN Pro X e Huawei FreeBuds Pro 5) ⭐ MVP

**User Story**: As a usuário proprietário dos fones Sony WH-1000XM4, KZ ZSN Pro X e Huawei FreeBuds Pro 5, I want selecionar diretamente o meu modelo na lista do equalizador no notch, so that o som seja corrigido automaticamente para a curva ideal com um único clique.

**Why P1**: Entrega valor imediato e personalizado para o ecossistema de hardware do usuário, demonstrando a superioridade do processamento paramétrico N-bandas sobre o modo simples.

**Acceptance Criteria**:

1. WHEN o usuário abre a lista de perfis do equalizador (`ProfilePicker` ou `ProfileListView`), THEN system SHALL listar na seção "Built-in" os perfis: `Sony WH-1000XM4 — Harman Target (ANC ON)`, `KZ ZSN Pro X — Harman IE Target` e `Huawei FreeBuds Pro 5 — Balanced Target`.
2. WHEN o usuário seleciona o `Sony WH-1000XM4`, THEN system SHALL carregar exatamente 10 bandas paramétricas do oratory1990 com um ganho de pré-amplificação de `-5.6 dB` para compensar os boosts de frequências baixas sem clipping.
3. WHEN o usuário seleciona o `KZ ZSN Pro X` ou o `Huawei FreeBuds Pro 5`, THEN system SHALL carregar suas respectivas 8 bandas paramétricas calculadas (com Preamp de `-4.2 dB` e `-3.5 dB`), domando os agudos agressivos/sibilância e controlando os graves boom do modelo de fábrica.

**Independent Test**: Clicar no menu de fones na interface do notch, escolher cada um dos três modelos sucessivamente, verificando na tabela de detalhes se os valores exatos de Hz, dB, Q e BW são exibidos e se o áudio do sistema muda de perfil instantaneamente.

---

### P2: Importação de Arquivos do AutoEQ (`ParametricEQ.txt`) e JSON

**User Story**: As a audiófilo explorando o banco de dados do AutoEQ ou recebendo perfis de amigos, I want arrastar ou selecionar um arquivo `ParametricEQ.txt` ou `.json` para dentro do equalizador, so that o app converta e salve o perfil na minha biblioteca pessoal.

**Why P2**: Torna o aplicativo universalmente compatível com os mais de 4.000 fones mapeados pela comunidade internacional sem exigir digitação manual de números.

**Acceptance Criteria**:

1. WHEN o usuário clica em "Importar" e escolhe um arquivo no formato padrão do AutoEQ (`Preamp: -6.1 dB \n Filter 1: ON LSC Fc 105 Hz Gain -4.2 dB Q 0.70...`), THEN system SHALL fazer o parsing via expressão regular no `ProfileImporter`, extrair marca/modelo do nome do arquivo e criar o objeto `HeadphoneProfile`.
2. WHEN o parsing é concluído com sucesso, THEN system SHALL salvar o arquivo JSON na pasta do usuário (`~/Library/Application Support/Equalizer/HeadphoneProfiles/custom/`) e adicioná-lo à lista "Meus Perfis".

**Independent Test**: Baixar um arquivo `ParametricEQ.txt` de teste da web, importá-lo pela interface do app e constatar o aparecimento imediato do novo perfil na lista com as bandas corretas.

---

### P3: Editor e Tabela de Bandas Paramétricas (`ProfileEditorView`)

**User Story**: As a usuário avançado que deseja fazer ajustes finos em um perfil existente (ex: dar 2 dB a mais de sub-bass no perfil do XM4), I want abrir a tabela paramétrica detalhada, adicionar/remover bandas ou alterar frequências, e salvar como um novo perfil customizado, so that eu tenha o controle estúdio total.

**Why P3**: Permite que o usuário refine aproximações (como o perfil Custom do Huawei FreeBuds Pro 5) e adecue a curva de equalização ao seu gosto pessoal ou anatomia de ouvido.

**Acceptance Criteria**:

1. WHEN o usuário clica em "Editar" ou "Criar Novo" na `ProfileDetailView`, THEN system SHALL abrir a `ProfileEditorView` listando cada banda com campos editáveis de `Tipo (LOW_SHELF/PEAK/HIGH_SHELF)`, `Freq (20-20000 Hz)`, `Gain (-30 a +30 dB)`, `Q (0.1 a 20.0)` e `BW (0.01 a 10.0)`.
2. WHEN o usuário altera qualquer campo na tabela, THEN system SHALL recalcular a relação entre `Q` e `BW` automaticamente (`BW = 2 / ln(2) * asinh(1 / (2 * Q))` ou vice-versa) e refletir a mudança no preview do gráfico.

**Independent Test**: Abrir o perfil do KZ ZSN Pro X, duplicá-lo, modificar a frequência de sibilância na banda de 6500 Hz para -7 dB no editor, salvar e verificar se a nova versão persiste no disco.

---

## Edge Cases

- WHEN o usuário tenta importar um arquivo JSON corrompido ou que viole o `_schema.json` (ex: banda com frequência negativa ou ganho acima de 100 dB), THEN system SHALL rejeitar a importação exibindo uma mensagem de erro compreensível sem quebrar o app ou sobreescrever perfis válidos.

---

## Success Criteria

- [ ] Todos os 3 perfis nativos dos fones do usuário são carregados a partir do bundle sem erros de decodificação no primeiro boot do app.
- [ ] O importador de `ParametricEQ.txt` processa e decodifica um perfil de 10 a 20 bandas em menos de 50 milissegundos.
