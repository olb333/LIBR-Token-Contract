// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 **╔═══════════════════════════════════════════════════════════════════════════╗
  ║                               🜁 LIBR TOKEN 🜁                               
  ║                     Ordem Libertária do Brasil — LIBR                         
  ║═══════════════════════════════════════════════════════════════════════════║
  ║ Token ERC20 Upgradeable com:                                                
  ║ • Vesting por fases                                                          
  ║ • Anti-Whale (opcional)                                                     
  ║ • DAO com ativação programada                                               
  ║ • UUPS para upgrades seguros                                                
  ║ • Burnable                                                                  
  ║───────────────────────────────────────────────────────────────────────────║
  ║  AVISO DE CONTROLE INICIAL                                               
  ║ - Durante o lançamento, o Admin inicial controla funções de governança.     
  ║ - A descentralização será progressiva, com transferência de governança     
  ║   para a DAO após períodos agendados.                                        
  ║───────────────────────────────────────────────────────────────────────────║
  ║  AVISO DE SEGURANÇA                                      
  ║ - Tokens armazenados no contrato não podem ser transferidos até a liberação
  ║   por fases de vesting.                                                     
  ║ - Anti-Whale pode limitar transferências temporariamente.                  
  ║ - Atualizações UUPS só podem ser feitas por Admin/Governança autorizada.   
  ║ - Este contrato não possui honeypot; transferências padrão de usuários são 
  ║   permitidas após a liberação dos tokens.                                   
  ║───────────────────────────────────────────────────────────────────────────║
  ║ 📖 Salmos 23: “O Senhor é o meu Pastor, nada me faltará...”                 
  ║ Autor: Davi Linck    
 * Este contrato representa o token oficial da Ordem Libertária do Brasil — LIBR.
 * Ele é projetado com mecanismos de governança, vesting por fases, proteção anti-baleia,
 * controle temporário por timelocks e upgrade seguro via UUPS.
 */

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

