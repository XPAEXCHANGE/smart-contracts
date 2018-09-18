pragma solidity ^0.4.25;

/*
需使用 0.4.25 compile

[Address]
XDice: 0xd2ae9b038f6d923efc99fc3e6f3cdb0f7e6db76c
USX: 0xb8e5c9d9e8ea9cb92cd883ecb0d4f718f031551d

查看本回合狀態：
eth_call
getCurrentRound(address)
0x565b1a25

查看該期開獎數字：
eth_call
results(address,uint256)
0x7724f4e7

押注：
send_rawTransaction
USX：0xb8e5c9d9e8ea9cb92cd883ecb0d4f718f031551d
approveAndCall(address,uint256,bytes): XDice地址, 下注金額, 下注數字

查看自己有沒有中獎猜單雙
eth_call
getOEResult(address,uint256,address): USX地址, 期數, 用戶
0x2a21c70b

查看自己有沒有中獎猜數字
eth_call
getResult(address,uint256,address): USX地址, 期數, 用戶
0x409c8314

查看自己有沒有未領取獎項
eth_call
unclaimeReward(address,uint256,address): USX地址, 期數, 用戶
0x8143c7e6

領獎
send_rawTransaction
claim(address,period): USX地址, 期數
0xaad3ec96
 */

interface Token {
    function totalSupply() external view returns (uint256 ts);
    function balanceOf(address _owner) external view returns (uint256 balance);
    function transfer(address _to, uint256 _value) external returns (bool success);
    function transferFrom(address _from, address _to, uint256 _value) external returns (bool success);
    function approve(address _spender, uint256 _value) external returns (bool success);
    function allowance(address _owner, address _spender) external view returns (uint256 remaining);
}

contract SafeMath {
    function safeAdd(uint x, uint y)
        internal
        pure
    returns(uint) {
        uint256 z = x + y;
        require((z >= x) && (z >= y), "safeAdd error!");
        return z;
    }

    function safeSub(uint x, uint y)
        internal
        pure
    returns(uint) {
        require(x >= y, "safeSub error!");
        uint256 z = x - y;
        return z;
    }

    function safeMul(uint x, uint y)
        internal
        pure
    returns(uint) {
        uint z = x * y;
        require((x == 0) || (z / x == y), "safeMul error!");
        return z;
    }
    
    function safeDiv(uint x, uint y)
        internal
        pure
    returns(uint) {
        require(y > 0, "safeDiv error!");
        return x / y;
    }

    function random(uint N, uint salt)
        internal
        view
    returns(uint) {
        bytes32 hash = keccak256(abi.encodePacked(block.timestamp, msg.sender, salt));
        return uint(hash) % N;
    }
}

contract Authorization {
    mapping(address => address) public agentBooks;
    address public owner;
    address public operator;
    address public bank;
    bool public powerStatus = true;

    constructor()
        public
    {
        owner = msg.sender;
        operator = msg.sender;
        bank = msg.sender;
    }

    modifier onlyOwner
    {
        assert(msg.sender == owner);
        _;
    }
    modifier onlyOperator
    {
        assert(msg.sender == operator || msg.sender == owner);
        _;
    }
    modifier onlyActive
    {
        assert(powerStatus);
        _;
    }

    function powerSwitch(
        bool onOff_
    )
        public
        onlyOperator
    {
        powerStatus = onOff_;
    }

    function transferOwnership(address newOwner_)
        public
        onlyOwner
    {
        owner = newOwner_;
    }
    
    function assignOperator(address user_)
        public
        onlyOwner
    {
        operator = user_;
        agentBooks[bank] = user_;
    }
    
    function assignBank(address bank_)
        public
        onlyOwner
    {
        bank = bank_;
    }
}

