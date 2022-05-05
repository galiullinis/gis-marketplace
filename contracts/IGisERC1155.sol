// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

interface IGisERC1155 is IERC1155 {
    function mint(address _to, uint256 _amount, bytes memory _data) external returns(uint256);
    function mintBatch(address _to, uint256[] memory _amounts, bytes memory _data) external returns(uint256[] memory);
}