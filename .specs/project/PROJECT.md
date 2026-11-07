# Equalizer

**Vision:** Um aplicativo de equalização de áudio paramétrica nativo, ultra-leve e elegante para macOS, perfeitamente integrado na área do notch do sistema, permitindo equalizar frequências de entrada e saída com precisão de estúdio e consumo de recursos quase nulo.
**For:** Audiófilos, produtores musicais, gamers e usuários de macOS que desejam melhorar a qualidade sonora de seus fones de ouvido e microfones sem interfaces complexas ou drivers intrusivos.
**Solves:** A ausência de um equalizador gráfico/paramétrico nativo de fácil acesso no macOS, eliminando a necessidade de instalar drivers de áudio virtuais de terceiros (como BlackHole ou Soundflower) e apps pesados.

## Goals

- **Precisão Paramétrica & Baixo Consumo:** Processar áudio do sistema (entrada e saída) em tempo real com uso de CPU < 2% e latência imperceptível (< 10ms) usando Core Audio Taps nativos.
- **Experiência Visual Premium no Notch:** Oferecer uma interface fluida, expansível e com micro-animações a partir do notch da tela do Mac, sem roubar o foco das janelas ativas (`NSPanel` non-activating).
- **Compatibilidade Plena com Perfis de Fones:** Suportar importação, exportação e edição de perfis paramétricos completos em JSON, incluindo integração nativa com dados do AutoEQ e oratory1990 para fones populares como Sony WH-1000XM4, KZ ZSN Pro X e Huawei FreeBuds Pro 5.

## Tech Stack

**Core:**

- Framework: SwiftUI & AppKit (macOS 15.0+ / Sequoia 15.7.7)
- Language: Swift 5.9+ (com concorrência moderna async/await)
- Database: Arquivos JSON no sistema de arquivos local (`~/Library/Application Support/Equalizer/`)

**Key dependencies:** Zero dependências externas. Utilização 100% de frameworks nativos da Apple:
- `AVFAudio` (`AVAudioEngine`, `AVAudioUnitEQ`) para processamento e roteamento de sinal DSP.
- `CoreAudio` (`AudioHardwareCreateProcessTap`) para interceptação de áudio de saída sem drivers de kernel.
- `Accelerate` (vDSP) para análise FFT e medidores de nível (VU meters/espectro).
- `AppKit` & `SwiftUI` para gerenciamento de janelas no notch (`NSScreen`, `NSPanel`).

## Scope

**v1 includes:**

- **Janela e Posicionamento no Notch:** Painel não-ativável fixado no notch, com estados colapsado (indicador visual sutil) e expandido (interface completa do equalizador).
- **Equalizador Gráfico de 10 Bandas:** Sliders visuais para frequências fixas (32 Hz a 16 kHz) no modo simples, com controle de ganho global (Preamp) e visualização de curva de resposta em tempo real.
- **Processador Paramétrico Dinâmico (`EQBand` & `HeadphoneProfile`):** Suporte a filtros `LOW_SHELF`, `PEAK` e `HIGH_SHELF` com controle de Frequência, Ganho, Q-Factor e Bandwidth para N bandas paramétricas simultâneas.
- **Perfis Built-in & Importação AutoEQ:** Perfis embutidos otimizados para Sony WH-1000XM4 (-5.6 dB Preamp, 10 bandas oratory1990), KZ ZSN Pro X (-4.2 dB Preamp, 8 bandas AutoEQ) e Huawei FreeBuds Pro 5 (-3.5 dB Preamp, 8 bandas Custom), além de importador para arquivos `ParametricEQ.txt` e `.json`.
- **Captura e Processamento de Áudio (In/Out):** Gerenciamento de dispositivos de áudio, interceptação de saída via `Core Audio Tap` e controle de entrada para microfones.

**Explicitly out of scope:**

- Instalação de drivers virtuais em nível de kernel (kext ou System Extensions de áudio de terceiros).
- Efeitos espaciais complexos (Surround 7.1 virtual, Dolby Atmos rendering ou reverberação convolucional).
- Suporte a versões legadas do macOS (< 14.2), visto que o app depende de APIs modernas de `Core Audio Tap`.

## Constraints

- Timeline: 9 fases de desenvolvimento planejadas no `PLAN.md` (~30 a 40 dias de esforço modular e incremental).
- Technical: O app deve solicitar e obter a autorização e entitlement `com.apple.security.device.audio-input` (Microfone/Áudio do Sistema) no macOS Sequoia (15.7.7 Build 24G720).
- Resources: Projeto solo em Pair Programming com o usuário, seguindo rigorosamente a metodologia TLC Spec-Driven Development.
