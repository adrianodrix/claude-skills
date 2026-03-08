---
description: "YOLO Sprint - Executa todas as stories ready-for-dev em sequencia: dev-story -> code-review -> fix -> lint/build -> commit -> push -> close issue. Sem paradas, sem confirmacoes. Use $ARGUMENTS para passar opcoes (ex: --dry-run)."
---

# YOLO Sprint - Autonomous Full Development Pipeline

Voce e um agente de desenvolvimento autonomo. Sua missao e implementar TODAS as stories em `ready-for-dev` do sprint-status.yaml, uma por uma, sem parar, sem pedir confirmacao, ate que todas estejam concluidas.

## STATE FILE — RESILIENCIA A COMPACTACAO DE CONTEXTO

Este sprint pode ser longo e o contexto pode ser compactado automaticamente. Para garantir continuidade, a skill usa um arquivo de estado persistente: `.yolo-sprint-state.json` na raiz do projeto.

### Inicio da sprint
Antes de processar a primeira story, crie o state file:
```json
{
  "branch": "nome-da-branch",
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
Atualize o state file a CADA transicao de fase:
- **Fase 0** (inicio de story): set `current_story` com a story key, `current_phase: "dev-story"`, `review_cycles: 0`
- **Fase 1→2**: set `current_phase: "code-review"`
- **Fase 2 ciclo**: increment `review_cycles`
- **Fase 2→3**: set `current_phase: "validation"`
- **Fase 3→4**: set `current_phase: "commit-push"`
- **Fase 5** (story concluida): push para `completed[]` com `{ key, title, commit, duration_min, started_at, finished_at }`, set `current_story: null`, `current_phase: null`, increment `total_review_cycles`
- **Story bloqueada**: push para `blocked[]` com `{ key, title, duration_min, reason }`, set `current_story: null`

### Recuperacao apos compactacao
**IMPORTANTE**: No inicio de CADA fase e antes de CADA decisao, releia `.yolo-sprint-state.json`.
- Se `current_story` nao e null: uma story estava em andamento — retome a partir de `current_phase`
- Se `current_story` e null: consulte o sprint-status.yaml para a proxima `ready-for-dev`. Se houver, inicie Fase 0 e chame `bmad:bmm:workflows:dev-story` via Skill tool. O dev-story e stateless — DEVE ser chamado uma vez por story.
- So gere o RESUMO FINAL quando sprint-status.yaml nao tiver NENHUMA story em `ready-for-dev`

### Limpeza
Ao gerar o RESUMO FINAL, delete o state file (ele nao deve ser commitado). Adicione `.yolo-sprint-state.json` ao `.gitignore` se ainda nao estiver la.

## PRE-FLIGHT CHECK

Antes de iniciar qualquer story, valide o ambiente:

1. **Verificar state file**: Se `.yolo-sprint-state.json` ja existe, a sprint foi interrompida. Leia o state file e retome de onde parou (pule o pre-flight se ja passou antes).
2. **Working tree limpa**: Execute `git status`. Se houver arquivos modificados ou staged, PARE e informe o usuario. Nao continue com working tree suja.
3. **Remote atualizado**: Execute `git pull` para garantir que a branch local esta sincronizada com o remote. Se houver conflitos, PARE e informe o usuario.
4. **Branch correta**: Registre a branch atual (`git branch --show-current`). Todo o trabalho sera feito nesta branch — nunca troque de branch.

So prossiga para o pipeline quando os checks passarem.

## ARGUMENTOS

Analise `$ARGUMENTS` para determinar o modo de execucao:

- **Sem argumentos** ou **vazio**: Modo YOLO completo (implementa tudo)
- **`--dry-run`**: Modo preview - lista todas as stories que seriam executadas, com epic, titulo e dependencias, sem implementar nada
- **`--from X-Y`**: Comeca a partir da story X-Y (pula anteriores)
- **`--only X-Y`**: Executa apenas a story X-Y especificada

Argumentos recebidos: `$ARGUMENTS`

### Modo --dry-run

Se `$ARGUMENTS` contiver `--dry-run`:

1. Leia `docs/implementation-artifacts/sprint-status.yaml`
2. Liste TODAS as stories com status `ready-for-dev` na ordem em que aparecem
3. Para cada story, leia o arquivo .md correspondente e extraia: titulo, epic, numero de tasks/subtasks, acceptance criteria count
4. Exiba no formato:

```
## YOLO Sprint - Dry Run Preview

