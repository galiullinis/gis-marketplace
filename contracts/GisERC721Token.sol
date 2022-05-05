// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./IGisERC721.sol";

contract GisERC721Token is ERC721, IGisERC721, AccessControl {
    using Counters for Counters.Counter;

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    string public baseTokenURI;
    Counters.Counter private currentTokenId;

    modifier onlyMinter {
        require(hasRole(MINTER_ROLE, msg.sender), "don't have minter role.");
        _;
    }
    
    constructor(string memory tokenName, string memory tokenSymbol) ERC721(tokenName, tokenSymbol) {
        baseTokenURI = "";
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setRoleAdmin(MINTER_ROLE, DEFAULT_ADMIN_ROLE);
    }
    
    function mint(address recipient) onlyMinter public override returns (uint256){
        currentTokenId.increment();
        uint256 newItemId = currentTokenId.current();
        _safeMint(recipient, newItemId);
        return newItemId;
    }

    function _baseURI() internal view override returns(string memory){
        return baseTokenURI;
    }

    function setBaseURI(string memory _URI) public {
        baseTokenURI = _URI;
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721, IERC165, AccessControl) returns (bool){
        return
            interfaceId == type(IGisERC721).interfaceId ||
            super.supportsInterface(interfaceId);
    }
}
