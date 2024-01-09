// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract RentLandNFT is Ownable {
  struct RentInfo {
    address owner;
    address tenant;
    uint256 rentAmount;
    uint256 security;
    uint256 duration;
    uint8 paymentMethod; // 0 for eth, 1 for token
    bool isAcceptByTenant;
    bool requestForBack;
    uint256 lastPaymentTime;
    address nftContract;
    address tokenContract;
  }

  mapping(address => mapping(uint256 => RentInfo)) public rentInfo; // mapping changed to include the NFT contract address
  uint256 public serviceFee;
  address public wallet;

  event PutOnRent(
    address owner,
    address tenant,
    uint256 rentAmount,
    uint256 security,
    uint256 duration,
    uint256 lastPaymentTime,
    address nftContract,
    address tokenContract
  );

  event PutBackRent(address nftContract, uint256 tokenId, bool requestForBack);
  event AcceptPutBackRent(address nftContract, uint256 tokenId);
  event AcceptOnRent(address nftContract, uint256 tokenId, uint256 lastPaymentTime, bool isAcceptByTenant);
  event PayRent(address nftContract, uint256 tokenId, uint256 paymentTime, uint256 serviceFee);

  constructor(uint256 _serviceFee, address _wallet) {
    serviceFee = _serviceFee;
    wallet = _wallet;
  }

  // Updating the service fee and wallet address
  // Can only be called by the contract owner
  // _serviceFee: New service fee to be set
  // _wallet: New wallet address to be set
  function updateServiceFeeAndWallet(uint256 _serviceFee, address _wallet) external onlyOwner {
    serviceFee = _serviceFee;
    wallet = _wallet;
  }

  // Allows the NFT owner to put their land NFT on rent
  // _nftContract: Address of the NFT contract
  // _tokenId: ID of the NFT that is being put on rent
  // _tenant: Address of the tenant
  // _rentAmount: Amount of rent to be paid
  // _security: Security amount to be paid
  // _duration: Duration for which the rent has to be paid
  // _paymentMethod: Payment method chosen, 0 for ETH, and 1 for token
  function putOnRent(
    address _nftContract,
    address _tokenContract,
    uint256 _tokenId,
    address _tenant,
    uint256 _rentAmount,
    uint256 _security,
    uint256 _duration,
    uint8 _paymentMethod
  ) external {
    IERC721 nft = IERC721(_nftContract);
    require(nft.ownerOf(_tokenId) == msg.sender, "HOC: Invalid owner");

    nft.transferFrom(msg.sender, address(this), _tokenId);

    rentInfo[_nftContract][_tokenId] = RentInfo(
      msg.sender,
      _tenant,
      _rentAmount,
      _security,
      _duration,
      _paymentMethod,
      false,
      false,
      block.timestamp,
      _nftContract,
      _tokenContract
    );

    emit PutOnRent(
      msg.sender,
      _tenant,
      _rentAmount,
      _security,
      _duration,
      block.timestamp,
      _nftContract,
      _tokenContract
    );
  }

  // Owner's request to put back the rented NFT
  // Requires the senders to be the owner of the NFT
  // _nftContract: Address of the NFT contract
  // _tokenId: ID of the NFT that is being put back to rent
  function putBackRent(address _nftContract, uint256 _tokenId) external payable {
    RentInfo storage rentInfo_ = rentInfo[_nftContract][_tokenId];
    require(rentInfo_.owner == msg.sender, "HOC: Invalid owner");

    if (rentInfo_.isAcceptByTenant == false) {
      IERC721 nft = IERC721(_nftContract);
      nft.transferFrom(address(this), msg.sender, _tokenId);
      rentInfo_.owner = address(0);
    } else {
      uint256 totalPayment = rentInfo_.security;
      if (rentInfo_.paymentMethod == 0) {
        require(msg.value >= totalPayment, "HOC: Invalid amount");
      } else {
        IERC20 token = IERC20(rentInfo_.tokenContract);
        token.transferFrom(msg.sender, address(this), totalPayment);
      }
      rentInfo_.requestForBack = true;
    }

    emit PutBackRent(_nftContract, _tokenId, true);
  }

  // Tenant to accept the rent and pay the required amount
  // _nftContract: Address of the NFT contract
  // _tokenId: ID of the NFT that is being rented
  function acceptOnRent(address _nftContract, uint256 _tokenId) external payable {
    RentInfo storage rentInfo_ = rentInfo[_nftContract][_tokenId];
    require(rentInfo_.tenant == msg.sender, "HOC: Not tenant");

    uint256 totalPayment = rentInfo_.rentAmount + rentInfo_.security;
    uint256 fee = (totalPayment * serviceFee) / 100;
    totalPayment = totalPayment + fee;

    if (rentInfo_.paymentMethod == 0) {
      require(msg.value >= totalPayment, "HOC: Invalid amount");
      payable(rentInfo_.owner).transfer(totalPayment - fee);
      payable(wallet).transfer(fee);
    } else {
      IERC20 token = IERC20(rentInfo_.tokenContract);
      token.transferFrom(msg.sender, rentInfo_.owner, totalPayment - fee);
      token.transferFrom(msg.sender, wallet, fee);
    }

    rentInfo_.lastPaymentTime = block.timestamp;
    rentInfo_.isAcceptByTenant = true;

    emit AcceptOnRent(_nftContract, _tokenId, block.timestamp, true);
  }

  // Allow tenant to accept the put back rent
  // _nftContract: Address of the NFT contract
  // _tokenId: ID of the NFT that is being put back to rent
  function acceptPutBackRent(address _nftContract, uint256 _tokenId) external {
    RentInfo storage rentInfo_ = rentInfo[_nftContract][_tokenId];

    // in case rent is not due, only tenant can execute it otherwise anyone can execute it
    if (block.timestamp <= rentInfo_.lastPaymentTime + rentInfo_.duration) {
      require(rentInfo_.tenant == msg.sender, "HOC: Not Tenant");
    }
    require(rentInfo_.requestForBack == true, "HOC: No request for back");

    uint256 totalPayment = rentInfo_.security;
    if (rentInfo_.paymentMethod == 0) {
      payable(rentInfo_.tenant).transfer(totalPayment);
    } else {
      IERC20 token = IERC20(rentInfo_.tokenContract);
      token.transfer(rentInfo_.tenant, totalPayment);
    }

    IERC721 nft = IERC721(rentInfo_.nftContract);
    nft.transferFrom(address(this), msg.sender, _tokenId);
    rentInfo_.owner == address(0);

    emit AcceptPutBackRent(_nftContract, _tokenId);
  }

  // Tenant pays the rent
  // _nftContract: Address of the NFT contract
  // _tokenId: ID of the NFT for which the rent has to be paid
  function payRent(address _nftContract, uint256 _tokenId) external payable {
    RentInfo storage rentInfo_ = rentInfo[_nftContract][_tokenId];
    require(rentInfo_.isAcceptByTenant, "HOC: Rent not accepted by tenant");
    require(msg.sender == rentInfo_.tenant, "HOC: Only tenant can pay rent");

    uint256 nextPaymentTime = rentInfo_.lastPaymentTime + rentInfo_.duration;
    require(block.timestamp >= nextPaymentTime, "HOC: Rent is not due yet");

    uint256 totalPayment = rentInfo_.rentAmount;
    uint256 fee = (totalPayment * serviceFee) / 100;
    totalPayment = totalPayment + fee;

    if (rentInfo_.paymentMethod == 0) {
      require(msg.value >= totalPayment, "HOC: Insufficient payment");

      if (msg.value > totalPayment) {
        payable(msg.sender).transfer(msg.value - totalPayment); // refund excess payment
      }

      payable(rentInfo_.owner).transfer(totalPayment - fee);
      payable(wallet).transfer(fee);
    } else {
      IERC20 token = IERC20(rentInfo_.tokenContract);
      token.transferFrom(msg.sender, rentInfo_.owner, totalPayment - fee);
      token.transferFrom(msg.sender, wallet, fee);
    }

    rentInfo_.lastPaymentTime = block.timestamp;
    emit PayRent(_nftContract, _tokenId, block.timestamp, totalPayment - fee);
  }
}
