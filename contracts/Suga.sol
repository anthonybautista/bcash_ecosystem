// SPDX-License-Identifier: MIT
pragma solidity 0.8.2;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./Avalant.sol";
import "./AntGold.sol";

contract Suga is Initializable, ERC20Upgradeable, AccessControlUpgradeable {
    bytes32 public constant ANT_CONTRACTS_ROLE = keccak256("ANT_CONTRACTS_ROLE");

    // Avalant needed to allow burning
    address public AVALANT_CONTRACT;
    // Antg needed to burn AntG
    address public ANTG_CONTRACT;
    // Bosses needed to allow burning Suga
    address public BOSSES_CONTRACT;
    // JLP Staking needed to allow for minting Suga
    address public JLP_STAKING_CONTRACT;

    uint public MAX_SUPPLY;
    uint public ANTG_RATIO;
    uint public ANTG_STAKE_DAY_RATIO;

    uint public totalAntgStaking;
    mapping(address => uint) public antgStaked;
    mapping(address => uint) private antgStakedFrom;

    // keeping them here so we can batch claim
    address[] public antgStakers;
    // index only useful for deleting user from array
    mapping(address => uint) private _stakerIndex;
    // same as Enumerable from openzeppelin

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    event AntGSwap(address swaper, uint antg);
    event UnstakedAntG(address staker, uint antg);
    event StakedAntG(address staker, uint antg);

    // Version 1.1
    mapping(address => bool) public whitelistTransfer;

    function initialize(
        address _avalantContract,
        address _antGContract,
        address _bossesContract,
        uint _maxSupply, // 25_000_000_000 SUGA (**18)
        uint _antGRatio, // 18
        uint _antGStakeDayRatio // 2
    ) initializer public {
        __ERC20_init("Sugar", "SUGA");
        __AccessControl_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ANT_CONTRACTS_ROLE, _avalantContract);
        _grantRole(ANT_CONTRACTS_ROLE, _antGContract);
        _grantRole(ANT_CONTRACTS_ROLE, _bossesContract);
        AVALANT_CONTRACT = _avalantContract;
        ANTG_CONTRACT = _antGContract;
        BOSSES_CONTRACT = _bossesContract;
        MAX_SUPPLY = _maxSupply;
        ANTG_RATIO = _antGRatio;
        ANTG_STAKE_DAY_RATIO = _antGStakeDayRatio;
    }

    function _mintSuga(address account, uint256 amount) internal {
        require(totalSupply() + amount <= MAX_SUPPLY, "Max supply reached");
        _mint(account, amount);
    }

    function mint(address account, uint256 amount) public onlyRole(ANT_CONTRACTS_ROLE) {
        _mintSuga(account, amount);
    }

    function swapAntGForSuga(uint amount) external {
        require(amount > 0, "Amount must be greater than 0");
        AntGold ag = AntGold(ANTG_CONTRACT);
        ag.burn(msg.sender, amount);
        _mintSuga(msg.sender, amount * ANTG_RATIO);
        emit AntGSwap(msg.sender, amount);
    }

    function claimableView(address account) public view returns(uint) {
        uint _antgStaked = antgStaked[account];
        // need to multiply by 10000000000 to get decimal during days
        return
            ((_antgStaked * ANTG_STAKE_DAY_RATIO) *
                ((block.timestamp - antgStakedFrom[account]) * 10000000000) / 86400) /
            10000000000;
    }

    function claimSuga() public {
        uint claimable = claimableView(msg.sender);
        if (claimable > 0) {
            antgStakedFrom[msg.sender] = block.timestamp;
            _mintSuga(msg.sender, claimable);
        }
    }

    function stakeAntg(uint amount) external {
        require(amount > 0, "Amount must be greater than 0");
        AntGold ag = AntGold(ANTG_CONTRACT);
        // we burn AntG from wallet, minting again on unstake
        // if not enough AntG it will fail in the AntG contract burn
        ag.burn(msg.sender, amount);
        claimSuga(); // atleast try, no harm in claimable 0
        totalAntgStaking += amount;
        if (antgStaked[msg.sender] == 0) { // first staking of user
            antgStakers.push(msg.sender);
            _stakerIndex[msg.sender] = antgStakers.length - 1;
        }
        antgStaked[msg.sender] += amount;
        antgStakedFrom[msg.sender] = block.timestamp;
        emit StakedAntG(msg.sender, amount);
    }

    function unstakeAntg(uint amount) external {
        require(amount > 0, "Amount must be greater than 0");
        require(antgStaked[msg.sender] >= amount, "Not enough AntG staked");
        claimSuga();
        antgStaked[msg.sender] -= amount;
        if (antgStaked[msg.sender] == 0) {
            _removeStaker(msg.sender);
        }
        totalAntgStaking -= amount;
        uint antgToMint = (amount * 9) / 10; // losing 10% at unstake
        AntGold ag = AntGold(ANTG_CONTRACT);
        ag.mint(msg.sender, antgToMint);
        emit UnstakedAntG(msg.sender, antgToMint);
    }

    function getAmountOfStakers() public view returns(uint) {
        return antgStakers.length;
    }

    function _removeStaker(address staker) internal {
        // https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC721/extensions/ERC721Enumerable.sol#L144
        uint stakerIndex = _stakerIndex[staker];
        uint lastStakerIndex = antgStakers.length - 1;
        address lastStaker = antgStakers[lastStakerIndex];
        antgStakers[stakerIndex] = lastStaker;
        _stakerIndex[lastStaker] = stakerIndex;
        delete _stakerIndex[staker];
        antgStakers.pop();
    }

    function burn(address acc, uint amount) public onlyRole(ANT_CONTRACTS_ROLE) {
        _burn(acc, amount);
    }

    // <AdminStuff>
    function updateRatios(uint _antGRatio, uint _antGStakeDayRatio) external onlyRole(DEFAULT_ADMIN_ROLE) {
        ANTG_RATIO = _antGRatio;
        ANTG_STAKE_DAY_RATIO = _antGStakeDayRatio;
    }

    function airdropSuga(address account, uint amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _mintSuga(account, amount);
    }

    function claimForPeople(uint256 from, uint256 to) external onlyRole(DEFAULT_ADMIN_ROLE) {
        for (uint256 i = from; i <= to; i++) {
            address account = antgStakers[i];
            uint claimable = claimableView(account);
            if (claimable > 0) {
                antgStakedFrom[account] = block.timestamp;
                _mintSuga(account, claimable);
            }
        }
    }

    function addWhitelistAddress(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        whitelistTransfer[account] = true;
    }
    // </AdminStuff>

    function transfer(address recipient, uint256 amount) public virtual override(ERC20Upgradeable) returns (bool) {
        // Preventing the SUGA trading until gen1
        require(whitelistTransfer[msg.sender] && whitelistTransfer[recipient], "No transfers allowed for the moment");
        return super.transfer(recipient, amount);
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public virtual override(ERC20Upgradeable) returns (bool) {
        // Preventing the SUGA trading until gen1
        require(whitelistTransfer[sender] && whitelistTransfer[recipient], "No transfers allowed for the moment");
        return super.transferFrom(sender, recipient, amount);
    }

    function setFarmRole(address _jlpStakingContract) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (JLP_STAKING_CONTRACT != address(0)) {
            _revokeRole(ANT_CONTRACTS_ROLE, JLP_STAKING_CONTRACT);
        }
        JLP_STAKING_CONTRACT = _jlpStakingContract;
        _grantRole(ANT_CONTRACTS_ROLE, _jlpStakingContract);
    }
}