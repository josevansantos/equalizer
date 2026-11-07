# Notch Window & Interface Base Tasks

**Design**: `.specs/features/notch-window/design.md`
**Status**: Approved

---

## Execution Plan

### Phase 1: Foundation (Sequential)

```
T1 → T2 → T3 → T4 → T5
```

### Phase 2: Core Models & Geometry (Parallel OK)

```
     ┌→ T6 [P] ─┐
T5 ──┼→ T7 [P] ─┼──→ T9
     └→ T8 [P] ─┘
```

### Phase 3: Panel Setup & Views (Sequential & Parallel)

```
T9 → T10 → T11 → T12 → T13 → T14 → T15
```

---

## Task Breakdown

### T1: Criar o Projeto Xcode Equalizer em Swift/SwiftUI

**What**: Inicializar a estrutura base do projeto `Equalizer.xcodeproj` via linha de comando ou Xcode, configurando o Target macOS 15.0+, Swift 5.9+ e ciclo de vida nativo de app ou `AppDelegate`.
**Where**: `Equalizer.xcodeproj/project.pbxproj`
**Depends on**: None
**Reuses**: NONE

**Tools**:
- MCP: `filesystem`
- Skill: NONE

**Done when**:
- [x] Projeto `Equalizer.xcodeproj` criado e abrindo corretamente no Xcode.
- [x] Build inicial executa sem warnings ou erros (`xcodebuild -project Equalizer.xcodeproj -scheme Equalizer build`).

**Verify**:
`xcodebuild -project Equalizer.xcodeproj -scheme Equalizer -configuration Debug build`

---

### T2: Configurar `Info.plist` para App de Fundo (`LSUIElement`)

**What**: Adicionar a chave `LSUIElement = true` ao `Info.plist` (ou build settings) para que a aplicação rode silenciosamente como agente de sistema, sem exibir ícone no Dock ou menu bar padrão.
**Where**: `Equalizer/Info.plist`
**Depends on**: T1
**Reuses**: NONE

**Tools**:
- MCP: `filesystem`
- Skill: NONE

**Done when**:
- [x] Chave `LSUIElement` (Application is agent (UIElement)) definida como `YES`.
- [x] Ao rodar o app, nenhum ícone é gerado no Dock do macOS.

**Verify**:
`grep -A 1 "LSUIElement" Equalizer/Info.plist || xcodebuild -project Equalizer.xcodeproj -showBuildSettings | grep "INFOPLIST_KEY_LSUIElement"`

---

### T3: Configurar Arquivo de Entitlements (`Equalizer.entitlements`)

**What**: Criar e habilitar o arquivo de entitlements do target, solicitando acesso à captura de áudio (`com.apple.security.device.audio-input`) e permissões de sandbox necessárias para o Core Audio Tap.
**Where**: `Equalizer/Equalizer.entitlements`
**Depends on**: T1
**Reuses**: NONE

**Tools**:
- MCP: `filesystem`
- Skill: NONE

**Done when**:
- [x] Arquivo `Equalizer.entitlements` criado no projeto com a chave `com.apple.security.device.audio-input` = `true`.
- [x] Build Settings apontando para o arquivo de entitlements corretamente (`CODE_SIGN_ENTITLEMENTS = Equalizer/Equalizer.entitlements`).

**Verify**:
`plutil -p Equalizer/Equalizer.entitlements`

---

### T4: Criar Arquivo `.gitignore` do Projeto

**What**: Criar um arquivo `.gitignore` padrão e limpo para projetos Xcode/Swift no macOS, excluindo pastas de build (`DerivedData/`, `*.xcuserdata`, `*.xcworkspace/xcuserdata`).
**Where**: `.gitignore`
**Depends on**: None
**Reuses**: NONE

**Tools**:
- MCP: `filesystem`
- Skill: NONE

**Done when**:
- [x] Arquivo `.gitignore` presente na raiz com regras do Swift/Xcode.

**Verify**:
`test -f .gitignore && head -n 5 .gitignore`

---

### T5: Estruturar Diretórios do Código Fonte

