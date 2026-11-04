# cleanlinux-spin-labwc

Сборка (spin) [CleanLinux](https://github.com/vovawees/CleanLinux) с [labwc](https://labwc.github.io/) —
лёгким стековым Wayland-композитором в духе Openbox на wlroots. Терминал — [foot](https://codeberg.org/dnkl/foot),
шрифты — DejaVu, звук — PipeWire + WirePlumber из базы. Только Wayland: без Xwayland (`SPIN_FEATURES="wayland -x11"`).

Формат сборок и контракт с базой — [docs/SPINS.md](https://github.com/vovawees/CleanLinux/blob/main/docs/SPINS.md);
начать свою — с [cleanlinux-spin-template](https://github.com/vovawees/cleanlinux-spin-template).

## Что ставит

| Пакет | Откуда | Что |
|---|---|---|
| `labwc` 0.20.3, `wlroots` 0.20.2 | рецепты сборки | композитор: DRM/KMS, libinput, рендереры GLES2 (Mesa) и pixman |
| `foot` 1.28.0, `fcft` 3.3.3, `tllist` 1.1.0 | рецепты сборки | терминал (`TERM=foot`, terminfo — из ncurses базы) |
| `dejavu-fonts` 2.37 | рецепт сборки | шрифты DejaVu Sans, Serif, Sans Mono |
| `labwc-spin` | рецепт сборки | настройки: `/etc/xdg/labwc/{rc.xml,menu.xml,environment}`, подсказка в консоли |
| `pipewire`, `wireplumber`, `seatd`, `turnstile`, `dbus`, `mesa`, `cairo`, `pango`, … | база (platform) | звук, место, пользовательские сервисы, графика, текст |

Сервисы: системные `dbus`, `seatd`, `turnstiled`; у каждого пользователя (`dinit --user` через turnstile) —
`dbus` (сессионная шина), `pipewire`, `wireplumber`.

## Установка

```sh
sudo burn spin add https://github.com/vovawees/cleanlinux-spin-labwc
usermod -aG seat <пользователь>      # от root: место (seatd) — у группы seat; затем войти заново
```

Войти в текстовую консоль и набрать `labwc`. Super+Return — терминал, правый клик по столу — меню,
Alt+Tab — окна. Свои настройки — `~/.config/labwc/` (заменяют `/etc/xdg/labwc/`), раскладка — в `environment`
(`XKB_DEFAULT_LAYOUT=us,ru`). Без 3D-ускорения (виртуальные машины) — `WLR_RENDERER=pixman` там же.

Обновляется вместе с базой: `burn sync && burn plan && burn update`. Удалить: `sudo burn spin remove labwc`.

Образ с этой сборкой собирает bootstrap базы:

```sh
bootstrap/bootstrap.sh --profile steam-deck --spin https://github.com/vovawees/cleanlinux-spin-labwc disk
```

## Проверка

```sh
tools/lint.sh --base ../CleanLinux-Recipes/packages   # spin.conf, рецепты, имена — из сборки или базы
tools/lint.sh --fetch                                 # скачать исходники и сверить sha256
```

## Лицензия

Рецепты и настройки — MIT. Пакеты — под своими лицензиями (`license=` в рецептах).
