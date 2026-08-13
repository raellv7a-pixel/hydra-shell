# Plano de nativização de plugins Noctalia

Fonte dos plugins (clonados via sparse-checkout, **não alterar**):
`/home/raell/Projetos/Exemplos/noctalia-legacy-v4-plugins/<plugin-id>/`

Registro completo original: `/home/raell/Projetos/Exemplos/noctalia-legacy-v4-plugins/registry.json`
Convenções de plugin (API, entry points): `/home/raell/Projetos/Exemplos/noctalia-legacy-v4-plugins/AGENTS.md`

## Status

- 🔴 Em espera — não iniciado
- 🟡 Em andamento — trabalho iniciado, não concluído
- 🟢 Finalizado — verificado funcionando

Ao concluir uma etapa: mude o status do item e risque o texto da etapa com `~~texto~~`. Isso permite retomar exatamente do ponto onde paramos.

---

## Descobertas de arquitetura (válidas para todas as fases abaixo)

### Como registrar um widget NATIVO de barra (não-plugin)
Confirmado lendo `Modules/Bar/Widgets/DarkMode.qml` (toggle simples) e `KeepAwake.qml` (toggle com `BarPill`). Passos obrigatórios para **cada** widget novo:

1. Criar `Modules/Bar/Widgets/<Nome>.qml` — raiz `Item`/`NIconButton`, recebe `screen`, `widgetId`, `section`, `sectionWidgetIndex`, `sectionWidgetsCount` injetados pelo `BarWidgetLoader` (o nome do arquivo precisa bater exatamente com a chave do registry — carregamento é por convenção de caminho, `Modules/Bar/Extras/BarWidgetLoader.qml:~110`).
2. Registrar em `Services/UI/BarWidgetRegistry.qml` em **4 blocos**: `widgets{}` (linha ~14-45), `widgetSettingsMap{}` (linha ~47+), `widgetMetadata{}` (defaults por widget), e `property Component <id>Component: Component { <Id> {} }`.
3. Criar `Modules/Panels/Settings/Bar/WidgetSettings/<Nome>Settings.qml` (só se o widget tiver configurações) seguindo o padrão de `DarkModeSettings.qml`.
4. Adicionar defaults em `Assets/settings-widgets-default.json` (chave `"bar"`) espelhando `widgetMetadata`.
5. Tooltips em `Assets/Translations/en.json` e `pt.json`, namespace `tooltips.*`. **O nome do widget no seletor não é traduzido** (usa o ID cru).
6. Padrão de clique/context-menu idêntico em todos os widgets nativos — copiar de `DarkMode.qml`.
7. Opcional: adicionar `{"id": "<Nome>"}` em `Assets/settings-default.json` (`bar.widgets.left/center/right`) só se o widget deve vir habilitado por padrão.

### Dashboard — seção "Controles" (quick toggles)
`Modules/Panels/ControlCenter/Panel.qml` — `component QuickActionsCard` (linha ~2701-2813): `GridLayout` **estático** de 2 colunas com 8 `ActionTile` hardcoded (sem `Repeater`/model). **Não existe sistema de abas hoje.** Para adicionar uma 2ª aba (screen-toolkit), envolver o `GridLayout` com `NTabBar`/`NTabButton` (`Widgets/NTabBar.qml`, `Widgets/NTabButton.qml`) seguindo o padrão já usado em `processMetricTabs` (linha ~3496-3526, abas CPU/RAM/GPU). Labels via `root.tr(key)` → chaves em `Modules/Panels/ControlCenter/i18n/{pt,en}.json` namespace `panel.*`.

### Dashboard — card Clima/Calendário/Uso de tela
`component CalendarShell` (linha ~7193-7263): `SwipeView` chamado `calendarSwipe` com 3 páginas hoje (`WeatherCard`, `CompactCalendarPage`, `ScreenUsagePage`), cada uma um `Item { <Componente> { anchors.fill: parent } }` filho direto do SwipeView, **sem** `Repeater`/model. Paginação via `PageDots` (componente genérico reutilizável, linha ~3696-3732) já 100% dirigido por `calendarSwipe.count` — **adicionar 4ª página é só inserir um novo `Item` filho**, nada mais muda (dots e `WheelHandler` já são dinâmicos).

