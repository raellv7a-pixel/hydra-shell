# hydra-shell

Fork pessoal e fortemente customizado do [Noctalia Shell](https://github.com/noctalia-dev/noctalia-shell). A integração nativa com **Umbriel** é o alvo atual; a configuração e o instalador legados do Hyprland ainda estão presentes durante a migração.

---

## Instalação

Arch Linux / CachyOS, com Umbriel já instalado, a partir de um checkout com
as alterações commitadas desta linha de desenvolvimento:

```bash
bash Scripts/bash/install.sh
```

O instalador usa a branch do checkout local quando executado dessa forma
(alterações não commitadas não são copiadas), instala as dependências sem
instalar Hyprland, provisiona as binds e mantém as opções existentes do
compositor. A Hydra é iniciada imediatamente numa sessão Umbriel ativa ou pelo
autostart idempotente no próximo login. O caminho legado de instalação
Hyprland continua disponível quando Umbriel não está instalado. O comando
remoto da branch `legacy-v4` só receberá este fluxo quando estas alterações
forem publicadas nessa branch.

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
- **Integração com Umbriel**: catálogo de atalhos da Hydra, ações nativas do compositor e editor com validação e gravação segura.

## Atalhos na sessão Umbriel

Na sessão Umbriel, a Hydra substitui as binds built-in por seu catálogo em
`Scripts/python/umbriel_keybinds.py`. No primeiro boot da shell, ela adiciona
`[include] files = ["hydra/keybinds.toml"]` a
`~/.config/umbriel/config.toml` sem alterar as demais opções; a configuração
gerada fica em `~/.config/umbriel/hydra/keybinds.toml` e os rebinds/custom binds
em `~/.config/umbriel/hydra/keybinds.json`. Se o arquivo principal já define
`[keybinds]` ou um include não puder ser editado com segurança, o
provisionamento recusa a mudança e mostra o erro em **Configurações → Umbriel
→ Atalhos**.

O editor usa draft: **Salvar** valida com `umbriel config validate` antes de
trocar os arquivos, **Reverter** descarta edições e **Restaurar padrões** volta
ao catálogo original (ainda é preciso salvar). Atalhos nativos usam ações do
compositor, ações da Hydra usam seu IPC e binds personalizadas também podem
executar comandos. **Mod+Shift+Escape** alterna a inibição de atalhos mesmo
quando a janela está com atalhos inibidos. Para reinstalar o catálogo sem
apagar rebinds: `python3 Scripts/python/umbriel_keybinds.py provision`.

## Edge Shelf (Umbriel)

Em **Configurações → Barra → Edge Shelf**, ative a prateleira com a barra
**Emoldurada**. Ela fica oculta em outros estilos sem apagar os favoritos.
Adicione ou remova apps pelo menu de contexto do Launcher; reordene ou remova
em Configurações, onde cada app reúne ícone, nome, identificação e ações compactas.
Na moldura esquerda, passe o cursor para revelar uma deformação suave da própria
Frame, com um chevron discreto; hover não abre a prateleira. Clique ou arraste-o
brevemente para a direita para expandir essa mesma superfície e abrir. O botão **+** abre o
Launcher. Escape, clique fora ou outro clique no handle fecham a prateleira.

O clique num app adota sua única janela existente ou lança uma nova instância.
Com várias janelas, escolha explicitamente uma no menu junto ao ícone. A Hydra
usa um scratchpad Umbriel `hydra-edge-<appId>` por favorito; antes de remover o
favorito, devolve suas janelas ao workspace normal. O scratchpad convencional
`hydra-default` e seus atalhos continuam separados. A posição da janela
invocada segue o comportamento nativo do Umbriel, sem alinhamento X/Y forçado.

---

## Superfícies Tinted

Em **Configurações → Esquema de cores → Cores**, ative cores do papel de
parede e escolha **Clássico** ou **Tinted** junto ao método de geração.
O padrão continua **Clássico**; Tinted é um pós-processamento que mistura
sutilmente a primária nas superfícies, antes dos templates da Hydra e dos apps.
A troca regenera `colors.json` e anima a UI sem reiniciar a shell.

Tinted atua em `tonal-spot`, `content`, `expressive`, `fidelity`, `neutral`,
`m3-vibrant`, `fruit-salad` e `rainbow`; `monochrome` permanece neutro.
Os métodos Wallust-like `vibrant`, `faithful`,
`dysfunctional` e `muted` mantêm suas superfícies originais, sem mapear
intensidades Material não equivalentes. Temas predefinidos e JSON importados
não são tingidos.

O modelo `smart` usa o critério do Studio: média de
`max(R,G,B) - min(R,G,B)` normalizada ≤ 0,035 escolhe Monochrome; acima disso,
escolhe Content. A mesma análise protege Tinted em imagens quase monocromáticas.
Imagens usam thumbnail RGBA Triangle de até 128px,
ignorando pixels totalmente transparentes; vídeos usam o frame representativo
já extraído pela Hydra. O redimensionador é ImageMagick, não a crate Rust
`image`; amostras no limiar podem diferir entre os decoders.

O processor aceita `--surface-style classic|tinted`. Os cinco containers de
superfície e os containers primário, secundário e terciário, com seus respectivos
foregrounds, passam explicitamente para `colors.json` em ambos os estilos.
`mSurfaceVariant` usa o papel Material `surface_variant`, não `surface_container`.
JSONs antigos e temas autorados sem esses campos preservam os blends legados;
trocar de uma paleta moderna para um tema antigo também limpa os roles opcionais.

A UI usa a mesma hierarquia em Clássico e Tinted: frame/barra em container baixo,
painéis em container, grupos/NBox e superfícies flutuantes em container alto,
controles elevados/hover em container máximo e seleção em containers de accent.
Ações primárias mantêm `primary/on_primary`; scrims e transparência configurável
continuam independentes dessa hierarquia.

Em **Wallpaper → Paleta de Cores**, a receita contextual combina o arquivo
selecionado, modelo, Material Spec, até quatro seeds ranqueadas e Classic/Tinted.
Trocar a receita recalcula a base e descarta edits manuais; Reset restaura a base
gerada. O mock preview acompanha essa paleta sem aplicar o tema à sessão.

O cálculo via `previewWallpaperPalette(path, recipe, callback)` é read-only.
Preview ao vivo altera temporariamente `colors.json`; Cancel restaura todos os
roles anteriores. Salvar mantém ambas as variantes e as cores ANSI. “Usar receita
no wallpaper ativo” persiste a receita somente quando a imagem dirige as cores
globais; candidates não alteram a sessão sem Preview ou Save.

`--seed-index N` escolhe uma seed Material; valores inválidos usam índice 0.
`--material-spec 2025|2021` controla o backend depois da seleção da seed, antes
do Tinted e dos templates. O padrão é **2025**: Tonal Spot, M3 Vibrant,
Expressive e Neutral usam os construtores reais de
[materialyoucolor](https://github.com/T-Dynamos/materialyoucolor-python), com
`spec_version="2025"` e plataforma `phone`. Não há download durante geração.
O caminho **2021** preserva o engine Hydra já validado; Content, Fidelity,
Fruit Salad, Rainbow, Monochrome e métodos Hydra também o mantêm quando 2025 é
selecionado. Smart mantém seu seletor Content/Monochrome e usa esse fallback.
O preview informa separadamente o spec solicitado e o efetivo.

Os mesmos seletores estão em **Configurações → Cores** e na receita contextual.
Favoritos novos guardam modelo, estilo, seed e spec; antigos sem spec usam 2021
para preservar sua aparência, sem seed usam 0 e sem estilo mantêm o atual.
`m3-vibrant` continua separado da heurística Hydra legada `vibrant`.
O backend 2025 recebe contraste neutro; reduções internas de contraste são
limitadas a zero. Não há sliders Contrast/Chroma/Tone nesta UI.

Instalações Arch precisam de `python-materialyoucolor3 >= 3.0.2` (não v2),
inclusive com `--skip-optional`. Nix empacota `materialyoucolor 3.0.4` com hash
fixo no runtime e no devShell. Em um venv de desenvolvimento, instale
`Scripts/python/requirements.txt`; sem a dependência, pedir 2025 falha
explicitamente, não substitui silenciosamente o spec por 2021.

---

## Templates de aplicativos

Ative as integrações em **Configurações → Cores → Templates**. Os templates
recebem a paleta final de wallpaper (Material 2021/2025, Classic/Tinted) ou as
cores autorais do esquema predefinido. Disponibilizar o arquivo não muda
automaticamente a preferência de tema do aplicativo.

| Aplicativo | Arquivo gerado / como usar |
| --- | --- |
| Discord | Midnight (`hydra.theme.css`), Material (`hydra-material.theme.css`) e System24 (`hydra-system24.theme.css`) na pasta `themes` de cada cliente detectado; escolha o estilo no cliente. Inclui Legcord e Vesktop Flatpak (`dev.vencord.Vesktop`). |
| Heroic | `heroic/themes/hydra.css` no config nativo ou `~/.var/app/com.heroicgameslauncher.hgl/config`; selecione Hydra no Heroic. O CSS permanece restrito a `body.hydra`. |
| Steam | `steamui/skins/Material-Theme/css/main/colors/matugen.css` dentro de `~/.steam/steam` ou `~/.var/app/com.valvesoftware.Steam/.local/share/Steam`. Requer a skin Material-Theme já instalada; não instala a skin/Millennium. |
| OBS Studio | `obs-studio/themes/hydra.obt` no config nativo ou `~/.var/app/com.obsproject.Studio/config`. |
| Prism Launcher | `$XDG_DATA_HOME/PrismLauncher/themes/Hydra/theme.json` ou `~/.var/app/org.prismlauncher.PrismLauncher/data/PrismLauncher/themes/Hydra/theme.json`; escolha Hydra em **Settings → Launcher → User Interface → Colors** e reinicie o Prism. |
| Fastfetch | `$XDG_CONFIG_HOME/fastfetch/themes/hydra.jsonc`; preset de cores para `fastfetch --config "${XDG_CONFIG_HOME:-$HOME/.config}/fastfetch/themes/hydra.jsonc"`. Não modifica `config.jsonc` e não pressupõe um include inexistente. Para manter módulos personalizados, use as seções `logo`/`display` geradas na sua própria configuração. |
| Claude Code | `~/.claude/themes/hydra.json`; escolha **Hydra** em `/theme` numa versão com suporte a temas customizados. O watcher do Claude recarrega o arquivo. Requer o diretório `~/.claude` já inicializado. |
| OpenCode | `$XDG_CONFIG_HOME/opencode/themes/hydra.json`, com variantes dark/light; escolha `hydra` em `/theme`. |
| tmux | `$XDG_CONFIG_HOME/tmux/themes/hydra.conf`; adicione `source-file "${XDG_CONFIG_HOME:-$HOME/.config}/tmux/themes/hydra.conf"` ao seu `tmux.conf`. Na geração, o hook recarrega o servidor corrente (`TMUX`) ou o padrão, apenas se houver sessão; `-N` impede iniciar servidor. Não enumera sockets personalizados. |
| Fcitx5 | `$XDG_DATA_HOME/fcitx5/themes/hydra/theme.conf`; selecione Hydra nas opções de **Classic User Interface** do `fcitx5-configtool`. O hook opcional usa `fcitx5-remote --check -r`, somente em uma instância existente, sem alterar suas preferências ou reiniciar a sessão. |

Os caminhos XDG acima usam os defaults `~/.config`, `~/.local/share`,
`~/.local/state` e `~/.cache` quando a variável correspondente está ausente,
vazia ou relativa. O renderer expande apenas um token inicial completo
(`$XDG_CONFIG_HOME`, `$XDG_DATA_HOME`, `$XDG_STATE_HOME`, `$XDG_CACHE_HOME`)
e `~`, sem executar shell. Caminhos Flatpak ficam fixos no sandbox do app.

No registry, um output pode declarar `requiresPath`; ele vira `requires_path`
no TOML. Se o caminho não existe, o renderer ignora aquele output antes de
criar diretórios ou executar hooks. Native e Flatpak são avaliados
independentemente. Steam exige a pasta da skin; Heroic, OBS, Prism e os
clientes Discord exigem suas pastas já inicializadas. Outputs sem guard
continuam criando os diretórios necessários quando habilitados.

Os novos arquivos são mappings próprios da Hydra baseados nos formatos
documentados de [Prism](https://prismlauncher.org/wiki/getting-started/change-themes/),
[Fastfetch](https://github.com/fastfetch-cli/fastfetch/wiki/Configuration),
[Claude Code](https://code.claude.com/docs/en/terminal-config#custom-themes),
[OpenCode](https://opencode.ai/docs/themes/),
[tmux](https://man.openbsd.org/tmux) e
[Fcitx5](https://github.com/fcitx/fcitx5/blob/master/src/ui/classic/theme.h).
Nenhum template comunitário sem licença foi copiado.
System24 usa o layout CSS remoto do [refact0r](https://github.com/refact0r/system24)
(MIT), com aviso/licença preservados no template, sem logo da Noctalia.
Essa importação requer acesso à rede, como os estilos Discord existentes.
Não há nova dependência Python; tmux e `fcitx5-remote` são opcionais para reload.

### Templates avançados (Fase 2)

| Aplicativo | Arquivo gerado / ativação |
| --- | --- |
| Neovim | `$XDG_CONFIG_HOME/nvim/lua/hydra-colors.lua`; adicione `require('hydra-colors')` ao seu `init.lua`. Exige config do Neovim já existente. Usa ANSI16 e highlights nativos, sem plugin Base16/DMS/IPC. O módulo observa somente sua própria pasta/arquivo e recarrega as instâncias que o carregaram; não envia sinais a outros Neovims. |
| Zellij | `$XDG_CONFIG_HOME/zellij/themes/hydra.kdl`; selecione `theme "hydra"` no seu config. Formato agrupado KDL atual; o config principal não é editado. |
| Antigravity CLI | Integração **Terminal**, conforme o contrato atual: mantém a receita em `$XDG_CACHE_HOME/hydra/antigravity.json` e altera somente `colorScheme` para `terminal` em `~/.gemini/antigravity-cli/settings.json` já existente. Usa as cores do terminal tematizado pela Hydra. Chaves desconhecidas são preservadas; se o valor já é `terminal`, nenhum byte/mtime é alterado. Não usa os antigos `customThemeSeeds*` nem inventa um tema customizado que o CLI atual não suporta. |
| Codex | `$CODEX_HOME/themes/hydra.tmTheme` (fallback `~/.codex/themes/hydra.tmTheme`); escolha Hydra em `/theme`, ou selecione `tui.theme = "hydra"` manualmente. Requer home do Codex inicializado. TextMate próprio, sem editar `config.toml`. |
| Obsidian | `hydra.css` em `.obsidian/snippets` de cada vault registrado e existente. Descobre apenas manifests nativos/Flatpak (`obsidian/obsidian.json`), sem varrer HOME. Ative Hydra em **Appearance → CSS snippets** em cada vault. Não altera plugins, Markdown ou `appearance.json`. Pastas de configuração customizadas sem `.obsidian` não são inferidas. |
| Bat | `$BAT_CONFIG_DIR/themes/Hydra.tmTheme` (fallback `$XDG_CONFIG_HOME/bat/themes/Hydra.tmTheme`); use `bat --theme Hydra` ou configure o tema manualmente. O hook opcional `bat cache --build` é assíncrono. |
| Fzf | `$XDG_CONFIG_HOME/fzf/hydra.sh` para bash/zsh e `hydra.fish` para fish. Faça `source` manualmente; os fragments acrescentam cores a `FZF_DEFAULT_OPTS`, preservando as opções existentes. Nenhum dotfile é editado. |
| Inkscape | `inkscape/ui/hydra-colors.css` no config nativo ou `~/.var/app/org.inkscape.Inkscape/config`. Acrescenta somente um import em `ui/user.css`, preservando o conteúdo anterior. Exige config do aplicativo já existente. |
| GIMP 3 | `GIMP/3.0/hydra-colors.css` ou `GIMP/3.2/hydra-colors.css`, no config nativo/Flatpak (`org.gimp.GIMP`), somente para versões inicializadas. Acrescenta import em `gimp.css`; não altera brushes, plugins, layouts ou imagens. Não suporta GIMP 2.10. |

A camada ANSI é derivada **depois** de Classic/Tinted, somente na entrada do
renderer. O JSON público da paleta e os roles Material originais permanecem
intactos. Há `terminal_foreground`, `terminal_background`, as variantes
`terminal_normal_*`/`terminal_bright_*` para black/red/green/yellow/blue/magenta/
cyan/white, além de cursor e seleção. Valores ANSI autorais de esquemas
predefinidos têm precedência. A derivação usa HCT harmonizado com os acentos
atuais e ajuste de contraste; não substitui os algoritmos Material ou Tinted.

```text
{{ colors.terminal_normal_red.default.hex }}
{{ colors.terminal_normal_blue.light.hex_stripped }}
{{ colors.terminal_normal_green.dark.rgb }}
{{ colors.terminal_normal_red.default.hex | rotate_hue 30 }}
```

`rotate_hue` é relativo, com ângulos positivos/negativos módulo 360 em HSL.
`set_hue` continua absoluto. No registry, `hookAsync` opcional gera
`hook_async = true` para o **post-hook**; o default é síncrono e pre-hooks
continuam síncronos. Os filhos não herdam pipes de captura que bloqueariam a
paleta. Obsidian usa `postProcessOnUnchanged`/`hook_on_unchanged` porque um novo
vault registrado precisa receber o snippet mesmo sem mudança nas cores.
Na CLI, use `--both --default-mode dark|light` para templates dual-mode como
Obsidian, que referenciam `.dark` e `.light` no mesmo arquivo. `--mode`/`--light`
selecionam um único payload; nesse caso, `{{mode}}` acompanha o modo gerado.

Os helpers escrevem atomicamente, mantêm permissões e não reescrevem arquivos
idênticos. Destinos symlink são recusados em vez de substituir links ou atingir
arquivos não relacionados. Nenhum backup persistente novo é criado.
Ativação/seleção permanece explícita nos apps; apenas a integração Antigravity
opt-in altera seu campo oficial `colorScheme`. Reinicie Inkscape/GIMP caso o
aplicativo não recarregue seu CSS sozinho.

O export opcional MaterialFox **não foi adicionado**: o upstream depende de
seletores/variáveis internas do Firefox, sem contrato externo versionado para
este export. Pywalfox permanece a integração principal, sem mudanças em
perfis, `prefs.js` ou Native Messaging.


---

## Requisitos

- Arch Linux ou derivada (CachyOS é o alvo testado)
- Umbriel para a sessão nativa e o editor de atalhos; o instalador legado ainda requer Hyprland ≥ 0.55.
- Lista completa de dependências: [`DEPENDENCIES.md`](./DEPENDENCIES.md)

---

## Créditos

Este projeto é um fork do [Noctalia Shell](https://github.com/noctalia-dev/noctalia-shell) (MIT), construído sobre [Quickshell](https://quickshell.org). Ver [`CREDITS.md`](./CREDITS.md) para a lista completa de dependências e atribuições de terceiros.

## Licença

Código original sob MIT — ver [LICENSE](./LICENSE).
O port do Tinted de [Matugen Studio](https://github.com/raellx22/Matugen-Studio/blob/cad6db3b178ee73c73bbd1facb869e3aaa16e49a/src-tauri/src/commands/color.rs)
(`Scripts/python/src/theming/lib/tinted.py`) mantém GPL-2.0-or-later — ver
[LICENSE.tinted](./Scripts/python/src/theming/lib/LICENSE.tinted).
A distribuição do pipeline combinado deve respeitar os termos GPL; este port
não é uma relicença MIT do código do Studio.
