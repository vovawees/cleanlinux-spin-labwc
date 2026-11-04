# Как участвовать

**cleanlinux-spin-labwc** — сборка CleanLinux с labwc, часть [CleanLinux](https://github.com/vovawees/CleanLinux). *English [below](#english).*

## С чего начать

- Что входит в базу, а что ставится сверху — [SCOPE.md](https://github.com/vovawees/CleanLinux/blob/main/docs/SCOPE.md); как всё устроено — [ARCHITECTURE.md](https://github.com/vovawees/CleanLinux/blob/main/docs/ARCHITECTURE.md).
- Что дальше — [ROADMAP.md](https://github.com/vovawees/CleanLinux/blob/main/docs/ROADMAP.md), issues с меткой `roadmap` и общая доска [CleanLinux roadmap](https://github.com/users/vovawees/projects/1).
- Крупную правку сначала обсудите в issue, чтобы не делать работу дважды.

## Проверки

Хостингового CI нет: проверки запускаются локально, одной командой (нужен shellcheck 0.11 или новее).

`tools/check.sh` — shellcheck, `tools/lint.sh --fetch --base …`: имена пакетов сверяются с рецептами базы, исходники скачиваются и проверяются по sha256.

Быстрые проверки можно запускать автоматически перед каждым `git push`:

```sh
git config core.hooksPath tools/hooks   # перед push: tools/check.sh --quick
```

## Правила

- Сборка ставится поверх базы и не меняет её: свои рецепты — категории `extra`, настройки — пакетом `labwc-spin` ([SPINS.md](https://github.com/vovawees/CleanLinux/blob/main/docs/SPINS.md)).
- Пакет нужен базе вообще (Wayland, PipeWire, шрифтовый стек)? Тогда он идёт в CleanLinux-Recipes, а не сюда.

## Коммиты и pull request'ы

- Одна логическая правка — один коммит. Сообщение — на английском, в стиле истории: `область: что изменилось`
  (`bootstrap: …`, `docs: …`), подробности — в теле письма.
- Ветка от `main`, pull request в `main`; `Closes #N` (или `Closes vovawees/CleanLinux#N`) закрывает issue при слиянии.
- Документация меняется в том же pull request'е, что и поведение.

## English

cleanlinux-spin-labwc is part of [CleanLinux](https://github.com/vovawees/CleanLinux). There is no hosted CI: run `tools/check.sh` (shellcheck 0.11+)
before every push (`git config core.hooksPath tools/hooks` runs the quick checks automatically). A spin goes on top of the base and never changes it: own recipes use `category=extra`, settings live in the settings package; anything the base needs in general belongs to CleanLinux-Recipes.
Commit messages are in English (`area: what changed`); pull requests target `main`, and `Closes #N` closes the issue.
See the [roadmap](https://github.com/vovawees/CleanLinux/blob/main/docs/ROADMAP.md) and the [project board](https://github.com/users/vovawees/projects/1).
