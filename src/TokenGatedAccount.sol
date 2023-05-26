// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@thirdweb-dev/contracts/smart-wallet/non-upgradeable/Account.sol";
import "@thirdweb-dev/contracts/eip/interface/IERC721.sol";

contract TokenGatedAccount is Account {
    uint256 public chainId;
    address public tokenContract;
    uint256 public tokenId;

    event TokenGatedAccountCreated(address indexed account, bytes indexed data);

    /**
     * @notice Executes once when a contract is created to initialize state variables
     *
     * @param _entrypoint - 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789
     * @param _factory - The factory contract address to issue token Gated accounts
     *
     */
    constructor(
        IEntryPoint _entrypoint,
        address _factory
    ) Account(_entrypoint, _factory) {
        _disableInitializers();
    }

    function isValidSigner(
        address _signer
    ) public view override returns (bool) {
        return (owner() == _signer);
    }

    function owner() public view returns (address) {
        if (chainId != block.chainid) {
            revert("Invalid chainId");
        }
        return IERC721(tokenContract).ownerOf(tokenId);
    }

    function initialize(
        address _admin,
        bytes calldata _data
    ) public override initializer {
        (chainId, tokenContract, tokenId) = abi.decode(
            _data,
            (uint256, address, uint256)
        );
        require(owner() == _admin, "Account: not token owner.");
        emit TokenGatedAccountCreated(_admin, _data);
    }

    /// @notice Executes a transaction (called directly from the token owner, or by entryPoint)
    function execute(
        address _target,
        uint256 _value,
        bytes calldata _calldata
    ) external virtual override onlyOwnerOrEntrypoint {
        _call(_target, _value, _calldata);
    }

    /// @notice Executes a sequence transaction (called directly from the token owner, or by entryPoint)
    function executeBatch(
        address[] calldata _target,
        uint256[] calldata _value,
        bytes[] calldata _calldata
    ) external virtual override onlyOwnerOrEntrypoint {
        require(
            _target.length == _calldata.length &&
                _target.length == _value.length,
            "Account: wrong array lengths."
        );
        for (uint256 i = 0; i < _target.length; i++) {
            _call(_target[i], _value[i], _calldata[i]);
        }
    }

    /// @notice Withdraw funds for this account from Entrypoint.
    function withdrawDepositTo(
        address payable withdrawAddress,
        uint256 amount
    ) public virtual override {
        require(owner() == msg.sender, "Account: not NFT owner");
        entryPoint().withdrawTo(withdrawAddress, amount);
    }

    function token()
        external
        view
        returns (uint256 chainId, address tokenContract, uint256 tokenId)
    {}

    /// @notice Checks whether the caller is the EntryPoint contract or the token owner.
    modifier onlyOwnerOrEntrypoint() {
        require(
            msg.sender == address(entryPoint()) || owner() == msg.sender,
            "Account: not admin or EntryPoint."
        );
        _;
    }
}
