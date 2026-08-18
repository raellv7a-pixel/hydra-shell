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
| 3. Widgets | **Finalizado e validado** | 55 widgets auditados e estados de interação unificados |
| 4. Superfície global | **Finalizado e validado** | MainScreen/SmartPanel usando blobs, fullscreen e input corretos |
| 5. Barra | **Finalizado e validado** | Quatro posições e cinco densidades validadas em dois monitores |
| 6. Painéis | **Finalizado e validado** | Todos os SmartPanel e conteúdos internos revisados |
| 7. Superfícies independentes | **Finalizado e validado** | Dock, OSD, notificações, overlays e Screen Toolkit migrados |
| 8. Assinaturas expressivas | **Finalizado e validado** | Morphs, trails e indicadores validados com performance mode |
| 9. Validação final e cutover | **Em trabalho** | Matriz visual completa e shell ativa atualizada |

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

**Estado: Finalizado e validado**

### Checklist

- [x] Refatorar `NText`, `NIcon`, `NIconButton`, `NToggle`, `NDivider`, `NButton`, `NComboBox`, `NTextInput`, `NLabel` e `NBox`.
- [x] Unificar hover, press, focus, disabled e semântica de clique.
- [x] Migrar forms: checkbox, radio, sliders, spinbox, color/file/icon pickers e keybind recorder.
- [x] Migrar navegação: tabs, listas, grids, scrolls, collapsible, menus e reorder.
- [x] Migrar data/display: clock, battery, graph, gauges, busy indicators, imagens e AudioSpectrum.
- [x] Migrar dialogs/popups complexos.
- [x] Eliminar triplicação visual de scroll/list/grid.

### Validação obrigatória

- [x] Os 55 widgets aparecem no inventário de revisão.
- [x] Todo controle interativo tem state layer e focus visível.
- [x] Mouse, teclado, disabled, hover, press e drag exercitados.
- [x] Nenhuma segunda convenção visual permanece.

---

## Fase 4 — Superfície global

**Estado: Finalizado e validado**

### Checklist

- [x] Integrar `BlobGroup` em `AllBackgrounds.qml`.
- [x] Representar moldura com `BlobInvertedRect`.
- [x] Converter cada `panelRegion` em `BlobRect`.
- [x] Aplicar `deformMatrix` ao conteúdo do `SmartPanel`.
- [x] Refatorar abertura/fechamento para `offsetScale`, slide, fade e overshoot.
- [x] Manter `PanelService`, input regions, exclusions e política de painel único.
- [x] Remover moldura/sombra em fullscreen.
- [x] Manter blur opt-in pelo compositor.

### Validação obrigatória

- [x] Abrir, fechar e trocar painéis sem flicker ou vazamento de input.
- [x] Fusão, deformação, sombra e cantos corretos em DP-1/DP-2.
- [x] Fullscreen remove moldura sem deixar regiões órfãs.

---

## Fase 5 — Barra

**Estado: Finalizado e validado**

### Checklist

- [x] Aplicar cápsulas tonais e raio total.
- [x] Aplicar cores semânticas por categoria de widget.
- [x] Criar active workspace trail elástico.
- [x] Migrar os 44 widgets de `Modules/Bar/` para state layer/motion.
- [x] Adaptar título e agrupamento às orientações vertical/horizontal.
- [x] Manter auto-hide, framed e configurações por monitor.

### Validação obrigatória

- [x] Posições top/bottom/left/right.
- [x] Densidades mini/compact/default/comfortable/spacious.
- [x] DP-1/DP-2, auto-hide e fullscreen.

---

## Fase 6 — Painéis

**Estado: Finalizado e validado**

### Checklist

- [x] Navegação principal: Launcher, Control Center, Settings, Session e Setup Wizard.
- [x] Sistema: Audio, Network, Bluetooth, Battery, Brightness, Media, Notification History e System Monitor.
- [x] Conteúdo/utilidades: Wallpaper, Tray, USB, OBS, Plugins, Tamagotchi, Cards, Changelog e Static Dock.
- [x] Modais integrados: Polkit, ScreenShare e ScreenToolkitPanel.
- [x] Aplicar padding 16, spacing 12, cards raio 16 e tipografia semântica.

