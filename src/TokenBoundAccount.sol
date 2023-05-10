// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@thirdweb-dev/contracts/smart-wallet/non-upgradeable/Account.sol";
import "@thirdweb-dev/contracts/eip/interface/IERC721.sol";

contract TokenBoundAccount is Account {
    uint256 chainId;
    address tokenContract;
    uint256 tokenId;

    constructor(
        IEntryPoint _entrypoint,
        address _factory
    ) Account(_entrypoint, _factory) {
        _disableInitializers();
    }

    function isValidSigner(
        address _signer
    ) public view override returns (bool) {
        return (isOwner(_signer) || hasRole(SIGNER_ROLE, _signer));
    }

    function isOwner(address _signer) public view returns (bool) {
        if (chainId != block.chainid) {
            revert("Invalid chainId");
        }
        return _signer == IERC721(tokenContract).ownerOf(tokenId);
    }

    function initialize(
        address _admin,
        bytes calldata _data
    ) public override initializer {
        (chainId, tokenContract, tokenId) = abi.decode(
            _data,
            (uint256, address, uint256)
        );
    }
}
