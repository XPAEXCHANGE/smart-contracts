// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;

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
        bytes32 hash = keccak256(abi.encodePacked(block.number, msg.sender, salt));
        return uint(hash) % N;
    }
}

contract StandardToken is SafeMath {
    mapping(address => uint256) balances;
    mapping(address => mapping (address => uint256)) allowed;
    uint256 public decimals;
    uint256 public totalSupply;

    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);
    event Issue(address indexed _to, uint256 indexed _value);
    event Burn(address indexed _from, uint256 indexed _value);

    /* constructor */
    constructor() public payable {}

    /* Send coins */
    function transfer(
        address to_,
        uint256 amount_
    )
        public
    returns(bool success) {
        if(balances[msg.sender] >= amount_ && amount_ > 0) {
            balances[msg.sender] = safeSub(balances[msg.sender], amount_);
            balances[to_] = safeAdd(balances[to_], amount_);
            emit Transfer(msg.sender, to_, amount_);
            return true;
        } else {
            return false;
        }
    }

    /* A contract attempts to get the coins */
    function transferFrom(
        address from_,
        address to_,
        uint256 amount_
    ) public returns(bool success) {
        if(balances[from_] >= amount_ && allowed[from_][msg.sender] >= amount_ && amount_ > 0) {
            balances[to_] = safeAdd(balances[to_], amount_);
            balances[from_] = safeSub(balances[from_], amount_);
            allowed[from_][msg.sender] = safeSub(allowed[from_][msg.sender], amount_);
            emit Transfer(from_, to_, amount_);
            return true;
        } else {
            return false;
        }
    }

    function balanceOf(
        address _owner
    )
        view
        public
    returns (uint256 balance) {
        return balances[_owner];
    }

    /* Allow another contract to spend some tokens in your behalf */
    function approve(
        address _spender,
        uint256 _value
    )
        public
    returns (bool success) {
        assert((_value == 0) || (allowed[msg.sender][_spender] == 0));
        allowed[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }

    function allowance(address _owner, address _spender) view public returns (uint256 remaining) {
        return allowed[_owner][_spender];
    }
}

contract BoltChainPoint is StandardToken {
    // metadata
    address public owner;
    string public version = "1.0";
    string public name = "BoltChain Point";
    string public symbol = "BCP";

    event ApplyService(bytes32 indexed service, address indexed user, uint256 indexed price);

    // constructor
    constructor(
    )
        payable
        public
    {
        owner = msg.sender;
        decimals = 18;
        totalSupply = 0;
    }

    modifier onlyOwner
    {
        assert(msg.sender == owner);
        _;
    }

    function transferOwnership(
        address newOwner_
    )
        onlyOwner
        public
    {
        owner = newOwner_;
    }

    fallback() external payable {}
    receive()
        external
        payable
    {
        uint256 amount = msg.value;
        address sender = msg.sender;
        if(amount > 0) {
            totalSupply = safeAdd(totalSupply, amount);
            balances[sender] = safeAdd(balances[sender], amount);
            emit Issue(address(0), amount);
            emit Transfer(address(0), sender, amount);
        }
    }

    function requestService(
        bytes32 service
    )
        external
        payable
    returns(bool success) {
        emit ApplyService(service, msg.sender, msg.value);
        return true;
    }

    function burn(
        uint256 amount_
    )
        public
    returns(bool success) {
        if(amount_ > 0 && balances[msg.sender] >= amount_) {
            balances[msg.sender] = safeSub(balances[msg.sender], amount_);
            totalSupply = safeSub(totalSupply, amount_);
            emit Transfer(msg.sender, address(0), amount_);
            emit Burn(address(0), amount_);
            return true;
        }
    }

    function burnFrom(
        address user_,
        uint256 amount_
    )
        public
        onlyOwner
    returns(bool success) {
        if (balances[user_] >= amount_ && amount_ > 0) {
            balances[user_] = safeSub(balances[user_], amount_);
            totalSupply = safeSub(totalSupply, amount_);
            emit Transfer(user_, owner, amount_);
            emit Burn(owner, amount_);
            return true;
        }
    }
    
    function getDecimals()
        view
        public
    returns(uint256 _decimals) {
        return decimals;
    }
}
