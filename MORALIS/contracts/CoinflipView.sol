// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;
pragma experimental ABIEncoderV2;

import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";
import "./OnlyOwner.sol";
import "./CoinflipView.sol";
import "./interfaces/IUniswapV2Router.sol";
import "./interfaces/IERC20.sol";
import "./CoinflipState.sol";

contract CoinFlipView is CoinFlipState {

    address public constant LINK_ADDRESS = 0xa36085F69e2889c224210F603D836748e7dC0088;
    address public constant UNISWAP_V2_ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address public constant UNISWAP_SWAP_CONTRACT = 0x828eD3Ed7C001a786A17335001B63473BF275568;
    address public constant WETH = 0xd0A1E359811322d97991E03f863a0C30C2cF029C;
    address public constant FACTORY = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
    bytes32 public keyHash;
    uint256 public fee;
    uint _id = 0;
    uint256 public RandomResult;
    uint private contractBalance;
    string[] public tokenList;

    event depositMade(address depositedBy, uint amount);
    event withdrawMade(address withdrawedBy, uint amount);
    event betInitialized(address player_address, uint amount, uint betId);
    event coinFlipped(address playerAddress, uint betId, bool hasWon);
    event FlipResult(address indexed player, bool won, uint amountWon);
    event LogNewProvableQuery(address indexed player);
    event balanceUpdated(address player, uint newBalance, uint oldBalance);
    event generatedRandomNumber(uint256 randomNumber);
    event tokenAdded(string ticker, address tokenAddress);

    function getTokenList() external view returns(string[] memory) {
        return tokenList;
    }

    function getRandomResult() external view returns(uint) {
        return RandomResult;
    }

    function getTokenByTicker(string calldata ticker) external view returns(Token memory) {
        return tokenMapping[ticker];
    }

    function getPlayerBetType() external view returns(uint) {
        return betType[msg.sender];
    }
   function getLinkContractBalance() public view returns (uint256) {
        return IERC20(LINK_ADDRESS).balanceOf(address(this));
    }
    
    //returns the contract balance
    function getContratcBalance() public view returns(uint) {
        return address(this).balance;
    }
 
    //return the bet Log of all bet histroys   
    function getActiveBets() public view returns(Player memory) {
        return player[msg.sender];
    }

    function isActiveBet() public view returns(bool) {
        return isActive[msg.sender];
    }

    function getPlayerBalance(string memory ticker) public view returns (uint) {
        return adminBalances[ticker];
    }
}