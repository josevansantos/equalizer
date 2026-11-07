# Roadmap

**Current Milestone:** Milestone 3 — Perfis Paramétricos, Polimento & Release
**Status:** In Progress

---

## Milestone 1 — Fundação & Interface no Notch

**Goal:** Projeto Xcode configurado na versão e target corretos, com janela flutuante (`NSPanel`) perfeitamente ancorada no notch, suportando animações fluidas entre estado colapsado e expandido, exibindo a interface visual base do equalizador gráfico de 10 bandas.
**Target:** Fases 0, 1 e 2 do `PLAN.md` (Estimativa: ~10 dias)
**Status:** COMPLETE

### Features

**Notch Window Base** - COMPLETE

- Configuração do projeto Xcode em Swift 5.9+, target macOS 15.0+, e Info.plist (`LSUIElement = true`).
- Sistema de detecção de tela e geometria do notch (`NSScreen+Notch`, `ScreenHelper`).
- Criação e gerenciamento do `NSPanel` non-activating sem roubar foco da aplicação ativa (`NotchHelper`).
- Animação de transição suave entre estado colapsado (mini-visualizador) e expandido (`NotchViewModel`, `NotchContainerView`).

**Equalizer UI Base** - COMPLETE

- Modelo de dados e visual para o equalizador gráfico de 10 bandas (`EQBand`, sliders verticais, labels de frequência).
- Visualizador de curva em tempo real renderizado com SwiftUI Canvas (`EQCurveView`).
- Barra de controle superior e inferior: Volume, Bypass, Seletor de Presets, Seletor de Perfis de Fones e Seletor de Dispositivos (I/O).
- Design System moderno: modo escuro curado, glassmorphism sutil (`VisualEffectView`) e micro-animações de feedback.

---

## Milestone 2 — Motor de Áudio & Interceptação Core Audio

**Goal:** Implementação completa do pipeline de processamento DSP no `AVAudioEngine`, utilizando Core Audio Taps nativos para interceptar áudio de saída do sistema sem drivers, além de suporte à equalização de entrada (microfones).
**Target:** Fases 3 e 4 do `PLAN.md` (Estimativa: ~10 dias)
**Status:** COMPLETE — Core Audio Tap e aggregate device funcionando; monitoramento de nível reabilitado de forma thread-safe

### Features

**Output Audio Engine (`AVAudioEngine` + `Core Audio Tap`)** - COMPLETE

- ✅ Gerenciador de dispositivos de saída e escuta de mudanças de hardware (`AudioDeviceManager`).
- ✅ Interceptação e captura de stream de áudio do sistema via `AudioHardwareCreateProcessTap` (`CoreAudioTapManager`).
- ✅ Criação de aggregate device combinando tap e dispositivo de saída real.
- ✅ Nó de processamento gráfico de 10 bandas com `AVAudioUnitEQ` e controle de ganho global (`EQProcessor`).
- ✅ Medidor de nível de saída em tempo real com análise FFT (`AudioLevelMeter`), isolado em `AudioLevelTap` para evitar crash de executor na realtime thread.

**Input Audio Engine & Microfones** - COMPLETE

- ✅ Módulo de captura de áudio para dispositivos de entrada/microfone (`InputCaptureManager`) integrado ao motor `AudioEngineManager`.
- ✅ Controles interativos no rodapé (`EQFooterView`) com seletor de dispositivos de entrada, controle de ganho e toggle de captura de microfone em tempo real.

---

## Milestone 3 — Perfis Paramétricos, Polimento & Release

**Goal:** Sistema completo de perfis de fones com N bandas paramétricas (`LOW_SHELF`, `PEAK`, `HIGH_SHELF`), importação nativa de arquivos AutoEQ/oratory1990, perfis pré-embarcados (Sony WH-1000XM4, KZ ZSN Pro X, Huawei FreeBuds Pro 5), visualização espectral avançada e suíte de testes unitários.
**Target:** Fases 5, 6, 7 e 8 do `PLAN.md` (Estimativa: ~15 a 20 dias)
**Status:** COMPLETE

### Features

**Headphone Profiles & Presets System** - COMPLETE

- ✅ Modelagem de dados paramétrica flexível (`HeadphoneProfile`, `EQPreset`, `ProfileBand` com Frequência, Ganho, Q-Factor e BW).
- ✅ Validação via JSON Schema (`_schema.json`) e persistência local (`ProfileStore`, `PresetStore`).
- ✅ Processador paramétrico dinâmico no `AVAudioUnitEQ` (`ParametricEQProcessor`).
- ✅ Perfis Built-in otimizados e prontos para uso imediato: Sony WH-1000XM4 (oratory1990), KZ ZSN Pro X (AutoEQ) e Huawei FreeBuds Pro 5 (Balanced Custom).
- ✅ Importador e conversor de arquivos texto AutoEQ (`ParametricEQ.txt`) e JSON (`ProfileImporter`).
- ✅ Interface de gerenciamento e edição de perfis: `ProfileListView`, `ProfileDetailView`, e editor inline de bandas paramétricas (`ProfileEditorView`).
- ✅ Importação interativa via seletor de arquivos (`.fileImporter`) e drag-and-drop (`.onDrop`) nativos na UI do `ProfileListView`.

**Audio Visualization & Polish** - COMPLETE

- ✅ Analisador de espectro FFT renderizado em tempo real com barras luminosas no modo colapsado (`NotchCollapsedView`) e no fundo do gráfico expandido (`EQCurveView`).
- ✅ Painel de configurações (`SettingsView`): inicialização automática com o sistema via `SMAppService` (Launch at Login), atalhos globais de teclado, seleção de tema (`Color+Theme`) e sobre o app.
- ✅ Testes unitários de serialização de perfis e matemática de filtros.
- ✅ Otimização de performance CPU/Memória e verificação de todo o pipeline de processamento DSP e UI reativa.

---

## Future Considerations

- **Sincronização via iCloud:** Sincronizar perfis customizados e presets de equalização entre múltiplos Macs.
- **Auto-Equalização por Perfil de Ouvido:** Teste auditivo integrado para gerar uma curva de compensação auditiva personalizada para o usuário.
- **Suporte a Plugins Audio Unit (AUv3):** Capacidade de carregar efeitos e compressores externos de terceiros dentro do pipeline do equalizador.