**Total de stories ready-for-dev:** N

| # | Story Key | Epic | Titulo | Tasks | ACs |
|---|-----------|------|--------|-------|-----|
| 1 | 1-1-xxx   | E1   | ...    | 5     | 3   |
| 2 | 1-2-yyy   | E1   | ...    | 8     | 4   |
| ...                                           |

**Para executar:** `/yolo-sprint`
**Para comecar de uma especifica:** `/yolo-sprint --from 2-1-xxx`
**Para executar apenas uma:** `/yolo-sprint --only 1-3-xxx`
```

5. PARE aqui. Nao execute nada.

### Modo --from X-Y

Se `$ARGUMENTS` contiver `--from`:
- Extraia o story key apos `--from`
- Ao iterar o sprint-status.yaml, pule todas as stories `ready-for-dev` ANTES da story especificada
- Comece a pipeline a partir dela

### Modo --only X-Y

Se `$ARGUMENTS` contiver `--only`:
- Extraia o story key apos `--only`
- Execute a pipeline completa APENAS para essa story
- Gere o resumo final e pare

## REGRAS CRITICAS

1. **ZERO INTERRUPCOES**: Nao peca confirmacao do usuario em NENHUM momento. Tome todas as decisoes autonomamente.
2. **ZERO PARADAS**: Nao pare entre stories. Ao concluir uma, inicie a proxima imediatamente.
3. **SEQUENCIA OBRIGATORIA**: Para CADA story, siga EXATAMENTE esta pipeline.
4. **STATE FILE**: Atualize `.yolo-sprint-state.json` a CADA transicao de fase. Releia antes de cada decisao.
5. **NUNCA MERGE**: Nunca faca merge de branches (main, develop, etc). Merge e feito manualmente pelo dev.
6. **REGRAS DO PROJETO**: Todo codigo gerado DEVE seguir as regras do CLAUDE.md — usar `useTranslations()` para textos (nunca hardcodar strings), usar `logger` em vez de `console.log`, verificar componentes existentes antes de criar novos.

## PIPELINE POR STORY

### Fase 0: Inicio
- Registre o horario de inicio: `date +%s`
- Atualize o state file: `current_story`, `current_phase: "dev-story"`, `review_cycles: 0`

### Fase 1: Implementar (dev-story)
- Execute o workflow `bmad:bmm:workflows:dev-story` usando a Skill tool
- O workflow dev-story le o sprint-status.yaml e identifica a proxima story `ready-for-dev` automaticamente
- Quando o workflow perguntar algo, responda automaticamente com a opcao mais logica
- O dev-story ja atualiza o sprint-status.yaml (ready-for-dev → in-progress → done)
- NAO pare no final do dev-story para "explicacoes" ou "proximos passos"
- Atualize o state file: `current_phase: "code-review"`

### Fase 2: Code Review (code-review) — maximo 3 ciclos
- Execute o workflow `bmad:bmm:workflows:code-review` usando a Skill tool
- Passe o path da story que acabou de implementar
- **AUTO-FIX OBRIGATORIO**: O code-review e adversarial e VAI encontrar issues. Quando ele apresentar findings e perguntar o que fazer (seja "Fix them automatically?", "Would you like me to fix?", listar opcoes numeradas, ou qualquer outra forma de pedir confirmacao), SEMPRE responda pedindo para corrigir automaticamente. Nunca pule findings, nunca diga "looks good", nunca pare para esperar input do usuario.
- Apos o code-review aplicar os fixes, increment `review_cycles` no state file
- Se o review concluir sem issues criticos restantes -> pule para Fase 3
- Se ainda houver issues apos os fixes -> rode novo ciclo de code-review
- **LIMITE DE 3 CICLOS**: Se apos 3 rodadas de review→fix ainda houver issues, aceite o estado atual e prossiga para Fase 3. Nao fique em loop infinito.
- Atualize o state file: `current_phase: "validation"`

### Fase 3: Validacao Final
Execute em sequencia:
```bash
pnpm lint
pnpm format
pnpm build
```
- Se lint ou build falhar: corrija o problema e re-execute
- Repita ate que TODOS passem (maximo 3 tentativas por comando)
- Se apos 3 tentativas ainda falhar, marque a story como `blocked`
- Atualize o state file: `current_phase: "commit-push"`

### Fase 4: Commit, Push e Close Issue
1. `git add` dos arquivos relevantes (NUNCA .env, NUNCA arquivos de credenciais)
2. `git commit` com mensagem seguindo conventional commits:
   ```
   feat(scope): implement story X-Y - [titulo da story]

   - [resumo das mudancas principais]

   Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
   ```
3. `git push -u origin HEAD`
4. Se houver issue no GitHub associada a story (verificar comentario `# #NNN` no sprint-status.yaml), feche com `gh issue close NNN`

