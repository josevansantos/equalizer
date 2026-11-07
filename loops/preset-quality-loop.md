---
nome: preset-quality-loop
categoria: Avaliação | Refatoração
gatilho: manual
base-teorica: "Verificação externa via logs para evitar auto-score e garantir consistência de estado entre ViewModel e DSP"
---

# Loop de Qualidade de Presets e Perfis

## Descrição
Garante que todos os presets (built-in e custom) e perfis de fone sejam aplicados instantaneamente ao DSP, reflitam na UI e persistam após o boot do engine.

## Use quando
Houver alterações no `EqualizerViewModel`, `AudioEngineManager` ou nos modelos de `EQPreset`/`HeadphoneProfile` que possam afetar a sincronização de áudio.

## Meta
100% de taxa de sucesso na aplicação de presets e perfis, com sincronização perfeita entre UI e DSP e restauração total no boot. Verificável? sim, é número/comando.

## Verificação (o check que manda)
A cada volta, o agente deve simular a troca de um preset/perfil e capturar a saída do console.
- **Check:** Análise de logs via `grep` ou leitura de arquivo de log.
- **Pronto =** Para cada ação de "load", deve existir a sequência:
  1. `[EqualizerViewModel] Aplicando preset: <nome>`
  2. `[EqualizerViewModel] Banda[0...9] ...`
  3. `[EqualizerViewModel] Preset aplicado/resetado`
  Sendo que NÃO deve haver mensagens de `Erro`, `Falha` ou `Crash` no transcript.

## Passos da volta
1. Fotografe a lista atual de presets e perfis disponíveis.
2. Escolha o preset/perfil com maior probabilidade de falha (ex: customizado com muitas bandas ou `nil`).
3. Execute a ação de carregamento via `viewModel.loadPreset()` ou `viewModel.loadHeadphoneProfile()`.
4. Capture os logs gerados e cole no transcript.
5. Verifique se a sequência de logs de sucesso foi emitida e se os valores no DSP coincidem com o modelo.
6. Se houver erro, corrija o código no `EqualizerViewModel` ou `AudioEngineManager`.
7. Registre o preset testado e o resultado em `loops/preset-quality-state.md`.

## Estados de parada
- **sucesso:** Todos os presets e perfis identificados foram testados e passaram no check de logs.
- **sem-progresso:** 2 voltas sem conseguir corrigir um erro de sincronização.
- **bloqueado:** Crash no engine que impede a execução de novos testes.
- **esgotado:** atingiu 20 turnos.

## Guardrails
- Teto: 20 turnos.
- Aprovação humana antes de: Alterações estruturais no `AudioEngineManager` que alterem o grafo de áudio.

## Memória / estado
`loops/preset-quality-state.md` (Lista de presets testados, status de cada um e correções aplicadas).

## Por que funciona
Ao basear a parada em logs reais do sistema (`Check externo`) em vez de suposições do agente, evita-se o "auto-engano". A iteração "um por um" garante que casos de borda (como presets `nil`) sejam validados individualmente.

## Como acionar
Loop curto/médio (cabe no contexto) — comando `/goal`:
> /goal Use o loop preset-quality-loop. Continue até que todos os presets e perfis do app sejam validados via logs de sincronização, sem erros no transcript. Pare e me chame se encontrar um crash impossível de resolver ou após 20 turnos.

## Métrica de saúde
custo por mudança aceita = tokens / nº de presets validados com sucesso.