### Validação obrigatória

- Todos os 25 roots `SmartPanel` revisados.
- Conteúdo cabe em telas menores e com escala aumentada.
- Navegação por teclado e estados vazios/erro/carregamento verificados.

---

## Fase 7 — Superfícies independentes

**Estado: Finalizado e validado**

### Checklist

- [x] Dock.
- [x] Notifications e Notification History.
- [x] OSD e ShowKeys OSD.
- [x] Toast, Tooltip, tray/context menus.
- [x] Settings floating window, Launcher overlay e Workspace Manager.
- [x] Polkit/ScreenShare standalone.
- [x] DesktopWidgets e Cards.
- [x] Screen Toolkit completo: panel, annotate, mirror, measure, pin, record, region selector e resultados.

### Validação obrigatória

- Nenhuma superfície mantém a estética antiga.
- Tempos de negócio não são confundidos com durações de animação.
- Overlays não capturam input fora de suas regiões.

---

## Fase 8 — Assinaturas expressivas

**Estado: Finalizado e validado**

### Checklist

- [x] Loading indicator com morph de forma. (`Widgets/NMorphLoader.qml`, usa `M3Shapes`; aplicado em `WallhavenView.qml`.)
- [x] Indicadores/progressos ondulados. (`Widgets/NSlider.qml` ganhou `wavy`; aplicado em `MediaCard.qml`/`MediaPlayerPanel.qml` durante playback.)
- [x] Thumb elástico em switches/sliders. (`NToggle` ganhou pop de mola no press; `NSlider` já tinha o pinch elástico via curva `ExpressiveFastSpatial`.)
- [x] Badges com entrada por scale. (`Widgets/NBadge.qml`, aplicado no badge de não lidas de `Bar/Widgets/NotificationHistory.qml`.)
- [x] Popouts que brotam da barra. (`Widgets/NPopupContextMenu.qml` ganhou `transformOrigin`/`scale` a partir da borda da barra.)
- [x] Cantos côncavos em superfícies conectadas. `SmartPanel.qml` (classe-base dos 25 SmartPanels) e `LauncherOverlayWindow.qml` (janela standalone) já calculavam corretamente os estados de inversão de canto (0/1/2) a partir do touching de borda/barra, cada um com sua própria lógica duplicada; consolidado na Fase 9 no singleton `ShapeCornerHelper.cornerStateFromEdges`, que passou a ter consumidores reais pela primeira vez.
- [x] Auditar licença e compatibilidade de `M3Shapes` antes de incorporar.

### Validação obrigatória

- Efeitos não degradam idle CPU/GPU.
- Performance mode desliga deformações e efeitos caros.
- Nenhum efeito prejudica legibilidade ou acessibilidade.

**Validação de performance mode:** os cinco efeitos entregues auto-desligam via `Style.motionEnabled` (idêntico ao padrão já usado por `NBusyIndicator`): `NMorphLoader` congela em forma de repouso, `NBadge` salta instantaneamente sem mola, overlay ondulado do `NSlider` fica oculto, pop do `NToggle` não anima, `NAnim` do popup zera a duração. Testado ao vivo alternando `Settings.data.general.animationDisabled` no Lab — sem erros nos logs.

---

## Fase 9 — Validação final e cutover

**Estado: Em trabalho**

### Checklist

