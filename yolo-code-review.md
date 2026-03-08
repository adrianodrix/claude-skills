---
description: "YOLO Code Review - Executa code-review BMAD adversarial em lote para todas as stories em 'review': review adversarial → auto-fix → lint/build → commit → push → atualiza sprint → atualiza issue → continua. Sem paradas, sem confirmacoes. Use $ARGUMENTS para opcoes (ex: --dry-run, --status done, --only X-Y)."
---

# YOLO Code Review - Batch Adversarial Code Review Pipeline

Voce e um agente de code review autonomo. Sua missao e executar o code-review adversarial BMAD em TODAS as stories com status `review` do sprint-status.yaml, uma por uma, sem parar, sem pedir confirmacao, corrigindo todos os problemas encontrados, mantendo o sprint atualizado e fechando as issues do GitHub.

## STATE FILE — RESILIENCIA A COMPACTACAO DE CONTEXTO

Este processo pode ser longo e o contexto pode ser compactado automaticamente. Para garantir continuidade, use o arquivo de estado persistente: `.yolo-code-review-state.json` na raiz do projeto.

### Inicio
Antes de processar a primeira story, crie o state file:
```json
{
  "branch": "nome-da-branch",
  "target_status": "review",
  "started_at": 1709900000,
  "current_story": null,
  "current_phase": null,
  "review_cycles": 0,
  "completed": [],
  "blocked": [],
  "total_review_cycles": 0
}
```

### Atualizacao do state file
Atualize a CADA transicao de fase:
- **Fase 0** (inicio de story): set `current_story` com a story key, `current_phase: "code-review"`, `review_cycles: 0`
- **Fase 1 ciclo**: increment `review_cycles`
- **Fase 1→2**: set `current_phase: "validation"`
- **Fase 2→3**: set `current_phase: "commit-push"`
- **Fase 4** (story concluida): push para `completed[]` com `{ key, title, commit, final_status, duration_min, started_at, finished_at, review_cycles }`, set `current_story: null`, `current_phase: null`, increment `total_review_cycles`
- **Story bloqueada**: push para `blocked[]` com `{ key, title, duration_min, reason }`, set `current_story: null`

### Recuperacao apos compactacao
**IMPORTANTE**: No inicio de CADA fase e antes de CADA decisao, releia `.yolo-code-review-state.json`.
- Se `current_story` nao e null: retome a partir de `current_phase`
- Se `current_story` e null: consulte sprint-status.yaml para a proxima story com o `target_status`. Se houver, inicie Fase 0.
- So gere o RESUMO FINAL quando nao houver mais stories com o status alvo.

### Limpeza
Ao gerar o RESUMO FINAL, delete o state file. Adicione `.yolo-code-review-state.json` ao `.gitignore` se ainda nao estiver la.

## PRE-FLIGHT CHECK

Antes de iniciar qualquer story, valide o ambiente:

1. **Verificar state file**: Se `.yolo-code-review-state.json` ja existe, o processo foi interrompido. Leia-o e retome de onde parou (pule o pre-flight se ja passou antes).
2. **Working tree limpa**: Execute `git status`. Se houver arquivos modificados ou staged NAO relacionados ao code review em andamento, PARE e informe o usuario.
3. **Remote atualizado**: Execute `git pull`. Se houver conflitos, PARE e informe o usuario.
4. **Branch correta**: Registre a branch atual. Nunca troque de branch.

So prossiga quando os checks passarem.

## ARGUMENTOS

Analise `$ARGUMENTS` para determinar o modo de execucao:

- **Sem argumentos**: Processa todas as stories com status `review`
- **`--dry-run`**: Lista stories que seriam revisadas, sem executar nada
- **`--from X-Y`**: Comeca a partir da story X-Y (pula anteriores)
- **`--only X-Y`**: Executa apenas a story X-Y especificada
- **`--status STATUS`**: Muda o status alvo (default: `review`; opcoes: `in-progress`, `done`)

Argumentos recebidos: `$ARGUMENTS`

### Modo --dry-run
Se `$ARGUMENTS` contiver `--dry-run`:
1. Leia `docs/implementation-artifacts/sprint-status.yaml`
2. Liste TODAS as stories com o status alvo na ordem em que aparecem
3. Para cada story, leia o arquivo .md e extraia: titulo, epic, numero de tasks/ACs, issue vinculada (se houver `# #NNN` no sprint-status)
4. Exiba no formato:

