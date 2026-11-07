# Notch Window & Interface Base Specification

## Problem Statement

A maioria dos utilitários e equalizadores para macOS reside na barra de menus tradicional ou em janelas soltas que obstruem o espaço de trabalho e exigem múltiplos cliques. Com a introdução do notch na tela dos MacBooks modernos (e telas externas compatíveis), há uma zona privilegiada de foco central que pode ser aproveitada para abrigar um painel flutuante ultra-leve, acessível instantaneamente ao mover o mouse ou clicar no topo da tela, sem roubar o foco da janela ativa do usuário.

## Goals

- [ ] Criar e gerenciar um `NSPanel` flutuante com estilo não-ativável (non-activating) ancorado exatamente na geometria do notch do macOS 15+.
- [ ] Implementar transição animada e fluida entre o estado colapsado (indicador visual sutil no notch) e expandido (painel principal de equalização).
- [ ] Garantir latência zero na abertura do painel e consumo de CPU nulo quando o painel estiver colapsado/inativo.

## Out of Scope

- Modificação ou injeção visual dentro da barra de menus nativa do sistema fora da área do notch.
- Suporte a monitores sem notch em modos que não simulem ou fallback para ancoragem no centro superior da barra de menus.

---

## User Stories

### P1: Janela Flutuante no Notch Não-Ativável ⭐ MVP

**User Story**: As a usuário de macOS, I want que o aplicativo resida discretamente na área do notch e abra como um overlay flutuante ao clicar na sua zona, so that eu possa ajustar a equalização sem perder o foco ou interromper a aplicação que estou usando no momento.

**Why P1**: É a fundação arquitetural da interface de usuário do projeto; sem o posicionamento preciso e comportamento de foco correto (`LSUIElement`, `NSPanel`), o app não atende ao requisito core de ser leve e não-intrusivo.

**Acceptance Criteria**:

1. WHEN o aplicativo é iniciado, THEN system SHALL ocultar o ícone da barra de tarefas/dock (`LSUIElement = true`) e exibir apenas o container colapsado na região do notch da tela principal.
2. WHEN o usuário clica ou passa o cursor (se configurado) sobre a zona do notch colapsado, THEN system SHALL expandir o `NSPanel` para baixo com uma animação de mola/transição suave em menos de 250ms.
3. WHEN o painel flutuante está expandido e o usuário clica em qualquer outra área da tela ou em outro aplicativo, THEN system SHALL colapsar o painel automaticamente e manter a aplicação ativa do usuário sem perda de foco.

**Independent Test**: Compilar e rodar o app no macOS Sequoia 15.7.7, verificar que nenhum ícone aparece no Dock, clicar no notch para ver a janela abrir, interagir com outro app aberto (ex: Safari) e confirmar que o painel fecha sem que o Safari perca o foco (`NSWindow.isKeyWindow`).

---

### P2: Detecção Dinâmica de Múltiplas Telas e Geometria do Notch

**User Story**: As a usuário conectando e desconectando monitores externos, I want que o aplicativo identifique automaticamente qual tela possui notch e ajuste suas proporções, so that a interface pareça sempre nativa e perfeitamente alinhada com o hardware da tela ativa.

**Why P2**: Usuários de Mac frequentemente alternam entre a tela interna do MacBook Pro/Air (com notch) e monitores externos ou Studio Displays (sem notch).

**Acceptance Criteria**:

1. WHEN a resolução da tela muda ou um novo monitor é conectado/desconectado, THEN system SHALL recalcular o bounding box do notch via `NSScreen.safeAreaInsets` e `auxiliaryTopLeftArea`.
2. WHEN o app é executado em uma tela externa sem notch físico, THEN system SHALL posicionar a janela colapsada no centro superior da barra de menus, simulando o ponto de ancoragem do notch.

**Independent Test**: Conectar/desconectar um monitor externo ou alterar a resolução da tela em System Settings enquanto o app roda, verificando se o painel se reposiciona corretamente no topo central.

---

## Edge Cases

- WHEN o usuário utiliza espaços de trabalho virtuais (Spaces/Mission Control) e troca de mesa, THEN system SHALL garantir que o painel do notch permaneça acessível e flutuante em todos os Spaces (`collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]`).
- WHEN o macOS está em modo de tela cheia (Full Screen App ativo), THEN system SHALL permitir que a zona do notch seja invocada quando o usuário mover o mouse para o topo absoluto da tela.

---

## Success Criteria

- [ ] O `NSPanel` abre e fecha consistentemente a 60/120 FPS nas telas ProMotion sem engasgos visualmente perceptíveis.
- [ ] O app consome 0% de uso de CPU adicional e < 35 MB de RAM no monitor do sistema quando no estado colapsado.
