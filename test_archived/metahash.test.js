// truffle test 'test/metahash.test.js' --network test

const { BN, time, expectRevert } = require('@openzeppelin/test-helpers');
const { deployProxy, upgradeProxy } = require('@openzeppelin/truffle-upgrades');
const { assert } = require('chai');

const { dexInit,
  getLP,
  addLiquidity,
  removeLiquidity,
  buy,
  buyExactTokens,
  sell,
  transferToken,
  transferAVAX,
  userTokenBalance,
  userAVAXBalance,
  getAVAXForTokens, } = require('./dex.js')

const MINTER_ROLE = web3.utils.keccak256('MINTER_ROLE');
const fromExponential = require('from-exponential');
const ethers = require('ethers');
const moment = require('moment');

const MAX_UINT = '0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff';
const Metahash = artifacts.require("Metahash");
const NODERewardManagement = artifacts.require("NODERewardManagement");
const MetahashNFT = artifacts.require("MetahashNFT");
const IJoeRouter02 = artifacts.require("IJoeRouter02");
const  IWAVAX = artifacts.require("IWAVAX");

let instanceRewardManagement;
let instanceToken;
let router
let wavax
let factory
const ROUTER_ADDRESS = '0x60aE616a2155Ee3d9A68541Ba4544862310933d4'
let instanceNFT
let instanceRouter

const toWei = (value, unit = "ether") => {
  return web3.utils.toWei(value, unit);
};

const fromWei = (value, unit = "ether") => {
  return web3.utils.fromWei(value, unit);
};

contract('Metahash', ([owner, payee1, payee2,lock, circulating, tre, dist, dev, bob, doe]) => {


  before(async () => {
    console.log('Deploying NFT')
    instanceNFT = await deployProxy(MetahashNFT, [], {

      initializer: '__MetahashNFT_init',
    });

    console.log('Deploying Reward Management')
    instanceRewardManagement = await NODERewardManagement.new(toWei('50'),'25000', '86400', instanceNFT.address)
    console.log('Deploying Token')
    instanceToken = await Metahash.new([payee1, payee2],['50', '50'],[lock, circulating, tre, dist, dev],['340000000', '660000000', '0', '0', '0'], ROUTER_ADDRESS, {gas:17492052})

    await instanceToken.setNodeManagement(instanceRewardManagement.address)
    await instanceRewardManagement.setToken(instanceToken.address)
    await instanceNFT.grantRole(MINTER_ROLE, instanceRewardManagement.address)

    const dex = await dexInit();
    router = dex.router;
    factory = dex.factory;
    wavax = dex.wavax;


    await instanceToken.approve(router.address, toWei("100000000000"), { from: circulating });
    console.log('Adding Liquidity')
    const timestamp = (await time.latest()) + 10000;
    await router.addLiquidityAVAX(
      instanceToken.address,
      toWei("660000000"),
      0,
      0,
      circulating,
      timestamp,
      {
        from: circulating,
        value: toWei("1"),
      }
    );
    console.log('Liquidity added')
  })

  it('should open trading and buy token', async () => {
    await instanceToken.openTrading()
    await buy(router, wavax, instanceToken.address, 0.0001, bob, "bob");
    await buy(router, wavax, instanceToken.address, 0.0001, doe, "doe");
  });

  it('should create nodes', async () => {
    await instanceToken.approve(instanceToken.address, toWei('1000'), { from: bob });
    await instanceToken.createNodeWithTokens('bobNode', toWei('1000'), { from:bob})
    assert.equal(await instanceNFT.balanceOf(bob), '1')
    assert.equal(await instanceNFT.ownerOf(1), bob)
    await instanceToken.approve(instanceToken.address, toWei('1000'), { from: doe });
    await instanceToken.createNodeWithTokens('doeNode', toWei('1000'), { from:doe})
    assert.equal(await instanceNFT.balanceOf(doe), '1')
    assert.equal(await instanceNFT.ownerOf(2), doe)

    assert.equal(fromWei(await instanceNFT.hashRate(1)), '1000')
    assert.equal(fromWei(await instanceNFT.hashRate(2)), '1000')
    await time.increase(86400)
  })
})