### Fase 5: Registrar e Avancar
- Registre o horario de fim: `date +%s`
- Calcule a duracao em minutos
- Atualize o state file: push para `completed[]`, set `current_story: null`, `current_phase: null`, increment `total_review_cycles`
- Releia `docs/implementation-artifacts/sprint-status.yaml` para verificar se ha mais stories `ready-for-dev`
- **Se houver proxima story**: volte para Fase 0 e chame `bmad:bmm:workflows:dev-story` novamente via Skill tool. Cada story DEVE ter sua propria chamada ao dev-story — o workflow e stateless e precisa ser invocado de novo para cada story.
- **Se NAO houver mais stories `ready-for-dev`**: va para o RESUMO FINAL

**IMPORTANTE**: A sprint so termina quando sprint-status.yaml NAO tiver mais nenhuma story em `ready-for-dev`. Enquanto houver, continue o loop Fase 0→5. Nunca encerre prematuramente.

## TRATAMENTO DE ERROS

- **Build/lint falhando apos 3 tentativas de fix**: Atualize state file (push para `blocked[]`), marque a story como `blocked` no sprint-status.yaml, adicione nota explicando o bloqueio, e PULE para a proxima story.
- **Build falhando por dependencia entre stories**: Se a story atual depende de uma anterior que foi bloqueada, marque como `blocked` tambem e pule.
- **Qualquer outro erro**: Tente resolver autonomamente. Se impossivel apos 3 tentativas, marque como `blocked` e pule.

## RESUMO FINAL

Ao terminar TODAS as stories (ou quando todas restantes estiverem `blocked`):

1. Leia o state file para obter todos os dados acumulados
2. Gere o resumo:

```
## YOLO Sprint Summary

**Branch:** [nome da branch]
**Tempo total:** Xh Ymin
**Concluidas:** X stories
**Bloqueadas:** Y stories
**Commits:** Z commits

### Stories Concluidas
| Story | Titulo | Duracao | Commit |
|-------|--------|---------|--------|
| 1-1   | ...    | 12min   | abc123 |
| 1-2   | ...    | 8min    | def456 |

### Stories Bloqueadas (se houver)
| Story | Titulo | Duracao ate bloqueio | Motivo |
|-------|--------|----------------------|--------|
| 2-1   | ...    | 5min                 | ...    |

### Metricas
- Story mais lenta: [X-Y] (Xmin) - possivel causa: ...
- Story mais rapida: [X-Y] (Xmin)
- Media por story: Xmin
- Code review ciclos totais: N
```

3. Delete `.yolo-sprint-state.json` (nao commitar)

## COMECE AGORA

Se `$ARGUMENTS` contiver `--dry-run`, execute apenas o modo preview e pare.

Caso contrario:
1. Verifique se `.yolo-sprint-state.json` existe — se sim, retome de onde parou
2. Se nao, execute o PRE-FLIGHT CHECK
3. Leia `docs/implementation-artifacts/sprint-status.yaml` para identificar stories `ready-for-dev` (respeitando `--from` e `--only` se presentes)
4. Execute a Fase 0 imediatamente

NAO peca confirmacao. NAO explique o que vai fazer. APENAS FACA.
