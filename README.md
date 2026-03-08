# Claude Skills

Custom Claude Code skills, settings e statusline — versionados para restauração rápida em qualquer máquina.

## Conteúdo do Repositório

| Arquivo | Destino | Descrição |
|---------|---------|-----------|
| `*.md` (exceto README) | `~/.claude/commands/` | Skills (user-scope commands) |
| `settings.json` | `~/.claude/settings.json` | Configurações, hooks e plugins |
| `statusline-command.sh` | `~/.claude/statusline-command.sh` | Statusline estilo Powerline com cores dinâmicas |
| `sync.sh` | Este repo | Script de sync automático (hooks → commit → push) |

## Skills

| Skill | Descrição |
|-------|-----------|
| `yolo-sprint` | Executa todas as stories `ready-for-dev` em sequência: dev-story → code-review → fix → lint/build → commit → push → close issue. Sem paradas, sem confirmações. |
| `create-story-issues` | Gera story files em lote via BMAD create-story e espelha no GitHub (Milestone > Epic Issues > Story Sub-issues) |

## Statusline

Statusline estilo Powerline/Agnoster com segmentos coloridos:

```
 adriano ▸ SAG-front ▸ feature/fix-general ▸ Opus 4.6 ▸ ctx:24%
```

Cores dinâmicas:
- **Branch git**: verde (limpo) / amarelo (dirty — arquivos modificados, staged ou untracked)
- **Context window**: cinza (< 90%) / vermelho (≥ 90% — autocompact iminente)

## Restauração em Nova Máquina

### 1. Clonar o repositório

```bash
git clone git@github.com:adrianodrix/claude-skills.git ~/Projects/claude-skills
```

### 2. Restaurar arquivos

```bash
cd ~/Projects/claude-skills

# Criar diretório de commands se não existir
mkdir -p ~/.claude/commands

# Copiar skills
cp *.md ~/.claude/commands/
rm ~/.claude/commands/README.md  # não copiar o README como skill

# Copiar settings e statusline
cp settings.json ~/.claude/settings.json
cp statusline-command.sh ~/.claude/statusline-command.sh
```

### 3. Restauração automatizada (one-liner)

```bash
git clone git@github.com:adrianodrix/claude-skills.git ~/Projects/claude-skills \
  && cd ~/Projects/claude-skills \
  && mkdir -p ~/.claude/commands \
  && cp *.md ~/.claude/commands/ \
  && rm -f ~/.claude/commands/README.md \
  && cp settings.json ~/.claude/settings.json \
  && cp statusline-command.sh ~/.claude/statusline-command.sh \
  && echo "Restauração completa!"
```

### Dependências

- **jq** — usado pelo statusline para parsear o JSON de entrada
- **git** — usado pelo statusline para branch e status
- **Fonte Powerline** — recomendada para renderizar caracteres especiais no terminal (o statusline usa `▸` como fallback universal)

## Auto-Sync

O `settings.json` inclui hooks que disparam `sync.sh` automaticamente ao editar:
- Qualquer skill em `~/.claude/commands/*.md`
- `~/.claude/settings.json`
- `~/.claude/statusline-command.sh`

O sync copia os arquivos para este repo, commita e pusha.

## Usage

```bash
# Preview what would be executed
/yolo-sprint --dry-run

# Run full sprint
/yolo-sprint

# Run from a specific story
/yolo-sprint --from 4-3

# Run only one story
/yolo-sprint --only 4-1
```

## License

MIT
