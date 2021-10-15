// SPDX-License-Identifier: MIT

pragma solidity ^0.6.6;

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

contract CustomToken is StandardToken {
    // metadata
    address public owner;
    string public version = "1.0";
    string public name;
    string public symbol;

    // constructor
    constructor(
        string memory name_,
        string memory symbol_,
        uint256 decimals_
    )
        payable
        public
    {
        owner = msg.sender;
        totalSupply = 0;
        name = name_;
        symbol = symbol_;
        decimals = decimals_;
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

    function mint(
        address user_,
        uint256 amount_
    )
        public
        onlyOwner
    returns(bool success) {
        if(amount_ > 0 && user_ != address(0)) {
            totalSupply = safeAdd(totalSupply, amount_);
            balances[user_] = safeAdd(balances[user_], amount_);
            emit Issue(address(0), amount_);
            emit Transfer(address(0), user_, amount_);
            return true;
        }
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

contract CentralBank is SafeMath {
    address owner;
    
    mapping(uint256 => address) Tokens;
    mapping(address => uint256) Prices;
    mapping(uint256 => address) Users;
    mapping(address => bool) UserExists;
    uint256 TokenCount = 0;
    uint256 UserCount = 0;
    
    event Register(address indexed _user);
    event NewToken(address indexed _contract);
    event Airdrop(address indexed _user, address indexed _token, uint256 indexed _amount);

    constructor()
        payable
        public
    {
        owner = msg.sender;
    }
    
    modifier onlyOwner
    {
        assert(msg.sender == owner);
        _;
    }

    function getToken(
        uint256 index_
    )
        public
        view
    returns(address _tokenAddress, uint256 _tokenPrice) {
        address tokenAddress = Tokens[index_];
        uint256 tokenPrice = Prices[tokenAddress];
        return (tokenAddress, tokenPrice);
    }
    
    function getUser(
        uint256 index_
    )
        public
        view
    returns(address _userAddress) {
        return Users[index_];
    }

    function createToken(
        string memory name_,
        string memory symbol_,
        uint256 decimals_,
        uint256 price_
    )
        public
    returns(bool _success) {
        CustomToken token = new CustomToken(name_, symbol_, decimals_);
        address tokenAddress = address(token);
        Tokens[TokenCount] = tokenAddress;
        Prices[tokenAddress] = price_ > 0 ? price_ : 1;
        TokenCount++;
        return true;
    }
    
    function registerUser(
        address user_,
        uint256 value_
    )
        public
    returns(bool _success) {
        if(!UserExists[user_]) {
            UserExists[user_] = true;
            for(uint i = 0; i < TokenCount; i++) {
                address tokenAddress = Tokens[i];
                CustomToken token = CustomToken(tokenAddress);
                uint256 price = Prices[tokenAddress];
                uint256 decimals = token.getDecimals();
                uint256 amount = safeDiv(safeMul(value_, 10 ** decimals), price);
                token.mint(user_, amount);
            }
            if(address(this).balance > 0.1 ether) {
                payable(user_).transfer(0.1 ether);
            }
        }
        return true;
    }
    
    function withdraw()
        public
        onlyOwner
    returns(bool _success) {
        payable(msg.sender).transfer(address(this).balance);
        return true;
    }
}
