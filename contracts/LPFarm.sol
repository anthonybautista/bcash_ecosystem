// SPDX-License-Identifier: MIT
// bCASH LP Farm by xrpant modified from Avalant LP Farm 


// File: @openzeppelin/contracts/utils/Context.sol
// OpenZeppelin Contracts v4.4.1 (utils/Context.sol)

pragma solidity ^0.8.0;

/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

// File: @openzeppelin/contracts/access/Ownable.sol


// OpenZeppelin Contracts (last updated v4.7.0) (access/Ownable.sol)

pragma solidity ^0.8.0;


/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
        _transferOwnership(_msgSender());
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if the sender is not the owner.
     */
    function _checkOwner() internal view virtual {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

// File: @openzeppelin/contracts/security/ReentrancyGuard.sol


// OpenZeppelin Contracts v4.4.1 (security/ReentrancyGuard.sol)

pragma solidity ^0.8.0;

/**
 * @dev Contract module that helps prevent reentrant calls to a function.
 *
 * Inheriting from `ReentrancyGuard` will make the {nonReentrant} modifier
 * available, which can be applied to functions to make sure there are no nested
 * (reentrant) calls to them.
 *
 * Note that because there is a single `nonReentrant` guard, functions marked as
 * `nonReentrant` may not call one another. This can be worked around by making
 * those functions `private`, and then adding `external` `nonReentrant` entry
 * points to them.
 *
 * TIP: If you would like to learn more about reentrancy and alternative ways
 * to protect against it, check out our blog post
 * https://blog.openzeppelin.com/reentrancy-after-istanbul/[Reentrancy After Istanbul].
 */
abstract contract ReentrancyGuard {
    // Booleans are more expensive than uint256 or any type that takes up a full
    // word because each write operation emits an extra SLOAD to first read the
    // slot's contents, replace the bits taken up by the boolean, and then write
    // back. This is the compiler's defense against contract upgrades and
    // pointer aliasing, and it cannot be disabled.

    // The values being non-zero value makes deployment a bit more expensive,
    // but in exchange the refund on every call to nonReentrant will be lower in
    // amount. Since refunds are capped to a percentage of the total
    // transaction's gas, it is best to keep them low in cases like this one, to
    // increase the likelihood of the full refund coming into effect.
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private _status;

    constructor() {
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and making it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        // On the first call to nonReentrant, _notEntered will be true
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");

        // Any calls to nonReentrant after this point will fail
        _status = _ENTERED;

        _;

        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = _NOT_ENTERED;
    }
}

// File: @openzeppelin/contracts/utils/math/SafeMath.sol


// OpenZeppelin Contracts (last updated v4.6.0) (utils/math/SafeMath.sol)

pragma solidity ^0.8.0;

// CAUTION
// This version of SafeMath should only be used with Solidity 0.8 or later,
// because it relies on the compiler's built in overflow checks.

/**
 * @dev Wrappers over Solidity's arithmetic operations.
 *
 * NOTE: `SafeMath` is generally not needed starting with Solidity 0.8, since the compiler
 * now has built in overflow checking.
 */
library SafeMath {
    /**
     * @dev Returns the addition of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryAdd(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            uint256 c = a + b;
            if (c < a) return (false, 0);
            return (true, c);
        }
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function trySub(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b > a) return (false, 0);
            return (true, a - b);
        }
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryMul(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
            // benefit is lost if 'b' is also tested.
            // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
            if (a == 0) return (true, 0);
            uint256 c = a * b;
            if (c / a != b) return (false, 0);
            return (true, c);
        }
    }

    /**
     * @dev Returns the division of two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryDiv(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a / b);
        }
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryMod(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a % b);
        }
    }

    /**
     * @dev Returns the addition of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
     *
     * - Addition cannot overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        return a + b;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return a - b;
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `*` operator.
     *
     * Requirements:
     *
     * - Multiplication cannot overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        return a * b;
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator.
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return a / b;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * reverting when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return a % b;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting with custom message on
     * overflow (when the result is negative).
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {trySub}.
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b <= a, errorMessage);
            return a - b;
        }
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting with custom message on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b > 0, errorMessage);
            return a / b;
        }
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * reverting with custom message when dividing by zero.
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {tryMod}.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b > 0, errorMessage);
            return a % b;
        }
    }
}

// File: contracts/LPFarm.sol


pragma solidity 0.8.2;




interface ILP {
    function totalSupply() external view returns (uint256);
    function balanceOf(address owner) external view returns (uint256);
    function getReserves() external view returns (uint112, uint112, uint32);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
    function transfer(address to, uint256 value) external returns (bool);
}


interface IBCash {
	function mintBatch(address[] calldata _to, uint256[] calldata _amount) external;
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract bCashLPFarm is ReentrancyGuard, Ownable {

    // LP needed to calculate WAVAX
    address public LP_CONTRACT;
    // bCASH needed to mint rewards
    address public BCASH_CONTRACT;

    uint public LP_STAKE_DAY_RATIO = 300;
    uint public totalLPStaking;

    mapping(address => uint) public LPStaked;
    mapping(address => uint) public LPStakedFrom;

    // keeping them here so we can batch claim
    address[] public LPStakers;

    address[] _mintAddressArray;
    uint256[] _mintAmountArray;

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
                ((block.timestamp - LPStakedFrom[account]) * 10000000000) / 86400) / 10000000000);
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
            _mintAddressArray.push(account);
            _mintAmountArray.push(claimable);
            bc.mintBatch(_mintAddressArray, _mintAmountArray);
            delete _mintAddressArray;
            delete _mintAmountArray;
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
                LPStakedFrom[account] = block.timestamp;
                _mintAddressArray.push(account);
                _mintAmountArray.push(claimable);
            }
        }
        IBCash bc = IBCash(BCASH_CONTRACT);
        bc.mintBatch(_mintAddressArray, _mintAmountArray);
        delete _mintAddressArray;
        delete _mintAmountArray;
    }

}