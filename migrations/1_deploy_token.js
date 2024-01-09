const { deployProxy, upgradeProxy } = require('@openzeppelin/truffle-upgrades');
const fromExponential = require('from-exponential');
const ethers = require('ethers');
const moment = require('moment');
const BN = web3.utils.BN;
const MAX_UINT = '0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff';
// const Hash2O = artifacts.require("Hash2O");
const LandDeveloperSale = artifacts.require('LandDeveloperSale');
// const MockERC20 = artifacts.require("MockERC20");

// const Hash2ONFT = artifacts.require("Hash2ONFT");
// const MINTER_ROLE = web3.utils.keccak256('MINTER_ROLE');
// const LandFactory = artifacts.require('LandFactory');

const toWei = (value, unit = 'ether') => {
  return web3.utils.toWei(value, unit);
};

const fromWei = (value, unit = 'ether') => {
  return web3.utils.fromWei(value, unit);
};

module.exports = async function (deployer, network) {
  await deployer.deploy(
    LandDeveloperSale,
    '0x0f893308b20ECAB653Ae520c43C025a65965E621',
    25587488,
    '0x271313aAbF4cCc26c4819D5E4a70de97981484D5',
    2,
    false,
    '0x0000000000000000000000000000000000000000'
  );

  if (network === 'test') return;
  // await newDeploy(deployer, network, accounts)
  // await upgradeNFT(deployer, network, accounts)
  // await upgradeEngine(deployer, network, accounts)
};

// https://testnet.bscscan.com/address/0x00D45aaFa673dc64a0518E8FC14B556B55AB2bA4#code

// truffle migrate --network polygonTestnet
// truffle run verify LandFactory --network polygonTestnet

// truffle run verify LandDeveloperSale@0xFa1De66A6E8Ed8789CD3da946dDBfFFAAfcD5A61 --forceConstructorArgs string:00000000000000000000000040176090ef37db2a758de2af9608617295a8a75d0000000000000000000000000000000000000000000000000000000000014a78000000000000000000000000710e11f08f5874cb1d557883b2d6f5a45d9495460000000000000000000000000000000000000000000000000000000000000000 --network bscTestnet