**What**: Criar as pastas organizacionais do código fonte dentro do diretório do app: `Models/`, `ViewModels/`, `Views/`, `Helpers/`, `Audio/` e `Services/`.
**Where**: `Equalizer/*`
**Depends on**: T1
**Reuses**: NONE

**Tools**:
- MCP: `filesystem`
- Skill: NONE

**Done when**:
- [x] Diretórios `Models/`, `ViewModels/`, `Views/`, `Helpers/`, `Audio/` criados no file system.

**Verify**:
`ls -R Equalizer/ | grep ":$"`

---

### T6: Implementar Extensão de Tela (`NSScreen+Notch`) [P]

**What**: Criar o arquivo `ScreenHelper.swift` com a extensão `NSScreen+Notch` que encapsula a lógica para detectar se a tela principal possui notch físico e calcula suas dimensões e insets com precisão.
**Where**: `Equalizer/Helpers/ScreenHelper.swift`
**Depends on**: T5
**Reuses**: NONE

**Tools**:
- MCP: `filesystem`
- Skill: NONE

**Done when**:
- [x] Propriedades `hasNotch`, `notchFrame` e `notchSize` implementadas e testadas na extensão `NSScreen`.
- [x] Arquivo compila sem erros.

**Verify**:
`xcodebuild -project Equalizer.xcodeproj -scheme Equalizer -configuration Debug build`

---

### T7: Implementar Modelo de Estado (`NotchState`) [P]

**What**: Criar o modelo `NotchState.swift` definindo o enum `NotchState: Equatable` com os casos `.collapsed` e `.expanded`.
**Where**: `Equalizer/Models/NotchState.swift`
**Depends on**: T5
**Reuses**: NONE

**Tools**:
- MCP: `filesystem`
- Skill: NONE

**Done when**:
- [x] Enum `NotchState` implementado e acessível publicamente pelo target.

**Verify**:
`xcodebuild -project Equalizer.xcodeproj -scheme Equalizer -configuration Debug build`

---

### T8: Implementar `NotchViewModel` [P]

**What**: Criar o `NotchViewModel: ObservableObject` responsável por manter o estado `@Published var state: NotchState = .collapsed` e as funções `toggleExpand()`, `expand()` e `collapse()`.
**Where**: `Equalizer/ViewModels/NotchViewModel.swift`
**Depends on**: T7
**Reuses**: NONE

**Tools**:
- MCP: `filesystem`
- Skill: NONE

**Done when**:
- [x] Classe `NotchViewModel` criada e importando `Combine` e `SwiftUI`.
- [x] Animações vinculadas com `withAnimation(.spring(response: 0.35, dampingFraction: 0.78))` nas trocas de estado.

**Verify**:
`xcodebuild -project Equalizer.xcodeproj -scheme Equalizer -configuration Debug build`

---

### T9: Implementar `NotchHelper` para Configuração do `NSPanel`

**What**: Criar a classe `NotchHelper` responsável por instanciar e gerenciar o `NSPanel` com estilo `.borderless` + `.nonactivatingPanel`, nível `.statusBar`, e comportamentos em múltiplos Spaces.
**Where**: `Equalizer/Helpers/NotchHelper.swift`
**Depends on**: T6, T8
**Reuses**: NONE

**Tools**:
- MCP: `filesystem`
- Skill: NONE

**Done when**:
- [x] Método `createNotchPanel(with viewModel: NotchViewModel) -> NSPanel` implementado.
- [x] Configurações de `isFloatingPanel = true`, `becomesKeyOnlyIfNeeded = true` e `collectionBehavior` aplicadas.

**Verify**:
`xcodebuild -project Equalizer.xcodeproj -scheme Equalizer -configuration Debug build`

---

### T10: Implementar View Colapsada (`NotchCollapsedView`)

**What**: Criar a view SwiftUI `NotchCollapsedView` com fundo preto puro (alinhado ao notch) e indicador visual sutil, que serve de gatilho acionável por clique.
**Where**: `Equalizer/Views/NotchCollapsedView.swift`
**Depends on**: T8
**Reuses**: NONE

**Tools**:
- MCP: `filesystem`
- Skill: NONE

