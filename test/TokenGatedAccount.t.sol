// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

// Test utils
import "@std/Test.sol";
import "@thirdweb-dev/src/test/mocks/MockERC721.sol";
import "@thirdweb-dev/src/test/mocks/MockERC1155.sol";
import "@thirdweb-dev/contracts/openzeppelin-presets/utils/cryptography/ECDSA.sol";

// Account Abstraction setup for smart wallets.
import {EntryPoint, IEntryPoint} from "@thirdweb-dev/contracts/smart-wallet/utils/Entrypoint.sol";
import {UserOperation} from "@thirdweb-dev/contracts/smart-wallet/utils/UserOperation.sol";

// Target
import {TokenGatedAccountFactory, TokenGatedAccount} from "../src/TokenGatedAccountFactory.sol";

/// @dev This is a dummy contract to test contract interactions with Account.
contract Number {
    uint256 public num;

    function setNum(uint256 _num) public {
        num = _num;
    }

    function doubleNum() public {
        num *= 2;
    }

    function incrementNum() public {
        num += 1;
    }
}

contract TokenGatedAccountTest is Test {
    using ECDSA for bytes32;

    // Target contracts
    EntryPoint private entrypoint;
    TokenGatedAccountFactory private tokenGatedAccountFactory;

    // Mocks
    Number internal numberContract;

    // Test params
    uint256 private accountAdminPKey = 100;
    address private accountAdmin;

    uint256 private accountSignerPKey = 200;
    address private accountSigner;

    uint256 private nonSignerPKey = 300;
    address private nonSigner;

    // UserOp terminology: `sender` is the smart wallet.
    address private sender = 0x44ABAc7E845100201E9c661c4ED5b30A28a20eb2;
    address payable private beneficiary = payable(address(0x45654));

    MockERC721 private mockERC721;
    MockERC1155 private mockERC1155;
    bytes data;

    event AccountCreated(address indexed account, address indexed accountAdmin);

    function _setupUserOp(
        uint256 _signerPKey,
        bytes memory _initCode,
        bytes memory _callDataForEntrypoint
    ) internal returns (UserOperation[] memory ops) {
        uint256 nonce = entrypoint.getNonce(sender, 0);

        // Get user op fields
        UserOperation memory op = UserOperation({
            sender: sender,
            nonce: nonce,
            initCode: _initCode,
            callData: _callDataForEntrypoint,
            callGasLimit: 500_000,
            verificationGasLimit: 500_000,
            preVerificationGas: 500_000,
            maxFeePerGas: 0,
            maxPriorityFeePerGas: 0,
            paymasterAndData: bytes(""),
            signature: bytes("")
        });

        // Sign UserOp
        bytes32 opHash = EntryPoint(entrypoint).getUserOpHash(op);
        bytes32 msgHash = ECDSA.toEthSignedMessageHash(opHash);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(_signerPKey, msgHash);
        bytes memory userOpSignature = abi.encodePacked(r, s, v);

        address recoveredSigner = ECDSA.recover(msgHash, v, r, s);
        address expectedSigner = vm.addr(_signerPKey);
        assertEq(recoveredSigner, expectedSigner);

        op.signature = userOpSignature;

        // Store UserOp
        ops = new UserOperation[](1);
        ops[0] = op;
    }

    function _setupUserOpExecute(
        uint256 _signerPKey,
        bytes memory _initCode,
        address _target,
        uint256 _value,
        bytes memory _callData
    ) internal returns (UserOperation[] memory) {
        bytes memory callDataForEntrypoint = abi.encodeWithSignature(
            "execute(address,uint256,bytes)",
            _target,
            _value,
            _callData
        );

        return _setupUserOp(_signerPKey, _initCode, callDataForEntrypoint);
    }

    function _setupUserOpExecuteBatch(
        uint256 _signerPKey,
        bytes memory _initCode,
        address[] memory _target,
        uint256[] memory _value,
        bytes[] memory _callData
    ) internal returns (UserOperation[] memory) {
        bytes memory callDataForEntrypoint = abi.encodeWithSignature(
            "executeBatch(address[],uint256[],bytes[])",
            _target,
            _value,
            _callData
        );

        return _setupUserOp(_signerPKey, _initCode, callDataForEntrypoint);
    }

    function setUp() public {
        mockERC721 = new MockERC721();
        mockERC1155 = new MockERC1155();

        // Setup signers.
        accountAdmin = vm.addr(accountAdminPKey);
        mockERC721.mint(accountAdmin, 1);
        vm.deal(accountAdmin, 100 ether);

        accountSigner = vm.addr(accountSignerPKey);
        nonSigner = vm.addr(nonSignerPKey);

        // Setup contracts
        entrypoint = new EntryPoint();
        // deploy account factory
        tokenGatedAccountFactory = new TokenGatedAccountFactory(
            IEntryPoint(payable(address(entrypoint)))
        );
        // deploy dummy contract
        numberContract = new Number();

        data = abi.encode(block.chainid, address(mockERC721), 0);
    }

    /*///////////////////////////////////////////////////////////////
                        Test: creating an account
    //////////////////////////////////////////////////////////////*/

    /// @dev Create an account by directly calling the factory.
    function test_state_createAccount_viaFactory() public {
        vm.expectEmit(true, true, false, true);
        emit AccountCreated(sender, accountAdmin);
        tokenGatedAccountFactory.createAccount(accountAdmin, data);
    }

    /// @dev Create an account via Entrypoint.
    function test_state_createAccount_viaEntrypoint() public {
        bytes memory initCallData = abi.encodeWithSignature(
            "createAccount(address,bytes)",
            accountAdmin,
            data
        );
        bytes memory initCode = abi.encodePacked(
            abi.encodePacked(address(tokenGatedAccountFactory)),
            initCallData
        );

        UserOperation[] memory userOpCreateAccount = _setupUserOpExecute(
            accountAdminPKey,
            initCode,
            address(0),
            0,
            bytes("")
        );

        vm.expectEmit(true, true, false, true);
        emit AccountCreated(sender, accountAdmin);
        EntryPoint(entrypoint).handleOps(userOpCreateAccount, beneficiary);
    }

    /*///////////////////////////////////////////////////////////////
                    Test: performing a contract call
    //////////////////////////////////////////////////////////////*/

    function _setup_executeTransaction() internal {
        bytes memory initCallData = abi.encodeWithSignature(
            "createAccount(address,bytes)",
            accountAdmin,
            data
        );
        bytes memory initCode = abi.encodePacked(
            abi.encodePacked(address(tokenGatedAccountFactory)),
            initCallData
        );

        UserOperation[] memory userOpCreateAccount = _setupUserOpExecute(
            accountAdminPKey,
            initCode,
            address(0),
            0,
            bytes("")
        );

        EntryPoint(entrypoint).handleOps(userOpCreateAccount, beneficiary);
    }

    /// @dev Perform a state changing transaction directly via account.
    function test_state_executeTransaction() public {
        _setup_executeTransaction();

        address account = tokenGatedAccountFactory.getAddress(
            accountAdmin,
            data
        );

        assertEq(numberContract.num(), 0);

        vm.prank(accountAdmin);
        TokenGatedAccount(payable(account)).execute(
            address(numberContract),
            0,
            abi.encodeWithSignature("setNum(uint256)", 42)
        );

        assertEq(numberContract.num(), 42);
    }

    /// @dev Perform many state changing transactions in a batch directly via account.
    function test_state_executeBatchTransaction() public {
        _setup_executeTransaction();

        address account = tokenGatedAccountFactory.getAddress(
            accountAdmin,
            data
        );

        assertEq(numberContract.num(), 0);

        uint256 count = 3;
        address[] memory targets = new address[](count);
        uint256[] memory values = new uint256[](count);
        bytes[] memory callData = new bytes[](count);

        for (uint256 i = 0; i < count; i += 1) {
            targets[i] = address(numberContract);
            values[i] = 0;
            callData[i] = abi.encodeWithSignature("incrementNum()", i);
        }

        vm.prank(accountAdmin);
        TokenGatedAccount(payable(account)).executeBatch(
            targets,
            values,
            callData
        );

        assertEq(numberContract.num(), count);
    }

    /// @dev Perform a state changing transaction via Entrypoint.
    function test_state_executeTransaction_viaEntrypoint() public {
        _setup_executeTransaction();

        assertEq(numberContract.num(), 0);

        UserOperation[] memory userOp = _setupUserOpExecute(
            accountAdminPKey,
            bytes(""),
            address(numberContract),
            0,
            abi.encodeWithSignature("setNum(uint256)", 42)
        );

        EntryPoint(entrypoint).handleOps(userOp, beneficiary);

        assertEq(numberContract.num(), 42);
    }

    /// @dev Perform many state changing transactions in a batch via Entrypoint.
    function test_state_executeBatchTransaction_viaEntrypoint() public {
        _setup_executeTransaction();

        assertEq(numberContract.num(), 0);

        uint256 count = 3;
        address[] memory targets = new address[](count);
        uint256[] memory values = new uint256[](count);
        bytes[] memory callData = new bytes[](count);

        for (uint256 i = 0; i < count; i += 1) {
            targets[i] = address(numberContract);
            values[i] = 0;
            callData[i] = abi.encodeWithSignature("incrementNum()", i);
        }

        UserOperation[] memory userOp = _setupUserOpExecuteBatch(
            accountAdminPKey,
            bytes(""),
            targets,
            values,
            callData
        );

        EntryPoint(entrypoint).handleOps(userOp, beneficiary);

        assertEq(numberContract.num(), count);
    }

    /// @dev Revert: perform a state changing transaction via Entrypoint without appropriate permissions.
    function test_revert_executeTransaction_nonSigner_viaEntrypoint() public {
        _setup_executeTransaction();

        assertEq(numberContract.num(), 0);

        UserOperation[] memory userOp = _setupUserOpExecute(
            accountSignerPKey,
            bytes(""),
            address(numberContract),
            0,
            abi.encodeWithSignature("setNum(uint256)", 42)
        );

        vm.expectRevert();
        EntryPoint(entrypoint).handleOps(userOp, beneficiary);
    }

    /*///////////////////////////////////////////////////////////////
                Test: receiving and sending native tokens
    //////////////////////////////////////////////////////////////*/

    /// @dev Send native tokens to an account.
    function test_state_accountReceivesNativeTokens() public {
        _setup_executeTransaction();

        address account = tokenGatedAccountFactory.getAddress(
            accountAdmin,
            data
        );

        assertEq(address(account).balance, 0);

        vm.prank(accountAdmin);
        payable(account).call{value: 1000}("");

        assertEq(address(account).balance, 1000);
    }

    /// @dev Transfer native tokens out of an account.
    function test_state_transferOutsNativeTokens() public {
        _setup_executeTransaction();

        uint256 value = 1000;

        address account = tokenGatedAccountFactory.getAddress(
            accountAdmin,
            data
        );
        vm.prank(accountAdmin);
        payable(account).call{value: value}("");
        assertEq(address(account).balance, value);

        address recipient = address(0x3456);

        UserOperation[] memory userOp = _setupUserOpExecute(
            accountAdminPKey,
            bytes(""),
            recipient,
            value,
            bytes("")
        );

        EntryPoint(entrypoint).handleOps(userOp, beneficiary);
        assertEq(address(account).balance, 0);
        assertEq(recipient.balance, value);
    }

    /// @dev Add and remove a deposit for the account from the Entrypoint.

    function test_state_addAndWithdrawDeposit() public {
        _setup_executeTransaction();

        address account = tokenGatedAccountFactory.createAccount(
            accountAdmin,
            data
        );

        assertEq(TokenGatedAccount(payable(account)).getDeposit(), 0);

        vm.prank(accountAdmin);
        TokenGatedAccount(payable(account)).addDeposit{value: 1000}();
        assertEq(TokenGatedAccount(payable(account)).getDeposit(), 1000);

        vm.prank(accountAdmin);
        TokenGatedAccount(payable(account)).withdrawDepositTo(
            payable(accountSigner),
            500
        );
        assertEq(TokenGatedAccount(payable(account)).getDeposit(), 500);
    }

    /*///////////////////////////////////////////////////////////////
                Test: receiving ERC-721 and ERC-1155 NFTs
    //////////////////////////////////////////////////////////////*/

    /// @dev Send an ERC-721 NFT to an account.
    function test_state_receiveERC721NFT() public {
        _setup_executeTransaction();
        address account = tokenGatedAccountFactory.getAddress(
            accountAdmin,
            data
        );

        assertEq(mockERC721.balanceOf(account), 0);

        mockERC721.mint(account, 1);

        assertEq(mockERC721.balanceOf(account), 1);
    }

    /// @dev Send an ERC-1155 NFT to an account.
    function test_state_receiveERC1155NFT() public {
        _setup_executeTransaction();
        address account = tokenGatedAccountFactory.getAddress(
            accountAdmin,
            data
        );

        assertEq(mockERC1155.balanceOf(account, 0), 0);

        mockERC1155.mint(account, 0, 1);

        assertEq(mockERC1155.balanceOf(account, 0), 1);
    }
}
