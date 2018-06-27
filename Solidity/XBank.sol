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

contract XBank is SafeMath {

    mapping (address => mapping(address => uint)) public ownerTokenAmount;
    mapping (address => uint) public ownerEtherAmount;
    mapping (address => mapping( address => mapping (address => uint256))) allowed;
    mapping (address => mapping(address => uint)) balances;
    address public ethaddress = address(1); 
        
    event xApproval(address indexed _owner, address indexed _token, address indexed _spender, uint256 _value);
    event xTransfer(address indexed _from, address indexed _token, address indexed _to, uint256 _value, bool _trueTransfer);
    
    function deposit (address _token)
        public 
        payable 
    {
        if(msg.value > 0){
            balances[ethaddress][msg.sender] += msg.value;
        }
        if(Token(_token).allowance(msg.sender, this) > 0){
            balances[_token][msg.sender] += Token(_token).allowance(msg.sender, this);
        }
    }
    
    function withdraw (address _token, uint _amount)
        public 
    {
        if(balances[ethaddress][msg.sender] >= _amount){
            balances[ethaddress][msg.sender] -= _amount;
            if(_token == address(1)){
                require(msg.sender.send(_amount));
            } else {
                require(Token(_token).transfer(msg.sender, _amount));
            }
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
            } else {
                balances[_to][_token] = safeAdd(balances[_to][_token], _value);
            }
            xTransfer(msg.sender, _token, _to, _value, _trueTransfer);
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
            xTransfer(_from, _token, _to, _value, _trueTransfer);
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
        xApproval(msg.sender, _token, _spender, _value);
        return true;
    }
    
    function allowance(address _owner, address _token, address _spender) constant public returns (uint256 remaining) {
        return allowed[_owner][_token][_spender];
    }
    
}