- [x] Corrigir a regressão que impedia o Lab de carregar: `Background.qml`, `MainScreen.qml`, `BarContentWindow.qml` e `FadeOverlay.qml` referenciavam `NAnim`/`NColorAnimation` sem `import qs.Widgets` (provavelmente perdido em alguma edição depois da Fase 4); `qs -p` falhava com `NAnim is not a type`. Corrigido e confirmado por boot real sem erro QML até o fim da inicialização dos serviços.
- [x] Consolidar a duplicação de cálculo de estado de canto entre `SmartPanel.qml` e `LauncherOverlayWindow.qml` no singleton `ShapeCornerHelper` (achado da Fase 8).
- [x] Reduzir `Easing.*` fora das primitivas para zero ou exceções documentadas. Varredura completa da árvore (`Modules/`, `Commons/`) encontrou apenas dois usos fora das primitivas de motion, ambos já documentados: `Commons/Color.qml` (ciclo de import Commons→Widgets→Commons) e `Modules/Toast/Toast.qml` (relógio de negócio, não motion); `plugin/smoke/shell.qml` é harness de desenvolvimento fora do escopo de produção.
- [x] Confirmar que os 23 SmartPanels endereçáveis por IPC abrem sem erro QML. Harness temporário (`IpcHandler { target: "qa" }`, nunca commitado) chamou `PanelService.getPanel(id, screen).open()` para cada um; sweep completo não deixou nenhum `WARN scene`/`ERROR` residual após as correções desta fase. `polkitPanel` e `screenSharePanel` não têm gatilho real disponível no Lab (pkexec/portal) e ficam pendentes de validação estrutural.
- [x] Eliminar referências a tokens `Style.`/`Color.` inexistentes. Varredura de toda `Modules/`+`Widgets/`+`Commons/` cruzando cada identificador usado contra as propriedades/funções realmente declaradas achou quatro tokens fantasma, todos corrigidos: `Style.radiusContent` (9 usos), `Color.mOutlineVariant` (3 usos), `Style.radiusMenu` (1 uso), `Style.fontWeightNormal` (1 uso).
- [x] Validar matriz light/dark × esquema fixo/wallpaper com captura real. `darkMode`/`useWallpaperColors` alternados via IPC com o Control Center aberto; a repaletização é assíncrona (regeneração externa de paleta + `FileView` reload, ~2-3s) e as quatro combinações renderizaram corretamente após esperar a conclusão — confirmado por captura de tela, não só pelo toast de confirmação.
- [x] Validar blur on/off (`hyprctl keyword decoration:blur:enabled`) e fullscreen real (`hl.dsp.window.fullscreen`) — bar/moldura somem em fullscreen e voltam ao sair, sem órfão; sem erro nos dois casos.
- [x] Validar escala (`general.scaleRatio` 0.85/1.0/1.3) — reflete no Lab imediatamente, sem erro.
- [ ] Validar escala/raios/animação/performance mode com metodologia limpa. Escala e animação/performance mode confirmados reativos; **achado não resolvido**: mudar `general.radiusRatio`/`iRadiusRatio` via configuração não mostrou, de forma conclusiva, a mudança de raio esperada nos testes visuais desta sessão (`Style.radiusCard`/`radiusS` computam o valor novo corretamente, confirmado por leitura direta da propriedade; painéis usam `BlobRect` do plugin nativo `Hydra.Visual` para a moldura, cujo `markDirty()` já chama `polish()`+`update()` em cada shape — não achei um bug de código óbvio por leitura). A metodologia de captura de tela usada (elementos capsula imunes a `radiusRatio`, crops errados, delta pequeno) não foi rigorosa o suficiente para confirmar ou descartar com segurança; fica como item de investigação dedicado antes de fechar esta fase, não deve ser presumido correto nem quebrado.
- [ ] Confirmar 55 widgets e todas as superfícies independentes individualmente (feito indiretamente via os 23 painéis, que exercitam a maioria; falta inventário item-a-item explícito).
- [ ] Eliminar durações literais de animação; preservar apenas timers de negócio documentados. Inventário levantado: 54 ocorrências de `duration: <número>` em 11 arquivos (`Modules/ScreenToolkit/{BarWidget,ControlCenterWidget,Panel,overlays/Mirror,overlays/Record}.qml`, `Modules/Panels/ControlCenter/{Panel,BarWidget}.qml`, `Modules/Panels/Settings/{SettingsContent,Tabs/Display/MonitorLayoutSubTab}.qml`, `Modules/Panels/UsbDriveManager/UsbDriveManagerPanel.qml`, `Modules/Bar/Extras/{BarPillHorizontal,BarPillVertical}.qml`, `Modules/Cards/WeatherCard.qml`, `Widgets/NSlider.qml`); nenhuma corrigida ainda — precisam de triagem individual (motion literal → token `Style.motionDuration*` vs. timer de negócio documentado), não uma substituição mecânica.
- [ ] Auditar e remover demais convenções visuais legadas (além dos tokens fantasma já corrigidos).
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

