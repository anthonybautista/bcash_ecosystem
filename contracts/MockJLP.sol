// SPDX-License-Identifier: MIT
pragma solidity 0.8.2;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";



contract MockJLP is ERC20 {
    
    //hard-code amounts to simplify testing
    uint112 public reserve0 = 1000*10**18; //wavax
    uint112 public reserve1 = 1000000*10**18; //antG


    constructor() ERC20("Mock JLP", "JLP"){
    }


    function mint(address account, uint256 amount) external {
        
        _mint(account, amount);
    }

    function getReserves() public view returns(uint112, uint112, uint32){
        return (reserve0, reserve1, uint32(block.timestamp));
    }

    function updateReserves(uint112 _newWAVAX, uint112 _newAntG) public {
        reserve0 = _newAntG * 10**18;
        reserve1 = _newWAVAX * 10**18;
    }

}