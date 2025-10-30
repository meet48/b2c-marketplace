// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

/**
 * @dev English auction.
 */
contract EnglishAuction {

    struct BidData {
        address nftOwner;
        address nftContract;
        uint256 nftTokenId;
        bool isStart;
        uint256 endTime;
        bool isEnd;
        address highestBidder;
        uint256 highestBid;
    }

    // Mapping from hash to biddata.
    mapping(bytes32 => BidData) public englishBids;

    mapping(address => uint256) internal _bids;
    
    // 100% equal 10000 ，300 equal 3%.
    uint256 private _fee = 300;

    uint256 public platformBalance;

    bool public locked;

    event Create(address indexed contractAddress , uint256 indexed tokenId);
    event Start(bytes32 indexed hash);
    event Bid(bytes32 indexed hash , address indexed bidder , uint256 amount);
    event End(bytes32 indexed hash , address winner , uint256 amount);
    event Withdraw(address indexed bidder , uint256 amount);
    event EndAuction(bytes32 indexed hash);

    constructor(){

    }
 
   function _setFee(uint256 _new) internal {
        require(_new < 10000 , "value error");
        _fee = _new;
    }

    /**
     * @dev Create.
     */
    function _create(
            address nftContract , 
            uint256 tokenId , 
            uint256 nonce , 
            address owner , 
            uint256 highestBid , 
            uint256 endTime
            ) internal {

        bytes32 _hash = getHash(nftContract, tokenId , nonce);
        require(isERC721(nftContract) , "not ERC721 contract");
        
        IERC721 nft = IERC721(nftContract);
        require(nft.ownerOf(tokenId) == owner , "not nft owner");
        require(nft.isApprovedForAll(owner , address(this)) || nft.getApproved(tokenId) == address(this) , "not approved");
        
        require(endTime > block.timestamp , "out of date");
        require(englishBids[_hash].nftContract == address(0) , "auction created");
        
        BidData memory _bidData;
        _bidData.nftOwner = owner;
        _bidData.nftContract = nftContract;
        _bidData.nftTokenId = tokenId;
        _bidData.highestBid = highestBid;
        _bidData.endTime = endTime;

        englishBids[_hash] = _bidData;

        emit Create(nftContract , tokenId);
    }

    /**
     * @dev Start.
     */
    function _start(bytes32 hash) internal {
        _requireExists(hash);
    
        BidData storage _bidData = englishBids[hash];
        require(!_bidData.isStart , "started");
        require(_bidData.endTime > block.timestamp , "ended");

        _bidData.isStart = true;

        emit Start(hash);
    }    

    /**
     * @dev Bid.
     */
    function bid(bytes32 hash) public virtual payable {
        _requireExists(hash);

        BidData storage _bidData = englishBids[hash];
        require(_bidData.isStart , "not started");
        require(_bidData.endTime > block.timestamp , "ended");
        require(msg.value > _bidData.highestBid , "value <= highestBid");

        if(_bidData.highestBidder != address(0)){
            _bids[_bidData.highestBidder] += _bidData.highestBid;
        }

        _bidData.highestBidder = msg.sender;
        _bidData.highestBid = msg.value;

        emit Bid(hash , msg.sender , msg.value);
    }

    /**
     * @dev End.
     */
    function end(bytes32 hash) external {
        _requireExists(hash);
        BidData storage _bidData = englishBids[hash];
        require(_bidData.isStart , "not started");
        require(block.timestamp > _bidData.endTime , "not ended");
        require(!_bidData.isEnd , "ended");

        IERC721 nft = IERC721(_bidData.nftContract);

        if(_bidData.highestBidder != address(0)){
            // Transfer nft.
            nft.transferFrom(_bidData.nftOwner, _bidData.highestBidder, _bidData.nftTokenId);

            // Pay.
            uint256 feeAmount = _bidData.highestBid * _fee / 10000;
            platformBalance += feeAmount;

            payable(_bidData.nftOwner).transfer(_bidData.highestBid - feeAmount);
        }

        _bidData.isEnd = true;

        emit End(hash , _bidData.highestBidder , _bidData.highestBid);
    }

    modifier _noReentrant() {
        require(!locked , "no re-entrancy");
        locked = true;
        _;
        locked = false;
    }


    // Function to allow a user to withdraw their bid amount
    // External visibility: can be called from outside the contract
    // _noReentrant modifier: prevents reentrancy attacks to ensure secure fund transfers
    function withdraw() external _noReentrant() {
        // Retrieve the bid amount associated with the calling address
        uint256 amount = _bids[msg.sender];
        
        // Ensure the user has a non-zero bid amount to withdraw
        require(amount > 0 , "amount zero");
        
        // Reset the user's bid amount to zero to prevent re-withdrawal
        _bids[msg.sender] = 0;
        
        // Transfer the bid amount to the calling address (converted to payable)
        payable(msg.sender).transfer(amount);
        
        // Emit an event to log the withdrawal, including the user's address and withdrawn amount
        emit Withdraw(msg.sender , amount);
    }


    function _endAuction(bytes32 hash) internal {
        _requireExists(hash);

        BidData storage _bidData = englishBids[hash];
        require(_bidData.isStart , "not started");
        require(block.timestamp > _bidData.endTime , "not ended");
        require(!_bidData.isEnd , "ended");

        payable(_bidData.highestBidder).transfer(_bidData.highestBid);

        _bidData.isEnd = true;

        emit EndAuction(hash);
    }

    /**
     * @dev Returns fee.
     */
    function getEnglishAuctionFee() public view returns (uint256) {
        return _fee;
    }

    function exists(bytes32 hash) public view returns (bool){
        return englishBids[hash].nftContract != address(0) ? true : false;
    }

    function _requireExists(bytes32 hash) internal view {
        require(exists(hash) , "auction not create");
    }

    function withdrawAmount(address bidder) public view returns (uint256) {
        return _bids[bidder];
    }

    /**
     * @dev Create hash.
     */
    function getHash(address nftContract , uint256 tokenId , uint256 nonce) public pure returns (bytes32) {
        return keccak256(abi.encode(nftContract , tokenId , nonce));
    }

    /**
     * @dev Returns whether it is the ERC721 contract.
     */
    function isERC721(address _addr) public view returns (bool) {
        return IERC721(_addr).supportsInterface(0x80ac58cd);
    }
 
}
