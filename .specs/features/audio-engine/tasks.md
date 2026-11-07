# Audio Engine - Input & Output Tasks

**Design**: `.specs/features/audio-engine/design.md`
**Status**: Approved

---

## Execution Plan

### Phase 1: Device Discovery & Core Helpers (Parallel OK)

```
     ┌→ T1 [P] ─┐
     ├→ T2 [P] ─┼──→ T4
     └→ T3 [P] ─┘
```

### Phase 2: DSP Nodes & Taps (Parallel OK)

```
     ┌→ T5 [P] ─┐
T4 ──┼→ T6 [P] ─┼──→ T8
     └→ T7 [P] ─┘
```

### Phase 3: Orchestration & UI Wiring (Sequential)

```
T8 → T9 → T10 → T11
```

---

## Task Breakdown

### T1: Criar Modelo e Estrutura `AudioDevice` [P]

**What**: Implementar `AudioDevice.swift` contendo id (`AudioObjectID`), uid, nome, flags booleanas para in/out e taxa de amostragem (`sampleRate`).
**Where**: `Equalizer/Models/AudioDevice.swift`
**Depends on**: None
**Reuses**: NONE

**Tools**:
- MCP: `filesystem`
- Skill: NONE

**Done when**:
- [x] Struct `AudioDevice` criada e em conformidade com `Identifiable, Equatable`.

**Verify**:
`xcodebuild -project Equalizer.xcodeproj -scheme Equalizer -configuration Debug build`

---

### T2: Implementar Gerenciador de Dispositivos (`AudioDeviceManager`) [P]

**What**: Criar a classe `AudioDeviceManager` utilizando chamadas C do `CoreAudio` (`AudioObjectGetPropertyData`) para listar todos os dispositivos físicos e identificar o default output/input.
**Where**: `Equalizer/Audio/AudioDeviceManager.swift`
**Depends on**: T1
**Reuses**: NONE

**Tools**:
- MCP: `filesystem`
- Skill: NONE

**Done when**:
- [x] Métodos para ler `outputDevices` e `inputDevices` implementados.
- [x] Listener (`startListeningForDeviceChanges`) registrado em `kAudioHardwarePropertyDefaultOutputDevice`.

**Verify**:
`xcodebuild -project Equalizer.xcodeproj -scheme Equalizer -configuration Debug build`

---

### T3: Implementar Medidor de Nível e FFT (`AudioLevelMeter`) [P]

**What**: Criar a classe `AudioLevelMeter` utilizando o framework `Accelerate` (`vDSP_fft_zrip`) para processar buffers de áudio em tempo real e fornecer dados de magnitude/espectro para a UI.
**Where**: `Equalizer/Audio/AudioLevelMeter.swift`
**Depends on**: None
**Reuses**: NONE

**Tools**:
- MCP: `filesystem`
- Skill: NONE

**Done when**:
- [x] Função `processBuffer(_ buffer: AVAudioPCMBuffer)` calculando RMS e saídas de frequência de espectro de forma não-bloqueante.

**Verify**:
`xcodebuild -project Equalizer.xcodeproj -scheme Equalizer -configuration Debug build`

---

### T4: Implementar `CoreAudioTapManager`

**What**: Criar o encapsulador `CoreAudioTapManager` que invoca `AudioHardwareCreateProcessTap` sobre o `AudioObjectID` primário para extrair o fluxo de saída de áudio de nível de sistema.
**Where**: `Equalizer/Audio/CoreAudioTapManager.swift`
**Depends on**: T2
**Reuses**: NONE

**Tools**:
- MCP: `filesystem`
- Skill: NONE

**Done when**:
- [x] Métodos `createProcessTap(on:)` e `destroyProcessTap()` implementados com `AudioHardwareCreateProcessTap` e `AudioHardwareDestroyProcessTap`.
- [x] Criação de aggregate device combinando tap + dispositivo de saída real via `AudioHardwareCreateAggregateDevice`.
- [x] Restauração do dispositivo de saída original ao destruir o tap.

**Verify**:
`swift build`

---

### T5: Implementar Processador de 10 Bandas (`EQProcessor`) [P]

**What**: Criar `EQProcessor` encapsulating um `AVAudioUnitEQ(numberOfBands: 10)` configurado com os tipos corretos (LowShelf na banda 0, HighShelf na 9, e Peak nas intermediárias).
**Where**: `Equalizer/Audio/EQProcessor.swift`
**Depends on**: None
**Reuses**: NONE

**Tools**:
- MCP: `filesystem`
- Skill: NONE

**Done when**:
- [x] Método `updateBandGain(index:gain:)` modificando dinamicamente `eqNode.bands[index].gain`.
- [x] Método `updateGlobalGain(_ gain:)` controlando `eqNode.globalGain`.

**Verify**:
`xcodebuild -project Equalizer.xcodeproj -scheme Equalizer -configuration Debug build`

