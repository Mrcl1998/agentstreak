// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/AgentStreak.sol";

/// @notice Mock Agent ID (ERC-721 balanceOf only) standing in for
///         0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F in tests.
contract MockAgentID {
    mapping(address => uint256) public bal;

    function setBalance(address user, uint256 amount) external {
        bal[user] = amount;
    }

    function balanceOf(address owner) external view returns (uint256) {
        return bal[owner];
    }
}

contract AgentStreakTest is Test {
    AgentStreak public streak;
    MockAgentID public agentId;

    address alice = address(0xA11CE);
    address bob = address(0xB0B);
    address carol = address(0xCA901);

    address constant AGENT_ID_ADDR =
        0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F;

    function setUp() public {
        agentId = new MockAgentID();
        // Etch the mock's code at the real Agent ID address (constant in the
        // contract under test). Etching copies code only, NOT storage, so the
        // mock balances are written directly into the etched address's storage:
        // mapping(address => uint256) at slot 0 -> keccak256(abi.encode(key, 0)).
        vm.etch(AGENT_ID_ADDR, address(agentId).code);
        vm.store(
            AGENT_ID_ADDR,
            keccak256(abi.encode(alice, uint256(0))),
            bytes32(uint256(1))
        );
        vm.store(
            AGENT_ID_ADDR,
            keccak256(abi.encode(bob, uint256(0))),
            bytes32(uint256(2))
        );
        // carol holds none
        streak = new AgentStreak();
        vm.warp(1_800_000_000); // 2027-01-15-ish, day 20833
    }

    // -- helpers -------------------------------------------------------------

    function _day() internal view returns (uint64) {
        return uint64(block.timestamp / 86400);
    }

    // -- tests ---------------------------------------------------------------

    function test_claimWorksForHolder() public {
        vm.prank(alice);
        streak.claim();
        (uint32 s, uint32 t, uint64 d, bool b) = streak.getStats(alice);
        assertEq(s, 1);
        assertEq(t, 1);
        assertEq(d, _day());
        assertTrue(b);
        assertEq(streak.getStreak(alice), 1);
        assertEq(streak.totalClaims(), 1);
        assertEq(streak.totalClaimants(), 1);
        assertEq(streak.claimants(0), alice);
    }

    function test_doubleClaimSameDayReverts() public {
        vm.prank(alice);
        streak.claim();
        vm.prank(alice);
        vm.expectRevert(AgentStreak.AlreadyClaimedToday.selector);
        streak.claim();
    }

    function test_streakIncrementsConsecutiveDays() public {
        vm.prank(alice);
        streak.claim();
        vm.warp(vm.getBlockTimestamp() + 86400);
        vm.prank(alice);
        streak.claim();
        vm.warp(vm.getBlockTimestamp() + 86400);
        vm.prank(alice);
        streak.claim();
        assertEq(streak.getStreak(alice), 3);
        (, uint32 t, , ) = streak.getStats(alice);
        assertEq(t, 3);
    }

    function test_streakResetsAfterMissedDay() public {
        vm.prank(alice);
        streak.claim();
        vm.warp(vm.getBlockTimestamp() + 86400);
        vm.prank(alice);
        streak.claim();
        assertEq(streak.getStreak(alice), 2);
        vm.warp(vm.getBlockTimestamp() + 2 * 86400); // miss one full day
        vm.prank(alice);
        streak.claim();
        assertEq(streak.getStreak(alice), 1);
    }

    function test_nonHolderReverts() public {
        vm.prank(carol);
        vm.expectRevert(AgentStreak.NotAgentIdHolder.selector);
        streak.claim();
    }

    function test_badgeMintedExactlyOnce() public {
        vm.prank(alice);
        streak.claim();
        uint256 tokenId = uint160(alice);
        assertEq(streak.ownerOf(tokenId), alice);
        assertEq(streak.balanceOf(alice), 1);
        vm.warp(vm.getBlockTimestamp() + 86400);
        vm.prank(alice);
        streak.claim();
        // Still exactly one badge, same tokenId, no second mint.
        assertEq(streak.balanceOf(alice), 1);
        assertEq(streak.ownerOf(tokenId), alice);
        assertEq(streak.totalClaimants(), 1);
    }

    function test_badgeTransferAndApproveRevert() public {
        vm.prank(alice);
        streak.claim();
        uint256 tokenId = uint160(alice);
        vm.prank(alice);
        vm.expectRevert(AgentStreak.Soulbound.selector);
        streak.transferFrom(alice, bob, tokenId);
        vm.prank(alice);
        vm.expectRevert(AgentStreak.Soulbound.selector);
        streak.safeTransferFrom(alice, bob, tokenId);
        vm.prank(alice);
        vm.expectRevert(AgentStreak.Soulbound.selector);
        streak.safeTransferFrom(alice, bob, tokenId, "");
        vm.prank(alice);
        vm.expectRevert(AgentStreak.Soulbound.selector);
        streak.approve(bob, tokenId);
        vm.prank(alice);
        vm.expectRevert(AgentStreak.Soulbound.selector);
        streak.setApprovalForAll(bob, true);
    }

    function test_badgeTokenIdEqualsAddressAsUint160() public {
        vm.prank(bob);
        streak.claim();
        assertEq(uint160(bob), uint256(uint160(bob)));
        assertEq(streak.ownerOf(uint160(bob)), bob);
        assertEq(streak.balanceOf(bob), 1);
    }

    function test_viewFunctions() public {
        vm.prank(alice);
        streak.claim();
        vm.prank(bob);
        streak.claim();
        assertEq(streak.getStreak(alice), 1);
        assertEq(streak.getStreak(carol), 0);
        (uint32 s, uint32 t, uint64 d, bool b) = streak.getStats(bob);
        assertEq(s, 1);
        assertEq(t, 1);
        assertEq(d, _day());
        assertTrue(b);
        (s, t, d, b) = streak.getStats(carol);
        assertEq(s, 0);
        assertEq(t, 0);
        assertEq(d, 0);
        assertFalse(b);
        assertEq(streak.totalClaimants(), 2);
        assertEq(streak.totalClaims(), 2);
        assertEq(streak.name(), "AgentStreak Badge");
        assertEq(streak.symbol(), "ASTREAK");
        assertTrue(streak.supportsInterface(0x80ac58cd));
    }

    function test_tokenURIContainsStreak() public {
        vm.prank(alice);
        streak.claim();
        vm.warp(vm.getBlockTimestamp() + 86400);
        vm.prank(alice);
        streak.claim();
        string memory uri = streak.tokenURI(uint160(alice));
        assertTrue(bytes(uri).length > 0);
        // JSON must contain the streak value 2.
        assertTrue(_contains(uri, '"value":2'));
        assertTrue(_contains(uri, "AgentStreak Badge"));
    }

    function test_tokenURIRevertsWithoutBadge() public {
        vm.expectRevert(AgentStreak.BadgeNotMinted.selector);
        streak.tokenURI(uint160(carol));
    }

    function test_getClaimantsPaging() public {
        vm.prank(alice);
        streak.claim();
        vm.prank(bob);
        streak.claim();
        address[] memory p0 = streak.getClaimants(0, 1);
        assertEq(p0.length, 1);
        assertEq(p0[0], alice);
        address[] memory p1 = streak.getClaimants(1, 10);
        assertEq(p1.length, 1);
        assertEq(p1[0], bob);
        address[] memory all = streak.getClaimants(0, 10);
        assertEq(all.length, 2);
        address[] memory empty = streak.getClaimants(5, 10);
        assertEq(empty.length, 0);
        address[] memory empty2 = streak.getClaimants(2, 10);
        assertEq(empty2.length, 0);
    }

    function test_claimGasAndDeployGas() public {
        uint256 g0 = gasleft();
        AgentStreak fresh = new AgentStreak();
        uint256 deployGas = g0 - gasleft();
        emit log_named_uint("deploy gas (new AgentStreak)", deployGas);

        agentId; // balances already etched at AGENT_ID_ADDR in setUp
        vm.prank(alice);
        uint256 g1 = gasleft();
        fresh.claim();
        uint256 firstClaimGas = g1 - gasleft();
        emit log_named_uint("first claim gas", firstClaimGas);

        vm.warp(vm.getBlockTimestamp() + 86400);
        vm.prank(alice);
        uint256 g2 = gasleft();
        fresh.claim();
        uint256 laterClaimGas = g2 - gasleft();
        emit log_named_uint("later claim gas", laterClaimGas);
    }

    // -- utils ---------------------------------------------------------------

    function _contains(string memory hay, string memory needle) internal pure returns (bool) {
        bytes memory h = bytes(hay);
        bytes memory n = bytes(needle);
        if (n.length > h.length) return false;
        for (uint256 i = 0; i <= h.length - n.length; i++) {
            bool found = true;
            for (uint256 j = 0; j < n.length; j++) {
                if (h[i + j] != n[j]) {
                    found = false;
                    break;
                }
            }
            if (found) return true;
        }
        return false;
    }
}
