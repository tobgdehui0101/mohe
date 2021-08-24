pragma solidity ^0.6.0;


import '@openzeppelin/contracts/math/Math.sol';
import '@openzeppelin/contracts/math/SafeMath.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/utils/Address.sol';
import '@openzeppelin/contracts/token/ERC20/SafeERC20.sol';
import '../interfaces/IRewardDistributionRecipient.sol';
import '../interfaces/IPlayerManager.sol';

contract TokenPool is Ownable
{
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    //主token
    IERC20 public mb = IERC20(0xF2987579B3B03D4581cf8Fe951682222A992143a);
    //总算力
    uint256 public totalPower;
    //总能耗
    uint256 public totalEniger;

    uint256 public mb_price = 5 * 1e17;  //1MB=0.5U
    uint256 public bnb_price = 300 * 1e18; //1BNB=300U
    uint256 public usdt_price = 1 * 1e18; //1U=1U
    uint256 public eth_price = 1000 * 1e18; //1ETH=1000U
    uint256 public btc_price = 10000 * 1e18; //1BTC=10000U
    address public usdt = 0x7243DAE68eA01f65d9304F26e968581b3a3c6e9F;
    address public eth = 0xABFe04F68e79F186A7E437312b2f6EEA4F6dF2A6;
    address public btc = 0xF2987579B3B03D4581cf8Fe951682222A992143a;

//    address public usdt = 0x337610d27c682e347c9cd60bd4b3b107c9d34ddd;
//    address public eth = 0xd66c6b4f0be8ce5b39d52e0fd1344c389929b378;
//    address public btc = 0x6ce8da28e2f864420840cf74474eff5fd80e65b8;

    address playerManager;
    event RewardAdded(uint256 reward);
    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user);
    event RewardPaid(address indexed user, uint256 reward);

    constructor(
        uint256 starttime_,
        address playermanager_,
        address mb_,
        address usdt_,
        address eth_,
        address btc_
    ) public {
        starttime = starttime_;
        playerManager = playermanager_;
        mb = IERC20(mb_);
        usdt = usdt_;
        eth = eth_;
        btc = btc_;
    }

    function setMb(address address_) public onlyOwner{
        mb = IERC20(address_);
    }
    function setUsdt(address address_) public onlyOwner{
        usdt = address_;
    }
    function setEth(address address_) public onlyOwner{
        eth = address_;
    }
    function setBtc(address address_) public onlyOwner{
        btc = address_;
    }

    //开始时间
    uint256 public starttime;

    mapping(address => UserOrder) private _userOrders;

    struct UserOrder{
        bool isUsed;
        uint256[] finishIds;
        uint256[] allOrderIds;
    }

    function isExistUserOrder(address _addr) public view returns(bool){
        return _userOrders[_addr].isUsed;
    }

    mapping (uint256 => Order) public _orders;
    //订单序号
    uint256 public orderIndex = 1;
    struct Order{
        uint256 index;
        uint256 coin; // 0:bnb,1:usdt,2:eth,3:btc
        address user;
        uint256 amount;
        uint256 amountMb;
        uint256 pasentMb;//MB的比例 20
        uint256 beiLv;//倍率 1.2倍
        //虚假的金额(经过加成的)
        uint256 power;
        uint256 startTime;
        uint256 stopTime;
        uint256 incomeMb;
//        uint256 week; // 周期 1,2,4
        uint256 state; // 状态 1:质押中， 2:已赎回
        uint256 runTime;//运行时长
        uint256 lastPower;
    }

    //获取倍率
    function getBeiLv(uint256 pasentMb, uint256 week) public pure returns (uint256) {
        if(pasentMb == 20){
            if(week == 1)return 150;
            if(week == 2)return 180;
            if(week == 4)return 225;
        }
        if(pasentMb == 30){
            if(week == 1)return 120 ;
            if(week == 2)return 144 ;
            if(week == 4)return 180 ;
        }
        if(pasentMb == 50){
            if(week == 1)return 100 ;
            if(week == 2)return 120 ;
            if(week == 4)return 150 ;
        }
        return 0;
    }

    //获取每日收益
    function getIncomePerDay() public view returns (uint256) {
        if(totalPower <= 100 * 10000){
            return 17100 * 1e18;
        }
        if(totalPower <= 500 * 10000){
            return 42750 * 1e18;
        }
        if(totalPower <= 1000 * 10000){
            return 85500 * 1e18;
        }
        return 128250 * 1e18;
    }

    //获取每秒钟收益
    function getIncomePerSecond() public view returns (uint256) {
        return getIncomePerDay().div(3600).div(24);
    }

    function setPlayerManager(address _playerManager) public onlyOwner{
        playerManager = _playerManager;
    }

    function getMinRealTime(uint256 orderTime) public view returns (uint256) {
        return Math.min(block.timestamp, orderTime);
    }

    function getOrders() public view returns(
        uint256[12][] memory
    ) {
        uint256[] memory allOrderIds = _userOrders[msg.sender].allOrderIds;
        uint256[12][] memory results = new uint256[12][](allOrderIds.length);

        for(uint256 i = 0; i < allOrderIds.length; i++) {
            Order memory order = _orders[allOrderIds[i]];

            results[i][0] = order.index;
            results[i][1] = order.coin;
            results[i][2] = order.beiLv;
            results[i][3] = order.amount;
            results[i][4] = order.startTime;
            results[i][5] = order.stopTime;
            if(order.state == 1){
                //订单市长，单位为秒
                uint256 runTime = getMinRealTime(order.stopTime) - order.startTime;
                uint256 incomePerSecond = getIncomePerSecond();
                uint256 incomeMb = incomePerSecond.mul(order.power).mul(runTime).div(totalPower);
                results[i][6] = incomeMb;
                results[i][10] = runTime;
            }else{
                results[i][6] = order.incomeMb;
                results[i][10] = order.runTime;
            }
            results[i][7] = order.amountMb;
            results[i][8] = order.lastPower;
            results[i][9] = order.power;
            results[i][11] = order.pasentMb;
        }
        return (results);
    }

    function getOrderById(uint256 orderId) public view returns(
        uint256[12][] memory
    ) {
        Order memory order = _orders[orderId];
        require(order.user == msg.sender, 'the order is not yours');
        uint256[12][] memory results = new uint256[12][](1);
        results[0][0] = order.index;
        results[0][1] = order.coin;
        results[0][2] = order.beiLv;
        results[0][3] = order.amount;
        results[0][4] = order.startTime;
        results[0][5] = order.stopTime;
        if(order.state == 1){
            //订单市长，单位为秒
            uint256 runTime = getMinRealTime(order.stopTime) - order.startTime;
            uint256 incomePerSecond = getIncomePerSecond();
            uint256 incomeMb = incomePerSecond.mul(order.power).mul(runTime).div(totalPower);

            results[0][6] = incomeMb;
            results[0][10] = runTime;
        }else{
            results[0][6] = order.incomeMb;
            results[0][10] = order.runTime;
        }
        results[0][7] = order.amountMb;
        results[0][8] = order.lastPower;
        results[0][9] = order.power;
        results[0][11] = order.pasentMb;
        return (results);
    }

    //0:bnb,1:usdt,2:eth,3:btc
    function getTokenAdress(uint256 coin) public view returns (address) {
        address tokenAdress = usdt;
        if(coin == 1){
            tokenAdress = usdt;
        }
        if(coin == 2){
            tokenAdress = eth;
        }
        if(coin == 3){
            tokenAdress = btc;
        }
        return tokenAdress;
    }

    address BURN_ADDRESS = 0x0000000000000000000000000000000000000000;//5

    //查询当前的余额
    function getCoinBalance() public view returns(uint256){
        return address(this).balance;
    }

    function stake(uint256 coin, uint256 tokenAmount, uint256 pasentMb, uint256 week) public payable checkStart
    {
        require(tokenAmount > 0, 'Cannot stake 0');
        require(coin == 0 || coin == 1 || coin == 2 || coin == 3, 'coin onely support 0,1,2,3');
        require(pasentMb == 20 || pasentMb == 30 || pasentMb == 50, 'pasentMb onely support 20,30,50');
        require(week == 1 || week == 2 || week == 4, 'week onely support 1,2,4');

        //获取价格
        uint256 price = usdt_price;
        address tokenAdress = usdt;
        //0:bnb,1:usdt,2:eth,3:btc
        if(coin == 0){
            price = bnb_price;
            require(msg.value >= tokenAmount, 'your send bnb is not enoph');
        }
        if(coin == 2){
            price = eth_price;
            tokenAdress = eth;
        }
        if(coin == 3){
            price = btc_price;
            tokenAdress = btc;
        }
        uint beiLv_ = getBeiLv(pasentMb, week);

        if(coin != 0){
            IERC20(tokenAdress).safeTransferFrom(msg.sender, address(this), tokenAmount);
        }

        uint256 tokenMbAmount = tokenAmount.mul(price).div(mb_price);
        uint256 mbAmount = tokenMbAmount.mul(pasentMb).div(100-pasentMb);

        mb.safeTransferFrom(msg.sender, address(this), mbAmount);

        uint256 thisPower = (mbAmount.add(tokenMbAmount)).mul(mb_price).div(1e18);
        thisPower = thisPower.mul(beiLv_).div(1e18);//算力保留2位小数

        uint256 lastTime = 4 weeks;
        if(week == 1)lastTime = 1 weeks;
        if(week == 2)lastTime = 2 weeks;

        Order memory order = Order({
            index: orderIndex,
            coin: coin,
            user: msg.sender,
            amount:tokenAmount,
            amountMb: mbAmount,
            pasentMb: pasentMb,
            beiLv: beiLv_,
            power: thisPower,
            startTime: block.timestamp,
            stopTime: block.timestamp.add(lastTime),
            incomeMb:0,
//            week: lastTime,
            state: 1,
            runTime:0,
            lastPower:0
        });
        _orders[orderIndex] = order;
        _userOrders[msg.sender].isUsed = true;
        _userOrders[msg.sender].allOrderIds.push(orderIndex);
        totalPower = totalPower.add(thisPower);
        totalEniger = totalEniger.add(thisPower.mul(lastTime));
        orderIndex ++;
        emit Staked(msg.sender, tokenAmount);
    }

    //获取奖励+退出
    function exit(uint256 orderId) public checkStart {
        Order memory order = _orders[orderId];
        require(order.user == msg.sender, 'the order is not yours');
        require(order.state == 1, 'the order state is not pledge');

        //修改订单状态
        _orders[orderId].state = 2;
        UserOrder storage userOrder  = _userOrders[msg.sender];
        userOrder.finishIds.push(orderId);

        uint256 amount = order.amount;
        uint256 mbAmount = order.amountMb;
        if(order.coin == 0){
            msg.sender.transfer(amount);
        }else{
            address tokenAdress = getTokenAdress(order.coin);
            IERC20(tokenAdress).safeTransfer(msg.sender, amount);
        }
        mb.safeTransfer(msg.sender, mbAmount);
        //订单市长，单位为秒
        uint256 runTime = getMinRealTime(order.stopTime) - order.startTime;
        uint256 lastTime = order.stopTime - order.startTime;
        uint256 incomePerSecond = getIncomePerSecond();
        uint256 orderAllEniger = order.power.mul(lastTime);
        uint256 incomeAllMb = incomePerSecond.mul(order.power).mul(runTime).div(totalPower);

        _orders[orderId].incomeMb = incomeAllMb;
        _orders[orderId].runTime = runTime;
        _orders[orderId].lastPower = totalPower;

        totalPower = totalPower.sub(order.power);
        //总功率减少,需要减去订单全部功率
        totalEniger = totalEniger.sub(orderAllEniger);

        if (incomeAllMb > 0) {
            if(now > order.stopTime){
                uint256 burnMb = incomeAllMb.mul(5).div(100);
                uint256 incomeMb = incomeAllMb.sub(burnMb);
                mb.safeTransfer(BURN_ADDRESS, burnMb);
//                mb.safeTransfer(msg.sender, incomeMb);
                IPlayerManager(playerManager).setlleReward(msg.sender,incomeMb);
            }else{
                uint256 burnMb = getBurnNum(order.pasentMb, incomeAllMb);
                uint256 incomeMb = incomeAllMb.sub(burnMb);
                mb.safeTransfer(BURN_ADDRESS, burnMb);
//                mb.safeTransfer(msg.sender, incomeMb);
                IPlayerManager(playerManager).setlleReward(msg.sender,incomeMb);
            }
            emit RewardPaid(msg.sender, incomeAllMb);
        }
    }


    //提前赎回，燃烧数量
    function getBurnNum(uint256 pasentMb, uint256 incomeMb) public pure returns (uint256) {
        if(pasentMb == 20){
            return incomeMb.mul(20).div(100);
        }
        if(pasentMb == 30){
            return incomeMb.mul(30).div(100);
        }
        if(pasentMb == 50){
            return incomeMb.mul(40).div(100);
        }
        return incomeMb.mul(20).div(100);
    }


    modifier checkStart() {
        require(block.timestamp >= starttime, 'not start');
        _;
    }

}
