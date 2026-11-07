# Equalizer Interface Tasks

**Design**: `.specs/features/equalizer-ui/design.md`
**Status**: Approved

---

## Execution Plan

### Phase 1: Models & Theme Foundation (Parallel OK)

```
     ┌→ T1 [P] ─┐
     ├→ T2 [P] ─┼──→ T4
     └→ T3 [P] ─┘
```

### Phase 2: UI Components (Parallel OK)

```
     ┌→ T5 [P] ─┐
T4 ──┼→ T6 [P] ─┼──→ T9
     ├→ T7 [P] ─┤
     └→ T8 [P] ─┘
```

### Phase 3: Assembly & Integration (Sequential)

```
T9 → T10 → T11 → T12
```

---

## Task Breakdown

### T1: Criar Enum `EQFilterType` [P]

**What**: Implementar o modelo `EQFilterType.swift` representando os tipos de filtros de áudio (`LOW_SHELF`, `PEAK`, `HIGH_SHELF`, etc.) com mapeamento para `AVAudioUnitEQFilterType`.
**Where**: `Equalizer/Models/EQFilterType.swift`
**Depends on**: None
**Reuses**: NONE

**Tools**:
- MCP: `filesystem`
- Skill: NONE

**Done when**:
- [x] Enum `EQFilterType` criado com conformidade a `String, Codable, CaseIterable`.
- [x] Propriedade `audioUnitFilterType` mapeando corretamente os tipos do Core Audio.

**Verify**:
`xcodebuild -project Equalizer.xcodeproj -scheme Equalizer -configuration Debug build`

---

### T2: Criar Modelo `EQBand` [P]

**What**: Implementar o `EQBand.swift` contendo id, frequência, ganho, Q-Factor, bandwidth, estado de ativação e o gerador estático `defaultTenBands`.
**Where**: `Equalizer/Models/EQBand.swift`
**Depends on**: T1
**Reuses**: NONE

**Tools**:
- MCP: `filesystem`
- Skill: NONE

**Done when**:
- [x] Struct `EQBand: Identifiable, Equatable, Codable` implementada.
- [x] Array `EQBand.defaultTenBands` retornando as 10 frequências padrão com ganho 0 dB.

**Verify**:
`xcodebuild -project Equalizer.xcodeproj -scheme Equalizer -configuration Debug build`

---

### T3: Criar Extensão de Paleta e Tema (`Color+Theme`) [P]

**What**: Implementar `Color+Theme.swift` definindo as cores curadas da aplicação: fundos escuros do notch, gradientes de destaque (accent neon), e cores de atenuamento/bypass.
**Where**: `Equalizer/Helpers/Color+Theme.swift`
**Depends on**: None
**Reuses**: NONE

**Tools**:
- MCP: `filesystem`
- Skill: NONE

**Done when**:
- [x] Cores estáticas (`Color.eqAccent`, `Color.eqBackground`, `Color.eqGrid`) e gradientes criados e disponíveis em SwiftUI.

**Verify**:
`xcodebuild -project Equalizer.xcodeproj -scheme Equalizer -configuration Debug build`

---

### T4: Implementar o `EqualizerViewModel`

**What**: Criar o `EqualizerViewModel: ObservableObject` mantendo as `@Published var bands: [EQBand] = EQBand.defaultTenBands`, `preampGain`, `isBypassed` e métodos de reset e ajuste de ganho por UUID.
**Where**: `Equalizer/ViewModels/EqualizerViewModel.swift`
**Depends on**: T2
**Reuses**: NONE

**Tools**:
- MCP: `filesystem`
- Skill: NONE

**Done when**:
- [x] `EqualizerViewModel` criado com métodos `resetAllBands()`, `updateBandGain(id:gain:)` e `updatePreampGain(gain:)`.

**Verify**:
`xcodebuild -project Equalizer.xcodeproj -scheme Equalizer -configuration Debug build`

---

### T5: Implementar Componente Slider de Banda (`EQBandSlider`) [P]

**What**: Criar a view `EQBandSlider` em SwiftUI composta por um trilho vertical, indicador de ganho arrastável (`DragGesture`), texto de dB ao centro/topo e label da frequência (ex: `1k`) na base.
**Where**: `Equalizer/Views/EQBandSlider.swift`
**Depends on**: T3, T4
**Reuses**: NONE

**Tools**:
- MCP: `filesystem`
- Skill: NONE

**Done when**:
- [x] Slider customizado renderizando e permitindo arrastar entre -15 dB e +15 dB.
- [x] Duplo clique acionando o callback de reset da banda para 0 dB.

**Verify**:
`xcodebuild -project Equalizer.xcodeproj -scheme Equalizer -configuration Debug build`

---

### T6: Implementar Renderizador de Curva (`EQCurveView`) [P]

