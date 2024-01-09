// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/draft-EIP712.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./interfaces/ILandNFT.sol";

contract LandDeveloperSale is Ownable, EIP712, AccessControl, ReentrancyGuard {
  struct Logs {
    address user;
    uint256 value;
    uint256 tokenId;
    uint256 _metadataId;
    uint256 _landType;
    address _agent;
    uint256 timestamp;
  }

  struct LandMetadata {
    uint256 lPrice;
    uint256 lType;
    uint256 lLimit;
  }

  /// @dev Validator role
  bytes32 public constant VALIDATOR_ROLE = keccak256("VALIDATOR_ROLE");

  /// @dev Buy logs
  Logs[] public _logs;

  /// @dev Sold by address
  mapping(address => mapping(uint256 => uint256)) public soldByAddress;
  /// @dev Sold by type
  mapping(uint256 => uint256) public soldByType;
  /// @dev Price against each round
  mapping(uint256 => LandMetadata) public landMetadata;

  mapping(address => bool) public blacklist;

  /// @dev Mintable NFT
  ILandNFT public landNFT;

  /// @dev Payment modes
  bool public isNativePayment;
  IERC20 public token;

  /// @dev Time to get the NFT
  uint256 public receiveWindow;
  uint256 public metadataCount = 1;
  uint256 public agentCommission;

  event CollectETHs(address sender, uint256 balance);
  event ChangeLandNFT(ILandNFT landNFT);
  event AddLandMetadata(uint256 price, uint256 _type, uint256 limit, uint256 metadataCount);
  event UpdatePrice(uint256 id, uint256 price);
  event UpdateReceiveWindow(uint256 receiveWindow);
  event UpdateRoundIndex(uint8 roundundex);

  /**
   * @dev Upgradable initializer
   * @param _landNFT Address of mintable NFT
   * @param _agentCommission Agent commission in %
   * @param _isNative If true only eth payments will be allowed
   * @param _token ERC20 token
   */
  constructor(
    ILandNFT _landNFT,
    uint256 _receiveWindow,
    address _developer,
    uint256 _agentCommission,
    bool _isNative,
    IERC20 _token
  ) Ownable() AccessControl() EIP712("LandSale", "1.0.0") ReentrancyGuard() {
    _setupRole(DEFAULT_ADMIN_ROLE, _developer);
    _setupRole(VALIDATOR_ROLE, _developer);

    transferOwnership(_developer);
    landNFT = _landNFT;
    receiveWindow = _receiveWindow;
    agentCommission = _agentCommission;
    isNativePayment = _isNative;
    token = _token;
  }

  /*
   * @notice Return length of buy logs
   */
  function getLogsLength() external view returns (uint) {
    return _logs.length;
  }

  /**
   * @notice View function to get buy logs.
   * @param _pOffset: Offset for paging
   * @param _pLimit: Limit for paging
   * @return Get users, next offset and total buys
   */
  function getLogsPaging(uint _pOffset, uint _pLimit)
    external
    view
    returns (
      Logs[] memory,
      uint,
      uint
    )
  {
    uint totalUsers = _logs.length;
    if (_pLimit == 0) {
      _pLimit = 1;
    }

    if (_pLimit > totalUsers - _pOffset) {
      _pLimit = totalUsers - _pOffset;
    }

    Logs[] memory values = new Logs[](_pLimit);
    for (uint i = 0; i < _pLimit; i++) {
      values[i] = _logs[_pOffset + i];
    }

    return (values, _pOffset + _pLimit, totalUsers);
  }

  /**
   * @notice View function to get buy logs.
   * @param _pOffset: Offset for paging
   * @param _pLimit: Limit for paging
   * @return Get users, next offset and total buys
   */
  function getMetadataPaging(uint _pOffset, uint _pLimit)
    external
    view
    returns (
      LandMetadata[] memory,
      uint,
      uint
    )
  {
    uint totalRecords = metadataCount - 1;
    if (_pLimit == 0) {
      _pLimit = 1;
    }

    if (_pLimit > totalRecords - _pOffset) {
      _pLimit = totalRecords - _pOffset;
    }

    LandMetadata[] memory values = new LandMetadata[](_pLimit);
    for (uint i = 0; i < _pLimit; i++) {
      values[i] = landMetadata[_pOffset + i + 1];
    }

    return (values, _pOffset + _pLimit, totalRecords);
  }

  /**
   * @notice Change the payment mode
   * @dev Only Owner can call this function
   * @param _isNative If true only eth payments will be allowed
   * @param _token ERC20 token
   */
  function updatePaymentMode(bool _isNative, IERC20 _token) external onlyOwner {
    isNativePayment = _isNative;
    token = _token;
  }

  /**
   * @notice Change the address of the mintable NFT
   * @dev Only Owner can call this function
   * @param _landNFT Address of mavia NFT Token
   */
  function changeLandNFT(ILandNFT _landNFT) external onlyOwner {
    landNFT = _landNFT;
    emit ChangeLandNFT(_landNFT);
  }

  /**
   * @notice Add new land metadata
   * @dev Only Owner can call this function
   * @param _price Price of land
   * @param _type type of land
   * @param _limit of land type of land
   */
  function addLandMetadata(
    uint256 _price,
    uint256 _type,
    uint256 _limit
  ) external onlyOwner returns (uint256) {
    landMetadata[metadataCount] = LandMetadata(_price, _type, _limit);
    emit AddLandMetadata(_price, _type, _limit, metadataCount);

    metadataCount++;

    return metadataCount - 1;
  }

  /**
   * @notice Update agent commision
   * @dev Only Owner can call this function
   * @param _agentCommission Agent commission in %
   */
  function setAgentCommission(uint256 _agentCommission) external onlyOwner {
    agentCommission = _agentCommission;
  }

  /**
   * @notice Update price of type
   * @dev Only Owner can call this function
   * @param _price Price of land
   */
  function updateLandPrice(uint256 _id, uint256 _price) external onlyOwner {
    landMetadata[_id].lPrice = _price;
    emit UpdatePrice(_id, _price);
  }

  /**
   * @notice Update Receive window
   * @dev Only Owner can call this function
   * @param _pReceiveWindow window to update
   */
  function updateReceiveWindow(uint256 _pReceiveWindow) external onlyOwner {
    receiveWindow = _pReceiveWindow;
    emit UpdateReceiveWindow(_pReceiveWindow);
  }

  /**
   * @dev Add blacklist to the contract
   * @param _addresses Array of addresses
   */
  function addBlacklist(address[] memory _addresses) external onlyOwner {
    for (uint i = 0; i < _addresses.length; i++) {
      blacklist[_addresses[i]] = true;
    }
  }

  /**
   * @dev Remove blacklist from the contract
   * @param _addresses Array of addresses
   */
  function removeBlacklist(address[] memory _addresses) external onlyOwner {
    for (uint i = 0; i < _addresses.length; i++) {
      blacklist[_addresses[i]] = false;
    }
  }

  /**
   * @notice Calculate hash
   * @dev This function is called in redeem functions
   * @param _wallet User Address
   * @param _tokenId From NFT Id of the user
   * @param _metadataId Id of pool
   * @param _agent Agent address
   * @param _signatureTime Signature time of the user
   */
  function _hash(
    address _wallet,
    uint256 _tokenId,
    uint256 _metadataId,
    address _agent,
    bool _updateInstallment,
    uint256 _signatureTime
  ) internal view returns (bytes32) {
    return
      _hashTypedDataV4(
        keccak256(
          abi.encode(
            keccak256(
              "LandSale(address _wallet,uint256 _tokenId,uint256 _metadataId,address _agent,bool _updateInstallment,uint256 _signatureTime)"
            ),
            _wallet,
            _tokenId,
            _metadataId,
            _agent,
            _updateInstallment,
            _signatureTime
          )
        )
      );
  }

  /**
   * @dev verify signature
   * @param sender_ Bytes32 digest
   * @param tokenId Bytes signature
   */

  function _verify(
    address sender_,
    uint256 tokenId,
    uint256 metadataId,
    address agent,
    bool updateInstallment,
    uint256 signatureTime,
    bytes memory pSignature
  ) internal view {
    bytes32 digest = _hash(sender_, tokenId, metadataId, agent, updateInstallment, signatureTime);

    require(hasRole(VALIDATOR_ROLE, ECDSA.recover(digest, pSignature)), "HOC: Invalid hash");
  }

  // function _verify(bytes32 _pDigest, bytes memory _pSignature) internal view returns (bool) {
  //   return hasRole(VALIDATOR_ROLE, ECDSA.recover(_pDigest, _pSignature));
  // }

  /**
   * @dev Owner can collect all ETH
   */
  function collectETHs() external onlyOwner {
    address payable sender = payable(_msgSender());

    uint256 balance = address(this).balance;
    sender.transfer(balance);

    // Emit event
    emit CollectETHs(sender, balance);
  }

  /**
   * @dev Owner can collect all ERC20 Tokens
   */
  function collectTokens() external onlyOwner {
    address sender = _msgSender();

    uint256 balance = token.balanceOf(address(this));

    token.transfer(sender, balance);
    // Emit event
    emit CollectETHs(sender, balance);
  }

  function mintLand(
    address sender_,
    uint256 _tokenId,
    string memory _tokenURI,
    uint256 _type,
    bool _updateInstallment
  ) internal {
    landNFT.mint(sender_, _tokenId, _tokenURI, _type, _updateInstallment);
  }

  /**
   * @dev Buy an NFT
   * @param _metadataId 0 MetadataId
   * @param _tokenId From NFT Id of the user
   * @param _tokenURI Token URI of the NFT
   * @param _signatureTime Signature time of the user
   * @param _pSignature Byte value
   */
  function buy(
    uint256 _tokenId,
    uint256 _metadataId,
    uint256 _signatureTime,
    uint256 _totalInstallments,
    string memory _tokenURI,
    address _agent,
    bool _updateInstallment,
    bytes calldata _pSignature
  ) external payable nonReentrant {
    uint256 value_ = isNativePayment ? msg.value : landMetadata[_metadataId].lPrice;
    uint256 landType = landMetadata[_metadataId].lType;
    address sender_ = _msgSender();

    require(block.timestamp <= _signatureTime + receiveWindow, "HOC: Signature expired");
    require(!blacklist[sender_], "HOC: Blacklisted user");

    _verify(sender_, _tokenId, _metadataId, _agent, _updateInstallment, _signatureTime, _pSignature);

    uint256 commission_;
    if (_agent != address(0)) {
      commission_ = (landMetadata[_metadataId].lPrice * agentCommission) / 100;
      if (isNativePayment) {
        payable(_agent).transfer(commission_);
      } else {
        token.transferFrom(sender_, _agent, commission_);
      }
    }

    if (_updateInstallment) {
      require(value_ >= (landMetadata[_metadataId].lPrice / _totalInstallments), "HOC: Invalid price");
      // Adjust token transfer logic for installment
      uint256 installmentValue = landMetadata[_metadataId].lPrice / _totalInstallments;
      if (isNativePayment) {
        payable(_agent).transfer(commission_);
        payable(_agent).transfer(installmentValue * (_totalInstallments - 1));
      } else {
        token.transferFrom(sender_, _agent, commission_ + installmentValue);
        token.transferFrom(sender_, address(this), value_ - commission_ - installmentValue);
      }
    } else {
      require(value_ >= landMetadata[_metadataId].lPrice, "HOC: Invalid price");
      if (isNativePayment) {
        payable(_agent).transfer(commission_);
      } else {
        token.transferFrom(sender_, _agent, commission_);
        token.transferFrom(sender_, address(this), value_ - commission_);
      }
    }

    // Mint NFT
    mintLand(sender_, _tokenId, _tokenURI, landType, _updateInstallment);

    soldByType[_metadataId] += value_;
    soldByAddress[sender_][_metadataId] += value_;

    _logs.push(Logs(sender_, value_, _tokenId, _metadataId, landType, _agent, block.timestamp));
  }
}
