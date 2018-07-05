pragma solidity ^0.4.21;

interface Token {
    function totalSupply() constant external returns (uint256 ts);
    function balanceOf(address _owner) constant external returns (uint256 balance);
    function transfer(address _to, uint256 _value) external returns (bool success);
    function transferFrom(address _from, address _to, uint256 _value) external returns (bool success);
    function approve(address _spender, uint256 _value) external returns (bool success);
    function allowance(address _owner, address _spender) constant external returns (uint256 remaining);
    function issue(address _user, uint256 _value) external returns (bool success);
    
    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);
}

contract SafeMath {
    function safeAdd(uint x, uint y)
        internal
        pure
    returns(uint) {
        uint256 z = x + y;
        require((z >= x) && (z >= y));
        return z;
    }

    function safeSub(uint x, uint y)
        internal
        pure
    returns(uint) {
        require(x >= y);
        uint256 z = x - y;
        return z;
    }

    function safeMul(uint x, uint y)
        internal
        pure
    returns(uint) {
        uint z = x * y;
        require((x == 0) || (z / x == y));
        return z;
    }
    
    function safeDiv(uint x, uint y)
        internal
        pure
    returns(uint) {
        require(y > 0);
        return x / y;
    }

    function random(uint N, uint salt)
        internal
        view
    returns(uint) {
        bytes32 hash = keccak256(block.timestamp, msg.sender, salt);
        return uint(hash) % N;
    }
}

contract Authorization {
    mapping(address => address) public agentBooks;
    address public owner;
    address public operator;
    address public bank;
    bool public powerStatus = true;

    function Authorization ()
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
        onlyOwner
        public
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

contract XBergo is SafeMath {

    string public bergoName;
    address public bergoToken;
    uint256 public bergoPrice;
    uint256 public bergoAmount;
    string public bergoPrize;
    address public xBank;
    address[] public players; 
    address public bergoer = address(0);
    
    event xReceiveTransfer(address _from, address _to, address _bergoToken, uint256 _bergoPrice, bytes _extraData);
    event xOpenBergo(address _bergoAddress, address _bergoer);

    function XBergo (
        string _bergoName,
        address _bergoToken,
        uint256 _bergoPrice,
        uint256 _bergoAmount,
        string _bergoPrize,
        address _xBank
    )
        public
    {
        bergoName = _bergoName;
        bergoToken = _bergoToken;
        bergoPrice = _bergoPrice;
        bergoAmount = _bergoAmount;
        bergoPrize = _bergoPrize;
        xBank = _xBank;
    }

    function receiveTransfer (
        address _from,
        address _token,
        uint256 _value,
        bytes _extraData
    )
        public
        returns(bool) 
    {
        require(players.length < bergoAmount);
        require(bergoToken == _token); // only bergoToken can buy bergo
        require(bergoPrice == _value);
        require(msg.sender == xBank);
        
        emit xReceiveTransfer(_from, this, _token, _value, _extraData);
        return buyBergo(_from);
        /*if(issueXGP(_from)){
            return buyBergo(_from);
        } else {
            return false;
        }*/
    }

    function buyBergo (
        address _user
    )
        internal
        returns(bool) 
    {
        players.push(_user);
        if(players.length == bergoAmount){
            openBergo();
        }
        return true;
    }

    function openBergo ()
        internal
    {
        uint256 x = random(players.length, block.number);
        bergoer = players[x];
        emit xOpenBergo(address(this), bergoer);
    }

    function issueXGP (
        address _user
    ) 
        public 
        returns(bool) 
    {
        if( Token(xBank).issue(_user, 1 ether) ){
            return true;
        } else {
            return false;
        }
        
    }
}

contract XBergoFacotry is Authorization {
    
    address[] public bergoBooks;

    function createBergo(
        string _bergoName,
        address _bergoToken,
        uint256 _bergoPrice,
        uint256 _bergoAmount,
        string _bergoPrize,
        address _xBank
    )
        public
        onlyOperator 
        returns (address) 
    {
        address bergoAddress = new XBergo(_bergoName, _bergoToken, _bergoPrice, _bergoAmount, _bergoPrize, _xBank);
        bergoBooks.push(bergoAddress);
        return bergoAddress;
    }
}