
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint);

    function balanceOf(address account) external view returns (uint);

    function transfer(address recipient, uint amount) external returns (bool);

    function allowance(address owner, address spender) external view returns (uint);

    function approve(address spender, uint amount) external returns (bool);

    function transferFrom(
        address sender,
        address recipient,
        uint amount
    ) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint value);
    event Approval(address indexed owner, address indexed spender, uint value);
}

contract ERC20 is IERC20 {
    uint public totalSupply;

    mapping (address => uint) public balanceOf;
    mapping(address => mapping(address => uint)) public allowance;

    string public name = "TCRtoken"; // Nome do token
    string public symbol = "TCT";  // Símbolo do token
    uint8 public decimals = 8; 

    function transfer(address tokenReceiver, uint numTokens) public returns (bool success) {
        require(balanceOf[msg.sender] >= numTokens);

        balanceOf[msg.sender] -= numTokens;
        balanceOf[tokenReceiver] += numTokens;
        emit Transfer(msg.sender, tokenReceiver, numTokens);
        return true;
    }

    function approve(address delegate, uint numTokens) public returns (bool success) {
        allowance[msg.sender][delegate] = numTokens;
        emit Approval(msg.sender,delegate,numTokens);
        return true;
    }
    
    function transferFrom(address owner, address buyer, uint numTokens) public returns (bool success) {
        require(balanceOf[owner] >= numTokens);
        require(allowance[owner][msg.sender] >= numTokens);

        balanceOf[owner] -= numTokens;
        balanceOf[buyer] += numTokens;
        allowance[owner][msg.sender] -= numTokens;
        emit Transfer(owner,buyer,numTokens);
        return true;
    }
    
    function mint(uint amount) external {
        balanceOf[msg.sender] += amount;
        totalSupply += amount;
        emit Transfer(address(0), msg.sender, amount);
    }

    function burn(uint amount) external {
        balanceOf[msg.sender] -= amount;
        totalSupply -= amount;
        emit Transfer(msg.sender, address(0), amount);
    }
}