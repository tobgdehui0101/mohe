pragma solidity ^0.6.0;

import '@openzeppelin/contracts/access/Ownable.sol';

abstract contract IRewardDistributionRecipient is Ownable {
    address public rewardDistribution;

    function notifyRewardAmount(uint256 reward) external virtual;

    constructor() internal {
        rewardDistribution = msg.sender;
    }

    modifier onlyRewardDistribution() {
        require(
            _msgSender() == rewardDistribution,
            'Caller is not reward distribution'
        );
        _;
    }

    function setRewardDistribution(address _rewardDistribution)
        external
        virtual
        onlyOwner
    {
        rewardDistribution = _rewardDistribution;
    }
}
