const { time } = require('@openzeppelin/test-helpers');
const BigNumber = require('bignumber.js');
// const { toWei, fromWei } = require('./utils');

const IJoeRouter02 = artifacts.require('IJoeRouter02.sol');
const IJoeFactory = artifacts.require('IJoeFactory.sol');
const IUniswapV2Pair = artifacts.require('IUniswapV2Pair.sol');

const  IWAVAX = artifacts.require("IWAVAX");

const ROUTER_ADDRESS = '0x60aE616a2155Ee3d9A68541Ba4544862310933d4';

let factory_address = '';
let wavax = '';

const toWei = (value, unit = "ether") => {
  return web3.utils.toWei(value, unit);
};

const fromWei = (value, unit = "ether") => {
  return web3.utils.fromWei(value, unit);
};

const dexInit = async () => {
  const router = await IJoeRouter02.at(ROUTER_ADDRESS);
  factory_address = await router.factory()
  wavax = await router.WAVAX()
  const factory = await IJoeFactory.at(factory_address);
  return { router, factory, wavax };
};

const getLP = async (factoryInstance, tokenAddress) => {
  const pairAddress = await factoryInstance.getPair(wavax, tokenAddress);
  const pair = await IUniswapV2Pair.at(pairAddress);
  return { pairAddress, pair };
};

const addLiquidity = async (routerInstance, tokenInstance, tokenName, tokenAmount, AVAXAmount, user, userName) => {
  console.log(`[ADD_LP] ${userName} is adding liquidity of ${tokenAmount} ${tokenName} and ${AVAXAmount} AVAX`);

  const tokenAmountInWei = toWei(tokenAmount.toString());
  const AVAXAmountInWei = toWei(AVAXAmount.toString());
  const timestamp = (await time.latest()) + 10000;
  await tokenInstance.approve(routerInstance.address.toString(), tokenAmountInWei, { from: user });
  return await routerInstance.addLiquidityAVAX(tokenInstance.address, tokenAmountInWei, 0, 0, user, timestamp, {
    from: user,
    value: AVAXAmountInWei,
  });
};

const removeLiquidity = async (routerInstance, lpInstance, tokenAddress, user, userName) => {
  console.log('=== Remove Liquidity ===');

  const lpBalanceInWei = await lpInstance.balanceOf(user);
  if (Number(fromWei(lpBalanceInWei)) === 0) {
    console.log(`${userName} empty LP`);
    return undefined;
  } else {
    console.log(`[RM_LP] ${userName} is removing liquidity of ${lpBalanceInWei} LP`);
    const timestamp = (await time.latest()) + 10000;
    await lpInstance.approve(routerInstance.address, lpBalanceInWei, { from: user });
    return await routerInstance.removeLiquidityAVAX(tokenAddress, lpBalanceInWei, 0, 0, user, timestamp, {
      from: user,
    });
  }
};

const buy = async (routerInstance, wavaxAddress, tokenAddress, AVAXAmount, user, userName) => {
  console.log(`[BUY] ${userName} is buying worth of ${AVAXAmount} AVAX`);

  const AVAXAmountInWei = toWei(AVAXAmount.toString());
  const path = [wavaxAddress, tokenAddress];

  console.log('Estimated output:', fromWei((await routerInstance.getAmountsOut(AVAXAmountInWei, path))[1].toString()));

  const timestamp = (await time.latest()) + 10000;
  return await routerInstance.swapExactAVAXForTokensSupportingFeeOnTransferTokens('0', path, user, timestamp, {
    from: user,
    value: AVAXAmountInWei,
  });
};

const buyExactTokens = async (routerInstance, wavaxAddress, tokenAddress, tokenAmount, user, userName) => {
  console.log(`[BUY_EXACT_TOKENS] ${userName} is buying worth of ${tokenAmount} Tokens`);

  const tokenAmountInWei = toWei(tokenAmount.toString());
  const path = [wavaxAddress, tokenAddress];

  const AVAXBalance = await userAVAXBalance(user);
  let AVAXInputEstimated = -1;
  try {
    AVAXInputEstimated = (await routerInstance.getAmountsIn(tokenAmountInWei, path))[0].toString();
    console.log('Estimated input:', fromWei(AVAXInputEstimated));
  } catch (e) {
    console.log('Not enough LP');
  }
  if (AVAXInputEstimated !== -1 && new BigNumber(AVAXBalance).gte(AVAXInputEstimated)) {
    const timestamp = (await time.latest()) + 10000;
    return await routerInstance.swapAVAXForExactTokens(tokenAmountInWei, path, user, timestamp, {
      from: user,
      value: AVAXInputEstimated,
    });
  }
  return undefined;
};

const sell = async (routerInstance, tokenInstance, wavaxAddress, tokenAmount, user, userName) => {
  console.log(`[SELL] ${userName} is selling ${tokenAmount} tokens`);

  const tokenAmountInWei = toWei(tokenAmount.toString());
  const path = [tokenInstance.address, wavaxAddress];

  console.log('AVAX snapshot:', web3.utils.fromWei(await web3.eth.getBalance(user)));
  let AVAXOutEstimated = -1;
  try {
    AVAXOutEstimated = (await routerInstance.getAmountsOut(tokenAmountInWei, path))[1].toString();
    console.log('Estimated output:', fromWei(AVAXOutEstimated));
  } catch (e) {
    console.log('Not enough LP');
  }
  if (AVAXOutEstimated !== -1) {
    const timestamp = (await time.latest()) + 10000;
    await tokenInstance.approve(routerInstance.address, tokenAmountInWei, { from: user });
    return await routerInstance.swapExactTokensForAVAXSupportingFeeOnTransferTokens(
      tokenAmountInWei,
      0,
      path,
      user,
      timestamp,
      { from: user }
    );
  }
  return undefined;
};

const transferToken = async (tokenInstance, from, to, tokens, fromName, toName) => {
  console.log(`[TRANSFER_TOKEN] From ${fromName} to ${toName} for ${tokens} tokens`);
  return await tokenInstance.transfer(to, toWei(tokens), { from: from });
};

const transferAVAX = async (tokenInstance, from, to, AVAXAmount, fromName, toName) => {
  console.log(`[TRANSFER_AVAX] From ${fromName} to ${toName} for ${AVAX} AVAX `);
  return await web3.eth.sendTransaction({ to: from, from: to, value: toWei(AVAXAmount) });
};

const userTokenBalance = async (tokenInstance, user) => {
  return await tokenInstance.balanceOf(user);
};

const userAVAXBalance = async (user) => {
  return await web3.eth.getBalance(user);
};

const getAVAXForTokens = async (routerInstance, tokenInstance, wavaxAddress, tokenAmount) => {
  try {
    const tokenAmountInWei = toWei(tokenAmount.toString());
    const path = [tokenInstance.address, wavaxAddress];
    return fromWei((await routerInstance.getAmountsOut(tokenAmountInWei, path))[1].toString());
  } catch (e) {
    return -1;
  }
};

module.exports = {
  dexInit,
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
  getAVAXForTokens,
};
