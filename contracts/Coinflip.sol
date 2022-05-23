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
    constructor() VRFConsumerBase
    (
        0xdD3782915140c8f3b190B5D67eAc6dc5760C46E9, // VRF Coordinator
        0xa36085F69e2889c224210F603D836748e7dC0088  // LINK Token
    ) {
        keyHash = 0x6c3699283bda56ad74f6b855546325b68d482e983852a7a82979cc4807b641f4;
        fee = 0.1 * 10 ** 18; // 0.1 LINK (Varies by network)
    }

    ///////////////////// Coinflip PUBLIC FUNCTIONS ///////////////////////

    // set a new bet using ETH
    function setETHBet(
        uint _betType, 
        string memory ticker
    ) 
        public 
        betConditions
        payable  
    {
        //set bet type 1 == 4x || 0 == 2x
        if(_betType == 1) {
            betType[msg.sender] = 1;
        }else {
            betType[msg.sender] = 0;
        }
        //define fee to be paid for chainlink oracle
        uint fee = msg.value * 1000 / 10000;
        //subtract this from admin balance
        adminBalances["ETH"] += msg.value - fee;

        //call _createBet to initilase player bet and pay oracle fee
        _createBet(msg.value, ticker, fee); 
        flipCoin();
        emit BetInitialized(msg.sender, player[msg.sender].betAmount, _id); 
        _id++;
    }
    
    // set a new bet using ERC20
    function setERC20Bet(
        uint _betType, 
        uint amount, 
        string calldata ticker
    ) 
        public
        payable  
    {     
        // require(amount > 0.001 ether);
        if(_betType == 1) {
            betType[msg.sender] = 1;
            require(amount >= adminBalances[ticker] / 2);
        }else {
            betType[msg.sender] = 0;
            require(amount >= adminBalances[ticker] / 4);
        }

        //define fee to be paid for chainlink oracle
        uint fee = amount * 1000 / 10000;
        //subtract this from admin balance
        adminBalances[ticker] += amount - fee;
        
        //transfer token from users wallet to contract
        IERC20(tokenMapping[ticker].tokenAddress)
            .transferFrom(msg.sender, address(this), amount);

        //call _createBet to initilase player bet and pay oracle fee
        _createBet(amount, ticker, fee); 
        flipCoin();
        emit BetInitialized(msg.sender, player[msg.sender].betAmount, _id);
        _id++; 
    }


    function _createBet(
        uint amount,
        string memory ticker, 
        uint fee
    ) 
        private 
    {
        //init player bet and set isActive to true to prevent 
        //new bets before current bet is settled
        player[msg.sender] = 
            (
                Player(
                    msg.sender, 
                    amount - (amount * 1000 / 10000), 
                    false, 
                    betType[msg.sender],
                    ticker
                )
        );
        isActive[msg.sender] = true;

        if(keccak256(bytes(ticker)) == keccak256(bytes("ETH"))) {
            swapEthForLink(fee);
        } else {
            swapTokenForLink(fee, ticker);
        }
    }

    function swapEthForLink(uint fee) private {
        address[] memory amounts = new address[](2);
        (amounts[0], amounts[1]) = (WETH, LINK_ADDRESS);
        uint[] memory amountsOut = 
            IUniswapV2Router(UNISWAP_V2_ROUTER)
                .getAmountsOut(fee, amounts);
        uint minAmount = amountsOut[1];
        IUniswapV2Router(UNISWAP_V2_ROUTER)
            .swapExactETHForTokens{value: fee}(
                minAmount, 
                amounts, 
                address(this), 
                block.timestamp
            );
    }

    function swapTokenForLink(
        uint fee, 
        string memory ticker
    ) 
        private 
    {
        // next we need to allow the uniswapv2 router to spend the token we just sent to this contract
       // by calling IERC20 approve you allow the uniswap contract to spend the tokens in this contract 
        uint tokenIn = tokenMapping[ticker].tokenAddress;
        uint tokenOut = LINK_ADDRESS;
        IERC20(tokenMapping[ticker].address).transferFrom(msg.sender, address(this), _amountIn);
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
        
        uint[] memory amountsOut = 
            IUniswapV2Router(UNISWAP_V2_ROUTER)
                .getAmountsOut(fee, path);

        uint minAmount = amountsOut[1];

        IUniswapV2Router(UNISWAP_V2_ROUTER)
            .swapExactTokensForTokens(
                fee,
                minAmount, 
                path, 
                address(this), 
                block.timestamp
            );
    }

    function flipCoin() private {
        //get random number from oracle and use the request id
        //to associate the plauers token and address for use
        //in fullfill randomness callback
        bytes32 id = getRandom();
        querySender[id] = msg.sender;
        emit CoinFlipped(msg.sender, _id, isActive[msg.sender]);
    }

    function getRandom() private returns (bytes32 requestId) {
        //reqyuire contract has sufficent link to pay oracle 
        //(0.1 LINK) then call requestRandoness from chainlink
        require(
            LINK.balanceOf(address(this)) >= fee, 
            "Not enough LINK - fill contract with faucet"
        );
        return requestRandomness(keyHash, fee);
    }

    function fulfillRandomness(
        bytes32 requestId, 
        uint256 randomness
    ) 
        internal
        override 
    {
        //setup player address and ticker from callback requets ID
        address playerAddress =  querySender[requestId];
        string memory ticker = player[playerAddress].ticker;
        uint betAmount = player[playerAddress].betAmount;
        uint threshold;
        uint multiplier;

        //decide the randomess limit based on if BET==0 OR BET==1
        if(betType[playerAddress] == 0) {
            RandomResult = randomness % 100;
            threshold = 45;
            multiplier = 2;

        } else {
            RandomResult == randomness % 400;
            threshold = 90;
            multiplier = 4;
        }

        //if ticker == ETH execute ETHTransfer else ececute token Transfer
        _transfer(
            playerAddress, 
            betAmount, 
            ticker, 
            threshold, 
            multiplier
        );

        //set isActive to false so player can make new bets and delete
        //player bet instamce
        isActive[playerAddress] = false;
        delete(player[playerAddress]);
        emit FlipResult (playerAddress, player[playerAddress].hasWon, betAmount * 2); 
    }

    function _transfer(
        address playerAddress, 
        uint betAmount, 
        string memory ticker, 
        uint threshold, 
        uint multiplier
    ) 
        private 
    {
        // only transfer winning if randomResult is less that threshold
        if (RandomResult >= threshold) {
            player[playerAddress].hasWon = true;

            // if ticker is ETH do payable transfer else do ERC20 Transfer
            if(keccak256(bytes(ticker)) == keccak256(bytes("ETH"))) {
                payable(playerAddress).transfer(multiplier * betAmount);
            } else {
                IERC20(tokenMapping[ticker].tokenAddress)
                    .transfer(playerAddress, multiplier * betAmount);
            }

            // update admin abalnces
            adminBalances[ticker] -= multiplier * betAmount;
        }
    }


    /////////////////////Addmin/////////////////////

    // contract creator add new bet token to contract
    function addToken(
        string memory _ticker, 
        address tokenAddress
    ) 
        public 
        tokenExists(_ticker) 
        isOwner() 
    {
        //make sure token hasnt been added already by comparing strings
        for (uint i = 0; i < tokenList.length; i++) {
            require(keccak256(bytes(tokenList[i])) != keccak256(bytes(_ticker)), "token has already been added"); 
        }
        //make sure address matches actial token symbol
        require(
            keccak256(bytes(IERC20(tokenAddress).symbol())) == 
            keccak256(bytes(_ticker)), 
            "inputted ticker does not match the token symbol"
        );

        //init token struct and push to token list
        tokenMapping[_ticker] = Token(_ticker, tokenAddress);
        tokenList.push(_ticker);
        emit TokenAdded(_ticker, tokenAddress);
    }

    // contratc creator withdraw the entire contratc balance (ETH or ERC20, based on ticker)
    function withdraw(
        uint amount, 
        string calldata ticker
    ) 
        public
        isOwner  
    {
        require(adminBalances[ticker] >= amount);
        if (keccak256(bytes("ETH")) == keccak256(bytes(ticker))) 
        payable(msg.sender).transfer(address(this).balance);
        else IERC20(tokenMapping[ticker].tokenAddress).transfer(msg.sender, amount);
        adminBalances[ticker] -= amount;
        emit WithdrawMade(msg.sender, address(this).balance);

    }

    // contract creator deposit ETH into the contract
    function deposit() 
        public 
        payable 
        isOwner 
        returns(bool _success) 
    {
        require(msg.value > 0, "need to deposit more than zero");
        adminBalances["ETH"] += msg.value;
        emit DepositMade(msg.sender, msg.value);
        _success = true;
    }

    // contract creator deposit ERC20 into the contract
    function depositERC20Token(
         uint amount, 
         string memory ticker
    ) 
        external 
        isOwner 
        tokenExists(ticker) 
    {
        require(tokenMapping[ticker].tokenAddress != address(0));
        IERC20(tokenMapping[ticker].tokenAddress).transferFrom(msg.sender, address(this), amount);
        adminBalances[ticker] += amount;  
        emit DepositMade(msg.sender, amount);
    }

    // contract creator withdraw link tokens
    function withdrawLink() public isOwner {
        IERC20 _interface = IERC20(LINK_ADDRESS);
        uint256 balanceOf = _interface.balanceOf(address(this));
        _interface.transfer(msg.sender, balanceOf);
    }
}