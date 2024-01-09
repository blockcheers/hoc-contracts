# HOC

## Overview

The HOC project is the decentralzied real estate project.

## Installation

To get started with the HOC project, follow these installation steps:

1. Clone the repository:

    ```bash
    git clone https://github.com/blockcheers/hoc-contracts.git
    cd hoc-contracts
    ```

2. Install dependencies using either Yarn or npm:

    ```bash
    # Using Yarn
    yarn

    # Using npm
    npm install
    ```

3. Install Truffle globally (if not already installed) using npm:

    ```bash
    npm install -g truffle
    ```

    Alternatively, you can use Hardhat as the development environment:

    ```bash
    npm install hardhat
    ```

## Usage

### Truffle Commands

#### Migrate Contracts

Use Truffle to migrate contracts to a specific network:

```bash
truffle migrate --network <network name>
```

#### Verify Contracts

Verify contracts on the blockchain using Truffle:

```bash
truffle run verify <contract name> --network <network name>
```

### Hardhat Commands

#### Deploy Contracts

Deploy contracts using Hardhat:

```bash
npx hardhat run scripts/deploy.js --network <network name>
```

#### Verify Contracts

Verify deployed contracts on the blockchain with Hardhat:

```bash
npx hardhat verify --network <chain name> <contract address> <param 1> <param 2>
```


## License

This project is licensed under the [MIT License](LICENSE).