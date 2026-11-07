# 🎛️ Equalizer

Equalizer é um aplicativo nativo, ultra-leve e elegante para macOS que reside na área do **notch** da tela, oferecendo equalização paramétrica em tempo real para o áudio de saída do sistema. Projetado para audiófilos, produtores, gamers e qualquer usuário de Mac que queira melhorar a qualidade sonora sem drivers intrusivos.

> **Versão alvo:** macOS 15.0+ (Sequoia 15.7.7 Build 24G720)  
> **Linguagem:** Swift 6.0+  
> **Frameworks:** SwiftUI, AppKit, Core Audio, AVFAudio, AudioToolbox, Accelerate  
> **Dependências externas:** zero

---

## ✨ Funcionalidades

- **Interface no notch** — painel flutuante `NSPanel` non-activating, expansível e com micro-animações.
- **Equalizador gráfico de 10 bandas** — sliders verticais para frequências fixas (32 Hz a 16 kHz).
- **Perfis paramétricos de fones** — suporte a filtros `LOW_SHELF`, `PEAK`, `HIGH_SHELF`, com controle de frequência, ganho, Q-Factor e bandwidth.
- **Perfis built-in** — Sony WH-1000XM4, KZ ZSN Pro X e Huawei FreeBuds Pro 5.
- **Importação AutoEQ** — parser nativo para arquivos `ParametricEQ.txt` do projeto AutoEQ.
- **Presets simples** — Flat, Bass Boost, Vocal, Rock, Electronic, Acoustic.
- **Interceptação nativa de áudio** — via `AudioHardwareCreateProcessTap` (macOS 14.2+), sem drivers virtuais.
- **Medidor de nível e FFT** — visualização em tempo real com `Accelerate`/`vDSP`.
- **Zero dependências externas** — build limpo com frameworks nativos da Apple.

---

## 🛠️ Requisitos

- macOS 15.0 ou superior
- Xcode 16+ **ou** Command Line Tools for Xcode
- Swift 6.0+

### Para desenvolvimento com testes

