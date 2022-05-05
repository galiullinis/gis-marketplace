// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./IGisERC1155.sol";

contract GisERC1155Token is ERC1155, IGisERC1155, AccessControl {
    using Strings for uint256;
    using Counters for Counters.Counter;

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    Counters.Counter private currentTokenId;
    
    constructor(string memory baseUrl) ERC1155(baseUrl) {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setRoleAdmin(MINTER_ROLE, DEFAULT_ADMIN_ROLE);
    }

    modifier onlyMinter {
        require(hasRole(MINTER_ROLE, msg.sender), "don't have minter role.");
        _;
    }

    function mint(address _to, uint256 _amount) onlyMinter public {
        mint(_to, _amount, "");
    }

    function mint(address _to, uint256 _amount, bytes memory _data) onlyMinter public override returns(uint256){
        currentTokenId.increment();
        uint256 newTokenId = currentTokenId.current();
        _mint(_to, newTokenId, _amount, _data);
        return newTokenId;
    }

    function mintBatch(address _to, uint256[] memory _amounts) onlyMinter public {
        mintBatch(_to, _amounts, "");
    }

    function mintBatch(address _to, uint256[] memory _amounts, bytes memory _data) onlyMinter public override returns(uint256[] memory){
        uint256[] memory _ids = new uint256[](_amounts.length);
        for(uint256 i = 0; i < _amounts.length; i++){
            currentTokenId.increment();
            _ids[i] = currentTokenId.current();
        }
        _mintBatch(_to, _ids, _amounts, _data);
        return _ids;
    }

    function uri(uint256 _tokenId) public view override returns(string memory){
        return string(abi.encodePacked(super.uri(_tokenId), _tokenId.toString()));
    }
    
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC1155, IERC165, AccessControl) returns (bool){
        return
            interfaceId == type(IGisERC1155).interfaceId ||
            super.supportsInterface(interfaceId);
    }
}