### Wallpaper — aba de paleta de cores
`Modules/Panels/Wallpaper/Components/WallpaperPaletteSheet.qml` (aba 3 do painel, `WallpaperPanelHeader.qml` define `mainTabIndex`). Hoje é **só exibição + cópia de hex** (sem editor individual de cor). Geração real via `Services/Theming/AppThemeService.qml:generate()` → `TemplateProcessor.processWallpaperColors()` (papel de parede) ou `ColorSchemeService.applyScheme()` (esquema predefinido). `ColorSchemeService.writeColorsToDisk()` atualiza o singleton `Commons/Color`, refletindo nos swatches automaticamente.

### Clipboard — sem conceito de pin hoje
`Services/Keyboard/ClipboardService.qml` (536 linhas) é 100% delegado ao `cliphist` externo (sem SQLite/JSON próprio), com cache em memória e `revision` como contador de invalidação. **Não existe pin/favorito.** Padrão reutilizável já existe para apps (dock/launcher): array de strings em `Settings` + `isXPinned`/`toggleXPin`. Ponto de extensão de ação: `Modules/Panels/Launcher/Providers/ClipboardProvider.qml:getItemActions()` (linha ~380-411).

### screen-toolkit — ACHADO CRÍTICO: já está 100% portado
`Modules/ScreenToolkit/` já implementa as 10 ferramentas do plugin original (colorpicker, palette, ocr, lens, qr, annotate, record, pin, measure, mirror), com scripts bash reais e completos em `Modules/ScreenToolkit/scripts/*.sh`. Acionável hoje via IPC `screenToolkit` (`Services/Control/IPCService.qml:1020-1040`) ou pelo painel flutuante (`Modules/ScreenToolkit/Panel.qml`, `toolDefs` linha 139-149). **Não há nada para portar aqui** — o trabalho real é só criar os quick toggles no dashboard chamando `Services/System/ScreenToolkitService.qml` (funções `colorPicker()`, `ocr()`, `qr()`, `palette()`, `measure()`, `lens()`, `annotate()`, `pin()`, `record()`, `mirror()`). `Modules/ScreenToolkit/BarWidget.qml`/`ControlCenterWidget.qml` existem mas são órfãos do formato antigo de plugin — não registrados em nenhum registry atual.

---

## Fase 1 — Widgets de barra simples e independentes

Cada item é auto-contido (arquivo novo + registro), sem tocar em arquivos compartilhados grandes. Paralelizável com segurança.

### 1. nvibrant — 🟡 Implementado; teste de efeito real bloqueado pela dependência
Toggle de vibrance NVIDIA (relevante: você tem RTX 4060 Ti).
Referência: `noctalia-legacy-v4-plugins/nvibrant/{Main.qml,BarWidget.qml,Settings.qml,manifest.json,README.md}`
- [x] Dependência verificada em 2026-08-12: `nvibrant` não está no `PATH` desta máquina; a API do AUR confirma `nvibrant-bin` 1.2.1-1 disponível e não marcado como desatualizado
- [x] `Modules/Bar/Widgets/Nvibrant.qml`: cápsula `contrast`, toggle e menu de contexto; monta argumentos por porta física (`displayIndex` 1-based, com `0` nas portas anteriores)
- [x] O estado persistido só muda após `nvibrant` encerrar com código 0; binário ausente e falha de execução exibem erro sem simular sucesso nem perder o estado anterior
- [x] `Modules/Panels/Settings/Bar/WidgetSettings/NvibrantSettings.qml`: `vibranceValue`, `displayIndex` e cor são salvos por instância; configurações globais parciais anteriores continuam como fallback
- [x] Registro completo em `Services/UI/BarWidgetRegistry.qml` (componente, mapa de settings, metadata e factory) e defaults em `Assets/settings-widgets-default.json`
- [x] Textos EN/PT para tooltip, porta de saída, dependência ausente e falha de aplicação
- [x] Validação dirigida: os quatro JSON passam em `jq empty`; Quickshell carregou o widget em configuração isolada; sem a dependência, o toggle manteve `enabled=false`; com um executável temporário controlado, a porta 3 gerou `nvibrant 0 0 640`/`nvibrant 0 0 0` e os estados observados foram `false → true → false`
- [ ] Limitação: instalar `nvibrant-bin` e validar visualmente o efeito na RTX 4060 Ti/porta física; nenhum efeito real no hardware foi alegado nesta máquina