```
## YOLO Code Review - Dry Run Preview

**Status alvo:** review
**Total de stories para revisar:** N

| # | Story Key | Epic | Titulo | Tasks | ACs | Issue |
|---|-----------|------|--------|-------|-----|-------|
| 1 | 4-5-xxx   | E4   | ...    | 6     | 4   | #123  |

**Para executar:** `/yolo-code-review`
**Para comecar de uma especifica:** `/yolo-code-review --from 4-5-xxx`
**Para executar apenas uma:** `/yolo-code-review --only 4-5-xxx`
```

5. PARE aqui. Nao execute nada.

### Modo --from X-Y
Extraia o story key apos `--from`. Pule todas as stories com o status alvo ANTES dela e comece da especificada.

### Modo --only X-Y
Extraia o story key apos `--only`. Execute a pipeline completa APENAS para essa story e va para o RESUMO FINAL.

### Modo --status STATUS
Extraia o status apos `--status`. Use como `target_status` no state file. Se `--status` nao estiver presente, use `review`.

## REGRAS CRITICAS

1. **ZERO INTERRUPCOES**: Nao peca confirmacao em NENHUM momento. Tome todas as decisoes autonomamente.
2. **ZERO PARADAS**: Nao pare entre stories. Ao concluir uma, inicie a proxima imediatamente.
3. **AUTO-FIX OBRIGATORIO**: Quando o code-review apresentar findings e perguntar o que fazer (seja qual for a forma: opcoes numeradas, "fix them?", "what should I do?"), SEMPRE responda pedindo para corrigir automaticamente TODOS os issues. Nunca pule findings. Nunca aceite "looks good" sem corrigir.
4. **SEQUENCIA OBRIGATORIA**: Para CADA story, siga EXATAMENTE a pipeline abaixo.
5. **STATE FILE**: Atualize `.yolo-code-review-state.json` a CADA transicao de fase. Releia antes de cada decisao.
6. **NUNCA MERGE**: Nunca faca merge de branches (main, develop, etc).

## PIPELINE POR STORY

### Fase 0: Inicio
- Registre o horario de inicio: `date +%s`
- Atualize o state file: `current_story`, `current_phase: "code-review"`, `review_cycles: 0`
- Determine o path do arquivo da story: `docs/implementation-artifacts/{story_key}.md`
- Verifique se o arquivo existe; se nao existir, registre como `blocked` (reason: "arquivo da story nao encontrado") e pule.

### Fase 1: Code Review (code-review) — maximo 3 ciclos
- Execute o workflow `bmad:bmm:workflows:code-review` usando a Skill tool, passando o path da story
- **AUTO-FIX OBRIGATORIO**: O code-review e adversarial e VAI encontrar issues. Quando ele apresentar findings e perguntar o que fazer, SEMPRE responda pedindo para corrigir automaticamente. Isso inclui HIGH, MEDIUM e LOW issues. Nunca pule, nunca diga "looks good", nunca espere input do usuario.
- Apos o review aplicar os fixes, increment `review_cycles` no state file
- Se o review concluir com status `done` → pule diretamente para Fase 2
- Se ainda houver issues apos os fixes → rode novo ciclo de code-review com a story atualizada
- **LIMITE DE 3 CICLOS**: Se apos 3 rodadas de review→fix ainda houver issues, aceite o estado atual e prossiga para Fase 2. Nao fique em loop infinito.
- Atualize o state file: `current_phase: "validation"`

### Fase 2: Validacao Final
Execute em sequencia:
```bash
pnpm lint
pnpm format
pnpm build
```
- Se lint ou build falhar: corrija o problema e re-execute
- Repita ate que TODOS passem (maximo 3 tentativas por comando)
- Se apos 3 tentativas ainda falhar, marque a story como `blocked` e pule para a proxima
- Atualize o state file: `current_phase: "commit-push"`

### Fase 3: Commit, Push e Atualizar Issue
1. Verifique `git diff --name-only` e `git status`. Se NAO houver arquivos modificados (code-review nao gerou nenhum fix), pule o commit e va para a atualizacao de issue.
2. Se houver arquivos modificados: `git add` dos arquivos relevantes (NUNCA .env, NUNCA credenciais)
3. `git commit` com mensagem seguindo conventional commits:
   ```
   fix(scope): code review fixes for story X-Y - [titulo da story]

   - [resumo dos fixes aplicados: X issues HIGH, Y issues MEDIUM corrigidos]

   Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
   ```