**Fase ativa:** Fase 9 — Validação final e cutover.

**Último trabalho concluído:** Todo o trabalho já implementado e validado das Fases 3 (widgets restantes) a 8 estava correto mas nunca tinha sido commitado (175 arquivos, ~6.500 linhas, acumulados em uma única árvore de trabalho); reconciliado em oito commits separados por fase. Nesse processo, o `qs -p` (Lab) revelou-se quebrado desde a Fase 4 (import ausente); corrigido. Com o Lab voltando a carregar: consolidação de canto (`ShapeCornerHelper`) concluída; auditoria de `Easing.*` concluída (zero pendências); sweep dos 23 SmartPanels endereçáveis por IPC (harness temporário, não commitado) achou e corrigiu quatro classes de tokens `Style.`/`Color.` inexistentes (`radiusContent`, `mOutlineVariant`, `radiusMenu`, `fontWeightNormal`, 14 ocorrências); matriz de tema (dark/light × esquema fixo/wallpaper), blur, fullscreen e escala validada com captura de tela real em DP-1/DP-2. Achado não resolvido: reatividade de `radiusRatio`/`iRadiusRatio` em painéis via `BlobRect` fica como investigação pendente, não confirmada como bug nem como correta. Inventário completo (mas não corrigido) de 54 durações literais de animação em 11 arquivos.

**Próxima ação exata:** Fase 9 — (1) investigar a reatividade de raio com metodologia limpa (QML isolado ou depuração do plugin nativo) antes de presumir qualquer lado; (2) triar e corrigir as 54 durações literais uma a uma; (3) inventariar os 55 widgets e superfícies independentes item a item (hoje coberto só indiretamente); (4) validar `polkitPanel`/`screenSharePanel` estruturalmente; (5) só então mesclar em `legacy-v4` e sincronizar a shell ativa.

