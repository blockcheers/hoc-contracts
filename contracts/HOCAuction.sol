// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/draft-EIP712Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract HOCAuction is ReentrancyGuardUpgradeable, OwnableUpgradeable, AccessControlUpgradeable, EIP712Upgradeable {
  using Counters for Counters.Counter;

  // AccessControl
  bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
  bytes32 public constant VALIDATOR_ROLE = keccak256("VALIDATOR_ROLE");

  // token listed Lands in auction
  Counters.Counter private biddingItems;

  // Signing domains for digital signature
  string private constant SIGNING_DOMAIN = "LandDigital-Signature";
  string private constant SIGNATURE_VERSION = "1.0.0";

  uint256 public platformCommission;
  uint256 public platformBalance;
  address public platformAddress;

  // bidding declarations
  struct AuctionItem {
    uint256 landId;
    uint256 askingPrice;
    uint256 endTime;
    address landAddress;
    address payable seller;
    address highestBidder;
    bool isAccepted;
  }

  struct LandDigitalSignature {
    uint256 landId;
    uint256 price;
    uint256 timeStamp;
    address landAddress;
    address highestBidder;
    bytes digitalSignature;
  }

  mapping(uint256 => mapping(address => AuctionItem)) public itemsForAuction;
  mapping(address => mapping(uint256 => bool)) public activeItems;

  event ItemAdded(uint256 landId, uint256 askingPrice, address landAddress);
  event BidClaimed(uint256 landId, uint256 askingPrice, address buyer);
  event HighBidder(address _highestBidder, uint256 _price);
  event AcceptBid(uint256 landId, address landAddress, bool isAccepted, uint256 price);
  event PlatformFee(uint256 time, uint256 newFee);

  /**
   * @dev Upgradable initializer
   */

  function __HocAuction_init(address _platformAddress, uint256 _platformCommission) external initializer {
    __EIP712_init(SIGNING_DOMAIN, SIGNATURE_VERSION);
    __ReentrancyGuard_init();
    __AccessControl_init();
    _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
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
   * @dev listing an item for bidding
   * @param _landId Token Id of NFT
   * @param _landAddress Contract address of NFT
   * @param _askingPrice mininum price of bidding
   * @param _time ending time of an auction
   */

  function addItemToBid(
    uint256 _landId,
    address _landAddress,
    uint256 _askingPrice,
    uint256 _time
  ) external nonReentrant returns (uint256) {
    require(_askingPrice > 0, "HOC: Price must be greater than 0");
    require(block.timestamp < _time, "HOC: Invalid time");

    itemsForAuction[_landId][_landAddress] = AuctionItem(
      _landId,
      _askingPrice,
      _time,
      _landAddress,
      payable(msg.sender),
      address(0),
      false
    );
    assert(itemsForAuction[_landId][_landAddress].landId == _landId);
    activeItems[_landAddress][_landId] = true;
    IERC721(_landAddress).transferFrom(msg.sender, address(this), _landId);
    biddingItems.increment();
    emit ItemAdded(_landId, _askingPrice, _landAddress);
    return (_landId);
  }

  /***
   * @dev placing bid for token
   * @param _landId Token Id of NFT
   * @param _landAddress Contract address of NFT
   * @param _amount  Amount enter by user
   */

  function placeBid(uint256 _landId, address _landAddress) external payable nonReentrant {
    uint256 amount = msg.value;
    require(block.timestamp < itemsForAuction[_landId][_landAddress].endTime, "HOC: Time is up");
    require(itemsForAuction[_landId][_landAddress].isAccepted == false, "HOC: Last bid was accepted");
    require(
      amount >= itemsForAuction[_landId][_landAddress].askingPrice,
      "HOC: Your bid must be greater than the current bid"
    );

    address highestBidder = itemsForAuction[_landId][_landAddress].highestBidder;

    payable(address(this)).transfer(amount);

    if (itemsForAuction[_landId][_landAddress].highestBidder != address(0)) {
      payable(highestBidder).transfer(itemsForAuction[_landId][_landAddress].askingPrice);
    }

    itemsForAuction[_landId][_landAddress].highestBidder = msg.sender;
    itemsForAuction[_landId][_landAddress].askingPrice = amount;
    emit HighBidder(msg.sender, amount);
  }

  /***
   * @dev claim Token
   * @param voucher struct: containing data of NFT
   */

  function claimToken(
    uint256 landId,
    uint256 price,
    uint256 timeStamp,
    address landAddress,
    address highestBidder,
    bytes calldata digitalSignature
  ) external nonReentrant {
    LandDigitalSignature memory landDigitalSignature = LandDigitalSignature(
      landId,
      price,
      timeStamp,
      landAddress,
      highestBidder,
      digitalSignature
    );
    AuctionItem storage auctionItem = itemsForAuction[landId][landAddress];

    address validatorAddress = _verifySignature(landDigitalSignature);
    require(auctionItem.seller == validatorAddress, "HOC: Invalid Signer's Digital Signature");

    require(block.timestamp > auctionItem.endTime, "HOC: Auction has not ended yet");
    require(
      _msgSender() == auctionItem.highestBidder || _msgSender() == auctionItem.seller,
      "HOC: Invalid caller of this function"
    );

    IERC721(auctionItem.landAddress).transferFrom(address(this), auctionItem.highestBidder, auctionItem.landId);
    uint256 commission = (platformCommission * auctionItem.askingPrice) / 100e18;
    uint256 landAmount = auctionItem.askingPrice - commission;
    payable(auctionItem.seller).transfer(landAmount);
    platformBalance += commission;

    delete itemsForAuction[auctionItem.landId][auctionItem.landAddress];
    activeItems[auctionItem.landAddress][auctionItem.landId] = false;
    biddingItems.decrement();

    emit BidClaimed(auctionItem.landId, auctionItem.askingPrice, msg.sender);
  }

  /**
   * @dev _verify, returns the public key
   * @param landDigitalSignature struct: containing data of NFT
   */

  function _verifySignature(LandDigitalSignature memory landDigitalSignature) internal view returns (address) {
    bytes32 digest = _hashTypedDataV4(
      keccak256(
        abi.encode(
          keccak256(
            "LandDigitalSignature(uint256 landId,uint256 price,uint256 timeStamp,address landAddress,address highestBidder)"
          ),
          landDigitalSignature.landId,
          landDigitalSignature.price,
          landDigitalSignature.timeStamp,
          landDigitalSignature.landAddress,
          landDigitalSignature.highestBidder
        )
      )
    );
    return ECDSA.recover(digest, landDigitalSignature.digitalSignature);
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
   * @dev Total number of lands listed in the auction for bidding
   */

  function totalListedLands() public view returns (uint256) {
    return biddingItems.current();
  }
}
