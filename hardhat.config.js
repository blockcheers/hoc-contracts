require('@nomiclabs/hardhat-waffle');
require('@nomiclabs/hardhat-etherscan');

require('dotenv').config();
const { POLYGON_KEY, MNEMONIC } = process.env;
task('accounts', 'Prints the list of accounts', async () => {
  const accounts = await ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

module.exports = {
  defaultNetwork: 'rinkeby',
  networks: {
    hardhat: {},
    polygonTestnet: {
      url: 'https://rpc-mumbai.maticvigil.com',
      accounts: [MNEMONIC],
    },
    polygonMainnet: {
      url: 'https://polygon-rpc.com',
      accounts: [MNEMONIC],
    },

    bnbTestnet: {
      url: 'https://data-seed-prebsc-1-s1.binance.org:8545',
      accounts: [MNEMONIC],
    },
    bnbMainnet: {
      url: 'https://bsc-dataseed.binance.org',
      accounts: [MNEMONIC],
    },
  },
  solidity: {
    version: '0.8.12',
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  paths: {
    artifacts: './artifacts',
    sources: './contracts',
    cache: './cache',
    tests: './test',
  },
  etherscan: {
    apiKey: {
      polygonMumbai: POLYGON_KEY,
    },
  },
};
