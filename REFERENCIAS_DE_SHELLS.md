# Referências de shells

## Diretriz para IAs e agentes

Ao projetar, corrigir ou refinar esta shell, **pesquise primeiro as implementações locais em `/home/raell/Projetos/Exemplos` (shells completas) e `/home/raell/Projetos/Uteis` (repositórios de apoio: capturas de tela, compressão, temas, utilitários)**. Esse material é uma fonte prática de padrões de arquitetura, composição QML, integração com o sistema, ergonomia e acabamento visual. Use-o para embasar decisões; não comece uma solução equivalente do zero quando já houver um precedente útil.

A referência deve orientar a decisão, não substituir o entendimento do código deste repositório. Preserve as convenções, os componentes compartilhados e os contratos já existentes em `hydra-shell`.

## Catálogo local

| Shell | Local | Melhor para estudar |
| --- | --- | --- |
| Caelestia | `/home/raell/Projetos/Exemplos/Caelestia` | Estrutura modular Quickshell, serviços e componentes reutilizáveis. |
| END4 | `/home/raell/Projetos/Exemplos/END4` | Padrões de shell e integração com Hyprland. |
| ryoku-arch | `/home/raell/Projetos/Exemplos/ryoku-arch` | Organização de uma shell completa e suas integrações. |
| iNiR | `/home/raell/Projetos/Exemplos/iNiR` | Shell Quickshell completa para Niri: barras, painéis, configurações, traduções e serviços. Consulte `docs/`, `modules/`, `services/` e `shell.qml`. |
| DankMaterialShell | `/home/raell/Projetos/Exemplos/DankMaterialShell` | Separação entre interface Quickshell e backend Go; módulos, serviços, widgets, temas, IPC e suporte a múltiplos compositores. Consulte `quickshell/`, `core/` e `docs/`. |
| Brain_Shell | `/home/raell/Projetos/Exemplos/Brain_Shell` | Referência adicional de shell Quickshell/Hyprland — consultar estrutura de módulos e serviços antes de portar qualquer padrão. |

Origens dos clones adicionados:

- iNiR: <https://github.com/snowarch/iNiR>
- DankMaterialShell: <https://github.com/AvengeMedia/DankMaterialShell>
- Brain_Shell: <https://github.com/neur0map/Brain_Shell>

## Repositórios com exemplos úteis

Não são shells completas — são projetos menores para extrair um módulo, uma animação, um painel ou uma técnica específica. Mesmas regras do catálogo acima: extraia o padrão, não o código, e nunca altere o clone local.

| Repositório | Local | Melhor para estudar |
| --- | --- | --- |
| hyprmod | `/home/raell/Projetos/Uteis/hyprmod` | Modificações/patches sobre Hyprland — referência de integração de baixo nível com o compositor. |
| DisCompress | `/home/raell/Projetos/Uteis/DisCompress` | Fluxo de compressão de mídia (screenshots/gravações) para compartilhar via Discord e afins. |
| ryoview | `/home/raell/Projetos/Uteis/ryoview` | Visualizador de imagens — padrões de UI para preview e navegação de mídia. |
| ryoshot | `/home/raell/Projetos/Uteis/ryoshot` | Ferramenta de captura de tela — referência direta para o Screen Toolkit desta shell. |
| Ricelin | `/home/raell/Projetos/Uteis/Ricelin` | Rice/tema de referência — paletas, acabamento visual e composição de painéis. |
| noctodeus | `/home/raell/Projetos/Uteis/noctodeus` | Módulo/widget derivado do ecossistema Hydra — comparar contra os módulos já portados aqui. |

Origens dos clones:

- hyprmod: <https://github.com/BlueManCZ/hyprmod>
- DisCompress: <https://github.com/snowarch/DisCompress>
- ryoview: <https://github.com/neur0map/ryoview>
- ryoshot: <https://github.com/neur0map/ryoshot>
- Ricelin: <https://github.com/Gakuseei/Ricelin>
- noctodeus: <https://github.com/neur0map/noctodeus>

