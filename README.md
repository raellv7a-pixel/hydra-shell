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
em Configurações. Na moldura esquerda, passe o cursor para revelar o handle;
clique ou arraste-o brevemente para a direita para abrir. O botão **+** abre o
Launcher. Escape, clique fora ou outro clique no handle fecham a prateleira.

O clique num app adota sua única janela existente ou lança uma nova instância.
Com várias janelas, escolha explicitamente uma no menu junto ao ícone. A Hydra
usa um scratchpad Umbriel `hydra-edge-<appId>` por favorito; antes de remover o
favorito, devolve suas janelas ao workspace normal. O scratchpad convencional
`hydra-default` e seus atalhos continuam separados. A posição da janela
invocada segue o comportamento nativo do Umbriel, sem alinhamento X/Y forçado.

---

## Requisitos

- Arch Linux ou derivada (CachyOS é o alvo testado)
- Umbriel para a sessão nativa e o editor de atalhos; o instalador legado ainda requer Hyprland ≥ 0.55.
- Lista completa de dependências: [`DEPENDENCIES.md`](./DEPENDENCIES.md)

---

## Créditos

Este projeto é um fork do [Noctalia Shell](https://github.com/noctalia-dev/noctalia-shell) (MIT), construído sobre [Quickshell](https://quickshell.org). Ver [`CREDITS.md`](./CREDITS.md) para a lista completa de dependências e atribuições de terceiros.

## Licença

MIT — ver [LICENSE](./LICENSE).