**Done when**:
- [x] `NotchCollapsedView` desenhada com dimensões correspondentes à largura e altura do notch.
- [x] Gesture de `.onTapGesture` conectando a `viewModel.toggleExpand()`.

**Verify**:
`xcodebuild -project Equalizer.xcodeproj -scheme Equalizer -configuration Debug build`

---

### T11: Implementar View Expandida Placeholder (`NotchExpandedView`)

**What**: Criar a view SwiftUI `NotchExpandedView` como estrutura base e container que em breve abrigará o equalizador gráfico, com botão/gesto para colapsar e efeito visual `.ultraThinMaterial`.
**Where**: `Equalizer/Views/NotchExpandedView.swift`
**Depends on**: T8
**Reuses**: NONE

**Tools**:
- MCP: `filesystem`
- Skill: NONE

**Done when**:
- [x] `NotchExpandedView` renderizando um painel com cantos arredondados, título base e botão de fechar/colapsar.

**Verify**:
`xcodebuild -project Equalizer.xcodeproj -scheme Equalizer -configuration Debug build`

---

### T12: Implementar Container Principal (`NotchContainerView`)

**What**: Criar a view `NotchContainerView` que observa `NotchViewModel` e alterna a exibição entre `NotchCollapsedView` e `NotchExpandedView` com transições declarativas.
**Where**: `Equalizer/Views/NotchContainerView.swift`
**Depends on**: T10, T11
**Reuses**: NONE

**Tools**:
- MCP: `filesystem`
- Skill: NONE

**Done when**:
- [x] Switch reativo renderizando a view colapsada quando `state == .collapsed` e expandida quando `state == .expanded`.

**Verify**:
`xcodebuild -project Equalizer.xcodeproj -scheme Equalizer -configuration Debug build`

---

### T13: Implementar e Conectar `AppDelegate`

**What**: Criar o `AppDelegate: NSObject, NSApplicationDelegate` que instancia `NotchViewModel` e `NotchHelper`, inicializando e montando o `NSPanel` no `applicationDidFinishLaunching`.
**Where**: `Equalizer/AppDelegate.swift`
**Depends on**: T9, T12
**Reuses**: NONE

**Tools**:
- MCP: `filesystem`
- Skill: NONE

**Done when**:
- [x] `AppDelegate` instanciando o painel no notch e exibindo o aplicativo em segundo plano ao ligar.
- [x] Observers de tela (`setupScreenChangeObservers`) registrados.

**Verify**:
`xcodebuild -project Equalizer.xcodeproj -scheme Equalizer -configuration Debug build`

---

### T14: Conectar o Ponto de Entrada da Aplicação (`EqualizerApp.swift`)

**What**: Configurar o `@main struct EqualizerApp: App` utilizando `@NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate` para ligar o ciclo de vida nativo ao SwiftUI.
**Where**: `Equalizer/EqualizerApp.swift`
**Depends on**: T13
**Reuses**: NONE

**Tools**:
- MCP: `filesystem`
- Skill: NONE

**Done when**:
- [x] App estruturado corretamente com `@NSApplicationDelegateAdaptor`.
- [x] Compilação final da Fase 1 bem-sucedida.

**Verify**:
`xcodebuild -project Equalizer.xcodeproj -scheme Equalizer -configuration Debug build`

---

### T15: Adicionar Monitoramento de Clique Fora (Auto-Collapse)

**What**: Implementar no `NotchHelper` ou `AppDelegate` um observador de eventos globais/locais (`NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown])`) para colapsar o painel sempre que o usuário clicar fora de sua área bounds enquanto expandido.
**Where**: `Equalizer/Helpers/NotchHelper.swift`
**Depends on**: T14
**Reuses**: NONE

**Tools**:
- MCP: `filesystem`
- Skill: NONE

**Done when**:
- [x] Quando o painel está expandido e o usuário clica no Safari ou no Finder, o `viewModel.collapse()` é acionado automaticamente.

**Verify**:
`xcodebuild -project Equalizer.xcodeproj -scheme Equalizer -configuration Debug build`
