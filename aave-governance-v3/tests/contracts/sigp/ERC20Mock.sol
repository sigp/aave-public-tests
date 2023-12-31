pragma solidity ^0.8.11;

contract ERC20Mock {
    string public  symbol;
    string public  name;
    uint8 public constant decimals = 18;
    uint256 public totalSupply = 0;

    mapping(address => uint256) internal _balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    address public minter;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor(string memory _name, string memory _symbol) {
        minter = msg.sender;
        name = _name;
        symbol = _symbol;
        _mint(msg.sender, 100000000 * 10**18); 
    }

    // No checks as its meant to be once off to set minting rights to BaseV1 Minter
    function setMinter(address _minter) external {
        require(msg.sender == minter);
        minter = _minter;
    }

    function approve(address _spender, uint256 _value) external returns (bool) {
        allowance[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }

    function _mint(address _to, uint256 _amount) internal returns (bool) {
        _balanceOf[_to] += _amount;
        totalSupply += _amount;
        emit Transfer(address(0x0), _to, _amount);
        return true;
    }

    function balanceOf(address account) external view returns (uint256) {
        return _balanceOf[account];
    }

    function _transfer(
        address _from,
        address _to,
        uint256 _value
    ) internal returns (bool) {
        _balanceOf[_from] -= _value;
        _balanceOf[_to] += _value;
        emit Transfer(_from, _to, _value);
        return true;
    }

    function transfer(address _to, uint256 _value) external returns (bool) {
        return _transfer(msg.sender, _to, _value);
    }

    function transferFrom(
        address _from,
        address _to,
        uint256 _value
    ) external returns (bool) {
        uint256 allowed_from = allowance[_from][msg.sender];
        if (allowed_from != type(uint256).max) {
            allowance[_from][msg.sender] -= _value;
        }
        return _transfer(_from, _to, _value);
    }

    function mint(address account, uint256 amount) external returns (bool) {
        require(msg.sender == minter);
        _mint(account, amount);
        return true;
    }
}