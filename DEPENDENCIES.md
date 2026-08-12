# Hydra Shell - Dependências do Sistema

Lista de pacotes do sistema necessários para a **Hydra Shell** (incluindo o módulo nativo **Screen Toolkit**).
Esses pacotes devem ser instalados pelo script de instalação no futuro.

## Arch Linux / CachyOS (`pacman`)

```bash
sudo pacman -S --needed \
    qt6-declarative \
    qt6-wayland \
    qt6-shadertools \
    qt6-multimedia \
    cli11 \
    vulkan-headers \
    spirv-tools \
    grim \
    slurp \
    hyprpicker \
    wl-clipboard \
    tesseract \
    tesseract-data-eng \
    tesseract-data-por \
    imagemagick \
    zbar \
    curl \
    ffmpeg \
    jq \
    python \
    python-gobject \
    xdg-desktop-portal \
    wf-recorder \
    translate-shell \
    adw-gtk-theme
## Links Simbólicos Globais
Para garantir a inicialização automática em qualquer gerenciador de login (Display Manager / SDDM / GDM / greetd):
```bash
sudo ln -sf /usr/local/bin/quickshell /usr/bin/quickshell
sudo ln -sf /usr/local/bin/qs /usr/bin/qs
```
```

## Resumo dos Recursos por Pacote
- **qt6-declarative, qt6-wayland, qt6-shadertools, cli11**: Compilação do motor `noctalia-qs` (`qs`).
- **grim & slurp**: Captura de tela e seleção de região.
- **hyprpicker**: Seletor de cores da tela (Color Picker).
- **wl-clipboard**: Manipulação da área de transferência Wayland (`wl-copy` / `wl-paste`).
- **tesseract & tesseract-data-eng/por**: Leitor de texto em imagens (OCR com suporte a EN/PT).
- **zbar**: Leitor de QR Code e código de barras (`zbarimg`).
- **imagemagick, ffmpeg, jq**: Manipulação de imagem, vídeo e manipulação de dados JSON.
- **wf-recorder**: Gravação de tela (GIF / MP4).
- **translate-shell**: Tradução de texto extraído via OCR.
- **python & python-gobject**: Suporte a seletores de arquivos do sistema.
- **adw-gtk-theme**: Tema GTK3 (`adw-gtk3`/`adw-gtk3-dark`) que responde aos overrides de cor (`@define-color`) gerados pelo Template Processor. Sem ele, apps GTK3 puros (nwg-look, cachyos-hello, etc.) caem no Adwaita mínimo embutido e ignoram as cores da shell — apps GTK4+libadwaita (Nautilus, ProtonPlus) não são afetados, pois usam as custom properties do `gtk4.css` diretamente.
