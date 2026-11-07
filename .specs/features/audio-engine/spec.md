# Audio Engine - Input & Output Specification

## Problem Statement

Equalizadores de sistema no macOS tradicionalmente exigem a instalação de drivers virtuais em nível de kernel ou system extensions (como BlackHole ou Loopback) para interceptar o áudio que sai dos aplicativos e roteá-lo para os alto-falantes ou fones. Esses drivers requerem reinicializações, permissões de segurança complexas e frequentemente quebram após atualizações do macOS. Com as APIs introduzidas no macOS 14.2+ (`Core Audio Tap`), é possível criar uma escuta nativa (`AudioHardwareCreateProcessTap`) de fluxo de saída em tempo real diretamente a partir de um aplicativo em espaço de usuário, aplicando processamento digital de sinais (DSP) e equalização de entrada/saída com latência ultra-baixa sem instalar nenhum driver de terceiro.

## Goals

- [ ] Implementar a interceptação e processamento de áudio de saída do sistema utilizando `Core Audio Tap` e `AVAudioEngine`.
- [ ] Configurar o nó de equalização (`AVAudioUnitEQ`) com 10 bandas de resposta dinâmica ou N bandas paramétricas em tempo real sem interrupção de áudio.
- [ ] Gerenciar a alternância automática entre dispositivos de saída do sistema (ex: desconectar fone Bluetooth e retornar aos alto-falantes do Mac).
- [ ] Suportar equalização no pipeline de captura de entrada de microfone (`InputCaptureManager`).

## Out of Scope

- Efeitos de reverberação, modulação ou processamento surround multi-canal 5.1/7.1 (apenas processamento estéreo 2.0 na v1).
- Suporte a sistemas operacionais macOS anteriores à versão 14.2 que não possuem suporte ao `AudioHardwareCreateProcessTap`.

---

## User Stories

### P1: Interceptação e Equalização de Saída do Sistema via Core Audio Tap ⭐ MVP

**User Story**: As a usuário de macOS, I want que todo o áudio tocado pelo meu computador (Spotify, YouTube, Games) passe pelo filtro do equalizador em tempo real ao ativar o aplicativo, so that eu ouça o som equalizado nos meus fones sem precisar configurar saídas virtuais nas configurações do sistema.

**Why P1**: É o coração funcional do produto; sem o processamento de áudio de saída em tempo real, a interface visual não teria utilidade prática.

**Acceptance Criteria**:

1. WHEN o aplicativo inicializa e obtém permissão de áudio, THEN system SHALL criar um process tap via `AudioHardwareCreateProcessTap` no dispositivo primário de saída do macOS (`kAudioHardwarePropertyDefaultOutputDevice`).
2. WHEN os buffers PCM chegam do tap no callback do Core Audio, THEN system SHALL roteá-los para o grafo do `AVAudioEngine` contendo o nó `AVAudioUnitEQ` devidamente configurado com os ganhos das bandas ativas.
3. WHEN o usuário altera um slider de frequência ou ganho de Preamp na UI (`EqualizerViewModel`), THEN system SHALL atualizar a propriedade `.gain` ou `.globalGain` do respectivo `AVAudioUnitEQFilterParameters` em menos de 15ms sem cliques, pops ou interrupções no fluxo sonoro.

**Independent Test**: Reproduzir uma música no Spotify, abrir o app do equalizador e alterar os sliders de graves (32 Hz) e agudos (16 kHz), confirmando auditivamente a mudança imediata no espectro sonoro.

---

### P2: Comutação Automática de Dispositivos de Áudio (`AudioDeviceManager`)

**User Story**: As a usuário que frequentemente conecta e desconecta fones Bluetooth ou DACs USB no Mac, I want que o equalizador identifique essa mudança e redirecione o fluxo de áudio automaticamente para o novo dispositivo ativo, so that o som não pare ou fique preso na saída anterior.

**Why P2**: Conectar AirPods ou fones via fio é uma ação diária e constante; o app deve se adaptar de forma invisível e resiliente.

**Acceptance Criteria**:

1. WHEN o dispositivo de saída padrão do macOS muda (ex: usuário conecta o fone Sony WH-1000XM4 via Bluetooth), THEN system SHALL capturar a notificação de listener do Core Audio (`kAudioHardwarePropertyDefaultOutputDevice`), encerrar o tap atual e recriar o grafo DSP direcionado ao novo dispositivo em < 500ms.
2. WHEN o dispositivo é alterado, THEN system SHALL notificar a UI e possivelmente carregar o perfil de equalização associado àquele dispositivo (se configurado pelo usuário).

**Independent Test**: Com uma música tocando no alto-falante do MacBook, conectar e parear o Sony WH-1000XM4; verificar se o áudio migra para o fone já equalizado sem fechar o app.

---

### P3: Equalização da Entrada de Áudio / Microfone (`InputCaptureManager`)

**User Story**: As a usuário em reuniões ou gravando voz, I want poder aplicar um filtro de equalização independente no meu microfone de entrada (ex: cortar ruídos graves sub-80 Hz ou dar clareza aos médios-agudos da voz), so that minha voz soe limpa para os outros.

**Why P3**: Expande a utilidade do equalizador para criadores de conteúdo e chamadas de vídeo, justificando seu lugar fixo no notch do sistema.

**Acceptance Criteria**:

1. WHEN o modo de equalização de entrada é ativado, THEN system SHALL capturar o buffer de entrada do microfone padrão do sistema via `AVAudioEngine.inputNode`.
2. WHEN o áudio passa pelo nó `AVAudioUnitEQ` dedicado à entrada, THEN system SHALL disponibilizar o stream processado ou ajustar as frequências antes da transmissão.

**Independent Test**: Fazer uma gravação de teste no QuickTime/Gravador de Voz enquanto ajusta as frequências baixas do microfone no equalizador para verificar a atenuação de ruídos de fundo.

---

## Edge Cases

- WHEN o usuário ainda não concedeu a permissão do sistema para gravação de áudio (`com.apple.security.device.audio-input`), THEN system SHALL não travar; em vez disso, o app deve exibir um alerta claro na janela do notch com um botão para abrir as Configurações de Privacidade do macOS (`x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone`).
- WHEN a CPU do Mac entra em carga extrema (> 95%) por conta de outros processos pesados, THEN system SHALL priorizar a continuidade do áudio sem engasgos (xruns), utilizando buffers otimizados de 512 ou 1024 frames no Core Audio.

---

## Success Criteria

- [ ] O pipeline completo de áudio (Tap → Engine → Output) consome menos de 2,0% de CPU em um chip Apple Silicon (M1/M2/M3/M4) e < 3,0% em processadores Intel compatíveis.
- [ ] Latência global adicionada pelo processamento do equalizador permanece inferior a 12 milissegundos (medida ponta a ponta).
