pragma solidity ^0.6.0;


interface IPlayerManager {
    function register(address user,address lastUser) external;
    function setlleReward(address user,uint256 amount) external;
    function addCount(address user) external;
}
