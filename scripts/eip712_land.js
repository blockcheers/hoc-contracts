const { createTypeData, signTypedData } = require('./eip712');
const TypeName = 'LandSale';
const TypeVersion = '1.0.0';
const Types = {
  [TypeName]: [
    { name: '_wallet', type: 'address' },
    { name: '_tokenId', type: 'uint256' },
    { name: '_metadataId', type: 'uint256' },
    { name: '_agent', type: 'address' },
    { name: '_updateInstallment', type: 'bool' },
    { name: '_signatureTime', type: 'uint256' },
  ],
};

async function sign(
  _web3,
  _validator,
  _wallet,
  _tokenId,
  _metadataId,
  _agent,
  _updateInstallment,
  _signatureTime,
  _verifyingContract
) {
  const chainId = Number(await _web3.eth.getChainId());

  const data = createTypeData(
    { name: TypeName, version: TypeVersion, chainId: chainId, verifyingContract: _verifyingContract },
    TypeName,
    { _wallet, _tokenId, _metadataId, _agent, _updateInstallment , _signatureTime },
    Types
  );
  return (await signTypedData(_web3, _validator, data)).sig;
}

module.exports = { sign };