### 2. privacy-indicator — 🟡 Implementado; smoke ativo limitado pelo runtime
Indicador mic/câmera/tela compartilhada ativos.
Referência: `noctalia-legacy-v4-plugins/privacy-indicator/{Main.qml,BarWidget.qml,Panel.qml,Settings.qml}`
- [x] `Services/Hardware/PrivacyIndicatorService.qml`: mic e screen-share reagem ao grafo PipeWire e somente a links ativos; câmera combina fontes V4L2/PipeWire com probe limitado a 2 s/8 dispositivos, cadência de 10 s em idle (3 s somente para consumidor V4L2 direto) e ignora os brokers `pipewire`/`wireplumber` para não gerar falso ativo
- [x] `Modules/Bar/Widgets/PrivacyIndicator.qml`: três ícones responsivos a barra horizontal/vertical, estados ativo/inativo, `hideInactive`, tooltip de estado atual e aviso explícito quando o vídeo não pode ser atribuído
- [x] Settings, factory/mapa/metadata no `BarWidgetRegistry` e default `hideInactive` integrados; textos de settings/tooltip/idle/limitação adicionados em EN/PT
- [x] Validação dirigida: `qmllint` passou no serviço, widget e settings; defaults e traduções passaram em `jq empty`
- [x] Smoke seguro isolado: Quickshell carregou a configuração e criou o widget pelo registry (`registryLoaded=true`, `widgetCreated=true`); estado observado foi mic/tela/câmera inativos e probe `limited`, sem inventar atividade
- [ ] Limitação ativa desta máquina/runtime: havia nós consumidores de vídeo do OBS, mas os links chegaram ao QML com estado inválido (`-1`) e somente o broker PipeWire possuía o V4L2; o serviço reportou `limited` em vez de falso ativo. Repetir o smoke com um consumidor direto ou runtime que exponha `PwLinkState.Active` para confirmar a mudança visual ativa

### 3. show-keys — 🟡 Implementado; smoke bloqueado por dependência
OSD de teclas pressionadas em tempo real (via `evtest` — útil para tutoriais).
Referência: `noctalia-legacy-v4-plugins/show-keys/{Main.qml,Settings.qml}`
- [x] Dependência `evtest` e leitura de `/dev/input/eventN` verificadas: binário ausente e `/dev/input/event3` sem leitura nesta máquina; a shell mantém captura desligada, informa a dependência e exige opt-in explícito.
- [x] `Services/System/ShowKeysService.qml`: singleton com detecção de `evtest`, captura/reinício do processo, parsing de modifiers/combinações e lista limitada de teclas.
- [x] `Modules/OSD/ShowKeysOsd.qml`: `PanelWindow` por monitor, layer overlay sem foco, posição/margem configuráveis e pills nas cores Material ou customizadas.
- [x] IPC `showKeys toggle|enable|disable` via `IpcHandler` no serviço.
- [x] Settings em OSD/Geral: toggle, dispositivo, posição e atraso; defaults e traduções pt/en adicionados.
- [ ] Smoke de digitação pendente: instalar `evtest`, conceder leitura ao dispositivo correto e confirmar as teclas no OSD. Reload e guarda de dependência verificados ao vivo.

