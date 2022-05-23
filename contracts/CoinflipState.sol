// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

contract CoinFlipState {
    // player bet data
    struct Player {
        address playerAddress;
        uint256 betAmount;
        bool hasWon;
        uint256 bet_type;
        string ticker;
    }
    // accepted tokens for bets data
    struct Token {
        string ticker;
        address tokenAddress;
    }

    // store accepted tokens for bets, EX:("LINK" => {ticker, tokenAddress})
    mapping(string => Token) tokenMapping;
    // store if player have an opened bet or not, EX: (0xas8... => true)
    mapping(address => bool) isActive;
    // store player actual bet data, EX:(0xas8... => Player)
    mapping(address => Player) player;
    // store player bet type 1 == 4x || 0 == 2x
    mapping(address => uint256) betType;
    // 
    mapping(bytes32 => address) querySender;
    // stores token(ticker) balance of contract
    mapping(string => uint256) adminBalances;

    /**
     * @dev verify:
     * - msg.sender does not have an active bet.
     * -  msg.value is less than contract balance (based on betType)
     */
    modifier betConditions() {
        // require(msg.value >= 0.001 ether, "Insuffisant amount, please increase your bet!");
        require(
            isActive[msg.sender] == false,
            "Cannot have more than one active bet at a time"
        );
        if (betType[msg.sender] == 1)
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

	/**
	 * @notice Checks if specified token exists
	 *
	 * @dev Returns whether the specified ticker is accepted for bets
	 *
	 * @param _ticker the token to query existence for
	 */
    modifier tokenExists(string memory _ticker) {
        require(tokenMapping[_ticker].tokenAddress != address(0), "Token not accepted for bets");

        _;
    }
}
