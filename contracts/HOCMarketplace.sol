// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/ECDSAUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/draft-EIP712Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";

contract HocMarketplace is OwnableUpgradeable, AccessControlUpgradeable, ReentrancyGuardUpgradeable, EIP712Upgradeable {
  using SafeMathUpgradeable for uint256;

  // AccessControl
  bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
  bytes32 public constant VALIDATOR_ROLE = keccak256("VALIDATOR_ROLE");
  uint256 public listedLandCount;
  uint256 public platformCommission;
  uint256 private platformBalance;
  address public platformAddress;

  // Signing domains for digital signature
  string private constant SIGNING_DOMAIN = "LandDigital-Signature";
  string private constant SIGNATURE_VERSION = "1.0.0";

  // Events
  event ListLand(address landAddress, uint256 landId, uint256 price, address seller);
  event PlatformFee(uint256 time, uint256 newFee);
  event TradeInitiated(address landAddress, uint256 landId, uint256 price, address buyer, uint256 time);
  event DeListLand(address landAddress, uint256 landId);
  event SellLand(address landAddress, address seller, address buyer, uint256 landId, uint256 price);
  event WithdrawAmount(address landAddress, uint256 landId, uint256 price, uint256 commission);

  // struct
  struct Land {
    uint256 landId;
    uint256 price;
    address payable seller;
    address payable buyer;
    bool isSold;
    InitiateTrade isInitiate;
  }

  struct InitiateTrade {
    bool isTradeStarted;
    uint256 amountLocked;
    uint256 time;
  }

  struct LandDigitalSignature {
    uint256 landId;
    address landAddress;
    uint256 price;
    uint256 timeStamp;
    bytes digitalSignature;
  }

  mapping(uint256 => mapping(address => Land)) public lands;

  /**
   * @dev Upgradable initializer
   * @param _platformAddress platform address that receives the commission
   * @param _platformCommission platform fee
   */

  function __HocMarketplace_init(address _platformAddress, uint256 _platformCommission) external initializer {
    __ReentrancyGuard_init();
    __AccessControl_init();
    __Ownable_init();
    __EIP712_init(SIGNING_DOMAIN, SIGNATURE_VERSION);
    _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
    _setupRole(VALIDATOR_ROLE, _msgSender());
    _setupRole(ADMIN_ROLE, _msgSender());
    platformCommission = _platformCommission;
    platformAddress = _platformAddress;
  }

  /**
   * @dev set platform fee
   * @param _platformFee platform fee
   * Note: set Platform fee in wei
   */

  function setPlatformCommission(uint256 _platformFee) public onlyOwner {
    platformCommission = _platformFee;
    emit PlatformFee(block.timestamp, platformCommission);
  }

  /**
   * @dev list land in marketplace
   * @param _landId token id to be listed
   * @param _price listing price of land
   */

  function listLand(address _landAddress, uint256 _landId, uint256 _price) external nonReentrant {
    require(_price > 0, "HOC: Price must be greater than 0");
    require(
      IERC721Upgradeable(_landAddress).ownerOf(_landId) == _msgSender(),
      "HOC: Caller is not the owner of the NFT"
    );

    // increment item count
    listedLandCount++;

    lands[_landId][_landAddress].landId = _landId;
    lands[_landId][_landAddress].price = _price;
    lands[_landId][_landAddress].seller = payable(_msgSender());

    IERC721Upgradeable(_landAddress).transferFrom(_msgSender(), address(this), _landId);
    emit ListLand(_landAddress, _landId, _price, _msgSender());
  }

  /**
   * @dev Initiate Land buying process from marketplace
   * @param _landAddress land contract address
   * @param _landId land token id
   */

  function initiateTrade(address _landAddress, uint256 _landId) external payable nonReentrant {
    uint256 priceOfLand = lands[_landId][_landAddress].price;
    uint256 amount = msg.value;

    require(!lands[_landId][_landAddress].isInitiate.isTradeStarted, "HOC: Trading is already started");
    require(!lands[_landId][_landAddress].isSold, "HOC: Land is already sold");
    require(amount == priceOfLand, "HOC: Invalid amount. Please send the exact price to initiate the trade");

    InitiateTrade memory initiateLandTrade = InitiateTrade(true, amount, block.timestamp);
    lands[_landId][_landAddress].isInitiate = initiateLandTrade;
    lands[_landId][_landAddress].buyer = payable(_msgSender());

    emit TradeInitiated(_landAddress, _landId, amount, _msgSender(), block.timestamp);
  }

  /**
   * @dev withdraw amount of buyer after initiating the buying process
   * @param _landAddress Land contract address
   * @param _landId Land token id
   */

  function withdrawAmount(address _landAddress, uint256 _landId) external nonReentrant {
    require(lands[_landId][_landAddress].buyer == _msgSender(), "HOC: Caller is not the buyer of the Land");
    require(block.timestamp < (lands[_landId][_landAddress].isInitiate.time + 1 days), "HOC: Withdraw time exceeds");
    uint256 price = lands[_landId][_landAddress].price;
    uint256 commission = (platformCommission.mul(price)).div(100e18);
    uint256 landAmount = price.sub(commission);
    platformBalance += commission;

    lands[_landId][_landAddress].isInitiate.isTradeStarted = false;
    lands[_landId][_landAddress].isInitiate.amountLocked = 0;
    lands[_landId][_landAddress].buyer = payable(address(0));

    payable(_msgSender()).transfer(landAmount);

    emit WithdrawAmount(_landAddress, _landId, landAmount, commission);
  }

  /**
   * @dev Delist NFT from marketplace
   * @param _landAddress Land contract address
   * @param _landId NFT token id
   */

  function deListLand(address _landAddress, uint256 _landId) external nonReentrant {
    require(lands[_landId][_landAddress].seller == _msgSender(), "HOC: Caller is not the seller of NFT");
    require(!lands[_landId][_landAddress].isInitiate.isTradeStarted, "HOC: Trade is already Initiated");

    listedLandCount--;

    IERC721Upgradeable(_landAddress).transferFrom(address(this), _msgSender(), _landId);
    emit DeListLand(_landAddress, _landId);
  }

  /**
   * @dev sell the land to the buyer
   */

  function sellLand(
    uint256 landId,
    address landAddress,
    uint256 price,
    uint256 timeStamp,
    bytes calldata digitalSignature
  ) public payable nonReentrant {
    uint256 _landId = landId;
    address _landAddress = landAddress;
    LandDigitalSignature memory landDigitalSignature = LandDigitalSignature(
      landId,
      landAddress,
      price,
      timeStamp,
      digitalSignature
    );

    address validatorAddress = _verifySignature(landDigitalSignature);
    require(lands[_landId][_landAddress].seller == validatorAddress, "HOC: Invalid validator's Digital Signature");

    uint256 totalPrice = lands[_landId][_landAddress].isInitiate.amountLocked;
    address buyer = lands[_landId][_landAddress].buyer;
    address seller = lands[_landId][_landAddress].seller;

    IERC721Upgradeable(_landAddress).transferFrom(address(this), buyer, _landId);

    uint256 commission = (totalPrice * platformCommission) / 100e18;
    uint256 landAmount = totalPrice - commission;
    platformBalance += commission;

    payable(seller).transfer(landAmount);

    lands[_landId][_landAddress].price = 0;
    seller = payable(_msgSender());
    buyer = payable(address(0));
    lands[_landId][_landAddress].isSold = true;

    InitiateTrade memory initiateLandTrade = InitiateTrade(false, 0, 0);
    lands[_landId][_landAddress].isInitiate = initiateLandTrade;

    listedLandCount--;

    emit SellLand(_landAddress, seller, buyer, _landId, landAmount);
  }

  /**
   * @dev _verify, returns the public key
   * @param voucher struct: containing data of NFT
   */

  function _verifySignature(LandDigitalSignature memory voucher) internal view returns (address) {
    bytes32 digest = _hashTypedDataV4(
      keccak256(
        abi.encode(
          keccak256("LandDigitalSignature(uint256 landId,address landAddress,uint256 price,uint256 timeStamp)"),
          voucher.landId,
          voucher.landAddress,
          voucher.price,
          voucher.timeStamp
        )
      )
    );
    return ECDSAUpgradeable.recover(digest, voucher.digitalSignature);
  }

  /**
   * @dev Withdraw platform fee
   */

  function withdraw() public payable onlyRole(ADMIN_ROLE) {
    require(platformBalance > 0, "HOC: Contract has no balance to withdraw");
    payable(platformAddress).transfer(platformBalance);
    platformBalance = 0;
  }

  /**
   * @dev Total number of lands listed in the marketplace for trading
   */

  function hocBalance() public view onlyRole(ADMIN_ROLE) returns (uint256) {
    return platformBalance;
  }

  /**
   * @dev Total number of lands listed in the marketplace for trading
   */

  function totalListedLands() public view returns (uint256) {
    return listedLandCount;
  }
}