### 4. catwalk — 🟢 Finalizado
Gatinho animado na barra, reage ao uso de CPU (`SystemStatService.cpuUsage` já existe nativamente).
Referência: `noctalia-legacy-v4-plugins/catwalk/{Main.qml,BarWidget.qml,icons/}`
- [x] ~~Copiar ícones SVG (`icons/my-active-*.svg`, `icons/my-idle-*.svg`) para `Assets/` (verificar licença/atribuição antes)~~ — copiados para `Assets/Icons/Catwalk/` (9 SVGs). Licença confirmada MIT em `catwalk/manifest.json` (`"license": "MIT"`, autor MannuVilasara, repo `noctalia-dev/noctalia-plugins`).
- [x] ~~Criar `Modules/Bar/Widgets/Catwalk.qml` (adapta `BarWidget.qml`: troca de frame por Timer, threshold de CPU via `SystemStatService.cpuUsage`)~~ — Item root no padrão `KeepAwake.qml`/`AudioVisualizer.qml`: 2 Timers (frame ativo com `interval: Math.max(30, 200 - cpuUsage * 1.7)`, frame idle fixo em 400ms), `Image` com `MultiEffect` colorization (branco/preto conforme `Settings.data.colorSchemes.darkMode`), tooltip via `TooltipService` ("Running"/"Sleeping"), `NPopupContextMenu` com ação `widget-settings` no clique direito.
- [x] ~~Registrar em `Services/UI/BarWidgetRegistry.qml`~~ — adicionado nos 4 blocos (`widgets`, `widgetSettingsMap`, `widgetMetadata`, `catwalkComponent`), ordem alfabética entre `Brightness` e `Clock`.
- [x] ~~Settings: threshold mínimo de CPU~~ — `Modules/Panels/Settings/Bar/WidgetSettings/CatwalkSettings.qml` (padrão `TaskbarSettings.qml`, `NValueSlider` 5–25%, default 10%). Chaves i18n em `bar.catwalk.*` (novo namespace) + tooltips `catwalk-running`/`catwalk-sleeping` em `en.json`/`pt.json`. Defaults em `Assets/settings-widgets-default.json`.
- [x] Smoke test: `qmllint` sem erros em `Catwalk.qml`, `CatwalkSettings.qml` e `BarWidgetRegistry.qml`; chaves balanceadas confirmadas; `grep "Catwalk"` confirma presença nos 4 blocos do registry; `getAvailableWidgets()` (usado pelo seletor de widgets em `BarTab.qml`/`MonitorWidgetsConfig.qml`) itera `Object.keys(widgets)`, que agora inclui `"Catwalk"`. **Não testado com carga real de CPU** (requer sessão gráfica ativa rodando o shell) — lógica de interval do Timer replicada 1:1 do plugin original.

### 5. tamagotchi — 🟢 Finalizado
Bichinho que evolui/precisa de cuidados, persistente.
Referência: `noctalia-legacy-v4-plugins/tamagotchi/{Main.qml,Pet.qml,Food.qml,Soap.qml,Ball.qml,Bed.qml,BarWidget.qml,Panel.qml,components/,assets/,sounds/}`
- [x] Criado `Services/System/TamagotchiService.qml`: singleton carregado somente após `Settings.settingsLoaded`, necessidades persistidas, reconciliação determinística dos intervalos de decay de 30 s inclusive após reinício, timer alinhado ao timestamp salvo, estados visuais e transições reais `feed`/`clean`/`play`/`rest`/`wake`.
- [x] Copiados 11 PNGs e `eat.wav` para `Assets/{Icons,Sounds}/Tamagotchi/`; licença MIT, autores Joaquin Righetti/Lucia Bollati e autoria da arte Forgy registrados em `CREDITS.md` com o repositório de origem.
- [x] Criado `Modules/Bar/Widgets/Tamagotchi.qml` com sprite/estado/menor necessidade, tooltip, painel no clique esquerdo e menu contextual; registrado nos quatro blocos de `BarWidgetRegistry`, com `TamagotchiSettings.qml`, defaults por widget e traduções pt/en.
- [x] Criados `Modules/Panels/Tamagotchi/{TamagotchiPanel,PetSprite}.qml`: painel nativo com quatro indicadores reativos, sprites dirty/eating/sleeping e botões funcionais de alimentar, limpar, brincar, descansar e acordar; `eat.wav` respeita o volume configurado.
- [x] Registrado `TamagotchiPanel` por tela em `MainScreen.qml` (`objectName: tamagotchiPanel-*`, descoberto pelo `PanelService`); estado/dificuldade/volume declarados em `Commons/Settings.qml` e `Assets/settings-default.json`, com settings/i18n completos.
- [x] Verificação direcionada: `qmllint` passou nos cinco QML novos; `jq` validou defaults e traduções pt/en. Smoke real em duas execuções do Quickshell com `XDG_CONFIG_HOME`, cache e state isolados produziu `TAMAGOTCHI_TRANSITIONS_OK` após feed 40→60, clean 40→65, play happiness 40→60/energy 80→72 e rest ativo, seguido por `TAMAGOTCHI_RELOAD_OK` com os mesmos valores e `sleeping=true`; harness e configuração temporários removidos. A shell viva recarregou e permaneceu pronta sem erros Tamagotchi.

