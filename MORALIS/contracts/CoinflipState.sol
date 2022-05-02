// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

contract CoinFlipState {

    struct Player {
        address playerAddress;
        uint256 betAmount;
        bool hasWon;
        uint bet_type;
        string ticker;
    }

    struct Token {
        string ticker;
        address tokenAddress;
    }

    mapping(string => Token) tokenMapping;
    mapping(address => bool) isActive;                    
    mapping(address => Player) player;
    mapping(address => uint) betType;
    mapping(bytes32 => address) querySender;
    mapping(string => uint) adminBalances;

    modifier betConditions {
        // require(msg.value >= 0.001 ether, "Insuffisant amount, please increase your bet!");
        require(
            isActive[msg.sender] == false, 
            "Cannot have more than one active bet at a time"
        );
        if(betType[msg.sender] == 1) 
            require(
                msg.value <= address(this).balance / 2, 
                "You can't bet more than half the contracts bal"
            );
        else 
            require(
                msg.value <= address(this).balance / 4, 
                "You can't bet more than 1 quarter the contracts bal"
            );
        _;
    }

    modifier tokenExists(string memory _ticker) {
        require(tokenMapping[_ticker].tokenAddress != address(0));
        _;
    }

}