// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title UsernameRegistry
 * @notice Manages username registration and identity resolution for the Just-a-Bet platform
 * @dev Supports username, ENS name, and wallet address resolution
 */
contract UsernameRegistry is Ownable, ReentrancyGuard {
    // ============ Structs ============

    struct UserProfile {
        string username;
        string ensName;         // Human-readable ENS name
        bytes32 ensNode;        // ENS node hash (if linked)
        uint96 registeredAt;    // Timestamp (uint96 is sufficient until year 2500+)
        bool isActive;
    }

    // ============ State Variables ============

    mapping(address => UserProfile) public profiles;
    mapping(string => address) public usernameToAddress;
    mapping(bytes32 => address) public ensNodeToAddress;

    uint256 public totalUsers;
    uint256 public constant MAX_USERNAME_LENGTH = 32;
    uint256 public constant MIN_USERNAME_LENGTH = 3;

    // ============ Events ============

    event UsernameRegistered(
        address indexed user,
        string username,
        uint256 timestamp
    );

    event UsernameUpdated(
        address indexed user,
        string oldUsername,
        string newUsername,
        uint256 timestamp
    );

    event ENSLinked(
        address indexed user,
        bytes32 indexed ensNode,
        string ensName,
        uint256 timestamp
    );

    event UserDeactivated(
        address indexed user,
        string username,
        uint256 timestamp
    );

    // ============ Errors ============

    error InvalidUsername();
    error UsernameTaken();
    error UsernameNotFound();
    error NoUsernameRegistered();
    error UserAlreadyRegistered();
    error InvalidENSNode();
    error Unauthorized();

    // ============ Constructor ============

    constructor() Ownable(msg.sender) {}

    // ============ External Functions ============

    /**
     * @notice Register a new username for the caller
     * @param _username The desired username (3-32 characters, alphanumeric + underscore)
     */
    function registerUsername(string calldata _username) external nonReentrant {
        if (profiles[msg.sender].isActive) revert UserAlreadyRegistered();
        if (!_isValidUsername(_username)) revert InvalidUsername();
        if (usernameToAddress[_username] != address(0)) revert UsernameTaken();

        profiles[msg.sender] = UserProfile({
            username: _username,
            ensName: "",
            ensNode: bytes32(0),
            registeredAt: uint96(block.timestamp),
            isActive: true
        });

        usernameToAddress[_username] = msg.sender;
        totalUsers++;

        emit UsernameRegistered(msg.sender, _username, block.timestamp);
    }

    /**
     * @notice Update existing username
     * @param _newUsername The new desired username
     */
    function updateUsername(string calldata _newUsername) external nonReentrant {
        if (!profiles[msg.sender].isActive) revert NoUsernameRegistered();
        if (!_isValidUsername(_newUsername)) revert InvalidUsername();
        if (usernameToAddress[_newUsername] != address(0)) revert UsernameTaken();

        string memory oldUsername = profiles[msg.sender].username;

        // Clear old mapping
        delete usernameToAddress[oldUsername];

        // Update to new username
        profiles[msg.sender].username = _newUsername;
        usernameToAddress[_newUsername] = msg.sender;

        emit UsernameUpdated(msg.sender, oldUsername, _newUsername, block.timestamp);
    }

    /**
     * @notice Link an ENS name to the user's profile
     * @param _ensNode The ENS node hash (namehash of the ENS name)
     * @param _ensName Human-readable ENS name (e.g., "alice.eth")
     */
    function linkENS(bytes32 _ensNode, string calldata _ensName) external nonReentrant {
        if (!profiles[msg.sender].isActive) revert NoUsernameRegistered();
        if (_ensNode == bytes32(0)) revert InvalidENSNode();

        profiles[msg.sender].ensNode = _ensNode;
        profiles[msg.sender].ensName = _ensName;
        ensNodeToAddress[_ensNode] = msg.sender;

        emit ENSLinked(msg.sender, _ensNode, _ensName, block.timestamp);
    }

    /**
     * @notice Deactivate user account
     * @dev Deletes username mapping to prevent squatting.
     *      User can re-register with a different username.
     */
    function deactivateAccount() external nonReentrant {
        if (!profiles[msg.sender].isActive) revert NoUsernameRegistered();

        string memory username = profiles[msg.sender].username;

        // Clear username mapping to prevent squatting
        delete usernameToAddress[username];

        // Clear ENS mapping if exists
        if (profiles[msg.sender].ensNode != bytes32(0)) {
            delete ensNodeToAddress[profiles[msg.sender].ensNode];
        }

        // Mark profile as inactive
        profiles[msg.sender].isActive = false;
        totalUsers--;

        emit UserDeactivated(msg.sender, username, block.timestamp);
    }

    // ============ View Functions ============

    /**
     * @notice Resolve any identifier (username, ENS name, or address) to a wallet address
     * @param _identifier Can be:
     *        - Username (e.g., "alice")
     *        - ENS name (e.g., "alice.eth") - Note: Currently returns address from our mapping
     *        - Ethereum address as string (e.g., "0x...")
     * @return Resolved Ethereum address
     */
    function resolveIdentifier(string calldata _identifier) external view returns (address) {
        // Try as username first
        address resolved = usernameToAddress[_identifier];
        if (resolved != address(0) && profiles[resolved].isActive) {
            return resolved;
        }

        // Try as ENS name
        bytes32 ensNode = _stringToENSNode(_identifier);
        resolved = ensNodeToAddress[ensNode];
        if (resolved != address(0) && profiles[resolved].isActive) {
            return resolved;
        }

        // Try as Ethereum address
        resolved = _parseAddress(_identifier);
        if (resolved != address(0)) {
            return resolved;
        }

        revert UsernameNotFound();
    }

    /**
     * @notice Get user profile by address
     * @param _user User address
     * @return UserProfile struct
     */
    function getProfile(address _user) external view returns (UserProfile memory) {
        return profiles[_user];
    }

    /**
     * @notice Check if a username is available
     * @param _username Username to check
     * @return bool True if available
     */
    function isUsernameAvailable(string calldata _username) external view returns (bool) {
        return usernameToAddress[_username] == address(0) && _isValidUsername(_username);
    }

    /**
     * @notice Get username by address
     * @param _user User address
     * @return Username string
     */
    function getUsername(address _user) external view returns (string memory) {
        if (!profiles[_user].isActive) revert NoUsernameRegistered();
        return profiles[_user].username;
    }

    // ============ Internal Functions ============

    /**
     * @dev Validate username format
     * - Length: 3-32 characters
     * - Characters: a-z, A-Z, 0-9, underscore
     * - Cannot start with number
     */
    function _isValidUsername(string calldata _username) internal pure returns (bool) {
        bytes memory usernameBytes = bytes(_username);
        uint256 len = usernameBytes.length;

        if (len < MIN_USERNAME_LENGTH || len > MAX_USERNAME_LENGTH) {
            return false;
        }

        // Check first character is not a digit
        if (usernameBytes[0] >= 0x30 && usernameBytes[0] <= 0x39) {
            return false;
        }

        // Validate each character
        for (uint256 i = 0; i < len; i++) {
            bytes1 char = usernameBytes[i];
            bool isValid = (char >= 0x30 && char <= 0x39) || // 0-9
                          (char >= 0x41 && char <= 0x5A) || // A-Z
                          (char >= 0x61 && char <= 0x7A) || // a-z
                          (char == 0x5F);                   // underscore

            if (!isValid) {
                return false;
            }
        }

        return true;
    }

    /**
     * @dev Convert string to ENS node hash (simplified - just for demo)
     * In production, use proper ENS namehash
     */
    function _stringToENSNode(string calldata _ensName) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(_ensName));
    }

    /**
     * @dev Parse string as Ethereum address
     * Returns address(0) if invalid
     */
    function _parseAddress(string calldata _addressString) internal pure returns (address) {
        bytes memory addressBytes = bytes(_addressString);

        // Must start with "0x" and be 42 characters total
        if (addressBytes.length != 42) {
            return address(0);
        }

        if (addressBytes[0] != 0x30 || addressBytes[1] != 0x78) { // "0x"
            return address(0);
        }

        uint160 addr = 0;
        for (uint256 i = 2; i < 42; i++) {
            uint8 digit = _hexCharToUint(addressBytes[i]);
            if (digit == 255) {
                return address(0); // Invalid hex character
            }
            addr = addr * 16 + digit;
        }

        return address(addr);
    }

    /**
     * @dev Convert hex character to uint
     * Returns 255 if invalid
     */
    function _hexCharToUint(bytes1 char) internal pure returns (uint8) {
        if (char >= 0x30 && char <= 0x39) { // 0-9
            return uint8(char) - 48;
        }
        if (char >= 0x41 && char <= 0x46) { // A-F
            return uint8(char) - 55;
        }
        if (char >= 0x61 && char <= 0x66) { // a-f
            return uint8(char) - 87;
        }
        return 255; // Invalid
    }
}
