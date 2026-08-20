# hydra-shell

Fork pessoal e fortemente customizado do [Noctalia Shell](https://github.com/noctalia-dev/noctalia-shell) para **Hyprland**, com foco em zero fricção: a shell assume a configuração do Hyprland (atalhos, animações, regras de janela), cuida do primeiro login, e reinstala do zero com um comando.

---

## Instalação

Arch Linux / CachyOS, Hyprland já instalado, sessão já aberta:

```bash
curl -fsSL https://raw.githubusercontent.com/raellv7a-pixel/hydra-shell/legacy-v4/Scripts/bash/install.sh | bash
```

O instalador resolve todas as dependências (ver [`DEPENDENCIES.md`](./DEPENDENCIES.md)), compila o motor Quickshell (`noctalia-qs`), habilita os serviços de sistema necessários, instala a configuração do Hyprland — com backup do que já existir — e sobe a shell na hora, sem precisar deslogar.

---

## Atualizando de uma instalação pré-rebrand (Noctalia)

O estado em disco mudou de nome junto com a shell:

| Antes | Agora |
| --- | --- |
| `~/.config/noctalia` | `~/.config/hydra` |
| `~/.cache/noctalia` | `~/.cache/hydra` |
| `~/.config/hypr/noctalia` | `~/.config/hypr/hydra` |
| `NOCTALIA_*` (env) | `HYDRA_*` |

`Assets/Hyprland/modules/autostart.lua` roda
[`Scripts/bash/migrate-noctalia-config.sh`](./Scripts/bash/migrate-noctalia-config.sh)
antes de subir a shell: ele renomeia esses diretórios e reescreve as chaves de
marca em `settings.json` (`noctaliaPerformance`, `showNoctaliaPerformance`,
`followNoctaliaPerformanceMode`, widget `NoctaliaPerformance`, ícone `noctalia`,
esquema `Noctalia (default)`), guardando um backup `settings.json.pre-hydra.bak`.
É idempotente — rodar de novo não faz nada. Para migrar na hora, sem relogar:

```bash
~/.config/quickshell/hydra-shell/Scripts/bash/migrate-noctalia-config.sh
```

Os arquivos de tema já gerados dentro de configs de terceiros (kitty, foot,
alacritty, GTK…) mantêm o nome antigo até os templates serem aplicados de novo
(troque o esquema de cores ou rode `Scripts/bash/template-apply.sh`).

---


## O que é diferente do Noctalia

- **Configuração completa do Hyprland em Lua** (`Assets/Hyprland/`), com todos os atalhos já ligados à shell via IPC — nada para configurar na mão.
- **Screen Toolkit nativo**: anotação, OCR, leitor de QR/código de barras, seletor de cores, gravação de tela.
- **Widgets extras**: Tamagotchi de barra, controle do OBS, gerenciador de dispositivos USB, indicador de privacidade, OSD de teclas pressionadas.
- **Escopo reduzido a Hyprland** — o Noctalia upstream também suporta Niri, Sway, Scroll, Labwc e MangoWC; esta shell não.

---

## Requisitos

- Arch Linux ou derivada (CachyOS é o alvo testado)
- Hyprland ≥ 0.55 (a configuração usa o suporte nativo a Lua do compositor)
- Lista completa de dependências: [`DEPENDENCIES.md`](./DEPENDENCIES.md)

---

## Créditos

Este projeto é um fork do [Noctalia Shell](https://github.com/noctalia-dev/noctalia-shell) (MIT), construído sobre [Quickshell](https://quickshell.org). Ver [`CREDITS.md`](./CREDITS.md) para a lista completa de dependências e atribuições de terceiros.

## Licença

MIT — ver [LICENSE](./LICENSE).