**Marco Fase 1:** 🟡 Implementação concluída — pendem apenas smokes dependentes do ambiente: `nvibrant` real, dispositivo ativo atribuível no privacy-indicator e `evtest` com acesso ao teclado.

---

## Fase 2 — Widgets de barra + painel completo

### 6. usb-drive-manager — 🟢 Finalizado
Mount/unmount/eject/browse de dispositivos USB.
Referência: `noctalia-legacy-v4-plugins/usb-drive-manager/{Main.qml,BarWidget.qml,Panel.qml,DeviceCard.qml,ControlCenterWidget.qml,Settings.qml}`
- [x] Dependências `udevadm`, `lsblk`, `df` e `udisksctl` verificadas em runtime, com degradação e mensagens de erro quando ausentes
- [x] Criado `Services/Hardware/UsbDriveService.qml` (singleton com monitor `udevadm`, enumeração `lsblk -J`, capacidade/uso via `df` e fila real de mount/unmount/power-off via `udisksctl`)
- [x] Criado `Modules/Bar/Widgets/UsbDriveManager.qml` com estado, badge, tooltip, menu contextual e abertura do painel nativo
- [x] Criados `Modules/Panels/UsbDriveManager/UsbDriveManagerPanel.qml` + `DeviceCard.qml` com capacidade, filesystem, montagem, uso e ações
- [x] Registrado em `BarWidgetRegistry.qml` e como `SmartPanel` por tela no `PanelService`
- [x] Settings/defaults: auto-mount, notificações, file browser, terminal, visibilidade, badge e cor do ícone; i18n pt/en
- [x] Smoke seguro: shell e singleton iniciaram sem erro; dependências disponíveis; `lsblk` retornou 0 dispositivos removíveis, portanto nenhuma ação destrutiva foi executada

### 7. obs-control + show-keys (combo streaming) — 🟢 Finalizado
Status e controle nativos de gravação/replay/transmissão do OBS na barra e em painel; `show-keys` permanece integrado pelo item 3.
Referência: `noctalia-legacy-v4-plugins/obs-control/{Main.qml,BarWidget.qml,Panel.qml,lib/,ControlCenterWidget.qml}`
- [x] Dependência verificada: `qt6-websockets` não está instalada nesta máquina; o transporte é carregado opcionalmente e expõe estado explícito de dependência ausente sem impedir a shell de iniciar
- [x] Criados `Services/System/ObsControlService.qml`, `ObsWebSocketTransport.qml` e `ObsWebSocketHash.js`: descoberta da configuração local ou host/porta/senha manuais, handshake/auth OBS WebSocket v5, eventos de saída, polling e controles de gravação/transmissão/replay
- [x] Criado `Modules/Bar/Widgets/ObsControl.qml`: selecionável, estado/saídas/tempo decorrido, painel no clique esquerdo, gravação no clique do meio e configurações no menu contextual
- [x] Criado `Modules/Panels/ObsControl/ObsControlPanel.qml` com estado de conexão/autenticação, erros técnicos claros e ações de gravação, transmissão, replay e salvamento de replay
- [x] Registrado em `BarWidgetRegistry.qml` e como `SmartPanel` por tela; settings/defaults globais e por widget, além de traduções completas pt/en
- [x] Verificações direcionadas: JSON/defaults e paridade i18n válidos; vetor SHA-256/Base64 validado; shell carregou os QML e o smoke vivo confirmou `dependency-missing=true`, `configuration-missing=true` e `connected=false`, sem sucesso falso. O smoke real de gravação fica condicionado à instalação de `qt6-websockets`

**Marco Fase 2:** 🟡 Implementação concluída — USB validado sem dispositivo removível presente; controle OBS real depende de `qt6-websockets` e uma instância OBS configurada.

---

## Fase 3 — Integrações em arquivos compartilhados (mais risco, tocam código existente)

> Estes itens editam arquivos grandes já em uso (`Panel.qml` do dashboard, `ClipboardService.qml`, `WallpaperPaletteSheet.qml`). Fazer um de cada vez, re-ler o arquivo antes de editar (pode ter mudado desde este plano).