contract XDice is SafeMath, Authorization {
    mapping(address => uint256) public period;
    mapping(address => mapping(uint256 => mapping(uint256 => uint256))) public gameSets;
    mapping(address => mapping(uint256 => mapping(address => uint256))) public stakes;
    mapping(address => mapping(uint256 => mapping(address => uint256))) public tickets;
    mapping(address => mapping(uint256 => mapping(address => bool))) public claimed;
    mapping(address => mapping(uint256 => uint256)) public results;
    mapping(address => uint256) public maxBets;
    mapping(address => uint256) public singleStake;
    uint256 defaultMaxBets = 3 ether;
    uint256 defaultSingleStake = 1 ether;

    event eBet(address token, uint256 period, address user, uint256 target, uint256 amount);
    event eDraw(address token, uint256 period, uint256 target);
    event eClaim(address token, uint256 period, address user, uint256 amount);
    
    event Error(uint256 code);

    constructor(
    )
        public
    {
    }

    function setMaxBets(
        uint256 maxBets_,
        address token_
    )
        public
        onlyOperator
    {
        if(maxBets_ >= 0.01 ether) {
            maxBets[token_] = maxBets_;
        }
    }
    
    function getMaxBets(
        address token_
    )
        public
        view
    returns(uint256) {
        return maxBets[token_] > 0 ? maxBets[token_] : defaultMaxBets;
    }

    function setSingleStake(
        uint256 singleStake_,
        address token_
    )
        public
    {
        if(singleStake_ > 0) {
            singleStake[token_] = singleStake_;
        }
    }
    
    function getSingleStake(
        address token_
    )
        public
        view
    returns(uint256) {
        return singleStake[token_] > 0 ? singleStake[token_] : defaultSingleStake;
    }

    function bet(
        address token_,
        uint256 target_,
        address representor_
    )
        public
        payable
    returns(bool) {
        address user = representor_ == address(0) ? msg.sender : representor_;
        uint256 x = target_ >= 2 && target_ <= 12 ?
            target_ :
            random(6, block.number * 15) + 1 + random(6, block.number * 25) + 1;
        uint256 ss = getSingleStake(token_);
        if(msg.value > 0) {
            uint256 amount = msg.value;
            betting(user, address(0), amount, x);
        } else if(Token(token_).transferFrom(user, this, ss)) {
            betting(user, token_, ss, x);
        }
    }

    function betting(
        address user_,
        address token_,
        uint256 amount_,
        uint256 target_
    )
        internal
    returns(bool) {
        uint256 t = target_;
        uint256 p = period[token_];
        uint256 oldt = tickets[token_][p][user_];
        uint256 olds = stakes[token_][p][user_];
        if(olds > 0 && oldt != t) {
            gameSets[token_][p][oldt] = safeSub(gameSets[token_][p][oldt], olds);
            gameSets[token_][p][t] = safeAdd(gameSets[token_][p][t], safeAdd(amount_, olds));
            stakes[token_][p][user_] = safeAdd(stakes[token_][p][user_], amount_);
            tickets[token_][p][user_] = t;
        } else {
            gameSets[token_][p][t] = safeAdd(gameSets[token_][p][t], amount_);
            stakes[token_][p][user_] = safeAdd(stakes[token_][p][user_], amount_);
            tickets[token_][p][user_] = t;
        }

        emit eBet(token_, p, user_, t, amount_);
        
        uint256 totalBets = getTotalStakes(token_, p, false);
        if(totalBets >= getMaxBets(token_)) {
            makeDraw(token_);
        }
    }

    function makeDraw(
        address token_
    )
        internal
    returns(bool) {
        uint256 p = period[token_];
        uint256 r = random(6, block.number) + 1 + random(6, block.number - 1) + 1;
        results[token_][p] = r;
        period[token_] = period[token_] + 1;
        
        // 未中彩金累積至下一期
        uint256 OEW = getOEWiningStakes(token_, p);
        uint256 NUMW = getNumWiningStakes(token_, p);
        uint256 TOTAL = getTotalStakes(token_, p, true);
        uint256 Jackpot = 0;
        if(OEW == 0) {
            Jackpot = TOTAL;
        } else if(NUMW == 0) {
            Jackpot = safeDiv(safeMul(TOTAL, 9), 10);
        }
        gameSets[token_][period[token_]][0] = Jackpot;
        emit eDraw(token_, p, r);
    }

    function getOEResult(
        address token_,
        uint256 period_,
        address user_
    )
        public
        view
    returns(bool) {
        return (
            stakes[token_][period_][user_] > 0 &&
            results[token_][period_] % 2 == tickets[token_][period_][user_] % 2
        );
    }

    function getNumResult(
        address token_,
        uint256 period_,
        address user_
    )
        public
        view
    returns(bool) {
        return (
            stakes[token_][period_][user_] > 0 &&
            results[token_][period_] == tickets[token_][period_][user_]
        );
    }

    function getLatestOEResult(
        address token_,
        address user_
    )
        public
        view
    returns(bool) {
        return getOEResult(token_, period[token_], user_);
    }

    function getLatestNumResult(
        address token_,
        address user_
    )
        public
        view
    returns(bool) {
        return getNumResult(token_, period[token_], user_);
    }

    function getCurrentRound(
        address token_    
    )
        public
        view
    returns(uint256, uint256, uint256) {
        uint256 p = period[token_];
        uint256 t = getTotalStakes(token_, p, false);
        return(p, t, getMaxBets(token_));
    }

    function getUserResult(
        address token_,
        uint256 period_,
        address user_
    )
        public
        view
    returns(bool, bool, uint256, uint256, uint256) {
        return (
            (getOEResult(token_, period_, user_) || getNumResult(token_, period_, user_)),
            claimed[token_][period_][user_],
            tickets[token_][period_][user_],
            results[token_][period_],
            getUserReward(token_, period_, user_)
        );
    }

    function unclaimedReward(
        address token_,
        uint256 period_,
        address user_
    )
        public
        view
    returns(bool) {
        return (
            (
                getOEResult(token_, period_, user_) ||
                getNumResult(token_, period_, user_)
            ) &&
            !claimed[token_][period_][user_]
        );
    }

    function getTotalStakes(
        address token_,
        uint256 period_,
        bool includeJackpot_
    )
        public
        view
    returns(uint256) {
        uint256 totalStakes = 0;
        for(uint256 i = includeJackpot_ ? 0 : 2; i < 16; i++) {
            totalStakes = safeAdd(totalStakes, gameSets[token_][period_][i]);
        }
        return totalStakes;
    }
    
    function getOEWiningStakes(
        address token_,
        uint256 period_
    )
        public
        view
    returns(uint256) {
        uint256 totalStakes = 0;
        uint256 OE = results[token_][period_] % 2;
        for(uint256 i = 2; i < 16; i++) {
            if(i % 2 == OE) {
                totalStakes = safeAdd(totalStakes, gameSets[token_][period_][i]);
            }
        }
        return totalStakes;
    }

    function getNumWiningStakes(
        address token_,
        uint256 period_
    )
        public
        view
    returns(uint256) {
        return gameSets[token_][period_][results[token_][period_]];
    }

    function getUserStakes(
        address token_,
        uint256 period_,
        address user_
    )
        public
        view
    returns(uint256) {
        return stakes[token_][period_][user_];
    }

    function getUserReward(
        address token_,
        uint256 period_,
        address user_
    )
        public
        view
    returns(uint256) {
        uint256 OEReward;
        uint256 NumReward;
        uint256 totalReward;
        if(getOEResult(token_, period_, user_)) {
            OEReward = safeDiv(
                safeMul(
                    safeDiv(getTotalStakes(token_, period_, true), 10),
                    getUserStakes(token_, period_, user_)
                ),
                getOEWiningStakes(token_, period_)
            );
        }
        if(getNumResult(token_, period_, user_)) {
            NumReward = safeDiv(
                safeMul(
                    safeDiv(safeMul(getTotalStakes(token_, period_, true), 9), 10),
                    getUserStakes(token_, period_, user_)
                ),
                getNumWiningStakes(token_, period_)
            );
        }
        totalReward = safeAdd(OEReward, NumReward);
        return totalReward;
    }

    function claim(
        address token_,
        uint256 period_
    )
        public
    returns(bool) {
        address user = msg.sender;
        uint256 totalReward;
        if(unclaimedReward(token_, period_, user)) {
            claimed[token_][period_][user] = true;
            totalReward = getUserReward(token_, period_, user);
            emit eClaim(token_, period_, user, totalReward);
            transferToken(user, token_, totalReward);
        }
    }
    
    function transferToken(
        address user_,
        address token_,
        uint256 amount_
    )
        internal
    returns(bool) {
        if(amount_ > 0) {
            if(token_ == address(0)) {
                if(address(this).balance < amount_) {
                    emit Error(1);
                    return false;
                } else {
                    user_.transfer(amount_);
                    return true;
                }
            } else if(Token(token_).transfer(user_, amount_)) {
                return true;
            } else {
                emit Error(1);
                return false;
            }
        } else {
            return true;
        }
    }
}