# Plano persistente — refatoração visual Hydra Expressive

## Objetivo

Refatorar todos os módulos, painéis, widgets e animações da Hydra Shell para a linguagem visual da Caelestia, preservando os serviços, integrações, configurações, suporte multi-monitor e recursos exclusivos da Hydra.

A decisão de projeto é portar o motor visual GPLv3 da Caelestia (`BlobGroup`, `BlobRect`, `BlobInvertedRect` e suporte correspondente), adaptar o trabalho combinado para GPLv3 e preservar os avisos de copyright/licença dos projetos de origem.

## Regra de estado

Cada fase e cada item usa exatamente um destes estados:

- **Em espera** — ainda não começou; nenhum trabalho parcial deve ser presumido.
- **Em trabalho** — existe trabalho ativo ou parcial; a seção deve registrar próximo passo, arquivos tocados e bloqueios.
- **Finalizado e validado** — implementação concluída e evidência de validação registrada. Ao entrar neste estado, o título e seus itens são riscados com `~~...~~`.

Regras operacionais:

1. Exatamente uma fase pode ficar em **Em trabalho**.
2. Uma fase só vira **Finalizado e validado** depois de executar a validação definida nela.
3. Antes de encerrar uma sessão, atualizar `Ponto de retomada` e `Registro de evidências`.
4. Ao retomar, ler primeiro este arquivo e rodar `prowl-agent wip` no Lab.
5. Desenvolvimento ocorre somente em `/home/raell/Projetos/hydra-shell`; a shell ativa em `~/.config/quickshell/hydra-shell` só recebe fases validadas.
6. Cada fase deve ser commitada separadamente. Nada parcialmente validado entra em `legacy-v4`.
7. Código, branding e assets da Caelestia não são copiados fora do escopo GPL explicitamente registrado.
8. Novos textos de interface continuam obrigatoriamente em português brasileiro.

## Quadro geral

| Fase | Estado | Gate de conclusão |
| --- | --- | --- |
| 0. Fundação, licença e baseline | **Finalizado e validado** | Toolchain determinístico, licença registrada, baseline capturado |
| 1. Plugin visual GPL | **Finalizado e validado** | Plugin Blob carrega, funde e deforma duas superfícies |
| 2. Design system | **Finalizado e validado** | Tokens, motion, state layer, foco e elevação centralizados |
| 3. Widgets | **Em trabalho** | 55 widgets auditados e estados de interação unificados |
| 4. Superfície global | **Em espera** | MainScreen/SmartPanel usando blobs, fullscreen e input corretos |
| 5. Barra | **Em espera** | Quatro posições e cinco densidades validadas em dois monitores |
| 6. Painéis | **Em espera** | Todos os SmartPanel e conteúdos internos revisados |
| 7. Superfícies independentes | **Em espera** | Dock, OSD, notificações, overlays e Screen Toolkit migrados |
| 8. Assinaturas expressivas | **Em espera** | Morphs, trails e indicadores validados com performance mode |
| 9. Validação final e cutover | **Em espera** | Matriz visual completa e shell ativa atualizada |

---

## Fase 0 — Fundação, licença e baseline

**Estado: Finalizado e validado**

### Checklist

- [x] Criar este ledger persistente com estados, gates e ponto de retomada.
- [x] Criar branch de trabalho `visual/caelestia-expressive` a partir de `legacy-v4`.
- [x] Estabilizar um `qmlformat` reproduzível; Qt 6.10.3 oficial fixado em cache pelo `Scripts/dev/bootstrap-qt-tools.sh`.
- [x] Garantir que `Scripts/dev/qmlfmt.sh` nunca deixe reformatação parcial após falha.
- [x] Registrar GPLv3 como licença do trabalho combinado, preservando atribuições MIT e GPL.
- [x] Registrar quais arquivos GPL da Caelestia serão portados.
- [x] Capturar baseline visual: barra, launcher, central de controle, settings, notificações, OSD, dock e Screen Toolkit em DP-1/DP-2.

### Validação obrigatória

- `qmlformat` percorre os 522 arquivos QML sem falha e sem diff residual.
- `bash -n` nos scripts alterados.
- `qs -p /home/raell/Projetos/hydra-shell` carrega o Lab.
- Screenshots baseline existem e identificam monitor/superfície/tema.
- Licenças e atribuições são coerentes com a decisão GPLv3.

### Ponto de retomada da fase

Fase concluída. O baseline está em `~/Pictures/HydraShell-Baseline/2026-08-17/`; o próximo trabalho começa no porte mínimo de `Hydra.Visual`.

---

## Fase 1 — Plugin visual GPL