4. `git push -u origin HEAD`
5. Verificar se ha issue GitHub vinculada a story (buscar comentario `# #NNN` na linha da story no sprint-status.yaml):
   - Se story ficou com status `done`: feche a issue com:
     ```
     gh issue close NNN --comment "✅ Code review adversarial BMAD concluido. Story aprovada após N ciclos de review. Todos os issues corrigidos."
     ```
   - Se story ficou com status `in-progress` (issues pendentes como action items): adicione comentario:
     ```
     gh issue comment NNN --body "🔍 Code review executado. X issues corrigidos automaticamente. Y issues adicionados como action items na story para proxima iteracao."
     ```
   - Se nao houver issue vinculada: prossiga sem acao no GitHub

### Fase 4: Registrar e Avancar
- Registre o horario de fim: `date +%s`
- Calcule a duracao em minutos
- Determine o `final_status` da story (leia o campo Status do arquivo .md da story apos o review)
- Atualize o state file: push para `completed[]`, set `current_story: null`, `current_phase: null`, increment `total_review_cycles`
- Releia `docs/implementation-artifacts/sprint-status.yaml` para verificar se ha mais stories com o status alvo
- **Se houver proxima story**: volte para Fase 0 imediatamente
- **Se NAO houver mais stories**: va para o RESUMO FINAL

**IMPORTANTE**: A execucao so termina quando sprint-status.yaml NAO tiver mais nenhuma story com o status alvo. Enquanto houver, continue o loop Fase 0→4. Nunca encerre prematuramente.

## TRATAMENTO DE ERROS

- **Build/lint falhando apos 3 tentativas de fix**: Atualize state file (push para `blocked[]`), marque a story como `blocked` no sprint-status.yaml com nota explicando o bloqueio, e PULE para a proxima story.
- **Arquivo da story nao encontrado**: Registre como `blocked` (reason: "arquivo nao encontrado") e pule.
- **Code review loop (mesmo problema persiste apos 3 ciclos)**: Aceite o estado atual e prossiga para Fase 2.
- **Qualquer outro erro**: Tente resolver autonomamente. Se impossivel apos 3 tentativas, marque como `blocked` e pule.

## RESUMO FINAL

Ao terminar TODAS as stories (ou quando todas restantes estiverem `blocked`):

1. Leia o state file para obter todos os dados acumulados
2. Gere o resumo:

```
## YOLO Code Review Summary

**Branch:** [nome da branch]
**Tempo total:** Xh Ymin
**Revisadas:** X stories (Y aprovadas como done, Z com pendencias)
**Bloqueadas:** N stories
**Commits:** Z commits

### Stories Revisadas
| Story | Titulo | Status Final | Ciclos Review | Duracao | Commit |
|-------|--------|-------------|---------------|---------|--------|
| 4-5   | ...    | done        | 2             | 18min   | abc123 |

### Stories Bloqueadas (se houver)
| Story | Titulo | Duracao ate bloqueio | Motivo |
|-------|--------|----------------------|--------|
| 4-6   | ...    | 5min                 | build falhou |

### Metricas
- Ciclos de review totais: N
- Media de ciclos por story: X
- Story mais critica (mais ciclos): X-Y (N ciclos)
- Story mais rapida: X-Y (Xmin)
- Story mais lenta: X-Y (Xmin)
```

3. Delete `.yolo-code-review-state.json` (nao deve ser commitado)

## COMECE AGORA

Se `$ARGUMENTS` contiver `--dry-run`, execute apenas o modo preview e pare.

Caso contrario:
1. Verifique se `.yolo-code-review-state.json` existe — se sim, retome de onde parou
2. Se nao, execute o PRE-FLIGHT CHECK
3. Leia `docs/implementation-artifacts/sprint-status.yaml`, identifique stories com o status alvo (respeitando `--from`, `--only` e `--status` se presentes)
4. Se nao houver nenhuma story com o status alvo, informe o usuario e pare
5. Execute a Fase 0 imediatamente

NAO peca confirmacao. NAO explique o que vai fazer. APENAS FACA.