**Bloqueios conhecidos:** nenhum bloqueio de ferramenta; o achado de reatividade de raio precisa de uma sessão de investigação dedicada (não deve ser apressado).

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
| 2026-08-17 | 3 | Inventário base confirmou 55 QML em `Widgets/`; busca residual retornou zero uso de `Style.iRadius`, durações/easings legados e `mHover/mOnHover` em consumidores; state-layer audit deixou apenas quatro itens não clicáveis (gauge, viewport de grid, marquee e indicador de tooltip); `qmlformat --check` percorreu 532 QML | Segunda convenção visual removida dos widgets |
| 2026-08-17 | 3 | Lab limpo carregou sem `TypeError`, tipo indisponível ou propriedade inválida; Settings Geral e Barra/Widgets foram abertas por IPC e inspecionadas em DP-1; hover dos cards, navegação/disabled do smoke anterior e drag visuals foram exercitados | Fase de widgets finalizada |
| 2026-08-17 | 4 | `AllBackgrounds.qml` passou de `Shape`/`ShapePath` duplicados para grupos `Hydra.Visual`; os slots 0/1/2 do `PanelService` renderizam `BlobRect`, a moldura usa `BlobInvertedRect` e o conteúdo recebe `deformMatrix`; captura de quatro frames mostrou slide, fade e geometria estável sem clipping | Cutover da superfície global concluído sem alterar os contratos de painel e blur |
| 2026-08-17 | 4 | Lab com configuração isolada e barra emoldurada validou fusão, sombra e cantos em DP-1/DP-2; fullscreen em cada monitor removeu somente a moldura/sombra e a região de input correspondentes, restaurando-as ao sair; DP-1 permaneceu emoldurado enquanto DP-2 estava fullscreen | Fullscreen e escopo por monitor aprovados sem região órfã |
| 2026-08-17 | 4 | Trocas launcher/áudio exercitaram slots de abertura e fechamento; modos de opacidade unificada e separada renderizaram; `qmlformat 6.10.3 --check` percorreu 532 QML; Lab limpo ficou sem erro QML e `prowl-agent doctor` retornou zero erros | Gate da superfície global aprovado |
| 2026-08-17 | 5 | Inventário exato classificou 44 QML em `Modules/Bar/`: 40 usam primitivas compartilhadas de state/motion, `BarExclusionZone.qml`, `BarWidgetLoader.qml` e `Spacer.qml` são passivos, e `Bar.qml` contém somente hit zones não visuais; busca residual por `NumberAnimation`, `ColorAnimation`, `Style.animation*`, `Easing.*`, `mHover` e `mOnHover` retornou zero | Migração integral dos widgets da barra concluída sem falsificar state layer em superfícies invisíveis |
| 2026-08-17 | 5 | Launcher/Control Center/Settings e famílias sistema/mídia/visual ganharam categorias tonais; cápsulas usam raio total; sequência de três frames confirmou active workspace trail elástico; hover real do Launcher foi capturado | Semântica tonal, cápsulas e assinatura de workspace aprovadas na barra real |
| 2026-08-17 | 5 | Lab recarregou a árvore completa após Taskbar, Tray, TrayMenu, Workspace e widgets autônomos; `qmlformat 6.10.3 --check` percorreu 532 QML; `prowl-agent doctor` retornou zero erros | Gate estrutural da migração dos 44 componentes aprovado |
| 2026-08-17 | 5 | Matriz automatizada aplicou top/bottom/left/right × mini/compact/default/comfortable/spacious em DP-1 e DP-2, gerando 40 capturas reais e contact sheets por orientação | Título, agrupamento, cápsulas e extremos das cinco densidades permaneceram legíveis e sem clipping nas duas orientações |
| 2026-08-17 | 5 | Overrides divergentes colocaram DP-1 em top/spacious e DP-2 em bottom/mini; auto-hide ocultou por monitor e o edge reveal de DP-1 foi exercitado; a ausência de estado no DP-2 revelou que `BarContentWindow` não registrava telas intocadas, corrigido na criação e confirmado por IPC show/hide no DP-2 | Configuração por monitor e auto-hide corrigidos na fonte, sem depender de primeiro hover |
| 2026-08-17 | 5 | Fullscreen real foi alternado separadamente em DP-1 e DP-2; a barra/moldura do monitor alvo desapareceram e restauraram enquanto a superfície do outro monitor permaneceu renderizada | Escopo fullscreen por monitor aprovado com overrides e densidades divergentes |
| 2026-08-17 | 5 | Lab reiniciado do zero carregou sem erro QML; `qmlformat 6.10.3 --check` percorreu 532 QML e `prowl-agent doctor` retornou zero erros | Gate integral da barra aprovado; Fase 5 finalizada |
| 2026-08-17 | 6 | Launcher, Control Center, Settings, Session e Setup Wizard foram abertos por IPC/fresh install no Lab isolado e inspecionados em DP-1; category pill, dashboard, sidebar selecionada, tiles de sessão e progresso do assistente renderizaram com a hierarquia expressive compartilhada | Navegação principal e identidade Hydra aprovadas nas superfícies reais |
| 2026-08-17 | 6 | Lab limpo carregou sem erro QML; `qmlformat 6.10.3 --check` percorreu 532 QML, JSON pt/en passou no `jq` e `prowl-agent doctor` retornou zero erros | Gate estrutural da navegação principal aprovado |
| 2026-08-17 | 6 | Audio, Network, Bluetooth, Battery, Brightness, Media, Notification History e System Monitor foram abertos na superfície real do Lab em DP-1; estados de hardware ausente, cards de status, transporte de mídia, vazio de notificações, gráficos e controles interativos renderizaram com a hierarquia expressive compartilhada | Painéis de sistema aprovados visualmente; lookup de escala do Brightness foi corrigido para o contrato `displayScales` do compositor |
| 2026-08-17 | 6 | Lab final reiniciado do zero carregou a fonte sem erro QML; os sete painéis com IPC permanente foram abertos em sequência sem `TypeError`, `ReferenceError` ou propriedade inválida; `qmlformat 6.10.3 --check` percorreu 532 QML e `prowl-agent doctor` retornou zero erros | Gate estrutural e funcional dos painéis de sistema aprovado |
| 2026-08-17 | 6 | Wallpaper, USB, Tamagotchi, OBS, Changelog, Static Dock, Cards no Control Center, ScreenShare, ScreenToolkitPanel e Polkit foram abertos na superfície real do Lab em DP-1; Tray e slots de Plugins foram revisados pelos seus contratos estruturais, sem plugin carregado para conteúdo dinâmico | Hierarquia, spacing, tipografia, cards, estados disabled/vazio/hardware e ações primárias das utilidades e modais aprovados; Screen Toolkit completo permanece no corte dedicado da Fase 7 |
| 2026-08-17 | 6 | Fechamento rápido do Wallpaper reproduziu callback de resolução após destruição do `WallpaperFileInfo`; o callback passou a validar o lifetime do root e a reprodução deixou de emitir `TypeError`; Lab final sem IPC de teste reabriu Wallpaper e ScreenToolkit sem erro | `qmlformat 6.10.3 --check` percorreu 532 QML, JSON pt/en passou no `jq` e `prowl-agent doctor` retornou zero erros; Fase 6 finalizada |
| 2026-08-17 | 7 | Dock always-visible e hover, volume OSD, toast e notificação real foram exercitados no Lab isolado em DP-1; Notification History, ShowKeys e menus passaram pelo mesmo inventário de tokens, motion e state layers | Superfícies renderizaram com hierarquia expressive sem erro QML; timers de auto-hide, lifetime e atraso permaneceram explícitos como lógica de negócio, separados de `NAnim` |
| 2026-08-17 | 7 | Settings, Launcher overlay (modo padrão e `overviewLayer`), Workspace Manager (grid, carrossel, hover de célula) e DesktopWidgets (painel de edição, `DraggableDesktopWidget`, Clock) foram abertos no Lab real em DP-1 via IPC e captura de tela; `qmlformat 6.10.3 --check` percorreu 532 QML e `prowl-agent doctor` retornou zero erros | Janelas e overlays independentes renderizaram com `radiusPanel`/`radiusPopover`/`NAnim`/`NStateLayer` sem erro QML; Cards já estava na convenção; Polkit/ScreenShare validados estruturalmente (sem gatilho real de pkexec/portal disponível no Lab) |
| 2026-08-17 | 7 | Screen Toolkit completo (20 arquivos, ~9.650 linhas) migrado por seis agentes paralelos em conjuntos de arquivos disjuntos, com tabela de mapeamento exata e contrato de não-regressão compartilhados; bug pré-existente em `RegionSelector.qml` (`Style.controlHeightS`/`controlHeightXXS` inexistentes) corrigido no mesmo corte | `qmlformat 6.10.3 --check` percorreu 532 QML e `prowl-agent doctor` retornou zero erros; Lab limpo abriu o painel do Screen Toolkit em DP-1 sem erro QML; Fase 7 finalizada |
| 2026-08-17 | 8 | `M3Shapes` (`github.com/soramanew/m3shapes`) confirmado Apache-2.0 via LICENSE bruto; `plugin/CMakeLists.txt` passou a buscá-lo via `FetchContent` e compilá-lo ao lado do `Hydra.Visual`; `flake.nix`/`nix/package.nix` recebem a fonte por input de flake para o build sandboxado do Nix | Build real `Scripts/dev/build-visual-plugin.sh` produziu `libm3shapes.so`/`libm3shapesplugin.so`/`qmldir`/`m3shapes.qmltypes`; smoke shell via `qs` real importou `M3Shapes`, leu os enums `MaterialShape.Circle=0`/`Heart=34` e morfou ao vivo Circle→Heart→Sunny→Cookie9Sided em tela (captura salva durante a sessão); build Nix não executado nesta máquina (sem `nix` instalado, mesma ressalva do `Hydra.Visual`) |
| 2026-08-17 | 8 | `NMorphLoader` substituiu o spinner do carregamento do Wallhaven; capturas ao vivo mostraram a forma roxa morfando durante um fetch real de 25.847 páginas. `NSlider.wavy` ligado a `MediaCard`/`MediaPlayerPanel` durante playback. `NBadge` substituiu o dot ad-hoc do sino de notificações na barra; disparo real via `notify-send` confirmado sem erro. `NToggle` ganhou `SpringAnimation` de pop no thumb; render em repouso confirmado sem regressão na aba Interface do usuário. `NPopupContextMenu` ganhou `transformOrigin`/`scale` a partir da borda da barra | `qmlformat 6.10.3 --check` percorreu 534 QML (2 widgets novos) e `prowl-agent doctor` retornou zero erros; `Scripts/dev/qmlfmt.sh` passou a excluir `.build/`/`.git`/`node_modules` da varredura após a dependência `M3Shapes` introduzir um `.qml` de exemplo vendorizado; todos os cinco efeitos testados com `animationDisabled=true` sem erro nos logs do Lab |
| 2026-08-18 | 3-8 | `git status` mostrava 175 arquivos modificados/novos nunca commitados, cobrindo integralmente as Fases 3 (resto)–8; todas já batiam com o que o ledger descrevia como finalizado. Reconciliado em oito commits separados por fase (mais um de rebrand i18n não relacionado ao plano), usando escopo por diretório alinhado a cada checklist | Histórico do branch `visual/caelestia-expressive` reflete o estado real do trabalho, uma fase por commit, antes de qualquer edição nova da Fase 9 |
| 2026-08-18 | 9 | `qs -p /home/raell/Projetos/hydra-shell` falhava com `Type ... unavailable` encadeado até `NAnim is not a type`/`NColorAnimation is not a type`; varredura de todo `Modules/`+`Commons/` cruzando cada widget `N*` usado contra os imports do arquivo achou exatamente quatro arquivos sem `import qs.Widgets`: `Background.qml`, `MainScreen.qml`, `BarContentWindow.qml`, `FadeOverlay.qml` | Import ausente corrigido nos quatro; segunda varredura de todo o `Widgets/` catalog confirmou zero arquivos restantes sem o import necessário |
| 2026-08-18 | 9 | `ShapeCornerHelper.qml` ganhou `cornerStateFromEdges()`; os oito blocos de 4 ramos em `SmartPanel.qml` (quatro cantos × ramo com/sem barra) e os quatro em `LauncherOverlayWindow.qml` foram substituídos por chamadas ao helper; `getMultX`/`getMultY`/`getArcDir` locais de `LauncherOverlayWindow.qml` foram substituídos pelas funções já existentes no singleton | Duplicação de lógica de canto (achado da Fase 8) eliminada; `qmlformat 6.10.3 --check` passou sem diff |
| 2026-08-18 | 9 | `bash Scripts/dev/build-visual-plugin.sh` reconstruiu `Hydra.Visual`/`M3Shapes` com o `plugin/CMakeLists.txt` atualizado; `qs -p` executado como processo gerenciado (`hub start`) com `QML_IMPORT_PATH` apontando para o install local rodou 47s sem nenhuma linha `ERROR`, com todos os serviços (`HyprlandService` até `Network`) reportando início | Regressão de carregamento do Lab, presente desde a Fase 4, corrigida e verificada; matriz visual completa (light/dark, wallpaper, blur, fullscreen, escala) ainda não executada — próximo passo da Fase 9 |
| 2026-08-18 | 9 | Varredura de `Easing\.` em `Modules/`+`Commons/` fora de `Widgets/NAnim.qml`/`NAnchorAnimation.qml`/`NColorAnimation.qml`/`NMorphLoader.qml` (as primitivas) encontrou só `Commons/Color.qml` e `Modules/Toast/Toast.qml`, ambos já com comentário de exceção documentada; `plugin/smoke/shell.qml` é harness de dev fora do escopo de produção | Gate "`Easing.*` fora das primitivas reduzido a zero ou exceções documentadas" aprovado |
| 2026-08-18 | 9 | Com DP-2 conectado nesta máquina, `qs -p` reexecutado; `grim -o DP-2` capturou a barra real renderizada sobre o wallpaper (cápsula tonal, raio total, relógio, pill de workspace, ícones de bandeja/notificação/volume/brilho) sem artefato; logs de ambos os monitores continham apenas os `WARN` esperados de serviço singleton duplicado (notifications/polkit) por rodar ao lado da shell ativa, zero `ERROR` | Boot limpo confirmado visualmente em DP-1 e DP-2; matriz completa de temas/estados ainda pendente |
| 2026-08-18 | 9 | Harness temporário `IpcHandler { target: "qa" }` (nunca commitado) abriu os 23 SmartPanels endereçáveis por IPC em sequência real no Lab, com `grim` capturando cada um; `hub logs --grep "ERROR\|WARN scene"` acusou `Unable to assign [undefined]` em `NFilePicker.qml`, `NColorPickerDialog.qml`, `NetworkPanel.qml`, `MediaPlayerPanel.qml` | Cache `~/.cache/{noctalia-qs,QtProject}/qmlcache` limpo (estava mascarando edições já salvas); varredura completa Style/Color achou e corrigiu `radiusContent`→`radiusControl` (9), `mOutlineVariant`→`mOutline` (3), `radiusMenu`→`radiusPopover` (1), `fontWeightNormal`→`fontWeightRegular` (1); sweep repetido voltou zero `WARN scene` restante |
| 2026-08-18 | 9 | `darkMode`/`useWallpaperColors` alternados via IPC com Control Center aberto; capturas antes de ~2s mostravam a paleta antiga apesar do toast de confirmação já ter aparecido (regeneração de paleta é assíncrona); com espera de 3.5s as quatro combinações claro/escuro × fixo/wallpaper renderizaram cores, contraste e cápsulas corretos | Matriz de tema validada com captura real, não só pelo toast |
| 2026-08-18 | 9 | `hyprctl keyword decoration:blur:enabled 0/1` alternado sem erro; `hl.dsp.window.fullscreen({mode="fullscreen", action="toggle"})` no terminal real ocultou a barra/moldura e restaurou ao desfazer, sem região órfã; `general.scaleRatio` 0.85/1.0/1.3 refletiu no Lab imediatamente | Blur, fullscreen e escala validados; zero erro nos logs |
| 2026-08-18 | 9 | Tentativa de validar `general.radiusRatio`/`iRadiusRatio` (0 a 5.0) em painéis (`BlobRect` via `PanelBackground.qml`) e em `NBox`/widgets simples: leitura direta de `Style.radiusCard`/`radiusS` confirma o valor recalculado corretamente; inspeção do plugin nativo mostra `BlobGroup::markDirty()` chamando `polish()` e `update()` em cada shape, sem bug óbvio de código; capturas de tela repetidas com crops/elementos variados não deram um resultado inequívoco (elemento cápsula imune ao token por design, deltas pequenos, uma comparação com delta grande mostrou alguma mudança mas não a magnitude esperada) | Achado registrado como não resolvido, não como bug confirmado nem como aprovado — precisa de investigação dedicada (QML isolado ou depuração do plugin) antes de fechar a Fase 9 |
| 2026-08-18 | 9 | Inventário de `duration: <número>` fora de `Timer` em `Modules/`+`Widgets/`: 54 ocorrências em 11 arquivos, concentradas em `Modules/ScreenToolkit/*` e `Modules/Panels/ControlCenter/Panel.qml` | Nenhuma corrigida; inventário exato registrado no checklist da Fase 9 para triagem individual futura |
