# Referências de shells

## Diretriz para IAs e agentes

Ao projetar, corrigir ou refinar esta shell, **pesquise primeiro as implementações locais em `/home/raell/Projetos/Exemplos`**. Essas shells são uma fonte prática de padrões de arquitetura, composição QML, integração com o sistema, ergonomia e acabamento visual. Use-as para embasar decisões; não comece uma solução equivalente do zero quando já houver um precedente útil.

A referência deve orientar a decisão, não substituir o entendimento do código deste repositório. Preserve as convenções, os componentes compartilhados e os contratos já existentes em `hydra-shell`.

## Catálogo local

| Shell | Local | Melhor para estudar |
| --- | --- | --- |
| Caelestia | `/home/raell/Projetos/Exemplos/Caelestia` | Estrutura modular Quickshell, serviços e componentes reutilizáveis. |
| END4 | `/home/raell/Projetos/Exemplos/END4` | Padrões de shell e integração com Hyprland. |
| ryoku-arch | `/home/raell/Projetos/Exemplos/ryoku-arch` | Organização de uma shell completa e suas integrações. |
| iNiR | `/home/raell/Projetos/Exemplos/iNiR` | Shell Quickshell completa para Niri: barras, painéis, configurações, traduções e serviços. Consulte `docs/`, `modules/`, `services/` e `shell.qml`. |
| DankMaterialShell | `/home/raell/Projetos/Exemplos/DankMaterialShell` | Separação entre interface Quickshell e backend Go; módulos, serviços, widgets, temas, IPC e suporte a múltiplos compositores. Consulte `quickshell/`, `core/` e `docs/`. |

Origens dos clones adicionados:

- iNiR: <https://github.com/snowarch/iNiR>
- DankMaterialShell: <https://github.com/AvengeMedia/DankMaterialShell>

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
- Não altere os repositórios em `/home/raell/Projetos/Exemplos`; eles são material de consulta local.

## Critério de qualidade

Uma mudança relevante deve poder responder: **qual referência local foi consultada, qual padrão foi adotado ou rejeitado, por que ele se encaixa nesta shell e qual teste confirmou o comportamento final?**