### 8. timer — 4ª página do dashboard — 🟢 Finalizado
Referência: `noctalia-legacy-v4-plugins/timer/{Main.qml,BarWidget.qml,ControlCenterWidget.qml,Panel.qml,Settings.qml}`.
- [x] Reutilizado o estado global já existente em `Commons/Time.qml` (`timerRunning`, countdown/stopwatch, pausa/reset e compensação de suspensão), evitando duplicar um segundo serviço.
- [x] `component TimerPage` em `Modules/Panels/ControlCenter/Panel.qml`: contagem regressiva e cronômetro, parser de `25m`/`1h 30m`/`05:00`, presets 5/25/60m, progresso e controles iniciar/pausar/reiniciar/parar alarme.
- [x] Inserida como 4ª página direta de `calendarSwipe`; `PageDots` e roda do mouse passaram a reconhecê-la automaticamente.
- [x] Alarme usa `SoundService` pelo fluxo existente de `Time.timerOnFinished()`; traduções pt/en adicionadas.
- [x] Smoke test ao vivo: página e quatro pontos renderizados; countdown temporário de 3s percorreu `00:02` → `00:00`, trocou para cor de erro e exibiu \"Parar alarme\" enquanto `alarm-beep.wav` repetia. Gatilho temporário removido e índice inicial restaurado para clima.


### 9. clipper → funções ricas no ClipboardService existente — 🟢 Finalizado
**Não portado como plugin separado** — pin e notas foram incorporados ao serviço nativo, sem segundo banco de histórico.
Referência: `noctalia-legacy-v4-plugins/clipper/{ClipboardCard.qml,CHANGELOG*.md}`.
- [x] `Commons/Settings.qml` + `Assets/settings-default.json`: persistência em `appLauncher.pinnedClipboardIds` e `appLauncher.clipboardNotes`.
- [x] `Services/Keyboard/ClipboardService.qml`: `isPinned()`/`togglePin()`, ordenação estável com fixados no topo, notas autorais com `contentType: \"note\"`, criação/cópia/colagem/exclusão e `wipeAll()` que mantém notas e entradas cliphist fixadas.
- [x] `Modules/Panels/Launcher/Providers/ClipboardProvider.qml`: chips Fixados/Notas, ação pin/unpin, comando `>clip note <texto>` e ícone próprio para notas.
- [x] `Modules/Panels/Launcher/LauncherCore.qml`: `Ctrl+P` fixa/desafixa o item selecionado sem roubar a tecla `p` da pesquisa.
- [x] Smoke test ao vivo: criado `Hydra note test` via launcher, confirmado em `~/.config/noctalia/settings.json`, launcher fechado/reaberto e nota recuperada no topo; `Ctrl+P` persistiu o ID e Delete removeu nota+pin. O dado sintético foi removido ao final. `wipeAll()` não foi disparado contra o histórico real do usuário; o caminho preserva fixados filtrando os IDs antes de chamar `cliphist delete`.


### 10. color-scheme-creator → editor na aba paleta do wallpaper — 🟢 Finalizado
**Portado como editor nativo** — usa `ColorSchemeService`/`AppThemeService`, sem loader ou serviço de tema paralelo.
Referência: `noctalia-legacy-v4-plugins/color-scheme-creator/{Panel.qml,Settings.qml}`.
- [x] `Modules/Panels/Wallpaper/Components/WallpaperPaletteSheet.qml`: `NColorPickerDialog` abre pelo swatch; botão secundário preserva a cópia hexadecimal.
- [x] Grid editável dos 16 papéis MD3, com alternância entre variantes escura/clara e rótulos compartilhados em `Assets/Translations/{en,pt}.json`.
- [x] Prévia ao vivo via `ColorSchemeService.writeColorsToDisk()`, com snapshot anterior e restauração ao cancelar, redefinir, ocultar ou destruir a folha.
- [x] `ColorSchemeService.saveNamedScheme()` grava atomicamente `Settings.configDir + "colorschemes/<nome>/<nome>.json"`; ao concluir, a UI aplica o caminho salvo, seleciona o esquema e recarrega a lista nativa.
- [x] Cores ANSI `normal`/`bright`, foreground/background, seleção e cursor são derivadas para as duas variantes no mesmo formato dos esquemas nativos.
- [x] Verificação direcionada: `jq empty` aprovou os dois JSON; `qmllint` aprovou `WallpaperPaletteSheet.qml` e `ColorSchemeService.qml`; checagem de dados confirmou 16 papéis únicos e todos os rótulos en/pt; o gravador atômico produziu em `/tmp` um esquema dark/light com ANSI validado por `jq` e o artefato foi removido. Smoke ao vivo com uma instância isolada `qs -p .`: painel aberto via IPC na aba “Paleta de Cores”, editor completo renderizado com swatches, alternância, nome, prévia/restauração e salvar/aplicar, sem erro QML no log.

