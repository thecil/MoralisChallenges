// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;
pragma experimental ABIEncoderV2;

import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";
import "./OnlyOwner.sol";
import "./CoinflipView.sol";
import "./interfaces/IUniswapV2Router.sol";
import "./interfaces/IERC20.sol";
import "./CoinflipState.sol";

/**
 * @dev Include all variables(public and private ), events and functions (external, publics) for 'Coinflip' contract
 *
 */
contract CoinFlipView is CoinFlipState {
    address public constant LINK_ADDRESS =
        0xa36085F69e2889c224210F603D836748e7dC0088;
    address public constant UNISWAP_V2_ROUTER =
        0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address public constant UNISWAP_SWAP_CONTRACT =
        0x828eD3Ed7C001a786A17335001B63473BF275568;
    address public constant WETH = 0xd0A1E359811322d97991E03f863a0C30C2cF029C;
    address public constant FACTORY =
        0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
    // chainlink vrf consumer parameters for constructor of it
    bytes32 public keyHash;
    uint256 public fee;
    // simple counter for each bet.
    uint256 _id = 0;
    // array of accepted tokens for bet, used on addToken()
    string[] public tokenList;

    //// NOT USED VARs ////
    uint256 private contractBalance;
    /**
     * @dev used at fulfillRandomness() to imitate randomness
     */
    uint256 public RandomResult;

    /**
     * @dev Fired in deposit() and depositERC20Token()
     *
     * @param depositedBy an address which executed update (contract creator only)
     * @param amount deposited amount
     */
    event DepositMade(address depositedBy, uint256 amount);
    /**
     * @dev Fired in withdraw()
     *
     * @param withdrawedBy an address which executed update (contract creator only)
     * @param amount withdrawed amount
     */
    event WithdrawMade(address withdrawedBy, uint256 amount);
    /**
     * @dev Fired in setETHBet() and setERC20Bet()
     *
     * @param player_address an address which executed update
     * @param amount amount to bet
     * @param betId bet id (_id)
     */
    event BetInitialized(address player_address, uint256 amount, uint256 betId);
    /**
     * @dev Fired in flipCoin()
     *
     * @param playerAddress an address which executed update
     * @param betId bet id (_id)
     * @param isActive player bet status (always should be: true )
     */
    event CoinFlipped(address playerAddress, uint256 betId, bool isActive);
    /**
     * @dev Fired in fulfillRandomness()
     *
     * @param player an address which executed update
     * @param won bet status
     * @param amountWon amount winned (transfered) from the bet
     */
    event FlipResult(address indexed player, bool won, uint256 amountWon);
    /**
     * @dev Fired in addToken()
     *
     * @param ticker ticker of the new token
     * @param tokenAddress address of the new ticker token
     */
    event TokenAdded(string ticker, address tokenAddress);

    //// NOT USED EVENTS ////
    event LogNewProvableQuery(address indexed player);
    event balanceUpdated(
        address player,
        uint256 newBalance,
        uint256 oldBalance
    );
    event generatedRandomNumber(uint256 randomNumber);

    // returns an array of all accepted tokens for bets
    function getTokenList() external view returns (string[] memory) {
        return tokenList;
    }

    // returns a random number for imitate result
    function getRandomResult() external view returns (uint256) {
        return RandomResult;
    }

    /**
     * @dev returns an struct of the data of a ticker from tokenMapping
     * @param ticker requested ticker
     * @return Token {string ticker, address tokenAddress}
     */
    function getTokenByTicker(string calldata ticker)
        external
        view
        returns (Token memory)
    {
        return tokenMapping[ticker];
    }

    // returns bet type 1 == 4x || 0 == 2x
    function getPlayerBetType() external view returns (uint256) {
        return betType[msg.sender];
    }

    // returns the LINK balanceOf(contract)
    function getLinkContractBalance() public view returns (uint256) {
        return IERC20(LINK_ADDRESS).balanceOf(address(this));
    }

    // returns the ETH contract balance
    function getContratcBalance() public view returns (uint256) {
        return address(this).balance;
    }

    // return the bet Log of all bet histroys
    function getActiveBets() public view returns (Player memory) {
        return player[msg.sender];
    }

    // returns the player bet status (true: have a bet opened, false: no bet opened yet)
    function isActiveBet() public view returns (bool) {
        return isActive[msg.sender];
    }

    /**
     * @dev returns the token(ticker) balance of the contract
     * @param ticker token
     * @return uint256 balance
     */
    function getPlayerBalance(string memory ticker)
        public
        view
        returns (uint256)
    {
        return adminBalances[ticker];
    }
}
