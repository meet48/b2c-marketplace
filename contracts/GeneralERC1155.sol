// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;
import "@openzeppelin/contracts@4.7.3/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts@4.7.3/access/Ownable.sol";
import "@openzeppelin/contracts@4.7.3/utils/Strings.sol";

contract NFT is ERC1155, Ownable {
    using Strings for uint256;
    
    // typeId Counts, starting with 1 and Automatic Increment
    uint256 public typeIdCount;

    // total supply
    uint256 public totalSupply;

    struct TypeInfo {
        uint256 id;             // type id
        string name;            // type name
        uint256 amount;         // total quantity of this type
        uint256 percentage;     // the percentage of typeId amount
    }

    // mapping from typeId to TypeInfo
    mapping(uint256 => TypeInfo) private _typeIds;

    constructor(address initialOwner) ERC1155("") { 
        transferOwnership(initialOwner);       
    }

    // add type
    function addType(string memory name, uint256 amount, address to) external onlyOwner returns(uint256) {
        require(to != address(0), "to is zero address");
        return _addType(name, amount, to);
    }

    // batch add type
    function batchAddType(string[] memory names, uint256[] memory amounts, address[] memory tos) external onlyOwner returns(uint256[] memory) {
        require(names.length == amounts.length && amounts.length == tos.length, "array lengths are not equal");
        uint256[] memory tokenIds = new uint256[](names.length);
        for (uint256 i = 0; i < names.length; i++) {
            require(tos[i] != address(0), "zero address");
            tokenIds[i] = _addType(names[i], amounts[i], tos[i]);
        }

        return tokenIds;
    }

    // internal add type
    function _addType(string memory name, uint256 amount, address to) internal returns(uint256) {        
        typeIdCount++;
        if(amount > 0){
            _mint(to, typeIdCount, amount, "");
            totalSupply += amount;
        }
        _typeIds[typeIdCount] = TypeInfo(typeIdCount, name, amount, 0);

        return typeIdCount;
    }

    // set typeId name
    function setTypeIdName(uint256 id, string memory name) external onlyOwner {
        require(_typeIds[id].id == id, "typeId does not exist");
        _typeIds[id].name = name;
    }

    // mint
    function mint(uint256 id, uint256 amount, address to) public onlyOwner {
        require(_typeIds[id].id == id, "typeId does not exist");
        require(amount > 0, "amount is zero");
        require(to != address(0), "to is zero address");
        _mint(to, id, amount, "");
        _typeIds[id].amount += amount;
        totalSupply += amount;
    }

    // burn
    function burn(uint256 id, uint256 amount) external {
        super._burn(msg.sender, id, amount);
        _typeIds[id].amount -= amount;
        totalSupply -= amount;
    }

    // set base uri
    function setURI(string memory newuri) public onlyOwner {
        _setURI(newuri);
    }

    // gets the id of the uri
    function uri(uint256 id) public view override returns (string memory) {
        return string(abi.encodePacked(super.uri(id) , id.toString() , ".json"));
    }

    // get typeId information
    function typeOfId(uint256 id) external view returns (TypeInfo memory) {
        require(_typeIds[id].id == id, "typeId does not exist");
        TypeInfo memory info;
        uint256 total = totalSupply;
        info = _typeIds[id];
        info.percentage = (total > 0)? info.amount * 10000 / total : 0;

        return info;
    }

    // get information of typeId range
    function types(uint256 start, uint256 end) external view returns (TypeInfo[] memory) {
        require(start > 0 && start <= end && end <= typeIdCount, "start or end error");
        TypeInfo[] memory info = new TypeInfo[](end - start + 1);
        uint256 total = totalSupply;
        for(uint256 i = 0; i + start <= end; i++){
            info[i] = _typeIds[i + start];
            info[i].percentage = (total > 0)? info[i].amount * 10000 / total : 0;
        }

        return info;   
    }




}
