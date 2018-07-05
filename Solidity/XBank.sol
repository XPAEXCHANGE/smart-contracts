pragma solidity ^0.4.21;

interface Token {
    function totalSupply() constant external returns (uint256 ts);
    function balanceOf(address _owner) constant external returns (uint256 balance);
    function transfer(address _to, uint256 _value) external returns (bool success);
    function transferFrom(address _from, address _to, uint256 _value) external returns (bool success);
    function approve(address _spender, uint256 _value) external returns (bool success);
    function allowance(address _owner, address _spender) constant external returns (uint256 remaining);
    
    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);
}

interface transferRecipient {
    function receiveTransfer(address _from, address _token, uint256 _value, bytes _extraData) external;
    function getXBank() external view returns ( address );
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
        bytes32 hash = keccak256(block.number, msg.sender, salt);
        return uint(hash) % N;
    }
}

contract Authorization {
    mapping(address => address) public agentBooks;
    address public owner;
    address public operator;
    address public bank;
    bool public powerStatus = true;
    bool public forceOff = false;
    
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
        if(forceOff) {
            powerStatus = false;
        } else {
            powerStatus = onOff_;
        }
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
    
    function assignAgent(
        address agent_
    )
        public
    {
        agentBooks[msg.sender] = agent_;
    }
    
    function isRepresentor(
        address representor_
    )
        public
        view
    returns(bool) {
        return agentBooks[representor_] == msg.sender;
    }
    
    function getUser(
        address representor_
    )
        internal
        view
    returns(address) {
        return isRepresentor(representor_) ? representor_ : msg.sender;
    }
}

contract StandardToken is SafeMath, Authorization {
    string public constant name = "XPA Game Point";
    string public constant symbol = "XGP";
    string public version = "1.0";
    uint256 public constant decimals = 18;
    
    uint256 public totalSupply;
    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);
    event Issue(address indexed _to, uint256 indexed _value);
    event Burn(address indexed _from, uint256 indexed _value);
    /* constructure */
    function StandardToken() public payable {
        totalSupply = 0;
    }
    
    function issue(
        address user_,
        uint256 amount_
    )
        public
        onlyOperator
    returns(bool success) {
        if(amount_ > 0 && user_ != address(0)) {
            totalSupply = safeAdd(totalSupply, amount_);
            balances[user_] = safeAdd(balances[user_], amount_);
            emit Issue(owner, amount_);
            emit Transfer(owner, user_, amount_);
            return true;
        }
    }
    
    function burn(
        uint256 amount_
    )
        public
        onlyOperator 
    returns(bool success) {
        if(amount_ > 0 && balances[msg.sender] >= amount_) {
            balances[msg.sender] = safeSub(balances[msg.sender], amount_);
            totalSupply = safeSub(totalSupply, amount_);
            emit Transfer(msg.sender, owner, amount_);
            emit Burn(owner, amount_);
            return true;
        }
    }
    
    /* Send coins */
    function transfer(address _to, uint256 _value) public returns (bool success) {
        if (balances[msg.sender] >= _value && _value > 0) {
            balances[msg.sender] = safeSub(balances[msg.sender], _value);
            balances[_to] = safeAdd(balances[_to], _value);
            emit Transfer(msg.sender, _to, _value);
            return true;
        } else {
            return false;
        }
    }

    /* A contract attempts to get the coins */
    function transferFrom(address _from, address _to, uint256 _value) public returns (bool success) {
        if (balances[_from] >= _value && allowed[_from][msg.sender] >= _value && _value > 0) {
            balances[_to] = safeAdd(balances[_to], _value);
            balances[_from] = safeSub(balances[_from], _value);
            allowed[_from][msg.sender] = safeSub(allowed[_from][msg.sender], _value);
            emit Transfer(_from, _to, _value);
            return true;
        } else {
            return false;
        }
    }

    function balanceOf(address _owner) constant public returns (uint256 balance) {
        return balances[_owner];
    }

    /* Allow another contract to spend some tokens in your behalf */
    function approve(address _spender, uint256 _value) public returns (bool success) {
        assert((_value == 0) || (allowed[msg.sender][_spender] == 0));
        allowed[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }
    
    function allowance(address _owner, address _spender) constant public returns (uint256 remaining) {
        return allowed[_owner][_spender];
    }

    /* This creates an array with all balances */
    mapping (address => uint256) balances;
    mapping (address => mapping (address => uint256)) allowed;
}

