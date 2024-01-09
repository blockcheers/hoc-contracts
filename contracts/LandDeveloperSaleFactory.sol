// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "./LandDeveloperSale.sol";

// import "./LandNFT.sol";

contract LandDeveloperSaleFactory is Ownable, AccessControl {
  // Array to store deployed LandNFT contracts
  // LandNFT[] public landNFTs;
  bytes32 public constant DEVELOPER_ROLE = keccak256("DEVELOPER_ROLE");

  // Array to store deployed LandDeveloperSale contracts
  LandDeveloperSale[] public LandDeveloperSales;
  uint256 public price;

  // event NewLandNFT(LandNFT newLandNFTContract);
  event NewLandDeveloperSale(LandDeveloperSale newLandDeveloperSaleContract);

  constructor() Ownable() AccessControl() {
    _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    _setupRole(DEVELOPER_ROLE, msg.sender);
  }

  /**
   * @dev See {IERC165-supportsInterface}.
   */
  function supportsInterface(bytes4 _interfaceId) public view virtual override(AccessControl) returns (bool) {
    return super.supportsInterface(_interfaceId);
  }

  function updatePrice(uint256 _price) external onlyOwner {
    price = _price;
  }

  /**
   * @notice Creates a new LandNFT and LandDeveloperSale contract
   * @param _agentCommission Agent commission in %
   * @param _receiveWindow Receive window for purchasing
   * @param _isNative If true only eth payments will be allowed
   * @param _token ERC20 token
   */
  function createDeveloperSale(
    uint256 _agentCommission,
    uint256 _receiveWindow,
    address _nftContract,
    bool _isNative,
    IERC20 _token
  ) external payable onlyRole(DEVELOPER_ROLE) returns (LandDeveloperSale) {
    require(price >= msg.value, "invalid price");

    address sender = _msgSender();
    LandDeveloperSale newLandDeveloperSaleContract = new LandDeveloperSale(
      ILandNFT(_nftContract),
      _receiveWindow,
      sender,
      _agentCommission,
      _isNative,
      _token
    );

    LandDeveloperSales.push(newLandDeveloperSaleContract);
    emit NewLandDeveloperSale(newLandDeveloperSaleContract);

    return (newLandDeveloperSaleContract);
  }

  /**
   * @notice Gets the number of deployed LandDeveloperSale contracts
   * @return The number of deployed LandDeveloperSale contracts
   */
  function getLandDeveloperSalesCount() external view returns (uint256) {
    return LandDeveloperSales.length;
  }
}
