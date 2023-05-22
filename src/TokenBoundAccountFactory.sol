// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.12;

// Utils
import "@thirdweb-dev/contracts/smart-wallet/utils/BaseAccountFactory.sol";

// Smart wallet implementation
import {TokenBoundAccount} from "./TokenBoundAccount.sol";

contract TokenBoundAccountFactory is BaseAccountFactory {
    /// @notice Emitted when a new Token Bound Account is created.
    event TokenBoundAccountCreated(address indexed account, bytes indexed data);

    /*///////////////////////////////////////////////////////////////
                            Constructor
    //////////////////////////////////////////////////////////////*/

    constructor(
        IEntryPoint _entrypoint
    )
        BaseAccountFactory(
            address(new TokenBoundAccount(_entrypoint, address(this)))
        )
    {}

    /*///////////////////////////////////////////////////////////////
                            Internal functions
    //////////////////////////////////////////////////////////////*/

    /// @notice
    function _generateSalt(
        address,
        bytes calldata _data
    ) internal view virtual override returns (bytes32) {
        return keccak256(abi.encode(_data));
    }

    /// @notice Deploys a new Account for admin.
    function _initializeAccount(
        address _account,
        address _admin,
        bytes calldata _data
    ) internal override {
        TokenBoundAccount(payable(_account)).initialize(_admin, _data);
        emit TokenBoundAccountCreated(_account, _data);
    }

    /// @notice Returns the address of an Account that would be deployed with the given admin signer.
    function getAccountAddress(
        bytes calldata _data
    ) public view returns (address) {
        bytes32 salt = keccak256(abi.encode(_data));
        return Clones.predictDeterministicAddress(accountImplementation, salt);
    }
}
