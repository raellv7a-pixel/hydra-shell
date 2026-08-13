# Hydra Shell - Dependências do Sistema

Lista de pacotes de sistema que a **Hydra Shell** (incluindo o **Screen Toolkit**)
realmente invoca em tempo de execução — auditada em `Services/`, `Modules/` e
`Scripts/` (toda chamada `Process { command: [...] }`, `exec_cmd(...)` e
`command -v` do repositório), não apenas copiada de um empacotamento anterior.

**Fonte de verdade para automação:** `Scripts/bash/install.sh`. Este arquivo é a
versão legível para humanos da mesma lista; se os dois divergirem, o script
está certo — abra uma issue.

## Arch Linux / CachyOS (`pacman`) — obrigatórios

```bash
sudo pacman -S --needed \
    qt6-base qt6-declarative qt6-wayland qt6-shadertools qt6-multimedia qt6-svg qt6ct \
    hyprland \
    grim slurp hyprpicker wl-clipboard \
    tesseract tesseract-data-eng tesseract-data-por \
    imagemagick zbar curl ffmpeg jq gifski \
    python python-gobject \
    xdg-desktop-portal xdg-desktop-portal-hyprland xdg-desktop-portal-gtk \
    wf-recorder translate-shell adw-gtk-theme \
    brightnessctl ddcutil wlsunset cliphist wlr-randr wget playerctl \
    bluez bluez-utils networkmanager \
    pipewire pipewire-pulse pipewire-alsa wireplumber \
    polkit power-profiles-daemon udisks2 git \
    shelly shelly-flatpak-backend
```

## Arch Linux / CachyOS (`pacman`) — opcionais (funcionalidades específicas)

```bash
sudo pacman -S --needed \
    fastfetch evtest vulkan-tools waifu2x-ncnn-vulkan khal xorg-xcursorgen librsvg
```

## Motor Quickshell (`noctalia-qs`, binário `qs`/`quickshell`)

**Não existe pacote AUR para o `noctalia-qs`.** O único pacote AUR com "noctalia"
no nome é `noctalia-git`, que é o **Noctalia v5** — uma reescrita nativa C++/Meson
incompatível com esta shell (que roda em cima do Quickshell/QML, branch `legacy-v4`).
O caminho correto é compilar do código-fonte, como o próprio `nix/package.nix`
já faz sob Nix:

```bash
sudo pacman -S --needed \
    cmake ninja pkgconf cli11 vulkan-headers spirv-tools \
    libdrm cpptrace jemalloc wayland wayland-protocols libxcb glib2 pam base-devel

git clone --depth 1 https://github.com/noctalia-dev/noctalia-qs.git
cmake -S noctalia-qs -B noctalia-qs/build -GNinja \
    -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr/local
cmake --build noctalia-qs/build
sudo cmake --install noctalia-qs/build   # já cria /usr/local/bin/{quickshell,qs}
```

`Scripts/bash/install.sh` automatiza tudo isso e ainda cria
`/usr/bin/{quickshell,qs}` apontando para `/usr/local/bin/`, porque alguns
contextos de execução (systemd `--user`, greeters, o próprio ambiente `exec`
do Hyprland) não têm `/usr/local/bin` no `PATH`.

## AUR (via `paru`/`yay`)

```bash
paru -S --needed wl-screenrec-git papirus-folders
# Só em máquinas com GPU NVIDIA:
paru -S --needed nvibrant-bin
```

## Serviços de sistema que precisam estar habilitados

```bash
sudo systemctl enable --now NetworkManager.service bluetooth.service power-profiles-daemon.service
```

Sem isso, `BluetoothService.qml`, `NetworkService.qml`/`VPNService.qml` e
`PowerProfileService.qml` degradam graciosamente (funcionalidade indisponível),
mas não é a experiência "shell cuida de tudo" que o projeto pretende entregar.

## Detalhes das dependências opcionais

- **papirus-folders** (AUR): necessário apenas para o modelo "Papirus Folders" (Modelos de Cores → categoria System). Ativar esse modelo dispara um pedido de permissão via polkit **uma única vez** (`Scripts/bash/papirus-folders-setup.sh`) para conceder `sudo` sem senha só para esse binário — depois disso, a cor das pastas do Papirus é atualizada automaticamente a cada troca de wallpaper/esquema, sem prompts. Sem o pacote instalado, o modelo falha silenciosamente ao ser ativado (toast de erro avisa).
- **xorg-xcursorgen** (+ **librsvg**, provê `rsvg-convert`): necessário apenas para o fallback Xcursor do modelo "Cursor" (Modelos de Cores → categoria System). Sem eles, a shell ainda gera e aplica o tema hyprcursor (vetorial, formato nativo do Hyprland) normalmente — apenas apps XWayland/toolkits que não falam hyprcursor não verão o cursor adaptativo até o fallback estar disponível.
- **evtest**: necessário apenas para "Mostrar teclas pressionadas" (Configurações → OSD → Geral). A captura fica desligada por padrão porque lê eventos brutos de `/dev/input/eventN`; selecione o dispositivo correto e conceda acesso por grupo `input` ou regra udev consciente do risco. Sem o binário ou sem permissão, a shell não inicia a captura e mostra um aviso.