// O contrato LIBR herda funcionalidades de ERC20, Burnable, Controle de Acesso e UUPS (Upgradeability).
contract LIBR is 
    Initializable,
    ERC20Upgradeable,
    ERC20BurnableUpgradeable,
    AccessControlUpgradeable,
    UUPSUpgradeable,
    ReentrancyGuardUpgradeable
{
    // Habilita funcionalidades de segurança para interações com outros tokens ERC20.
    using SafeERC20Upgradeable for IERC20Upgradeable;

    // ──────────────────────────────
    // I. CONFIGURAÇÕES E CONSTANTES
    // ──────────────────────────────

    // Role para governança DAO. Possui poderes para liberar fases, atualizar treasury e habilitar features.
    bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");

    // Definição numérica das fases do vesting e seus respectivos pesos percentuais.
    uint8 private constant PHASE_FUNDACAO   = 1; // 10% do supply total
    uint8 private constant PHASE_EXPANSAO   = 2; // 30% do supply total
    uint8 private constant PHASE_LIBERTACAO = 3; // 30% do supply total
    uint8 private constant PHASE_RESERVA    = 4; // 30% do supply total

    // Supply total imutável do token (333.333.333 tokens com 18 casas decimais).
    uint256 public constant TOTAL_SUPPLY = 333_333_333 * 10 ** 18; 
    // Delay de 48 horas necessário antes que a DAO possa ser ativada.
    uint256 public constant GOVERNANCE_DELAY = 48 hours;           
    // Delay padrão de 24 horas para operações sensíveis via Timelock (ex: mudar treasury).
    uint256 public constant TIMELOCK_DELAY = 24 hours;             

    // ──────────────────────────────
    // II. VARIÁVEIS DE ESTADO
    // ──────────────────────────────

    // Endereço da carteira que receberá os tokens liberados pelo vesting.
    address public treasury;         
    // Endereço do contrato DAO que assumirá o papel de governança.
    address public daoAddress;       

    // Mapa que rastreia se uma fase de vesting foi completamente liberada.
    mapping(uint8 => bool) public released;          
    // Mapa que rastreia a quantidade de tokens já liberada em cada fase de vesting.
    mapping(uint8 => uint256) public releasedAmount; 
    // Contador total de tokens já liberados de todas as fases.
    uint256 private _totalReleasedAmount;           

    // Flag que indica se o upgrade do contrato está atualmente permitido.
    bool public upgradeAllowed;                    
    // Flag que indica se o mecanismo Anti-Baleia (limites de transação/carteira) está ativo.
    bool public antiWhaleEnabled;                  
    // Flag que bloqueia permanentemente qualquer upgrade via UUPS.
    bool public upgradePermanentlyDisabled;        
    // Flag que bloqueia permanentemente a ativação do Anti-Baleia.
    bool public antiWhalePermanentlyDisabled;      

    // Valor máximo de tokens permitido por transação quando o Anti-Baleia está ativo.
    uint256 public maxTxAmount;    
    // Valor máximo de tokens permitido em uma única carteira quando o Anti-Baleia está ativo.
    uint256 public maxWalletAmount;

    // Flag que indica se a governança foi transferida para o DAO.
    bool public daoActive;          
    // Timestamp em que a DAO poderá ser ativada (após GOVERNANCE_DELAY).
    uint256 public governanceActivationTime; 

    // Identificador para a funcionalidade de liberação parcial do vesting.
    bytes32 public constant FEATURE_PARTIAL_RELEASE = keccak256("FEATURE_PARTIAL_RELEASE"); 
    // Mapa para controlar a ativação de diferentes funcionalidades.
    mapping(bytes32 => bool) public featureEnabled; 

    // Mapa que armazena o timestamp de execução para operações sujeitas a Timelock.
    mapping(bytes32 => uint256) public scheduledOperations; 

    // ──────────────────────────────
    // III. EVENTOS
    // ──────────────────────────────

    /**
     * Emitido quando a permissão de upgrade (via UUPS) é alterada.
     */
    event UpgradeAllowedSet(bool allowed);

    /**
     * Emitido quando os limites do Anti-Baleia são configurados ou reconfigurados.
     */
    event AntiWhaleLimitsUpdated(uint256 maxTx, uint256 maxWallet, bool enabled);

    /**
     * Emitido quando o upgrade do contrato é desativado permanentemente.
     */
    event UpgradePermanentlyDisabled(address indexed by);

    /**
     * Emitido quando o mecanismo Anti-Baleia é desativado permanentemente.
     */
    event AntiWhalePermanentlyDisabled(address indexed by);

    /**
     * Emitido sempre que uma fase de vesting é liberada (total ou parcial).
     */
    event ReleaseTriggered(uint8 indexed phase, uint256 amount, uint256 timestamp, address indexed triggeredBy);

    /**
     * Emitido quando o endereço do contrato DAO é configurado.
     */
    event DAOSet(address indexed previousDAO, address indexed newDAO);

    /**
     * Emitido quando o endereço da tesouraria é alterado.
     */
    event TreasurySet(address indexed previousTreasury, address indexed newTreasury);

    /**
     * Emitido quando uma feature (ex: FEATURE_PARTIAL_RELEASE) é ativada ou desativada.
     */
    event FeatureToggled(bytes32 indexed feature, bool enabled);

    /**
     * Emitido quando a ativação da DAO é programada (agendada).
     */
    event GovernanceActivationScheduled(uint256 timestamp);

    /**
     * Emitido quando o agendamento da ativação da DAO é cancelado.
     */
    event GovernanceScheduleCanceled(uint256 timestamp);

    /**
     * Emitido quando a governança é ativada e transferida para o DAO.
     */
    event GovernanceActivated(address indexed daoAddress);

    /**
     * Emitido quando o papel de governança é revogado de um endereço (geralmente do Admin inicial).
     */
    event GovernanceRoleRevoked(address indexed previousGovernance, address indexed newGovernance);

    /**
     * Emitido quando uma operação sensível é agendada com Timelock.
     */
    event OperationScheduled(bytes32 indexed operationId, uint256 executeAfter);

    /**
     * Emitido quando uma operação agendada é cancelada antes do prazo.
     */
    event OperationCanceled(bytes32 indexed operationId, uint256 timestamp);

    // ──────────────────────────────
    // IV. INICIALIZAÇÃO
    // ──────────────────────────────

    /**
     * @notice Função de inicialização do token LIBR.
     * @dev Chamada apenas uma vez durante o deploy do proxy.
     * @param _treasury Endereço inicial da tesouraria para o vesting.
     * @param _initialAdmin Endereço do administrador inicial que terá controle.
     */
    function initialize(address _treasury, address _initialAdmin) public initializer {
        require(_treasury != address(0), "Tesouraria invalida");
        require(_initialAdmin != address(0), "Admin inicial invalido");

        // Inicializa o token ERC20 com nome e símbolo
        __ERC20_init("LIBR Token", "LIBR");
        // Inicializa a extensão ERC20 Burnable
        __ERC20Burnable_init();
        // Inicializa o controle de acesso (Roles)
        __AccessControl_init();
        // Inicializa o mecanismo de upgrade UUPS
        __UUPSUpgradeable_init();
        // Inicializa o modificador Anti-Reentrância
        __ReentrancyGuard_init();

        treasury = _treasury;
        // Cunhagem (Mint) do supply total para o próprio contrato (de onde será liberado via vesting)
        _mint(address(this), TOTAL_SUPPLY);

        // Concede os papéis de ADMIN e GOVERNANCE ao administrador inicial.
        _grantRole(DEFAULT_ADMIN_ROLE, _initialAdmin);
        _grantRole(GOVERNANCE_ROLE, _initialAdmin);

        // Define o Anti-Baleia como desativado por padrão.
        antiWhaleEnabled = false;
        antiWhalePermanentlyDisabled = false;
    }

    // ──────────────────────────────
    // V. GOVERNANÇA E DAO
    // ──────────────────────────────

    /**
     * @notice Modificador para restringir funções à governança.
     * @dev Permite a execução apenas pelo Admin inicial ou pelo endereço com GOVERNANCE_ROLE (futuramente a DAO).
     */
    modifier onlyGovernance() {
        require(
            hasRole(GOVERNANCE_ROLE, msg.sender) || hasRole(DEFAULT_ADMIN_ROLE, msg.sender),
            "Apenas governanca"
        );
        _;
    }

    /**
     * @notice Modificador para permitir execução apenas se a feature específica estiver ativa.
     */
    modifier onlyWhenFeature(bytes32 feature) {
        require(featureEnabled[feature], "Feature inativa");
        _;
    }

    /**
     * @notice Permite ao Admin inicial renunciar ao papel de DEFAULT_ADMIN_ROLE.
     * @dev Usado após a DAO estar ativa para completar a descentralização.
     */
    function renounceAdmin() external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(daoActive, "DAO deve estar ativa antes de renunciar");
        _revokeRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /**
     * @notice Configura o endereço do contrato DAO.
     * @dev Deve ser chamado antes de agendar a ativação.
     * @param _dao Endereço do contrato DAO que irá governar.
     */
    function setDAO(address _dao) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_dao != address(0), "DAO invalida");
        require(governanceActivationTime == 0, "Ja agendado");
        require(daoAddress == address(0) || !daoActive, "DAO ja ativa");
        address prev = daoAddress;
        daoAddress = _dao;
        emit DAOSet(prev, _dao);
    }

    /**
     * @notice Agenda a ativação da DAO após o delay definido (GOVERNANCE_DELAY).
     * @dev O Admin inicial deve chamar activateDAO após o delay expirar.
     */
    function scheduleActivateDAO() external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(daoAddress != address(0), "DAO nao definida");
        governanceActivationTime = block.timestamp + GOVERNANCE_DELAY;
        emit GovernanceActivationScheduled(governanceActivationTime);
    }

    /**
     * @notice Cancela um agendamento de ativação da DAO pendente.
     */
    function cancelScheduleActivateDAO() external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(governanceActivationTime != 0, "Nenhum agendamento ativo");
        governanceActivationTime = 0;
        emit GovernanceScheduleCanceled(block.timestamp);
    }

    /**
     * @notice Ativa a DAO e transfere o papel de GOVERNANCE_ROLE para o endereço DAO.
     * @dev Requer que o GOVERNANCE_DELAY tenha expirado.
     */
    function activateDAO() external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(daoAddress != address(0), "DAO nao definida");
        require(block.timestamp >= governanceActivationTime, "Aguardando delay");
        require(!daoActive, "DAO ja ativa");

        daoActive = true;
        governanceActivationTime = 0;

        // Concede o papel de governança para o endereço DAO
        grantRole(GOVERNANCE_ROLE, daoAddress);

        // Revoga o papel de governança do Admin inicial (se ele o possuir), completando a transferência de poder.
        if (hasRole(GOVERNANCE_ROLE, msg.sender)) {
            revokeRole(GOVERNANCE_ROLE, msg.sender);
            emit GovernanceRoleRevoked(msg.sender, daoAddress);
        }

        emit GovernanceActivated(daoAddress);
    }

    /**
     * @notice Retorna o tempo restante (em segundos) até que a DAO possa ser ativada.
     */
    function timeUntilDAOActivation() public view returns (uint256) {
        if (governanceActivationTime == 0 || block.timestamp >= governanceActivationTime)
            return 0;
        return governanceActivationTime - block.timestamp;
    }

    // ──────────────────────────────
    // VI. TIMELOCK
    // ──────────────────────────────

    /**
     * @notice Função interna para agendar uma operação com o delay padrão (TIMELOCK_DELAY).
     * @param operationId Hash único que identifica a operação a ser agendada.
     */
    function _scheduleOperation(bytes32 operationId) internal {
        scheduledOperations[operationId] = block.timestamp + TIMELOCK_DELAY;
        emit OperationScheduled(operationId, scheduledOperations[operationId]);
    }

    /**
     * @notice Função interna para executar uma operação agendada após o Timelock expirar.
     * @param operationId Hash da operação.
     */
    function _executeOperation(bytes32 operationId) internal {
        require(scheduledOperations[operationId] > 0, "Operacao nao agendada");
        require(block.timestamp >= scheduledOperations[operationId], "Timelock ativo");
        delete scheduledOperations[operationId];
    }

    /**
     * @notice Função interna para cancelar uma operação agendada antes do prazo de execução.
     * @param operationId Hash da operação.
     */
    function _cancelOperation(bytes32 operationId) internal {
        require(scheduledOperations[operationId] > 0, "Operacao nao existe");
        delete scheduledOperations[operationId];
        emit OperationCanceled(operationId, block.timestamp);
    }

    /**
     * @notice Agenda uma alteração no endereço da tesouraria (Treasury).
     * @dev Requer execução posterior via executeTreasuryChange.
     */
    function scheduleTreasuryChange(address _treasury) external onlyGovernance {
        require(_treasury != address(0) && _treasury != address(this), "Tesouraria invalida");
        _scheduleOperation(keccak256(abi.encode("TREASURY", _treasury)));
    }

    /**
     * @notice Executa a alteração do endereço da tesouraria após o Timelock.
     */
    function executeTreasuryChange(address _treasury) external onlyGovernance {
        _executeOperation(keccak256(abi.encode("TREASURY", _treasury)));
        address prev = treasury;
        treasury = _treasury;
        emit TreasurySet(prev, _treasury);
    }

    /**
     * @notice Agenda a ativação ou desativação de uma feature.
     * @dev Requer execução posterior via executeFeatureToggle.
     */
    function scheduleFeatureToggle(bytes32 feature, bool enabled) external onlyGovernance {
        require(feature != keccak256("FEATURE_MINT"), "FEATURE_MINT removida"); // Trava de segurança
        _scheduleOperation(keccak256(abi.encode("FEATURE", feature, enabled)));
    }

    /**
     * @notice Executa a ativação ou desativação de uma feature após o Timelock.
     */
    function executeFeatureToggle(bytes32 feature, bool enabled) external onlyGovernance {
        _executeOperation(keccak256(abi.encode("FEATURE", feature, enabled)));
        featureEnabled[feature] = enabled;
        emit FeatureToggled(feature, enabled);
    }

    /**
     * @notice Agenda a permissão/proibição de futuros upgrades do contrato.
     * @dev Requer execução posterior via executeUpgradeAllowed.
     */
    function scheduleUpgradeAllowed(bool _allowed) external onlyGovernance {
        require(!upgradePermanentlyDisabled, "Upgrade desativado permanentemente");
        _scheduleOperation(keccak256(abi.encode("UPGRADE", _allowed)));
    }

    /**
     * @notice Executa a alteração da permissão de upgrade após o Timelock.
     */
    function executeUpgradeAllowed(bool _allowed) external onlyGovernance {
        _executeOperation(keccak256(abi.encode("UPGRADE", _allowed)));
        upgradeAllowed = _allowed;
        emit UpgradeAllowedSet(_allowed);
    }

    /**
     * @notice Permite o cancelamento de qualquer operação agendada.
     */
    function cancelScheduledOperation(bytes32 operationId) external onlyGovernance {
        _cancelOperation(operationId);
    }

    /**
     * @notice Função interna de autorização para o mecanismo UUPS (Upgradeability).
     * @dev Deve ser substituída (override). Permite upgrade apenas se upgradeAllowed for true e for chamado por Admin/Governance.
     */
    function _authorizeUpgrade(address) internal view override {
        bool canUpgrade = upgradeAllowed &&
            (hasRole(GOVERNANCE_ROLE, msg.sender) || hasRole(DEFAULT_ADMIN_ROLE, msg.sender));
        require(canUpgrade, "Upgrade desativado ou nao autorizado");
    }

    // ──────────────────────────────
    // VII. VESTING
    // ──────────────────────────────

    /**
     * @notice Libera a quantidade total de tokens de uma fase completa para a treasury.
     * @param phase O número da fase de vesting a ser liberada (1 a 4).
     */
    function release(uint8 phase) external onlyGovernance nonReentrant {
        _releaseChecks(phase); // Checa se a fase é válida
        require(!released[phase], "Fase ja liberada");
        uint256 amount = _amountForPhase(phase);
        require(balanceOf(address(this)) >= amount, "Saldo insuficiente");

        // Atualiza o estado da fase e a contagem de liberados
        released[phase] = true;
        releasedAmount[phase] = amount;
        _totalReleasedAmount += amount;

        // Transfere o valor do contrato para a tesouraria
        _transfer(address(this), treasury, amount);
        emit ReleaseTriggered(phase, amount, block.timestamp, msg.sender);
    }

    /**
     * @notice Liberação de uma quantidade parcial de tokens de uma fase de vesting.
     * @dev Requer que a feature FEATURE_PARTIAL_RELEASE esteja ativa.
     * @param phase O número da fase.
     * @param amount A quantidade de tokens a ser liberada.
     */
    function releasePartial(uint8 phase, uint256 amount)
        external
        onlyGovernance
        onlyWhenFeature(FEATURE_PARTIAL_RELEASE)
        nonReentrant
    {
        _releaseChecks(phase); // Checa se a fase é válida
        require(amount > 0, "Quantidade invalida");
        require(amount <= balanceOf(address(this)), "Saldo insuficiente");

        uint256 maxAmount = _amountForPhase(phase);
        // Garante que a liberação parcial não exceda o limite total da fase
        require(releasedAmount[phase] + amount <= maxAmount, "Excede limite da fase");

        // Atualiza a contagem parcial
        releasedAmount[phase] += amount;
        if (releasedAmount[phase] == maxAmount) released[phase] = true; // Marca como liberada se atingir o total
        _totalReleasedAmount += amount;

        _transfer(address(this), treasury, amount);
        emit ReleaseTriggered(phase, amount, block.timestamp, msg.sender);
    }

    /**
     * @notice Checa se o número da fase de vesting é um valor válido (entre 1 e 4).
     */
    function _releaseChecks(uint8 phase) internal pure {
        require(phase >= PHASE_FUNDACAO && phase <= PHASE_RESERVA, "Fase invalida");
    }

    /**
     * @notice Calcula e retorna o total de tokens alocados para uma determinada fase.
     */
    function _amountForPhase(uint8 phase) internal pure returns (uint256) {
        if (phase == PHASE_FUNDACAO) return TOTAL_SUPPLY / 10; // 10%
        if (phase == PHASE_EXPANSAO) return (TOTAL_SUPPLY * 3) / 10; // 30%
        if (phase == PHASE_LIBERTACAO) return (TOTAL_SUPPLY * 3) / 10; // 30%
        if (phase == PHASE_RESERVA) return (TOTAL_SUPPLY * 3) / 10; // 30%
        return 0;
    }

    // ──────────────────────────────
    // VIII. ANTI-BALEIA TEMPORÁRIO
    // ──────────────────────────────

    /**
     * @notice Ativa o mecanismo Anti-Baleia com limites de transação e carteira.
     * @dev Pode ser desativado temporariamente ou permanentemente pela governança.
     * @param _maxTx Máximo de tokens por transação.
     * @param _maxWallet Máximo de tokens que uma carteira pode possuir.
     */
    function enableAntiWhale(uint256 _maxTx, uint256 _maxWallet) external onlyGovernance {
        require(!antiWhalePermanentlyDisabled, "Anti-Baleia desativado permanentemente");
        require(_maxTx > 0 && _maxWallet > 0, "Valores invalidos");

        maxTxAmount = _maxTx;
        maxWalletAmount = _maxWallet;
        antiWhaleEnabled = true;

        emit AntiWhaleLimitsUpdated(_maxTx, _maxWallet, true);
    }

    /**
     * @notice Desativa o mecanismo Anti-Baleia permanentemente.
     * @dev Não poderá ser reativado após esta chamada.
     */
    function disableAntiWhalePermanently() external onlyGovernance nonReentrant {
        antiWhaleEnabled = false;
        antiWhalePermanentlyDisabled = true;

        emit AntiWhalePermanentlyDisabled(msg.sender);
    }

    /**
     * @notice Lógica interna para checar se uma transação viola os limites anti-baleia.
     * @dev A checagem é ignorada para endereços com roles de controle (Admin/Governance).
     */
    function _checkAntiWhale(address from, address to, uint256 value) internal view {
        // Checa se o 'from' ou 'to' é um endereço de controle.
        bool controller = hasRole(DEFAULT_ADMIN_ROLE, from) || hasRole(GOVERNANCE_ROLE, from)
            || hasRole(DEFAULT_ADMIN_ROLE, to) || hasRole(GOVERNANCE_ROLE, to);

        if (antiWhaleEnabled && !controller && from != address(0)) {
            // Limite por transação (ignora o próprio contrato)
            if (from != address(this)) require(value <= maxTxAmount, "Limite por transacao excedido");
            // Limite por carteira (ignora o próprio contrato e a treasury)
            if (to != address(this) && to != treasury)
                require(balanceOf(to) + value <= maxWalletAmount, "Limite por carteira excedido");
        }
    }

    /**
     * @notice Hook do OpenZeppelin chamado antes de qualquer transferência de token.
     * @dev Injeta a lógica do Anti-Baleia antes que a transação ocorra.
     */
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual {
        _checkAntiWhale(from, to, amount);
    }

    // ──────────────────────────────
    // IX. RECUPERAÇÃO E LEITURAS
    // ──────────────────────────────

    /**
     * @notice Permite ao Admin inicial recuperar quaisquer tokens ERC20 (diferentes de LIBR)
     * acidentalmente enviados para o contrato.
     * @param token Endereço do token ERC20 a ser recuperado.
     * @param amount Quantidade a ser enviada para a tesouraria.
     */
    function recoverERC20(address token, uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(token != address(this), "Nao pode recuperar LIBR");
        IERC20Upgradeable(token).safeTransfer(treasury, amount);
    }

    /**
     * @notice Retorna a quantidade de tokens LIBR que ainda estão retidos no contrato (aguardando vesting).
     */
    function remainingInContract() external view returns (uint256) {
        return balanceOf(address(this));
    }

    /**
     * @notice Retorna o total de tokens LIBR liberados do vesting até o momento.
     */
    function totalReleased() external view returns (uint256) {
        return _totalReleasedAmount;
    }

    /**
     * @notice Retorna se uma fase de vesting foi totalmente liberada.
     */
    function isPhaseFullyReleased(uint8 phase) public view returns (bool) {
        return released[phase];
    }

    /**
     * @notice Retorna a quantidade de tokens LIBR que ainda faltam ser liberados em uma fase específica.
     */
    function amountRemainingInPhase(uint8 phase) external view returns (uint256) {
        return _amountForPhase(phase) - releasedAmount[phase];
    }

    /**
     * @notice Retorna um conjunto completo de variáveis de estado para monitoramento.
     */
    function getDetailedStatus() external view returns (
        bool antiWhale_, // Anti-Baleia ativo?
        bool antiWhalePermanentlyDisabled_, // Anti-Baleia permanentemente desativado?
        bool dao_, // DAO ativo e governando?
        bool upgrade_, // Upgrade permitido?
        bool upgradePermanentlyDisabled_, // Upgrade permanentemente desativado?
        uint256 contractBalance, // Saldo de LIBR retido no contrato
        uint256 totalReleased_, // Total liberado via vesting
        uint256 timeUntilDAO, // Tempo restante para ativar a DAO
        uint256[4] memory phaseAmounts, // Quantidade liberada por fase
        bool[4] memory phaseReleased // Fases totalmente liberadas
    ) {
        phaseAmounts[0] = releasedAmount[PHASE_FUNDACAO];
        phaseAmounts[1] = releasedAmount[PHASE_EXPANSAO];
        phaseAmounts[2] = releasedAmount[PHASE_LIBERTACAO];
        phaseAmounts[3] = releasedAmount[PHASE_RESERVA];

        phaseReleased[0] = released[PHASE_FUNDACAO];
        phaseReleased[1] = released[PHASE_EXPANSAO];
        phaseReleased[2] = released[PHASE_LIBERTACAO];
        phaseReleased[3] = released[PHASE_RESERVA];

        return (
            antiWhaleEnabled,
            antiWhalePermanentlyDisabled,
            daoActive,
            upgradeAllowed,
            upgradePermanentlyDisabled,
            balanceOf(address(this)),
            _totalReleasedAmount,
            timeUntilDAOActivation(),
            phaseAmounts,
            phaseReleased
        );
    }

    // Gap de armazenamento UUPS (necessário para garantir que variáveis futuras não sobreponham o estado do proxy)
    uint256[100] private __gap; 
}
/*╔═══════════════════════════════════════════════════════════════════════════╗
  ║                      FIM DO CONTRATO LIBR TOKEN                              
  ║ Isaías 40:31: “Mas os que esperam no Senhor renovarão as suas forças...”      
  ║ © 2025 Ordem Libertária Brasil — Todos os direitos reservados.               
  ╚═══════════════════════════════════════════════════════════════════════════╝*/