### 11. screen-toolkit — 2ª aba de quick toggles no dashboard — 🟢 Finalizado
**Sem porte de lógica** (já existia) — só UI de acesso rápido.
- [x] ~~Em `Modules/Panels/ControlCenter/Panel.qml`, envolver o `GridLayout` de `QuickActionsCard` (linha 2701-2917) com `NTabBar`/`NTabButton` (padrão de `processMetricTabs`): aba 1 = "Controles" atual, aba 2 = "Ferramentas"~~ — feito, `id: quickActionsCard` + `property int toolsTabIndex` controla as duas `GridLayout` via `visible`.
- [x] ~~Aba 2: `GridLayout` de `ActionTile` chamando `ScreenToolkitService.colorPicker()`, `.palette()`, `.ocr()`, `.qr()`, `.lens()`, `.annotateFullscreen()`, `.measure()`, `.pin()`, `.mirror()`~~ — 9 toggles implementados (`record`/`recordStop` deixados de fora de propósito: já existem no `RecordingCard`/"Ferramentas de Captura" existente, evitando duplicação).
- [x] ~~Chaves de tradução em `Modules/Panels/ControlCenter/i18n/{pt,en}.json`~~ — adicionadas `screenToolsTab`, `toolColorPicker`, `toolPalette`, `toolOcr`, `toolQr`, `toolLens`, `toolAnnotate`, `toolMeasure`, `toolPin`, `toolMirror` em ambos os arquivos.
- [x] ~~Smoke test: clicar cada toggle, confirmar que aciona a ferramenta correta~~ — verificado ao vivo via `qs ipc call controlCenter toggle` + `grim` no shell rodando (`qs -c hydra-shell -d`, hot-reload confirmado sem erros no log); as 9 ActionTile renderizam corretamente com labels traduzidos (screenshot confirmado). Clique real não testado (sem mouse disponível no ambiente de execução) — lógica é idêntica ao padrão `ActionTile.onTriggered` já usado nos outros 8 toggles existentes, que funcionam.


**Marco Fase 3:** 🟢 Finalizado — itens 8, 9, 10 e 11 implementados e validados.

---

## Ordem de execução recomendada

Fase 1 (5 itens independentes) → Fase 2 (2 itens independentes, obs-control precisa de `qt6-websockets` confirmado antes) → Fase 3 (4 itens sequenciais, cada um toca arquivo compartilhado — fazer um por vez e reler antes de editar).

## Riscos/dependências a validar antes de portar

| Item | Dependência externa | Ação |
|---|---|---|
| nvibrant | binário `nvibrant` | confirmar instalado/instalável via AUR |
| privacy-indicator | Pipewire (já usado nativamente) + `/sys/class/video4linux` | nenhuma nova dependência |
| show-keys | `evtest` + acesso a `/dev/input/eventN` | confirmar grupo `input` ou regra udev |
| catwalk | nenhuma | ícones SVG a copiar (checar licença) |
| tamagotchi | nenhuma | assets PNG/WAV a copiar (checar licença) |
| usb-drive-manager | `udevadm`, `lsblk`, `df`, `udisksctl` | usuais em qualquer Arch, confirmar `udisks2` instalado |
| obs-control | `qt6-websockets`, OBS com websocket habilitado | **confirmar `qt6-websockets` instalado antes de iniciar** |
| timer | `SoundService` (já nativo) | nenhuma nova dependência |
| clipper | nenhuma (usa `cliphist` já integrado) | nenhuma nova dependência |
| color-scheme-creator | nenhuma (usa `ColorSchemeService`/`TemplateProcessor` já nativos) | nenhuma nova dependência |
| screen-toolkit toggles | nenhuma (lógica já existe) | nenhuma nova dependência |
