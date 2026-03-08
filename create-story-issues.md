---
description: 'Gera story files em lote via BMAD create-story e espelha no GitHub (Milestone > Epic Issues > Story Sub-issues)'
---

# Skill: Create Story Issues

Gera arquivos de story completos via BMAD e cria a estrutura espelhada no GitHub.

## Pre-requisitos

Antes de iniciar, valide que existem:
1. Um arquivo `sprint-status.yaml` em `docs/implementation-artifacts/`
2. Um arquivo de epics (`docs/planning-artifacts/epics*.md`) correspondente ao modulo do sprint
3. Acesso ao GitHub via `gh` CLI autenticado

## Etapas

### Etapa 1: Descoberta e Contexto

1. Leia o `docs/implementation-artifacts/sprint-status.yaml` para identificar:
   - O nome do **modulo** (campo `module`)
   - Todas as stories com status `backlog`
   - A estrutura epic > stories

2. Identifique o arquivo de epics correto em `docs/planning-artifacts/` baseado no modulo do sprint-status.

3. Leia o arquivo de epics para extrair:
   - Nome de cada epic
   - Nome de cada story dentro de cada epic

4. Verifique quais stories **ja possuem arquivo** em `docs/implementation-artifacts/` (pattern: `*story-key*.md`). Pule stories que ja tem arquivo gerado.

5. Detecte o repositorio GitHub atual:
   ```bash
   gh repo view --json nameWithOwner -q '.nameWithOwner'
   ```

6. Detecte o usuario git atual:
   ```bash
   gh api user --jq '.login'
   ```

7. Apresente ao usuario um resumo do que sera criado:
   - Nome da milestone
   - Quantidade de epics e stories
   - Lista das stories que serao processadas
   - Pergunte: "Confirma a criacao? (s/n)"

### Etapa 2: Criar Milestone no GitHub

1. Verifique se a milestone ja existe:
   ```bash
   gh api repos/{owner}/{repo}/milestones --jq '.[] | select(.title == "{module}") | .number'
   ```

2. Se nao existir, crie:
   ```bash
   gh api repos/{owner}/{repo}/milestones -f title="{module}" -f state="open" -f description="Epic breakdown para o modulo {module}"
   ```

3. Guarde o `milestone_number` para uso nas issues.

### Etapa 3: Loop por Epic

Para cada epic que contenha stories em backlog:

#### 3a. Criar Issue do Epic

1. Verifique se a issue do epic ja existe (busque por titulo):
   ```bash
   gh issue list --search "epic({module}): {epic_title}" --json number,title --jq '.[0].number'
   ```

2. Se nao existir, crie a issue do epic:
   ```bash
   gh issue create \
     --title "epic({module}): {epic_title}" \
     --body "## Epic\n\n{epic_description}\n\n## FRs\n\n{frs_list}\n\n## Stories\n\n{stories_checklist}" \
     --label "epic,{module},backend" \
     --assignee "{git_user}" \
     --milestone "{module}"
   ```

3. Guarde o `epic_issue_number`.

#### 3b. Loop por Story do Epic

Para cada story em backlog (sem arquivo existente):

##### i. Gerar arquivo da story via BMAD

Invoque a skill BMAD create-story:
```
/bmad:bmm:workflows:create-story
```

IMPORTANTE: O create-story e interativo e pode fazer perguntas. Responda automaticamente baseado no contexto do epics file. O objetivo e modo YOLO - minima interacao.

Aguarde a conclusao e confirme que o arquivo foi gerado em `docs/implementation-artifacts/`.

##### ii. Criar Sub-issue no GitHub

```bash
gh issue create \
  --title "story({module}): {story_title}" \
  --body "## Story {epic_num}.{story_num}: {story_title}\n\nPart of #{epic_issue_number}\n\n### Acceptance Criteria\n\n{acceptance_criteria_from_epics}\n\n### Story File\n\n`docs/implementation-artifacts/{story_key}.md`" \
  --label "story,{module},backend" \
  --assignee "{git_user}" \
  --milestone "{module}"
```

Guarde o `story_issue_number`.

##### iii. Vincular sub-issue ao epic

```bash
gh issue edit {epic_issue_number} --add-sub-issue {story_issue_number}
```

##### iv. Atualizar arquivo da story com referencia da issue

No arquivo da story gerado, adicione logo apos a linha `Status:`:
```
GitHub Issue: #{story_issue_number}
```

##### v. Atualizar sprint-status.yaml

Altere o status da story de `backlog` para `ready-for-dev`.

##### vi. Log de progresso

Informe ao usuario:
```
[{current}/{total}] Story {story_key} criada
  - Arquivo: docs/implementation-artifacts/{story_key}.md
  - Issue: #{story_issue_number} (sub-issue de #{epic_issue_number})
```

### Etapa 4: Resumo Final

Apresente um resumo completo:

```
## Resumo da Criacao

Milestone: {module}
Repositorio: {owner}/{repo}

### Epics criados: {count}
| Epic | Issue | Stories |
|------|-------|---------|
| {epic_title} | #{epic_issue_number} | {story_count} |

### Stories criadas: {count}
| Story | Issue | Epic | Arquivo |
|-------|-------|------|---------|
| {story_title} | #{story_issue_number} | #{epic_issue_number} | {file_path} |

### Proximos passos
- Execute `/bmad:bmm:workflows:dev-story` para implementar cada story
- Execute `/bmad:bmm:workflows:code-review` apos cada implementacao
- Ao finalizar a issue, use `gh issue close #{number}` com referencia ao PR
```

## Regras

- NUNCA crie issues duplicadas. Sempre verifique se ja existem antes de criar.
- Se uma story ja tem arquivo em `docs/implementation-artifacts/`, pule o create-story mas ainda crie a issue no GitHub se nao existir.
- Se o `gh` CLI falhar, pare e informe o erro. Nao tente continuar sem GitHub.
- Labels seguem o padrao do CLAUDE.md: tipo (`epic` ou `story`) + modulo + camada (`backend`).
- Assignee: usuario atual do git.
- Milestone: nome do modulo do sprint-status.yaml.
- Todas as issues sao criadas no repositorio atual (origin).
