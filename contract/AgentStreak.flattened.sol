// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// src/AgentStreak.sol

/// @title AgentStreak — free daily streak claim for Binance Agent ID holders
/// @notice NO owner, NO fees, NO upgradeability, NO pause, NO token, NO funds held.
///         This contract holds no BNB and no tokens; claim() is free apart from gas.
///         Built for the Binance Agent ID Hackathon (submission ends 9 Dec 2026 08:00 UTC).
///         One deployment only: the soulbound badge is a minimal ERC721 implemented
///         inside this same contract (no OpenZeppelin — hand-rolled to keep deploy gas low).
/// @dev Agent ID = SPACE ID ERC-721 on BNB Smart Chain mainnet (chain 56).
contract AgentStreak {
    // ------------------------------------------------------------------------
    // Constants
    // ------------------------------------------------------------------------

    /// @notice SPACE ID Agent ID contract (ERC-721, non-transferable) on BNB Chain.
    address public constant AGENT_ID =
        0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F;

    string public constant name = "AgentStreak Badge";
    string public constant symbol = "ASTREAK";

    // ------------------------------------------------------------------------
    // Types / storage
    // ------------------------------------------------------------------------

    struct User {
        uint64 lastClaimDay; // UTC day of last claim (block.timestamp / 86400)
        uint32 streak; // current consecutive-day streak
        uint32 totalClaims; // lifetime claims
        bool hasBadge; // badge minted (first claim)
    }
    // Packed into a single storage slot (64 + 32 + 32 + 8 bits).

    mapping(address => User) private _users;
    address[] private _claimants; // first-time claimants, in order (leaderboard source)
    uint256 public totalClaims; // global claim counter

    // ------------------------------------------------------------------------
    // Events
    // ------------------------------------------------------------------------

    event Claimed(
        address indexed user,
        uint64 day,
        uint32 streak,
        uint32 totalClaims
    );
    event BadgeMinted(address indexed user, uint256 indexed tokenId);
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    // ------------------------------------------------------------------------
    // Errors
    // ------------------------------------------------------------------------

    error NotAgentIdHolder();
    error AlreadyClaimedToday();
    error Soulbound();
    error BadgeNotMinted();

    // ------------------------------------------------------------------------
    // Claim
    // ------------------------------------------------------------------------

    /// @notice Claim today's streak. One claim per UTC day. Requires holding an Agent ID.
    /// @dev Streak: +1 if yesterday was claimed, else resets to 1. First claim mints
    ///      the soulbound badge (tokenId = uint160(msg.sender)).
    function claim() external {
        uint64 day = uint64(block.timestamp / 86400);
        User storage u = _users[msg.sender];

        if (u.lastClaimDay == day) revert AlreadyClaimedToday();
        if (IAgentID(AGENT_ID).balanceOf(msg.sender) == 0)
            revert NotAgentIdHolder();

        if (u.lastClaimDay + 1 == day) {
            u.streak += 1;
        } else {
            u.streak = 1;
        }
        u.lastClaimDay = day;
        u.totalClaims += 1;
        totalClaims += 1;

        if (!u.hasBadge) {
            u.hasBadge = true;
            _claimants.push(msg.sender);
            uint256 tokenId = uint160(msg.sender);
            emit Transfer(address(0), msg.sender, tokenId);
            emit BadgeMinted(msg.sender, tokenId);
        }

        emit Claimed(msg.sender, day, u.streak, u.totalClaims);
    }

    // ------------------------------------------------------------------------
    // Views
    // ------------------------------------------------------------------------

    function getStreak(address user) external view returns (uint32) {
        return _users[user].streak;
    }

    function getStats(
        address user
    )
        external
        view
        returns (
            uint32 streak,
            uint32 totalClaims_,
            uint64 lastClaimDay,
            bool hasBadge
        )
    {
        User storage u = _users[user];
        return (u.streak, u.totalClaims, u.lastClaimDay, u.hasBadge);
    }

    function totalClaimants() external view returns (uint256) {
        return _claimants.length;
    }

    function claimants(uint256 index) external view returns (address) {
        return _claimants[index];
    }

    /// @notice Paged leaderboard source: claimants[offset .. offset+limit).
    function getClaimants(
        uint256 offset,
        uint256 limit
    ) external view returns (address[] memory) {
        uint256 len = _claimants.length;
        if (offset >= len) return new address[](0);
        uint256 end = offset + limit;
        if (end > len) end = len;
        address[] memory out = new address[](end - offset);
        for (uint256 i = offset; i < end; i++) {
            out[i - offset] = _claimants[i];
        }
        return out;
    }

    // ------------------------------------------------------------------------
    // Minimal ERC721 (soulbound badge) — read surface + metadata
    // ------------------------------------------------------------------------

    function balanceOf(address owner) external view returns (uint256) {
        if (owner == address(0)) revert BadgeNotMinted();
        return _users[owner].hasBadge ? 1 : 0;
    }

    function ownerOf(uint256 tokenId) external view returns (address) {
        address holder = address(uint160(tokenId));
        if (!_users[holder].hasBadge) revert BadgeNotMinted();
        return holder;
    }

    function tokenURI(uint256 tokenId) external view returns (string memory) {
        address holder = address(uint160(tokenId));
        User storage u = _users[holder];
        if (!u.hasBadge) revert BadgeNotMinted();
        return
            string(
                abi.encodePacked(
                    'data:application/json,{"name":"AgentStreak Badge #',
                    _toString(tokenId),
                    '","description":"Soulbound daily streak badge for Binance Agent ID holders. Claim every day to grow your streak.","attributes":[{"trait_type":"Streak","value":',
                    _toString(u.streak),
                    '},{"trait_type":"Total Claims","value":',
                    _toString(u.totalClaims),
                    '}]}'
                )
            );
    }

    function getApproved(uint256) external pure returns (address) {
        return address(0);
    }

    function isApprovedForAll(address, address) external pure returns (bool) {
        return false;
    }

    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return
            interfaceId == 0x01ffc9a7 || // ERC165
            interfaceId == 0x80ac58cd || // ERC721
            interfaceId == 0x5b5e139f; // ERC721Metadata
    }

    // ------------------------------------------------------------------------
    // Soulbound: every transfer / approval reverts
    // ------------------------------------------------------------------------

    function approve(address, uint256) external pure {
        revert Soulbound();
    }

    function setApprovalForAll(address, bool) external pure {
        revert Soulbound();
    }

    function transferFrom(address, address, uint256) external pure {
        revert Soulbound();
    }

    function safeTransferFrom(address, address, uint256) external pure {
        revert Soulbound();
    }

    function safeTransferFrom(address, address, uint256, bytes calldata) external pure {
        revert Soulbound();
    }

    // ------------------------------------------------------------------------
    // Internal helpers
    // ------------------------------------------------------------------------

    function _toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) return "0";
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }
}

interface IAgentID {
    function balanceOf(address owner) external view returns (uint256);
}
