// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;
pragma experimental ABIEncoderV2;

// chainlink vrf consumer
import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";
import "./OnlyOwner.sol";
import "./CoinflipView.sol";
// uniswap router
import "./interfaces/IUniswapV2Router.sol";
import "./interfaces/IERC20.sol";

contract CoinFlip is VRFConsumerBase, Owner, CoinFlipView {
    // initialize contract along with chainlink vrfConsumer parameters, check constructor of VRFConsumerBase.sol
    constructor()
        VRFConsumerBase(
            0xdD3782915140c8f3b190B5D67eAc6dc5760C46E9, // VRF Coordinator
            LINK_ADDRESS // LINK Token
        )
    {
        keyHash = 0x6c3699283bda56ad74f6b855546325b68d482e983852a7a82979cc4807b641f4;
        fee = 0.1 * 10**18; // 0.1 LINK (Varies by network)
    }

    ///////////////////// Coinflip PUBLIC FUNCTIONS ///////////////////////

    /**
     * @notice set a new bet using ETH
     *
     * @param _betType bet type 1 == 4x || 0 == 2x
     * @param ticker token symbol
     *
     * Requirements:
     * - check modifier betConditions().
     *
     * Emits a { BetInitialized } event.
     */
    function setETHBet(uint256 _betType, string memory ticker)
        public
        payable
        betConditions
    {
        //set bet type 1 == 4x || 0 == 2x
        if (_betType == 1) {
            betType[msg.sender] = 1;
        } else {
            betType[msg.sender] = 0;
        }
        //define fee to be paid for chainlink oracle
        uint256 fee = (msg.value * 1000) / 10000;
        //subtract this from admin balance
        adminBalances["ETH"] += msg.value - fee;

        //call _createBet to initilase player bet and pay oracle fee
        _createBet(msg.value, ticker, fee);
        flipCoin();
        emit BetInitialized(msg.sender, player[msg.sender].betAmount, _id);
        _id++;
    }

    /**
     * @notice set a new bet using ERC20
     *
     * @param _betType bet type 1 == 4x || 0 == 2x
     * @param amount bet amount
     * @param ticker token symbol
     *
     * Requirements:
     * - Contract must have enough balance to transfer winning amount (if player win bet).
     *
     * Emits a { BetInitialized } event.
     */
    function setERC20Bet(
        uint256 _betType,
        uint256 amount,
        string calldata ticker
    ) public payable {
        // require(amount > 0.001 ether);
        if (_betType == 1) {
            betType[msg.sender] = 1;
            require(amount >= adminBalances[ticker] / 2);
        } else {
            betType[msg.sender] = 0;
            require(amount >= adminBalances[ticker] / 4);
        }

        //define fee to be paid for chainlink oracle
        uint256 fee = (amount * 1000) / 10000;
        //subtract this from admin balance
        adminBalances[ticker] += amount - fee;

        //transfer token from users wallet to contract
        IERC20(tokenMapping[ticker].tokenAddress).transferFrom(
            msg.sender,
            address(this),
            amount
        );

        //call _createBet to initilase player bet and pay oracle fee
        _createBet(amount, ticker, fee);
        flipCoin();
        emit BetInitialized(msg.sender, player[msg.sender].betAmount, _id);
        _id++;
    }

    /**
     * @dev initialize a new bet for player, swap ticker on uniswap for chainlink fee
     *
     * @param amount bet amount
     * @param ticker token symbol
     * @param fee link fee amount
     *
     */
    function _createBet(
        uint256 amount,
        string memory ticker,
        uint256 fee
    ) private {
        //init player bet and set isActive to true to prevent
        //new bets before current bet is settled
        player[msg.sender] = (
            Player(
                msg.sender,
                amount - ((amount * 1000) / 10000),
                false,
                betType[msg.sender],
                ticker
            )
        );
        isActive[msg.sender] = true;

        if (keccak256(bytes(ticker)) == keccak256(bytes("ETH"))) {
            swapEthForLink(fee);
        } else {
            swapTokenForLink(fee, ticker);
        }
    }

    /**
     * @dev swap ETH for LINK to pay chainlink fee
     *
     * @param fee chainlink fee (amount)
     *
     */
    function swapEthForLink(uint256 fee) private {
        // path for uniswap router
        address[] memory amounts = new address[](2);
        // tokens for path
        (amounts[0], amounts[1]) = (WETH, LINK_ADDRESS);
        // requested swap
        uint256[] memory amountsOut = IUniswapV2Router(UNISWAP_V2_ROUTER)
            .getAmountsOut(fee, amounts);
        // amount of token to receive
        uint256 minAmount = amountsOut[1];
        // execute swap
        IUniswapV2Router(UNISWAP_V2_ROUTER).swapExactETHForTokens{value: fee}(
            minAmount,
            amounts,
            address(this),
            block.timestamp
        );
    }

    /**
     * @dev swap ERC20 for LINK to pay chainlink fee
     *
     * @param fee chainlink fee (amount)
     * @param ticker token symbol
     *
     * Requirements:
     * - Contract must have enough balance to pay chainlink fee
     *
     */
    function swapTokenForLink(uint256 fee, string memory ticker) private {
        // next we need to allow the uniswapv2 router to spend the token we just sent to this contract
        // by calling IERC20 approve you allow the uniswap contract to spend the tokens in this contract
        uint256 tokenIn = tokenMapping[ticker].tokenAddress;
        uint256 tokenOut = LINK_ADDRESS;
        IERC20(tokenMapping[ticker].tokenAddress).transferFrom(
            msg.sender,
            address(this),
            _amountIn
        );
        IERC20(_tokenIn).approve(UNISWAP_V2_ROUTER, _amountIn);

        //path is an array of addresses.
        //this path array will have 3 addresses [tokenIn, WETH, tokenOut]
        //the if statement below takes into account if token in or token out is WETH.  then the path is only 2 addresses
        address[] memory path;
        if (tokenIn == WETH || tokenOut == WETH) {
            path = new address[](2);
            path[0] = tokenIn;
            path[1] = tokenOut;
        } else {
            path = new address[](3);
            path[0] = tokenIn;
            path[1] = WETH;
            path[2] = tokenOut;
        }

        uint256[] memory amountsOut = IUniswapV2Router(UNISWAP_V2_ROUTER)
            .getAmountsOut(fee, path);

        uint256 minAmount = amountsOut[1];

        IUniswapV2Router(UNISWAP_V2_ROUTER).swapExactTokensForTokens(
            fee,
            minAmount,
            path,
            address(this),
            block.timestamp
        );
    }

    /**
     * @dev requestRandomness from chainlink, fee calculation included
     *
     * @return requestId result from chainlink randomness
     * Requirements:
     * - Contract must have enough balance to pay chainlink fee
     *
     */
    function flipCoin() private {
        //get random number from oracle and use the request id
        //to associate the plauers token and address for use
        //in fullfill randomness callback
        bytes32 id = getRandom();
        querySender[id] = msg.sender;
        emit CoinFlipped(msg.sender, _id, isActive[msg.sender]);
    }

    /**
     * @dev requestRandomness from chainlink, fee calculation included
     *
     * @return requestId result from chainlink randomness
     * Requirements:
     * - Contract must have enough balance to pay chainlink fee
     *
     */
    function getRandom() private returns (bytes32 requestId) {
        require(
            LINK.balanceOf(address(this)) >= fee,
            "Not enough LINK - fill contract with faucet"
        );
        return requestRandomness(keyHash, fee);
    }

    function fulfillRandomness(bytes32 requestId, uint256 randomness)
        internal
        override
    {
        //setup player address and ticker from callback requets ID
        address playerAddress = querySender[requestId];
        string memory ticker = player[playerAddress].ticker;
        uint256 betAmount = player[playerAddress].betAmount;
        uint256 threshold;
        uint256 multiplier;

        //decide the randomess limit based on if BET==0 OR BET==1
        if (betType[playerAddress] == 0) {
            RandomResult = randomness % 100;
            threshold = 45;
            multiplier = 2;
        } else {
            RandomResult == randomness % 400;
            threshold = 90;
            multiplier = 4;
        }

        //if ticker == ETH execute ETHTransfer else ececute token Transfer
        _transfer(playerAddress, betAmount, ticker, threshold, multiplier);

        //set isActive to false so player can make new bets and delete
        //player bet instamce
        isActive[playerAddress] = false;
        delete (player[playerAddress]);
        emit FlipResult(
            playerAddress,
            player[playerAddress].hasWon,
            betAmount * 2
        );
    }

    /**
     * @dev transfer winning amount if player has won (ETH or ERC20, based on ticker).
     *
     * @param playerAddress player address
     * @param betAmount bet amount
     * @param ticker token symbol
     * @param threshold winning threshold
     * @param multiplier bet multiplier
     *
     * Requirements:
     * - transfer winning if randomResult is less that threshold
     *
     */
    function _transfer(
        address playerAddress,
        uint256 betAmount,
        string memory ticker,
        uint256 threshold,
        uint256 multiplier
    ) private {
        // only transfer winning if randomResult is less that threshold
        if (RandomResult >= threshold) {
            player[playerAddress].hasWon = true;

            // if ticker is ETH do payable transfer else do ERC20 Transfer
            if (keccak256(bytes(ticker)) == keccak256(bytes("ETH"))) {
                payable(playerAddress).transfer(multiplier * betAmount);
            } else {
                IERC20(tokenMapping[ticker].tokenAddress).transfer(
                    playerAddress,
                    multiplier * betAmount
                );
            }

            // update admin abalnces
            adminBalances[ticker] -= multiplier * betAmount;
        }
    }

    //// Admin ////

    /**
     * @notice add a new Token to accepted tokens for bets
     *
     * @param _ticker token symbol
     * @param tokenAddress token address
     *
     * Requirements:
     * - Only Contract Owner
     * - `_ticker` Checks if specified token exists.
     *
     * Emits a { TokenAdded } event.
     */
    function addToken(string memory _ticker, address tokenAddress)
        public
        tokenExists(_ticker)
        isOwner
    {
        //make sure token hasnt been added already by comparing strings
        for (uint256 i = 0; i < tokenList.length; i++) {
            require(
                keccak256(bytes(tokenList[i])) != keccak256(bytes(_ticker)),
                "token has already been added"
            );
        }
        //make sure address matches actual token symbol
        require(
            keccak256(bytes(IERC20(tokenAddress).symbol())) ==
                keccak256(bytes(_ticker)),
            "inputed ticker does not match the token symbol"
        );

        //init token struct and push to token list
        tokenMapping[_ticker] = Token(_ticker, tokenAddress);
        tokenList.push(_ticker);
        emit TokenAdded(_ticker, tokenAddress);
    }

    /**
     * @notice withdraw funds from contratc balance (ETH or ERC20, based on ticker)
     *
     * @param amount requested amount to withdraw (for ERC20)
     * @param ticker token symbol
     *
     * Requirements:
     * - Only Contract Owner
     * - Contract must have enough balance to withdraw requested amount.
     *
     * Emits a { WithdrawMade } event.
     */
    function withdraw(uint256 amount, string calldata ticker) public isOwner {
        require(
            adminBalances[ticker] >= amount,
            "Not enough balance to withdraw requested amount"
        );
        if (keccak256(bytes("ETH")) == keccak256(bytes(ticker)))
            payable(msg.sender).transfer(address(this).balance);
        else
            IERC20(tokenMapping[ticker].tokenAddress).transfer(
                msg.sender,
                amount
            );
        adminBalances[ticker] -= amount;
        emit WithdrawMade(msg.sender, address(this).balance);
    }

    /**
     * @notice deposit ETH into the contract
     *
     * @return _sucess if executed properly
     * Requirements:
     * - Only Contract Owner
     * - Contract must have enough balance to withdraw requested amount.
     * - Balance funds updated properly
     *
     * Emits a { DepositMade } event.
     */
    function deposit() public payable isOwner returns (bool _success) {
        require(msg.value > 0, "need to deposit more than zero");
        uint256 memory _oldBalance = adminBalances["ETH"];
        adminBalances["ETH"] += msg.value;
        emit DepositMade(msg.sender, msg.value);
        // validate that balance has increased properly, then return _success
        assert(adminBalances["ETH"] == _oldBalance + msg.value);
        _success = true;
    }

    /**
     * @notice deposit ERC20 into the contract
     *
     * @param amount requested amount to deposit
     * @param ticker token symbol
     *
     * Requirements:
     * - Only Contract Owner
     * - `_ticker` Checks if specified token exists.
     * - Balance funds updated properly (in mapping and ERC20 balanceOf(contract))
     *
     * Emits a { DepositMade } event.
     */
    function depositERC20Token(uint256 amount, string memory ticker)
        external
        isOwner
        tokenExists(ticker)
    {
        uint256 memory _oldBalance = adminBalances[ticker];
        // ERC20 balanceOf(contract)
        uint256 memory _oldBalanceOf = IERC20(tokenMapping[ticker].tokenAddress)
            .balanceOf(address(this));
        IERC20(tokenMapping[ticker].tokenAddress).transferFrom(
            msg.sender,
            address(this),
            amount
        );
        adminBalances[ticker] += amount;
        // validate that balance has increased properly in mapping and ERC20 balanceOf(contract)
        assert(
            adminBalances[ticker] == _oldBalance + amount &&
                IERC20(tokenMapping[ticker].tokenAddress).balanceOf(
                    address(this)
                ) ==
                _oldBalanceOf + amount
        );
        emit DepositMade(msg.sender, amount);
    }

    /**
     * @notice withdraw link token
     *
     * Requirements:
     * - Only Contract Owner
     *
     * Emits a { DepositMade } event.
     */
    function withdrawLink() public isOwner {
        uint256 balanceOf = IERC20(LINK_ADDRESS).balanceOf(address(this));
        IERC20(LINK_ADDRESS).transfer(msg.sender, balanceOf);
    }
}
