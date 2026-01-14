// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "./Bet.sol";
import "./UsernameRegistry.sol";
import "../liquidity/CDOPool.sol";
import "../liquidity/CDOPoolFactory.sol";
import "../liquidity/BetRiskValidator.sol";

/**
 * @title BetFactory
 * @notice Factory for creating P2P bets with minimal proxy pattern (EIP-1167)
 * @dev Uses clones for gas-efficient bet deployment
 */
contract BetFactory is Ownable, ReentrancyGuard {
    // ============ State Variables ============

    address public immutable betImplementation;
    address public immutable usdc;
    address public yieldVault;
    UsernameRegistry public immutable usernameRegistry;

    // House (CDO Pool) integration
    CDOPool public cdoPool; // DEPRECATED: Legacy single pool support
    CDOPoolFactory public poolFactory; // NEW: Multi-pool factory
    uint256 public defaultPoolId; // Default pool for uncategorized bets
    BetRiskValidator public riskValidator;

    // Special identifier for house opponent
    string public constant HOUSE_IDENTIFIER = "HOUSE";
    address public constant HOUSE_ADDRESS = address(0x486F757365); // "House" in hex

    mapping(address => address[]) public userBets;  // user => their bets
    address[] public allBets;

    // Track house-matched bets
    mapping(address => bool) public isHouseBet;  // bet => is matched with house
    address[] public houseBets;
    mapping(address => address) public betToPool;  // bet => pool that matched it

    struct ProtocolConfig {
        uint256 minStakeAmount;          // Minimum USDC stake (6 decimals)
        uint256 maxStakeAmount;          // Maximum USDC stake
        uint256 minDuration;             // Minimum bet duration
        uint256 maxDuration;             // Maximum bet duration
        uint256 maxBetsPerUser;          // Max active bets per user (0 = unlimited)
        uint256 maxTotalBets;            // Max total active bets (0 = unlimited)
        bool paused;                     // Emergency pause
    }

    ProtocolConfig public config;

    // ============ Events ============

    event BetCreated(
        address indexed betContract,
        address indexed creator,
        address indexed opponent,
        uint256 stakeAmount,
        uint256 duration,
        string description,
        uint256 timestamp
    );

    event HouseBetCreated(
        address indexed betContract,
        address indexed creator,
        uint256 stakeAmount,
        uint256 duration,
        string description,
        bytes32 indexed betId,
        uint256 timestamp
    );

    event HouseBetMatched(
        address indexed betContract,
        uint256 poolAmount,
        uint256 timestamp
    );

    event HouseBetRejected(
        address indexed betContract,
        string reason,
        uint256 timestamp
    );

    event ConfigUpdated(string parameter, uint256 newValue, uint256 timestamp);
    event YieldVaultUpdated(address oldVault, address newVault, uint256 timestamp);
    event CDOPoolUpdated(address oldPool, address newPool, uint256 timestamp);
    event RiskValidatorUpdated(address oldValidator, address newValidator, uint256 timestamp);
    event ProtocolPaused(bool paused, uint256 timestamp);

    // ============ Errors ============

    error ProtocolIsPaused();
    error InvalidOpponent();
    error InvalidStakeAmount();
    error InvalidDuration();
    error YieldVaultNotSet();
    error CDOPoolNotSet();
    error PoolFactoryNotSet();
    error NoPoolForCategory();
    error RiskValidatorNotSet();
    error HouseBetRejectedByRiskValidator(string reason);
    error InsufficientPoolLiquidity();

    // ============ Constructor ============

    constructor(
        address _usdc,
        address _usernameRegistry
    ) Ownable(msg.sender) {
        require(_usdc != address(0), "Invalid USDC");
        require(_usernameRegistry != address(0), "Invalid registry");

        usdc = _usdc;
        usernameRegistry = UsernameRegistry(_usernameRegistry);

        // Deploy implementation contract with valid placeholder addresses
        // Note: We use address(this) as placeholder vault since address(0) now fails validation
        betImplementation = address(new Bet(
            address(this), // placeholder creator (non-zero)
            address(1),    // placeholder opponent
            1,             // placeholder stake
            "Implementation", // placeholder description (must be non-empty)
            "Implementation", // placeholder outcome desc
            1 hours,       // placeholder duration
            new string[](0), // placeholder tags
            _usdc,
            address(this), // placeholder vault (non-zero, will be overridden in actual bets)
            _usernameRegistry
        ));

        // Set default config
        config = ProtocolConfig({
            minStakeAmount: 1 * 10**6,       // 1 USDC
            maxStakeAmount: 1_000_000 * 10**6, // 1M USDC
            minDuration: 1 hours,
            maxDuration: 365 days,
            maxBetsPerUser: 100,             // Max 100 active bets per user
            maxTotalBets: 10000,             // Max 10k total active bets
            paused: false
        });
    }

    // ============ External Functions ============

    /**
     * @notice Create a new bet
     * @param opponentIdentifier Username, ENS, address of opponent, or "HOUSE" for pool matching
     * @param stakeAmount Amount of USDC to stake (6 decimals)
     * @param description Bet description
     * @param outcomeDescription How to determine outcome
     * @param duration Bet duration in seconds
     * @param tags Tags for categorization
     * @return betContract Address of created bet
     */
    function createBet(
        string calldata opponentIdentifier,
        uint256 stakeAmount,
        string calldata description,
        string calldata outcomeDescription,
        uint256 duration,
        string[] calldata tags
    ) external nonReentrant returns (address betContract) {
        if (config.paused) revert ProtocolIsPaused();
        if (yieldVault == address(0)) revert YieldVaultNotSet();
        if (stakeAmount < config.minStakeAmount || stakeAmount > config.maxStakeAmount) {
            revert InvalidStakeAmount();
        }
        if (duration < config.minDuration || duration > config.maxDuration) {
            revert InvalidDuration();
        }

        // Check user bet limit
        if (config.maxBetsPerUser > 0 && userBets[msg.sender].length >= config.maxBetsPerUser) {
            revert("Max bets per user reached");
        }

        // Check total bet limit
        if (config.maxTotalBets > 0 && allBets.length >= config.maxTotalBets) {
            revert("Max total bets reached");
        }

        // Check if opponent is "HOUSE"
        bool isHouse = _isStringEqual(opponentIdentifier, HOUSE_IDENTIFIER);

        if (isHouse) {
            // Create house bet with AI validation
            return _createHouseBet(
                stakeAmount,
                description,
                outcomeDescription,
                duration,
                tags
            );
        } else {
            // Regular P2P bet
            // Resolve opponent address
            address opponent = usernameRegistry.resolveIdentifier(opponentIdentifier);
            if (opponent == address(0) || opponent == msg.sender) revert InvalidOpponent();

            // Create bet using minimal proxy (EIP-1167)
            betContract = _deployBet(
                msg.sender,
                opponent,
                stakeAmount,
                description,
                outcomeDescription,
                duration,
                tags
            );

            // Track bet
            userBets[msg.sender].push(betContract);
            userBets[opponent].push(betContract);
            allBets.push(betContract);

            emit BetCreated(
                betContract,
                msg.sender,
                opponent,
                stakeAmount,
                duration,
                description,
                block.timestamp
            );

            return betContract;
        }
    }

    /**
     * @notice Get all bets for a user
     * @param user User address
     * @return Array of bet contract addresses
     */
    function getBetsForUser(address user) external view returns (address[] memory) {
        return userBets[user];
    }

    /**
     * @notice Get all bets
     * @return Array of all bet contract addresses
     */
    function getAllBets() external view returns (address[] memory) {
        return allBets;
    }

    /**
     * @notice Get total bet count
     */
    function getTotalBets() external view returns (uint256) {
        return allBets.length;
    }

    // ============ Owner Functions ============

    /**
     * @notice Set yield vault address (must be set before creating bets)
     * @param _yieldVault Address of BetYieldVault
     */
    function setYieldVault(address _yieldVault) external onlyOwner {
        require(_yieldVault != address(0), "Invalid vault");
        address oldVault = yieldVault;
        yieldVault = _yieldVault;
        emit YieldVaultUpdated(oldVault, _yieldVault, block.timestamp);
    }

    /**
     * @notice Update protocol configuration
     */
    function updateConfig(
        uint256 _minStakeAmount,
        uint256 _maxStakeAmount,
        uint256 _minDuration,
        uint256 _maxDuration,
        uint256 _maxBetsPerUser,
        uint256 _maxTotalBets
    ) external onlyOwner {
        config.minStakeAmount = _minStakeAmount;
        config.maxStakeAmount = _maxStakeAmount;
        config.minDuration = _minDuration;
        config.maxDuration = _maxDuration;
        config.maxBetsPerUser = _maxBetsPerUser;
        config.maxTotalBets = _maxTotalBets;

        emit ConfigUpdated("config", block.timestamp, block.timestamp);
    }

    /**
     * @notice Pause/unpause protocol
     */
    function setPaused(bool _paused) external onlyOwner {
        config.paused = _paused;
        emit ProtocolPaused(_paused, block.timestamp);
    }

    // ============ Internal Functions ============

    /**
     * @dev Deploy a new bet contract using EIP-1167 minimal proxy
     * @dev Uses deterministic cloning for ~10x gas savings vs full contract deployment
     */
    function _deployBet(
        address creator,
        address opponent,
        uint256 stakeAmount,
        string calldata description,
        string calldata outcomeDescription,
        uint256 duration,
        string[] calldata tags
    ) internal returns (address) {
        // TODO: Implement EIP-1167 minimal proxy pattern for gas optimization
        // Current implementation uses full deployment (~2M gas)
        // Future: Use Clones.cloneDeterministic for ~10x gas savings (~200k gas)
        // Requires refactoring Bet.sol to use initializer pattern instead of constructor
        //
        // bytes32 salt = keccak256(abi.encodePacked(creator, opponent, block.timestamp, allBets.length));
        // address betClone = Clones.cloneDeterministic(betImplementation, salt);
        //
        // For now, deploy full contracts
        Bet bet = new Bet(
            creator,
            opponent,
            stakeAmount,
            description,
            outcomeDescription,
            duration,
            tags,
            usdc,
            yieldVault,
            address(usernameRegistry)
        );

        return address(bet);
    }

    /**
     * @dev Create a house bet with risk validation
     * @dev AI validation happens on frontend for UX, on-chain validation for security
     */
    function _createHouseBet(
        uint256 stakeAmount,
        string calldata description,
        string calldata outcomeDescription,
        uint256 duration,
        string[] calldata tags
    ) internal returns (address betContract) {
        // Validate house bet requirements
        if (address(riskValidator) == address(0)) revert RiskValidatorNotSet();

        // NEW: Select pool based on bet category (first tag)
        CDOPool selectedPool = _selectPoolForBet(tags);

        // Create bet with HOUSE_ADDRESS as opponent
        betContract = _deployBet(
            msg.sender,
            HOUSE_ADDRESS,
            stakeAmount,
            description,
            outcomeDescription,
            duration,
            tags
        );

        // Validate and match with selected pool (BetRiskValidator enforces security)
        _validateAndMatchHouseBet(betContract, stakeAmount, selectedPool);

        // Track house bet
        bytes32 betId = keccak256(abi.encodePacked(
            msg.sender,
            stakeAmount,
            description,
            block.timestamp,
            allBets.length
        ));
        _trackHouseBet(betContract, stakeAmount, duration, description, betId);

        return betContract;
    }


    /**
     * @dev Validate bet and match with pool
     * @param betContract Address of bet contract
     * @param stakeAmount Stake amount in USDC
     * @param pool Selected CDOPool to match with
     */
    function _validateAndMatchHouseBet(
        address betContract,
        uint256 stakeAmount,
        CDOPool pool
    ) internal {
        uint256 availableLiquidity = pool.getAvailableLiquidity();

        // Check pool has sufficient liquidity first
        if (stakeAmount > availableLiquidity) {
            emit HouseBetRejected(betContract, "Insufficient pool liquidity", block.timestamp);
            revert InsufficientPoolLiquidity();
        }

        // Validate bet with risk validator
        (bool isValid, string memory reason) = riskValidator.validateBetForMatching(
            betContract,
            availableLiquidity,
            pool.getUtilizationRate()
        );

        if (!isValid) {
            emit HouseBetRejected(betContract, reason, block.timestamp);
            revert HouseBetRejectedByRiskValidator(reason);
        }

        // Match with selected pool immediately
        pool.matchBet(betContract, stakeAmount);

        // Track which pool matched this bet (needed for auto-funding)
        betToPool[betContract] = address(pool);
    }

    /**
     * @dev Select appropriate pool based on bet category
     * @param tags Bet tags (first tag is primary category)
     * @return CDOPool instance to match bet with
     */
    function _selectPoolForBet(string[] calldata tags) internal view returns (CDOPool) {
        // Priority 1: Use multi-pool factory if set
        if (address(poolFactory) != address(0)) {
            // Try to find pool by category (first tag)
            if (tags.length > 0) {
                address poolAddress = poolFactory.getPoolByCategory(tags[0]);
                if (poolAddress != address(0)) {
                    return CDOPool(poolAddress);
                }
            }

            // Fallback to default pool if category not found
            if (defaultPoolId < poolFactory.getTotalPools()) {
                CDOPoolFactory.PoolMetadata memory metadata = poolFactory.getPoolMetadata(defaultPoolId);
                if (metadata.isActive) {
                    return CDOPool(metadata.poolAddress);
                }
            }

            revert NoPoolForCategory();
        }

        // Priority 2: Use legacy single pool (backward compatibility)
        if (address(cdoPool) != address(0)) {
            return cdoPool;
        }

        // No pool configured
        revert CDOPoolNotSet();
    }

    /**
     * @dev Track house bet in mappings and emit events
     */
    function _trackHouseBet(
        address betContract,
        uint256 stakeAmount,
        uint256 duration,
        string calldata description,
        bytes32 betId
    ) internal {
        // Mark as house bet
        isHouseBet[betContract] = true;
        houseBets.push(betContract);

        // Track bet
        userBets[msg.sender].push(betContract);
        allBets.push(betContract);

        emit HouseBetCreated(
            betContract,
            msg.sender,
            stakeAmount,
            duration,
            description,
            betId,
            block.timestamp
        );

        emit HouseBetMatched(betContract, stakeAmount, block.timestamp);
    }

    /**
     * @dev Compare two strings for equality
     */
    function _isStringEqual(string calldata a, string memory b) internal pure returns (bool) {
        return keccak256(abi.encodePacked(a)) == keccak256(abi.encodePacked(b));
    }

    // ============ Owner Functions - House Integration ============

    /**
     * @notice Set CDO Pool address (LEGACY - for backward compatibility)
     * @dev Use setCDOPoolFactory for multi-pool support
     */
    function setCDOPool(address _cdoPool) external onlyOwner {
        require(_cdoPool != address(0), "Invalid pool");
        address oldPool = address(cdoPool);
        cdoPool = CDOPool(_cdoPool);
        emit CDOPoolUpdated(oldPool, _cdoPool, block.timestamp);
    }

    /**
     * @notice Set CDO Pool Factory address (NEW - multi-pool support)
     * @param _poolFactory Address of CDOPoolFactory
     */
    function setCDOPoolFactory(address _poolFactory) external onlyOwner {
        require(_poolFactory != address(0), "Invalid factory");
        poolFactory = CDOPoolFactory(_poolFactory);
    }

    /**
     * @notice Set default pool ID for uncategorized bets
     * @param _defaultPoolId Pool ID to use as fallback
     */
    function setDefaultPool(uint256 _defaultPoolId) external onlyOwner {
        require(address(poolFactory) != address(0), "Factory not set");
        require(_defaultPoolId < poolFactory.getTotalPools(), "Invalid pool ID");
        defaultPoolId = _defaultPoolId;
    }

    /**
     * @notice Set Risk Validator address
     */
    function setRiskValidator(address _riskValidator) external onlyOwner {
        require(_riskValidator != address(0), "Invalid validator");
        address oldValidator = address(riskValidator);
        riskValidator = BetRiskValidator(_riskValidator);
        emit RiskValidatorUpdated(oldValidator, _riskValidator, block.timestamp);
    }

    // ============ View Functions - House Bets ============

    /**
     * @notice Get all house bets
     */
    function getHouseBets() external view returns (address[] memory) {
        return houseBets;
    }

    /**
     * @notice Check if a bet is matched with house
     */
    function isHouseMatch(address betContract) external view returns (bool) {
        return isHouseBet[betContract];
    }

    /**
     * @notice Get house bets count
     */
    function getHouseBetsCount() external view returns (uint256) {
        return houseBets.length;
    }

    /**
     * @notice Get the pool that matched a specific bet
     * @param betContract Address of the bet contract
     * @return poolAddress Address of the pool, or address(0) if not a house bet
     */
    function getMatchedPool(address betContract) external view returns (address poolAddress) {
        return betToPool[betContract];
    }
}
