const { createTypeData, signTypedData } = require('./eip712');
const TypeName = 'LandDigitalSignature';
const TypeVersion = '1.0.0';
const Types = {
  [TypeName]: [
    { name: 'landId', type: 'uint256' },
    { name: 'price', type: 'uint256' },
    { name: 'timeStamp', type: 'uint256' },
    { name: 'landAddress', type: 'address' },
    { name: 'highestBidder', type: 'address' },
    { name: 'message', type: 'string' },
  ],
};

async function sign(_web3, landId, landAddress, price, timeStamp, highestBidder, message, _verifyingContract) {
  const chainId = Number(await _web3.eth.getChainId());
  const data = createTypeData(
    { name: TypeName, version: TypeVersion, chainId: chainId, verifyingContract: _verifyingContract },
    TypeName,
    { landId, price, timeStamp, landAddress, highestBidder, message },
    Types
  );
  return (await signTypedData(_web3, _validator, data)).sig;
}

module.exports = { sign };
