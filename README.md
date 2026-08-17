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

Este projeto é um fork do [Noctalia Shell](https://github.com/noctalia-dev/noctalia-shell) (MIT), construído sobre [Quickshell](https://quickshell.org), e incorpora o motor visual Blob da [Caelestia Shell](https://github.com/caelestia-dots/shell) (GPLv3). Ver [`CREDITS.md`](./CREDITS.md) e [`LICENSES/`](./LICENSES/) para atribuições e termos dos componentes de origem.

## Licença

GPL-3.0-only — ver [LICENSE](./LICENSE). O código herdado do Noctalia conserva seus termos MIT em [`LICENSES/Noctalia-MIT.txt`](./LICENSES/Noctalia-MIT.txt); o escopo e a atribuição do porte Caelestia estão em [`LICENSES/Caelestia-Blob-Port.md`](./LICENSES/Caelestia-Blob-Port.md).