---

### T6: Implementar Processador Paramétrico N-Bandas (`ParametricEQProcessor`) [P]

**What**: Criar `ParametricEQProcessor` que aplica equalização paramétrica com base nas bandas ativas de um objeto `HeadphoneProfile`.
**Where**: `Equalizer/Audio/ParametricEQProcessor.swift`
**Depends on**: T5
**Reuses**: `EQProcessor.swift` (padrões de configuração de nó)

**Tools**:
- MCP: `filesystem`
- Skill: NONE

**Done when**:
- [x] Método `loadProfile(_ profile: HeadphoneProfile)` configurando Frequência, Ganho, Q-Factor, BW e `globalGain` (preamp).
- [x] Node fixo de 20 bandas (limite do schema) com ativação/desativação dinâmica para evitar reconexão do grafo.

**Verify**:
`swift build`

---

### T7: Implementar Capturador de Entrada (`InputCaptureManager`) [P]

**What**: Criar `InputCaptureManager` conectando o `inputNode` do `AVAudioEngine` a uma sub-cadeia de `AVAudioUnitEQ` para processar microfones em reuniões ou gravações.
**Where**: `Equalizer/Audio/InputCaptureManager.swift`
**Depends on**: T2
**Reuses**: NONE

**Tools**:
- MCP: `filesystem`
- Skill: NONE

**Done when**:
- [x] Lógica de inicialização de captura de microfone com checagem de autorização de privacidade e tratamento de erro de dispositivo ocupado.

**Verify**:
`xcodebuild -project Equalizer.xcodeproj -scheme Equalizer -configuration Debug build`

---

### T8: Implementar o Orquestrador Master (`AudioEngineManager`)

**What**: Criar o singleton ou classe orquestradora `AudioEngineManager` que monta o grafo do `AVAudioEngine`: conecta a saída do Tap ao `EQProcessor` / `ParametricEQProcessor` e os roteia para o `AVAudioOutputNode`.
**Where**: `Equalizer/Audio/AudioEngineManager.swift`
**Depends on**: T4, T5, T6, T7
**Reuses**: NONE

**Tools**:
- MCP: `filesystem`
- Skill: NONE

**Done when**:
- [x] Métodos `startEngine()`, `stopEngine()`, `setBypass()` implementados.
- [x] Grafo `inputNode → EQProcessor → ParametricEQProcessor → mainMixerNode → outputNode` montado usando o aggregate device do tap como input/output padrão.

**Verify**:
`swift build`

---

### T9: Conectar `EqualizerViewModel` ao `AudioEngineManager`

**What**: Vincular os callbacks de mudança (`$bands`, `$preampGain`, `$isBypassed`, `$selectedProfile`) do `EqualizerViewModel` aos métodos correspondentes de atualização do `AudioEngineManager`.
**Where**: `Equalizer/ViewModels/EqualizerViewModel.swift`
**Depends on**: T8
**Reuses**: `EqualizerViewModel.swift` (modificar)

**Tools**:
- MCP: `filesystem`
- Skill: NONE

**Done when**:
- [x] Mudanças em `bands`, `preampGain`, `isBypassed` e `selectedProfile` atualizam os nós `AVAudioUnitEQ` em tempo real.
- [x] `EqualizerViewModel` integra `ProfileStore` e `PresetStore` e aplica perfis/presets ao motor.

**Verify**:
`swift build`

---

### T10: Implementar Reconexão Automática de Áudio em Mudança de Dispositivo

**What**: Conectar o callback do `AudioDeviceManager.startListeningForDeviceChanges` no `AudioEngineManager` para parar o motor, trocar o dispositivo alvo no Tap e reiniciar em caso de reconexão de fones.
**Where**: `Equalizer/Audio/AudioEngineManager.swift`
**Depends on**: T9
**Reuses**: NONE

**Tools**:
- MCP: `filesystem`
- Skill: NONE

**Done when**:
- [x] `AudioEngineManager` observa `deviceManager.$defaultOutputDevice` e reinicia o engine ao detectar mudança.
- [ ] Teste manual confirmando migração suave entre alto-falantes internos e fones Bluetooth.

**Status:** Código implementado; validação manual pendente.

**Verify**:
`swift build`

---

### T11: Validação Geral de DSP e Interceptação de Áudio

**What**: Executar o teste de validação integrado ponta a ponta reproduzindo áudio do sistema com o equalizador rodando no notch, verificando latência (< 12ms) e carga de CPU (< 2%).
**Where**: `Equalizer.app`
**Depends on**: T10
**Reuses**: NONE

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [ ] Teste manual confirmando áudio do sistema processado e equalizado em tempo real.
- [ ] Medição de latência < 12ms e CPU < 2% em Apple Silicon.

**Status:** Implementação concluída; testes manuais de áudio pendentes.

**Verify**:
`swift build`
