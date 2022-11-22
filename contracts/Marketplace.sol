// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/draft-EIP712.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./MarketplaceStorage.sol";
import "./EnglishAuction.sol";


/**
 * @dev Marketplace
 */
contract Marketplace is Ownable , EIP712 , MarketplaceStorage , EnglishAuction {
    
    constructor() EIP712("marketplace" , "1") {
        recipient = msg.sender;
    }

    function setRecipient(address _new) external onlyOwner {
        require(_new != address(0) , "zero address");
        require(recipient.code.length == 0 , "contract address");
        recipient = _new;
    }

    function setFee(uint256 _fee) external onlyOwner {
        require(_fee < 10000 , "value error");
        fee = _fee;
    }

    function platformWithdraw(uint256 value) external onlyOwner {
        require(recipient != address(0) , "zero address");
        require(recipient.code.length == 0 , "contract address");
        require(value <= platformBalance , "value > platformBalance");
        platformBalance -= value;
        payable(recipient).transfer(value);
    }

    function setVoucher(address signer , uint256 nonce , bool isValid) external onlyOwner {
        uint256 length = vouchers.length;
        uint256 i;
        for( ; i < length ; i++){
            if(vouchers[i].signer == signer && vouchers[i].nonce == nonce){
                break;
            }   
        }

        if(i == length){
            vouchers.push(Voucher(signer , nonce , isValid));
        }else{
            vouchers[i].isValid = isValid;
        }

        emit SetVoucher(signer, nonce, isValid);
    }

    function removeVoucher(address signer , uint256 nonce) external onlyOwner {
        uint256 length = vouchers.length;
        for(uint256 i ; i < length ; i++){
            if(vouchers[i].signer == signer && vouchers[i].nonce == nonce){
                vouchers[i] = vouchers[length - 1];
                vouchers.pop();
                emit RemoveVoucher(signer , nonce);
                break;
            }   
        }
    }

    /**
     * @dev Returns whether the voucher is registered valid
     */
    function isValidVoucher(address signer , uint256 nonce) public view returns(bool){
        bool isValid;
        uint256 length = vouchers.length;
        for(uint256 i ; i < length ; i++){
            if(vouchers[i].signer == signer && vouchers[i].nonce == nonce && vouchers[i].isValid){
                isValid = true;
            }   
        }

        return isValid;
    }


    function getAllVouchers() external view returns (Voucher[] memory) {
        return vouchers;
    }

    /**
     * @dev Buy
     */
    function buy(Sell calldata voucher) external payable {
        require(isSell(voucher) , "signature missmatch");
        require(isValidVoucher(voucher.signer , voucher.nonce) , "invalid voucher");
        require(voucher.startTime <= block.timestamp , "no start");
        require(voucher.endTime > block.timestamp , "end");
        require(msg.value >= voucher.price , "value error");
        require(isERC721(voucher.nftContract) , "not ERC721 contract");

        // Transfer nft
        IERC721 nft = IERC721(voucher.nftContract);
        nft.transferFrom(voucher.nftOwner, msg.sender, voucher.nftTokenId);
        
        // Pay
        uint256 feeAmount = voucher.price * fee / 10000;
        payable(voucher.nftOwner).transfer(voucher.price - feeAmount);
        platformBalance += msg.value - (voucher.price - feeAmount);

        emit Buy(voucher.nftContract , voucher.nftTokenId , voucher.nftOwner , msg.sender);
    }

    function isSell(Sell calldata voucher) public view returns (bool) {
        bytes32 _hash = _hashTypedDataV4(keccak256(abi.encode(
                    SELL_HASH,
                    voucher.signer,
                    voucher.nftContract,
                    voucher.nftTokenId,
                    voucher.nftOwner,
                    voucher.price,
                    voucher.startTime,
                    voucher.endTime,
                    voucher.nonce
                )));

        return ECDSA.recover(_hash, voucher.signature) == voucher.signer;
    }

    function setEnglishAuctionFee(uint256 _fee) external onlyOwner {
        _setFee(_fee);
    }

    function firstBid(Auction calldata voucher) external payable {
        require(isEnglishAuction(voucher) , "signature missmatch");
        require(isValidVoucher(voucher.signer , voucher.nonce) , "invalid voucher");
        require(voucher.startTime <= block.timestamp , "no start");
        require(voucher.endTime > block.timestamp , "end");

        // Create
        _create(voucher.nftContract , voucher.nftTokenId , voucher.nonce , voucher.nftOwner , voucher.highestBid , voucher.endTime);

        // Start
        bytes32 hash = getHash(voucher.nftContract , voucher.nftTokenId , voucher.nonce);
        _start(hash);

        // Bid
        bid(hash);
    }

    function isEnglishAuction(Auction calldata voucher) public view returns (bool) {
        bytes32 _hash = _hashTypedDataV4(keccak256(abi.encode(
                    AUCTION_HASH,
                    voucher.signer,
                    voucher.nftContract,
                    voucher.nftTokenId,
                    voucher.nftOwner,
                    voucher.highestBid,
                    voucher.startTime,
                    voucher.endTime,
                    voucher.nonce
                )));

        return ECDSA.recover(_hash, voucher.signature) == voucher.signer;
    }
 
    function endEnlishAuction(bytes32 hash) public onlyOwner {
        _endAuction(hash);
    }

}

