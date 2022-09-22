// SPDX-License-Identifier: MIT
pragma solidity 0.8.2;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/MerkleProofUpgradeable.sol";
import "./AntGold.sol";
import "./Suga.sol";
import "./AntBosses.sol";

interface AvalantBoxes {
    function ownerOf(uint256 tokenId) external view returns (address owner);
}

contract Avalant is Initializable, ERC721Upgradeable, ERC721EnumerableUpgradeable, AccessControlUpgradeable {
    bytes4 private constant _INTERFACE_ID_ERC2981 = 0x2a55205a;
    address public AVALANT_BOXES_CONTRACT;
    address public ANTG_CONTRACT;
    address public SUGA_CONTRACT;
    address public BOSSES_CONTRACT;

    // Whitelist
    bytes32 private merkleRoot;
    mapping(address => uint) public boughtByWL;
    mapping(address => bool) public lateWhitelisted;
    uint public presaleRestrictedNumber;
    uint public quantityMintedByWLs;
    uint public constant MAX_SUPPLY_PRESALE = 2500;

    string public baseURI;
    address public royaltiesAddr;
    uint public royaltyFees;

    uint public constant MAX_SUPPLY = 10000;
    bool public openForPresale;
    bool public openForPublic;
    uint public mintFeeAmountWL;
    uint public mintFeeAmount;
    mapping(uint => bool) public alreadyOpenedBoxes;

    uint public feesToChangeName;

    struct Ant {
        uint tokenId;
        address pickedBy;
        uint colonyStage;
        string name;
        uint restUntil;
    }

    // map tokenId to Avalant struct
    mapping(uint => Ant) public allAvalants;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    // --- EVENTS
    event OpenBox(uint boxId, uint numberOfAnts);
    event NameChange(uint antId, string name);
    event AntDug(uint antId, uint colonyStage);

    // VERSION 1.2
    // a => b, a is the antId, b is 0, 1, 2, 3, 4, 5 or 6
    // 5 is mythical, 4 is legendary, 3 is epic, 2 is rare, 1 is uncommon
    // 6 is unique
    mapping(uint => uint) public antRarity;

    function initialize(
        address _royaltiesAddr,
        address _avalantBoxesContractAddr,
        string memory _baseURIMetadata,
        bytes32 _merkleRoot,
        uint _presaleRestrictedNumber, // 5 at first 10 after an hour
        uint _royaltyFees // 5%
    ) public initializer {
        __ERC721_init("Avalant", "ANT");
        __ERC721Enumerable_init();
        __AccessControl_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);

        openForPresale = false;
        openForPublic = false;
        mintFeeAmountWL = 0.8 ether;
        mintFeeAmount = 1.2 ether;
        feesToChangeName = 500 ether; // 500 ANTG
        AVALANT_BOXES_CONTRACT = _avalantBoxesContractAddr;
        royaltiesAddr = _royaltiesAddr;
        baseURI = _baseURIMetadata;
        merkleRoot = _merkleRoot;
        presaleRestrictedNumber = _presaleRestrictedNumber;
        royaltyFees = _royaltyFees;
    }

    // <MintStuff>
    function isOpenBox(uint tokenId) public view returns (bool) {
        return alreadyOpenedBoxes[tokenId];
    }

    function openBox(uint boxTokenId) public {
        require(openForPresale == true || openForPublic == true, "Cannot open yet");
        AvalantBoxes ab = AvalantBoxes(AVALANT_BOXES_CONTRACT);
        address ownerOfBox = ab.ownerOf(boxTokenId);
        require(ownerOfBox == msg.sender, "Its not your box");
        require(alreadyOpenedBoxes[boxTokenId] != true, "Box already opened");
        alreadyOpenedBoxes[boxTokenId] = true;
        uint antToGive = 2;
        if (boxTokenId >= 900) antToGive = 3;
        if (boxTokenId < 600) antToGive = 1;
        require(totalSupply() + antToGive <= MAX_SUPPLY, "Ant escaped the box, sorry");
        for (uint i = 1; i <= antToGive; i++) {
            _mint(msg.sender);
        }
        emit OpenBox(boxTokenId, antToGive);
    }

    function _mint(address to) private {
        uint nextTokenId = totalSupply();
        Ant memory newAnt = Ant(nextTokenId, to, 1, string(abi.encodePacked("Ant #", StringsUpgradeable.toString(nextTokenId))), 0);
        allAvalants[nextTokenId] = newAnt;
        _safeMint(to, nextTokenId);
    }

    // <Whitelist Stuff>
    function _isWhitelist(address account, bytes32[] calldata proof) internal view returns(bool) {
        bytes32 leaf = keccak256(abi.encodePacked(account));
        if (MerkleProofUpgradeable.verify(proof, merkleRoot, leaf)) {
            return true;
        }
        if (lateWhitelisted[account] == true) {
            return true;
        }
        return false;
    }

    function isWhitelisted(address account, bytes32[] calldata proof) public view returns(bool) {
        return _isWhitelist(account, proof);
    }

    function pickAntsWhitelist(uint numberOfAnts, bytes32[] calldata proof) external payable {
        require(openForPresale == true, "Whitelist sale is not open");
        require(_isWhitelist(msg.sender, proof), "Not whitelisted");
        require(quantityMintedByWLs + numberOfAnts <= MAX_SUPPLY_PRESALE, "Presale supply is full");
        require(boughtByWL[msg.sender] + numberOfAnts <= presaleRestrictedNumber, "Too many ants");

        boughtByWL[msg.sender] += numberOfAnts;
        uint price = mintFeeAmountWL * numberOfAnts;
        require(msg.value >= price, "Not enough avax");

        for (uint i = 1; i <= numberOfAnts; i++) {
            quantityMintedByWLs += 1;
            _mint(msg.sender);
        }
        (bool sent,) = payable(royaltiesAddr).call{value: msg.value}("");
        require(sent, "Failed to pay royalties");
    }
    // </Whitelist Stuff>

    function pickAnts(uint numberOfAnts) external payable {
        require(openForPublic == true, "Sale is not open");
        require(numberOfAnts <= 10, "Trying to buy too many ants");
        require(totalSupply() + numberOfAnts <= MAX_SUPPLY, "Ants supply is full");

        uint price = mintFeeAmount * numberOfAnts;
        require(msg.value >= price, "Not enough avax");

        for (uint i = 1; i <= numberOfAnts; i++) {
            _mint(msg.sender);
        }
        (bool sent,) = payable(royaltiesAddr).call{value: msg.value}("");
        require(sent, "Failed to pay royalties");
    }
    // </MintStuff>

    function changeName(uint _tokenId, string memory newName) external {
        require(address(ANTG_CONTRACT) != address(0), "Change name not open yet");
        address ownerOfAnt = ownerOf(_tokenId);
        // backdoor to change name in case of racism or something
        require(ownerOfAnt == msg.sender || hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Not ur ant");
        AntGold ag = AntGold(ANTG_CONTRACT);
        uint256 available = ag.balanceOf(msg.sender);
        require(available >= feesToChangeName, "Not enough ANTG");
        ag.burn(msg.sender, feesToChangeName);
        allAvalants[_tokenId].name = newName;
        emit NameChange(_tokenId, newName);
    }

    function dig(uint _tokenId) public {
        require(ownerOf(_tokenId) == msg.sender, "Not ur ant");
        require(block.timestamp >= allAvalants[_tokenId].restUntil, "Ant is too tired to dig");
        AntBosses b = AntBosses(BOSSES_CONTRACT);
        require(b.isBossAliveAtStage(allAvalants[_tokenId].colonyStage) == false, "Blocked by boss");
        uint currentStage = allAvalants[_tokenId].colonyStage;
        uint sugarToDig = (currentStage**2 * 20) * 1e18;

        Suga s = Suga(SUGA_CONTRACT);
        // if not enough suga, it will fail inside
        s.burn(msg.sender, sugarToDig);
        AntGold ag = AntGold(ANTG_CONTRACT);
        uint[] memory tmp = new uint[](1);
        tmp[0] = _tokenId;
        ag.claimAntGold(tmp);
        allAvalants[_tokenId].colonyStage += 1;
        // Digging into stage 2 will require 2 hours of resting
        allAvalants[_tokenId].restUntil = block.timestamp + 60*60*(currentStage + 1);
        emit AntDug(_tokenId, allAvalants[_tokenId].colonyStage);
    }

    function digMultipleAnts(uint[] calldata _tokenIds) public {
        for (uint i = 0; i < _tokenIds.length; i++) {
            dig(_tokenIds[i]);
        }
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721Upgradeable)
        returns (string memory)
    {
        require(_exists(tokenId), "URI query for nonexistent token");
        return string(abi.encodePacked(baseURI, StringsUpgradeable.toString(tokenId), ".json"));
    }

    // <AdminStuff>
    function setMintPrice(uint _publicPrice, uint _wlPrice) public onlyRole(DEFAULT_ADMIN_ROLE) {
        mintFeeAmount = _publicPrice;
        mintFeeAmountWL = _wlPrice;
    }

    function setPresaleRestrictedNumber(uint _presaleRestrictedNumber) public onlyRole(DEFAULT_ADMIN_ROLE) {
        presaleRestrictedNumber = _presaleRestrictedNumber;
    }

    function openPublic(bool _open) public onlyRole(DEFAULT_ADMIN_ROLE) {
        openForPublic = _open;
    }

    function openPresale(bool _open) public onlyRole(DEFAULT_ADMIN_ROLE) {
        openForPresale = _open;
    }

    function setBaseURI(string memory newURI) public onlyRole(DEFAULT_ADMIN_ROLE) {
        baseURI = newURI;
    }

    function setRoyaltyFees(uint _royaltyFees) public onlyRole(DEFAULT_ADMIN_ROLE) {
        royaltyFees = _royaltyFees;
    }

    function addLateWhitelist(address _account) public onlyRole(DEFAULT_ADMIN_ROLE) {
        lateWhitelisted[_account] = true;
    }

    function setContractAddresses(address _antGoldContract, address _sugaContract, address _bossesContract) public onlyRole(DEFAULT_ADMIN_ROLE) {
        ANTG_CONTRACT = _antGoldContract;
        SUGA_CONTRACT = _sugaContract;
        BOSSES_CONTRACT = _bossesContract;
    }

    function updateMerkleRoot(bytes32 _merkleRoot) external onlyRole(DEFAULT_ADMIN_ROLE) {
        merkleRoot = _merkleRoot;
    }

    function changeRoyaltyAddress(address _royaltiesAddress) external onlyRole(DEFAULT_ADMIN_ROLE) {
        royaltiesAddr = _royaltiesAddress;
    }

    function changeFeeToChangeName(uint _feesToChangeName) external onlyRole(DEFAULT_ADMIN_ROLE) {
        feesToChangeName = _feesToChangeName;
    }

    function setAntsRarity(uint _rarity, uint[] calldata _antIds) external onlyRole(DEFAULT_ADMIN_ROLE) {
        for (uint i = 0; i < _antIds.length; i++) {
            antRarity[_antIds[i]] = _rarity;
        }
    }
    // </AdminStuff>

    function royaltyInfo(uint256, uint256 _salePrice) external view returns (address receiver, uint256 royaltyAmount) {
        return (royaltiesAddr, _salePrice * royaltyFees / 100);
    }

    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId)
        internal
        override(ERC721Upgradeable, ERC721EnumerableUpgradeable)
    {
        if (address(ANTG_CONTRACT) != address(0) && address(from) != address(0)) {
            AntGold ag = AntGold(ANTG_CONTRACT);
            ag.unstakeAntWithoutClaim(tokenId);
        }
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721Upgradeable, ERC721EnumerableUpgradeable, AccessControlUpgradeable)
        returns (bool)
    {
        if (interfaceId == _INTERFACE_ID_ERC2981) {
            return true;
        }
        return super.supportsInterface(interfaceId);
    }
}