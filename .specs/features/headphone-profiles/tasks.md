# Headphone Profiles & Presets Tasks

**Design**: `.specs/features/headphone-profiles/design.md`
**Status**: Approved

---

## Execution Plan

### Phase 1: Models, Schema & Built-in JSONs (Parallel OK)

```
     ┌→ T1 [P] ─┐
     ├→ T2 [P] ─┼──→ T5
     ├→ T3 [P] ─┤
     └→ T4 [P] ─┘
```

### Phase 2: Importers & Store Engine (Parallel OK)

```
     ┌→ T5 [P] ─┐
T4 ──┼→ T6 [P] ─┼──→ T8
     └→ T7 [P] ─┘
```

### Phase 3: Profile UI & Engine Integration (Sequential)

```
T8 → T9 → T10 → T11 → T12 → T13
```

---

## Task Breakdown

### T1: Implementar Modelo e Conversão de Bandas (`HeadphoneProfile`) [P]

**What**: Criar `HeadphoneProfile.swift` contendo a struct principal e sub-struct `ProfileBand` com métodos estáticos de conversão `qToBandwidth(q:)` e `bandwidthToQ(bw:)`.
**Where**: `Equalizer/Models/HeadphoneProfile.swift`
**Depends on**: None
**Reuses**: `EQFilterType.swift`

**Tools**:
- MCP: `filesystem`
- Skill: NONE

**Done when**:
- [x] Struct `HeadphoneProfile` e `ProfileBand` em conformidade com `Identifiable, Codable, Equatable`.
- [x] Campos `preampGain`, `description`, `source`, `isBuiltIn`, `createdAt`, `updatedAt` e `isEnabled` por banda implementados.
- [x] Fórmulas matemáticas de Q ↔ BW gerando os resultados esperados nos testes de decodificação.

**Verify**:
`swift build && swift test`

---

### T2: Criar Arquivo de JSON Schema (`_schema.json`) [P]

**What**: Criar o arquivo de especificação de esquema JSON (`_schema.json`) com validações rigorosas de faixas (Hz entre 20-20000, dB entre -30 e +30, Q entre 0.1 e 20.0).
**Where**: `Equalizer/Resources/HeadphoneProfiles/_schema.json`
**Depends on**: None
**Reuses**: NONE

**Tools**:
- MCP: `filesystem`
- Skill: NONE

**Done when**:
- [x] Arquivo JSON Schema criado e válido no repositório de recursos.

**Verify**:
`python3 -m json.tool Sources/Equalizer/Resources/HeadphoneProfiles/_schema.json > /dev/null`

---

### T3: Criar Perfil Built-in do Sony WH-1000XM4 (`sony_wh1000xm4.json`) [P]

**What**: Criar o arquivo de perfil JSON contendo as 10 bandas paramétricas exatas da medição oratory1990 para o Sony WH-1000XM4 com ANC ON e Preamp de -5.6 dB.
**Where**: `Equalizer/Resources/HeadphoneProfiles/sony_wh1000xm4.json`
**Depends on**: T2
**Reuses**: NONE

**Tools**:
- MCP: `filesystem`
- Skill: NONE

**Done when**:
- [x] Arquivo `sony_wh1000xm4.json` criado com 2 filtros LOW_SHELF e 8 filtros PEAK.
- [x] UUID válido, `preampGain: -5.6`, `source: oratory1990`, `isBuiltIn: true`.
- [x] JSON formatado sem erros de sintaxe.

**Verify**:
`python3 -m json.tool Sources/Equalizer/Resources/HeadphoneProfiles/sony_wh1000xm4.json > /dev/null`

---

### T4: Criar Perfis Built-in do KZ ZSN Pro X e Huawei FreeBuds Pro 5 [P]

**What**: Criar `kz_zsn_pro_x.json` (8 bandas AutoEQ, Preamp -4.2 dB) e `huawei_freebuds_pro5.json` (8 bandas Custom Balanced, Preamp -3.5 dB).
**Where**: `Equalizer/Resources/HeadphoneProfiles/kz_zsn_pro_x.json` e `huawei_freebuds_pro5.json`
**Depends on**: T2
**Reuses**: NONE

