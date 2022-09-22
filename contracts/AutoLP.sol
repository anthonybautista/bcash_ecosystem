// SPDX-License-Identifier: MIT
// Butterfly Cash Locker by moonbags (mostly) & xrpant (smol)

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

// File: @openzeppelin/contracts/token/ERC20/IERC20.sol


// OpenZeppelin Contracts (last updated v4.6.0) (token/ERC20/IERC20.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `from` to `to` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
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

pragma solidity ^0.8.0;

interface IJoeRouter01 {
    function factory() external pure returns (address);

    function WAVAX() external pure returns (address);

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    )
        external
        returns (
            uint256 amountA,
            uint256 amountB,
            uint256 liquidity
        );

    function addLiquidityAVAX(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountAVAXMin,
        address to,
        uint256 deadline
    )
        external
        payable
        returns (
            uint256 amountToken,
            uint256 amountAVAX,
            uint256 liquidity
        );

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB);

    function removeLiquidityAVAX(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountAVAXMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountToken, uint256 amountAVAX);

    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256 amountA, uint256 amountB);

    function removeLiquidityAVAXWithPermit(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountAVAXMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256 amountToken, uint256 amountAVAX);

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapTokensForExactTokens(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapExactAVAXForTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable returns (uint256[] memory amounts);

    function swapTokensForExactAVAX(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapExactTokensForAVAX(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapAVAXForExactTokens(
        uint256 amountOut,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable returns (uint256[] memory amounts);

    function quote(
        uint256 amountA,
        uint256 reserveA,
        uint256 reserveB
    ) external pure returns (uint256 amountB);

    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) external pure returns (uint256 amountOut);

    function getAmountIn(
        uint256 amountOut,
        uint256 reserveIn,
        uint256 reserveOut
    ) external pure returns (uint256 amountIn);

    function getAmountsOut(uint256 amountIn, address[] calldata path)
        external
        view
        returns (uint256[] memory amounts);

    function getAmountsIn(uint256 amountOut, address[] calldata path)
        external
        view
        returns (uint256[] memory amounts);
}

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
    function transfer(address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
}

contract BCashAutoLP is ReentrancyGuard, Ownable {

    mapping(address => TimeLock) public addressToLocker;
    mapping(address => uint256) public addressToIndex;
    address[] _lockedAccounts;
    address[] _mintAddressArray;

    uint256 private _totalAvaxDeposited;
    uint256 private _totalLPLocked;
    uint256 public lockTime = 300;
    uint256[] private _mintAmountArray;

    struct TimeLock {
        uint256 avaxDeposited;
        uint256 lpLocked;
        uint256 timestamp;
    }

    event LPLocked(address indexed holder, uint256 amountLP, uint256 amountAvax);
    event LPReleased(address indexed holder, uint256 amountLP);

    IBCash _bc;
    ILP _lp; 
    IJoeRouter01 _router;

    constructor(address bcashAddress, address lp) {
        _bc = IBCash(bcashAddress);
        _lp = ILP(lp);
        _router = IJoeRouter01(0x60aE616a2155Ee3d9A68541Ba4544862310933d4);
        _mintAddressArray.push(address(this));
    }

    function deposit() public payable nonReentrant {
        // only allow over X amount to be locked
        require(msg.value >= 0.01 ether, "Must deposit at least 1 AVAX.");

        TimeLock memory _locker;

        _locker.avaxDeposited = msg.value;

        // get LP reserves and find the required bCASH amount to add liquidity
        (uint256 _bcReserves, uint256 _wavaxReserves,) = _lp.getReserves();
        uint256 _bcNeeded = ((_bcReserves / _wavaxReserves) * 10**18) * msg.value / 10**18;

        // mint bCASH 
        _mintAmountArray.push(_bcNeeded);
        _bc.mintBatch(_mintAddressArray, _mintAmountArray);
        delete _mintAmountArray;

        // get before balance of LP tokens
        uint256 _beforeLP = _lp.balanceOf(address(this));

        // approve token transfer to cover all possible scenarios
        _bc.approve(address(_router), _bcNeeded);

        // add liquidity
        // add the liquidity
        (, 
         uint256 amountAVAX,) = _router.addLiquidityAVAX{value: msg.value}(
                                address(_bc),
                                _bcNeeded,
                                0, // slippage is unavoidable
                                0, // slippage is unavoidable
                                address(this),
                                block.timestamp + 1800 // need to give time buffer
                              );

        if (amountAVAX > msg.value) {
            payable(msg.sender).call{ value: msg.value - amountAVAX }("");
        }                      

        // get after balance of LP tokens
        uint256 _afterLP = _lp.balanceOf(address(this));

        // get new LP added
        uint256 _lpAdded = _afterLP - _beforeLP;

        _locker.lpLocked = _lpAdded;
        _locker.timestamp = block.timestamp;

        addressToIndex[msg.sender] = _lockedAccounts.length;
        addressToLocker[msg.sender] = _locker;
        _lockedAccounts.push(msg.sender);

        _totalAvaxDeposited += msg.value;
        _totalLPLocked += _lpAdded;

        emit LPLocked(msg.sender, _lpAdded, msg.value);
    }

    function amountLockedFor(address _holder) public view returns (uint256) {
        return addressToLocker[_holder].lpLocked;
    }

    function totalAvaxDeposited() public view returns (uint256) {
        return _totalAvaxDeposited;
    }

    function totalLPLocked() public view returns (uint256) {
        return _totalLPLocked;
    }

    function totalAccountsLocked() public view returns (uint256) {
        return _lockedAccounts.length;
    }

    function timeUntilUnlockedFor(address _holder) public view returns (uint256) {
        TimeLock memory _locker = addressToLocker[_holder];
        if (_locker.timestamp + lockTime < block.timestamp) {
            return 0;
        } else {
            return (_locker.timestamp + lockTime) - block.timestamp;
        }
    }

    function claim() public nonReentrant {
        require(addressToLocker[msg.sender].lpLocked > 0 &&
                timeUntilUnlockedFor(msg.sender) == 0, "Nothing to claim!");

        TimeLock storage _locker = addressToLocker[msg.sender];

        uint256 _claimable = _locker.lpLocked;

        _locker.lpLocked = 0;
        _locker.avaxDeposited = 0;
        _locker.timestamp = 0;

        // transfer claimable
        _lp.transfer(msg.sender, _claimable);

        // claimable should never be gt amount locked, but just in case, prevent less than 0 errors
        if (_totalLPLocked > _claimable) {
            _totalLPLocked -= _claimable;
        } else {
            _totalLPLocked = 0;
        }

        remove(msg.sender);

        emit LPReleased(msg.sender, _claimable);
    }

    function remove(address _account) private {
        uint256 _index = addressToIndex[_account];
        _lockedAccounts[_index] = _lockedAccounts[_lockedAccounts.length - 1];

        delete addressToIndex[_account];
        _lockedAccounts.pop();
    }

    function lockedAccounts() public view returns (address[] memory) {
        return _lockedAccounts;
    }

    function amountClaimableFor(address _holder) public view returns(uint256) {
        TimeLock memory _locker = addressToLocker[_holder];

        if (_locker.timestamp + lockTime < block.timestamp) {
            return 0;
        } else {
            return _locker.lpLocked;
        }
    }

    function emergencyWithdraw() public onlyOwner {
        (bool success, ) = payable(owner()).call{ value: address(this).balance }("");
		require(success, "AVAX Transaction: Failed to transfer funds");
    }

    function emergencyWithdrawERC20(address _contract) public onlyOwner {
        IERC20 _token = IERC20(_contract);
        _token.transfer(msg.sender, _token.balanceOf(address(this)));
    }

}