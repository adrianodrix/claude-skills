# Claude Skills

Custom Claude Code skills (user-scope commands) for autonomous development workflows.

## Skills

| Skill | Description |
|-------|-------------|
| `yolo-sprint` | Executa todas as stories `ready-for-dev` em sequência: dev-story → code-review → fix → lint/build → commit → push → close issue. Sem paradas, sem confirmações. |
| `create-story-issues` | Gera story files em lote via BMAD create-story e espelha no GitHub (Milestone > Epic Issues > Story Sub-issues) |

## Installation

Copy the `.md` files to your Claude Code user commands directory:

```bash
cp *.md ~/.claude/commands/
```

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
