// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

/**
 * @dev Marketplace storage.
 */
contract MarketplaceStorage {
    // Address that will receive as trade fees.
    address public recipient;

    // Rate, 100% equal 10000.
    uint256 public fee = 300;

    // The sell from the nft owner.
    bytes32 internal constant SELL_HASH = keccak256("Sell(address signer,address nftContract,uint256 nftTokenId,address nftOwner,uint256 price,uint256 startTime,uint256 endTime,uint256 nonce)");

    // The bid from the bider.
    bytes32 internal constant AUCTION_HASH = keccak256("Auction(address signer,address nftContract,uint256 nftTokenId,address nftOwner,uint256 highestBid,uint256 startTime,uint256 endTime,uint256 nonce)");

    Voucher[] public vouchers;

    struct Auction {
        address signer;
        address nftContract;
        uint256 nftTokenId;
        address nftOwner;
        uint256 highestBid;
        uint256 startTime;
        uint256 endTime;
        uint256 nonce;
        bytes signature;
    }

    struct Sell {
        address signer;
        address nftContract;
        uint256 nftTokenId;
        address nftOwner;
        uint256 price;
        uint256 startTime;
        uint256 endTime;
        uint256 nonce;
        bytes signature;
    }


    struct Voucher {
        address signer;
        uint256 nonce;
        bool isValid;
    }

    event Buy(address _contract , uint256 _tokenId , address _old , address _new);
    event SetVoucher(address signer , uint256 nonce , bool isValid);
    event RemoveVoucher(address signer , uint256 nonce);   
}