**What**: Criar a view `EQCurveView` usando a API `Canvas` de SwiftUI para desenhar a curva logarítmica interpolação Bézier conectando o ganho das bandas ativas no fundo do painel.
**Where**: `Equalizer/Views/EQCurveView.swift`
**Depends on**: T2, T3
**Reuses**: NONE

**Tools**:
- MCP: `filesystem`
- Skill: NONE

**Done when**:
- [x] `Canvas` desenhando linha suave entre os pontos de ganho com gradiente de preenchimento translúcido sob a curva.
- [x] Curva reagindo ao estado de bypass achatando em 0 dB.

**Verify**:
`xcodebuild -project Equalizer.xcodeproj -scheme Equalizer -configuration Debug build`

---

### T7: Implementar Barra Superior de Controle (`EQHeaderView`) [P]

**What**: Criar a view `EQHeaderView` contendo o título/ícone do app, botão de toggle Bypass com feedback visual, e seletor rápido de perfil/preset.
**Where**: `Equalizer/Views/EQHeaderView.swift`
**Depends on**: T3, T4
**Reuses**: NONE

**Tools**:
- MCP: `filesystem`
- Skill: NONE

**Done when**:
- [x] Header renderizando controles alinhados no topo da área expandida.

**Verify**:
`xcodebuild -project Equalizer.xcodeproj -scheme Equalizer -configuration Debug build`

---

### T8: Implementar Barra Inferior de Controle (`EQFooterView`) [P]

**What**: Criar a view `EQFooterView` com o slider horizontal de `Preamp` (-15 dB a +15 dB), indicador de volume de saída e seletor dropdown de dispositivo de áudio (I/O).
**Where**: `Equalizer/Views/EQFooterView.swift`
**Depends on**: T3, T4
**Reuses**: NONE

**Tools**:
- MCP: `filesystem`
- Skill: NONE

**Done when**:
- [x] Rodapé renderizando o slider de Preamp interativo e o botão de I/O.

**Verify**:
`xcodebuild -project Equalizer.xcodeproj -scheme Equalizer -configuration Debug build`

---

### T9: Implementar Container das 10 Bandas (`EQBandsContainerView`)

**What**: Criar a view `EQBandsContainerView` que itera sobre `viewModel.bands` via `HStack` horizontal e instancia um `EQBandSlider` para cada banda com espaçamento uniforme.
**Where**: `Equalizer/Views/EQBandsContainerView.swift`
**Depends on**: T5
**Reuses**: NONE

**Tools**:
- MCP: `filesystem`
- Skill: NONE

**Done when**:
- [x] `HStack` exibindo exatamente as 10 bandas de frequência lado a lado em layout flexível.

**Verify**:
`xcodebuild -project Equalizer.xcodeproj -scheme Equalizer -configuration Debug build`

---

### T10: Integrar Interface Completa na `NotchExpandedView`

**What**: Atualizar o arquivo `NotchExpandedView.swift` (criado na Fase 1) para hospedar `EQCurveView` no fundo (`.background`), `EQHeaderView` no topo, `EQBandsContainerView` no centro e `EQFooterView` na base.
**Where**: `Equalizer/Views/NotchExpandedView.swift`
**Depends on**: T6, T7, T8, T9
**Reuses**: `NotchExpandedView.swift` (modificar)

**Tools**:
- MCP: `filesystem`
- Skill: NONE

**Done when**:
- [x] Janela expandida exibindo o equalizador gráfico completo em funcionamento reativo.
- [x] Nenhum erro de layout de sobreposição ou corte visual.

**Verify**:
`xcodebuild -project Equalizer.xcodeproj -scheme Equalizer -configuration Debug build`

---

### T11: Conectar `EqualizerViewModel` ao `NotchViewModel`

**What**: Permitir que `NotchViewModel` comunique ou compartilhe referência com `EqualizerViewModel` para que o indicador na view colapsada mostre se o EQ está ativo ou em bypass.
**Where**: `Equalizer/ViewModels/NotchViewModel.swift`
**Depends on**: T10
**Reuses**: NONE

**Tools**:
- MCP: `filesystem`
- Skill: NONE

**Done when**:
- [x] View colapsada (`NotchCollapsedView`) muda ligeiramente a cor/ícone no notch dependendo de `viewModel.isBypassed`.

**Verify**:
`xcodebuild -project Equalizer.xcodeproj -scheme Equalizer -configuration Debug build`

---

### T12: Validação Visual do Equalizador no Notch

**What**: Compilar, executar o app e realizar o teste completo de interatividade de todos os sliders, preamp e botões de bypass com a janela integrada ao notch.
**Where**: `Equalizer.app`
**Depends on**: T11
**Reuses**: NONE

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [x] Build concluído com sucesso e app funcionando com interface de 10 bandas no notch sem falhas.

**Verify**:
`xcodebuild -project Equalizer.xcodeproj -scheme Equalizer -configuration Debug build`
