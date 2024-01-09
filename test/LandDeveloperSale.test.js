const { expect, assert } = require('chai');
const { BN, ether, expectEvent, expectRevert, time } = require('@openzeppelin/test-helpers');
const LandDeveloperSale = artifacts.require('LandDeveloperSale');
const LandNFT = artifacts.require('LandNFT');
const { sign } = require('../scripts/eip712_land');
const { ethers } = require('hardhat');
// const { web3 } = require('@openzeppelin/test-helpers/src/setup');

// npx hardhat node
// truffle test 'test/LandDeveloperSale.test.js' --network test
const ZERO = '0x0000000000000000000000000000000000000000'

contract('LandDeveloperSale', function (accounts) {
  const [owner, user, agent, validator] = accounts;

  beforeEach(async function () {
    this.landNFT = await LandNFT.new('abc', 'abc', 'abc', 10, owner, true, ZERO, { from: owner });
    this.landDeveloperSale = await LandDeveloperSale.new(this.landNFT.address, 86400, owner, 10, true, ZERO, { from: owner });

    // Grant VALIDATOR_ROLE to `validator`
    await this.landDeveloperSale.grantRole(web3.utils.keccak256("VALIDATOR_ROLE"), validator, { from: owner });
  });

  it('should allow the owner to add land metadata', async function () {
    const { logs } = await this.landDeveloperSale.addLandMetadata(ether('1'), 1, 100, { from: owner });
    expectEvent.inLogs(logs, 'AddLandMetadata', { price: ether('1'), _type: new BN(1), limit: new BN(100), metadataCount: new BN(1) });

    const landMetadata = await this.landDeveloperSale.landMetadata(1);
    expect(landMetadata.lPrice.toString()).to.be.equal(ether('1').toString());
    expect(landMetadata.lType.toString()).to.be.equal('1');
    expect(landMetadata.lLimit.toString()).to.be.equal('100');
  });

  it('should revert when non-owner tries to add land metadata', async function () {
    await expectRevert(this.landDeveloperSale.addLandMetadata(ether('1'), 1, 100, { from: user }), "Ownable: caller is not the owner");
  });

  // Add more test cases below
  // ...
  describe('buy', function () {
    const tokenId = 1;
    const metadataId = 1;
    const landType = 0;
    const price = ether('1');
    const limit = 100;
    const VALIDATOR_ROLE = web3.utils.keccak256('VALIDATOR_ROLE');
    const MINTER_ROLE = web3.utils.keccak256('MINTER_ROLE');
    const DEVELOPER_ROLE = web3.utils.keccak256('DEVELOPER_ROLE');


    beforeEach(async function () {
      // this.landNFT = await LandNFT.new('abc', 'abc', 'abc', owner,{ from: owner });
      // this.landDeveloperSale = await landDeveloperSale.new(this.landNFT.address, 86400, owner, { from: owner });

      await this.landDeveloperSale.addLandMetadata(price, metadataId, limit, { from: owner });
      await this.landDeveloperSale.grantRole(VALIDATOR_ROLE, validator, { from: owner });
      await this.landNFT.grantRole(MINTER_ROLE, this.landDeveloperSale.address, { from: owner });
      await this.landNFT.grantRole(DEVELOPER_ROLE, owner, { from: owner });

      this.signatureTime = (await web3.eth.getBlock('latest')).timestamp;
    });

    it('should buy successfully', async function () {
      const signature = await sign(web3, validator, user, tokenId, metadataId, agent, false, this.signatureTime, this.landDeveloperSale.address);
      // console.log(signature, this.landDeveloperSale.address, validator, user, tokenId, metadataId, agent, this.signatureTime);

      await this.landDeveloperSale.buy(tokenId, metadataId, this.signatureTime, agent, false, signature, { from: user, value: price });

      const balance = await this.landNFT.balanceOf(user);
      expect(balance.toString()).to.be.equal('1');
    });

    it('should fail if the signature is invalid', async function () {
      const badValidator = accounts[5];
      // const signature = await sign(user, tokenId, metadataId, agent, this.signatureTime, badValidator);
      const signature = await sign(web3, badValidator, user, tokenId, metadataId, agent, false, this.signatureTime, this.landDeveloperSale.address);

      await expectRevert(
        this.landDeveloperSale.buy(tokenId, metadataId, this.signatureTime, agent, false, signature, { from: user, value: price }),
        'invalid hash'
      );
    });

    it('should fail if signature is expired', async function () {
      // const signature = await sign(user, tokenId, metadataId, agent, this.signatureTime - 86401, validator);
      const signature = await sign(web3, validator, user, tokenId, metadataId, agent, false, this.signatureTime- 86401, this.landDeveloperSale.address);

      await expectRevert(
        this.landDeveloperSale.buy(tokenId, metadataId, this.signatureTime - 86401, agent, false, signature, { from: user, value: price }),
        'signature expired'
      );
    });

    it('should fail if the user is in the blacklist', async function () {
      // const signature = await sign(user, tokenId, metadataId, agent, this.signatureTime, validator);
      const signature = await sign(web3, validator, user, tokenId, metadataId, agent, false, this.signatureTime, this.landDeveloperSale.address);

      await this.landDeveloperSale.addBlacklist([user], { from: owner });

      await expectRevert(
        this.landDeveloperSale.buy(tokenId, metadataId, this.signatureTime, agent, false,signature, { from: user, value: price }),
        'blacklist'
      );
    });

    it('should fail if price is too low', async function () {
      // const signature = await sign(user, tokenId, metadataId, agent, this.signatureTime, validator);
      const signature = await sign(web3, validator, user, tokenId, metadataId, agent, false, this.signatureTime, this.landDeveloperSale.address);

      await expectRevert(
        this.landDeveloperSale.buy(tokenId, metadataId, this.signatureTime, agent, false, signature, { from: user, value: ether('0.5') }),
        'invalid price'
      );
    });

    it('should fail if the limit is reached', async function () {
      const signature = await sign(web3, validator, user, tokenId, metadataId, agent, false, this.signatureTime, this.landDeveloperSale.address);
      const signature2 = await sign(web3, validator ,user, tokenId + 1, metadataId, agent, false, this.signatureTime, this.landDeveloperSale.address);

      await this.landDeveloperSale.updateLandPrice(metadataId, price, { from: owner });
      await this.landDeveloperSale.addLandMetadata(price, 1,1, { from: owner });

      await this.landDeveloperSale.buy(tokenId, metadataId, this.signatureTime, agent, false, signature, { from: user, value: price });

      await expectRevert(
        this.landDeveloperSale.buy(tokenId + 1, metadataId, this.signatureTime, agent, false, signature2, { from: user, value: price }),
        'limit reached'
      );
    });

    it('should setup default installments', async function () {
      await this.landNFT.updateDefaultInstallmentsByType(
        ether('1'),
        ['10', '20', '30', '40', '50', '60', '70', '80', '90', '100'],
        [ether('0.1'), ether('0.1'), ether('0.1'), ether('0.1'), ether('0.1'), ether('0.1'), ether('0.1'), ether('0.1'), ether('0.1'), ether('0.1')],
        1
      );

      const defaultInstallments = await this.landNFT.getDefaultInstallmentsByType(0,10, metadataId)
      // console.log(defaultInstallments)
      const signature = await sign(web3, validator, user, tokenId, metadataId, agent, true, this.signatureTime, this.landDeveloperSale.address);
      // console.log(signature, this.landDeveloperSale.address, validator, user, tokenId, metadataId, agent, this.signatureTime);

      await this.landDeveloperSale.buy(tokenId, metadataId, this.signatureTime, agent, true, signature, { from: user, value: price });
      assert.equal(await this.landNFT.ownerOf(tokenId), user)
      const installments = await this.landNFT.getInstallmentsByTokenId(0,10, tokenId)
      assert.equal(await this.landNFT.isFullyPaid(tokenId), false)

      const numOfIns = await this.landNFT.numberOfInstallments(tokenId)
      const t = await this.landNFT.typeIds(tokenId)
      const defaultIns = await this.landNFT.defaultNumberOfInstallments(metadataId)
      // console.log(numOfIns.toString(), defaultIns.toString(), await this.landDeveloperSale.landNFT(), t.toString())
      // console.log(installments)
      await expectRevert(this.landNFT.payInstallment(1, tokenId), 'not owner') ;
      await expectRevert(this.landNFT.payInstallment(1, tokenId, {from: user}), 'Invalid Amount') ;
      await expectRevert(this.landNFT.payInstallment(1, tokenId, {from: user, value: 1}), 'Invalid Amount') ;

      await this.landNFT.payInstallment(1, tokenId, {from: user, value: ether('0.1')})
      await expectRevert(this.landNFT.payInstallment(1, tokenId, {from: user, value:ether('0.1') }), 'paid') ;

      await time.increase(22)
      await expectRevert(this.landNFT.payInstallment(2, tokenId, {from: user, value: ether('0.1')}), 'Invalid Amount');
      assert.equal(await this.landNFT.isFullyPaid(tokenId), false)
      await this.landNFT.payInstallment(2, tokenId, {from: user, value: ether('0.11')})
      assert.equal(await this.landNFT.isFullyPaid(tokenId), false)
      await this.landNFT.payInstallment(3, tokenId, {from: user, value: ether('0.1')})
      assert.equal(await this.landNFT.isFullyPaid(tokenId), false)
      await this.landNFT.payInstallment(4, tokenId, {from: user, value: ether('0.1')})
      assert.equal(await this.landNFT.isFullyPaid(tokenId), false)
      await this.landNFT.payInstallment(5, tokenId, {from: user, value: ether('0.1')})
      assert.equal(await this.landNFT.isFullyPaid(tokenId), false)
      await this.landNFT.payInstallment(6, tokenId, {from: user, value: ether('0.1')})
      assert.equal(await this.landNFT.isFullyPaid(tokenId), false)
      await this.landNFT.payInstallment(7, tokenId, {from: user, value: ether('0.1')})
      assert.equal(await this.landNFT.isFullyPaid(tokenId), false)
      await this.landNFT.payInstallment(8, tokenId, {from: user, value: ether('0.1')})
      assert.equal(await this.landNFT.isFullyPaid(tokenId), false)
      await this.landNFT.payInstallment(9, tokenId, {from: user, value: ether('0.1')})
      assert.equal(await this.landNFT.isFullyPaid(tokenId), false)
      await this.landNFT.payInstallment(10, tokenId, {from: user, value: ether('0.1')})

      assert.equal(await this.landNFT.isFullyPaid(tokenId), true)
    });
  });
});
