## Custom Smart Accounts

Use the [Solidity SDK](https://portal.thirdweb.com/solidity) to create custom ERC-4337 [Smart Wallets](https://portal.thirdweb.com/wallet/smart-wallet) in which the owner of the wallet is tied to the ownership of a specified erc-721 token.

## Getting Started

To create a custom smart wallet, clone this repo using the [thirdweb CLI](https://portal.thirdweb.com/cli):

```bash
npx thirdweb create --contract --template erc-6551
```

## Building the project & running tests

_Note: This repository is a [Foundry](https://book.getfoundry.sh/) project, so make sure that [Foundry is installed](https://book.getfoundry.sh/getting-started/installation) locally._

To make sure that Foundry is up to date and install dependencies, run the following command:

```bash
foundryup && forge install
```

Once the dependencies are installed, tests can be run:

```bash
forge test
```

## Deploying Contracts

To deploy *ANY* contract, with no requirements, use thirdweb Deploy:

```bash
npx thirdweb deploy
```

1. Deploy the implementation contract, `TokenBoundAccount` as this will be needed as a constructor parameter for the factory.
2. Deploy the factory contract `TokenBoundAccountFactory`

In both cases, set the `EntryPoint` contract address as `0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789`.
This address is the same on all chains it is deployed to.

## Join our Discord!

For any questions or suggestions, join our discord at [https://discord.gg/thirdweb](https://discord.gg/thirdweb).
