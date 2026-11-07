# Equalizer Interface Specification

## Problem Statement

Um equalizador precisa oferecer controle visual imediato, preciso e responsivo sobre o espectro sonoro. Sliders tradicionais em janelas estáticas frequentemente carecem de feedback em tempo real ou tornam difícil visualizar como os filtros paramétricos ou gráficos interagem entre si. Na interface do notch, o desafio é condensar 10 bandas de frequência, controles de ganho de pré-amplificação (Preamp), seletores de presets e visualização da curva harmônica em um layout limpo, escuro e com micro-animações, sem que a tela fique poluída ou ilegível.

## Goals

- [ ] Criar o componente de controle gráfico de 10 bandas (`EQBandSlider`) com resposta tátil visual, permitindo ajustes entre -15 dB e +15 dB por slider.
- [ ] Implementar visualização da curva de resposta em tempo real (`EQCurveView`) com SwiftUI Canvas para representar graficamente a soma de todas as bandas ativas.
- [ ] Construir a barra de ferramentas superior e inferior com controles essenciais: Volume global, Bypass, Preamp slider, Seletor de Presets, Seletor de Fones (`ProfilePicker`) e Seletor de I/O.

## Out of Scope

- Edição paramétrica fina (arrastar nós diretamente na curva em 2D do Canvas na v1; a v1 usa os sliders ou a tabela do editor de perfis).
- Temas claros (Light Mode); o equalizador no notch foi projetado primariamente com estética escura, glassmorphism e cores vibrantes.

---

## User Stories

### P1: Equalizador Gráfico de 10 Bandas e Sliders ⭐ MVP

**User Story**: As a usuário, I want deslizar os controles de 10 bandas de frequência individuais (de 32 Hz a 16 kHz), so that eu possa moldar com precisão os graves, médios e agudos do áudio do meu Mac.

**Why P1**: É a interface visual principal através da qual o usuário interage e modifica as configurações sonoras no dia a dia.

**Acceptance Criteria**:

1. WHEN a janela expandida do notch é aberta, THEN system SHALL renderizar 10 sliders verticais alinhados horizontalmente, cada um exibindo o rótulo de sua frequência de centro (ex: `32`, `64`, `125`, `250`, `500`, `1k`, `2k`, `4k`, `8k`, `16k`).
2. WHEN o usuário arrasta um slider para cima ou para baixo, THEN system SHALL atualizar o valor numérico de ganho de forma fluida (ex: `+3.5 dB`) e emitir a mudança para o `EqualizerViewModel` sem atraso de renderização.
3. WHEN o botão de "Reset" ou duplo clique em um slider ocorre, THEN system SHALL retornar o ganho daquela banda para `0.0 dB` animadamente.

**Independent Test**: Abrir a janela expandida no app em execução e arrastar os sliders entre -15 dB e +15 dB, verificando se a UI reflete os números em tempo real e se o duplo clique restaura a banda ao zero absoluto.

---

### P2: Visualizador da Curva de Equalização (`EQCurveView`)

**User Story**: As a usuário ajustando várias bandas ou carregando um perfil paramétrico de fone, I want ver uma curva gráfica suave sobreposta na interface, so that eu entenda visualmente como a resposta de frequência final está se comportando em todo o espectro auditivo.

**Why P2**: Fornece clareza estética e técnica incomparável, elevando o app de um simples painel de sliders para um instrumento DSP de precisão premium.

**Acceptance Criteria**:

1. WHEN qualquer banda de equalização ou ganho de Preamp é alterada, THEN system SHALL recalcular os pontos da curva logarítmica e redesenhar o traçado no `Canvas` de fundo com um gradiente visualmente vibrante.
2. WHEN o equalizador entra no modo `Bypass` (desativado), THEN system SHALL atenuar a cor da curva ou desenhar uma linha reta neutra em `0 dB`.

**Independent Test**: Alterar drasticamente a banda de 32 Hz para +10 dB e a banda de 1k para -8 dB, observando se o gráfico no Canvas forma uma curva suave interligando as bandas.

---

### P3: Controles Globais (Preamp, Volume, Presets e I/O)

**User Story**: As a usuário, I want ter acesso rápido na barra de topo/fundo a um controle de ganho de entrada (Preamp), seletor de fone ativo e botão de ativação geral (Toggle Bypass), so that eu evite distorções digitais e ligue/desligue o efeito com um clique.

**Why P3**: Completa o ecossistema da janela do notch com todas as ferramentas essenciais de roteamento e prevenção de clipping.

**Acceptance Criteria**:

1. WHEN o usuário ajusta o slider de `Preamp`, THEN system SHALL atualizar o ganho global de entrada (-15 dB a +15 dB).
2. WHEN o usuário clica no seletor de dispositivo, THEN system SHALL exibir um menu dropdown listando os dispositivos de saída de áudio disponíveis no macOS.

**Independent Test**: Verificar se o toggle de Bypass altera visualmente o estado geral do painel e se o dropdown lista corretamente os alto-falantes internos/fones Bluetooth conectados.

---

## Edge Cases

- WHEN todas as 10 bandas estão no máximo (+15 dB) e o Preamp em 0 dB, THEN system SHALL exibir um indicador de aviso visual discreto ou sugerir abaixar o Preamp para evitar distorção harmônica severa.

---

## Success Criteria

- [ ] A rolagem e o arrasto de múltiplos sliders acontecem a 60 FPS consistentes, sem travamentos na thread principal da UI.
- [ ] O visual no notch causa impacto positivo instantâneo no usuário, com paleta escura harmoniosa (`Color+Theme`), sombras sutis e tipografia clara.
