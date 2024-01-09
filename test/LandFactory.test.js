const { expect } = require('chai');
const { BN, ether, expectEvent, expectRevert, time } = require('@openzeppelin/test-helpers');
const LandDeveloperSale = artifacts.require('LandDeveloperSale');
const LandNFT = artifacts.require('LandNFT');
const LandNFTFactory = artifacts.require('LandNFTFactory');
const LandDeveloperSaleFactory = artifacts.require('LandDeveloperSaleFactory');

const { sign } = require('../scripts/eip712_land');
// const { web3 } = require('@openzeppelin/test-helpers/src/setup');


// truffle test 'test/LandFactory.test.js' --network test
const DEVELOPER_ROLE = web3.utils.keccak256('DEVELOPER_ROLE');
const MINTER_ROLE = web3.utils.keccak256('MINTER_ROLE');
const VALIDATOR_ROLE = web3.utils.keccak256('VALIDATOR_ROLE');


contract('LandDeveloperSale', function (accounts) {
  const [owner, developer, agent, bob] = accounts;

  const price = ether('0.5');

  const tokenId = 1;
    const metadataId = 1;
    const landType = 0;
    // const price = ether('1');
    const limit = 100;

  beforeEach(async function () {
    this.landFactory = await LandNFTFactory.new({ from: owner });
    await this.landFactory.grantRole(DEVELOPER_ROLE, developer, { from: owner });
    await this.landFactory.updatePrice(price)

    this.saleFactory = await LandDeveloperSaleFactory.new({ from: owner });
    await this.saleFactory.grantRole(DEVELOPER_ROLE, developer, { from: owner });
    await this.saleFactory.updatePrice(price)

    this.signatureTime = (await web3.eth.getBlock('latest')).timestamp;

  });

  it('should allow the owner to add land metadata', async function () {

    const tx = await this.landFactory.createLandNFT('oo','oo', 'uri', 0, {from:developer, value:price})
    const landNFT = await LandNFT.at(tx.logs[3].args[0])
    await landNFT.grantRole(DEVELOPER_ROLE, developer, { from: developer });

    const tx1 = await this.saleFactory.createDeveloperSale(10, 86400, landNFT.address, {from:developer, value:price})

    const sale = await LandDeveloperSale.at(tx1.logs[0].address)
    await sale.addLandMetadata(price, metadataId, limit, { from: developer });

    // console.log(tx1.logs[0].address)
    await landNFT.grantRole(MINTER_ROLE, sale.address, {from:developer})
    // await sale.grantRole(VALIDATOR_ROLE, developer, { from: developer });


    await landNFT.updateDefaultInstallmentsByType(
      ether('1'),
      ['10', '20', '30', '40', '50', '60', '70', '80', '90', '100'],
      [ether('0.1'), ether('0.1'), ether('0.1'), ether('0.1'), ether('0.1'), ether('0.1'), ether('0.1'), ether('0.1'), ether('0.1'), ether('0.1')],
      1,
      {from:developer}
    );
    const ts = await time.latest()
    const signature = await sign(web3, developer, bob, tokenId, metadataId, agent, true, this.signatureTime, sale.address);

    await sale.buy(tokenId, metadataId, this.signatureTime, agent, true, signature, { from: bob, value: price });


  });


});
