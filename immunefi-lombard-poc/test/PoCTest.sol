// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.24;

import {IERC20, PoC} from "@immunefi/PoC.sol";
import {AttackContract} from "../src/AttackContract.sol";

contract PoCTest is PoC {
    string internal constant MAINNET_ARCHIVE_RPC_URL =
        "https://ethereum.blockpi.network/v1/rpc/bfc71cc49cfe003fd425b1936e806be02ef787bd";
    uint256 internal constant FORK_BLOCK = 23842682;

    address internal constant STAKED_LBTC =
        0x8236a87084f8B84306f72007F36F2618A5634494;
    address internal constant HISTORICAL_RECIPIENT =
        0x555fcE4A88f9261B449A8078400e022c3a4fB706;

    AttackContract public attackContract;
    IERC20[] internal tokens;

    function setUp() public {
        vm.createSelectFork(MAINNET_ARCHIVE_RPC_URL, FORK_BLOCK);

        attackContract = new AttackContract();
        tokens.push(IERC20(STAKED_LBTC));

        setAlias(address(attackContract), "Attacker");
        setAlias(HISTORICAL_RECIPIENT, "Historical recipient");

        emit log_string(">>> Initial conditions");
    }

    function testAttack() public snapshot(HISTORICAL_RECIPIENT, tokens) {
        attackContract.initializeAttack();
    }
}