O projeto usa **Swift Testing**. Em ambientes com apenas Command Line Tools, os testes compilam mas o runner pode não executar localmente sem o Xcode completo. Veja a seção [Como testar](#como-testar).

---

## 🚀 Como buildar

O projeto usa **Swift Package Manager** (não um `.xcodeproj`). Para gerar e abrir o app:

```bash
scripts/build-app.sh
```

```bash
open .build/Equalizer.app
```

Na primeira execução, o macOS pede permissão para capturar o áudio do sistema. Sem ela, o app não recebe áudio.

> **Use o `.app`, não `swift run`:** um binário solto não tem `Info.plist` nem assinatura, então a permissão não é atribuída ao Equalizer.
>
> A assinatura é ad hoc, e por isso o macOS pode pedir a permissão de novo depois de uma recompilação.

### Diagnóstico

Para registrar os níveis antes e depois do EQ a cada segundo:

```bash
open --env EQUALIZER_DIAG=1 --stdout /tmp/equalizer.log --stderr /tmp/equalizer.log .build/Equalizer.app
```

- `nenhum ciclo de IO`: o áudio não está sendo lido. Costuma ser a permissão ainda pendente.
- `silêncio` com algo tocando: confira a permissão em Ajustes do Sistema > Privacidade e Segurança > Gravação de Tela e Áudio do Sistema.

---

## 🧪 Como testar

Os testes precisam do Xcode completo:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
```

> **Cuidado:** com o `xcode-select` apontando para as Command Line Tools, `swift test` termina em `Build complete!` **sem executar nenhum teste**. Confira se a saída traz `Test run with N tests`.

### Testes existentes

- `AudioPathTests.swift` — passa senoides pela cadeia real de renderização e mede o ganho (bandas, bypass, perfis). Também cria um tap e um aggregate reais, sem iniciar IO, portanto sem silenciar nada.
- `EqualizerTests.swift` — modelos (`EQBand`, `EQFilterType`) e aplicação de presets.
- `ProfileTests.swift` — decodificação dos JSONs built-in, cálculos Q/BW, importação JSON e parsing AutoEQ.
- `ViewModelTests.swift` — integração do ViewModel com um motor simulado.

Os testes não devem iniciar o `AudioEngineManager` real: ele silenciaria o áudio da máquina durante a execução. Use `MockAudioEngineManager`.

---

## 🔐 Permissões Necessárias

Só uma: **captura de áudio do sistema**, pedida pelo macOS na primeira execução graças à chave `NSAudioCaptureUsageDescription` do `Info.plist`. Ela fica em Ajustes do Sistema > Privacidade e Segurança > Gravação de Tela e Áudio do Sistema.

O app não usa o microfone e roda sem sandbox.

---

## 📁 Estrutura do Projeto

```
Equalizer/
├── Package.swift
├── PLAN.md
├── README.md
├── .specs/
│   └── project/
│       ├── PROJECT.md
│       ├── ROADMAP.md
│       └── STATE.md
│   └── features/
│       ├── audio-engine/
│       ├── equalizer-ui/
│       ├── headphone-profiles/
│       └── notch-window/
├── scripts/
│   └── build-app.sh
├── Sources/
│   └── Equalizer/
│       ├── EqualizerApp.swift
│       ├── AppDelegate.swift
│       ├── Info.plist
│       ├── Equalizer.entitlements
│       ├── Audio/
│       │   ├── AudioDeviceManager.swift
│       │   ├── AudioEngineManager.swift
│       │   ├── AudioLevelMeter.swift
│       │   ├── AudioLevelTap.swift
│       │   ├── CoreAudioTapManager.swift
│       │   ├── EQProcessor.swift
│       │   ├── ParametricEQProcessor.swift
│       │   ├── PropertyListener.swift
│       │   ├── SystemAudioRenderer.swift
│       │   └── VolumeListenerHelper.swift
│       ├── Helpers/
│       │   ├── Color+Theme.swift
│       │   ├── NotchHelper.swift
│       │   └── ScreenHelper.swift
│       ├── Models/
│       │   ├── AudioDevice.swift
│       │   ├── EQBand.swift
│       │   ├── EQFilterType.swift
│       │   ├── EQPreset.swift
│       │   ├── HeadphoneProfile.swift
│       │   └── NotchState.swift
│       ├── Services/
│       │   ├── PresetStore.swift
│       │   ├── ProfileImporter.swift
│       │   └── ProfileStore.swift
│       ├── ViewModels/
│       │   ├── EqualizerViewModel.swift
│       │   └── NotchViewModel.swift
│       ├── Views/
│       │   ├── EQBandSlider.swift
│       │   ├── EQBandsContainerView.swift
│       │   ├── EQCurveView.swift
│       │   ├── EQFooterView.swift
│       │   ├── EQHeaderView.swift
│       │   ├── NotchCollapsedView.swift
│       │   ├── NotchContainerView.swift
│       │   ├── NotchExpandedView.swift
│       │   ├── SettingsView.swift
│       │   └── Profiles/
│       │       ├── ProfileListView.swift
│       │       ├── ProfileDetailView.swift
│       │       └── ProfileEditorView.swift
│       └── Resources/
│           └── HeadphoneProfiles/
│               ├── _schema.json
│               ├── sony_wh1000xm4.json
│               ├── kz_zsn_pro_x.json
│               └── huawei_freebuds_pro5.json
└── Tests/
    └── EqualizerTests/
        ├── AudioPathTests.swift
        ├── EqualizerTests.swift
        ├── ProfileTests.swift
        └── ViewModelTests.swift
```

---

## 🏗️ Arquitetura

```
┌─────────────────────────────────────────────────────────────┐
│                        UI (SwiftUI)                         │
│  NotchContainerView → NotchExpandedView → EQHeaderView      │
│                     → EQBandsContainerView → EQBandSlider   │
│                     → EQCurveView → EQFooterView            │
└──────────────────────────┬──────────────────────────────────┘
                           │
┌──────────────────────────▼──────────────────────────────────┐
│                  ViewModels (Combine)                       │
│         NotchViewModel ← EqualizerViewModel                 │
│         (ProfileStore / PresetStore / AudioEngineManager)   │
└──────────────────────────┬──────────────────────────────────┘
                           │
┌──────────────────────────▼──────────────────────────────────┐
│                     AudioEngineManager                      │
│  CoreAudioTapManager: tap global + aggregate device privado │
│  SystemAudioRenderer: IOProc → EQProcessor →                │
│                       ParametricEQProcessor → hardware      │
└─────────────────────────────────────────────────────────────┘
```

O tap captura o áudio de todos os apps, menos o do próprio Equalizer, e os silencia no hardware enquanto é lido. Um IOProc no aggregate device lê esse áudio, passa pelo `AVAudioEngine` em *manual rendering* (que não abre nenhum dispositivo) e escreve o resultado no hardware.

O dispositivo de saída padrão do sistema nunca é alterado. Se o app parar ou cair, o som dos outros apps volta sozinho.

---

## ⚠️ Limitações Conhecidas

- **macOS 14.2+ obrigatório** para o `AudioHardwareCreateProcessTap`.
- **Testes** exigem o Xcode completo; só com as Command Line Tools eles compilam e não rodam.
- **Saída estéreo**: em dispositivos com mais canais, só os dois primeiros recebem áudio.
- **Sem limitador**: ganhos positivos altos podem clipar. Use o Preamp para compensar.
- **EQ de entrada (microfone)** não existe.
- **Importação via UI** (file picker / drag-and-drop) está parcial; a engine de importação (`ProfileImporter`) já funciona.

---

## 📄 Licença

Este projeto é de uso pessoal/experimental. Licença a definir.

---

## 🤝 Contribuição

Este projeto segue a metodologia **TLC Spec-Driven Development**. As especificações estão em `.specs/` e o estado atual em `.specs/project/STATE.md`.
