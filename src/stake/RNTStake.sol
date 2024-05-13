// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import {BaseToken} from "../token/BaseToken.sol";
import {RewardToken} from "../token/RewardToken.sol";

/**
 * 质押挖矿: 
 *  1) 为了限制用户抛售代币，给用户提供一种机制，将代币(RNT)质押，满足一定时间才可以提取，然后项目方支付一定的Token(RNT)，从而降低用户抛售代币
 *  2) 为了激励大家去提供流动性，可以上DEX去中心化交易所进行代币交易，然后就可以提高DEX中RNT的流动性
 * LP挖矿: 
 * 交易挖矿 交易多少ETH，可以领取多少Token
 * 
 * 质押挖矿特点：
 *  1) 随时可以存取，随时领取收益，还可以进复利
 *  2) 也可以质押N天后在领取
 *  3) 质押的代币随时可以取走，但是去最后就不会再有矿池奖励
 * 
 * @title 质押挖矿
 * @author 张乐辉
 * @notice 
 */
contract RNTStake  {

    struct Stake {
        uint256 amount; // stake token number
        uint256 updatedAt; // last update date
    }

    struct Reward {
        uint256 id;
        uint256 amount; // user reward amount
        bool taked; // user if has taked
        uint256 createdAt; // created time
    }

    // Stake token
    BaseToken stakeToken;

    // Reward token
    RewardToken rewardToken;

    // stake initialzier
    address initialzier;

    // Min  speed per second
    uint256 mintSpeedPerSecond;

    // User and stake mapping
    mapping(address => Stake) stakes;

    // User accumulated the  rewards
    mapping(address => uint256) accumulatedRewards;

    // User accumulated claim rewards, may be have taked, may be not
    mapping(address => Reward[]) userClaimRewards;

    // User latest claim rewards
    mapping(address => uint256) userLatestClaimRewards;

    event StakeEvent(address indexed from, address indexed market, uint256 amount);
    event UnstakeEvent(address indexed from, address indexed market, uint256 amount);
    event ClaimRewardEvent(address indexed from, address indexed market, uint256 amount);
    event GetRewardEvent(address indexed from, address indexed market, uint256 amount);



    constructor(address _stakeToken, address _rewardToken , address _initialzier){
        stakeToken = BaseToken(_stakeToken);
        rewardToken = RewardToken(_rewardToken);
        initialzier = _initialzier;
    }


    modifier updateUserReward() {
        // If user have no amount, no need update the reward
        if (stakes[msg.sender].amount <= 0) {
            _;
            return;
        }

        // Calculate the user latest rewards based on the stake token owned by user
        uint256 currentReward = (1 * 1e18 / uint256(1 days)) * (block.timestamp - stakes[msg.sender].updatedAt)  * stakes[msg.sender].amount / 1e18;

        // Accumulate the user total reward
        accumulatedRewards[msg.sender] += currentReward;


        stakes[msg.sender].updatedAt = block.timestamp;
        _;
    }




    /*
     * User add stake token
     * @param amount 
     */
    function stake(uint256 amount) external updateUserReward {
        require(amount > 0, "stake amount must greater than 0");
        
        // Update user stake amount
        stakes[msg.sender].amount += amount;

        // Transfer stake token from user to market
        stakeToken.transferFrom(msg.sender, address(this), amount);

        emit StakeEvent(msg.sender, address(this), amount);
    }



    /*
     * User unstake specified amount stake token
     * @param amount 
     */
    function unstake(uint256 amount) external updateUserReward {
        require(amount <= stakes[msg.sender].amount, "unstake amount must less than user stake token amount");
        
        // Update user stake amount
        stakes[msg.sender].amount -= amount;

        // Transfer stake token from market to user
        stakeToken.transfer(msg.sender, amount);

        emit UnstakeEvent(msg.sender, address(this), amount);
    }



    /**
     * User can claim anytime, calculate user unclaimed reward and mint es RNT at this time
     */
    function claim() external updateUserReward{
         // User claimed reward last time, if no any claim, the value is 0
        uint256 latestClaimReward = userLatestClaimRewards[msg.sender];

        // Calculate the user claim reward now
        uint256 claimReward = accumulatedRewards[msg.sender] - latestClaimReward;

        // Update the user latest claim rewards
        userLatestClaimRewards[msg.sender] += claimReward;

        // Each user will save the claim reward data, and every reward has an id
        Reward memory reward = Reward(userClaimRewards[msg.sender].length + 1,claimReward, false, block.timestamp);
        userClaimRewards[msg.sender].push(reward);
        
        // Mint esRNT based on the current claim value
        rewardToken.mint(msg.sender, claimReward);

        emit ClaimRewardEvent(msg.sender, address(this), claimReward);
    }



    /*
     * User could get the reward, that has claimed
     * @param rewardId 
     */
    function getReward(uint256 rewardId) external updateUserReward {
        require(userClaimRewards[msg.sender].length > 0, "User have no claim reward data");
        require(rewardId > 0 && rewardId <= userClaimRewards[msg.sender].length, "invalid reward id");
        
        // Get the reward by reward id
        Reward memory reward = userClaimRewards[msg.sender][rewardId - 1];

        // Not allow user withdraw the same claim
        require(!reward.taked, "User have taked the reward");

        // Calculate the unlock time, if time greater than 30 days, which allow user 1:1 get the reward
        // If user wants to take the esRNT before unlock forcefully, must allow lost some reward by linear time
        uint256 unlockTime = block.timestamp - reward.createdAt;

        if (unlockTime > 30 days) {
            // Transfer RNT to user
            stakeToken.transferFrom(initialzier, msg.sender, reward.amount);
            // Update the reward has been taked
            userClaimRewards[msg.sender][rewardId - 1].taked = true;

            emit GetRewardEvent(msg.sender, address(this), reward.amount);
            return;
        }

        // User allow the reward loss, will calculate the exchange reward and burned reward 
        uint256 afterExchangeReward = (unlockTime * reward.amount)/ 30 days ;
        
        stakeToken.transferFrom(initialzier, msg.sender, afterExchangeReward);

        // Update the reward has been taked
        userClaimRewards[msg.sender][rewardId - 1].taked = true;

        // Other part of reward will be burned
        rewardToken.burnFrom(msg.sender, reward.amount - afterExchangeReward);

        emit GetRewardEvent(msg.sender, address(this), afterExchangeReward);
    }



    /*
     * Get balance of user
     * @param user 
     */
    function balanceOf(address user) external returns (uint256) {
        return stakes[user].amount;
    }



    /*
     * Get balance of user
     * @param user 
     */
    function rewardOf(address user) external returns (uint256) {
        return accumulatedRewards[user];
    }
}