contract XBank is StandardToken {

    mapping (address => mapping( address => mapping (address => uint256))) public allowed;
    mapping (address => mapping(address => uint)) public balances; //[user][token] = amount
    address ethaddress = address(1); 
        
    event xApproval(address indexed _owner, address indexed _token, address indexed _spender, uint256 _value);
    event xTransfer(address indexed _from, address indexed _token, address indexed _to, uint256 _value, bool _trueTransfer);
    event xDeposit(address _user, address _token, uint256 _amount);
    event xWithdraw(address _user, address _token, uint256 _amount);

    function deposit (address _token)
        public 
        onlyActive 
        payable 
    {
        if(msg.value > 0){
            balances[msg.sender][ethaddress] += msg.value;
            emit xDeposit(msg.sender, ethaddress, msg.value);
        }
        uint256 _amount = Token(_token).allowance(msg.sender, this);
        if(_amount > 0 && Token(_token).transferFrom(msg.sender, this, _amount) ){
            balances[msg.sender][_token] += _amount;
            emit xDeposit(msg.sender, _token, _amount);
        }
    }
    
    function withdraw (address _token, uint _amount)
        public 
    {
        if(balances[msg.sender][_token] >= _amount){
            balances[msg.sender][_token] -= _amount;
            if(_token == address(1)){
                require(msg.sender.send(_amount));
            } else {
                require(Token(_token).transfer(msg.sender, _amount));
            }
            emit xWithdraw(msg.sender, _token, _amount);
        }
    }
    
    /* Send coins */
    function transfer(address _to, address _token, uint256 _value, bool _trueTransfer) public returns (bool success) {
        if (balances[msg.sender][_token] >= _value && _value > 0) {
            balances[msg.sender][_token] = safeSub(balances[msg.sender][_token], _value);
            if(_trueTransfer) {
                if(_token == address(1)){
                    _to.transfer(_value);
                } else {
                    require(Token(_token).transfer(_to, _value));
                }
            }
            balances[_to][_token] = safeAdd(balances[_to][_token], _value);
            emit xTransfer(msg.sender, _token, _to, _value, _trueTransfer);
            return true;
        } else {
            return false;
        }
    }
    
    /* Send coins and call receiveTransfer*/
    function transferAndCall(address _to, address _token, uint256 _value, bool _trueTransfer, bytes _extraData) public returns (bool success) {
        if(transfer(_to, _token, _value, _trueTransfer)) {
            transferRecipient(_to).receiveTransfer(msg.sender, _token, _value, _extraData);
            return true;
        }
    }
    
    /* A contract attempts to get the coins */
    function transferFrom(address _from, address _token, address _to, uint256 _value, bool _trueTransfer) public returns (bool success) {
        if (balances[_from][_token] >= _value && allowed[_from][_token][msg.sender] >= _value && _value > 0) {
            balances[_from][_token] = safeSub(balances[_from][_token], _value);
            if(_trueTransfer) {
                if(_token == address(1)){
                    _to.transfer(_value);
                } else {
                    require(Token(_token).transfer(_to, _value));
                }
            } else {
                balances[_to][_token] = safeAdd(balances[_to][_token], _value);
            }
            allowed[_from][_token][msg.sender] = safeSub(allowed[_from][_token][msg.sender], _value);
            emit xTransfer(_from, _token, _to, _value, _trueTransfer);
            return true;
        } else {
            return false;
        }
    }
    
    function balanceOf(address _owner, address _token) constant public returns (uint256 balance) {
        return balances[_owner][_token];
    }
    
    function approve(address _spender, address _token, uint256 _value) public returns (bool success) {
        assert((_value == 0) || (allowed[msg.sender][_token][_spender] == 0));
        allowed[msg.sender][_token][_spender] = _value;
        emit xApproval(msg.sender, _token, _spender, _value);
        return true;
    }
    
    function allowance(address _owner, address _token, address _spender) constant public returns (uint256 remaining) {
        return allowed[_owner][_token][_spender];
    }
    
    function withdrawProfit(address _to, address _token) 
        public 
        onlyOperator
    {
        if(transferRecipient(_to).getXBank() == address(this)){
            require(Token(_token).transfer(bank, balances[_to][_token]));
            balances[_to][_token] = 0;
        }
    }
}