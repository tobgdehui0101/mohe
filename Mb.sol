pragma solidity ^0.6.0;

import '@openzeppelin/contracts/token/ERC20/ERC20Burnable.sol';
import './owner/Operator.sol';

contract Mb is ERC20Burnable, Ownable, Operator {

    uint256 maxCount = 125000000 * 1e18;
    uint256 totalCount = 0;
    /**
     * @notice Constructs the Basis Cash ERC-20 contract.
     */
    constructor() public ERC20('MB', 'MB') {
    }

    function mint(address recipient_, uint256 amount_)
    public
    onlyOperator
    returns (bool)
    {
        if(totalCount < maxCount){
            uint256 balanceBefore = balanceOf(recipient_);
            _mint(recipient_, amount_);
            totalCount = totalCount.add(amount_);
            uint256 balanceAfter = balanceOf(recipient_);

            return balanceAfter > balanceBefore;
        }
    }

    function burn(uint256 amount) public override onlyOperator {
        super.burn(amount);
    }

    function burnFrom(address account, uint256 amount)
    public
    override
    onlyOperator
    {
        super.burnFrom(account, amount);
    }

}
