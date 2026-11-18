// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/AgentStreak.sol";

/// @notice Deploy AgentStreak to BNB Smart Chain mainnet (chain 56).
///         Constructor takes NO arguments.
///         Usage (DO NOT run without Marcell's explicit go-ahead):
///           forge script script/AgentStreak.s.sol --rpc-url <BSC_RPC> --broadcast
contract DeployAgentStreak is Script {
    function run() external returns (AgentStreak) {
        vm.startBroadcast();
        AgentStreak streak = new AgentStreak();
        vm.stopBroadcast();
        return streak;
    }
}
