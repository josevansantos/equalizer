# State

**Last Updated:** 2026-11-07
**Current Work:** Pipeline de áudio refeito e validado com áudio real. Falta validar a interação na interface e a troca de dispositivo em uso.
**Status:** IN PROGRESS

> O status `COMPLETE` anterior estava errado: o tap nunca entrava no aggregate device, e o motor processava o microfone em vez do áudio do sistema. Os testes não detectavam isso porque não passavam áudio. O EQ de entrada citado em AD-008 não existe no código.

---

## Recent Decisions (Last 60 days)

### AD-010: IOProc + AVAudioEngine em manual rendering (2026-11-07)

**Decision:** Ler o aggregate device com um IOProc próprio (`SystemAudioRenderer`) e usar o `AVAudioEngine` só como cadeia de DSP, em manual rendering. O tap entra em `kAudioAggregateDeviceTapListKey`, exclui o próprio processo e usa `.mutedWhenTapped`. O dispositivo de saída padrão não é mais alterado.
**Reason:** Com o aggregate ligado ao engine, o `inputNode` continua informando o formato do microfone (1 canal contra 2 no hardware), e o uso normal do engine abre o microfone padrão.
**Trade-off:** Mais código de tempo real sob nossa responsabilidade (buffers pré-alocados, conversão entre layouts de canal).
**Impact:** O áudio do sistema passa de fato pelo EQ, o microfone não é aberto, e o som dos outros apps volta sozinho se o app parar. Substitui a parte de AD-006 sobre o grafo em runtime: o engine agora é recriado a cada início.

### AD-008: Integração reativa entre InputCaptureManager e UI I/O (2026-07-11)

**Decision:** Expor `InputCaptureManager` e seleção de dispositivos diretamente em menus interativos no rodapé (`EQFooterView`)
**Reason:** Elimina placeholders estáticos e permite que o usuário alterne gravação com equalização de microfone (`startCapture`/`stopCapture`) e alterne ou inspecione dispositivos sem sair da UI do notch
**Trade-off:** Mais bindings reativos no rodapé compactado
**Impact:** Completa a Fase 4 (`Motor de Áudio Input`) integrando o pipeline de entrada ao fluxo de experiência do usuário

### AD-009: Visualizador de espectro FFT integrado no Canvas de curva e no notch colapsado (2026-07-11)

**Decision:** Desenhar barras em gradiente de espectro FFT diretamente no `Canvas` de `EQCurveView` e mini barras dinâmicas em `NotchCollapsedView` com base nas magnitudes emitidas por `AudioLevelTap`
**Reason:** Garante renderização em 60 FPS sem overhead de views extras do SwiftUI e fornece feedback visual imediato tanto quando colapsado quanto quando expandido
**Trade-off:** Exige observação reativa do `AudioEngineManager` em ambas as views
**Impact:** Interface dinâmica e visualmente rica que atende plenamente ao requisito de design e à Fase 6 (`Medidor de Nível & Visualização`)

### AD-001: Core Audio Tap para interceptação de áudio (2026-07-11)

**Decision:** Usar Core Audio Tap (AudioHardwareCreateProcessTap) para interceptar e processar áudio do sistema
**Reason:** API nativa disponível desde macOS 14.2+, não requer instalação de driver de áudio virtual nem extensão de kernel
**Trade-off:** Requer macOS 14.2 ou superior — usuários em versões anteriores não poderão utilizar o app
**Impact:** Simplifica drasticamente a arquitetura de captura de áudio, elimina necessidade de virtual audio driver (como BlackHole ou Soundflower), e permite distribuição via App Store sem problemas de assinatura de kernel extension

### AD-002: NSPanel para janela do notch (2026-07-11)

**Decision:** Usar NSPanel (non-activating) para a janela flutuante do equalizador posicionada no notch
**Reason:** NSPanel com estilo non-activating não rouba foco da aplicação ativa, comportamento essencial para um equalizador que deve funcionar como overlay
**Trade-off:** Menor flexibilidade de customização comparado a NSWindow com configurações avançadas de nível de janela
**Impact:** A janela do equalizador aparece e desaparece sem interferir no fluxo de trabalho do usuário, mantendo o foco na aplicação que está em uso

### AD-003: Zero dependências externas (2026-07-11)

**Decision:** Utilizar exclusivamente frameworks nativos da Apple (CoreAudio, Accelerate, SwiftUI, AVFoundation) sem nenhuma dependência externa
**Reason:** Reduz complexidade de build, elimina riscos de supply chain, garante compatibilidade total com o ecossistema Apple e facilita manutenção a longo prazo
**Trade-off:** Pode exigir mais código custom para funcionalidades que bibliotecas de terceiros já oferecem prontas (ex: DSP avançado, UI components)
**Impact:** Projeto sem CocoaPods, SPM packages externos ou Carthage — build limpo e rápido, sem riscos de breaking changes de dependências