## Fluxo obrigatório de pesquisa

1. **Defina o problema observável.** Ex.: painel de configurações, seletor de tema, tela de bloqueio, notificação, dock ou integração com um serviço do sistema.
2. **Localize pelo menos uma implementação análoga** nas shells acima antes de editar. Comece pelos pontos de entrada, depois percorra módulo, componente e serviço envolvidos.
3. **Extraia o padrão, não o código.** Identifique responsabilidades, fluxo de estado, limites entre UI e integração, comportamento em múltiplos monitores e estratégia de carregamento/atualização.
4. **Compare com a arquitetura local.** Reuse `Commons/`, `Widgets/`, `Services/` e `Modules/` existentes quando o contrato permitir. Não crie uma segunda convenção para algo já padronizado.
5. **Registre referências concretas na entrega.** Cite os caminhos consultados e explique, em uma frase, qual decisão eles informaram.
6. **Valide no ambiente real.** Uma referência é evidência de desenho, não prova de compatibilidade: execute o fluxo alterado nesta shell e corrija diferenças de APIs, compositor e dependências.

## Como investigar bem

- Para UI: compare hierarquia QML, estados, transições, tokens de cor/espaçamento, acessibilidade, navegação por teclado e comportamento em telas pequenas.
- Para serviços: observe propriedade de estado, ciclo de vida, IPC, erros, cache e atualização; mantenha comandos e efeitos colaterais fora de componentes visuais.
- Para recursos de sessão: estude cuidadosamente bloqueio, idle, energia, notificações e polkit; integre pelo contrato desta shell e teste o caminho completo.
- Para desempenho: procure carregamento preguiçoso, instâncias por tela e assinaturas de eventos antes de introduzir timers ou polling.

## Limites

- Não copie arquivos, trechos extensos, branding, assets ou licenças das referências sem verificar a compatibilidade de licença e atribuição.
- Não trate caminhos, comandos, daemons, versões do Quickshell ou APIs dos exemplos como compatíveis por padrão.
- Não adicione uma dependência apenas porque uma referência a usa; justifique a necessidade no contexto deste projeto.
- Não altere os repositórios em `/home/raell/Projetos/Exemplos` e `/home/raell/Projetos/Uteis`; eles são material de consulta local.

## Lab de desenvolvimento e publicação

O desenvolvimento acontece em `/home/raell/Projetos/hydra-shell` (o "Lab", um checkout git completo em `legacy-v4`), nunca direto em `~/.config/quickshell/hydra-shell` (a "shell ativa", que é a instalação em uso no dia a dia, feita pelo `Scripts/bash/install.sh`). Os dois diretórios são clones independentes do mesmo `origin`.

Fluxo:

1. Edite e commit no Lab. Use o `prowl-agent` (obrigatório, ver `.prowl_instructions.md`/`AGENTS.md`) para localizar código antes de abrir arquivos inteiros.
2. `Scripts/dev/lab-preview.sh` — sobe uma instância isolada (`qs -p`) a partir do Lab, sem tocar na shell ativa, para validar visualmente a mudança.
3. `Scripts/dev/lab-status.sh` — mostra de relance se o Lab está à frente de `origin/legacy-v4` e se a shell ativa está atrás dele.
4. `Scripts/dev/lab-sync.sh` — só roda com o Lab limpo em `legacy-v4`: formata QML, roda `prowl-agent doctor`, publica em `origin/legacy-v4`, pede confirmação de que o preview foi validado, dá fast-forward na shell ativa e reinicia o processo `qs -c hydra-shell`. Use `-y`/`--yes` para pular a confirmação em automação.

Nenhum desses scripts descarta trabalho local não commitado, no Lab ou na shell ativa — eles param e avisam.

## Critério de qualidade

Uma mudança relevante deve poder responder: **qual referência local foi consultada, qual padrão foi adotado ou rejeitado, por que ele se encaixa nesta shell e qual teste confirmou o comportamento final?**
