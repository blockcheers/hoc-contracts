// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./interfaces/ILandNFT.sol";
import "./utils/OpenseaDelegate.sol";

/**
 * @title LandNFT contract
 * @dev Contract for managing Land NFTs
 */
contract LandNFT is ERC721URIStorage, Ownable, AccessControl, ILandNFT {
  // Structure to represent an installment
  struct Installment {
    uint256 dueDate;
    uint256 amount;
    bool isPaid;
  }

  // Role constants
  bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
  bytes32 public constant APPROVER_ROLE = keccak256("APPROVER_ROLE");
  bytes32 public constant DEVELOPER_ROLE = keccak256("DEVELOPER_ROLE");

  // Mapping to track whether the token installments are fully paid
  mapping(uint256 => bool) public isFullyPaid;

  // Mapping to track the creator of each token
  mapping(uint256 => address) public creators;

  // Mapping to track the timestamp of ownership for each token
  mapping(uint256 => uint256) public ownTime;

  // Mapping to store custom installments for each token
  mapping(uint256 => mapping(uint256 => Installment)) public defaultInstallments;

  // Mapping to store installments for each token
  mapping(uint256 => mapping(uint256 => Installment)) public installments;

  // Mapping to store the default total amount for each token type
  mapping(uint256 => uint256) public defaultTotalAmount;

  // Mapping to store the default number of installments for each token type
  mapping(uint256 => uint256) public defaultNumberOfInstallments;

  // Mapping to track the total amount paid for each token
  mapping(uint256 => uint256) public totalAmountPaid;

  // Mapping to track the number of installments for each token
  mapping(uint256 => uint256) public numberOfInstallments;

  // Penalty percentage for late installment payment
  uint256 public dueDatePaneltyPercentage;

  // Address for OpenSea proxy registry
  address public proxyRegistryAddress;

  // Flag to indicate if OpenSea proxy is active or not
  bool public isOpenSeaProxyActive;

  // Address of the contract factory
  address public factory;

  /// @dev Payment modes
  bool public isNativePayment;
  IERC20 public token;

  // Mapping to store the type ID of each token
  mapping(uint256 => uint256) public typeIds;

  // Event emitted when all installments for a token are paid
  event AllInstalmentsPaid(uint256 _tokenId);

  // Event emitted when an installment for a token is paid
  event InstallmentPaid(uint256 _tokenId, uint256 _installmentIndex, uint256 amount, uint256 panelty);

  // Event emitted when an installment for a token is updated
  event UpdateInstallment(
    uint256 _tokenId,
    uint256 _installment,
    uint256 _numberOfSecondsFromNow,
    uint256 _amount,
    uint256 _numberOfInstallments
  );

  // Event emitted when multiple installments for a token are updated
  event UpdateBulkInstallment(
    uint256 _tokenId,
    uint256[] _installment,
    uint256[] _numberOfSecondsFromNow,
    uint256[] _amount,
    uint256 _numberOfInstallments
  );

  // Event emitted when the default installments for a token type are updated
  event UpdateDefaultInstallmentsByType(
    uint256 _totalAmount,
    uint256[] _numberOfSecondsFromNow,
    uint256[] _amounts,
    uint256 _type
  );

  // Collect all the ETH
  event CollectETHs(address sender, uint256 balance);

  /**
   * @dev See {IERC165-supportsInterface}.
   */
  function supportsInterface(bytes4 _interfaceId) public view virtual override(ERC721, AccessControl) returns (bool) {
    return _interfaceId == type(ILandNFT).interfaceId || super.supportsInterface(_interfaceId);
  }

  /**
   * @dev Initializer
   * @param _name Token name
   * @param _symbol Token symbol
   * @param _dueDatePenaltyPercentage Penalty percentage for late installment payment
   * @param _owner Address of the contract owner
   * @param _isNative If true only eth payments will be allowed
   * @param _token ERC20 token
   */
  constructor(
    string memory _name,
    string memory _symbol,
    uint256 _dueDatePenaltyPercentage,
    address _owner,
    bool _isNative,
    IERC20 _token
  ) AccessControl() ERC721(_name, _symbol) Ownable() {
    _setupRole(DEFAULT_ADMIN_ROLE, _owner);
    _setupRole(DEVELOPER_ROLE, _owner);
    _setupRole(APPROVER_ROLE, _owner);
    _setupRole(MINTER_ROLE, _owner);
    transferOwnership(_owner);
    dueDatePaneltyPercentage = _dueDatePenaltyPercentage;
    isNativePayment = _isNative;
    token = _token;
  }

  /**
   * @notice View function to get default installments.
   * @param _pOffset: Offset for paging
   * @param _pLimit: Limit for paging
   * @param _type: Type of Installment
   * @return Get users, next offset and total buys
   */
  function getDefaultInstallmentsByType(
    uint _pOffset,
    uint _pLimit,
    uint256 _type
  ) external view returns (Installment[] memory, uint, uint) {
    uint totalRecords = defaultNumberOfInstallments[_type];
    if (_pLimit == 0) {
      _pLimit = 1;
    }

    if (_pLimit > totalRecords - _pOffset) {
      _pLimit = totalRecords - _pOffset;
    }

    Installment[] memory values = new Installment[](_pLimit);
    for (uint i = 0; i < _pLimit; i++) {
      values[i] = defaultInstallments[_type][_pOffset + i + 1];
    }

    return (values, _pOffset + _pLimit, totalRecords);
  }

  /**
   * @notice View function to get default installments.
   * @param _pOffset: Offset for paging
   * @param _pLimit: Limit for paging
   * @param _tokenId: Type of Installment
   * @return Get users, next offset and total buys
   */
  function getInstallmentsByTokenId(
    uint _pOffset,
    uint _pLimit,
    uint256 _tokenId
  ) external view returns (Installment[] memory, uint, uint) {
    uint totalRecords = numberOfInstallments[_tokenId];
    if (_pLimit == 0) {
      _pLimit = 1;
    }

    if (_pLimit > totalRecords - _pOffset) {
      _pLimit = totalRecords - _pOffset;
    }

    Installment[] memory values = new Installment[](_pLimit);
    for (uint i = 0; i < _pLimit; i++) {
      values[i] = installments[_tokenId][_pOffset + i + 1];
    }

    return (values, _pOffset + _pLimit, totalRecords);
  }

  /**
   * @dev Update the default installments for a token type.
   * @param _totalAmount The total amount for the installments
   * @param _numberOfSecondsFromNow Array of durations in seconds for each installment
   * @param _amounts Array of amounts for each installment
   * @param _type The token type
   */
  function updateDefaultInstallmentsByType(
    uint256 _totalAmount,
    uint256[] memory _numberOfSecondsFromNow,
    uint256[] memory _amounts,
    uint256 _type
  ) external onlyRole(DEVELOPER_ROLE) {
    for (uint256 index; index < _numberOfSecondsFromNow.length; index++) {
      defaultInstallments[_type][index + 1] = Installment(_numberOfSecondsFromNow[index], _amounts[index], false);
    }

    defaultTotalAmount[_type] = _totalAmount;
    defaultNumberOfInstallments[_type] = _numberOfSecondsFromNow.length;

    emit UpdateDefaultInstallmentsByType(_totalAmount, _numberOfSecondsFromNow, _amounts, _type);
  }

  /**
   * @dev Update an installment for a token.
   * @param _tokenId The token ID
   * @param _installment The installment index
   * @param _numberOfSecondsFromNow The duration in seconds for the installment to be due
   * @param _amount The amount for the installment
   * @param _numberOfInstallments The total number of installments for the token
   */
  function updateInstallment(
    uint256 _tokenId,
    uint256 _installment,
    uint256 _numberOfSecondsFromNow,
    uint256 _amount,
    uint256 _numberOfInstallments
  ) external onlyRole(DEVELOPER_ROLE) {
    require(isFullyPaid[_tokenId] == false, "HOC: All installments are paid");

    Installment storage installment = installments[_tokenId][_installment];
    if (installment.isPaid == false) {
      installment.dueDate = block.timestamp + _numberOfSecondsFromNow;
      installment.amount = _amount;
    }

    numberOfInstallments[_tokenId] = _numberOfInstallments;

    emit UpdateInstallment(_tokenId, _installment, _numberOfSecondsFromNow, _amount, _numberOfInstallments);
  }

  /**
   * @dev Update multiple installments for a token.
   * @param _tokenId The token ID
   * @param _installment Array of installment indexes
   * @param _numberOfSecondsFromNow Array of durations in seconds for each installment
   * @param _amount Array of amounts for each installment
   * @param _numberOfInstallments The total number of installments for the token
   */
  function updateBulkInstallment(
    uint256 _tokenId,
    uint256[] memory _installment,
    uint256[] memory _numberOfSecondsFromNow,
    uint256[] memory _amount,
    uint256 _numberOfInstallments
  ) external onlyRole(DEVELOPER_ROLE) {
    require(isFullyPaid[_tokenId] == false, "HOC: All installments are paid");

    for (uint256 index; index < _numberOfSecondsFromNow.length; index++) {
      Installment storage installment = installments[_tokenId][_installment[index]];
      if (installment.isPaid == false) {
        installment.dueDate = block.timestamp + _numberOfSecondsFromNow[index];
        installment.amount = _amount[index];
      }
    }

    numberOfInstallments[_tokenId] = _numberOfInstallments;

    emit UpdateBulkInstallment(_tokenId, _installment, _numberOfSecondsFromNow, _amount, _numberOfInstallments);
  }

  /**
   * @dev Make an installment payment for a token.
   * @param _installmentIndex The index of the installment to be paid
   * @param _tokenId The token ID
   */
  function payInstallment(uint256 _installmentIndex, uint256 _tokenId) public payable {
    Installment storage installment = installments[_tokenId][_installmentIndex];
    require(installment.isPaid == false, "HOC: Installment already paid");
    require(ownerOf(_tokenId) == _msgSender(), "HOC: Invalid owner");

    uint256 amount = msg.value;
    uint256 panelty;

    if (block.timestamp > installment.dueDate) {
      panelty = (installment.amount * dueDatePaneltyPercentage) / 100;
    }
    if (isNativePayment) {
      require(amount >= installment.amount + panelty, "HOC: Invalid Amount");
    } else {
      token.transferFrom(_msgSender(), address(this), installment.amount + panelty);
    }
    totalAmountPaid[_tokenId] = totalAmountPaid[_tokenId] + amount - panelty;

    installment.isPaid = true;

    emit InstallmentPaid(_tokenId, _installmentIndex, amount, panelty);
    uint256 t = typeIds[_tokenId];

    if (totalAmountPaid[_tokenId] >= defaultTotalAmount[t]) {
      isFullyPaid[_tokenId] = true;

      emit AllInstalmentsPaid(_tokenId);
    }
  }

  /**
   * @notice Activate Opensea proxy for emergency cases
   * @dev This function is only callable by an DEVELOPER
   * @param _proxyRegistryAddress Address of the Opensea proxy registry
   * @param _isOpenSeaProxyActive True to activate the Opensea proxy, false otherwise
   */
  function activeOpenseaProxy(
    address _proxyRegistryAddress,
    bool _isOpenSeaProxyActive
  ) external onlyRole(DEVELOPER_ROLE) {
    proxyRegistryAddress = _proxyRegistryAddress;
    isOpenSeaProxyActive = _isOpenSeaProxyActive;
  }

  /**
   * @dev Mint a new NFT token.
   * @param _to Address of the token owner
   * @param _id Token ID
   * @param _type Token type
   * @param _updateInstallment True to update installments for the token, false otherwise
   */
  function mint(
    address _to,
    uint256 _id,
    string memory _tokenURI,
    uint256 _type,
    bool _updateInstallment
  ) external override onlyRole(MINTER_ROLE) {
    _mint(_to, _id);
    _setTokenURI(_id, _tokenURI);

    typeIds[_id] = _type;

    if (_updateInstallment == true) {
      for (uint256 index; index < defaultNumberOfInstallments[_type]; index++) {
        Installment memory defaultInstallment = defaultInstallments[_type][index + 1];
        Installment storage installment = installments[_id][index + 1];

        installment.dueDate = defaultInstallment.dueDate + block.timestamp;
        installment.amount = defaultInstallment.amount;
      }
    }
    numberOfInstallments[_id] = defaultNumberOfInstallments[_type];
  }

  /**
   * @notice Burn an NFT token.
   * @dev This function is only callable by the token owner.
   * @param _tokenId The token ID to be burned
   */
  function burn(uint256 _tokenId) external override {
    require(ownerOf(_tokenId) == _msgSender(), "HOC: Invalid owner");
    _burn(_tokenId);
  }

  /**
   * @dev Get the ownership timestamp for a token.
   * @param _tokenId The token ID
   * @return The ownership timestamp of the token
   */
  function getOwnTime(uint256 _tokenId) external view returns (uint256) {
    return ownTime[_tokenId];
  }

  /**
   * @dev Checks if an operator is approved for all tokens of a particular owner.
   * @param _account The address of the token owner
   * @param _operator The address of the operator
   * @return True if the operator is approved for all tokens, false otherwise
   */
  function isApprovedForAll(address _account, address _operator) public view override returns (bool) {
    ProxyRegistry proxyRegistry = ProxyRegistry(proxyRegistryAddress);
    if (isOpenSeaProxyActive && address(proxyRegistry.proxies(_account)) == _operator) {
      return true;
    }

    return hasRole(APPROVER_ROLE, _operator) || super.isApprovedForAll(_account, _operator);
  }

  /**
   * @dev Overrides the transfer function of ERC721 to update the ownership timestamp.
   * @param _from The current owner of the token
   * @param _to The address to transfer the token ownership to
   * @param _tokenId The token ID
   */
  function _transfer(address _from, address _to, uint256 _tokenId) internal override {
    ownTime[_tokenId] = block.timestamp;
    super._transfer(_from, _to, _tokenId);
  }

  /**
   * @dev Overrides the mint function of ERC721 to update the ownership timestamp and type ID.
   * @param _to The address to mint the token for
   * @param _tokenId The token ID to mint
   */
  function _mint(address _to, uint256 _tokenId) internal override {
    creators[_tokenId] = _to;
    ownTime[_tokenId] = block.timestamp;
    super._mint(_to, _tokenId);
  }

  /**
   * @dev Overrides the burn function of ERC721 to update the ownership timestamp.
   * @param _pTokenId The ID of the token to burn
   */
  function _burn(uint256 _pTokenId) internal override {
    ownTime[_pTokenId] = block.timestamp;
    super._burn(_pTokenId);
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
}