### AD-004: Headphone profiles em JSON (2026-07-11)

**Decision:** Armazenar perfis de equalização de headphones em formato JSON
**Reason:** Formato portável, legível por humanos, fácil de versionar com Git, e compatível com o projeto AutoEQ que disponibiliza milhares de perfis de compensação
**Trade-off:** Maior tamanho de arquivo comparado a formatos binários como plist binário ou Protocol Buffers
**Impact:** Usuários podem importar perfis diretamente do AutoEQ, criar e compartilhar perfis customizados, e inspecionar/editar manualmente os arquivos de configuração

### AD-005: Alinhamento do modelo HeadphoneProfile com JSON Schema (2026-07-11)

**Decision:** Expandir a struct `HeadphoneProfile` para conter todos os campos definidos no `_schema.json` e no `PLAN.md` (`preampGain`, `description`, `source`, `isBuiltIn`, `createdAt`, `updatedAt`, `isEnabled` em cada banda)
**Reason:** Garantir decodificação direta dos JSONs built-in e importados, evitando perda de metadados e inconsistências entre persistência e runtime
**Trade-off:** Modelo ligeiramente maior, mas ainda trivial em memória
**Impact:** `ProfileStore` pode carregar qualquer perfil compatível com o schema sem transformações ad-hoc

### AD-006: Capacidade fixa de 20 bandas no ParametricEQProcessor (2026-07-11)

**Decision:** Manter um `AVAudioUnitEQ` fixo com 20 bandas (máximo do schema) e ativar/desativar bandas conforme o perfil, em vez de recriar o node a cada troca
**Reason:** Evita a complexidade de desanexar/reconectar nós no `AVAudioEngine` em runtime; 20 bandas cobrem o limite do schema
**Trade-off:** Consumo ligeiramente maior de memória do DSP, mas irrelevante para o hardware alvo
**Impact:** Troca de perfis é instantânea e sem interrupção no grafo de áudio

### AD-007: Cálculo de geometria do notch via visibleFrame (2026-07-11)

**Decision:** Usar `NSScreen.visibleFrame.maxY` para calcular a altura e posição Y do notch, em vez de `safeAreaInsets.top`
**Reason:** `visibleFrame` reflete a altura real da barra de menus no macOS, eliminando deslocamentos visuais
**Trade-off:** Depende da API `visibleFrame`, que pode variar em configurações de tela incomuns
**Impact:** Painel colapsado alinha-se perfeitamente à faixa do notch/barra de menus

---

## Active Blockers

Nenhum.

---

## Lessons Learned

- A marcação de tasks como `[x]` nos specs deve ser acompanhada de verificação real de comportamento, não apenas de compilação.
- A divergência entre modelos Swift e JSONs pode passar despercebida enquanto os arquivos não são carregados em runtime.
- Swift Testing com Foundation apresenta conflitos de módulo no ambiente CommandLineTools sem Xcode completo; testes foram mantidos em Swift Testing sem import Foundation e validam compilação.
- Recursos em SPM (`Bundle.module`) não preservam necessariamente a estrutura de subpastas; é preciso verificar o bundle gerado.
- `NSScreen.visibleFrame` é mais confiável que `safeAreaInsets.top` para calcular a faixa da barra de menus em telas com notch.
- O callback de `installTap` do `AVAudioEngine` roda em uma realtime thread; capturar `self` de um `@MainActor` dentro dele causa crash (`_dispatch_assert_queue_fail`) no Swift 6. A solução é isolar o tap em um objeto não-ator (`AudioLevelTap`) e notificar a UI por meio de uma closure `@Sendable`.
- "Engine iniciou sem crash" não prova que há áudio. Um UID desconhecido em `SubDeviceList` é descartado sem erro, deixando o aggregate sem entrada. O teste que vale mede o sinal.
- `isFloatingPanel = true` redefine o nível da janela para `.floating`: defina `level` depois dele.
- Testes que usam o `AudioEngineManager` real silenciam o áudio da máquina. Use `MockAudioEngineManager`.
- Mutar elementos de um array `@Published` via subscript (`array[index].property = ...`) não dispara o publisher `$array`. Para que o Combine/SwiftUI e os bindings do motor de áudio sejam notificados, é necessário reatribuir o array inteiro (`array = updatedArray`).

---

## Preferences

**Model Guidance Shown:** never