**Estado: Finalizado e validado**

### Checklist

- [x] Auditar dependências e compatibilidade do plugin Caelestia com `noctalia-qs 0.0.12`.
- [x] Portar `BlobGroup`, `BlobRect`, `BlobInvertedRect`, material, física e shader para o namespace `Hydra.Visual`.
- [x] Preservar cabeçalhos GPL e créditos da Caelestia.
- [x] Criar build CMake mínimo do módulo QML.
- [x] Integrar build/instalação em `Scripts/bash/install.sh`.
- [x] Integrar o plugin em `flake.nix`/`nix/`.
- [x] Criar smoke surface isolada com dois blobs, fusão, raio por canto e deformação.

### Validação obrigatória

- Import `Hydra.Visual` carrega no Lab.
- Dois blobs fundem e se separam sem artefato.
- Deformação acompanha velocidade e estabiliza quando parada.
- Reinício da shell não deixa locks ou processos duplicados.

---

## Fase 2 — Design system

**Estado: Finalizado e validado**

### Checklist

- [x] Expandir `Commons/Style.qml` com raios, padding, tipografia semântica e elevação.
- [x] Adicionar curvas standard, emphasized e expressive spatial/effects.
- [x] Preservar `animationSpeed`, `animationDisabled`, escala e performance mode.
- [x] Criar `NAnim`, `NColorAnimation`, `NAnchorAnimation` e `NFadeSwap`.
- [x] Criar `NStateLayer`, ripple, shape morph e `NFocusRing`.
- [x] Criar `NElevation` e evolução de `NDropShadow`.
- [x] Adicionar helpers tonais ao `Commons/Color.qml` sem substituir a geração HCT existente.

### Validação obrigatória

- Curvas espaciais nunca animam cor/opacidade.
- Nenhuma nova animação usa duração ou easing literal.
- Kill-switch de animação e performance mode zeram/desligam todos os novos efeitos.
- Troca de tema não executa animações duplicadas.

---

## Fase 3 — Widgets

**Estado: Em trabalho**

### Checklist

- [x] Refatorar `NText`, `NIcon`, `NIconButton`, `NToggle`, `NDivider`, `NButton`, `NComboBox`, `NTextInput`, `NLabel` e `NBox`.
- [ ] Unificar hover, press, focus, disabled e semântica de clique.
- [ ] Migrar forms: checkbox, radio, sliders, spinbox, color/file/icon pickers e keybind recorder.
- [ ] Migrar navegação: tabs, listas, grids, scrolls, collapsible, menus e reorder.
- [ ] Migrar data/display: clock, battery, graph, gauges, busy indicators, imagens e AudioSpectrum.
- [ ] Migrar dialogs/popups complexos.
- [ ] Eliminar triplicação visual de scroll/list/grid.

### Validação obrigatória

- Os 55 widgets aparecem no inventário de revisão.
- Todo controle interativo tem state layer e focus visível.
- Mouse, teclado, disabled, hover, press e drag exercitados.
- Nenhuma segunda convenção visual permanece.

---

## Fase 4 — Superfície global

**Estado: Em espera**

### Checklist

- [ ] Integrar `BlobGroup` em `AllBackgrounds.qml`.
- [ ] Representar moldura com `BlobInvertedRect`.
- [ ] Converter cada `panelRegion` em `BlobRect`.
- [ ] Aplicar `deformMatrix` ao conteúdo do `SmartPanel`.
- [ ] Refatorar abertura/fechamento para `offsetScale`, slide, fade e overshoot.
- [ ] Manter `PanelService`, input regions, exclusions e política de painel único.
- [ ] Remover moldura/sombra em fullscreen.
- [ ] Manter blur opt-in pelo compositor.

### Validação obrigatória

- Abrir, fechar e trocar painéis sem flicker ou vazamento de input.
- Fusão, deformação, sombra e cantos corretos em DP-1/DP-2.
- Fullscreen remove moldura sem deixar regiões órfãs.

---

## Fase 5 — Barra

**Estado: Em espera**

### Checklist

- [ ] Aplicar cápsulas tonais e raio total.
- [ ] Aplicar cores semânticas por categoria de widget.
- [ ] Criar active workspace trail elástico.
- [ ] Migrar os 44 widgets de `Modules/Bar/` para state layer/motion.
- [ ] Adaptar título e agrupamento às orientações vertical/horizontal.
- [ ] Manter auto-hide, framed e configurações por monitor.

### Validação obrigatória

- Posições top/bottom/left/right.
- Densidades mini/compact/default/comfortable/spacious.
- DP-1/DP-2, auto-hide e fullscreen.

