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

Tinted atua em `tonal-spot`, `content`, `fruit-salad` e `rainbow`; `monochrome`
permanece neutro. Os métodos Wallust-like `vibrant`, `faithful`,
`dysfunctional` e `muted` mantêm suas superfícies originais, sem mapear
intensidades Material não equivalentes. Temas predefinidos e JSON importados
não são tingidos.

O Smart Monochrome usa o critério do Studio: média de
`max(R,G,B) - min(R,G,B)` normalizada ≤ 0,035 suprime a tonalização sem trocar
o engine nem os acentos. Imagens usam thumbnail RGBA Triangle de até 128px,
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