**Tools**:
- MCP: `filesystem`
- Skill: NONE

**Done when**:
- [x] Arquivos JSON para os dois fones criados na pasta de recursos com UUIDs válidos, `preampGain`, `source` e `isBuiltIn: true`.

**Verify**:
`python3 -m json.tool Sources/Equalizer/Resources/HeadphoneProfiles/kz_zsn_pro_x.json > /dev/null && python3 -m json.tool Sources/Equalizer/Resources/HeadphoneProfiles/huawei_freebuds_pro5.json > /dev/null`

---

### T5: Implementar o Conversor e Importador (`ProfileImporter`) [P]

**What**: Criar a classe `ProfileImporter` capaz de ler arquivos JSON via `JSONDecoder` e realizar parsing de expressões regulares para o formato texto do AutoEQ (`ParametricEQ.txt`).
**Where**: `Equalizer/Services/ProfileImporter.swift`
**Depends on**: T1
**Reuses**: NONE

**Tools**:
- MCP: `filesystem`
- Skill: NONE

**Done when**:
- [x] Método `importFromAutoEQ(text:brand:model:) -> HeadphoneProfile` extraindo corretamente linhas como `Filter 1: ON LSC Fc 105 Hz Gain -4.2 dB Q 0.70`.
- [x] Métodos `importFromJSON(url:)`, `importFromJSON(data:)`, `importFromJSON(string:)` e `exportToJSON(profile:to:)` operando sem erros.

**Verify**:
`swift build && swift test`

---

### T6: Implementar o Gerenciador de Armazenamento (`ProfileStore`) [P]

**What**: Criar `ProfileStore: ObservableObject` mantendo a lista `@Published var profiles` dividida em Built-in (carregados do Bundle) e Custom (salvos no disco local do usuário).
**Where**: `Equalizer/Services/ProfileStore.swift`
**Depends on**: T1, T3, T4, T5
**Reuses**: NONE

**Tools**:
- MCP: `filesystem`
- Skill: NONE

**Done when**:
- [x] Método `loadBuiltInProfiles()` encontrando os 3 perfis nativos no Bundle do app.
- [x] Métodos `saveProfile(_:)`, `deleteProfile(_:)`, `duplicateProfile(_:)` e `importProfile(from:)` mantendo a pasta `~/Library/Application Support/Equalizer/HeadphoneProfiles/custom/` sincronizada.

**Verify**:
`swift build && swift test`

---

### T7: Implementar Modelo e Gerenciador de Presets (`PresetStore`) [P]

**What**: Criar o modelo `EQPreset.swift` (para curvas simples de 10 bandas como Flat, Rock, Jazz, Bass Boost) e sua classe de gerenciamento `PresetStore: ObservableObject`.
**Where**: `Equalizer/Models/EQPreset.swift` & `Equalizer/Services/PresetStore.swift`
**Depends on**: T1
**Reuses**: NONE

**Tools**:
- MCP: `filesystem`
- Skill: NONE

**Done when**:
- [x] Presets básicos de 10 bandas criados (Flat, Bass Boost, Vocal, Rock, Electronic, Acoustic) e carregando junto ao app.
- [x] `PresetStore` com carregamento, salvamento, exclusão e duplicação de presets customizados.

**Verify**:
`swift build && swift test`

---

### T8: Implementar Lista e Detalhes de Perfis (`ProfileListView` & `ProfileDetailView`)

**What**: Criar as views em SwiftUI para listar os perfis agrupados e exibir o painel detalhado `ProfileDetailView` mostrando a tabela de todas as frequências e o botão de ativação.
**Where**: `Equalizer/Views/Profiles/ProfileListView.swift` & `ProfileDetailView.swift`
**Depends on**: T6
**Reuses**: NONE

**Tools**:
- MCP: `filesystem`
- Skill: NONE

**Done when**:
- [x] Lista agrupada por Built-in / My Profiles renderizada.
- [x] `ProfileDetailView` exibindo metadados e tabela de bandas.

**Verify**:
`swift build`

---

### T9: Implementar Editor Paramétrico Inline (`ProfileEditorView` & `BandEditorRow`)

