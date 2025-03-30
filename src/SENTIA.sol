// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface IUniswapV2Factory {
    event PairCreated(address indexed token0, address indexed token1, address pair, uint256);

    function feeTo() external view returns (address);
    function feeToSetter() external view returns (address);

    function getPair(address tokenA, address tokenB) external view returns (address pair);
    function allPairs(uint256) external view returns (address pair);
    function allPairsLength() external view returns (uint256);

    function createPair(address tokenA, address tokenB) external returns (address pair);

    function setFeeTo(address) external;
    function setFeeToSetter(address) external;
}
/**
 * @dev Interface for interacting with Uniswap V2 Router
 */

interface IUniswapV2Router {
    /**
     * @dev Swaps exact ETH for tokens
     * @param amountOutMin Minimum amount of tokens to receive
     * @param path Array of token addresses representing the swap path
     * @param to Address to receive the output tokens
     * @param deadline Timestamp after which the transaction will revert
     * @return amounts Array of input and output token amounts
     */
    function swapExactETHForTokens(uint256 amountOutMin, address[] calldata path, address to, uint256 deadline)
        external
        payable
        returns (uint256[] memory amounts);

    /**
     * @dev Swaps exact ETH for tokens supporting fee-on-transfer tokens
     * @param amountOutMin Minimum amount of tokens to receive
     * @param path Array of token addresses representing the swap path
     * @param to Address to receive the output tokens
     * @param deadline Timestamp after which the transaction will revert
     */
    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable;

    /**
     * @dev Returns the address of WETH token
     * @return Address of the WETH token
     */
    function WETH() external pure returns (address);

    function factory() external pure returns (address);
}

/**
 * @dev SENTIA is an NFT contract with auction mechanism and token burning functionality
 * Each NFT is minted through an auction system where the highest bidder receives the token
 */