---

## Fase 6 — Painéis

**Estado: Em espera**

### Checklist

- [ ] Navegação principal: Launcher, Control Center, Settings, Session e Setup Wizard.
- [ ] Sistema: Audio, Network, Bluetooth, Battery, Brightness, Media, Notification History e System Monitor.
- [ ] Conteúdo/utilidades: Wallpaper, Tray, USB, OBS, Plugins, Tamagotchi, Cards, Changelog e Static Dock.
- [ ] Modais integrados: Polkit, ScreenShare e ScreenToolkitPanel.
- [ ] Aplicar padding 16, spacing 12, cards raio 16 e tipografia semântica.

### Validação obrigatória

- Todos os 25 roots `SmartPanel` revisados.
- Conteúdo cabe em telas menores e com escala aumentada.
- Navegação por teclado e estados vazios/erro/carregamento verificados.

---

## Fase 7 — Superfícies independentes

**Estado: Em espera**

### Checklist

- [ ] Dock.
- [ ] Notifications e Notification History.
- [ ] OSD e ShowKeys OSD.
- [ ] Toast, Tooltip, tray/context menus.
- [ ] Settings floating window, Launcher overlay e Workspace Manager.
- [ ] Polkit/ScreenShare standalone.
- [ ] DesktopWidgets e Cards.
- [ ] Screen Toolkit completo: panel, annotate, mirror, measure, pin, record, region selector e resultados.

### Validação obrigatória

- Nenhuma superfície mantém a estética antiga.
- Tempos de negócio não são confundidos com durações de animação.
- Overlays não capturam input fora de suas regiões.

---

## Fase 8 — Assinaturas expressivas

**Estado: Em espera**

### Checklist

- [ ] Loading indicator com morph de forma.
- [ ] Indicadores/progressos ondulados.
- [ ] Thumb elástico em switches/sliders.
- [ ] Badges com entrada por scale.
- [ ] Popouts que brotam da barra.
- [ ] Cantos côncavos em superfícies conectadas.
- [ ] Auditar licença e compatibilidade de `M3Shapes` antes de incorporar.

### Validação obrigatória

- Efeitos não degradam idle CPU/GPU.
- Performance mode desliga deformações e efeitos caros.
- Nenhum efeito prejudica legibilidade ou acessibilidade.

---

## Fase 9 — Validação final e cutover

**Estado: Em espera**

### Checklist

- [ ] Executar matriz visual light/dark, esquema fixo/wallpaper, blur on/off e fullscreen.
- [ ] Executar matriz de escala, raios, animação desligada e performance mode.
- [ ] Confirmar 55 widgets, 25 SmartPanels e todas as superfícies independentes.
- [ ] Reduzir `Easing.*` fora das primitivas para zero ou exceções documentadas.
- [ ] Eliminar durações literais de animação; preservar apenas timers de negócio documentados.
- [ ] Remover código e convenções visuais legadas.
- [ ] Atualizar créditos/documentação necessários.
- [ ] Mesclar em `legacy-v4`, publicar e sincronizar a shell ativa.

### Validação obrigatória

- Lab limpo e indexado por Prowl.
- Shell inicia do zero pelo instalador.
- Dois monitores estáveis.
- Sem regressão funcional nos IPCs, painéis, atalhos ou configurações.
- Shell ativa atualizada somente após a matriz completa passar.

---

## Ponto de retomada global

**Fase ativa:** Fase 3 — Widgets.

**Último trabalho concluído:** dez widgets de maior fan-in migrados para tokens semânticos, state layer, morph, focus ring e motion centralizado.

**Próxima ação exata:** migrar a família de forms — checkbox, radio, sliders, spinbox, pickers e gravador de atalhos — reutilizando as mesmas primitivas.

**Bloqueios conhecidos:** nenhum; o formatter reproduzível usa Qt 6.10.3 isolado pelo `Scripts/dev/bootstrap-qt-tools.sh`.

## Registro de evidências

