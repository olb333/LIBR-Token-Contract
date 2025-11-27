# ✨ LIBR TOKEN: O Ativo da Ordem Libertária do Brasil ✨

### 📜 Contrato Inteligente ERC-20 Upgradeable (V2)

*LIBR* é o token nativo e avançado da Ordem Libertária do Brasil. Construído com as melhores práticas da OpenZeppelin, ele garante segurança, governança progressiva e a *imutabilidade total* das transações.

---

## 💎 Visão Geral e Imutabilidade

O foco central da arquitetura LIBR é a segurança de trading e a descentralização progressiva.

> 🚫 *Imutabilidade de Trading Garantida:*
> Todas as funcionalidades de pausa (Pausable) foram removidas. Após o deploy, *nenhum administrador pode bloquear ou interromper as transações* do token, garantindo um mercado 100% ativo e livre.

---

## 🏗 Arquitetura Técnica e Segurança

O contrato LIBR utiliza o padrão UUPS (Upgradeable) para permitir atualizações futuras controladas, protegendo a comunidade contra bugs imprevistos, mas sempre sob estrito controle de *Timelock*.

| Padrão | 🛡 Foco em Segurança | 🚀 Recurso Principal |
| :--- | :--- | :--- |
| *ERC20 + UUPS* | Standard & Flexibilidade | Token Base para atualizações seguras. |
| *Access Control* | Governança Segregada | Separação de poder entre Admin e DAO. |
| *Reentrancy Guard* | Proteção Crítica | Impede ataques em funções como liberação de vesting. |
| *Burnable* | Deflação | Permite a queima de tokens pela Tesouraria. |

### 🌐 Informações On-Chain

| Detalhe | Valor |
| :--- | :--- |
| *Símbolo* | *LIBR* |
| *Nome* | LIBR Token |
| *Decimais* | 18 |
| *Supply Total* | $333,333,333$ $LIBR$ |
| *Rede Principal* | Polygon |
| *Licença* | MIT |

---

## 🏛 Descentralização e Controle (Timelocks)

A governança é migrada de forma planejada do Administrador inicial para a DAO, utilizando mecanismos de tempo para impedir decisões precipitadas.

### 👥 Papéis de Governança

| Role | 🎯 Propósito | ⏳ Transição para DAO |
| :--- | :--- | :--- |
| DEFAULT_ADMIN_ROLE | *Admin Inicial* (Controle de Bootstrap) | Renúncia obrigatória (renounceAdmin) após a DAO assumir. |
| GOVERNANCE_ROLE | *DAO* (Controle Final) | Assume poder total sobre o token. |

### ⏳ Timelock para Ações Críticas

As operações são protegidas por um atraso obrigatório, garantindo transparência e tempo para auditoria da comunidade.

| Ação Crítica | Delay Necessário |
| :--- | :--- |
| *Transferência de Poder para a DAO* | **48 Horas (GOVERNANCE_DELAY)** |
| *Mudança de Tesouraria* | **24 Horas (TIMELOCK_DELAY)** |
| *Ativação de Features / Upgrade* | **24 Horas (TIMELOCK_DELAY)** |

---

## ⚖ Controle de Supply e Anti-Baleia

O supply total é liberado gradualmente através de um sistema de vesting de 4 fases, e o trading pode ser protegido temporariamente pelo Anti-Whale.

### 📦 Vesting de Supply (4 Fases)

Todo o supply é retido no contrato e liberado para a *Tesouraria* apenas mediante autorização da Governança.

| Fase | Allocation | Status de Liberação |
| :--- | :--- | :--- |
| *1: Fundação* | *10%* | Disponível para liberação. |
| *2: Expansão* | *30%* | Disponível para liberação. |
| *3: Libertação* | *30%* | Disponível para liberação. |
| *4: Reserva Estratégica| **30%* | Disponível para liberação. |

> *Nota:* A liberação pode ser feita de forma *Total* (release()) ou *Parcial* (releasePartial()), dependendo da ativação de uma feature flag.

### 🐳 Proteção Anti-Whale (Opcional)

Ativado pela Governança, este mecanismo protege contra a concentração excessiva e grandes despejos:

* *Limite Máximo por Transação* (maxTxAmount).
* *Limite Máximo por Carteira* (maxWalletAmount).
* Isenção: Endereços de Governança e Tesouraria são isentos para permitir a gestão institucional.

---

## 🔎 Consultas e Auditoria Pública

Use as funções de leitura pública para monitorar o estado do contrato em tempo real:

* remainingInContract(): Saldo de LIBR que ainda não foi liberado.
* totalReleased(): Total de LIBR já em circulação via vesting.
* timeUntilDAOActivation(): Confirmação do tempo restante para a transição de poder.
* getDetailedStatus(): Visão completa de todas as flags de segurança (Anti-Whale, Upgrade, DAO).

### 🔗 Endereço e Links Oficiais

| Plataforma | Link |
| :--- | :--- |
| *Endereço do Contrato (Polygon)* | 0xDE67aCA04983EF6156e287FEf5Cd8C7Ab79f6157 |
| *Website Oficial* | https://ordemlibertariabrasil.org |
| *Polygonscan* | https://polygonscan.com/token/0xE60d4a8ef7Df364634fb855F6acebe593a666A9D |
| *GitHub do Contrato* | https://github.com/olb333/LIBR-Token-Contract |
| *Comunidade (Twitter/Discord)* | https://x.com/olboficiall \| https://discord.gg/TkmC4zsU8j |

***

> 📖 Salmos 23: “O Senhor é o meu Pastor, nada me faltará...”
>
> © 2025 Ordem Libertária Brasil — Todos os direitos reservados.
