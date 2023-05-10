// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.12;

// Utils
import "@thirdweb-dev/contracts/smart-wallet/utils/BaseAccountFactory.sol";

// Smart wallet implementation
import {TokenBoundAccount} from "./TokenBoundAccount.sol";

contract TokenBoundAccountFactory is BaseAccountFactory {
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

    /// @notice Deploys a new Account for admin.
    function _initializeAccount(
        address _account,
        address _admin,
        bytes calldata _data
    ) internal override {
        TokenBoundAccount(payable(_account)).initialize(_admin, _data);
    }
}
