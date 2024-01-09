// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

// import "./LandDeveloperSale.sol";
import "./LandNFT.sol";

contract LandNFTFactory is Ownable, AccessControl {
  // Array to store deployed LandNFT contracts
  LandNFT[] public landNFTs;
  bytes32 public constant DEVELOPER_ROLE = keccak256("DEVELOPER_ROLE");

  uint256 public price;

  event NewLandNFT(LandNFT newLandNFTContract);
  // Collect all the ETH
  event CollectETHs(address sender, uint256 balance);

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
   * @param _name Name of the LandNFT
   * @param _symbol Symbol of the LandNFT
   * @param _isNative If true only eth payments will be allowed
   * @param _token ERC20 token
   */
  function createLandNFT(
    string memory _name,
    string memory _symbol,
    uint256 _paneltyPercentage,
    bool _isNative,
    IERC20 _token
  ) external payable onlyRole(DEVELOPER_ROLE) returns (LandNFT) {
    require(price >= msg.value, "invalid price");

    address sender = _msgSender();
    LandNFT newLandNFTContract = new LandNFT(_name, _symbol, _paneltyPercentage, sender, _isNative, _token);
    landNFTs.push(newLandNFTContract);
    // newLandNFTContract.grantRole(newLandNFTContract.DEFAULT_ADMIN_ROLE(), msg.sender);

    emit NewLandNFT(newLandNFTContract);
    return (newLandNFTContract);
  }

  /**
   * @notice Gets the number of deployed LandNFT contracts
   * @return The number of deployed LandNFT contracts
   */
  function getLandNFTsCount() external view returns (uint256) {
    return landNFTs.length;
  }

  /**
   * @dev Owner can collect all ETH
   */
  function fCollectETHs() external onlyOwner {
    address payable sender = payable(_msgSender());

    uint256 balance = address(this).balance;
    sender.transfer(balance);

    // Emit event
    emit CollectETHs(sender, balance);
  }
}