contract SENTIA is ERC721, Ownable, ReentrancyGuard {
    /**
     * @dev Structure representing an NFT auction
     */
    struct Auction {
        uint256 tokenId; // ID of the token being auctioned
        uint256 startTime; // Timestamp when the auction starts
        uint256 endTime; // Timestamp when the auction ends
        address highestBidder; // Address of the current highest bidder
        uint256 highestBid; // Value of the current highest bid
        bool settled; // Whether the auction has been settled
    }

    /**
     * @dev dev versioning
     */
    uint256 public constant version = 3;

    // Constants
    /**
     * @dev Duration of each auction in seconds
     */
    uint256 public constant AUCTION_DURATION = 10 minutes; //1 days

    /**
     * @dev Burn address
     */
    address constant BURN_ADDRESS = 0x000000000000000000000000000000000000dEaD;

    /**
     * @dev Minimum bid increment amount in ETH
     */
    uint256 public minBidIncrement = 0.0005 ether; //$1

    /**
     * @dev Address authorized to manage auctions
     */
    address public auctionManager;

    /**
     * @dev Base URI for token metadata
     */
    string private baseTokenURI = "https://bafybeifhofputngb7k3zqpl5otnv4utpvse66sbzutxsg6bkozks6ytt7m.ipfs.dweb.link/";

    // State variables
    /**
     * @dev ID to be used for the next minted token
     */
    uint256 public nextTokenId = 1;

    /**
     * @dev Current active auction
     */
    Auction public currentAuction;

    /**
     * @dev Mapping of user addresses to their pending ETH refunds
     */
    mapping(address => uint256) public pendingReturns;

    // Events
    /**
     * @dev Emitted when a new auction is started
     * @param tokenId ID of the token being auctioned
     * @param startTime Timestamp when the auction starts
     * @param endTime Timestamp when the auction ends
     */
    event AuctionStarted(uint256 indexed tokenId, uint256 startTime, uint256 endTime);

    /**
     * @dev Emitted when a bid is placed
     * @param bidder Address of the bidder
     * @param amount Value of the bid
     */
    event BidPlaced(address indexed bidder, uint256 amount);

    /**
     * @dev Emitted when an auction is settled
     * @param winner Address of the auction winner
     * @param tokenId ID of the token that was auctioned
     * @param amount Final winning bid amount
     */
    event AuctionSettled(address indexed winner, uint256 tokenId, uint256 amount);

    /**
     * @dev Emitted when a user withdraws their pending returns
     * @param recipient Address receiving the withdrawal
     * @param amount Value withdrawn
     */
    event Withdrawal(address indexed recipient, uint256 amount);

    /**
     * @dev Emitted when tokens are burned
     * @param token Address of the token that was burned
     * @param amount Amount of tokens burned
     */
    event TokensBurned(address token, uint256 amount);

    /**
     * @dev Modifier to ensure function is called only during an active auction
     */
    modifier auctionActive() {
        require(
            block.timestamp >= currentAuction.startTime && block.timestamp < currentAuction.endTime,
            "Auction not active"
        );
        _;
    }

    /**
     * @dev Constructor for the SENTIA contract
     * @param initialOwner Address that will be set as the initial owner
     */
    constructor(address initialOwner, address aManager) ERC721("SENTIA", "SENTIA") Ownable(initialOwner) {
        auctionManager = aManager;
        //call rollOverAuction to start the first auction
    }

    /**
     * @dev Place a bid in the current auction
     * Requires payment to be sent with the transaction
     */
    function bid() external payable auctionActive nonReentrant {
        require(msg.value > 0, "bid must be greater than 0");
        require(msg.value >= currentAuction.highestBid + minBidIncrement, "bid must be higher than current bid");

        // Refund the previous highest bidder
        if (currentAuction.highestBidder != address(0)) {
            pendingReturns[currentAuction.highestBidder] += currentAuction.highestBid;
        }

        // Update auction state
        currentAuction.highestBidder = msg.sender;
        currentAuction.highestBid = msg.value;

        emit BidPlaced(msg.sender, msg.value);
    }

    /**
     * @dev Withdraw pending returns (refunded bids)
     */
    function withdraw() external nonReentrant {
        uint256 amount = pendingReturns[msg.sender];
        require(amount > 0, "nothing to withdraw");

        pendingReturns[msg.sender] = 0;
        (bool success,) = msg.sender.call{value: amount}("");
        require(success, "transfer failed");

        emit Withdrawal(msg.sender, amount);
    }

    /**
     * @dev Place a bid using pending returns balance and optionally additional ETH
     * @param amount Amount of pending returns to use for the bid
     */
    function usePendingBalanceForBid(uint256 amount) external payable auctionActive nonReentrant {
        require(amount > 0, "Amount must be greater than 0");
        require(pendingReturns[msg.sender] >= amount, "Insufficient pending balance");

        pendingReturns[msg.sender] -= amount;

        uint256 totalBid = amount;
        if (msg.value > 0) {
            totalBid += msg.value;
        }

        require(
            totalBid >= currentAuction.highestBid + minBidIncrement,
            "bid lower then winner and minBidIncrement"
        );

        // Refund the previous highest bidder
        if (currentAuction.highestBidder != address(0)) {
            pendingReturns[currentAuction.highestBidder] += currentAuction.highestBid;
        }

        // Update auction state
        currentAuction.highestBidder = msg.sender;
        currentAuction.highestBid = totalBid;

        emit BidPlaced(msg.sender, totalBid);
    }

    /**
     * @dev Get details of the current auction
     * @return tokenId ID of the token being auctioned
     * @return startTime Timestamp when the auction started
     * @return endTime Timestamp when the auction ends
     * @return highestBidder Address of the current highest bidder
     * @return highestBid Value of the current highest bid
     * @return settled Whether the auction has been settled
     */
    function getCurrentAuction()
        public
        view
        returns (
            uint256 tokenId,
            uint256 startTime,
            uint256 endTime,
            address highestBidder,
            uint256 highestBid,
            bool settled
        )
    {
        Auction memory auction = currentAuction;
        return (
            auction.tokenId,
            auction.startTime,
            auction.endTime,
            auction.highestBidder,
            auction.highestBid,
            auction.settled
        );
    }

    /**
     * @dev Settle the current auction and start a new one
     * Can only be called by the auction manager after the current auction has ended
     */
    function rollover() external {
        require(msg.sender == auctionManager, "Caller is not the auction manager");
        require(block.timestamp >= currentAuction.endTime, "Current auction not ended");

        // Settle the current auction if it exists and hasn't been settled
        if (currentAuction.tokenId != 0 && !currentAuction.settled) {
            currentAuction.settled = true;

            if (currentAuction.highestBidder != address(0)) {
                // Mint NFT to the winner
                _safeMint(currentAuction.highestBidder, currentAuction.tokenId);
                emit AuctionSettled(currentAuction.highestBidder, currentAuction.tokenId, currentAuction.highestBid);
            } else {
                // If no bids, emit event with zero address
                emit AuctionSettled(address(0), currentAuction.tokenId, 0);
            }
        }

        // Start new auction
        uint256 tokenId = nextTokenId++;
        uint256 startTime = block.timestamp;
        uint256 endTime = startTime + AUCTION_DURATION;

        currentAuction = Auction({
            tokenId: tokenId,
            startTime: startTime,
            endTime: endTime,
            highestBidder: address(0),
            highestBid: 0,
            settled: false
        });

        emit AuctionStarted(tokenId, startTime, endTime);
    }

    /**
     * @dev Override for the ERC721 _baseURI function
     * @return Base URI for token metadata
     */
    function _baseURI() internal view override returns (string memory) {
        return baseTokenURI;
    }

    /**
     * @dev Set the auction manager address
     * @param _auctionManager Address to set as the auction manager
     */
    function setAuctionManager(address _auctionManager) external onlyOwner {
        auctionManager = _auctionManager;
    }

    /**
     * @dev Set the base URI for token metadata
     * @param uri New base URI to set
     */
    function setBaseURI(string calldata uri) external onlyOwner {
        baseTokenURI = uri;
    }

    /**
     * @dev Set the minimum bid increment
     * @param newIncrement New minimum bid increment value
     */
    function setMinBidIncrement(uint256 newIncrement) external onlyOwner {
        require(newIncrement > 0, "Must be greater than zero");
        minBidIncrement = newIncrement;
    }

    /**
     * @dev Rescue ERC721 tokens that were accidentally sent to this contract
     * @param _tokenAddress Address of the ERC721 token
     * @param tokenId ID of the token to rescue
     * @param recipient Address to receive the rescued token
     */
    function rescueERC721(address _tokenAddress, uint256 tokenId, address recipient) external onlyOwner {
        IERC721(_tokenAddress).safeTransferFrom(address(this), recipient, tokenId);
    }

    /**
     * @dev Rescue ERC20 tokens that were accidentally sent to this contract
     * @param _tokenAddress Address of the ERC20 token
     * @param amount Amount of tokens to rescue
     * @param recipient Address to receive the rescued tokens
     */
    function rescueERC20Token(address _tokenAddress, uint256 amount, address recipient) external onlyOwner {
        IERC20(_tokenAddress).transfer(recipient, amount);
    }

    // @dev Convert all ETH in the contract to tokens and burn them

    function convertETHAndBurn(
        uint256 amountEthToBurn,
        address wethAddress,
        address token,
        address uniV2Router,
        uint256 amountOutMin
    ) external {
        require(msg.sender == auctionManager, "Only auction manager");
        require(address(this).balance >= amountEthToBurn, "No ETH to convert");

        IUniswapV2Router router = IUniswapV2Router(uniV2Router);
        address[] memory path = new address[](2);
        path[0] = wethAddress;
        path[1] = token;

        // Perform the swap
        router.swapExactETHForTokens{value: amountEthToBurn}(amountOutMin, path, address(this), block.timestamp + 300);

        // token with fees?
        // router.swapExactETHForTokensSupportingFeeOnTransferTokens{value: address(this).balance}(
        //     amountOutMin,
        //     path,
        //     address(this),
        //     block.timestamp + 300
        // );

        uint256 receivedTokens = IERC20(token).balanceOf(address(this));
        IERC20(token).transfer(BURN_ADDRESS, receivedTokens);

        emit TokensBurned(token, receivedTokens);
    }

    /**
     * @dev Rescue ETH from the contract
     * @param recipient Address to receive the rescued ETH
     * @param amount Amount of ETH to rescue
     */
    function rescueETH(address payable recipient, uint256 amount) external onlyOwner {
        require(address(this).balance >= amount, "Insufficient balance");
        (bool success,) = recipient.call{value: amount}("");
        require(success, "ETH transfer failed");
    }

    /**
     * @dev See {IERC165-supportsInterface}
     * @param interfaceId Interface identifier to check
     * @return Bool indicating whether the interface is supported
     */
    function supportsInterface(bytes4 interfaceId) public view override(ERC721) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    // Allows the contract to receive ETH
    receive() external payable {}
}
