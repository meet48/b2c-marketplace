// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract NftCalim is Ownable, IERC1155Receiver, ERC165 {
    using ECDSA for bytes32;
    address public signer;
    bool public isOpen;
    mapping(address => mapping(uint256 => bool)) public allow;
    mapping(bytes32 => bool) public signatures;

    event SignerUpdated(address indexed newSigner);
    event Claimed(
        string orderId,
        address sender,
        address nft,
        uint256 id,
        uint256 amount
    );

    constructor(address initialOwner, address _signer) Ownable(initialOwner) {
        require(_signer != address(0), "Invalid signer address");
        signer = _signer;
    }

    function setSigner(address _signer) external onlyOwner {
        require(_signer != address(0), "Invalid signer address");
        signer = _signer;
        
        emit SignerUpdated(_signer);
    }
    
    function setIsOpen(bool _isOpen) external onlyOwner {
        isOpen = _isOpen;
    }

    function setAllow(address nft, uint256 nftId, bool allowed) external onlyOwner {
        require(nft != address(0), "Invalid address");
        allow[nft][nftId] = allowed;
    }

    function claim(
        string memory orderId,
        address nft,
        uint256 nftId,
        uint256 nftAmount,
        address nftFrom,
        address recipient,
        uint256 startTime,
        uint256 endTime,
        uint256 salt,
        bytes calldata signature
    ) external {
        require(isOpen, "Claiming is disabled");
        bytes32 messageHash = keccak256(abi.encodePacked(orderId, nft, nftId, nftAmount, nftFrom, recipient, startTime, endTime, salt));
        require(_verifySignature(messageHash, signature), "Invalid signature");

        bytes32 _signature = getBytes32(signature);
        require(!signatures[_signature], "Signature already used");

        require(allow[nft][nftId], "Claim not allowed");
        require(block.timestamp >= startTime, "Not started");
        require(block.timestamp <= endTime, "Ended");
        require(msg.sender == recipient, "Caller is not recipient");

        signatures[_signature] = true;

        IERC1155(nft).safeTransferFrom(address(this), recipient, nftId, nftAmount, '0x');

        emit Claimed(orderId, msg.sender, nft, nftId, nftAmount);
    }

    function _verifySignature(bytes32 messageHash, bytes memory signature) internal view returns (bool) {
        bytes32 ethSignedHash = _getEthSignedMessageHash(messageHash);
        return ECDSA.recover(ethSignedHash, signature) == signer;
    }

    function _getEthSignedMessageHash(bytes32 _messageHash) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", _messageHash));
    }

    function getBytes32(bytes memory content) public pure returns (bytes32) {
        return keccak256(content);
    }
    
    function withdrawNFT(address nftContract, address to, uint256 tokenId, uint256 amount, bytes calldata data) external onlyOwner {
        IERC1155(nftContract).safeTransferFrom(address(this), to, tokenId, amount, data);
    }

    function onERC1155Received(address operator, address from, uint256 id, uint256 value, bytes calldata data) external pure override returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(address operator, address from, uint256[] calldata ids, uint256[] calldata values, bytes calldata data) external pure override returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return interfaceId == type(IERC1155Receiver).interfaceId || super.supportsInterface(interfaceId);
    }

}