// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.24;

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
}

interface Vm {
    function createSelectFork(
        string calldata urlOrAlias,
        uint256 blockNumber
    ) external returns (uint256);
    function prank(address msgSender) external;
}

contract PoC {
    Vm internal constant vm =
        Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    event log_named_address(string key, address val);
    event log_named_uint(string key, uint256 val);
    event log_string(string val);

    mapping(address account => string aliasName) internal aliases;

    function setAlias(address account, string memory aliasName) public {
        aliases[account] = aliasName;
    }

    modifier snapshot(address account, IERC20[] memory tokens) {
        emit log_string(">>> Pre-attack balances");
        _printBalances(account, tokens);
        _;
        emit log_string(">>> Post-attack balances");
        _printBalances(account, tokens);
    }

    function _printBalances(address account, IERC20[] memory tokens) internal {
        emit log_named_address("account", account);
        for (uint256 i; i < tokens.length; ++i) {
            emit log_named_address("token", address(tokens[i]));
            emit log_named_uint("balance", tokens[i].balanceOf(account));
        }
    }
}

