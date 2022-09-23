// SPDX-License-Identifier: MIT
pragma solidity 0.8.2;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface ILP {
    function totalSupply() external view returns (uint256);
    function balanceOf(address owner) external view returns (uint256);
    function getReserves() external view returns (uint112, uint112, uint32);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
    function transfer(address to, uint256 value) external returns (bool);
}


interface IBCash {
	function mint(address _to, uint256 _amount) external;
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract bCashLPFarm is ReentrancyGuard, Ownable {

    // LP needed to calculate WAVAX
    address public LP_CONTRACT;
    // bCASH needed to mint rewards
    address public BCASH_CONTRACT;

    uint public LP_STAKE_DAY_RATIO = 40;
    uint public totalLPStaking;

    mapping(address => uint) public LPStaked;
    mapping(address => uint) public LPStakedFrom;

    // keeping them here so we can batch claim
    address[] public LPStakers;
    // index only useful for deleting user from array
    mapping(address => uint) private _stakerIndex;
    // same as Enumerable from openzeppelin

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address _lp, address _bc) {
        LP_CONTRACT = _lp;
        BCASH_CONTRACT = _bc;
    }

    event UnstakedLP(address staker, uint lp);
    event StakedLP(address staker, uint lp);

    function wavaxView(address account) public view returns(uint) {
        ILP lp = ILP(LP_CONTRACT);

        uint _lpSupply = lp.totalSupply();

        (,uint _reserveWavax,) = lp.getReserves();

        uint _lpStaked = LPStaked[account];

        uint _wavax = _lpStaked * _reserveWavax / _lpSupply;

        return _wavax;
    }

    function bCashView(address account) public view returns(uint) {
        ILP lp = ILP(LP_CONTRACT);

        uint _lpSupply = lp.totalSupply();

        (uint _reserveBCash,,) = lp.getReserves();

        uint _lpStaked = LPStaked[account];

        uint _bCash = _lpStaked * _reserveBCash / _lpSupply;

        return _bCash;
    }

    function totalView(address account) public view returns(uint, uint, uint) {
        return (wavaxView(account), bCashView(account), claimableView(account));
    }


    function claimableView(address account) public view returns(uint) {

        uint _wavax = wavaxView(account);

        // divide ratio by 10 to allow for decimal
        // need to multiply by 10000000000 to get decimal during days
        return
            (((_wavax * LP_STAKE_DAY_RATIO / 10) *
                ((block.timestamp - LPStakedFrom[account]) * 10000000000) / 86400) /
            10000000000) / 10**18;
    }

    function claimBCash() public nonReentrant {
        _claim(msg.sender);
    }

    function stakeLP(uint amount) external {
        require(amount > 0, "Amount must be greater than 0");
        ILP lp = ILP(LP_CONTRACT);
        // we transfer LP tokens from the caller to the contract
        // if not enough LP it will fail in the LP contract transferFrom
        lp.transferFrom(msg.sender, address(this), amount);
        claimBCash(); // atleast try, no harm in claimable 0
        totalLPStaking += amount;
        if (LPStaked[msg.sender] == 0) { // first staking of user
            LPStakers.push(msg.sender);
            _stakerIndex[msg.sender] = LPStakers.length - 1;
        }
        LPStaked[msg.sender] += amount;
        LPStakedFrom[msg.sender] = block.timestamp;
        emit StakedLP(msg.sender, amount);
    }

    function unstakeLP(uint amount) external nonReentrant {
        require(amount > 0, "Amount must be greater than 0");
        require(LPStaked[msg.sender] >= amount, "Not enough LP staked");
        
        // nonReentrant requires claim to be an internal function
        _claim(msg.sender);
        
        LPStaked[msg.sender] -= amount;
        if (LPStaked[msg.sender] == 0) {
            _removeStaker(msg.sender);
        }
        totalLPStaking -= amount;
        
        ILP lp = ILP(LP_CONTRACT);
        lp.transfer(msg.sender, amount);
        emit UnstakedLP(msg.sender, amount);
    }

    function _claim(address account) internal {
        uint claimable = claimableView(account);
        if (claimable > 0) {
            IBCash bc = IBCash(BCASH_CONTRACT);
            LPStakedFrom[account] = block.timestamp;
            bc.mint(account, claimable);
        }
    }

    function getAmountOfStakers() public view returns(uint) {
        return LPStakers.length;
    }

    function _removeStaker(address staker) internal {
        // https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC721/extensions/ERC721Enumerable.sol#L144
        uint stakerIndex = _stakerIndex[staker];
        uint lastStakerIndex = LPStakers.length - 1;
        address lastStaker = LPStakers[lastStakerIndex];
        LPStakers[stakerIndex] = lastStaker;
        _stakerIndex[lastStaker] = stakerIndex;
        delete _stakerIndex[staker];
        LPStakers.pop();
    }

    // <AdminStuff>
    function updateRatio(uint _lpStakeDayRatio) external onlyOwner {
        LP_STAKE_DAY_RATIO = _lpStakeDayRatio;
    }

    function claimForPeople(uint256 from, uint256 to) external onlyOwner {
        for (uint256 i = from; i <= to; i++) {
            address account = LPStakers[i];
            uint claimable = claimableView(account);
            if (claimable > 0) {
                IBCash bc = IBCash(BCASH_CONTRACT);
                LPStakedFrom[account] = block.timestamp;
                bc.mint(account, claimable);
            }
        }
    }

}