**What**: Criar a view de edição `ProfileEditorView` permitindo modificar Hz, Gain, Q, BW e adicionar/remover bandas do perfil dinamicamente com cálculo instantâneo.
**Where**: `Equalizer/Views/Profiles/ProfileEditorView.swift` & `BandEditorRow.swift`
**Depends on**: T1, T8
**Reuses**: NONE

**Tools**:
- MCP: `filesystem`
- Skill: NONE

**Done when**:
- [x] Tabela de edição permitindo alterar tipo, frequência, ganho, Q e estado ativo de cada banda.
- [x] Botão "Save" persistindo no `ProfileStore`.

**Verify**:
`swift build`

---

### T10: Conectar `ProfilePicker` na `NotchExpandedView` (`EQHeaderView`)

**What**: Adicionar na barra superior do equalizador no notch o botão/menu `ProfilePicker` que mostra o fone ativo atual (ex: `● Sony WH-1000XM4`) e abre a `ProfileListView` ao ser clicado.
**Where**: `Equalizer/Views/EQHeaderView.swift`
**Depends on**: T8
**Reuses**: `EQHeaderView.swift` (modificar)

**Tools**:
- MCP: `filesystem`
- Skill: NONE

**Done when**:
- [x] Menu de perfis e menu de presets conectados no `EQHeaderView`.
- [x] Seleção de perfil/preset atualiza o motor de áudio via `EqualizerViewModel`.

**Verify**:
`swift build`

---

### T11: Conectar `ParametricEQProcessor` ao `ProfileStore`

**What**: Configurar para que, ao alterar o `activeProfile` no `ProfileStore` ou `EqualizerViewModel`, o `AudioEngineManager` acione o método `ParametricEQProcessor.loadProfile(_:)` com as N bandas.
**Where**: `Equalizer/ViewModels/EqualizerViewModel.swift` & `Equalizer/Audio/AudioEngineManager.swift`
**Depends on**: T6
**Reuses**: `AudioEngineManager.swift` (modificar)

**Tools**:
- MCP: `filesystem`
- Skill: NONE

**Done when**:
- [x] `EqualizerViewModel` observa `profileStore.activeProfile` e chama `ParametricEQProcessor.loadProfile(_:)` com `preampGain` e bandas ativas.
- [x] `ParametricEQProcessor` usa 20 bandas fixas (limite do schema) e ativa apenas as bandas do perfil.

**Verify**:
`swift build`

---

### T12: Implementar Seletor de Arquivo e Drag & Drop (`fileImporter`)

**What**: Adicionar suporte a `.fileImporter(isPresented:allowedContentTypes:)` e `.onDrop(of:)` na `ProfileListView` para permitir importar arquivos `ParametricEQ.txt` ou `.json` arrastando do Finder.
**Where**: `Equalizer/Views/Profiles/ProfileListView.swift`
**Depends on**: T5, T8
**Reuses**: `ProfileListView.swift` (modificar)

**Tools**:
- MCP: `filesystem`
- Skill: NONE

**Done when**:
- [ ] Arrastar um arquivo do AutoEQ da área de trabalho sobre a janela do equalizador importa e salva o perfil instantaneamente na lista.
- [ ] Botão "Import" na `ProfileListView` abre file picker.

**Status:** Parcial — `ProfileStore.importProfile(from:)` implementado; UI de importação/drag-drop pendente.

**Verify**:
`swift build`

---

### T13: Validação Final e Suíte de Testes Unitários de Perfis (`EqualizerTests`)

**What**: Criar o target de testes unitários `EqualizerTests` testando a conversão de `qToBandwidth`, decodificação dos JSONs nativos dos 3 fones e parsing de texto do AutoEQ.
**Where**: `EqualizerTests/ProfileTests.swift`
**Depends on**: T12
**Reuses**: NONE

**Tools**:
- MCP: NONE
- Skill: NONE

**Done when**:
- [x] Testes de decodificação dos 3 perfis built-in, cálculos Q/BW, importação JSON e parsing AutoEQ escritos e compilando.
- [ ] Todos os testes unitários executam e passam no ambiente de CI/Xcode completo.

**Status:** Compilando; execução depende de ambiente com Xcode/Swift Testing completo.

**Verify**:
`swift build && swift test`
