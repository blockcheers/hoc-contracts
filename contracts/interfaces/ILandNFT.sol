// SPDX-License-Identifier: MIT

pragma solidity 0.8.4;

interface ILandNFT {
  function mint(
    address _to,
    uint256 _id,
    string memory _tokenURI,
    uint256 _type,
    bool _updateInstallment
  ) external; /* onlyRole(MINTER_ROLE) */

  function burn(uint256 _pId) external;
}
