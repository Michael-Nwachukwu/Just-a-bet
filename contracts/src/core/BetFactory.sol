// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "./Bet.sol";
import "./UsernameRegistry.sol";

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

    mapping(address => address[]) public userBets;  // user => their bets
    address[] public allBets;

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

    event ConfigUpdated(string parameter, uint256 newValue, uint256 timestamp);
    event YieldVaultUpdated(address oldVault, address newVault, uint256 timestamp);
    event ProtocolPaused(bool paused, uint256 timestamp);

    // ============ Errors ============

    error ProtocolIsPaused();
    error InvalidOpponent();
    error InvalidStakeAmount();
    error InvalidDuration();
    error YieldVaultNotSet();

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
     * @param opponentIdentifier Username, ENS, or address of opponent
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
}
