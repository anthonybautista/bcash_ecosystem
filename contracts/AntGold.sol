// SPDX-License-Identifier: MIT
pragma solidity 0.8.2;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./Avalant.sol";

contract AntGold is Initializable, ERC20Upgradeable, AccessControlUpgradeable {
    // Suga, boss, avalant contracts addresses
    bytes32 public constant ANT_CONTRACTS_ROLE = keccak256("ANT_CONTRACTS_ROLE");

    address public AVALANT_CONTRACT;
    address public SUGA_CONTRACT;
    uint public BASE_ANTG_BY_ANT_PER_DAY;
    uint public BASE_ANTG_BY_ANT_PER_DAY_PER_STAGE;

    mapping(uint => bool) public antStaked;
    // ant staked from timestamp
    mapping(uint => uint) public antStakedFromTime;
    mapping(uint => uint) private antLastClaim;
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    event Minted(address minter, uint antGold);

    function initialize(
        address _avalantContract,
        uint _baseAntgByAnt, // 7.5 so 7500000000000000000
        uint _baseAntgByAntByStage // 2.5 so 2500000000000000000
    ) initializer public {
        __ERC20_init("AntGold", "ANTG");
        __AccessControl_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ANT_CONTRACTS_ROLE, _avalantContract);
        AVALANT_CONTRACT = _avalantContract;
        BASE_ANTG_BY_ANT_PER_DAY = _baseAntgByAnt;
        BASE_ANTG_BY_ANT_PER_DAY_PER_STAGE = _baseAntgByAntByStage;
    }

    function claimableView(uint256 tokenId) public view returns (uint) {
        Avalant a = Avalant(AVALANT_CONTRACT);
        (,,uint colonyStage,,) = a.allAvalants(tokenId);
        if (antStaked[tokenId] == false) {
            return 0;
        } else {
            uint goldPerDay = ((BASE_ANTG_BY_ANT_PER_DAY_PER_STAGE * colonyStage) +
                BASE_ANTG_BY_ANT_PER_DAY);
            uint deltaSeconds = block.timestamp - antLastClaim[tokenId];
            // 10% additional if ant is staked for 10 days
            if (block.timestamp - antStakedFromTime[tokenId] >= 864000) {
                return goldPerDay * deltaSeconds / 86400 * 105 / 100;
            }
            return deltaSeconds * (goldPerDay / 86400);
        }
    }

    function myClaimableView() public view returns (uint) {
        Avalant a = Avalant(AVALANT_CONTRACT);
        uint ants = a.balanceOf(msg.sender);
        if (ants == 0) return 0;
        uint totalClaimable = 0;
        for (uint i = 0; i < ants; i++) {
            uint tokenId = a.tokenOfOwnerByIndex(msg.sender, i);
            totalClaimable += claimableView(tokenId);
        }
        return totalClaimable;
    }

    function claimAntGold(uint[] calldata tokenIds) external {
        Avalant a = Avalant(AVALANT_CONTRACT);
        uint totalNewAntg = 0;
        // if it fails its ok, empty array not authorized
        address ownerOfAnt = a.ownerOf(tokenIds[0]);
        for (uint i = 0; i < tokenIds.length; i++) {
            require(a.ownerOf(tokenIds[i]) == msg.sender || hasRole(ANT_CONTRACTS_ROLE, msg.sender), "Not ur ant");
            uint claimableAntGold = claimableView(tokenIds[i]);
            if (claimableAntGold > 0) {
                totalNewAntg += claimableAntGold;
                antLastClaim[tokenIds[i]] = uint(block.timestamp);
            }
        }
        if (totalNewAntg > 0) {
            _mint(ownerOfAnt, totalNewAntg);
            emit Minted(ownerOfAnt, totalNewAntg);
        }
    }

    function stakeAnt(uint tokenId) public {
        Avalant a = Avalant(AVALANT_CONTRACT);
        require(a.ownerOf(tokenId) == msg.sender, "Not ur ant");
        require(antStaked[tokenId] == false, "Already staked");
        antStaked[tokenId] = true;
        antStakedFromTime[tokenId] = block.timestamp;
        antLastClaim[tokenId] = block.timestamp;
    }

    function stakeAnts(uint[] calldata tokenIds) external {
        for (uint i = 0; i < tokenIds.length; i++) {
            stakeAnt(tokenIds[i]);
        }
    }

    function unstakeAntWithoutClaim(uint tokenId) external {
        Avalant a = Avalant(AVALANT_CONTRACT);
        address ownerOfAnt = a.ownerOf(tokenId);
        require(ownerOfAnt == msg.sender || hasRole(ANT_CONTRACTS_ROLE, msg.sender), "Not ur ant");

        antStaked[tokenId] = false;
    }

    function burn(address acc, uint amount) public onlyRole(ANT_CONTRACTS_ROLE) {
        _burn(acc, amount);
    }

    function mint(address to, uint amount) public {
        require(hasRole(ANT_CONTRACTS_ROLE, msg.sender) || hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Not authorized");
        _mint(to, amount);
    }

    function setSugaAddress(address _sugaAddress) public onlyRole(DEFAULT_ADMIN_ROLE) {
        if (SUGA_CONTRACT != address(0)) {
            _revokeRole(ANT_CONTRACTS_ROLE, SUGA_CONTRACT);
        }
        SUGA_CONTRACT = _sugaAddress;
        _grantRole(ANT_CONTRACTS_ROLE, _sugaAddress);
    }

    function airdrop(address[] calldata addresses, uint amount) public onlyRole(DEFAULT_ADMIN_ROLE) {
        for (uint i = 0; i < addresses.length; i++) {
            _mint(addresses[i], amount);
        }
    }
}