| Data | Fase | Evidência | Resultado |
| --- | --- | --- | --- |
| 2026-08-17 | 0 | Análise paralela de Caelestia/Hydra; inventários de Style, Widgets, Modules, motion, components e blobs | Arquitetura de migração definida |
| 2026-08-17 | 0 | Decisão explícita do proprietário: portar plugin GPLv3 | Estratégia de licença definida |
| 2026-08-17 | 0 | `qmlformat 6.10.3` oficial percorreu 522 QML; segunda execução `--check` retornou árvore formatada | Formatter reproduzível validado |
| 2026-08-17 | 0 | Execução intencional com Qt 6.11.1 falhou em nove arquivos e preservou hash idêntico de `git status` | Transação em falha validada |
| 2026-08-17 | 0 | `LICENSE` atualizado para GPL-3.0-only; MIT do Noctalia preservada em `LICENSES/Noctalia-MIT.txt`; inventário exato do porte em `LICENSES/Caelestia-Blob-Port.md` | Licenciamento e atribuição fechados |
| 2026-08-17 | 0 | 16 PNGs em `~/Pictures/HydraShell-Baseline/2026-08-17/`, superfícies nominadas e DP-1/DP-2 identificados; launcher, central, settings, notificações, Screen Toolkit e OSD inspecionados visualmente | Baseline capturado |
| 2026-08-17 | 0 | Reprodução mostrou OSD importado sem instância; `OSD {}` restaurado em `shell.qml`; volume IPC renderizou em DP-1 e DP-2 no Lab | Bug funcional de baseline corrigido e verificado |
| 2026-08-17 | 1 | CMake/Ninja com Qt 6.11.1 compilou `hydra_visual`, plugin QML e shaders; `/usr/lib64/qt6/bin/qml -I /tmp/hydra-visual-build/qml /tmp/HydraVisualImport.qml` encerrou com código 0 | Porte mínimo `Hydra.Visual` compila e importa |
| 2026-08-17 | 1 | `build-visual-plugin.sh --prefix /tmp/hydra-visual-install` instalou `.so`, `qmldir` e `.qmltypes` com RPATH `$ORIGIN`; import via `QML_IMPORT_PATH` retornou 0; `bash -n` passou | Instalação CachyOS/Lab validada |
| 2026-08-17 | 1 | `nix/package.nix` passou a compilar/instalar `Hydra.Visual`, exportar `QML_IMPORT_PATH` e declarar GPL-3.0-only; dev shell ganhou CMake/Ninja/ShaderTools | Integração Nix implementada; build Nix não executado porque `nix` não está instalado nesta máquina |
| 2026-08-17 | 1 | `plugin/smoke/shell.qml` executado no `noctalia-qs`; `08-blob-separated.png` e `09-blob-merged.png` mostram repouso, raios independentes, fusão contínua e deformação durante movimento | Smoke visual aprovado sem artefatos |
| 2026-08-17 | 1 | `qmlformat 6.10.3 --check` percorreu 523 QML; Lab completo carregou; após encerrar smoke/Lab, `qs list --all` mostrou apenas a shell ativa PID 14830 | Gate de plugin e limpeza de instâncias aprovado |
| 2026-08-17 | 2 | `Commons/Style.qml` ganhou escala semântica aditiva de tipografia, espaço/padding e raios expressive; `qmlformat --check` passou e o Lab carregou sem tipo indisponível ou propriedade indefinida | Tokens base integrados sem quebrar 340 consumidores |
| 2026-08-17 | 2 | Smoke temporário executou `NAnim`, `NColorAnimation`, `NAnchorAnimation` e `NFadeSwap`; frames separados por um ciclo divergiram; probe com configuração isolada retornou `MOTION_KILL_SWITCH false 0 0 0 0 0 0`; `qmlformat --check` percorreu 527 QML e o Lab completo carregou | Motion centralizado validado; curvas com overshoot ficaram restritas a geometria e kill-switch/performance mode compartilham o mesmo corte |
| 2026-08-17 | 2 | Smoke temporário alternou `NStateLayer`, `NRipple`, `NShapeMorph`, `NFocusRing` e `NElevation`; quatro frames produziram três hashes e inspeção visual confirmou os estados; `qmlformat --check` percorreu 532 QML; o Lab carregou e o OSD real foi acionado pelo IPC após evoluir `NDropShadow` | State, foco, morph, elevação e helpers tonais aprovados; encerramento deixou apenas a shell ativa PID 14830 |
| 2026-08-17 | 3 | Prowl contou 809 relações de consumo nos dez widgets prioritários; smoke visual carregou todos, Return ativou `NButton`, Tab/Space abriu `NComboBox`, foco contornou controles disabled e clique Wayland alternou `NToggle`; launcher e Settings reais foram inspecionados; `qmlformat --check` percorreu 532 QML | Primeiro corte de widgets aprovado em uso isolado e nas superfícies reais |
| 2026-08-17 | 3 | Fechar launcher e abrir/fechar Settings reproduziu acessos nulos nos atalhos centralizados; `MainScreen.qml` passou a usar painel estável e optional chaining; nova instância do Lab repetiu a corrida sem `TypeError` | Regressão funcional adjacente corrigida na fonte |
